const std = @import("std");
const builtin = @import("builtin");
const root = @import("../root.zig");

const c = @cImport({
    @cInclude("stdlib.h");
    @cInclude("poll.h");
    @cInclude("pthread.h");
    @cInclude("sched.h");
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

    pub fn supportsDeviceChangeSignals(self: Host) bool {
        _ = self;
        return hasControlCard();
    }

    pub fn waitForDeviceChangeSignal(
        self: Host,
        allocator: std.mem.Allocator,
        timeout_ns: u64,
    ) root.AudioError!bool {
        _ = self;
        return waitForControlDeviceChangeSignal(allocator, timeout_ns);
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
            const desc = if (desc_ptr != null) std.mem.span(desc_ptr) else null;
            try list.append(allocator, try Device.init(allocator, name, name, desc, direction));
        }

        if (list.items.len == 0) {
            try list.append(allocator, try Device.init(
                allocator,
                "default",
                "Default ALSA device",
                "ALSA default PCM",
                .unknown,
            ));
        }

        return .{ .items = try list.toOwnedSlice(allocator) };
    }

    pub fn defaultOutputDevice(self: Host, allocator: std.mem.Allocator) root.AudioError!?Device {
        _ = self;
        return try Device.init(
            allocator,
            "default",
            "Default ALSA output device",
            "ALSA default playback PCM",
            .output,
        );
    }

    pub fn defaultInputDevice(self: Host, allocator: std.mem.Allocator) root.AudioError!?Device {
        _ = self;
        return try Device.init(
            allocator,
            "default",
            "Default ALSA input device",
            "ALSA default capture PCM",
            .input,
        );
    }
};

const ControlSubscription = struct {
    handle: *c.snd_ctl_t,
    descriptor_count: usize,

    fn close(self: ControlSubscription) void {
        _ = c.snd_ctl_close(self.handle);
    }
};

fn hasControlCard() bool {
    var card: c_int = -1;
    while (c.snd_card_next(&card) >= 0 and card >= 0) {
        var name_buffer: [32]u8 = undefined;
        const name = std.fmt.bufPrintZ(&name_buffer, "hw:{d}", .{card}) catch continue;
        var handle: ?*c.snd_ctl_t = null;
        const rc = c.snd_ctl_open(&handle, name.ptr, c.SND_CTL_NONBLOCK | c.SND_CTL_READONLY);
        if (rc >= 0) {
            _ = c.snd_ctl_close(handle);
            return true;
        }
    }
    return false;
}

fn waitForControlDeviceChangeSignal(
    allocator: std.mem.Allocator,
    timeout_ns: u64,
) root.AudioError!bool {
    var subscriptions: std.ArrayList(ControlSubscription) = .empty;
    defer {
        for (subscriptions.items) |subscription| subscription.close();
        subscriptions.deinit(allocator);
    }

    try collectControlSubscriptions(allocator, &subscriptions);

    var descriptor_count: usize = 0;
    for (subscriptions.items) |subscription| {
        descriptor_count += subscription.descriptor_count;
    }
    if (controlWaitNeedsFallbackSleep(subscriptions.items.len, descriptor_count)) {
        sleepNs(timeout_ns);
        return false;
    }

    const descriptors = try allocator.alloc(c.struct_pollfd, descriptor_count);
    defer allocator.free(descriptors);

    var offset: usize = 0;
    for (subscriptions.items) |subscription| {
        const rc = c.snd_ctl_poll_descriptors(
            subscription.handle,
            descriptors[offset..].ptr,
            @intCast(subscription.descriptor_count),
        );
        if (rc < 0) return mapAlsaError(rc);
        if (@as(usize, @intCast(rc)) != subscription.descriptor_count) return root.AudioError.BackendError;
        offset += subscription.descriptor_count;
    }
    if (offset == 0) {
        sleepNs(timeout_ns);
        return false;
    }

    const poll_rc = c.poll(descriptors.ptr, @intCast(offset), timeoutNsToPollMs(timeout_ns));
    if (poll_rc == 0) return false;
    if (poll_rc < 0) {
        return switch (std.c.errno(poll_rc)) {
            .INTR => false,
            else => root.AudioError.BackendError,
        };
    }

    offset = 0;
    for (subscriptions.items) |subscription| {
        var revents: c_ushort = 0;
        const rc = c.snd_ctl_poll_descriptors_revents(
            subscription.handle,
            descriptors[offset..].ptr,
            @intCast(subscription.descriptor_count),
            &revents,
        );
        if (rc < 0) return true;
        if (controlReventsSignalDeviceChange(revents)) {
            drainControlEvents(subscription.handle);
            return true;
        }
        offset += subscription.descriptor_count;
    }

    return false;
}

fn collectControlSubscriptions(
    allocator: std.mem.Allocator,
    subscriptions: *std.ArrayList(ControlSubscription),
) root.AudioError!void {
    var card: c_int = -1;
    while (true) {
        const next_rc = c.snd_card_next(&card);
        if (next_rc < 0) return mapAlsaError(next_rc);
        if (card < 0) break;

        var name_buffer: [32]u8 = undefined;
        const name = std.fmt.bufPrintZ(&name_buffer, "hw:{d}", .{card}) catch continue;

        var handle: ?*c.snd_ctl_t = null;
        const open_rc = c.snd_ctl_open(&handle, name.ptr, c.SND_CTL_NONBLOCK | c.SND_CTL_READONLY);
        if (open_rc < 0) continue;
        var handle_owned = true;
        errdefer {
            if (handle_owned) _ = c.snd_ctl_close(handle);
        }

        const subscribe_rc = c.snd_ctl_subscribe_events(handle.?, 1);
        if (subscribe_rc < 0) {
            _ = c.snd_ctl_close(handle);
            handle_owned = false;
            continue;
        }

        const descriptor_count = c.snd_ctl_poll_descriptors_count(handle.?);
        if (descriptor_count <= 0) {
            _ = c.snd_ctl_close(handle);
            handle_owned = false;
            continue;
        }

        try subscriptions.append(allocator, .{
            .handle = handle.?,
            .descriptor_count = @intCast(descriptor_count),
        });
        handle_owned = false;
    }
}

fn controlWaitNeedsFallbackSleep(subscription_count: usize, descriptor_count: usize) bool {
    return subscription_count == 0 or descriptor_count == 0;
}

fn timeoutNsToPollMs(timeout_ns: u64) c_int {
    if (timeout_ns == 0) return 0;
    const max_ms: u64 = @intCast(std.math.maxInt(c_int));
    const rounded_ms = (timeout_ns +| (std.time.ns_per_ms - 1)) / std.time.ns_per_ms;
    return @intCast(@min(@max(rounded_ms, 1), max_ms));
}

fn controlReventsSignalDeviceChange(revents: c_ushort) bool {
    return (revents & @as(c_ushort, @intCast(c.POLLIN))) != 0 or
        (revents & @as(c_ushort, @intCast(c.POLLERR))) != 0 or
        (revents & @as(c_ushort, @intCast(c.POLLHUP))) != 0 or
        (revents & @as(c_ushort, @intCast(c.POLLNVAL))) != 0;
}

fn drainControlEvents(handle: *c.snd_ctl_t) void {
    var event: ?*c.snd_ctl_event_t = null;
    if (c.snd_ctl_event_malloc(&event) < 0) return;
    defer c.snd_ctl_event_free(event);

    var drained: usize = 0;
    while (drained < 256) : (drained += 1) {
        c.snd_ctl_event_clear(event);
        const rc = c.snd_ctl_read(handle, event);
        if (rc > 0) continue;
        if (rc == 0) return;
        if (controlReadQueueEmpty(rc)) return;
        return;
    }
}

fn controlReadQueueEmpty(rc: c_int) bool {
    return rc == -c.EAGAIN or rc == -c.EINTR;
}

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
    description_text: ?[]const u8,
    direction: root.DeviceDirection,

    pub fn init(
        allocator: std.mem.Allocator,
        id_text: []const u8,
        name_text: []const u8,
        description_text: ?[]const u8,
        direction: root.DeviceDirection,
    ) root.AudioError!Device {
        const normalized_description = if (description_text) |description| normalizeDescription(description) else null;
        return .{
            .id_text = try allocator.dupeZ(u8, id_text),
            .name_text = try allocator.dupe(u8, normalizeDescription(name_text)),
            .description_text = if (normalized_description) |description|
                try allocator.dupe(u8, description)
            else
                null,
            .direction = direction,
        };
    }

    pub fn deinit(self: *Device, allocator: std.mem.Allocator) void {
        allocator.free(self.id_text);
        allocator.free(self.name_text);
        if (self.description_text) |description| allocator.free(description);
    }

    pub fn info(self: Device) root.DeviceInfo {
        return .{
            .host = .alsa,
            .id = self.id_text,
            .name = self.name_text,
            .description = self.description_text,
            .direction = self.direction,
        };
    }

    pub fn isAvailable(self: Device) bool {
        return switch (self.direction) {
            .output => deviceDirectionIsAvailable(
                self.direction,
                self.canOpen(c.SND_PCM_STREAM_PLAYBACK),
                false,
            ),
            .input => deviceDirectionIsAvailable(
                self.direction,
                false,
                self.canOpen(c.SND_PCM_STREAM_CAPTURE),
            ),
            .duplex => deviceDirectionIsAvailable(
                self.direction,
                self.canOpen(c.SND_PCM_STREAM_PLAYBACK),
                self.canOpen(c.SND_PCM_STREAM_CAPTURE),
            ),
            .unknown => self.canOpen(c.SND_PCM_STREAM_PLAYBACK) or
                self.canOpen(c.SND_PCM_STREAM_CAPTURE),
        };
    }

    fn canOpen(self: Device, stream_type: c.snd_pcm_stream_t) bool {
        const handle = self.openProbePcm(stream_type) catch |err| return probeOpenErrorMeansAvailable(err);
        _ = c.snd_pcm_close(handle);
        return true;
    }

    fn openProbePcm(self: Device, stream_type: c.snd_pcm_stream_t) root.AudioError!*c.snd_pcm_t {
        if (isKnownNoisyAvailabilityProbe(self.id_text)) return root.AudioError.DeviceNotAvailable;
        var handle: ?*c.snd_pcm_t = null;
        const previous_handler = c.snd_lib_error;
        _ = c.snd_lib_error_set_handler(quietAlsaErrorHandler);
        defer _ = c.snd_lib_error_set_handler(previous_handler);

        const rc = c.snd_pcm_open(&handle, self.id_text.ptr, stream_type, c.SND_PCM_NONBLOCK);
        if (rc < 0) return mapAlsaError(rc);
        return handle.?;
    }

    pub fn supportedOutputConfigs(
        self: Device,
        allocator: std.mem.Allocator,
    ) root.AudioError![]root.SupportedStreamConfigRange {
        if (!self.direction.supportsOutput()) return root.AudioError.UnsupportedOperation;
        return self.supportedConfigs(allocator, c.SND_PCM_STREAM_PLAYBACK, .output);
    }

    pub fn supportedInputConfigs(
        self: Device,
        allocator: std.mem.Allocator,
    ) root.AudioError![]root.SupportedStreamConfigRange {
        if (!self.direction.supportsInput()) return root.AudioError.UnsupportedOperation;
        return self.supportedConfigs(allocator, c.SND_PCM_STREAM_CAPTURE, .input);
    }

    pub fn supportedOutputCapabilities(
        self: Device,
        allocator: std.mem.Allocator,
    ) root.AudioError![]root.StreamCapability {
        if (!self.direction.supportsOutput()) return root.AudioError.UnsupportedOperation;
        return self.supportedCapabilities(allocator, c.SND_PCM_STREAM_PLAYBACK, .output);
    }

    pub fn supportedInputCapabilities(
        self: Device,
        allocator: std.mem.Allocator,
    ) root.AudioError![]root.StreamCapability {
        if (!self.direction.supportsInput()) return root.AudioError.UnsupportedOperation;
        return self.supportedCapabilities(allocator, c.SND_PCM_STREAM_CAPTURE, .input);
    }

    fn supportedConfigs(
        self: Device,
        allocator: std.mem.Allocator,
        stream_type: c.snd_pcm_stream_t,
        direction: root.StreamCapabilityDirection,
    ) root.AudioError![]root.SupportedStreamConfigRange {
        const capabilities = try self.supportedCapabilities(allocator, stream_type, direction);
        defer allocator.free(capabilities);
        const configs = try allocator.alloc(root.SupportedStreamConfigRange, capabilities.len);
        for (capabilities, 0..) |capability, index| {
            configs[index] = capability.representativeConfigRange();
        }
        return configs;
    }

    fn supportedCapabilities(
        self: Device,
        allocator: std.mem.Allocator,
        stream_type: c.snd_pcm_stream_t,
        direction: root.StreamCapabilityDirection,
    ) root.AudioError![]root.StreamCapability {
        const handle = try self.openProbePcm(stream_type);
        defer _ = c.snd_pcm_close(handle);

        var capabilities: std.ArrayList(root.StreamCapability) = .empty;
        errdefer capabilities.deinit(allocator);

        for (buildableAlsaFormats()) |format| {
            try appendProbedCapability(
                allocator,
                &capabilities,
                handle,
                direction,
                format.sample_format,
                format.alsa_format,
            );
        }

        return capabilities.toOwnedSlice(allocator);
    }

    pub fn defaultOutputConfig(self: Device) root.AudioError!root.SupportedStreamConfig {
        const allocator = std.heap.c_allocator;
        const configs = try self.supportedOutputConfigs(allocator);
        defer allocator.free(configs);
        if (configs.len == 0) return root.AudioError.UnsupportedConfig;
        return preferredDefaultConfigRange(configs).withStandardSampleRate();
    }

    pub fn defaultInputConfig(self: Device) root.AudioError!root.SupportedStreamConfig {
        const allocator = std.heap.c_allocator;
        const configs = try self.supportedInputConfigs(allocator);
        defer allocator.free(configs);
        if (configs.len == 0) return root.AudioError.UnsupportedConfig;
        return preferredDefaultConfigRange(configs).withStandardSampleRate();
    }

    pub fn buildOutputStreamF32(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.OutputCallbackF32,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        try config_value.validate();
        if (!self.direction.supportsOutput()) return root.AudioError.UnsupportedOperation;

        const handle = try openConfiguredPcm(self.id_text, c.SND_PCM_STREAM_PLAYBACK, config_value, .f32);
        errdefer _ = c.snd_pcm_close(handle);
        return .{
            .handle = handle,
            .direction = .output,
            .sample_format = .f32,
            .config = config_value,
            .callback = .{ .output_f32 = callback },
            .userdata = userdata,
            .error_callback = error_callback,
            .error_userdata = error_userdata,
            .buffer_size_frames = queryPeriodSize(handle) catch null,
        };
    }

    pub fn buildInputStreamF32(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.InputCallbackF32,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        try config_value.validate();
        if (!self.direction.supportsInput()) return root.AudioError.UnsupportedOperation;

        const handle = try openConfiguredPcm(self.id_text, c.SND_PCM_STREAM_CAPTURE, config_value, .f32);
        errdefer _ = c.snd_pcm_close(handle);
        return .{
            .handle = handle,
            .direction = .input,
            .sample_format = .f32,
            .config = config_value,
            .callback = .{ .input_f32 = callback },
            .userdata = userdata,
            .error_callback = error_callback,
            .error_userdata = error_userdata,
            .buffer_size_frames = queryPeriodSize(handle) catch null,
        };
    }

    pub fn buildOutputStreamI8(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.OutputCallbackI8,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        try config_value.validate();
        if (!self.direction.supportsOutput()) return root.AudioError.UnsupportedOperation;

        const handle = try openConfiguredPcm(self.id_text, c.SND_PCM_STREAM_PLAYBACK, config_value, .i8);
        errdefer _ = c.snd_pcm_close(handle);
        return .{
            .handle = handle,
            .direction = .output,
            .sample_format = .i8,
            .config = config_value,
            .callback = .{ .output_i8 = callback },
            .userdata = userdata,
            .error_callback = error_callback,
            .error_userdata = error_userdata,
            .buffer_size_frames = queryPeriodSize(handle) catch null,
        };
    }

    pub fn buildInputStreamI8(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.InputCallbackI8,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        try config_value.validate();
        if (!self.direction.supportsInput()) return root.AudioError.UnsupportedOperation;

        const handle = try openConfiguredPcm(self.id_text, c.SND_PCM_STREAM_CAPTURE, config_value, .i8);
        errdefer _ = c.snd_pcm_close(handle);
        return .{
            .handle = handle,
            .direction = .input,
            .sample_format = .i8,
            .config = config_value,
            .callback = .{ .input_i8 = callback },
            .userdata = userdata,
            .error_callback = error_callback,
            .error_userdata = error_userdata,
            .buffer_size_frames = queryPeriodSize(handle) catch null,
        };
    }

    pub fn buildOutputStreamU8(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.OutputCallbackU8,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        try config_value.validate();
        if (!self.direction.supportsOutput()) return root.AudioError.UnsupportedOperation;

        const handle = try openConfiguredPcm(self.id_text, c.SND_PCM_STREAM_PLAYBACK, config_value, .u8);
        errdefer _ = c.snd_pcm_close(handle);
        return .{
            .handle = handle,
            .direction = .output,
            .sample_format = .u8,
            .config = config_value,
            .callback = .{ .output_u8 = callback },
            .userdata = userdata,
            .error_callback = error_callback,
            .error_userdata = error_userdata,
            .buffer_size_frames = queryPeriodSize(handle) catch null,
        };
    }

    pub fn buildInputStreamU8(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.InputCallbackU8,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        try config_value.validate();
        if (!self.direction.supportsInput()) return root.AudioError.UnsupportedOperation;

        const handle = try openConfiguredPcm(self.id_text, c.SND_PCM_STREAM_CAPTURE, config_value, .u8);
        errdefer _ = c.snd_pcm_close(handle);
        return .{
            .handle = handle,
            .direction = .input,
            .sample_format = .u8,
            .config = config_value,
            .callback = .{ .input_u8 = callback },
            .userdata = userdata,
            .error_callback = error_callback,
            .error_userdata = error_userdata,
            .buffer_size_frames = queryPeriodSize(handle) catch null,
        };
    }

    pub fn buildOutputStreamI16(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.OutputCallbackI16,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        try config_value.validate();
        if (!self.direction.supportsOutput()) return root.AudioError.UnsupportedOperation;

        const handle = try openConfiguredPcm(self.id_text, c.SND_PCM_STREAM_PLAYBACK, config_value, .i16);
        errdefer _ = c.snd_pcm_close(handle);
        return .{
            .handle = handle,
            .direction = .output,
            .sample_format = .i16,
            .config = config_value,
            .callback = .{ .output_i16 = callback },
            .userdata = userdata,
            .error_callback = error_callback,
            .error_userdata = error_userdata,
            .buffer_size_frames = queryPeriodSize(handle) catch null,
        };
    }

    pub fn buildInputStreamI16(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.InputCallbackI16,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        try config_value.validate();
        if (!self.direction.supportsInput()) return root.AudioError.UnsupportedOperation;

        const handle = try openConfiguredPcm(self.id_text, c.SND_PCM_STREAM_CAPTURE, config_value, .i16);
        errdefer _ = c.snd_pcm_close(handle);
        return .{
            .handle = handle,
            .direction = .input,
            .sample_format = .i16,
            .config = config_value,
            .callback = .{ .input_i16 = callback },
            .userdata = userdata,
            .error_callback = error_callback,
            .error_userdata = error_userdata,
            .buffer_size_frames = queryPeriodSize(handle) catch null,
        };
    }

    pub fn buildOutputStreamU16(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.OutputCallbackU16,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        try config_value.validate();
        if (!self.direction.supportsOutput()) return root.AudioError.UnsupportedOperation;

        const handle = try openConfiguredPcm(self.id_text, c.SND_PCM_STREAM_PLAYBACK, config_value, .u16);
        errdefer _ = c.snd_pcm_close(handle);
        return .{
            .handle = handle,
            .direction = .output,
            .sample_format = .u16,
            .config = config_value,
            .callback = .{ .output_u16 = callback },
            .userdata = userdata,
            .error_callback = error_callback,
            .error_userdata = error_userdata,
            .buffer_size_frames = queryPeriodSize(handle) catch null,
        };
    }

    pub fn buildInputStreamU16(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.InputCallbackU16,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        try config_value.validate();
        if (!self.direction.supportsInput()) return root.AudioError.UnsupportedOperation;

        const handle = try openConfiguredPcm(self.id_text, c.SND_PCM_STREAM_CAPTURE, config_value, .u16);
        errdefer _ = c.snd_pcm_close(handle);
        return .{
            .handle = handle,
            .direction = .input,
            .sample_format = .u16,
            .config = config_value,
            .callback = .{ .input_u16 = callback },
            .userdata = userdata,
            .error_callback = error_callback,
            .error_userdata = error_userdata,
            .buffer_size_frames = queryPeriodSize(handle) catch null,
        };
    }

    pub fn buildOutputStreamI32(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.OutputCallbackI32,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        try config_value.validate();
        if (!self.direction.supportsOutput()) return root.AudioError.UnsupportedOperation;

        const handle = try openConfiguredPcm(self.id_text, c.SND_PCM_STREAM_PLAYBACK, config_value, .i32);
        errdefer _ = c.snd_pcm_close(handle);
        return .{
            .handle = handle,
            .direction = .output,
            .sample_format = .i32,
            .config = config_value,
            .callback = .{ .output_i32 = callback },
            .userdata = userdata,
            .error_callback = error_callback,
            .error_userdata = error_userdata,
            .buffer_size_frames = queryPeriodSize(handle) catch null,
        };
    }

    pub fn buildInputStreamI32(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.InputCallbackI32,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        try config_value.validate();
        if (!self.direction.supportsInput()) return root.AudioError.UnsupportedOperation;

        const handle = try openConfiguredPcm(self.id_text, c.SND_PCM_STREAM_CAPTURE, config_value, .i32);
        errdefer _ = c.snd_pcm_close(handle);
        return .{
            .handle = handle,
            .direction = .input,
            .sample_format = .i32,
            .config = config_value,
            .callback = .{ .input_i32 = callback },
            .userdata = userdata,
            .error_callback = error_callback,
            .error_userdata = error_userdata,
            .buffer_size_frames = queryPeriodSize(handle) catch null,
        };
    }

    pub fn buildOutputStreamU32(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.OutputCallbackU32,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        try config_value.validate();
        if (!self.direction.supportsOutput()) return root.AudioError.UnsupportedOperation;

        const handle = try openConfiguredPcm(self.id_text, c.SND_PCM_STREAM_PLAYBACK, config_value, .u32);
        errdefer _ = c.snd_pcm_close(handle);
        return .{
            .handle = handle,
            .direction = .output,
            .sample_format = .u32,
            .config = config_value,
            .callback = .{ .output_u32 = callback },
            .userdata = userdata,
            .error_callback = error_callback,
            .error_userdata = error_userdata,
            .buffer_size_frames = queryPeriodSize(handle) catch null,
        };
    }

    pub fn buildInputStreamU32(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.InputCallbackU32,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        try config_value.validate();
        if (!self.direction.supportsInput()) return root.AudioError.UnsupportedOperation;

        const handle = try openConfiguredPcm(self.id_text, c.SND_PCM_STREAM_CAPTURE, config_value, .u32);
        errdefer _ = c.snd_pcm_close(handle);
        return .{
            .handle = handle,
            .direction = .input,
            .sample_format = .u32,
            .config = config_value,
            .callback = .{ .input_u32 = callback },
            .userdata = userdata,
            .error_callback = error_callback,
            .error_userdata = error_userdata,
            .buffer_size_frames = queryPeriodSize(handle) catch null,
        };
    }

    pub fn buildOutputStreamF64(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.OutputCallbackF64,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        try config_value.validate();
        if (!self.direction.supportsOutput()) return root.AudioError.UnsupportedOperation;

        const handle = try openConfiguredPcm(self.id_text, c.SND_PCM_STREAM_PLAYBACK, config_value, .f64);
        errdefer _ = c.snd_pcm_close(handle);
        return .{
            .handle = handle,
            .direction = .output,
            .sample_format = .f64,
            .config = config_value,
            .callback = .{ .output_f64 = callback },
            .userdata = userdata,
            .error_callback = error_callback,
            .error_userdata = error_userdata,
            .buffer_size_frames = queryPeriodSize(handle) catch null,
        };
    }

    pub fn buildInputStreamF64(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.InputCallbackF64,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        try config_value.validate();
        if (!self.direction.supportsInput()) return root.AudioError.UnsupportedOperation;

        const handle = try openConfiguredPcm(self.id_text, c.SND_PCM_STREAM_CAPTURE, config_value, .f64);
        errdefer _ = c.snd_pcm_close(handle);
        return .{
            .handle = handle,
            .direction = .input,
            .sample_format = .f64,
            .config = config_value,
            .callback = .{ .input_f64 = callback },
            .userdata = userdata,
            .error_callback = error_callback,
            .error_userdata = error_userdata,
            .buffer_size_frames = queryPeriodSize(handle) catch null,
        };
    }
};

fn openConfiguredPcm(
    id_text: [:0]const u8,
    stream_type: c.snd_pcm_stream_t,
    config_value: root.StreamConfig,
    sample_format: root.SampleFormat,
) root.AudioError!*c.snd_pcm_t {
    var handle: ?*c.snd_pcm_t = null;
    const rc = c.snd_pcm_open(&handle, id_text.ptr, stream_type, streamPcmOpenMode());
    if (rc < 0) return mapAlsaError(rc);
    errdefer _ = c.snd_pcm_close(handle);

    try configurePcmParams(
        handle.?,
        stream_type,
        config_value,
        alsaFormat(sample_format) orelse return root.AudioError.UnsupportedConfig,
    );

    return handle.?;
}

fn streamPcmOpenMode() c_int {
    return c.SND_PCM_NONBLOCK;
}

fn configurePcmParams(
    handle: *c.snd_pcm_t,
    stream_type: c.snd_pcm_stream_t,
    config_value: root.StreamConfig,
    format: c.snd_pcm_format_t,
) root.AudioError!void {
    var params: ?*c.snd_pcm_hw_params_t = null;
    var rc = c.snd_pcm_hw_params_malloc(&params);
    if (rc < 0) return mapAlsaError(rc);
    defer c.snd_pcm_hw_params_free(params);

    rc = c.snd_pcm_hw_params_any(handle, params);
    if (rc < 0) return mapAlsaError(rc);

    rc = c.snd_pcm_hw_params_set_access(handle, params, c.SND_PCM_ACCESS_RW_INTERLEAVED);
    if (rc < 0) return mapAlsaError(rc);

    rc = c.snd_pcm_hw_params_set_format(handle, params, format);
    if (rc < 0) return root.AudioError.UnsupportedConfig;

    rc = c.snd_pcm_hw_params_set_channels(handle, params, config_value.channels);
    if (rc < 0) return root.AudioError.UnsupportedConfig;

    var rate: c_uint = config_value.sample_rate;
    var dir: c_int = 0;
    rc = c.snd_pcm_hw_params_set_rate_near(handle, params, &rate, &dir);
    if (rc < 0) return mapAlsaError(rc);
    if (rate != config_value.sample_rate) return root.AudioError.UnsupportedConfig;

    var period_size = requestedPeriodFrames(config_value);
    dir = 0;
    rc = c.snd_pcm_hw_params_set_period_size_near(handle, params, &period_size, &dir);
    if (rc < 0) return mapAlsaError(rc);
    if (!fixedPeriodRequestMatches(config_value, period_size)) return root.AudioError.UnsupportedConfig;

    var buffer_size = requestedTotalBufferFrames(config_value, period_size);
    rc = c.snd_pcm_hw_params_set_buffer_size_near(handle, params, &buffer_size);
    if (rc < 0) return mapAlsaError(rc);
    if (!fixedTotalBufferRequestMatches(config_value, buffer_size)) return root.AudioError.UnsupportedConfig;

    rc = c.snd_pcm_hw_params(handle, params);
    if (rc < 0) return mapAlsaError(rc);

    const sizes = try queryBufferPeriodSizes(handle);
    try verifyCommittedBufferPeriodSizes(config_value, sizes);
    try configurePcmSoftwareParams(handle, stream_type, sizes);
}

fn requestedPeriodFrames(config_value: root.StreamConfig) c.snd_pcm_uframes_t {
    return switch (config_value.buffer_size) {
        .fixed => |frames| @intCast(frames),
        .default => defaultPeriodFrames(config_value.sample_rate),
    };
}

fn requestedTotalBufferFrames(
    config_value: root.StreamConfig,
    period_size: c.snd_pcm_uframes_t,
) c.snd_pcm_uframes_t {
    return switch (config_value.total_buffer_size) {
        .fixed => |frames| @intCast(frames),
        .default => @max(period_size *| 4, period_size),
    };
}

fn defaultPeriodFrames(sample_rate: u32) c.snd_pcm_uframes_t {
    const target = @max(sample_rate / 100, 1);
    return @intCast(std.math.clamp(target, 64, 2048));
}

fn fixedPeriodRequestMatches(
    config_value: root.StreamConfig,
    actual_period: c.snd_pcm_uframes_t,
) bool {
    return switch (config_value.buffer_size) {
        .default => true,
        .fixed => |frames| actual_period == frames,
    };
}

fn fixedTotalBufferRequestMatches(
    config_value: root.StreamConfig,
    actual_buffer: c.snd_pcm_uframes_t,
) bool {
    return switch (config_value.total_buffer_size) {
        .default => true,
        .fixed => |frames| actual_buffer == frames,
    };
}

fn verifyCommittedBufferPeriodSizes(
    config_value: root.StreamConfig,
    sizes: BufferPeriodSizes,
) root.AudioError!void {
    if (!fixedPeriodRequestMatches(config_value, sizes.period_size_frames)) {
        return root.AudioError.UnsupportedConfig;
    }
    if (!fixedTotalBufferRequestMatches(config_value, sizes.buffer_size_frames)) {
        return root.AudioError.UnsupportedConfig;
    }
}

fn configurePcmSoftwareParams(
    handle: *c.snd_pcm_t,
    stream_type: c.snd_pcm_stream_t,
    sizes: BufferPeriodSizes,
) root.AudioError!void {
    var params: ?*c.snd_pcm_sw_params_t = null;
    var rc = c.snd_pcm_sw_params_malloc(&params);
    if (rc < 0) return mapAlsaError(rc);
    defer c.snd_pcm_sw_params_free(params);

    rc = c.snd_pcm_sw_params_current(handle, params);
    if (rc < 0) return mapAlsaError(rc);

    const period_size: c.snd_pcm_uframes_t = @max(sizes.period_size_frames, 1);
    rc = c.snd_pcm_sw_params_set_avail_min(handle, params, period_size);
    if (rc < 0) return mapAlsaError(rc);

    if (stream_type == c.SND_PCM_STREAM_PLAYBACK) {
        rc = c.snd_pcm_sw_params_set_start_threshold(handle, params, period_size);
        if (rc < 0) return mapAlsaError(rc);
    }

    configurePcmTimestampParams(handle, params);

    rc = c.snd_pcm_sw_params(handle, params);
    if (rc < 0) return mapAlsaError(rc);
}

fn configurePcmTimestampParams(
    handle: *c.snd_pcm_t,
    params: ?*c.snd_pcm_sw_params_t,
) void {
    var rc = c.snd_pcm_sw_params_set_tstamp_mode(handle, params, c.SND_PCM_TSTAMP_ENABLE);
    if (rc < 0) return;

    rc = c.snd_pcm_sw_params_set_tstamp_type(handle, params, c.SND_PCM_TSTAMP_TYPE_MONOTONIC);
    if (rc < 0) {
        _ = c.snd_pcm_sw_params_set_tstamp_type(handle, params, c.SND_PCM_TSTAMP_TYPE_MONOTONIC_RAW);
    }
}

const AlsaSampleFormat = struct {
    sample_format: root.SampleFormat,
    alsa_format: c.snd_pcm_format_t,
};

const buildable_alsa_formats = [_]AlsaSampleFormat{
    .{ .sample_format = .f32, .alsa_format = c.SND_PCM_FORMAT_FLOAT_LE },
    .{ .sample_format = .i8, .alsa_format = c.SND_PCM_FORMAT_S8 },
    .{ .sample_format = .u8, .alsa_format = c.SND_PCM_FORMAT_U8 },
    .{ .sample_format = .i16, .alsa_format = c.SND_PCM_FORMAT_S16_LE },
    .{ .sample_format = .u16, .alsa_format = c.SND_PCM_FORMAT_U16_LE },
    .{ .sample_format = .i32, .alsa_format = c.SND_PCM_FORMAT_S32_LE },
    .{ .sample_format = .u32, .alsa_format = c.SND_PCM_FORMAT_U32_LE },
    .{ .sample_format = .f64, .alsa_format = c.SND_PCM_FORMAT_FLOAT64_LE },
};

fn buildableAlsaFormats() []const AlsaSampleFormat {
    return &buildable_alsa_formats;
}

fn alsaFormat(sample_format: root.SampleFormat) ?c.snd_pcm_format_t {
    for (buildableAlsaFormats()) |format| {
        if (format.sample_format == sample_format) return format.alsa_format;
    }
    return null;
}

fn alsaStreamBackendState(state: c.snd_pcm_state_t) root.StreamBackendState {
    return switch (state) {
        c.SND_PCM_STATE_OPEN => .open,
        c.SND_PCM_STATE_SETUP => .setup,
        c.SND_PCM_STATE_PREPARED => .prepared,
        c.SND_PCM_STATE_RUNNING => .running,
        c.SND_PCM_STATE_XRUN => .xrun,
        c.SND_PCM_STATE_DRAINING => .draining,
        c.SND_PCM_STATE_PAUSED => .paused,
        c.SND_PCM_STATE_SUSPENDED => .suspended,
        c.SND_PCM_STATE_DISCONNECTED => .disconnected,
        c.SND_PCM_STATE_PRIVATE1 => .private,
        else => .unknown,
    };
}

fn runStatusForBackendState(backend_state: root.StreamBackendState) ?root.StreamRunStatus {
    return switch (backend_state) {
        .xrun => .xrun,
        .suspended => .stream_suspended,
        .disconnected => .stream_invalidated,
        else => null,
    };
}

fn reconciledRunStatusForBackendState(
    backend_state: root.StreamBackendState,
    running: bool,
    current: root.StreamRunStatus,
) root.StreamRunStatus {
    if (runStatusForBackendState(backend_state)) |terminal_status| return terminal_status;
    if (backendStateClearsXrunObservation(backend_state)) {
        return if (running) .running else .stopped;
    }
    return current;
}

const ObservedBackendError = enum(u8) {
    none,
    xrun,
    suspended,
    invalidated,
};

fn observedBackendErrorForBackendState(backend_state: root.StreamBackendState) ?ObservedBackendError {
    return switch (backend_state) {
        .xrun => .xrun,
        .suspended => .suspended,
        .disconnected => .invalidated,
        else => null,
    };
}

fn observedBackendErrorForAudioError(err: root.AudioError) ?ObservedBackendError {
    return switch (err) {
        root.AudioError.Xrun => .xrun,
        root.AudioError.StreamSuspended => .suspended,
        root.AudioError.StreamInvalidated => .invalidated,
        else => null,
    };
}

fn audioErrorForObservedBackendError(observed: ObservedBackendError) ?root.AudioError {
    return switch (observed) {
        .xrun => root.AudioError.Xrun,
        .suspended => root.AudioError.StreamSuspended,
        .invalidated => root.AudioError.StreamInvalidated,
        .none => null,
    };
}

fn backendStateClearsXrunObservation(backend_state: root.StreamBackendState) bool {
    return switch (backend_state) {
        .open,
        .setup,
        .prepared,
        .running,
        .draining,
        .paused,
        => true,
        .unavailable,
        .xrun,
        .suspended,
        .disconnected,
        .private,
        .unknown,
        => false,
    };
}

fn isTerminalRunStatus(run_status_value: root.StreamRunStatus) bool {
    return switch (run_status_value) {
        .backend_unavailable,
        .backend_error,
        .device_not_available,
        .invalid_input,
        .out_of_memory,
        .permission_denied,
        .resource_exhausted,
        .stream_invalidated,
        .stream_suspended,
        .unsupported_config,
        .unsupported_operation,
        .xrun,
        => true,
        .stopped,
        .running,
        .device_busy,
        => false,
    };
}

fn appendProbedCapability(
    allocator: std.mem.Allocator,
    capabilities: *std.ArrayList(root.StreamCapability),
    handle: ?*c.snd_pcm_t,
    direction: root.StreamCapabilityDirection,
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
    const buffer_range = try probedBufferSizeRange(params);

    try capabilities.append(allocator, .{
        .direction = direction,
        .sample_format = sample_format,
        .channels = .{
            .min = @intCast(@min(channel_range.min, std.math.maxInt(u16))),
            .max = @intCast(@min(channel_range.max, std.math.maxInt(u16))),
        },
        .min_sample_rate = rate_range.min,
        .max_sample_rate = rate_range.max,
        .buffer_size = .{ .range = .{
            .min = period_range.min,
            .max = period_range.max,
        } },
        .total_buffer_size = .{ .range = .{
            .min = buffer_range.min,
            .max = buffer_range.max,
        } },
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

fn probedBufferSizeRange(params: ?*c.snd_pcm_hw_params_t) root.AudioError!UIntRange {
    var min: c.snd_pcm_uframes_t = 0;
    var max: c.snd_pcm_uframes_t = 0;
    var rc = c.snd_pcm_hw_params_get_buffer_size_min(params, &min);
    if (rc < 0) return mapAlsaError(rc);
    rc = c.snd_pcm_hw_params_get_buffer_size_max(params, &max);
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

fn preferredDefaultConfigRange(configs: []const root.SupportedStreamConfigRange) root.SupportedStreamConfigRange {
    for (root.defaultSampleFormatPreferences()) |sample_format| {
        if (findFormat(configs, sample_format)) |config_range| return config_range;
    }
    return configs[0];
}

fn callbackSampleCount(frames: usize, channels: u16) root.AudioError!usize {
    if (channels == 0) return root.AudioError.InvalidInput;
    return std.math.mul(usize, frames, @as(usize, channels)) catch root.AudioError.ResourceExhausted;
}

pub const Stream = struct {
    handle: *c.snd_pcm_t,
    direction: root.DeviceDirection,
    sample_format: root.SampleFormat,
    config: root.StreamConfig,
    callback: union(enum) {
        output_f32: root.OutputCallbackF32,
        input_f32: root.InputCallbackF32,
        output_i8: root.OutputCallbackI8,
        input_i8: root.InputCallbackI8,
        output_u8: root.OutputCallbackU8,
        input_u8: root.InputCallbackU8,
        output_i16: root.OutputCallbackI16,
        input_i16: root.InputCallbackI16,
        output_u16: root.OutputCallbackU16,
        input_u16: root.InputCallbackU16,
        output_i32: root.OutputCallbackI32,
        input_i32: root.InputCallbackI32,
        output_u32: root.OutputCallbackU32,
        input_u32: root.InputCallbackU32,
        output_f64: root.OutputCallbackF64,
        input_f64: root.InputCallbackF64,
    },
    userdata: ?*anyopaque,
    error_callback: ?root.StreamErrorCallback,
    error_userdata: ?*anyopaque,
    buffer_size_frames: ?u32,
    thread: ?std.Thread = null,
    running: std.atomic.Value(bool) = .init(false),
    run_status: std.atomic.Value(u8) = .init(@intFromEnum(root.StreamRunStatus.stopped)),
    scheduling_status: std.atomic.Value(u8) = .init(@intFromEnum(root.ThreadSchedulingStatus.not_requested)),
    callback_count: std.atomic.Value(u64) = .init(0),
    stream_error_count: std.atomic.Value(u64) = .init(0),
    observed_backend_error: std.atomic.Value(u8) = .init(@intFromEnum(ObservedBackendError.none)),
    xrun_count: std.atomic.Value(u64) = .init(0),
    xrun_observed: std.atomic.Value(bool) = .init(false),
    recovery_count: std.atomic.Value(u64) = .init(0),
    last_callback_ns: std.atomic.Value(u64) = .init(0),
    last_callback_interval_ns: std.atomic.Value(u64) = .init(0),
    last_callback_drift_ns: std.atomic.Value(i64) = .init(0),

    pub fn play(self: *Stream) root.AudioError!void {
        if (self.running.load(.seq_cst)) return;
        self.joinStoppedWorker();
        if (self.running.swap(true, .seq_cst)) return;
        const prepare_rc = c.snd_pcm_prepare(self.handle);
        if (prepare_rc < 0) {
            const err = mapAlsaError(prepare_rc);
            self.running.store(false, .seq_cst);
            self.storeRunStatus(root.runStatusFromAudioError(err));
            return err;
        }
        self.resetCallbackTiming();
        self.clearXrunObservation();
        self.clearObservedBackendError();
        self.thread = std.Thread.spawn(.{}, run, .{self}) catch |err| switch (err) {
            error.OutOfMemory => {
                self.running.store(false, .seq_cst);
                self.storeRunStatus(.out_of_memory);
                return root.AudioError.OutOfMemory;
            },
            error.SystemResources, error.ThreadQuotaExceeded, error.LockedMemoryLimitExceeded => {
                self.running.store(false, .seq_cst);
                self.storeRunStatus(.resource_exhausted);
                return root.AudioError.ResourceExhausted;
            },
            else => {
                self.running.store(false, .seq_cst);
                self.storeRunStatus(.backend_error);
                return root.AudioError.BackendError;
            },
        };
        self.storeRunStatus(.running);
    }

    pub fn isRunning(self: *Stream) bool {
        return self.running.load(.seq_cst);
    }

    pub fn status(self: *Stream) root.StreamRunStatus {
        return self.loadRunStatus();
    }

    pub fn pause(self: *Stream) root.AudioError!void {
        self.stopWorker();
        const rc = c.snd_pcm_drop(self.handle);
        if (rc < 0) {
            const err = mapAlsaError(rc);
            self.storeRunStatus(root.runStatusFromAudioError(err));
            return err;
        }
        self.storeStoppedUnlessTerminal();
    }

    pub fn drain(self: *Stream) root.AudioError!void {
        self.stopWorker();
        switch (self.direction) {
            .output => self.drainOutputPcm() catch |err| {
                self.storeRunStatus(root.runStatusFromAudioError(err));
                return err;
            },
            .input, .duplex, .unknown => {
                const rc = c.snd_pcm_drop(self.handle);
                if (rc < 0) {
                    const err = mapAlsaError(rc);
                    self.storeRunStatus(root.runStatusFromAudioError(err));
                    return err;
                }
            },
        }
        self.storeStoppedUnlessTerminal();
    }

    fn stopWorker(self: *Stream) void {
        self.running.store(false, .seq_cst);
        if (self.thread) |thread| {
            thread.join();
            self.thread = null;
        }
    }

    fn joinStoppedWorker(self: *Stream) void {
        if (self.running.load(.seq_cst)) return;
        if (self.thread) |thread| {
            thread.join();
            self.thread = null;
        }
    }

    pub fn bufferSize(self: *Stream) root.AudioError!u32 {
        if (self.buffer_size_frames) |frames| return frames;
        return queryPeriodSize(self.handle);
    }

    pub fn diagnostics(self: *Stream) root.AudioError!root.StreamDiagnostics {
        const status_snapshot = queryPcmStatusSnapshot(self.handle);

        var delay_frames: c.snd_pcm_sframes_t = 0;
        const delay_rc = c.snd_pcm_delay(self.handle, &delay_frames);
        const delay_value: ?i64 = if (status_snapshot) |snapshot|
            snapshot.delay_frames
        else if (delay_rc < 0)
            null
        else
            @intCast(delay_frames);

        const available = c.snd_pcm_avail(self.handle);
        const available_value: ?u32 = if (status_snapshot) |snapshot|
            snapshot.available_frames
        else if (available < 0)
            null
        else
            clampToU32(available);

        var timestamp_status: root.LatencyStatus = .measured;
        const timestamp = streamTimestampStatus(self.handle, &timestamp_status);
        const latency_status: root.LatencyStatus = if (delay_value != null or available_value != null)
            timestamp_status
        else
            .unavailable;
        const buffer_period_sizes = queryBufferPeriodSizes(self.handle) catch null;
        const backend_state = alsaStreamBackendState(c.snd_pcm_state(self.handle));
        self.syncXrunObservationForBackendState(backend_state);
        self.syncStreamErrorObservationForBackendState(backend_state);
        const run_status = self.refreshRunStatusForBackendState(backend_state);

        return .{
            .timestamp = timestamp,
            .run_status = run_status,
            .backend_state = backend_state,
            .buffer_size_frames = if (buffer_period_sizes) |sizes| sizes.buffer_size_frames else null,
            .period_size_frames = if (buffer_period_sizes) |sizes| sizes.period_size_frames else null,
            .available_frames = available_value,
            .available_max_frames = if (status_snapshot) |snapshot| snapshot.available_max_frames else null,
            .available_duration_ns = if (available_value) |frames|
                root.framesToUnsignedDurationNs(frames, self.config.sample_rate)
            else
                null,
            .delay_frames = delay_value,
            .delay_duration_ns = if (delay_value) |frames|
                root.framesToDurationNs(frames, self.config.sample_rate)
            else
                null,
            .latency_duration_ns = if (delay_value) |frames|
                root.nonNegativeFramesToDurationNs(frames, self.config.sample_rate)
            else
                null,
            .overrange_frames = if (status_snapshot) |snapshot| snapshot.overrange_frames else null,
            .latency_status = latency_status,
            .scheduling_status = self.loadSchedulingStatus(),
            .callback_count = self.callback_count.load(.seq_cst),
            .stream_error_count = self.stream_error_count.load(.seq_cst),
            .xrun_count = self.xrun_count.load(.seq_cst),
            .recovery_count = self.recovery_count.load(.seq_cst),
            .last_callback_interval_ns = if (self.callback_count.load(.seq_cst) > 1)
                self.last_callback_interval_ns.load(.seq_cst)
            else
                null,
            .last_callback_drift_ns = if (self.callback_count.load(.seq_cst) > 1)
                self.last_callback_drift_ns.load(.seq_cst)
            else
                null,
        };
    }

    pub fn deinit(self: *Stream) void {
        _ = self.pause() catch {};
        _ = c.snd_pcm_close(self.handle);
    }

    fn run(self: *Stream) void {
        defer self.running.store(false, .seq_cst);
        self.tryPromoteWorkerThread();

        const frames = self.callbackPeriodFrames();
        const poll_descriptors = self.allocPollDescriptors() catch |err| {
            self.storeRunStatus(root.runStatusFromAudioError(err));
            emitStreamError(self, err);
            return;
        };
        defer std.heap.c_allocator.free(poll_descriptors);

        switch (self.callback) {
            .output_f32, .input_f32 => self.runF32(frames, poll_descriptors),
            .output_i8, .input_i8 => self.runI8(frames, poll_descriptors),
            .output_u8, .input_u8 => self.runU8(frames, poll_descriptors),
            .output_i16, .input_i16 => self.runI16(frames, poll_descriptors),
            .output_u16, .input_u16 => self.runU16(frames, poll_descriptors),
            .output_i32, .input_i32 => self.runI32(frames, poll_descriptors),
            .output_u32, .input_u32 => self.runU32(frames, poll_descriptors),
            .output_f64, .input_f64 => self.runF64(frames, poll_descriptors),
        }
    }

    fn callbackPeriodFrames(self: *Stream) usize {
        if (self.buffer_size_frames) |frames| return @max(@as(usize, @intCast(frames)), 1);
        return switch (self.config.buffer_size) {
            .default => 256,
            .fixed => |value| @max(@as(usize, @intCast(value)), 1),
        };
    }

    fn allocCallbackBuffer(self: *Stream, comptime Sample: type, frames: usize) ?[]Sample {
        const samples = callbackSampleCount(frames, self.config.channels) catch |err| {
            self.storeRunStatus(root.runStatusFromAudioError(err));
            emitStreamError(self, err);
            self.running.store(false, .seq_cst);
            return null;
        };
        return std.heap.c_allocator.alloc(Sample, samples) catch {
            self.storeRunStatus(.out_of_memory);
            emitStreamError(self, root.AudioError.OutOfMemory);
            self.running.store(false, .seq_cst);
            return null;
        };
    }

    fn allocPollDescriptors(self: *Stream) root.AudioError![]c.struct_pollfd {
        const count = c.snd_pcm_poll_descriptors_count(self.handle);
        if (count < 0) return mapAlsaError(count);
        if (count == 0) return root.AudioError.BackendError;

        const descriptors = try std.heap.c_allocator.alloc(c.struct_pollfd, @intCast(count));
        errdefer std.heap.c_allocator.free(descriptors);

        const rc = c.snd_pcm_poll_descriptors(self.handle, descriptors.ptr, @intCast(descriptors.len));
        if (rc < 0) return mapAlsaError(rc);
        if (rc == 0) return root.AudioError.BackendError;
        return descriptors;
    }

    fn waitForReady(self: *Stream, poll_descriptors: []c.struct_pollfd) bool {
        const timeout_ms: c_int = 100;
        const poll_rc = c.poll(poll_descriptors.ptr, @intCast(poll_descriptors.len), timeout_ms);
        if (poll_rc == 0) return false;
        if (poll_rc < 0) {
            switch (std.c.errno(poll_rc)) {
                .INTR => return false,
                else => {
                    self.storeRunStatus(.backend_error);
                    emitStreamError(self, root.AudioError.BackendError);
                    self.running.store(false, .seq_cst);
                    return false;
                },
            }
            return false;
        }

        var revents: c_ushort = 0;
        const revents_rc = c.snd_pcm_poll_descriptors_revents(
            self.handle,
            poll_descriptors.ptr,
            @intCast(poll_descriptors.len),
            &revents,
        );
        if (revents_rc < 0) {
            self.handlePcmIoError(revents_rc);
            return false;
        }

        const error_events = revents & (@as(c_ushort, @intCast(c.POLLERR)) |
            @as(c_ushort, @intCast(c.POLLHUP)) |
            @as(c_ushort, @intCast(c.POLLNVAL)));
        if (error_events != 0) {
            self.handlePcmPollError(error_events);
            return false;
        }

        return switch (self.direction) {
            .output => (revents & @as(c_ushort, @intCast(c.POLLOUT))) != 0,
            .input => (revents & @as(c_ushort, @intCast(c.POLLIN))) != 0,
            .duplex, .unknown => revents != 0,
        };
    }

    fn drainOutputPcm(self: *Stream) root.AudioError!void {
        const max_waits = 200;
        var waits: usize = 0;
        while (waits <= max_waits) {
            const rc = c.snd_pcm_drain(self.handle);
            if (rc == 0) return;
            if (rc == -c.EINTR) continue;
            if (rc == -c.EAGAIN) {
                waits += 1;
                try self.waitForDrainProgress();
                continue;
            }
            if (rc == -c.EPIPE) self.recordXrun();
            if (rc == -c.EPIPE or rc == -c.ESTRPIPE) {
                const recovered = c.snd_pcm_recover(self.handle, rc, 1);
                if (recovered < 0) return mapAlsaError(recovered);
                _ = self.recovery_count.fetchAdd(1, .seq_cst);
                self.clearXrunObservation();
                self.clearObservedBackendError();
                continue;
            }
            return mapAlsaError(rc);
        }
        return root.AudioError.DeviceBusy;
    }

    fn waitForDrainProgress(self: *Stream) root.AudioError!void {
        const poll_descriptors = try self.allocPollDescriptors();
        defer std.heap.c_allocator.free(poll_descriptors);

        const poll_rc = c.poll(poll_descriptors.ptr, @intCast(poll_descriptors.len), 100);
        if (poll_rc == 0) return;
        if (poll_rc < 0) {
            return switch (std.c.errno(poll_rc)) {
                .INTR => {},
                else => root.AudioError.BackendError,
            };
        }

        var revents: c_ushort = 0;
        const revents_rc = c.snd_pcm_poll_descriptors_revents(
            self.handle,
            poll_descriptors.ptr,
            @intCast(poll_descriptors.len),
            &revents,
        );
        if (revents_rc < 0) return mapAlsaError(revents_rc);

        const error_events = revents & (@as(c_ushort, @intCast(c.POLLERR)) |
            @as(c_ushort, @intCast(c.POLLHUP)) |
            @as(c_ushort, @intCast(c.POLLNVAL)));
        if (error_events != 0) return mapAlsaError(pcmPollErrorCode(c.snd_pcm_state(self.handle), error_events));
    }

    fn runF32(self: *Stream, frames: usize, poll_descriptors: []c.struct_pollfd) void {
        const buffer = self.allocCallbackBuffer(f32, frames) orelse return;
        defer std.heap.c_allocator.free(buffer);

        switch (self.callback) {
            .output_f32 => |callback| while (self.running.load(.seq_cst)) {
                if (!self.waitForReady(poll_descriptors)) continue;
                self.runOutputCallbackF32(callback, buffer, frames);
            },
            .input_f32 => |callback| {
                var filled_frames: usize = 0;
                while (self.running.load(.seq_cst)) {
                    if (!self.waitForReady(poll_descriptors)) continue;
                    const read = self.readInputFrames(f32, buffer, filled_frames, frames) orelse {
                        filled_frames = 0;
                        continue;
                    };
                    filled_frames += read;
                    if (filled_frames >= frames) {
                        self.deliverInputCallbackF32(callback, buffer, frames);
                        filled_frames = 0;
                    }
                }
            },
            else => unreachable,
        }
    }

    fn runI8(self: *Stream, frames: usize, poll_descriptors: []c.struct_pollfd) void {
        const buffer = self.allocCallbackBuffer(i8, frames) orelse return;
        defer std.heap.c_allocator.free(buffer);

        switch (self.callback) {
            .output_i8 => |callback| while (self.running.load(.seq_cst)) {
                if (!self.waitForReady(poll_descriptors)) continue;
                self.runOutputCallbackI8(callback, buffer, frames);
            },
            .input_i8 => |callback| {
                var filled_frames: usize = 0;
                while (self.running.load(.seq_cst)) {
                    if (!self.waitForReady(poll_descriptors)) continue;
                    const read = self.readInputFrames(i8, buffer, filled_frames, frames) orelse {
                        filled_frames = 0;
                        continue;
                    };
                    filled_frames += read;
                    if (filled_frames >= frames) {
                        self.deliverInputCallbackI8(callback, buffer, frames);
                        filled_frames = 0;
                    }
                }
            },
            else => unreachable,
        }
    }

    fn runU8(self: *Stream, frames: usize, poll_descriptors: []c.struct_pollfd) void {
        const buffer = self.allocCallbackBuffer(u8, frames) orelse return;
        defer std.heap.c_allocator.free(buffer);

        switch (self.callback) {
            .output_u8 => |callback| while (self.running.load(.seq_cst)) {
                if (!self.waitForReady(poll_descriptors)) continue;
                self.runOutputCallbackU8(callback, buffer, frames);
            },
            .input_u8 => |callback| {
                var filled_frames: usize = 0;
                while (self.running.load(.seq_cst)) {
                    if (!self.waitForReady(poll_descriptors)) continue;
                    const read = self.readInputFrames(u8, buffer, filled_frames, frames) orelse {
                        filled_frames = 0;
                        continue;
                    };
                    filled_frames += read;
                    if (filled_frames >= frames) {
                        self.deliverInputCallbackU8(callback, buffer, frames);
                        filled_frames = 0;
                    }
                }
            },
            else => unreachable,
        }
    }

    fn runI16(self: *Stream, frames: usize, poll_descriptors: []c.struct_pollfd) void {
        const buffer = self.allocCallbackBuffer(i16, frames) orelse return;
        defer std.heap.c_allocator.free(buffer);

        switch (self.callback) {
            .output_i16 => |callback| while (self.running.load(.seq_cst)) {
                if (!self.waitForReady(poll_descriptors)) continue;
                self.runOutputCallbackI16(callback, buffer, frames);
            },
            .input_i16 => |callback| {
                var filled_frames: usize = 0;
                while (self.running.load(.seq_cst)) {
                    if (!self.waitForReady(poll_descriptors)) continue;
                    const read = self.readInputFrames(i16, buffer, filled_frames, frames) orelse {
                        filled_frames = 0;
                        continue;
                    };
                    filled_frames += read;
                    if (filled_frames >= frames) {
                        self.deliverInputCallbackI16(callback, buffer, frames);
                        filled_frames = 0;
                    }
                }
            },
            else => unreachable,
        }
    }

    fn runU16(self: *Stream, frames: usize, poll_descriptors: []c.struct_pollfd) void {
        const buffer = self.allocCallbackBuffer(u16, frames) orelse return;
        defer std.heap.c_allocator.free(buffer);

        switch (self.callback) {
            .output_u16 => |callback| while (self.running.load(.seq_cst)) {
                if (!self.waitForReady(poll_descriptors)) continue;
                self.runOutputCallbackU16(callback, buffer, frames);
            },
            .input_u16 => |callback| {
                var filled_frames: usize = 0;
                while (self.running.load(.seq_cst)) {
                    if (!self.waitForReady(poll_descriptors)) continue;
                    const read = self.readInputFrames(u16, buffer, filled_frames, frames) orelse {
                        filled_frames = 0;
                        continue;
                    };
                    filled_frames += read;
                    if (filled_frames >= frames) {
                        self.deliverInputCallbackU16(callback, buffer, frames);
                        filled_frames = 0;
                    }
                }
            },
            else => unreachable,
        }
    }

    fn runI32(self: *Stream, frames: usize, poll_descriptors: []c.struct_pollfd) void {
        const buffer = self.allocCallbackBuffer(i32, frames) orelse return;
        defer std.heap.c_allocator.free(buffer);

        switch (self.callback) {
            .output_i32 => |callback| while (self.running.load(.seq_cst)) {
                if (!self.waitForReady(poll_descriptors)) continue;
                self.runOutputCallbackI32(callback, buffer, frames);
            },
            .input_i32 => |callback| {
                var filled_frames: usize = 0;
                while (self.running.load(.seq_cst)) {
                    if (!self.waitForReady(poll_descriptors)) continue;
                    const read = self.readInputFrames(i32, buffer, filled_frames, frames) orelse {
                        filled_frames = 0;
                        continue;
                    };
                    filled_frames += read;
                    if (filled_frames >= frames) {
                        self.deliverInputCallbackI32(callback, buffer, frames);
                        filled_frames = 0;
                    }
                }
            },
            else => unreachable,
        }
    }

    fn runU32(self: *Stream, frames: usize, poll_descriptors: []c.struct_pollfd) void {
        const buffer = self.allocCallbackBuffer(u32, frames) orelse return;
        defer std.heap.c_allocator.free(buffer);

        switch (self.callback) {
            .output_u32 => |callback| while (self.running.load(.seq_cst)) {
                if (!self.waitForReady(poll_descriptors)) continue;
                self.runOutputCallbackU32(callback, buffer, frames);
            },
            .input_u32 => |callback| {
                var filled_frames: usize = 0;
                while (self.running.load(.seq_cst)) {
                    if (!self.waitForReady(poll_descriptors)) continue;
                    const read = self.readInputFrames(u32, buffer, filled_frames, frames) orelse {
                        filled_frames = 0;
                        continue;
                    };
                    filled_frames += read;
                    if (filled_frames >= frames) {
                        self.deliverInputCallbackU32(callback, buffer, frames);
                        filled_frames = 0;
                    }
                }
            },
            else => unreachable,
        }
    }

    fn runF64(self: *Stream, frames: usize, poll_descriptors: []c.struct_pollfd) void {
        const buffer = self.allocCallbackBuffer(f64, frames) orelse return;
        defer std.heap.c_allocator.free(buffer);

        switch (self.callback) {
            .output_f64 => |callback| while (self.running.load(.seq_cst)) {
                if (!self.waitForReady(poll_descriptors)) continue;
                self.runOutputCallbackF64(callback, buffer, frames);
            },
            .input_f64 => |callback| {
                var filled_frames: usize = 0;
                while (self.running.load(.seq_cst)) {
                    if (!self.waitForReady(poll_descriptors)) continue;
                    const read = self.readInputFrames(f64, buffer, filled_frames, frames) orelse {
                        filled_frames = 0;
                        continue;
                    };
                    filled_frames += read;
                    if (filled_frames >= frames) {
                        self.deliverInputCallbackF64(callback, buffer, frames);
                        filled_frames = 0;
                    }
                }
            },
            else => unreachable,
        }
    }

    fn runOutputCallbackF32(
        self: *Stream,
        callback: root.OutputCallbackF32,
        buffer: []f32,
        frames: usize,
    ) void {
        self.recordCallbackTiming(frames);
        @memset(buffer, 0);
        callback(buffer, self.outputCallbackInfo(), self.userdata);
        self.writeAllF32(buffer, frames);
    }

    fn runOutputCallbackI8(
        self: *Stream,
        callback: root.OutputCallbackI8,
        buffer: []i8,
        frames: usize,
    ) void {
        self.recordCallbackTiming(frames);
        @memset(buffer, 0);
        callback(buffer, self.outputCallbackInfo(), self.userdata);
        self.writeAllI8(buffer, frames);
    }

    fn runOutputCallbackU8(
        self: *Stream,
        callback: root.OutputCallbackU8,
        buffer: []u8,
        frames: usize,
    ) void {
        self.recordCallbackTiming(frames);
        @memset(buffer, 128);
        callback(buffer, self.outputCallbackInfo(), self.userdata);
        self.writeAllU8(buffer, frames);
    }

    fn runOutputCallbackI16(
        self: *Stream,
        callback: root.OutputCallbackI16,
        buffer: []i16,
        frames: usize,
    ) void {
        self.recordCallbackTiming(frames);
        @memset(buffer, 0);
        callback(buffer, self.outputCallbackInfo(), self.userdata);
        self.writeAllI16(buffer, frames);
    }

    fn runOutputCallbackU16(
        self: *Stream,
        callback: root.OutputCallbackU16,
        buffer: []u16,
        frames: usize,
    ) void {
        self.recordCallbackTiming(frames);
        @memset(buffer, 32768);
        callback(buffer, self.outputCallbackInfo(), self.userdata);
        self.writeAllU16(buffer, frames);
    }

    fn runOutputCallbackI32(
        self: *Stream,
        callback: root.OutputCallbackI32,
        buffer: []i32,
        frames: usize,
    ) void {
        self.recordCallbackTiming(frames);
        @memset(buffer, 0);
        callback(buffer, self.outputCallbackInfo(), self.userdata);
        self.writeAllI32(buffer, frames);
    }

    fn runOutputCallbackU32(
        self: *Stream,
        callback: root.OutputCallbackU32,
        buffer: []u32,
        frames: usize,
    ) void {
        self.recordCallbackTiming(frames);
        @memset(buffer, 0x80000000);
        callback(buffer, self.outputCallbackInfo(), self.userdata);
        self.writeAllU32(buffer, frames);
    }

    fn runOutputCallbackF64(
        self: *Stream,
        callback: root.OutputCallbackF64,
        buffer: []f64,
        frames: usize,
    ) void {
        self.recordCallbackTiming(frames);
        @memset(buffer, 0);
        callback(buffer, self.outputCallbackInfo(), self.userdata);
        self.writeAllF64(buffer, frames);
    }

    fn readInputFrames(
        self: *Stream,
        comptime Sample: type,
        buffer: []Sample,
        filled_frames: usize,
        target_frames: usize,
    ) ?usize {
        if (filled_frames >= target_frames) return 0;
        const channels: usize = self.config.channels;
        const offset = filled_frames * channels;
        const frames_to_read = target_frames - filled_frames;
        const read = c.snd_pcm_readi(self.handle, buffer[offset..].ptr, @intCast(frames_to_read));
        if (read < 0) {
            self.handlePcmIoError(@intCast(read));
            return null;
        }
        if (read == 0) {
            self.handleRecoverableBusy();
            return null;
        }
        return @intCast(read);
    }

    fn outputCallbackInfo(self: *Stream) root.OutputCallbackInfo {
        const callback = root.StreamInstant.nowMonotonic();
        const playback = if (queryDelayFrames(self.handle)) |delay_frames|
            offsetInstantByFrames(callback, delay_frames, self.config.sample_rate)
        else
            callback;
        return .{ .callback = callback, .playback = playback };
    }

    fn inputCallbackInfo(self: *Stream, frames: usize) root.InputCallbackInfo {
        const callback = root.StreamInstant.nowMonotonic();
        const queued_frames: u64 = if (queryDelayFrames(self.handle)) |delay_frames|
            if (delay_frames > 0) @intCast(delay_frames) else 0
        else
            0;
        const delivered_frames = @as(u64, @intCast(frames));
        const capture_offset_ns = root.framesToUnsignedDurationNs(
            clampU64ToU32(queued_frames +| delivered_frames),
            self.config.sample_rate,
        ) orelse 0;
        return .{
            .callback = callback,
            .capture = callback.subtractDurationNs(capture_offset_ns),
        };
    }

    fn deliverInputCallbackF32(self: *Stream, callback: root.InputCallbackF32, buffer: []f32, frames: usize) void {
        self.recordCallbackTiming(frames);
        const sample_count = frames * self.config.channels;
        callback(buffer[0..@min(sample_count, buffer.len)], self.inputCallbackInfo(frames), self.userdata);
    }

    fn deliverInputCallbackI8(self: *Stream, callback: root.InputCallbackI8, buffer: []i8, frames: usize) void {
        self.recordCallbackTiming(frames);
        const sample_count = frames * self.config.channels;
        callback(buffer[0..@min(sample_count, buffer.len)], self.inputCallbackInfo(frames), self.userdata);
    }

    fn deliverInputCallbackU8(self: *Stream, callback: root.InputCallbackU8, buffer: []u8, frames: usize) void {
        self.recordCallbackTiming(frames);
        const sample_count = frames * self.config.channels;
        callback(buffer[0..@min(sample_count, buffer.len)], self.inputCallbackInfo(frames), self.userdata);
    }

    fn deliverInputCallbackI16(self: *Stream, callback: root.InputCallbackI16, buffer: []i16, frames: usize) void {
        self.recordCallbackTiming(frames);
        const sample_count = frames * self.config.channels;
        callback(buffer[0..@min(sample_count, buffer.len)], self.inputCallbackInfo(frames), self.userdata);
    }

    fn deliverInputCallbackU16(self: *Stream, callback: root.InputCallbackU16, buffer: []u16, frames: usize) void {
        self.recordCallbackTiming(frames);
        const sample_count = frames * self.config.channels;
        callback(buffer[0..@min(sample_count, buffer.len)], self.inputCallbackInfo(frames), self.userdata);
    }

    fn deliverInputCallbackI32(self: *Stream, callback: root.InputCallbackI32, buffer: []i32, frames: usize) void {
        self.recordCallbackTiming(frames);
        const sample_count = frames * self.config.channels;
        callback(buffer[0..@min(sample_count, buffer.len)], self.inputCallbackInfo(frames), self.userdata);
    }

    fn deliverInputCallbackU32(self: *Stream, callback: root.InputCallbackU32, buffer: []u32, frames: usize) void {
        self.recordCallbackTiming(frames);
        const sample_count = frames * self.config.channels;
        callback(buffer[0..@min(sample_count, buffer.len)], self.inputCallbackInfo(frames), self.userdata);
    }

    fn deliverInputCallbackF64(self: *Stream, callback: root.InputCallbackF64, buffer: []f64, frames: usize) void {
        self.recordCallbackTiming(frames);
        const sample_count = frames * self.config.channels;
        callback(buffer[0..@min(sample_count, buffer.len)], self.inputCallbackInfo(frames), self.userdata);
    }

    fn writeAllF32(self: *Stream, buffer: []f32, frames: usize) void {
        var frames_written: usize = 0;
        const channels: usize = self.config.channels;
        while (frames_written < frames and self.running.load(.seq_cst)) {
            const offset = frames_written * channels;
            const written = c.snd_pcm_writei(
                self.handle,
                buffer[offset..].ptr,
                @intCast(frames - frames_written),
            );
            if (written < 0) {
                self.handlePcmIoError(@intCast(written));
                return;
            }
            if (written == 0) {
                self.handleRecoverableBusy();
                return;
            }
            frames_written += @intCast(written);
        }
    }

    fn writeAllI8(self: *Stream, buffer: []i8, frames: usize) void {
        var frames_written: usize = 0;
        const channels: usize = self.config.channels;
        while (frames_written < frames and self.running.load(.seq_cst)) {
            const offset = frames_written * channels;
            const written = c.snd_pcm_writei(
                self.handle,
                buffer[offset..].ptr,
                @intCast(frames - frames_written),
            );
            if (written < 0) {
                self.handlePcmIoError(@intCast(written));
                return;
            }
            if (written == 0) {
                self.handleRecoverableBusy();
                return;
            }
            frames_written += @intCast(written);
        }
    }

    fn writeAllU8(self: *Stream, buffer: []u8, frames: usize) void {
        var frames_written: usize = 0;
        const channels: usize = self.config.channels;
        while (frames_written < frames and self.running.load(.seq_cst)) {
            const offset = frames_written * channels;
            const written = c.snd_pcm_writei(
                self.handle,
                buffer[offset..].ptr,
                @intCast(frames - frames_written),
            );
            if (written < 0) {
                self.handlePcmIoError(@intCast(written));
                return;
            }
            if (written == 0) {
                self.handleRecoverableBusy();
                return;
            }
            frames_written += @intCast(written);
        }
    }

    fn writeAllI16(self: *Stream, buffer: []i16, frames: usize) void {
        var frames_written: usize = 0;
        const channels: usize = self.config.channels;
        while (frames_written < frames and self.running.load(.seq_cst)) {
            const offset = frames_written * channels;
            const written = c.snd_pcm_writei(
                self.handle,
                buffer[offset..].ptr,
                @intCast(frames - frames_written),
            );
            if (written < 0) {
                self.handlePcmIoError(@intCast(written));
                return;
            }
            if (written == 0) {
                self.handleRecoverableBusy();
                return;
            }
            frames_written += @intCast(written);
        }
    }

    fn writeAllU16(self: *Stream, buffer: []u16, frames: usize) void {
        var frames_written: usize = 0;
        const channels: usize = self.config.channels;
        while (frames_written < frames and self.running.load(.seq_cst)) {
            const offset = frames_written * channels;
            const written = c.snd_pcm_writei(
                self.handle,
                buffer[offset..].ptr,
                @intCast(frames - frames_written),
            );
            if (written < 0) {
                self.handlePcmIoError(@intCast(written));
                return;
            }
            if (written == 0) {
                self.handleRecoverableBusy();
                return;
            }
            frames_written += @intCast(written);
        }
    }

    fn writeAllI32(self: *Stream, buffer: []i32, frames: usize) void {
        var frames_written: usize = 0;
        const channels: usize = self.config.channels;
        while (frames_written < frames and self.running.load(.seq_cst)) {
            const offset = frames_written * channels;
            const written = c.snd_pcm_writei(
                self.handle,
                buffer[offset..].ptr,
                @intCast(frames - frames_written),
            );
            if (written < 0) {
                self.handlePcmIoError(@intCast(written));
                return;
            }
            if (written == 0) {
                self.handleRecoverableBusy();
                return;
            }
            frames_written += @intCast(written);
        }
    }

    fn writeAllU32(self: *Stream, buffer: []u32, frames: usize) void {
        var frames_written: usize = 0;
        const channels: usize = self.config.channels;
        while (frames_written < frames and self.running.load(.seq_cst)) {
            const offset = frames_written * channels;
            const written = c.snd_pcm_writei(
                self.handle,
                buffer[offset..].ptr,
                @intCast(frames - frames_written),
            );
            if (written < 0) {
                self.handlePcmIoError(@intCast(written));
                return;
            }
            if (written == 0) {
                self.handleRecoverableBusy();
                return;
            }
            frames_written += @intCast(written);
        }
    }

    fn writeAllF64(self: *Stream, buffer: []f64, frames: usize) void {
        var frames_written: usize = 0;
        const channels: usize = self.config.channels;
        while (frames_written < frames and self.running.load(.seq_cst)) {
            const offset = frames_written * channels;
            const written = c.snd_pcm_writei(
                self.handle,
                buffer[offset..].ptr,
                @intCast(frames - frames_written),
            );
            if (written < 0) {
                self.handlePcmIoError(@intCast(written));
                return;
            }
            if (written == 0) {
                self.handleRecoverableBusy();
                return;
            }
            frames_written += @intCast(written);
        }
    }

    fn handlePcmIoError(self: *Stream, rc: c_int) void {
        const err = mapAlsaError(rc);
        if (isRecoverableStreamIoError(err)) {
            self.handleRecoverableBusy();
            return;
        }
        if (isFatalStreamIoError(err)) {
            emitStreamError(self, err);
            self.storeRunStatus(root.runStatusFromAudioError(err));
            self.running.store(false, .seq_cst);
            return;
        }

        if (err == root.AudioError.Xrun) {
            self.recordXrun();
        }
        self.recoverPcmError(rc, err);
    }

    fn handlePcmPollError(self: *Stream, revents: c_ushort) void {
        self.handlePcmIoError(pcmPollErrorCode(c.snd_pcm_state(self.handle), revents));
    }

    fn recoverPcmError(self: *Stream, rc: c_int, err: root.AudioError) void {
        emitStreamError(self, err);
        const recovered = c.snd_pcm_recover(self.handle, rc, 1);
        if (recovered < 0) {
            const recovered_err = mapAlsaError(recovered);
            if (isRecoverableStreamIoError(recovered_err)) {
                self.handleRecoverableBusy();
            } else {
                emitStreamError(self, recovered_err);
                self.storeRunStatus(root.runStatusFromAudioError(recovered_err));
                self.running.store(false, .seq_cst);
            }
        } else {
            _ = self.recovery_count.fetchAdd(1, .seq_cst);
            self.clearXrunObservation();
            self.clearObservedBackendError();
            self.storeRunStatus(.running);
        }
    }

    fn handleRecoverableBusy(self: *Stream) void {
        if (self.running.load(.seq_cst)) self.storeRunStatus(.running);
        sleepBackoff();
    }

    fn emitStreamError(self: *Stream, err: root.AudioError) void {
        self.rememberObservedBackendErrorForAudioError(err);
        _ = self.stream_error_count.fetchAdd(1, .seq_cst);
        if (self.error_callback) |callback| callback(err, self.error_userdata);
    }

    fn rememberObservedBackendErrorForAudioError(self: *Stream, err: root.AudioError) void {
        if (observedBackendErrorForAudioError(err)) |observed| {
            self.observed_backend_error.store(@intFromEnum(observed), .seq_cst);
        }
    }

    fn clearObservedBackendError(self: *Stream) void {
        self.observed_backend_error.store(@intFromEnum(ObservedBackendError.none), .seq_cst);
    }

    fn recordXrun(self: *Stream) void {
        if (!self.xrun_observed.swap(true, .seq_cst)) {
            _ = self.xrun_count.fetchAdd(1, .seq_cst);
        }
    }

    fn clearXrunObservation(self: *Stream) void {
        self.xrun_observed.store(false, .seq_cst);
    }

    fn syncXrunObservationForBackendState(self: *Stream, backend_state: root.StreamBackendState) void {
        if (backend_state == .xrun) {
            self.recordXrun();
        } else if (backendStateClearsXrunObservation(backend_state)) {
            self.clearXrunObservation();
        }
    }

    fn syncStreamErrorObservationForBackendState(self: *Stream, backend_state: root.StreamBackendState) void {
        if (observedBackendErrorForBackendState(backend_state)) |observed| {
            const previous = self.observed_backend_error.swap(@intFromEnum(observed), .seq_cst);
            if (previous != @intFromEnum(observed)) {
                if (audioErrorForObservedBackendError(observed)) |err| self.emitStreamError(err);
            }
        } else if (backendStateClearsXrunObservation(backend_state)) {
            self.clearObservedBackendError();
        }
    }

    fn loadRunStatus(self: *Stream) root.StreamRunStatus {
        return @enumFromInt(self.run_status.load(.seq_cst));
    }

    fn refreshRunStatusForBackendState(self: *Stream, backend_state: root.StreamBackendState) root.StreamRunStatus {
        const run_status_value = reconciledRunStatusForBackendState(
            backend_state,
            self.running.load(.seq_cst),
            self.loadRunStatus(),
        );
        self.storeRunStatus(run_status_value);
        if (run_status_value == .stream_invalidated) self.running.store(false, .seq_cst);
        return run_status_value;
    }

    fn storeRunStatus(self: *Stream, run_status_value: root.StreamRunStatus) void {
        self.run_status.store(@intFromEnum(run_status_value), .seq_cst);
    }

    fn storeStoppedUnlessTerminal(self: *Stream) void {
        if (isTerminalRunStatus(self.loadRunStatus())) return;
        self.storeRunStatus(.stopped);
    }

    fn loadSchedulingStatus(self: *Stream) root.ThreadSchedulingStatus {
        return @enumFromInt(self.scheduling_status.load(.seq_cst));
    }

    fn storeSchedulingStatus(self: *Stream, scheduling_status_value: root.ThreadSchedulingStatus) void {
        self.scheduling_status.store(@intFromEnum(scheduling_status_value), .seq_cst);
    }

    fn resetCallbackTiming(self: *Stream) void {
        self.callback_count.store(0, .seq_cst);
        self.last_callback_ns.store(0, .seq_cst);
        self.last_callback_interval_ns.store(0, .seq_cst);
        self.last_callback_drift_ns.store(0, .seq_cst);
    }

    fn recordCallbackTiming(self: *Stream, frames: usize) void {
        const now_ns = saturatingU128ToU64(root.StreamInstant.nowMonotonic().nanos);
        const previous_ns = self.last_callback_ns.swap(now_ns, .seq_cst);
        _ = self.callback_count.fetchAdd(1, .seq_cst);
        if (previous_ns == 0 or now_ns <= previous_ns) return;

        const interval_ns = now_ns - previous_ns;
        self.last_callback_interval_ns.store(interval_ns, .seq_cst);

        const expected_ns = root.framesToUnsignedDurationNs(
            @intCast(@min(frames, std.math.maxInt(u32))),
            self.config.sample_rate,
        ) orelse return;
        self.last_callback_drift_ns.store(saturatingDiffI64(interval_ns, expected_ns), .seq_cst);
    }

    fn saturatingU128ToU64(value: u128) u64 {
        return if (value > std.math.maxInt(u64)) std.math.maxInt(u64) else @intCast(value);
    }

    fn saturatingDiffI64(left: u64, right: u64) i64 {
        if (left >= right) {
            const delta = left - right;
            return if (delta > std.math.maxInt(i64)) std.math.maxInt(i64) else @intCast(delta);
        }
        const delta = right - left;
        return if (delta > std.math.maxInt(i64)) std.math.minInt(i64) else -@as(i64, @intCast(delta));
    }

    fn tryPromoteWorkerThread(self: *Stream) void {
        if (builtin.os.tag != .linux) {
            self.storeSchedulingStatus(.unsupported);
            return;
        }

        const max_priority = c.sched_get_priority_max(c.SCHED_FIFO);
        if (max_priority < 0) {
            self.storeSchedulingStatus(.unsupported);
            return;
        }

        var params = c.struct_sched_param{
            .sched_priority = @max(1, max_priority - 1),
        };
        const rc = c.pthread_setschedparam(c.pthread_self(), c.SCHED_FIFO, &params);
        if (rc == 0) {
            self.storeSchedulingStatus(.applied);
            return;
        }

        self.storeSchedulingStatus(switch (rc) {
            c.EPERM, c.EACCES => .permission_denied,
            c.EINVAL, c.ENOTSUP => .unsupported,
            else => .failed,
        });
    }
};

const BufferPeriodSizes = struct {
    buffer_size_frames: u32,
    period_size_frames: u32,
};

fn queryPeriodSize(handle: ?*c.snd_pcm_t) root.AudioError!u32 {
    return (try queryBufferPeriodSizes(handle)).period_size_frames;
}

fn queryBufferPeriodSizes(handle: ?*c.snd_pcm_t) root.AudioError!BufferPeriodSizes {
    var buffer_size: c.snd_pcm_uframes_t = 0;
    var period_size: c.snd_pcm_uframes_t = 0;
    const rc = c.snd_pcm_get_params(handle, &buffer_size, &period_size);
    if (rc < 0) return mapAlsaError(rc);
    return .{
        .buffer_size_frames = clampToU32(buffer_size),
        .period_size_frames = clampToU32(period_size),
    };
}

const PcmStatusSnapshot = struct {
    delay_frames: i64,
    available_frames: u32,
    available_max_frames: u32,
    overrange_frames: u32,
};

fn queryPcmStatusSnapshot(handle: ?*c.snd_pcm_t) ?PcmStatusSnapshot {
    var status: ?*c.snd_pcm_status_t = null;
    if (c.snd_pcm_status_malloc(&status) < 0) return null;
    defer c.snd_pcm_status_free(status);

    if (c.snd_pcm_status(handle, status) < 0) return null;
    return .{
        .delay_frames = @intCast(c.snd_pcm_status_get_delay(status)),
        .available_frames = clampToU32(c.snd_pcm_status_get_avail(status)),
        .available_max_frames = clampToU32(c.snd_pcm_status_get_avail_max(status)),
        .overrange_frames = clampToU32(c.snd_pcm_status_get_overrange(status)),
    };
}

fn queryDelayFrames(handle: ?*c.snd_pcm_t) ?i64 {
    var delay_frames: c.snd_pcm_sframes_t = 0;
    const rc = c.snd_pcm_delay(handle, &delay_frames);
    if (rc < 0) return null;
    return @intCast(delay_frames);
}

fn offsetInstantByFrames(
    instant: root.StreamInstant,
    frames: i64,
    sample_rate: u32,
) root.StreamInstant {
    const offset_ns = root.framesToDurationNs(frames, sample_rate) orelse return instant;
    if (offset_ns < 0) {
        return instant.subtractDurationNs(@intCast(-@as(i128, offset_ns)));
    }
    return instant.addDurationNs(@intCast(offset_ns));
}

fn clampU64ToU32(value: u64) u32 {
    return if (value > std.math.maxInt(u32)) std.math.maxInt(u32) else @intCast(value);
}

fn streamTimestampStatus(handle: ?*c.snd_pcm_t, status: *root.LatencyStatus) root.StreamInstant {
    var avail: c.snd_pcm_uframes_t = 0;
    var timestamp: c.snd_htimestamp_t = undefined;
    const rc = c.snd_pcm_htimestamp(handle, &avail, &timestamp);
    if (rc < 0) {
        status.* = .estimated;
        return root.StreamInstant.nowMonotonic();
    }
    if (!pcmTimestampUsesMonotonicClock(handle)) {
        status.* = .estimated;
        return root.StreamInstant.nowMonotonic();
    }
    status.* = .measured;
    return timestampToInstant(timestamp);
}

fn pcmTimestampUsesMonotonicClock(handle: ?*c.snd_pcm_t) bool {
    var params: ?*c.snd_pcm_sw_params_t = null;
    if (c.snd_pcm_sw_params_malloc(&params) < 0) return false;
    defer c.snd_pcm_sw_params_free(params);

    if (c.snd_pcm_sw_params_current(handle, params) < 0) return false;

    var mode: c.snd_pcm_tstamp_t = undefined;
    if (c.snd_pcm_sw_params_get_tstamp_mode(params, &mode) < 0) return false;
    if (mode != c.SND_PCM_TSTAMP_ENABLE) return false;

    var timestamp_type: c.snd_pcm_tstamp_type_t = undefined;
    if (c.snd_pcm_sw_params_get_tstamp_type(params, &timestamp_type) < 0) return false;
    return timestampTypeIsMonotonic(timestamp_type);
}

fn timestampTypeIsMonotonic(timestamp_type: c.snd_pcm_tstamp_type_t) bool {
    return timestamp_type == c.SND_PCM_TSTAMP_TYPE_MONOTONIC or
        timestamp_type == c.SND_PCM_TSTAMP_TYPE_MONOTONIC_RAW;
}

fn timestampToInstant(timestamp: c.snd_htimestamp_t) root.StreamInstant {
    return .{
        .nanos = @as(u128, @intCast(timestamp.tv_sec)) * std.time.ns_per_s +
            @as(u128, @intCast(timestamp.tv_nsec)),
    };
}

fn sleepBackoff() void {
    sleepNs(std.time.ns_per_ms);
}

fn sleepNs(ns: u64) void {
    if (ns == 0) return;
    if (builtin.os.tag == .linux) {
        var ts = std.os.linux.timespec{
            .sec = @intCast(ns / std.time.ns_per_s),
            .nsec = @intCast(ns % std.time.ns_per_s),
        };
        _ = std.os.linux.nanosleep(&ts, null);
    }
}

fn directionFromIoId(ioid_ptr: [*c]u8) root.DeviceDirection {
    if (ioid_ptr == null) return .duplex;
    const ioid = std.mem.span(ioid_ptr);
    if (std.ascii.eqlIgnoreCase(ioid, "Input")) return .input;
    if (std.ascii.eqlIgnoreCase(ioid, "Output")) return .output;
    return .unknown;
}

fn deviceDirectionIsAvailable(
    direction: root.DeviceDirection,
    can_open_output: bool,
    can_open_input: bool,
) bool {
    return switch (direction) {
        .output => can_open_output,
        .input => can_open_input,
        .duplex => can_open_output and can_open_input,
        .unknown => can_open_output or can_open_input,
    };
}

fn normalizeDescription(description: []const u8) []const u8 {
    return std.mem.trim(u8, description, " \t\r\n");
}

fn quietAlsaErrorHandler(file: [*c]const u8, line: c_int, function: [*c]const u8, err: c_int, fmt: [*c]const u8, ...) callconv(.c) void {
    _ = file;
    _ = line;
    _ = function;
    _ = err;
    _ = fmt;
}

fn isKnownNoisyAvailabilityProbe(id_text: []const u8) bool {
    return std.mem.eql(u8, id_text, "jack") or
        std.mem.startsWith(u8, id_text, "jack:") or
        std.mem.eql(u8, id_text, "oss") or
        std.mem.startsWith(u8, id_text, "oss:");
}

fn probeOpenErrorMeansAvailable(err: root.AudioError) bool {
    return switch (err) {
        root.AudioError.DeviceNotAvailable,
        root.AudioError.StreamInvalidated,
        => false,
        else => true,
    };
}

fn pcmPollErrorCode(state: c.snd_pcm_state_t, revents: c_ushort) c_int {
    _ = revents;
    return switch (state) {
        c.SND_PCM_STATE_XRUN => -c.EPIPE,
        c.SND_PCM_STATE_SUSPENDED => -c.ESTRPIPE,
        c.SND_PCM_STATE_DISCONNECTED => -c.EIO,
        else => -c.EIO,
    };
}

fn mapAlsaError(rc: c_int) root.AudioError {
    return switch (-rc) {
        c.EPIPE => root.AudioError.Xrun,
        c.ESTRPIPE => root.AudioError.StreamSuspended,
        c.EBUSY, c.EAGAIN => root.AudioError.DeviceBusy,
        c.ENODEV, c.ENOENT, c.ENXIO => root.AudioError.DeviceNotAvailable,
        c.EACCES, c.EPERM => root.AudioError.PermissionDenied,
        c.EINVAL => root.AudioError.InvalidInput,
        c.ENOMEM => root.AudioError.OutOfMemory,
        c.EIO => root.AudioError.StreamInvalidated,
        else => root.AudioError.BackendError,
    };
}

fn isRecoverableStreamIoError(err: root.AudioError) bool {
    return err == root.AudioError.DeviceBusy;
}

fn isFatalStreamIoError(err: root.AudioError) bool {
    return switch (err) {
        root.AudioError.DeviceNotAvailable,
        root.AudioError.StreamInvalidated,
        root.AudioError.PermissionDenied,
        root.AudioError.InvalidInput,
        => true,
        else => false,
    };
}

test "ALSA direction parsing handles missing IOID as duplex" {
    try std.testing.expectEqual(root.DeviceDirection.duplex, directionFromIoId(null));
}

test "ALSA availability policy matches declared device direction" {
    try std.testing.expect(deviceDirectionIsAvailable(.output, true, false));
    try std.testing.expect(!deviceDirectionIsAvailable(.output, false, true));
    try std.testing.expect(deviceDirectionIsAvailable(.input, false, true));
    try std.testing.expect(!deviceDirectionIsAvailable(.input, true, false));

    try std.testing.expect(deviceDirectionIsAvailable(.duplex, true, true));
    try std.testing.expect(!deviceDirectionIsAvailable(.duplex, true, false));
    try std.testing.expect(!deviceDirectionIsAvailable(.duplex, false, true));

    try std.testing.expect(deviceDirectionIsAvailable(.unknown, true, false));
    try std.testing.expect(deviceDirectionIsAvailable(.unknown, false, true));
    try std.testing.expect(!deviceDirectionIsAvailable(.unknown, false, false));
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
    try std.testing.expectEqual(root.SampleFormat.f32, preferredDefaultConfigRange(&ranges).sample_format);
}

test "ALSA preferred default format lookup follows negotiation preferences without f32" {
    const ranges = [_]root.SupportedStreamConfigRange{
        .{
            .channels = 2,
            .min_sample_rate = 44_100,
            .max_sample_rate = 48_000,
            .buffer_size = .unknown,
            .sample_format = .i8,
        },
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
            .sample_format = .u8,
        },
    };
    try std.testing.expectEqual(root.SampleFormat.i16, preferredDefaultConfigRange(&ranges).sample_format);
}

test "ALSA callback sample count guards overflow" {
    try std.testing.expectEqual(@as(usize, 512), try callbackSampleCount(256, 2));
    try std.testing.expectError(root.AudioError.InvalidInput, callbackSampleCount(256, 0));
    try std.testing.expectError(root.AudioError.ResourceExhausted, callbackSampleCount(std.math.maxInt(usize), 2));
}

test "ALSA default period and total buffer requests stay latency-oriented" {
    try std.testing.expectEqual(@as(c.snd_pcm_uframes_t, 480), defaultPeriodFrames(48_000));
    try std.testing.expectEqual(@as(c.snd_pcm_uframes_t, 64), defaultPeriodFrames(1_000));
    try std.testing.expectEqual(@as(c.snd_pcm_uframes_t, 2048), defaultPeriodFrames(384_000));

    const default_config = root.StreamConfig{
        .channels = 2,
        .sample_rate = 48_000,
    };
    const default_period = requestedPeriodFrames(default_config);
    try std.testing.expectEqual(@as(c.snd_pcm_uframes_t, 480), default_period);
    try std.testing.expectEqual(
        @as(c.snd_pcm_uframes_t, 1920),
        requestedTotalBufferFrames(default_config, default_period),
    );

    const fixed_config = root.StreamConfig{
        .channels = 2,
        .sample_rate = 48_000,
        .buffer_size = .{ .fixed = 256 },
        .total_buffer_size = .{ .fixed = 1024 },
    };
    try std.testing.expectEqual(@as(c.snd_pcm_uframes_t, 256), requestedPeriodFrames(fixed_config));
    try std.testing.expectEqual(
        @as(c.snd_pcm_uframes_t, 1024),
        requestedTotalBufferFrames(fixed_config, 256),
    );
}

test "ALSA fixed period and total buffer requests reject rounded values" {
    const default_config = root.StreamConfig{
        .channels = 2,
        .sample_rate = 48_000,
    };
    try std.testing.expect(fixedPeriodRequestMatches(default_config, 481));
    try std.testing.expect(fixedTotalBufferRequestMatches(default_config, 1924));

    const fixed_config = root.StreamConfig{
        .channels = 2,
        .sample_rate = 48_000,
        .buffer_size = .{ .fixed = 480 },
        .total_buffer_size = .{ .fixed = 1920 },
    };
    try std.testing.expect(fixedPeriodRequestMatches(fixed_config, 480));
    try std.testing.expect(!fixedPeriodRequestMatches(fixed_config, 481));
    try std.testing.expect(fixedTotalBufferRequestMatches(fixed_config, 1920));
    try std.testing.expect(!fixedTotalBufferRequestMatches(fixed_config, 1924));
}

test "ALSA committed buffer and period verification enforces fixed requests" {
    const default_config = root.StreamConfig{
        .channels = 2,
        .sample_rate = 48_000,
    };
    try verifyCommittedBufferPeriodSizes(default_config, .{
        .buffer_size_frames = 1936,
        .period_size_frames = 484,
    });

    const fixed_config = root.StreamConfig{
        .channels = 2,
        .sample_rate = 48_000,
        .buffer_size = .{ .fixed = 480 },
        .total_buffer_size = .{ .fixed = 1920 },
    };
    try verifyCommittedBufferPeriodSizes(fixed_config, .{
        .buffer_size_frames = 1920,
        .period_size_frames = 480,
    });
    try std.testing.expectError(root.AudioError.UnsupportedConfig, verifyCommittedBufferPeriodSizes(fixed_config, .{
        .buffer_size_frames = 1920,
        .period_size_frames = 481,
    }));
    try std.testing.expectError(root.AudioError.UnsupportedConfig, verifyCommittedBufferPeriodSizes(fixed_config, .{
        .buffer_size_frames = 1924,
        .period_size_frames = 480,
    }));
}

test "ALSA buildable format table drives open and probe mappings" {
    const formats = buildableAlsaFormats();
    try std.testing.expectEqual(@as(usize, 8), formats.len);

    for (formats) |format| {
        try std.testing.expectEqual(format.alsa_format, alsaFormat(format.sample_format).?);
    }

    try std.testing.expectEqual(c.SND_PCM_FORMAT_FLOAT_LE, alsaFormat(.f32).?);
    try std.testing.expectEqual(c.SND_PCM_FORMAT_S8, alsaFormat(.i8).?);
    try std.testing.expectEqual(c.SND_PCM_FORMAT_U8, alsaFormat(.u8).?);
    try std.testing.expectEqual(c.SND_PCM_FORMAT_S16_LE, alsaFormat(.i16).?);
    try std.testing.expectEqual(c.SND_PCM_FORMAT_U16_LE, alsaFormat(.u16).?);
    try std.testing.expectEqual(c.SND_PCM_FORMAT_S32_LE, alsaFormat(.i32).?);
    try std.testing.expectEqual(c.SND_PCM_FORMAT_U32_LE, alsaFormat(.u32).?);
    try std.testing.expectEqual(c.SND_PCM_FORMAT_FLOAT64_LE, alsaFormat(.f64).?);

    try std.testing.expectEqual(@as(?c.snd_pcm_format_t, null), alsaFormat(.i24));
    try std.testing.expectEqual(@as(?c.snd_pcm_format_t, null), alsaFormat(.u24));
    try std.testing.expectEqual(@as(?c.snd_pcm_format_t, null), alsaFormat(.i64));
    try std.testing.expectEqual(@as(?c.snd_pcm_format_t, null), alsaFormat(.u64));
    try std.testing.expectEqual(@as(?c.snd_pcm_format_t, null), alsaFormat(.dsd_u8));
}

test "ALSA stream PCM open mode is nonblocking from open" {
    try std.testing.expect((streamPcmOpenMode() & c.SND_PCM_NONBLOCK) != 0);
}

test "ALSA PCM states map to public backend diagnostics states" {
    try std.testing.expectEqual(root.StreamBackendState.open, alsaStreamBackendState(c.SND_PCM_STATE_OPEN));
    try std.testing.expectEqual(root.StreamBackendState.setup, alsaStreamBackendState(c.SND_PCM_STATE_SETUP));
    try std.testing.expectEqual(root.StreamBackendState.prepared, alsaStreamBackendState(c.SND_PCM_STATE_PREPARED));
    try std.testing.expectEqual(root.StreamBackendState.running, alsaStreamBackendState(c.SND_PCM_STATE_RUNNING));
    try std.testing.expectEqual(root.StreamBackendState.xrun, alsaStreamBackendState(c.SND_PCM_STATE_XRUN));
    try std.testing.expectEqual(root.StreamBackendState.draining, alsaStreamBackendState(c.SND_PCM_STATE_DRAINING));
    try std.testing.expectEqual(root.StreamBackendState.paused, alsaStreamBackendState(c.SND_PCM_STATE_PAUSED));
    try std.testing.expectEqual(root.StreamBackendState.suspended, alsaStreamBackendState(c.SND_PCM_STATE_SUSPENDED));
    try std.testing.expectEqual(root.StreamBackendState.disconnected, alsaStreamBackendState(c.SND_PCM_STATE_DISCONNECTED));
    try std.testing.expectEqual(root.StreamBackendState.private, alsaStreamBackendState(c.SND_PCM_STATE_PRIVATE1));
}

test "ALSA terminal backend states map to public run statuses" {
    try std.testing.expectEqual(root.StreamRunStatus.xrun, runStatusForBackendState(.xrun).?);
    try std.testing.expectEqual(root.StreamRunStatus.stream_suspended, runStatusForBackendState(.suspended).?);
    try std.testing.expectEqual(root.StreamRunStatus.stream_invalidated, runStatusForBackendState(.disconnected).?);
    try std.testing.expectEqual(@as(?root.StreamRunStatus, null), runStatusForBackendState(.running));
    try std.testing.expectEqual(@as(?root.StreamRunStatus, null), runStatusForBackendState(.prepared));
}

test "ALSA diagnostics reconcile stale terminal statuses after non-terminal backend states" {
    try std.testing.expectEqual(
        root.StreamRunStatus.xrun,
        reconciledRunStatusForBackendState(.xrun, true, .running),
    );
    try std.testing.expectEqual(
        root.StreamRunStatus.running,
        reconciledRunStatusForBackendState(.running, true, .xrun),
    );
    try std.testing.expectEqual(
        root.StreamRunStatus.stopped,
        reconciledRunStatusForBackendState(.prepared, false, .stream_suspended),
    );
    try std.testing.expectEqual(
        root.StreamRunStatus.backend_error,
        reconciledRunStatusForBackendState(.unknown, false, .backend_error),
    );
    try std.testing.expectEqual(
        root.StreamRunStatus.stream_invalidated,
        reconciledRunStatusForBackendState(.private, false, .stream_invalidated),
    );
}

test "ALSA terminal backend states map to callback audio errors" {
    try std.testing.expectEqual(ObservedBackendError.xrun, observedBackendErrorForBackendState(.xrun).?);
    try std.testing.expectEqual(ObservedBackendError.suspended, observedBackendErrorForBackendState(.suspended).?);
    try std.testing.expectEqual(ObservedBackendError.invalidated, observedBackendErrorForBackendState(.disconnected).?);
    try std.testing.expectEqual(@as(?ObservedBackendError, null), observedBackendErrorForBackendState(.running));

    try std.testing.expectEqual(ObservedBackendError.xrun, observedBackendErrorForAudioError(root.AudioError.Xrun).?);
    try std.testing.expectEqual(ObservedBackendError.suspended, observedBackendErrorForAudioError(root.AudioError.StreamSuspended).?);
    try std.testing.expectEqual(ObservedBackendError.invalidated, observedBackendErrorForAudioError(root.AudioError.StreamInvalidated).?);
    try std.testing.expectEqual(@as(?ObservedBackendError, null), observedBackendErrorForAudioError(root.AudioError.DeviceBusy));

    try std.testing.expectEqual(root.AudioError.Xrun, audioErrorForObservedBackendError(.xrun).?);
    try std.testing.expectEqual(root.AudioError.StreamSuspended, audioErrorForObservedBackendError(.suspended).?);
    try std.testing.expectEqual(root.AudioError.StreamInvalidated, audioErrorForObservedBackendError(.invalidated).?);
    try std.testing.expectEqual(@as(?root.AudioError, null), audioErrorForObservedBackendError(.none));
}

test "ALSA diagnostics xrun observation clears only after non-xrun stream states" {
    try std.testing.expect(backendStateClearsXrunObservation(.open));
    try std.testing.expect(backendStateClearsXrunObservation(.setup));
    try std.testing.expect(backendStateClearsXrunObservation(.prepared));
    try std.testing.expect(backendStateClearsXrunObservation(.running));
    try std.testing.expect(backendStateClearsXrunObservation(.draining));
    try std.testing.expect(backendStateClearsXrunObservation(.paused));

    try std.testing.expect(!backendStateClearsXrunObservation(.xrun));
    try std.testing.expect(!backendStateClearsXrunObservation(.suspended));
    try std.testing.expect(!backendStateClearsXrunObservation(.disconnected));
    try std.testing.expect(!backendStateClearsXrunObservation(.private));
    try std.testing.expect(!backendStateClearsXrunObservation(.unknown));
    try std.testing.expect(!backendStateClearsXrunObservation(.unavailable));
}

test "ALSA lifecycle cleanup preserves terminal run statuses" {
    try std.testing.expect(isTerminalRunStatus(.stream_invalidated));
    try std.testing.expect(isTerminalRunStatus(.stream_suspended));
    try std.testing.expect(isTerminalRunStatus(.xrun));
    try std.testing.expect(isTerminalRunStatus(.device_not_available));
    try std.testing.expect(isTerminalRunStatus(.backend_error));
    try std.testing.expect(!isTerminalRunStatus(.stopped));
    try std.testing.expect(!isTerminalRunStatus(.running));
    try std.testing.expect(!isTerminalRunStatus(.device_busy));
}

test "ALSA poll error mapping recovers xrun and suspended states before invalidation" {
    const pollerr: c_ushort = @intCast(c.POLLERR);
    try std.testing.expectEqual(@as(c_int, -c.EPIPE), pcmPollErrorCode(c.SND_PCM_STATE_XRUN, pollerr));
    try std.testing.expectEqual(@as(c_int, -c.ESTRPIPE), pcmPollErrorCode(c.SND_PCM_STATE_SUSPENDED, pollerr));
    try std.testing.expectEqual(@as(c_int, -c.EIO), pcmPollErrorCode(c.SND_PCM_STATE_DISCONNECTED, pollerr));
    try std.testing.expectEqual(@as(c_int, -c.EIO), pcmPollErrorCode(c.SND_PCM_STATE_RUNNING, pollerr));
}

test "ALSA control revents only signal on actionable device-change events" {
    try std.testing.expect(!controlReventsSignalDeviceChange(0));
    try std.testing.expect(!controlReventsSignalDeviceChange(@intCast(c.POLLOUT)));
    try std.testing.expect(controlReventsSignalDeviceChange(@intCast(c.POLLIN)));
    try std.testing.expect(controlReventsSignalDeviceChange(@intCast(c.POLLERR)));
    try std.testing.expect(controlReventsSignalDeviceChange(@intCast(c.POLLHUP)));
    try std.testing.expect(controlReventsSignalDeviceChange(@intCast(c.POLLNVAL)));
}

test "ALSA control event drain treats empty nonblocking queue as normal" {
    try std.testing.expect(controlReadQueueEmpty(-c.EAGAIN));
    try std.testing.expect(controlReadQueueEmpty(-c.EINTR));
    try std.testing.expect(!controlReadQueueEmpty(-c.EIO));
}

test "ALSA native signal poll timeout rounds up and clamps" {
    try std.testing.expectEqual(@as(c_int, 0), timeoutNsToPollMs(0));
    try std.testing.expectEqual(@as(c_int, 1), timeoutNsToPollMs(1));
    try std.testing.expectEqual(@as(c_int, 1), timeoutNsToPollMs(std.time.ns_per_ms));
    try std.testing.expectEqual(@as(c_int, 2), timeoutNsToPollMs(std.time.ns_per_ms + 1));
    try std.testing.expectEqual(std.math.maxInt(c_int), timeoutNsToPollMs(std.math.maxInt(u64)));
}

test "ALSA native signal waits fall back to sleeping without control descriptors" {
    try std.testing.expect(controlWaitNeedsFallbackSleep(0, 0));
    try std.testing.expect(controlWaitNeedsFallbackSleep(1, 0));
    try std.testing.expect(!controlWaitNeedsFallbackSleep(1, 1));
    try std.testing.expect(!controlWaitNeedsFallbackSleep(2, 3));
}

test "ALSA availability probes skip known noisy external plugins" {
    try std.testing.expect(isKnownNoisyAvailabilityProbe("jack"));
    try std.testing.expect(isKnownNoisyAvailabilityProbe("jack:system"));
    try std.testing.expect(isKnownNoisyAvailabilityProbe("oss"));
    try std.testing.expect(isKnownNoisyAvailabilityProbe("oss:/dev/dsp"));
    try std.testing.expect(!isKnownNoisyAvailabilityProbe("default"));
    try std.testing.expect(!isKnownNoisyAvailabilityProbe("pulse"));
}

test "ALSA probe open error classification keeps busy devices available" {
    try std.testing.expect(!probeOpenErrorMeansAvailable(root.AudioError.DeviceNotAvailable));
    try std.testing.expect(!probeOpenErrorMeansAvailable(root.AudioError.StreamInvalidated));
    try std.testing.expect(probeOpenErrorMeansAvailable(root.AudioError.DeviceBusy));
    try std.testing.expect(probeOpenErrorMeansAvailable(root.AudioError.PermissionDenied));
    try std.testing.expect(probeOpenErrorMeansAvailable(root.AudioError.BackendError));
}

test "ALSA timestamp frame offsets saturate around base instants" {
    const base = root.StreamInstant{ .nanos = 1_000_000_000 };
    try std.testing.expectEqual(
        @as(u128, 1_500_000_000),
        offsetInstantByFrames(base, 24_000, 48_000).nanos,
    );
    try std.testing.expectEqual(
        @as(u128, 500_000_000),
        offsetInstantByFrames(base, -24_000, 48_000).nanos,
    );
    try std.testing.expectEqual(
        @as(u128, 0),
        offsetInstantByFrames(base, -96_000, 48_000).nanos,
    );
}

test "ALSA measured stream timestamps require monotonic timestamp types" {
    try std.testing.expect(timestampTypeIsMonotonic(c.SND_PCM_TSTAMP_TYPE_MONOTONIC));
    try std.testing.expect(timestampTypeIsMonotonic(c.SND_PCM_TSTAMP_TYPE_MONOTONIC_RAW));
    try std.testing.expect(!timestampTypeIsMonotonic(c.SND_PCM_TSTAMP_TYPE_GETTIMEOFDAY));
}

test "ALSA error mapping distinguishes invalidated and unavailable devices" {
    try std.testing.expectEqual(root.AudioError.StreamInvalidated, mapAlsaError(-c.EIO));
    try std.testing.expectEqual(root.AudioError.DeviceNotAvailable, mapAlsaError(-c.ENODEV));
    try std.testing.expectEqual(root.AudioError.DeviceNotAvailable, mapAlsaError(-c.ENXIO));
    try std.testing.expectEqual(root.AudioError.DeviceBusy, mapAlsaError(-c.EAGAIN));
    try std.testing.expectEqual(root.AudioError.Xrun, mapAlsaError(-c.EPIPE));
    try std.testing.expectEqual(root.AudioError.StreamSuspended, mapAlsaError(-c.ESTRPIPE));
}

test "ALSA stream IO error classes separate recoverable busy from fatal errors" {
    try std.testing.expect(isRecoverableStreamIoError(root.AudioError.DeviceBusy));
    try std.testing.expect(!isRecoverableStreamIoError(root.AudioError.Xrun));
    try std.testing.expect(isFatalStreamIoError(root.AudioError.StreamInvalidated));
    try std.testing.expect(isFatalStreamIoError(root.AudioError.DeviceNotAvailable));
    try std.testing.expect(!isFatalStreamIoError(root.AudioError.DeviceBusy));
    try std.testing.expect(!isFatalStreamIoError(root.AudioError.Xrun));
}
