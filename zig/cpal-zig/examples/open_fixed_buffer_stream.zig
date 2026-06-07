const std = @import("std");
const cpal = @import("cpal_zig");

const SmokeError = error{
    UnexpectedPeriodSize,
    UnexpectedTotalBufferSize,
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

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const io = init.io;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};

    var host = try cpal.defaultHost();
    defer host.deinit(allocator);

    var device = (try host.defaultOutputDevice(allocator)) orelse {
        try stdout.print("No output device available.\n", .{});
        return;
    };
    defer device.deinit(allocator);

    const negotiated = device.negotiateOutputConfig(allocator, .{
        .sample_formats = &.{.f32},
        .channels = 2,
        .sample_rate = 48_000,
        .buffer_size = .{ .fixed = 480 },
        .total_buffer_size = .{ .fixed = 1920 },
    }) catch |err| switch (err) {
        cpal.AudioError.UnsupportedConfig => {
            try stdout.print("Default output device does not support fixed f32 period/buffer request.\n", .{});
            return;
        },
        else => return err,
    };

    var output_stream = try device.buildOutputStreamF32(negotiated.config, silence, null, null, null);
    defer output_stream.deinit();

    try output_stream.play();
    sleepNs(100 * std.time.ns_per_ms);
    const diagnostics = try output_stream.diagnostics();
    try output_stream.pause();

    try stdout.print(
        "Opened fixed-buffer f32 stream on {s}: period={?d}, total_buffer={?d}\n",
        .{ device.info().name, diagnostics.period_size_frames, diagnostics.buffer_size_frames },
    );
    if (diagnostics.period_size_frames != 480) return SmokeError.UnexpectedPeriodSize;
    if (diagnostics.buffer_size_frames != 1920) return SmokeError.UnexpectedTotalBufferSize;
}
