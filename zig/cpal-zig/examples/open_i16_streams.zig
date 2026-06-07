const std = @import("std");
const cpal = @import("cpal_zig");

fn sleepNs(ns: u64) void {
    var ts = std.os.linux.timespec{
        .sec = @intCast(ns / std.time.ns_per_s),
        .nsec = @intCast(ns % std.time.ns_per_s),
    };
    _ = std.os.linux.nanosleep(&ts, null);
}

const State = struct {
    output_calls: std.atomic.Value(usize) = .init(0),
    input_calls: std.atomic.Value(usize) = .init(0),
    input_samples: std.atomic.Value(usize) = .init(0),
    errors: std.atomic.Value(usize) = .init(0),

    fn output(buffer: []i16, info: cpal.OutputCallbackInfo, userdata: ?*anyopaque) void {
        _ = info;
        const state: *State = @ptrCast(@alignCast(userdata.?));
        @memset(buffer, 0);
        _ = state.output_calls.fetchAdd(1, .monotonic);
    }

    fn input(buffer: []const i16, info: cpal.InputCallbackInfo, userdata: ?*anyopaque) void {
        _ = info;
        const state: *State = @ptrCast(@alignCast(userdata.?));
        _ = state.input_calls.fetchAdd(1, .monotonic);
        _ = state.input_samples.fetchAdd(buffer.len, .monotonic);
    }

    fn errorCallback(err: cpal.AudioError, userdata: ?*anyopaque) void {
        if (@errorName(err).len == 0) unreachable;
        const state: *State = @ptrCast(@alignCast(userdata.?));
        _ = state.errors.fetchAdd(1, .monotonic);
    }
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const io = init.io;

    var stdout_buffer: [2048]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};

    var host = try cpal.defaultHost();
    defer host.deinit(allocator);

    var output_device = (try host.defaultOutputDevice(allocator)) orelse {
        try stdout.print("No output device available.\n", .{});
        return;
    };
    defer output_device.deinit(allocator);

    var input_device = (try host.defaultInputDevice(allocator)) orelse {
        try stdout.print("No input device available.\n", .{});
        return;
    };
    defer input_device.deinit(allocator);

    const output_negotiated = try output_device.negotiateOutputConfig(allocator, .{
        .sample_formats = &.{.i16},
        .channels = 2,
        .sample_rate = 48_000,
    });
    const input_negotiated = try input_device.negotiateInputConfig(allocator, .{
        .sample_formats = &.{.i16},
        .channels = output_negotiated.config.channels,
        .sample_rate = output_negotiated.config.sample_rate,
    });

    var state = State{};
    var output_stream = try output_device.buildOutputStreamI16(
        output_negotiated.config,
        State.output,
        &state,
        State.errorCallback,
        &state,
    );
    defer output_stream.deinit();

    var input_stream = try input_device.buildInputStreamI16(
        input_negotiated.config,
        State.input,
        &state,
        State.errorCallback,
        &state,
    );
    defer input_stream.deinit();

    try output_stream.play();
    try input_stream.play();
    sleepNs(200 * std.time.ns_per_ms);
    try input_stream.pause();
    try output_stream.pause();

    try stdout.print(
        "Opened i16 streams: {d} channels at {d} Hz, output_calls={d}, input_calls={d}, input_samples={d}, callback_errors={d}\n",
        .{
            output_negotiated.config.channels,
            output_negotiated.config.sample_rate,
            state.output_calls.load(.monotonic),
            state.input_calls.load(.monotonic),
            state.input_samples.load(.monotonic),
            state.errors.load(.monotonic),
        },
    );
}
