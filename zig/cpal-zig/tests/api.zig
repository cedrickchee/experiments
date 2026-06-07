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

test "null i16 output and input streams invoke callbacks" {
    const allocator = std.testing.allocator;
    var host = try cpal.hostFromId(.null);
    defer host.deinit(allocator);

    var output_device = (try host.defaultOutputDevice(allocator)).?;
    defer output_device.deinit(allocator);
    var input_device = (try host.defaultInputDevice(allocator)).?;
    defer input_device.deinit(allocator);

    const output_negotiated = try output_device.negotiateOutputConfig(allocator, .{
        .sample_formats = &.{.i16},
        .channels = 2,
        .sample_rate = 48_000,
        .buffer_size = .{ .fixed = 64 },
    });
    const input_negotiated = try input_device.negotiateInputConfig(allocator, .{
        .sample_formats = &.{.i16},
        .channels = output_negotiated.config.channels,
        .sample_rate = output_negotiated.config.sample_rate,
        .buffer_size = output_negotiated.config.buffer_size,
    });

    const State = struct {
        output_calls: usize = 0,
        input_calls: usize = 0,
        input_samples: usize = 0,

        fn output(buffer: []i16, info: cpal.OutputCallbackInfo, userdata: ?*anyopaque) void {
            _ = info;
            const state: *@This() = @ptrCast(@alignCast(userdata.?));
            state.output_calls += 1;
            @memset(buffer, 0);
        }

        fn input(buffer: []const i16, info: cpal.InputCallbackInfo, userdata: ?*anyopaque) void {
            _ = info;
            const state: *@This() = @ptrCast(@alignCast(userdata.?));
            state.input_calls += 1;
            state.input_samples += buffer.len;
            for (buffer) |sample| {
                std.debug.assert(sample == 0);
            }
        }
    };

    var state = State{};
    var output_stream = try output_device.buildOutputStreamI16(
        output_negotiated.config,
        State.output,
        &state,
        null,
        null,
    );
    defer output_stream.deinit();
    var input_stream = try input_device.buildInputStreamI16(
        input_negotiated.config,
        State.input,
        &state,
        null,
        null,
    );
    defer input_stream.deinit();

    try output_stream.play();
    try input_stream.play();
    try std.testing.expectEqual(@as(usize, 1), state.output_calls);
    try std.testing.expectEqual(@as(usize, 1), state.input_calls);
    try std.testing.expectEqual(@as(usize, 128), state.input_samples);
}
