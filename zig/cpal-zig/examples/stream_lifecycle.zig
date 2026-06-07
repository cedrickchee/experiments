const std = @import("std");
const cpal = @import("cpal_zig");

const LifecycleSmokeError = error{
    OutputCallbacksMissing,
    OutputCallbacksDidNotResume,
    InputCallbacksMissing,
    StreamErrorsObserved,
    StreamDidNotRun,
    StreamDidNotStop,
};

const LifecycleState = struct {
    output_calls: std.atomic.Value(usize) = .init(0),
    input_calls: std.atomic.Value(usize) = .init(0),
    errors: std.atomic.Value(usize) = .init(0),

    fn output(buffer: []f32, info: cpal.OutputCallbackInfo, userdata: ?*anyopaque) void {
        _ = info;
        const state: *LifecycleState = @ptrCast(@alignCast(userdata.?));
        @memset(buffer, 0);
        _ = state.output_calls.fetchAdd(1, .monotonic);
    }

    fn input(buffer: []const f32, info: cpal.InputCallbackInfo, userdata: ?*anyopaque) void {
        _ = buffer;
        _ = info;
        const state: *LifecycleState = @ptrCast(@alignCast(userdata.?));
        _ = state.input_calls.fetchAdd(1, .monotonic);
    }

    fn errorCallback(err: cpal.AudioError, userdata: ?*anyopaque) void {
        if (@errorName(err).len == 0) unreachable;
        const state: *LifecycleState = @ptrCast(@alignCast(userdata.?));
        _ = state.errors.fetchAdd(1, .monotonic);
    }
};

fn sleepNs(ns: u64) void {
    var ts = std.os.linux.timespec{
        .sec = @intCast(ns / std.time.ns_per_s),
        .nsec = @intCast(ns % std.time.ns_per_s),
    };
    _ = std.os.linux.nanosleep(&ts, null);
}

fn expectRunning(stream: *cpal.stream.Stream) LifecycleSmokeError!void {
    if (!stream.isRunning()) return LifecycleSmokeError.StreamDidNotRun;
    if (stream.status() != .running) return LifecycleSmokeError.StreamDidNotRun;
}

fn expectStopped(stream: *cpal.stream.Stream) LifecycleSmokeError!void {
    if (stream.isRunning()) return LifecycleSmokeError.StreamDidNotStop;
    if (stream.status() != .stopped) return LifecycleSmokeError.StreamDidNotStop;
}

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

    const output_negotiated = try output_device.negotiateOutputConfig(allocator, .{
        .sample_formats = &.{.f32},
        .channels = 2,
        .sample_rate = 48_000,
    });

    var state = LifecycleState{};
    var output_stream = try output_device.buildOutputStreamF32(
        output_negotiated.config,
        LifecycleState.output,
        &state,
        LifecycleState.errorCallback,
        &state,
    );
    defer output_stream.deinit();

    try output_stream.play();
    sleepNs(120 * std.time.ns_per_ms);
    try expectRunning(&output_stream);
    const first_output_calls = state.output_calls.load(.monotonic);
    if (first_output_calls == 0) return LifecycleSmokeError.OutputCallbacksMissing;

    try output_stream.pause();
    try expectStopped(&output_stream);

    try output_stream.play();
    sleepNs(120 * std.time.ns_per_ms);
    try expectRunning(&output_stream);
    const resumed_output_calls = state.output_calls.load(.monotonic);
    if (resumed_output_calls <= first_output_calls) return LifecycleSmokeError.OutputCallbacksDidNotResume;

    try output_stream.drain();
    try expectStopped(&output_stream);

    var input_deinitialized_running = false;
    if (try host.defaultInputDevice(allocator)) |input_device_value| {
        var input_device = input_device_value;
        defer input_device.deinit(allocator);
        const input_negotiated = input_device.negotiateInputConfig(allocator, .{
            .sample_formats = &.{.f32},
            .channels = output_negotiated.config.channels,
            .sample_rate = output_negotiated.config.sample_rate,
        }) catch |err| switch (err) {
            cpal.AudioError.UnsupportedConfig => {
                try stdout.print("Default input device does not support matching f32 lifecycle config.\n", .{});
                if (state.errors.load(.monotonic) != 0) return LifecycleSmokeError.StreamErrorsObserved;
                try stdout.print(
                    "Lifecycle smoke passed on {s}: first_output_calls={d}, resumed_output_calls={d}, input_deinit_running=false, callback_errors={d}\n",
                    .{ output_device.info().name, first_output_calls, resumed_output_calls, state.errors.load(.monotonic) },
                );
                return;
            },
            else => return err,
        };

        var input_stream = try input_device.buildInputStreamF32(
            input_negotiated.config,
            LifecycleState.input,
            &state,
            LifecycleState.errorCallback,
            &state,
        );

        try input_stream.play();
        sleepNs(120 * std.time.ns_per_ms);
        try expectRunning(&input_stream);
        if (state.input_calls.load(.monotonic) == 0) return LifecycleSmokeError.InputCallbacksMissing;
        input_stream.deinit();
        input_deinitialized_running = true;
    }

    const callback_errors = state.errors.load(.monotonic);
    if (callback_errors != 0) return LifecycleSmokeError.StreamErrorsObserved;

    try stdout.print(
        "Lifecycle smoke passed on {s}: first_output_calls={d}, resumed_output_calls={d}, input_deinit_running={}, callback_errors={d}\n",
        .{
            output_device.info().name,
            first_output_calls,
            resumed_output_calls,
            input_deinitialized_running,
            callback_errors,
        },
    );
}
