const std = @import("std");
const builtin = @import("builtin");

pub const config = @import("config.zig");
pub const stream = @import("stream.zig");
pub const backends = @import("backends/root.zig");

pub const SampleFormat = config.SampleFormat;
pub const BufferSize = config.BufferSize;
pub const SupportedBufferSize = config.SupportedBufferSize;
pub const StreamConfig = config.StreamConfig;
pub const StreamConfigRequest = config.StreamConfigRequest;
pub const StreamCapability = config.StreamCapability;
pub const StreamCapabilityDirection = config.StreamCapabilityDirection;
pub const ChannelRange = config.ChannelRange;
pub const SupportedStreamConfig = config.SupportedStreamConfig;
pub const SupportedStreamConfigRange = config.SupportedStreamConfigRange;
pub const NegotiatedStreamConfig = config.NegotiatedStreamConfig;
pub const StreamInstant = stream.StreamInstant;
pub const LatencyStatus = stream.LatencyStatus;
pub const ThreadSchedulingStatus = stream.ThreadSchedulingStatus;
pub const StreamRunStatus = stream.StreamRunStatus;
pub const StreamBackendState = stream.StreamBackendState;
pub const StreamDiagnostics = stream.StreamDiagnostics;
pub const framesToDurationNs = stream.framesToDurationNs;
pub const framesToUnsignedDurationNs = stream.framesToUnsignedDurationNs;
pub const nonNegativeFramesToDurationNs = stream.nonNegativeFramesToDurationNs;
pub const runStatusFromAudioError = stream.runStatusFromAudioError;
pub const OutputCallback = stream.OutputCallback;
pub const InputCallback = stream.InputCallback;
pub const sampleFormatForType = stream.sampleFormatForType;
pub const OutputCallbackInfo = stream.OutputCallbackInfo;
pub const InputCallbackInfo = stream.InputCallbackInfo;
pub const OutputCallbackF32 = stream.OutputCallbackF32;
pub const InputCallbackF32 = stream.InputCallbackF32;
pub const OutputCallbackI8 = stream.OutputCallbackI8;
pub const InputCallbackI8 = stream.InputCallbackI8;
pub const OutputCallbackU8 = stream.OutputCallbackU8;
pub const InputCallbackU8 = stream.InputCallbackU8;
pub const OutputCallbackI16 = stream.OutputCallbackI16;
pub const InputCallbackI16 = stream.InputCallbackI16;
pub const OutputCallbackU16 = stream.OutputCallbackU16;
pub const InputCallbackU16 = stream.InputCallbackU16;
pub const OutputCallbackI32 = stream.OutputCallbackI32;
pub const InputCallbackI32 = stream.InputCallbackI32;
pub const OutputCallbackU32 = stream.OutputCallbackU32;
pub const InputCallbackU32 = stream.InputCallbackU32;
pub const OutputCallbackF64 = stream.OutputCallbackF64;
pub const InputCallbackF64 = stream.InputCallbackF64;
pub const StreamErrorCallback = stream.StreamErrorCallback;
pub const negotiateStreamConfig = config.negotiateStreamConfig;
pub const negotiateStreamCapability = config.negotiateStreamCapability;
pub const defaultSampleFormatPreferences = config.defaultSampleFormatPreferences;

pub const AudioError = error{
    BackendUnavailable,
    BackendError,
    DeviceBusy,
    DeviceNotAvailable,
    InvalidInput,
    OutOfMemory,
    PermissionDenied,
    ResourceExhausted,
    StreamInvalidated,
    StreamSuspended,
    UnsupportedConfig,
    UnsupportedOperation,
    Xrun,
};

pub const HostId = enum {
    alsa,
    coreaudio,
    wasapi,
    jack,
    pulseaudio,
    null,

    pub fn name(self: HostId) []const u8 {
        return switch (self) {
            .alsa => "ALSA",
            .coreaudio => "CoreAudio",
            .wasapi => "WASAPI",
            .jack => "JACK",
            .pulseaudio => "PulseAudio",
            .null => "Null",
        };
    }

    pub fn stableName(self: HostId) []const u8 {
        return switch (self) {
            .alsa => "alsa",
            .coreaudio => "coreaudio",
            .wasapi => "wasapi",
            .jack => "jack",
            .pulseaudio => "pulseaudio",
            .null => "null",
        };
    }
};

pub const DeviceDirection = enum {
    input,
    output,
    duplex,
    unknown,

    pub fn supportsInput(self: DeviceDirection) bool {
        return self == .input or self == .duplex or self == .unknown;
    }

    pub fn supportsOutput(self: DeviceDirection) bool {
        return self == .output or self == .duplex or self == .unknown;
    }
};

pub const DeviceInfo = struct {
    host: HostId,
    id: []const u8,
    name: []const u8,
    description: ?[]const u8 = null,
    direction: DeviceDirection,

    pub fn metadataFingerprint(self: DeviceInfo) u64 {
        return deviceMetadataFingerprint(self.host, self.id, self.name, self.description, self.direction, true);
    }
};

pub const DeviceSnapshotEntry = struct {
    host: HostId,
    id: []const u8,
    name: []const u8,
    description: ?[]const u8 = null,
    direction: DeviceDirection,
    available: bool = true,
    metadata_fingerprint: u64 = 0,

    pub fn clone(self: DeviceSnapshotEntry, allocator: std.mem.Allocator) AudioError!DeviceSnapshotEntry {
        return .{
            .host = self.host,
            .id = try allocator.dupe(u8, self.id),
            .name = try allocator.dupe(u8, self.name),
            .description = if (self.description) |description| try allocator.dupe(u8, description) else null,
            .direction = self.direction,
            .available = self.available,
            .metadata_fingerprint = self.fingerprint(),
        };
    }

    pub fn deinit(self: *DeviceSnapshotEntry, allocator: std.mem.Allocator) void {
        allocator.free(self.id);
        allocator.free(self.name);
        if (self.description) |description| allocator.free(description);
    }

    pub fn sameIdentity(self: DeviceSnapshotEntry, other: DeviceSnapshotEntry) bool {
        return self.host == other.host and std.mem.eql(u8, self.id, other.id);
    }

    pub fn sameEndpoint(self: DeviceSnapshotEntry, other: DeviceSnapshotEntry) bool {
        return self.sameIdentity(other) and self.direction == other.direction;
    }

    pub fn sameMetadata(self: DeviceSnapshotEntry, other: DeviceSnapshotEntry) bool {
        return self.fingerprint() == other.fingerprint();
    }

    pub fn fingerprint(self: DeviceSnapshotEntry) u64 {
        if (self.metadata_fingerprint != 0) return self.metadata_fingerprint;
        return deviceMetadataFingerprint(self.host, self.id, self.name, self.description, self.direction, self.available);
    }
};

fn deviceMetadataFingerprint(
    host: HostId,
    id: []const u8,
    name: []const u8,
    description: ?[]const u8,
    direction: DeviceDirection,
    available: bool,
) u64 {
    var hasher = std.hash.Wyhash.init(0);
    hasher.update(@tagName(host));
    hasher.update(&.{0});
    hasher.update(id);
    hasher.update(&.{0});
    hasher.update(name);
    hasher.update(&.{0});
    if (description) |text| hasher.update(text);
    hasher.update(&.{0});
    hasher.update(@tagName(direction));
    hasher.update(&.{0});
    hasher.update(if (available) "available" else "unavailable");
    const value = hasher.final();
    return if (value == 0) 1 else value;
}

fn monotonicNowNs() u64 {
    const now = stream.StreamInstant.nowMonotonic().nanos;
    return if (now > std.math.maxInt(u64)) std.math.maxInt(u64) else @intCast(now);
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

pub const DeviceSnapshot = struct {
    allocator: std.mem.Allocator,
    items: []DeviceSnapshotEntry,

    pub fn deinit(self: *DeviceSnapshot) void {
        for (self.items) |*item| item.deinit(self.allocator);
        self.allocator.free(self.items);
        self.* = .{ .allocator = self.allocator, .items = &.{} };
    }
};

pub const DeviceSnapshotTracker = struct {
    allocator: std.mem.Allocator,
    current: DeviceSnapshot,

    pub fn init(host: Host, allocator: std.mem.Allocator) AudioError!DeviceSnapshotTracker {
        return .{
            .allocator = allocator,
            .current = try host.snapshotDevices(allocator),
        };
    }

    pub fn deinit(self: *DeviceSnapshotTracker) void {
        self.current.deinit();
        self.* = .{
            .allocator = self.allocator,
            .current = .{ .allocator = self.allocator, .items = &.{} },
        };
    }

    pub fn snapshot(self: DeviceSnapshotTracker) []const DeviceSnapshotEntry {
        return self.current.items;
    }

    pub fn refresh(self: *DeviceSnapshotTracker, host: Host) AudioError![]DeviceSnapshotChange {
        var next = try host.snapshotDevices(self.allocator);
        errdefer next.deinit();

        const changes = try diffDeviceSnapshots(self.allocator, self.current.items, next.items);
        self.current.deinit();
        self.current = next;
        return changes;
    }
};

pub const DeviceSnapshotMonitor = struct {
    tracker: DeviceSnapshotTracker,
    poll_interval_ns: u64,

    pub fn init(
        host: Host,
        allocator: std.mem.Allocator,
        poll_interval_ns: u64,
    ) AudioError!DeviceSnapshotMonitor {
        return .{
            .tracker = try host.snapshotTracker(allocator),
            .poll_interval_ns = @max(poll_interval_ns, std.time.ns_per_ms),
        };
    }

    pub fn deinit(self: *DeviceSnapshotMonitor) void {
        self.tracker.deinit();
    }

    pub fn snapshot(self: DeviceSnapshotMonitor) []const DeviceSnapshotEntry {
        return self.tracker.snapshot();
    }

    pub fn poll(self: *DeviceSnapshotMonitor, host: Host) AudioError![]DeviceSnapshotChange {
        return self.tracker.refresh(host);
    }

    pub fn waitForChanges(
        self: *DeviceSnapshotMonitor,
        host: Host,
        timeout_ns: u64,
    ) AudioError![]DeviceSnapshotChange {
        const start_ns = monotonicNowNs();
        while (true) {
            const changes = try self.poll(host);
            if (changes.len > 0) return changes;

            const elapsed_ns = monotonicNowNs() -| start_ns;
            if (elapsed_ns >= timeout_ns) return changes;
            freeDeviceSnapshotChanges(self.tracker.allocator, changes);

            const wait_ns = @min(self.poll_interval_ns, timeout_ns - elapsed_ns);
            if (host.supportsDeviceChangeSignals()) {
                _ = try host.waitForDeviceChangeSignal(self.tracker.allocator, wait_ns);
            } else {
                sleepNs(wait_ns);
            }
        }
    }
};

pub const DeviceSnapshotChangeKind = enum {
    added,
    removed,
    changed,
};

pub const DeviceSnapshotChange = struct {
    kind: DeviceSnapshotChangeKind,
    item: DeviceSnapshotEntry,
    previous: ?DeviceSnapshotEntry = null,

    pub fn availabilityChanged(self: DeviceSnapshotChange) bool {
        const previous = self.previous orelse return false;
        return self.item.available != previous.available;
    }

    pub fn nameChanged(self: DeviceSnapshotChange) bool {
        const previous = self.previous orelse return false;
        return !std.mem.eql(u8, self.item.name, previous.name);
    }

    pub fn descriptionChanged(self: DeviceSnapshotChange) bool {
        const previous = self.previous orelse return false;
        if (self.item.description == null and previous.description == null) return false;
        if (self.item.description == null or previous.description == null) return true;
        return !std.mem.eql(u8, self.item.description.?, previous.description.?);
    }

    pub fn directionChanged(self: DeviceSnapshotChange) bool {
        const previous = self.previous orelse return false;
        return self.item.direction != previous.direction;
    }

    pub fn metadataChanged(self: DeviceSnapshotChange) bool {
        const previous = self.previous orelse return false;
        return self.item.fingerprint() != previous.fingerprint();
    }

    pub fn deinit(self: *DeviceSnapshotChange, allocator: std.mem.Allocator) void {
        self.item.deinit(allocator);
        if (self.previous) |*previous| previous.deinit(allocator);
    }
};

pub fn freeDeviceSnapshotChanges(allocator: std.mem.Allocator, changes: []DeviceSnapshotChange) void {
    for (changes) |*change| change.deinit(allocator);
    allocator.free(changes);
}

pub fn diffDeviceSnapshots(
    allocator: std.mem.Allocator,
    before: []const DeviceSnapshotEntry,
    after: []const DeviceSnapshotEntry,
) AudioError![]DeviceSnapshotChange {
    var changes: std.ArrayList(DeviceSnapshotChange) = .empty;
    const matched_after = try allocator.alloc(bool, after.len);
    defer allocator.free(matched_after);
    @memset(matched_after, false);

    errdefer {
        for (changes.items) |*change| change.deinit(allocator);
        changes.deinit(allocator);
    }

    for (before) |before_item| {
        const allow_direction_fallback =
            !hasDuplicateSnapshotIdentity(before, before_item) and
            !hasDuplicateSnapshotIdentity(after, before_item);
        const maybe_after_index = findBestSnapshotEntryIndex(after, matched_after, before_item, allow_direction_fallback);
        if (maybe_after_index == null) {
            try changes.append(allocator, .{
                .kind = .removed,
                .item = try before_item.clone(allocator),
            });
        } else {
            const after_index = maybe_after_index.?;
            matched_after[after_index] = true;
            const after_item = after[after_index];
            if (!before_item.sameMetadata(after_item)) {
                try changes.append(allocator, .{
                    .kind = .changed,
                    .item = try after_item.clone(allocator),
                    .previous = try before_item.clone(allocator),
                });
            }
        }
    }

    for (after, 0..) |after_item, index| {
        if (!matched_after[index]) {
            try changes.append(allocator, .{
                .kind = .added,
                .item = try after_item.clone(allocator),
            });
        }
    }

    return changes.toOwnedSlice(allocator);
}

fn findBestSnapshotEntryIndex(
    items: []const DeviceSnapshotEntry,
    matched: []const bool,
    needle: DeviceSnapshotEntry,
    allow_direction_fallback: bool,
) ?usize {
    var fallback: ?usize = null;
    for (items, 0..) |item, index| {
        if (matched[index]) continue;
        if (!item.sameIdentity(needle)) continue;
        if (item.sameEndpoint(needle)) return index;
        if (allow_direction_fallback and fallback == null) fallback = index;
    }
    return fallback;
}

fn hasDuplicateSnapshotIdentity(items: []const DeviceSnapshotEntry, needle: DeviceSnapshotEntry) bool {
    var count: usize = 0;
    for (items) |item| {
        if (item.sameIdentity(needle)) {
            count += 1;
            if (count > 1) return true;
        }
    }
    return false;
}

fn findSnapshotEntry(items: []const DeviceSnapshotEntry, needle: DeviceSnapshotEntry) ?DeviceSnapshotEntry {
    for (items) |item| {
        if (item.sameIdentity(needle)) return item;
    }
    return null;
}

pub const Device = union(HostId) {
    alsa: backends.alsa.Device,
    coreaudio: backends.stub.Device,
    wasapi: backends.stub.Device,
    jack: backends.stub.Device,
    pulseaudio: backends.stub.Device,
    null: backends.null_backend.Device,

    pub fn deinit(self: *Device, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .alsa => |*device| device.deinit(allocator),
            .coreaudio, .wasapi, .jack, .pulseaudio => |*device| device.deinit(allocator),
            .null => |*device| device.deinit(allocator),
        }
    }

    pub fn info(self: Device) DeviceInfo {
        return switch (self) {
            .alsa => |device| device.info(),
            .coreaudio, .wasapi, .jack, .pulseaudio => |device| device.info(),
            .null => |device| device.info(),
        };
    }

    pub fn isAvailable(self: Device) bool {
        return switch (self) {
            .alsa => |device| device.isAvailable(),
            .coreaudio, .wasapi, .jack, .pulseaudio => |device| device.isAvailable(),
            .null => |device| device.isAvailable(),
        };
    }

    pub fn supportedOutputConfigs(
        self: Device,
        allocator: std.mem.Allocator,
    ) AudioError![]SupportedStreamConfigRange {
        return switch (self) {
            .alsa => |device| device.supportedOutputConfigs(allocator),
            .coreaudio, .wasapi, .jack, .pulseaudio => |device| device.supportedOutputConfigs(allocator),
            .null => |device| device.supportedOutputConfigs(allocator),
        };
    }

    pub fn supportedInputConfigs(
        self: Device,
        allocator: std.mem.Allocator,
    ) AudioError![]SupportedStreamConfigRange {
        return switch (self) {
            .alsa => |device| device.supportedInputConfigs(allocator),
            .coreaudio, .wasapi, .jack, .pulseaudio => |device| device.supportedInputConfigs(allocator),
            .null => |device| device.supportedInputConfigs(allocator),
        };
    }

    pub fn supportedOutputCapabilities(
        self: Device,
        allocator: std.mem.Allocator,
    ) AudioError![]StreamCapability {
        return switch (self) {
            .alsa => |device| device.supportedOutputCapabilities(allocator),
            .coreaudio, .wasapi, .jack, .pulseaudio => |device| device.supportedOutputCapabilities(allocator),
            .null => |device| device.supportedOutputCapabilities(allocator),
        };
    }

    pub fn supportedInputCapabilities(
        self: Device,
        allocator: std.mem.Allocator,
    ) AudioError![]StreamCapability {
        return switch (self) {
            .alsa => |device| device.supportedInputCapabilities(allocator),
            .coreaudio, .wasapi, .jack, .pulseaudio => |device| device.supportedInputCapabilities(allocator),
            .null => |device| device.supportedInputCapabilities(allocator),
        };
    }

    pub fn defaultOutputConfig(self: Device) AudioError!SupportedStreamConfig {
        return switch (self) {
            .alsa => |device| device.defaultOutputConfig(),
            .coreaudio, .wasapi, .jack, .pulseaudio => |device| device.defaultOutputConfig(),
            .null => |device| device.defaultOutputConfig(),
        };
    }

    pub fn defaultInputConfig(self: Device) AudioError!SupportedStreamConfig {
        return switch (self) {
            .alsa => |device| device.defaultInputConfig(),
            .coreaudio, .wasapi, .jack, .pulseaudio => |device| device.defaultInputConfig(),
            .null => |device| device.defaultInputConfig(),
        };
    }

    pub fn negotiateOutputConfig(
        self: Device,
        allocator: std.mem.Allocator,
        request: StreamConfigRequest,
    ) AudioError!NegotiatedStreamConfig {
        const capabilities = try self.supportedOutputCapabilities(allocator);
        defer allocator.free(capabilities);
        return negotiateStreamCapability(capabilities, request);
    }

    pub fn negotiateInputConfig(
        self: Device,
        allocator: std.mem.Allocator,
        request: StreamConfigRequest,
    ) AudioError!NegotiatedStreamConfig {
        const capabilities = try self.supportedInputCapabilities(allocator);
        defer allocator.free(capabilities);
        return negotiateStreamCapability(capabilities, request);
    }

    pub fn buildOutputStreamF32(
        self: Device,
        config_value: StreamConfig,
        callback: OutputCallbackF32,
        userdata: ?*anyopaque,
        error_callback: ?StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) AudioError!stream.Stream {
        return switch (self) {
            .alsa => |device| .{ .alsa = try device.buildOutputStreamF32(config_value, callback, userdata, error_callback, error_userdata) },
            .coreaudio, .wasapi, .jack, .pulseaudio => |device| .{ .stub = try device.buildOutputStreamF32(config_value, callback, userdata, error_callback, error_userdata) },
            .null => |device| .{ .null = try device.buildOutputStreamF32(config_value, callback, userdata, error_callback, error_userdata) },
        };
    }

    pub fn buildOutputStream(
        self: Device,
        comptime Sample: type,
        config_value: StreamConfig,
        callback: OutputCallback(Sample),
        userdata: ?*anyopaque,
        error_callback: ?StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) AudioError!stream.Stream {
        const sample_format = comptime sampleFormatForType(Sample) orelse
            @compileError("unsupported output stream sample type");
        return switch (sample_format) {
            .f32 => self.buildOutputStreamF32(config_value, callback, userdata, error_callback, error_userdata),
            .i8 => self.buildOutputStreamI8(config_value, callback, userdata, error_callback, error_userdata),
            .u8 => self.buildOutputStreamU8(config_value, callback, userdata, error_callback, error_userdata),
            .i16 => self.buildOutputStreamI16(config_value, callback, userdata, error_callback, error_userdata),
            .u16 => self.buildOutputStreamU16(config_value, callback, userdata, error_callback, error_userdata),
            .i32 => self.buildOutputStreamI32(config_value, callback, userdata, error_callback, error_userdata),
            .u32 => self.buildOutputStreamU32(config_value, callback, userdata, error_callback, error_userdata),
            .f64 => self.buildOutputStreamF64(config_value, callback, userdata, error_callback, error_userdata),
            else => unreachable,
        };
    }

    pub fn buildInputStream(
        self: Device,
        comptime Sample: type,
        config_value: StreamConfig,
        callback: InputCallback(Sample),
        userdata: ?*anyopaque,
        error_callback: ?StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) AudioError!stream.Stream {
        const sample_format = comptime sampleFormatForType(Sample) orelse
            @compileError("unsupported input stream sample type");
        return switch (sample_format) {
            .f32 => self.buildInputStreamF32(config_value, callback, userdata, error_callback, error_userdata),
            .i8 => self.buildInputStreamI8(config_value, callback, userdata, error_callback, error_userdata),
            .u8 => self.buildInputStreamU8(config_value, callback, userdata, error_callback, error_userdata),
            .i16 => self.buildInputStreamI16(config_value, callback, userdata, error_callback, error_userdata),
            .u16 => self.buildInputStreamU16(config_value, callback, userdata, error_callback, error_userdata),
            .i32 => self.buildInputStreamI32(config_value, callback, userdata, error_callback, error_userdata),
            .u32 => self.buildInputStreamU32(config_value, callback, userdata, error_callback, error_userdata),
            .f64 => self.buildInputStreamF64(config_value, callback, userdata, error_callback, error_userdata),
            else => unreachable,
        };
    }

    pub fn buildInputStreamF32(
        self: Device,
        config_value: StreamConfig,
        callback: InputCallbackF32,
        userdata: ?*anyopaque,
        error_callback: ?StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) AudioError!stream.Stream {
        return switch (self) {
            .alsa => |device| .{ .alsa = try device.buildInputStreamF32(config_value, callback, userdata, error_callback, error_userdata) },
            .coreaudio, .wasapi, .jack, .pulseaudio => |device| .{ .stub = try device.buildInputStreamF32(config_value, callback, userdata, error_callback, error_userdata) },
            .null => |device| .{ .null = try device.buildInputStreamF32(config_value, callback, userdata, error_callback, error_userdata) },
        };
    }

    pub fn buildOutputStreamI8(
        self: Device,
        config_value: StreamConfig,
        callback: OutputCallbackI8,
        userdata: ?*anyopaque,
        error_callback: ?StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) AudioError!stream.Stream {
        return switch (self) {
            .alsa => |device| .{ .alsa = try device.buildOutputStreamI8(config_value, callback, userdata, error_callback, error_userdata) },
            .coreaudio, .wasapi, .jack, .pulseaudio => |device| .{ .stub = try device.buildOutputStreamI8(config_value, callback, userdata, error_callback, error_userdata) },
            .null => |device| .{ .null = try device.buildOutputStreamI8(config_value, callback, userdata, error_callback, error_userdata) },
        };
    }

    pub fn buildInputStreamI8(
        self: Device,
        config_value: StreamConfig,
        callback: InputCallbackI8,
        userdata: ?*anyopaque,
        error_callback: ?StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) AudioError!stream.Stream {
        return switch (self) {
            .alsa => |device| .{ .alsa = try device.buildInputStreamI8(config_value, callback, userdata, error_callback, error_userdata) },
            .coreaudio, .wasapi, .jack, .pulseaudio => |device| .{ .stub = try device.buildInputStreamI8(config_value, callback, userdata, error_callback, error_userdata) },
            .null => |device| .{ .null = try device.buildInputStreamI8(config_value, callback, userdata, error_callback, error_userdata) },
        };
    }

    pub fn buildOutputStreamU8(
        self: Device,
        config_value: StreamConfig,
        callback: OutputCallbackU8,
        userdata: ?*anyopaque,
        error_callback: ?StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) AudioError!stream.Stream {
        return switch (self) {
            .alsa => |device| .{ .alsa = try device.buildOutputStreamU8(config_value, callback, userdata, error_callback, error_userdata) },
            .coreaudio, .wasapi, .jack, .pulseaudio => |device| .{ .stub = try device.buildOutputStreamU8(config_value, callback, userdata, error_callback, error_userdata) },
            .null => |device| .{ .null = try device.buildOutputStreamU8(config_value, callback, userdata, error_callback, error_userdata) },
        };
    }

    pub fn buildInputStreamU8(
        self: Device,
        config_value: StreamConfig,
        callback: InputCallbackU8,
        userdata: ?*anyopaque,
        error_callback: ?StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) AudioError!stream.Stream {
        return switch (self) {
            .alsa => |device| .{ .alsa = try device.buildInputStreamU8(config_value, callback, userdata, error_callback, error_userdata) },
            .coreaudio, .wasapi, .jack, .pulseaudio => |device| .{ .stub = try device.buildInputStreamU8(config_value, callback, userdata, error_callback, error_userdata) },
            .null => |device| .{ .null = try device.buildInputStreamU8(config_value, callback, userdata, error_callback, error_userdata) },
        };
    }

    pub fn buildOutputStreamI16(
        self: Device,
        config_value: StreamConfig,
        callback: OutputCallbackI16,
        userdata: ?*anyopaque,
        error_callback: ?StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) AudioError!stream.Stream {
        return switch (self) {
            .alsa => |device| .{ .alsa = try device.buildOutputStreamI16(config_value, callback, userdata, error_callback, error_userdata) },
            .coreaudio, .wasapi, .jack, .pulseaudio => |device| .{ .stub = try device.buildOutputStreamI16(config_value, callback, userdata, error_callback, error_userdata) },
            .null => |device| .{ .null = try device.buildOutputStreamI16(config_value, callback, userdata, error_callback, error_userdata) },
        };
    }

    pub fn buildInputStreamI16(
        self: Device,
        config_value: StreamConfig,
        callback: InputCallbackI16,
        userdata: ?*anyopaque,
        error_callback: ?StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) AudioError!stream.Stream {
        return switch (self) {
            .alsa => |device| .{ .alsa = try device.buildInputStreamI16(config_value, callback, userdata, error_callback, error_userdata) },
            .coreaudio, .wasapi, .jack, .pulseaudio => |device| .{ .stub = try device.buildInputStreamI16(config_value, callback, userdata, error_callback, error_userdata) },
            .null => |device| .{ .null = try device.buildInputStreamI16(config_value, callback, userdata, error_callback, error_userdata) },
        };
    }

    pub fn buildOutputStreamU16(
        self: Device,
        config_value: StreamConfig,
        callback: OutputCallbackU16,
        userdata: ?*anyopaque,
        error_callback: ?StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) AudioError!stream.Stream {
        return switch (self) {
            .alsa => |device| .{ .alsa = try device.buildOutputStreamU16(config_value, callback, userdata, error_callback, error_userdata) },
            .coreaudio, .wasapi, .jack, .pulseaudio => |device| .{ .stub = try device.buildOutputStreamU16(config_value, callback, userdata, error_callback, error_userdata) },
            .null => |device| .{ .null = try device.buildOutputStreamU16(config_value, callback, userdata, error_callback, error_userdata) },
        };
    }

    pub fn buildInputStreamU16(
        self: Device,
        config_value: StreamConfig,
        callback: InputCallbackU16,
        userdata: ?*anyopaque,
        error_callback: ?StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) AudioError!stream.Stream {
        return switch (self) {
            .alsa => |device| .{ .alsa = try device.buildInputStreamU16(config_value, callback, userdata, error_callback, error_userdata) },
            .coreaudio, .wasapi, .jack, .pulseaudio => |device| .{ .stub = try device.buildInputStreamU16(config_value, callback, userdata, error_callback, error_userdata) },
            .null => |device| .{ .null = try device.buildInputStreamU16(config_value, callback, userdata, error_callback, error_userdata) },
        };
    }

    pub fn buildOutputStreamI32(
        self: Device,
        config_value: StreamConfig,
        callback: OutputCallbackI32,
        userdata: ?*anyopaque,
        error_callback: ?StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) AudioError!stream.Stream {
        return switch (self) {
            .alsa => |device| .{ .alsa = try device.buildOutputStreamI32(config_value, callback, userdata, error_callback, error_userdata) },
            .coreaudio, .wasapi, .jack, .pulseaudio => |device| .{ .stub = try device.buildOutputStreamI32(config_value, callback, userdata, error_callback, error_userdata) },
            .null => |device| .{ .null = try device.buildOutputStreamI32(config_value, callback, userdata, error_callback, error_userdata) },
        };
    }

    pub fn buildInputStreamI32(
        self: Device,
        config_value: StreamConfig,
        callback: InputCallbackI32,
        userdata: ?*anyopaque,
        error_callback: ?StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) AudioError!stream.Stream {
        return switch (self) {
            .alsa => |device| .{ .alsa = try device.buildInputStreamI32(config_value, callback, userdata, error_callback, error_userdata) },
            .coreaudio, .wasapi, .jack, .pulseaudio => |device| .{ .stub = try device.buildInputStreamI32(config_value, callback, userdata, error_callback, error_userdata) },
            .null => |device| .{ .null = try device.buildInputStreamI32(config_value, callback, userdata, error_callback, error_userdata) },
        };
    }

    pub fn buildOutputStreamU32(
        self: Device,
        config_value: StreamConfig,
        callback: OutputCallbackU32,
        userdata: ?*anyopaque,
        error_callback: ?StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) AudioError!stream.Stream {
        return switch (self) {
            .alsa => |device| .{ .alsa = try device.buildOutputStreamU32(config_value, callback, userdata, error_callback, error_userdata) },
            .coreaudio, .wasapi, .jack, .pulseaudio => |device| .{ .stub = try device.buildOutputStreamU32(config_value, callback, userdata, error_callback, error_userdata) },
            .null => |device| .{ .null = try device.buildOutputStreamU32(config_value, callback, userdata, error_callback, error_userdata) },
        };
    }

    pub fn buildInputStreamU32(
        self: Device,
        config_value: StreamConfig,
        callback: InputCallbackU32,
        userdata: ?*anyopaque,
        error_callback: ?StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) AudioError!stream.Stream {
        return switch (self) {
            .alsa => |device| .{ .alsa = try device.buildInputStreamU32(config_value, callback, userdata, error_callback, error_userdata) },
            .coreaudio, .wasapi, .jack, .pulseaudio => |device| .{ .stub = try device.buildInputStreamU32(config_value, callback, userdata, error_callback, error_userdata) },
            .null => |device| .{ .null = try device.buildInputStreamU32(config_value, callback, userdata, error_callback, error_userdata) },
        };
    }

    pub fn buildOutputStreamF64(
        self: Device,
        config_value: StreamConfig,
        callback: OutputCallbackF64,
        userdata: ?*anyopaque,
        error_callback: ?StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) AudioError!stream.Stream {
        return switch (self) {
            .alsa => |device| .{ .alsa = try device.buildOutputStreamF64(config_value, callback, userdata, error_callback, error_userdata) },
            .coreaudio, .wasapi, .jack, .pulseaudio => |device| .{ .stub = try device.buildOutputStreamF64(config_value, callback, userdata, error_callback, error_userdata) },
            .null => |device| .{ .null = try device.buildOutputStreamF64(config_value, callback, userdata, error_callback, error_userdata) },
        };
    }

    pub fn buildInputStreamF64(
        self: Device,
        config_value: StreamConfig,
        callback: InputCallbackF64,
        userdata: ?*anyopaque,
        error_callback: ?StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) AudioError!stream.Stream {
        return switch (self) {
            .alsa => |device| .{ .alsa = try device.buildInputStreamF64(config_value, callback, userdata, error_callback, error_userdata) },
            .coreaudio, .wasapi, .jack, .pulseaudio => |device| .{ .stub = try device.buildInputStreamF64(config_value, callback, userdata, error_callback, error_userdata) },
            .null => |device| .{ .null = try device.buildInputStreamF64(config_value, callback, userdata, error_callback, error_userdata) },
        };
    }
};

pub const DeviceList = struct {
    allocator: std.mem.Allocator,
    items: []Device,

    pub fn deinit(self: *DeviceList) void {
        for (self.items) |*device| device.deinit(self.allocator);
        self.allocator.free(self.items);
        self.* = .{ .allocator = self.allocator, .items = &.{} };
    }
};

pub const Host = union(HostId) {
    alsa: backends.alsa.Host,
    coreaudio: backends.stub.Host,
    wasapi: backends.stub.Host,
    jack: backends.stub.Host,
    pulseaudio: backends.stub.Host,
    null: backends.null_backend.Host,

    pub fn id(self: Host) HostId {
        return switch (self) {
            .alsa => .alsa,
            .coreaudio => .coreaudio,
            .wasapi => .wasapi,
            .jack => .jack,
            .pulseaudio => .pulseaudio,
            .null => .null,
        };
    }

    pub fn deinit(self: *Host, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .alsa => |*host| host.deinit(allocator),
            .coreaudio, .wasapi, .jack, .pulseaudio => |*host| host.deinit(allocator),
            .null => |*host| host.deinit(allocator),
        }
    }

    pub fn devices(self: Host, allocator: std.mem.Allocator) AudioError!DeviceList {
        var list: std.ArrayList(Device) = .empty;
        errdefer {
            for (list.items) |*device| device.deinit(allocator);
            list.deinit(allocator);
        }

        switch (self) {
            .alsa => |host| {
                const backend_devices = try host.devices(allocator);
                defer allocator.free(backend_devices.items);
                for (backend_devices.items) |backend_device| {
                    try list.append(allocator, .{ .alsa = backend_device });
                }
            },
            .coreaudio => |host| {
                const backend_devices = try host.devices(allocator);
                defer allocator.free(backend_devices.items);
                for (backend_devices.items) |backend_device| {
                    try list.append(allocator, .{ .coreaudio = backend_device });
                }
            },
            .wasapi => |host| {
                const backend_devices = try host.devices(allocator);
                defer allocator.free(backend_devices.items);
                for (backend_devices.items) |backend_device| {
                    try list.append(allocator, .{ .wasapi = backend_device });
                }
            },
            .jack => |host| {
                const backend_devices = try host.devices(allocator);
                defer allocator.free(backend_devices.items);
                for (backend_devices.items) |backend_device| {
                    try list.append(allocator, .{ .jack = backend_device });
                }
            },
            .pulseaudio => |host| {
                const backend_devices = try host.devices(allocator);
                defer allocator.free(backend_devices.items);
                for (backend_devices.items) |backend_device| {
                    try list.append(allocator, .{ .pulseaudio = backend_device });
                }
            },
            .null => |host| {
                const backend_devices = try host.devices(allocator);
                defer allocator.free(backend_devices.items);
                for (backend_devices.items) |backend_device| {
                    try list.append(allocator, .{ .null = backend_device });
                }
            },
        }

        return .{ .allocator = allocator, .items = try list.toOwnedSlice(allocator) };
    }

    pub fn defaultOutputDevice(self: Host, allocator: std.mem.Allocator) AudioError!?Device {
        return switch (self) {
            .alsa => |host| if (try host.defaultOutputDevice(allocator)) |device| .{ .alsa = device } else null,
            .coreaudio => |host| if (try host.defaultOutputDevice(allocator)) |device| .{ .coreaudio = device } else null,
            .wasapi => |host| if (try host.defaultOutputDevice(allocator)) |device| .{ .wasapi = device } else null,
            .jack => |host| if (try host.defaultOutputDevice(allocator)) |device| .{ .jack = device } else null,
            .pulseaudio => |host| if (try host.defaultOutputDevice(allocator)) |device| .{ .pulseaudio = device } else null,
            .null => |host| if (try host.defaultOutputDevice(allocator)) |device| .{ .null = device } else null,
        };
    }

    pub fn defaultInputDevice(self: Host, allocator: std.mem.Allocator) AudioError!?Device {
        return switch (self) {
            .alsa => |host| if (try host.defaultInputDevice(allocator)) |device| .{ .alsa = device } else null,
            .coreaudio => |host| if (try host.defaultInputDevice(allocator)) |device| .{ .coreaudio = device } else null,
            .wasapi => |host| if (try host.defaultInputDevice(allocator)) |device| .{ .wasapi = device } else null,
            .jack => |host| if (try host.defaultInputDevice(allocator)) |device| .{ .jack = device } else null,
            .pulseaudio => |host| if (try host.defaultInputDevice(allocator)) |device| .{ .pulseaudio = device } else null,
            .null => |host| if (try host.defaultInputDevice(allocator)) |device| .{ .null = device } else null,
        };
    }

    pub fn supportsDeviceChangeSignals(self: Host) bool {
        return switch (self) {
            .alsa => |host| host.supportsDeviceChangeSignals(),
            .coreaudio, .wasapi, .jack, .pulseaudio, .null => false,
        };
    }

    pub fn waitForDeviceChangeSignal(
        self: Host,
        allocator: std.mem.Allocator,
        timeout_ns: u64,
    ) AudioError!bool {
        return switch (self) {
            .alsa => |host| host.waitForDeviceChangeSignal(allocator, timeout_ns),
            .coreaudio, .wasapi, .jack, .pulseaudio, .null => false,
        };
    }

    pub fn snapshotDevices(self: Host, allocator: std.mem.Allocator) AudioError!DeviceSnapshot {
        var devices_value = try self.devices(allocator);
        defer devices_value.deinit();

        const items = try allocator.alloc(DeviceSnapshotEntry, devices_value.items.len);
        var initialized: usize = 0;
        errdefer {
            for (items[0..initialized]) |*item| item.deinit(allocator);
            allocator.free(items);
        }

        for (devices_value.items, 0..) |device, index| {
            const info_value = device.info();
            items[index] = try (DeviceSnapshotEntry{
                .host = info_value.host,
                .id = info_value.id,
                .name = info_value.name,
                .description = info_value.description,
                .direction = info_value.direction,
                .available = device.isAvailable(),
            }).clone(allocator);
            initialized += 1;
        }

        return .{ .allocator = allocator, .items = items };
    }

    pub fn snapshotTracker(self: Host, allocator: std.mem.Allocator) AudioError!DeviceSnapshotTracker {
        return DeviceSnapshotTracker.init(self, allocator);
    }

    pub fn snapshotMonitor(
        self: Host,
        allocator: std.mem.Allocator,
        poll_interval_ns: u64,
    ) AudioError!DeviceSnapshotMonitor {
        return DeviceSnapshotMonitor.init(self, allocator, poll_interval_ns);
    }
};

pub fn availableHosts(allocator: std.mem.Allocator) AudioError![]HostId {
    var ids: std.ArrayList(HostId) = .empty;
    errdefer ids.deinit(allocator);

    if (builtin.os.tag == .linux and backends.alsa.Host.isAvailable()) {
        try ids.append(allocator, .alsa);
    }

    try ids.append(allocator, .null);
    return ids.toOwnedSlice(allocator);
}

pub fn hostFromId(id_value: HostId) AudioError!Host {
    return switch (id_value) {
        .alsa => if (builtin.os.tag == .linux)
            .{ .alsa = try backends.alsa.Host.init() }
        else
            AudioError.BackendUnavailable,
        .coreaudio => .{ .coreaudio = backends.stub.Host.init(.coreaudio) },
        .wasapi => .{ .wasapi = backends.stub.Host.init(.wasapi) },
        .jack => .{ .jack = backends.stub.Host.init(.jack) },
        .pulseaudio => .{ .pulseaudio = backends.stub.Host.init(.pulseaudio) },
        .null => .{ .null = backends.null_backend.Host.init() },
    };
}

pub fn defaultHost() AudioError!Host {
    if (builtin.os.tag == .linux and backends.alsa.Host.isAvailable()) {
        return .{ .alsa = try backends.alsa.Host.init() };
    }
    return .{ .null = backends.null_backend.Host.init() };
}

test {
    _ = config;
    _ = stream;
    _ = backends;
}

test "device snapshot tracker refresh reports no changes for stable null host" {
    const allocator = std.testing.allocator;
    var host = try hostFromId(.null);
    defer host.deinit(allocator);

    var tracker = try host.snapshotTracker(allocator);
    defer tracker.deinit();
    try std.testing.expectEqual(@as(usize, 2), tracker.snapshot().len);
    try std.testing.expect(tracker.snapshot()[0].fingerprint() != 0);

    const changes = try tracker.refresh(host);
    defer freeDeviceSnapshotChanges(allocator, changes);
    try std.testing.expectEqual(@as(usize, 0), changes.len);
    try std.testing.expectEqual(@as(usize, 2), tracker.snapshot().len);
}

test "device snapshot monitor wait returns empty changes for stable null host" {
    const allocator = std.testing.allocator;
    var host = try hostFromId(.null);
    defer host.deinit(allocator);

    var monitor = try host.snapshotMonitor(allocator, std.time.ns_per_ms);
    defer monitor.deinit();
    try std.testing.expectEqual(@as(usize, 2), monitor.snapshot().len);

    const changes = try monitor.waitForChanges(host, 0);
    defer freeDeviceSnapshotChanges(allocator, changes);
    try std.testing.expectEqual(@as(usize, 0), changes.len);
}

test "null host reports no native device change signal support" {
    const allocator = std.testing.allocator;
    var host = try hostFromId(.null);
    defer host.deinit(allocator);

    try std.testing.expect(!host.supportsDeviceChangeSignals());
    try std.testing.expect(!try host.waitForDeviceChangeSignal(allocator, 0));
}

test "host identifiers expose stable and display names" {
    try std.testing.expectEqualStrings("alsa", HostId.alsa.stableName());
    try std.testing.expectEqualStrings("ALSA", HostId.alsa.name());
}

test "available hosts always includes null fallback" {
    const allocator = std.testing.allocator;
    const ids = try availableHosts(allocator);
    defer allocator.free(ids);
    try std.testing.expect(ids.len >= 1);
    try std.testing.expect(ids[ids.len - 1] == .null);
}

test "device snapshot identity can distinguish directional endpoints" {
    const output = DeviceSnapshotEntry{ .host = .alsa, .id = "default", .name = "Default output", .direction = .output };
    const input = DeviceSnapshotEntry{ .host = .alsa, .id = "default", .name = "Default input", .direction = .input };
    const renamed_output = DeviceSnapshotEntry{ .host = .alsa, .id = "default", .name = "Renamed output", .direction = .output };

    try std.testing.expect(output.sameIdentity(input));
    try std.testing.expect(!output.sameEndpoint(input));
    try std.testing.expect(output.sameEndpoint(renamed_output));
}

test "device snapshot diff reports added removed and changed entries" {
    const allocator = std.testing.allocator;
    const before = [_]DeviceSnapshotEntry{
        .{ .host = .alsa, .id = "a", .name = "Old A", .direction = .output },
        .{ .host = .alsa, .id = "b", .name = "B", .direction = .input },
        .{ .host = .alsa, .id = "d", .name = "D", .description = "Old D", .direction = .duplex },
        .{ .host = .alsa, .id = "e", .name = "E", .direction = .output, .available = true },
        .{ .host = .alsa, .id = "f", .name = "F", .direction = .input },
    };
    const after = [_]DeviceSnapshotEntry{
        .{ .host = .alsa, .id = "a", .name = "New A", .direction = .output },
        .{ .host = .alsa, .id = "c", .name = "C", .direction = .duplex },
        .{ .host = .alsa, .id = "d", .name = "D", .description = "New D", .direction = .duplex },
        .{ .host = .alsa, .id = "e", .name = "E", .direction = .output, .available = false },
        .{ .host = .alsa, .id = "f", .name = "F", .direction = .duplex },
    };

    const changes = try diffDeviceSnapshots(allocator, &before, &after);
    defer freeDeviceSnapshotChanges(allocator, changes);

    try std.testing.expectEqual(@as(usize, 6), changes.len);
    try std.testing.expectEqual(DeviceSnapshotChangeKind.changed, changes[0].kind);
    try std.testing.expectEqualStrings("a", changes[0].item.id);
    try std.testing.expectEqualStrings("New A", changes[0].item.name);
    try std.testing.expect(changes[0].item.fingerprint() != before[0].fingerprint());
    try std.testing.expect(changes[0].previous != null);
    try std.testing.expectEqualStrings("Old A", changes[0].previous.?.name);
    try std.testing.expectEqual(before[0].fingerprint(), changes[0].previous.?.fingerprint());
    try std.testing.expect(changes[0].metadataChanged());
    try std.testing.expect(changes[0].nameChanged());
    try std.testing.expect(!changes[0].descriptionChanged());
    try std.testing.expect(!changes[0].directionChanged());
    try std.testing.expect(!changes[0].availabilityChanged());
    try std.testing.expectEqual(DeviceSnapshotChangeKind.removed, changes[1].kind);
    try std.testing.expectEqualStrings("b", changes[1].item.id);
    try std.testing.expect(changes[1].previous == null);
    try std.testing.expect(!changes[1].metadataChanged());
    try std.testing.expect(!changes[1].nameChanged());
    try std.testing.expect(!changes[1].descriptionChanged());
    try std.testing.expect(!changes[1].directionChanged());
    try std.testing.expect(!changes[1].availabilityChanged());
    try std.testing.expectEqual(DeviceSnapshotChangeKind.changed, changes[2].kind);
    try std.testing.expectEqualStrings("d", changes[2].item.id);
    try std.testing.expectEqualStrings("New D", changes[2].item.description.?);
    try std.testing.expect(changes[2].item.fingerprint() != before[2].fingerprint());
    try std.testing.expect(changes[2].previous != null);
    try std.testing.expectEqualStrings("Old D", changes[2].previous.?.description.?);
    try std.testing.expect(changes[2].metadataChanged());
    try std.testing.expect(!changes[2].nameChanged());
    try std.testing.expect(changes[2].descriptionChanged());
    try std.testing.expect(!changes[2].directionChanged());
    try std.testing.expect(!changes[2].availabilityChanged());
    try std.testing.expectEqual(DeviceSnapshotChangeKind.changed, changes[3].kind);
    try std.testing.expectEqualStrings("e", changes[3].item.id);
    try std.testing.expect(!changes[3].item.available);
    try std.testing.expect(changes[3].previous != null);
    try std.testing.expect(changes[3].previous.?.available);
    try std.testing.expect(changes[3].metadataChanged());
    try std.testing.expect(!changes[3].nameChanged());
    try std.testing.expect(!changes[3].descriptionChanged());
    try std.testing.expect(!changes[3].directionChanged());
    try std.testing.expect(changes[3].availabilityChanged());
    try std.testing.expectEqual(DeviceSnapshotChangeKind.changed, changes[4].kind);
    try std.testing.expectEqualStrings("f", changes[4].item.id);
    try std.testing.expectEqual(DeviceDirection.duplex, changes[4].item.direction);
    try std.testing.expect(changes[4].previous != null);
    try std.testing.expectEqual(DeviceDirection.input, changes[4].previous.?.direction);
    try std.testing.expect(changes[4].metadataChanged());
    try std.testing.expect(!changes[4].nameChanged());
    try std.testing.expect(!changes[4].descriptionChanged());
    try std.testing.expect(changes[4].directionChanged());
    try std.testing.expect(!changes[4].availabilityChanged());
    try std.testing.expectEqual(DeviceSnapshotChangeKind.added, changes[5].kind);
    try std.testing.expectEqualStrings("c", changes[5].item.id);
    try std.testing.expect(changes[5].previous == null);
    try std.testing.expect(!changes[5].metadataChanged());
    try std.testing.expect(!changes[5].nameChanged());
    try std.testing.expect(!changes[5].descriptionChanged());
    try std.testing.expect(!changes[5].directionChanged());
    try std.testing.expect(!changes[5].availabilityChanged());
}

test "device snapshot diff keeps duplicate directional device ids distinct" {
    const allocator = std.testing.allocator;
    const before = [_]DeviceSnapshotEntry{
        .{ .host = .alsa, .id = "default", .name = "Default ALSA output", .direction = .output },
        .{ .host = .alsa, .id = "default", .name = "Default ALSA input", .direction = .input },
    };
    const after = [_]DeviceSnapshotEntry{
        .{ .host = .alsa, .id = "default", .name = "Default ALSA input", .direction = .input },
    };

    const changes = try diffDeviceSnapshots(allocator, &before, &after);
    defer freeDeviceSnapshotChanges(allocator, changes);

    try std.testing.expectEqual(@as(usize, 1), changes.len);
    try std.testing.expectEqual(DeviceSnapshotChangeKind.removed, changes[0].kind);
    try std.testing.expectEqualStrings("default", changes[0].item.id);
    try std.testing.expectEqual(DeviceDirection.output, changes[0].item.direction);
    try std.testing.expect(changes[0].previous == null);
}
