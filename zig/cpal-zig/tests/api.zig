const std = @import("std");
const cpal = @import("cpal_zig");

test "default host is constructible and deinitializable" {
    const allocator = std.testing.allocator;
    var host = try cpal.defaultHost();
    defer host.deinit(allocator);
    try std.testing.expect(host.id() == .alsa or host.id() == .null);
}

test "null host exposes a usable output device" {
    const allocator = std.testing.allocator;
    var host = try cpal.hostFromId(.null);
    defer host.deinit(allocator);

    const maybe_device = try host.defaultOutputDevice(allocator);
    try std.testing.expect(maybe_device != null);
    var device = maybe_device.?;
    defer device.deinit(allocator);

    const config = try device.defaultOutputConfig();
    try std.testing.expectEqual(@as(u32, 48_000), config.sample_rate);
    try std.testing.expectEqual(cpal.SampleFormat.f32, config.sample_format);
}

test "null output stream invokes callback" {
    const allocator = std.testing.allocator;
    var host = try cpal.hostFromId(.null);
    defer host.deinit(allocator);
    var device = (try host.defaultOutputDevice(allocator)).?;
    defer device.deinit(allocator);

    const State = struct {
        calls: usize = 0,

        fn callback(buffer: []f32, info: cpal.OutputCallbackInfo, userdata: ?*anyopaque) void {
            _ = info;
            const state: *@This() = @ptrCast(@alignCast(userdata.?));
            state.calls += 1;
            @memset(buffer, 0);
        }
    };

    var state = State{};
    var output_stream = try device.buildOutputStreamF32(.{
        .channels = 2,
        .sample_rate = 48_000,
    }, State.callback, &state);
    defer output_stream.deinit();

    try output_stream.play();
    try std.testing.expectEqual(@as(usize, 1), state.calls);
}
