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
    }, State.callback, &state, null, null);
    defer output_stream.deinit();

    try output_stream.play();
    try std.testing.expectEqual(@as(usize, 1), state.calls);
    try std.testing.expectEqual(@as(u32, 128), try output_stream.bufferSize());
}

test "null host exposes a usable input device" {
    const allocator = std.testing.allocator;
    var host = try cpal.hostFromId(.null);
    defer host.deinit(allocator);

    const maybe_device = try host.defaultInputDevice(allocator);
    try std.testing.expect(maybe_device != null);
    var device = maybe_device.?;
    defer device.deinit(allocator);

    const config = try device.defaultInputConfig();
    try std.testing.expectEqual(@as(u32, 48_000), config.sample_rate);
    try std.testing.expectEqual(cpal.SampleFormat.f32, config.sample_format);
}

test "null input stream invokes callback" {
    const allocator = std.testing.allocator;
    var host = try cpal.hostFromId(.null);
    defer host.deinit(allocator);
    var device = (try host.defaultInputDevice(allocator)).?;
    defer device.deinit(allocator);

    const State = struct {
        calls: usize = 0,
        samples: usize = 0,

        fn callback(buffer: []const f32, info: cpal.InputCallbackInfo, userdata: ?*anyopaque) void {
            _ = info;
            const state: *@This() = @ptrCast(@alignCast(userdata.?));
            state.calls += 1;
            state.samples += buffer.len;
            for (buffer) |sample| {
                std.debug.assert(sample == 0);
            }
        }
    };

    var state = State{};
    var input_stream = try device.buildInputStreamF32(.{
        .channels = 2,
        .sample_rate = 48_000,
        .buffer_size = .{ .fixed = 64 },
    }, State.callback, &state, null, null);
    defer input_stream.deinit();

    try input_stream.play();
    try std.testing.expectEqual(@as(usize, 1), state.calls);
    try std.testing.expectEqual(@as(usize, 128), state.samples);
    try std.testing.expectEqual(@as(u32, 64), try input_stream.bufferSize());
}
