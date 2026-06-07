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
};

pub const OutputCallbackInfo = struct {
    callback: StreamInstant,
    playback: StreamInstant,
};

pub const OutputCallbackF32 = *const fn (
    buffer: []f32,
    info: OutputCallbackInfo,
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
}
