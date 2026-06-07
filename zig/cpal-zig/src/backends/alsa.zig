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
        _ = self;
        const configs = try allocator.alloc(root.SupportedStreamConfigRange, 2);
        configs[0] = .{
            .channels = 2,
            .min_sample_rate = 8_000,
            .max_sample_rate = 192_000,
            .buffer_size = .{ .range = .{ .min = 32, .max = 8192 } },
            .sample_format = .f32,
        };
        configs[1] = .{
            .channels = 2,
            .min_sample_rate = 8_000,
            .max_sample_rate = 192_000,
            .buffer_size = .{ .range = .{ .min = 32, .max = 8192 } },
            .sample_format = .i16,
        };
        return configs;
    }

    pub fn defaultOutputConfig(self: Device) root.AudioError!root.SupportedStreamConfig {
        _ = self;
        return .{
            .channels = 2,
            .sample_rate = 48_000,
            .buffer_size = .{ .range = .{ .min = 32, .max = 8192 } },
            .sample_format = .f32,
        };
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
