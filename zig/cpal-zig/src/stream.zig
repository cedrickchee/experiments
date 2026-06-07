const std = @import("std");
const root = @import("root.zig");
const backends = @import("backends/root.zig");

pub const StreamInstant = struct {
    nanos: u128,

    pub const zero: StreamInstant = .{ .nanos = 0 };

    pub fn nowMonotonic() StreamInstant {
        if (@import("builtin").os.tag == .linux) {
            var ts: std.os.linux.timespec = undefined;
            _ = std.os.linux.clock_gettime(.MONOTONIC, &ts);
            return .{
                .nanos = @as(u128, @intCast(ts.sec)) * std.time.ns_per_s +
                    @as(u128, @intCast(ts.nsec)),
            };
        }
        return zero;
    }

    pub fn durationSince(self: StreamInstant, earlier: StreamInstant) u64 {
        if (self.nanos <= earlier.nanos) return 0;
        const delta = self.nanos - earlier.nanos;
        return if (delta > std.math.maxInt(u64)) std.math.maxInt(u64) else @intCast(delta);
    }

    pub fn addDurationNs(self: StreamInstant, duration_ns: u64) StreamInstant {
        return .{ .nanos = self.nanos +| duration_ns };
    }

    pub fn subtractDurationNs(self: StreamInstant, duration_ns: u64) StreamInstant {
        return .{ .nanos = self.nanos -| duration_ns };
    }
};

pub const OutputCallbackInfo = struct {
    callback: StreamInstant,
    playback: StreamInstant,
};

pub const InputCallbackInfo = struct {
    callback: StreamInstant,
    capture: StreamInstant,
};

pub const LatencyStatus = enum {
    measured,
    estimated,
    unavailable,
};

pub const ThreadSchedulingStatus = enum {
    not_requested,
    unsupported,
    applied,
    permission_denied,
    failed,
};

pub const StreamRunStatus = enum {
    stopped,
    running,
    backend_unavailable,
    backend_error,
    device_busy,
    device_not_available,
    invalid_input,
    out_of_memory,
    permission_denied,
    resource_exhausted,
    stream_invalidated,
    stream_suspended,
    unsupported_config,
    unsupported_operation,
    xrun,
};

pub const StreamBackendState = enum {
    unavailable,
    open,
    setup,
    prepared,
    running,
    xrun,
    draining,
    paused,
    suspended,
    disconnected,
    private,
    unknown,
};

pub const StreamDiagnostics = struct {
    timestamp: StreamInstant,
    timestamp_status: LatencyStatus,
    run_status: StreamRunStatus,
    backend_state: StreamBackendState,
    buffer_size_frames: ?u32,
    period_size_frames: ?u32,
    avail_min_frames: ?u32,
    start_threshold_frames: ?u32,
    available_frames: ?u32,
    available_max_frames: ?u32,
    available_duration_ns: ?u64,
    delay_frames: ?i64,
    delay_duration_ns: ?i64,
    latency_duration_ns: ?u64,
    overrange_frames: ?u32,
    latency_status: LatencyStatus,
    scheduling_status: ThreadSchedulingStatus,
    callback_count: u64,
    stream_error_count: u64,
    xrun_count: u64,
    recovery_count: u64,
    expected_callback_interval_ns: ?u64,
    last_callback_interval_ns: ?u64,
    last_callback_drift_ns: ?i64,
    max_callback_interval_ns: ?u64,
    max_callback_drift_abs_ns: ?u64,
};

pub fn framesToDurationNs(frames: i64, sample_rate: u32) ?i64 {
    if (sample_rate == 0) return null;
    const frame_count: u128 = if (frames < 0)
        @intCast(-@as(i128, frames))
    else
        @intCast(frames);
    const ns = frame_count * std.time.ns_per_s / sample_rate;
    if (ns > std.math.maxInt(i64)) {
        return if (frames < 0) std.math.minInt(i64) else std.math.maxInt(i64);
    }
    const signed: i64 = @intCast(ns);
    return if (frames < 0) -signed else signed;
}

pub fn framesToUnsignedDurationNs(frames: u32, sample_rate: u32) ?u64 {
    const ns = framesToDurationNs(@intCast(frames), sample_rate) orelse return null;
    return if (ns < 0) 0 else @intCast(ns);
}

pub fn nonNegativeFramesToDurationNs(frames: i64, sample_rate: u32) ?u64 {
    if (frames < 0) return null;
    const ns = framesToDurationNs(frames, sample_rate) orelse return null;
    return if (ns < 0) null else @intCast(ns);
}

pub fn runStatusFromAudioError(err: root.AudioError) StreamRunStatus {
    return switch (err) {
        root.AudioError.BackendUnavailable => .backend_unavailable,
        root.AudioError.BackendError => .backend_error,
        root.AudioError.DeviceBusy => .device_busy,
        root.AudioError.DeviceNotAvailable => .device_not_available,
        root.AudioError.InvalidInput => .invalid_input,
        root.AudioError.OutOfMemory => .out_of_memory,
        root.AudioError.PermissionDenied => .permission_denied,
        root.AudioError.ResourceExhausted => .resource_exhausted,
        root.AudioError.StreamInvalidated => .stream_invalidated,
        root.AudioError.StreamSuspended => .stream_suspended,
        root.AudioError.UnsupportedConfig => .unsupported_config,
        root.AudioError.UnsupportedOperation => .unsupported_operation,
        root.AudioError.Xrun => .xrun,
    };
}

pub const StreamErrorCallback = *const fn (
    err: root.AudioError,
    userdata: ?*anyopaque,
) void;

pub fn OutputCallback(comptime Sample: type) type {
    return *const fn (
        buffer: []Sample,
        info: OutputCallbackInfo,
        userdata: ?*anyopaque,
    ) void;
}

pub fn InputCallback(comptime Sample: type) type {
    return *const fn (
        buffer: []const Sample,
        info: InputCallbackInfo,
        userdata: ?*anyopaque,
    ) void;
}

pub fn sampleFormatForType(comptime Sample: type) ?root.SampleFormat {
    if (Sample == f32) return .f32;
    if (Sample == i8) return .i8;
    if (Sample == u8) return .u8;
    if (Sample == i16) return .i16;
    if (Sample == u16) return .u16;
    if (Sample == i24) return .i24;
    if (Sample == u24) return .u24;
    if (Sample == i32) return .i32;
    if (Sample == u32) return .u32;
    if (Sample == f64) return .f64;
    return null;
}

pub const OutputCallbackF32 = *const fn (
    buffer: []f32,
    info: OutputCallbackInfo,
    userdata: ?*anyopaque,
) void;

pub const InputCallbackF32 = *const fn (
    buffer: []const f32,
    info: InputCallbackInfo,
    userdata: ?*anyopaque,
) void;

pub const OutputCallbackI8 = *const fn (
    buffer: []i8,
    info: OutputCallbackInfo,
    userdata: ?*anyopaque,
) void;

pub const InputCallbackI8 = *const fn (
    buffer: []const i8,
    info: InputCallbackInfo,
    userdata: ?*anyopaque,
) void;

pub const OutputCallbackU8 = *const fn (
    buffer: []u8,
    info: OutputCallbackInfo,
    userdata: ?*anyopaque,
) void;

pub const InputCallbackU8 = *const fn (
    buffer: []const u8,
    info: InputCallbackInfo,
    userdata: ?*anyopaque,
) void;

pub const OutputCallbackI16 = *const fn (
    buffer: []i16,
    info: OutputCallbackInfo,
    userdata: ?*anyopaque,
) void;

pub const InputCallbackI16 = *const fn (
    buffer: []const i16,
    info: InputCallbackInfo,
    userdata: ?*anyopaque,
) void;

pub const OutputCallbackU16 = *const fn (
    buffer: []u16,
    info: OutputCallbackInfo,
    userdata: ?*anyopaque,
) void;

pub const InputCallbackU16 = *const fn (
    buffer: []const u16,
    info: InputCallbackInfo,
    userdata: ?*anyopaque,
) void;

pub const OutputCallbackI24 = *const fn (
    buffer: []i24,
    info: OutputCallbackInfo,
    userdata: ?*anyopaque,
) void;

pub const InputCallbackI24 = *const fn (
    buffer: []const i24,
    info: InputCallbackInfo,
    userdata: ?*anyopaque,
) void;

pub const OutputCallbackU24 = *const fn (
    buffer: []u24,
    info: OutputCallbackInfo,
    userdata: ?*anyopaque,
) void;

pub const InputCallbackU24 = *const fn (
    buffer: []const u24,
    info: InputCallbackInfo,
    userdata: ?*anyopaque,
) void;

pub const OutputCallbackI32 = *const fn (
    buffer: []i32,
    info: OutputCallbackInfo,
    userdata: ?*anyopaque,
) void;

pub const InputCallbackI32 = *const fn (
    buffer: []const i32,
    info: InputCallbackInfo,
    userdata: ?*anyopaque,
) void;

pub const OutputCallbackU32 = *const fn (
    buffer: []u32,
    info: OutputCallbackInfo,
    userdata: ?*anyopaque,
) void;

pub const InputCallbackU32 = *const fn (
    buffer: []const u32,
    info: InputCallbackInfo,
    userdata: ?*anyopaque,
) void;

pub const OutputCallbackF64 = *const fn (
    buffer: []f64,
    info: OutputCallbackInfo,
    userdata: ?*anyopaque,
) void;

pub const InputCallbackF64 = *const fn (
    buffer: []const f64,
    info: InputCallbackInfo,
    userdata: ?*anyopaque,
) void;

pub const Stream = union(enum) {
    alsa: backends.alsa.Stream,
    stub: backends.stub.Stream,
    null: backends.null_backend.Stream,

    pub fn play(self: *Stream) root.AudioError!void {
        return switch (self.*) {
            .alsa => |*stream_value| stream_value.play(),
            .stub => |*stream_value| stream_value.play(),
            .null => |*stream_value| stream_value.play(),
        };
    }

    pub fn pause(self: *Stream) root.AudioError!void {
        return switch (self.*) {
            .alsa => |*stream_value| stream_value.pause(),
            .stub => |*stream_value| stream_value.pause(),
            .null => |*stream_value| stream_value.pause(),
        };
    }

    pub fn drain(self: *Stream) root.AudioError!void {
        return switch (self.*) {
            .alsa => |*stream_value| stream_value.drain(),
            .stub => |*stream_value| stream_value.drain(),
            .null => |*stream_value| stream_value.drain(),
        };
    }

    pub fn isRunning(self: *Stream) bool {
        return switch (self.*) {
            .alsa => |*stream_value| stream_value.isRunning(),
            .stub => |*stream_value| stream_value.isRunning(),
            .null => |*stream_value| stream_value.isRunning(),
        };
    }

    pub fn status(self: *Stream) StreamRunStatus {
        return switch (self.*) {
            .alsa => |*stream_value| stream_value.status(),
            .stub => |*stream_value| stream_value.status(),
            .null => |*stream_value| stream_value.status(),
        };
    }

    pub fn bufferSize(self: *Stream) root.AudioError!u32 {
        return switch (self.*) {
            .alsa => |*stream_value| stream_value.bufferSize(),
            .stub => |*stream_value| stream_value.bufferSize(),
            .null => |*stream_value| stream_value.bufferSize(),
        };
    }

    pub fn diagnostics(self: *Stream) root.AudioError!StreamDiagnostics {
        return switch (self.*) {
            .alsa => |*stream_value| stream_value.diagnostics(),
            .stub => |*stream_value| stream_value.diagnostics(),
            .null => |*stream_value| stream_value.diagnostics(),
        };
    }

    pub fn deinit(self: *Stream) void {
        switch (self.*) {
            .alsa => |*stream_value| stream_value.deinit(),
            .stub => |*stream_value| stream_value.deinit(),
            .null => |*stream_value| stream_value.deinit(),
        }
    }
};

test "stream instant duration saturates" {
    const earlier = StreamInstant{ .nanos = 100 };
    const later = StreamInstant{ .nanos = 250 };
    try std.testing.expectEqual(@as(u64, 150), later.durationSince(earlier));
    try std.testing.expectEqual(@as(u64, 0), earlier.durationSince(later));
    try std.testing.expectEqual(@as(u128, 350), later.addDurationNs(100).nanos);
    try std.testing.expectEqual(@as(u128, 150), later.subtractDurationNs(100).nanos);
    try std.testing.expectEqual(@as(u128, 0), earlier.subtractDurationNs(200).nanos);
}

test "frame duration conversion handles signed frame counts" {
    try std.testing.expectEqual(@as(?i64, 1_000_000_000), framesToDurationNs(48_000, 48_000));
    try std.testing.expectEqual(@as(?i64, -500_000_000), framesToDurationNs(-24_000, 48_000));
    try std.testing.expectEqual(@as(?i64, null), framesToDurationNs(1, 0));
    try std.testing.expectEqual(@as(?u64, 1_000_000), framesToUnsignedDurationNs(48, 48_000));
    try std.testing.expectEqual(@as(?u64, 500_000_000), nonNegativeFramesToDurationNs(24_000, 48_000));
    try std.testing.expectEqual(@as(?u64, null), nonNegativeFramesToDurationNs(-1, 48_000));
    try std.testing.expectEqual(@as(?u64, null), nonNegativeFramesToDurationNs(1, 0));
}
