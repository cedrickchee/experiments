const std = @import("std");
const builtin = @import("builtin");
const root = @import("../root.zig");

const c = @cImport({
    @cInclude("stdlib.h");
    @cInclude("alsa/asoundlib.h");
});

pub const Host = struct {
    pub fn init() root.AudioError!Host {
        if (!isAvailable()) return root.AudioError.BackendUnavailable;
        return .{};
    }

    pub fn isAvailable() bool {
        if (builtin.os.tag != .linux) return false;
        var card: c_int = -1;
        return c.snd_card_next(&card) >= 0;
    }

    pub fn deinit(self: *Host, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
    }

    pub fn devices(self: Host, allocator: std.mem.Allocator) root.AudioError!DeviceList {
        _ = self;
        var hints: [*c]?*anyopaque = null;
        const rc = c.snd_device_name_hint(-1, "pcm", &hints);
        if (rc < 0) return mapAlsaError(rc);
        defer _ = c.snd_device_name_free_hint(hints);

        var list: std.ArrayList(Device) = .empty;
        errdefer {
            for (list.items) |*device| device.deinit(allocator);
            list.deinit(allocator);
        }

        const hint_array: [*c]?*anyopaque = hints;
        var index: usize = 0;
        while (hint_array[index]) |hint| : (index += 1) {
            const name_ptr = c.snd_device_name_get_hint(hint, "NAME");
            if (name_ptr == null) continue;
            defer c.free(name_ptr);

            const ioid_ptr = c.snd_device_name_get_hint(hint, "IOID");
            defer if (ioid_ptr != null) c.free(ioid_ptr);

            const desc_ptr = c.snd_device_name_get_hint(hint, "DESC");
            defer if (desc_ptr != null) c.free(desc_ptr);

            const name = std.mem.span(name_ptr);
            if (name.len == 0) continue;

            const direction = directionFromIoId(ioid_ptr);
            const desc = if (desc_ptr != null) std.mem.span(desc_ptr) else name;
            try list.append(allocator, try Device.init(allocator, name, desc, direction));
        }

        if (list.items.len == 0) {
            try list.append(allocator, try Device.init(allocator, "default", "Default ALSA device", .unknown));
        }

        return .{ .items = try list.toOwnedSlice(allocator) };
    }

    pub fn defaultOutputDevice(self: Host, allocator: std.mem.Allocator) root.AudioError!?Device {
        _ = self;
        return try Device.init(allocator, "default", "Default ALSA output device", .output);
    }
};

pub const DeviceList = struct {
    items: []Device,

    pub fn deinit(self: *DeviceList, allocator: std.mem.Allocator) void {
        for (self.items) |*device| device.deinit(allocator);
        allocator.free(self.items);
    }
};

pub const Device = struct {
    id_text: [:0]const u8,
    name_text: []const u8,
    direction: root.DeviceDirection,

    pub fn init(
        allocator: std.mem.Allocator,
        id_text: []const u8,
        name_text: []const u8,
        direction: root.DeviceDirection,
    ) root.AudioError!Device {
        return .{
            .id_text = try allocator.dupeZ(u8, id_text),
            .name_text = try allocator.dupe(u8, normalizeDescription(name_text)),
            .direction = direction,
        };
    }

    pub fn deinit(self: *Device, allocator: std.mem.Allocator) void {
        allocator.free(self.id_text);
        allocator.free(self.name_text);
    }

    pub fn info(self: Device) root.DeviceInfo {
        return .{
            .host = .alsa,
            .id = self.id_text,
            .name = self.name_text,
            .direction = self.direction,
        };
    }

    pub fn supportedOutputConfigs(
        self: Device,
        allocator: std.mem.Allocator,
    ) root.AudioError![]root.SupportedStreamConfigRange {
        if (!self.direction.supportsOutput()) return root.AudioError.UnsupportedOperation;

        var handle: ?*c.snd_pcm_t = null;
        const open_rc = c.snd_pcm_open(
            &handle,
            self.id_text.ptr,
            c.SND_PCM_STREAM_PLAYBACK,
            c.SND_PCM_NONBLOCK,
        );
        if (open_rc < 0) return mapAlsaError(open_rc);
        defer _ = c.snd_pcm_close(handle);

        var configs: std.ArrayList(root.SupportedStreamConfigRange) = .empty;
        errdefer configs.deinit(allocator);

        try appendProbedFormat(allocator, &configs, handle, .f32, c.SND_PCM_FORMAT_FLOAT_LE);
        try appendProbedFormat(allocator, &configs, handle, .i16, c.SND_PCM_FORMAT_S16_LE);

        return configs.toOwnedSlice(allocator);
    }

    pub fn defaultOutputConfig(self: Device) root.AudioError!root.SupportedStreamConfig {
        const allocator = std.heap.c_allocator;
        const configs = try self.supportedOutputConfigs(allocator);
        defer allocator.free(configs);
        if (configs.len == 0) return root.AudioError.UnsupportedConfig;

        if (findFormat(configs, .f32)) |config_range| {
            return config_range.withStandardSampleRate();
        }
        return configs[0].withStandardSampleRate();
    }

    pub fn buildOutputStreamF32(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.OutputCallbackF32,
        userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        try config_value.validate();
        if (!self.direction.supportsOutput()) return root.AudioError.UnsupportedOperation;

        var handle: ?*c.snd_pcm_t = null;
        var rc = c.snd_pcm_open(&handle, self.id_text.ptr, c.SND_PCM_STREAM_PLAYBACK, 0);
        if (rc < 0) return mapAlsaError(rc);
        errdefer _ = c.snd_pcm_close(handle);

        const latency_us: c_uint = switch (config_value.buffer_size) {
            .default => 100_000,
            .fixed => |frames| @intCast(@max(1, frames) * 1_000_000 / config_value.sample_rate),
        };

        rc = c.snd_pcm_set_params(
            handle,
            c.SND_PCM_FORMAT_FLOAT_LE,
            c.SND_PCM_ACCESS_RW_INTERLEAVED,
            config_value.channels,
            config_value.sample_rate,
            1,
            latency_us,
        );
        if (rc < 0) return mapAlsaError(rc);

        return .{
            .handle = handle.?,
            .config = config_value,
            .callback = callback,
            .userdata = userdata,
        };
    }
};

fn appendProbedFormat(
    allocator: std.mem.Allocator,
    configs: *std.ArrayList(root.SupportedStreamConfigRange),
    handle: ?*c.snd_pcm_t,
    sample_format: root.SampleFormat,
    alsa_format: c.snd_pcm_format_t,
) root.AudioError!void {
    var params: ?*c.snd_pcm_hw_params_t = null;
    var rc = c.snd_pcm_hw_params_malloc(&params);
    if (rc < 0) return mapAlsaError(rc);
    defer c.snd_pcm_hw_params_free(params);

    rc = c.snd_pcm_hw_params_any(handle, params);
    if (rc < 0) return mapAlsaError(rc);

    rc = c.snd_pcm_hw_params_set_access(handle, params, c.SND_PCM_ACCESS_RW_INTERLEAVED);
    if (rc < 0) return;

    rc = c.snd_pcm_hw_params_test_format(handle, params, alsa_format);
    if (rc < 0) return;

    rc = c.snd_pcm_hw_params_set_format(handle, params, alsa_format);
    if (rc < 0) return;

    const channel_range = try probedChannelRange(params);
    const rate_range = try probedRateRange(params);
    const period_range = try probedPeriodSizeRange(params);

    try configs.append(allocator, .{
        .channels = chooseRepresentativeChannels(channel_range.min, channel_range.max),
        .min_sample_rate = rate_range.min,
        .max_sample_rate = rate_range.max,
        .buffer_size = .{ .range = .{
            .min = period_range.min,
            .max = period_range.max,
        } },
        .sample_format = sample_format,
    });
}

const UIntRange = struct {
    min: u32,
    max: u32,
};

fn probedChannelRange(params: ?*c.snd_pcm_hw_params_t) root.AudioError!UIntRange {
    var min: c_uint = 0;
    var max: c_uint = 0;
    var rc = c.snd_pcm_hw_params_get_channels_min(params, &min);
    if (rc < 0) return mapAlsaError(rc);
    rc = c.snd_pcm_hw_params_get_channels_max(params, &max);
    if (rc < 0) return mapAlsaError(rc);
    return sanitizeRange(min, max, 1, std.math.maxInt(u16));
}

fn probedRateRange(params: ?*c.snd_pcm_hw_params_t) root.AudioError!UIntRange {
    var min: c_uint = 0;
    var max: c_uint = 0;
    var dir: c_int = 0;
    var rc = c.snd_pcm_hw_params_get_rate_min(params, &min, &dir);
    if (rc < 0) return mapAlsaError(rc);
    rc = c.snd_pcm_hw_params_get_rate_max(params, &max, &dir);
    if (rc < 0) return mapAlsaError(rc);
    return sanitizeRange(min, max, 1, 768_000);
}

fn probedPeriodSizeRange(params: ?*c.snd_pcm_hw_params_t) root.AudioError!UIntRange {
    var min: c.snd_pcm_uframes_t = 0;
    var max: c.snd_pcm_uframes_t = 0;
    var dir: c_int = 0;
    var rc = c.snd_pcm_hw_params_get_period_size_min(params, &min, &dir);
    if (rc < 0) return mapAlsaError(rc);
    rc = c.snd_pcm_hw_params_get_period_size_max(params, &max, &dir);
    if (rc < 0) return mapAlsaError(rc);
    return sanitizeRange(min, max, 1, std.math.maxInt(u32));
}

fn sanitizeRange(min_value: anytype, max_value: anytype, fallback_min: u32, clamp_max: u32) UIntRange {
    var min: u32 = if (min_value == 0) fallback_min else clampToU32(min_value);
    var max: u32 = if (max_value == 0) min else clampToU32(max_value);
    min = @max(min, fallback_min);
    max = @min(@max(max, min), clamp_max);
    return .{ .min = min, .max = max };
}

fn clampToU32(value: anytype) u32 {
    return if (value > std.math.maxInt(u32)) std.math.maxInt(u32) else @intCast(value);
}

fn chooseRepresentativeChannels(min: u32, max: u32) u16 {
    if (min <= 2 and max >= 2) return 2;
    return @intCast(@min(max, @max(min, 1)));
}

fn findFormat(
    configs: []const root.SupportedStreamConfigRange,
    sample_format: root.SampleFormat,
) ?root.SupportedStreamConfigRange {
    for (configs) |config_range| {
        if (config_range.sample_format == sample_format) return config_range;
    }
    return null;
}

pub const Stream = struct {
    handle: *c.snd_pcm_t,
    config: root.StreamConfig,
    callback: root.OutputCallbackF32,
    userdata: ?*anyopaque,
    thread: ?std.Thread = null,
    running: std.atomic.Value(bool) = .init(false),

    pub fn play(self: *Stream) root.AudioError!void {
        if (self.running.swap(true, .seq_cst)) return;
        self.thread = std.Thread.spawn(.{}, run, .{self}) catch |err| switch (err) {
            error.OutOfMemory => return root.AudioError.OutOfMemory,
            error.SystemResources => return root.AudioError.ResourceExhausted,
            error.ThreadQuotaExceeded => return root.AudioError.ResourceExhausted,
            error.LockedMemoryLimitExceeded => return root.AudioError.ResourceExhausted,
            else => return root.AudioError.BackendError,
        };
    }

    pub fn pause(self: *Stream) root.AudioError!void {
        self.running.store(false, .seq_cst);
        if (self.thread) |thread| {
            thread.join();
            self.thread = null;
        }
        const rc = c.snd_pcm_drop(self.handle);
        if (rc < 0) return mapAlsaError(rc);
    }

    pub fn deinit(self: *Stream) void {
        _ = self.pause() catch {};
        _ = c.snd_pcm_close(self.handle);
    }

    fn run(self: *Stream) void {
        const frames: usize = switch (self.config.buffer_size) {
            .default => 256,
            .fixed => |value| @intCast(value),
        };
        const samples = frames * self.config.channels;
        const allocator = std.heap.c_allocator;
        const buffer = allocator.alloc(f32, samples) catch return;
        defer allocator.free(buffer);

        while (self.running.load(.seq_cst)) {
            @memset(buffer, 0);
            const now = root.StreamInstant.nowMonotonic();
            self.callback(buffer, .{ .callback = now, .playback = now }, self.userdata);
            const written = c.snd_pcm_writei(self.handle, buffer.ptr, @intCast(frames));
            if (written < 0) {
                const recovered = c.snd_pcm_recover(self.handle, @intCast(written), 1);
                if (recovered < 0) {
                    self.running.store(false, .seq_cst);
                    return;
                }
            }
        }
    }
};

fn directionFromIoId(ioid_ptr: [*c]u8) root.DeviceDirection {
    if (ioid_ptr == null) return .duplex;
    const ioid = std.mem.span(ioid_ptr);
    if (std.ascii.eqlIgnoreCase(ioid, "Input")) return .input;
    if (std.ascii.eqlIgnoreCase(ioid, "Output")) return .output;
    return .unknown;
}

fn normalizeDescription(description: []const u8) []const u8 {
    return std.mem.trim(u8, description, " \t\r\n");
}

fn mapAlsaError(rc: c_int) root.AudioError {
    return switch (-rc) {
        c.EBUSY, c.EAGAIN => root.AudioError.DeviceBusy,
        c.ENODEV, c.ENOENT => root.AudioError.DeviceNotAvailable,
        c.EACCES, c.EPERM => root.AudioError.PermissionDenied,
        c.EINVAL => root.AudioError.InvalidInput,
        c.ENOMEM => root.AudioError.OutOfMemory,
        else => root.AudioError.BackendError,
    };
}

test "ALSA direction parsing handles missing IOID as duplex" {
    try std.testing.expectEqual(root.DeviceDirection.duplex, directionFromIoId(null));
}

test "ALSA representative channel selection prefers stereo" {
    try std.testing.expectEqual(@as(u16, 2), chooseRepresentativeChannels(1, 8));
    try std.testing.expectEqual(@as(u16, 1), chooseRepresentativeChannels(1, 1));
    try std.testing.expectEqual(@as(u16, 4), chooseRepresentativeChannels(4, 8));
}

test "ALSA range sanitation handles zeros and inverted ranges" {
    try std.testing.expectEqual(UIntRange{ .min = 1, .max = 1 }, sanitizeRange(0, 0, 1, 1024));
    try std.testing.expectEqual(UIntRange{ .min = 64, .max = 64 }, sanitizeRange(64, 32, 1, 1024));
    try std.testing.expectEqual(UIntRange{ .min = 64, .max = 1024 }, sanitizeRange(64, 4096, 1, 1024));
}

test "ALSA preferred default format lookup chooses f32 when present" {
    const ranges = [_]root.SupportedStreamConfigRange{
        .{
            .channels = 2,
            .min_sample_rate = 44_100,
            .max_sample_rate = 48_000,
            .buffer_size = .unknown,
            .sample_format = .i16,
        },
        .{
            .channels = 2,
            .min_sample_rate = 44_100,
            .max_sample_rate = 48_000,
            .buffer_size = .unknown,
            .sample_format = .f32,
        },
    };
    const found = findFormat(&ranges, .f32).?;
    try std.testing.expectEqual(root.SampleFormat.f32, found.sample_format);
}
