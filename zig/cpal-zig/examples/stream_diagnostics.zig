const std = @import("std");
const cpal = @import("cpal_zig");

const DiagnosticsSmokeError = error{
    MissingCallbacks,
    StreamErrorsObserved,
    XrunsObserved,
    MissingPeriodSize,
    MissingTotalBufferSize,
    LatencyUnavailable,
};

fn sleepNs(ns: u64) void {
    var ts = std.os.linux.timespec{
        .sec = @intCast(ns / std.time.ns_per_s),
        .nsec = @intCast(ns % std.time.ns_per_s),
    };
    _ = std.os.linux.nanosleep(&ts, null);
}

fn silence(buffer: []f32, info: cpal.OutputCallbackInfo, userdata: ?*anyopaque) void {
    _ = info;
    _ = userdata;
    @memset(buffer, 0);
}

fn consumeInput(buffer: []const f32, info: cpal.InputCallbackInfo, userdata: ?*anyopaque) void {
    _ = buffer;
    _ = info;
    _ = userdata;
}

fn printOptionalU32(stdout: *std.Io.Writer, value: ?u32) !void {
    if (value) |frames| {
        try stdout.print("{d}", .{frames});
    } else {
        try stdout.print("unavailable", .{});
    }
}

fn printOptionalU64(stdout: *std.Io.Writer, value: ?u64) !void {
    if (value) |duration| {
        try stdout.print("{d}", .{duration});
    } else {
        try stdout.print("unavailable", .{});
    }
}

fn printOptionalI64(stdout: *std.Io.Writer, value: ?i64) !void {
    if (value) |frames| {
        try stdout.print("{d}", .{frames});
    } else {
        try stdout.print("unavailable", .{});
    }
}

fn printDiagnosticsLine(stdout: *std.Io.Writer, diagnostics: cpal.StreamDiagnostics) !void {
    try stdout.print("  run={s}, backend={s}, timestamp={s}, latency={s}, scheduling={s}, avail=", .{
        @tagName(diagnostics.run_status),
        @tagName(diagnostics.backend_state),
        @tagName(diagnostics.timestamp_status),
        @tagName(diagnostics.latency_status),
        @tagName(diagnostics.scheduling_status),
    });
    try printOptionalU32(stdout, diagnostics.available_frames);
    try stdout.print(" frames/", .{});
    try printOptionalU64(stdout, diagnostics.available_duration_ns);
    try stdout.print(" ns, avail_max=", .{});
    try printOptionalU32(stdout, diagnostics.available_max_frames);
    try stdout.print(", buffer=", .{});
    try printOptionalU32(stdout, diagnostics.buffer_size_frames);
    try stdout.print(" frames, period=", .{});
    try printOptionalU32(stdout, diagnostics.period_size_frames);
    try stdout.print(" frames, avail_min=", .{});
    try printOptionalU32(stdout, diagnostics.avail_min_frames);
    try stdout.print(" frames, start_threshold=", .{});
    try printOptionalU32(stdout, diagnostics.start_threshold_frames);
    try stdout.print(" frames, delay=", .{});
    try printOptionalI64(stdout, diagnostics.delay_frames);
    try stdout.print(" frames/", .{});
    try printOptionalI64(stdout, diagnostics.delay_duration_ns);
    try stdout.print(" ns, latency=", .{});
    try printOptionalU64(stdout, diagnostics.latency_duration_ns);
    try stdout.print(" ns, overrange=", .{});
    try printOptionalU32(stdout, diagnostics.overrange_frames);
    try stdout.print(", callbacks={d}, errors={d}, xruns={d}, recoveries={d}, interval=", .{
        diagnostics.callback_count,
        diagnostics.stream_error_count,
        diagnostics.xrun_count,
        diagnostics.recovery_count,
    });
    try printOptionalU64(stdout, diagnostics.last_callback_interval_ns);
    try stdout.print(" ns, expected_interval=", .{});
    try printOptionalU64(stdout, diagnostics.expected_callback_interval_ns);
    try stdout.print(" ns, drift=", .{});
    try printOptionalI64(stdout, diagnostics.last_callback_drift_ns);
    try stdout.print(" ns, max_interval=", .{});
    try printOptionalU64(stdout, diagnostics.max_callback_interval_ns);
    try stdout.print(" ns, max_abs_drift=", .{});
    try printOptionalU64(stdout, diagnostics.max_callback_drift_abs_ns);
    try stdout.print(" ns", .{});
    try stdout.print(", timestamp_ns={d}\n", .{diagnostics.timestamp.nanos});
}

fn validateDiagnostics(diagnostics: cpal.StreamDiagnostics) DiagnosticsSmokeError!void {
    if (diagnostics.callback_count == 0) return DiagnosticsSmokeError.MissingCallbacks;
    if (diagnostics.stream_error_count != 0) return DiagnosticsSmokeError.StreamErrorsObserved;
    if (diagnostics.xrun_count != 0) return DiagnosticsSmokeError.XrunsObserved;
    if (diagnostics.period_size_frames == null) return DiagnosticsSmokeError.MissingPeriodSize;
    if (diagnostics.buffer_size_frames == null) return DiagnosticsSmokeError.MissingTotalBufferSize;
    if (diagnostics.avail_min_frames == null) return DiagnosticsSmokeError.MissingPeriodSize;
    if (diagnostics.start_threshold_frames == null) return DiagnosticsSmokeError.MissingTotalBufferSize;
    if (diagnostics.timestamp_status == .unavailable) return DiagnosticsSmokeError.LatencyUnavailable;
    if (diagnostics.latency_status == .unavailable) return DiagnosticsSmokeError.LatencyUnavailable;
}

fn sampleDiagnostics(
    stdout: *std.Io.Writer,
    stream: *cpal.stream.Stream,
) !void {
    var index: usize = 0;
    var last_diagnostics: ?cpal.StreamDiagnostics = null;
    while (index < 5) : (index += 1) {
        sleepNs(100 * std.time.ns_per_ms);
        const diagnostics = try stream.diagnostics();
        last_diagnostics = diagnostics;
        try printDiagnosticsLine(stdout, diagnostics);
    }

    const diagnostics = last_diagnostics orelse return DiagnosticsSmokeError.MissingCallbacks;
    try validateDiagnostics(diagnostics);
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

    var output_stream = try output_device.buildOutputStreamF32(
        output_negotiated.config,
        silence,
        null,
        null,
        null,
    );
    defer output_stream.deinit();

    try output_stream.play();
    defer output_stream.pause() catch {};

    try stdout.print(
        "Output diagnostics for {s}: {d} channels at {d} Hz\n",
        .{ output_device.info().name, output_negotiated.config.channels, output_negotiated.config.sample_rate },
    );
    try sampleDiagnostics(stdout, &output_stream);

    var input_device = (try host.defaultInputDevice(allocator)) orelse {
        try stdout.print("No input device available.\n", .{});
        return;
    };
    defer input_device.deinit(allocator);

    const input_negotiated = input_device.negotiateInputConfig(allocator, .{
        .sample_formats = &.{.f32},
        .channels = output_negotiated.config.channels,
        .sample_rate = output_negotiated.config.sample_rate,
    }) catch |err| switch (err) {
        cpal.AudioError.UnsupportedConfig => {
            try stdout.print("Default input device does not support matching f32 diagnostics config.\n", .{});
            return;
        },
        else => return err,
    };

    var input_stream = try input_device.buildInputStreamF32(
        input_negotiated.config,
        consumeInput,
        null,
        null,
        null,
    );
    defer input_stream.deinit();

    try input_stream.play();
    defer input_stream.pause() catch {};

    try stdout.print(
        "Input diagnostics for {s}: {d} channels at {d} Hz\n",
        .{ input_device.info().name, input_negotiated.config.channels, input_negotiated.config.sample_rate },
    );
    try sampleDiagnostics(stdout, &input_stream);
}
