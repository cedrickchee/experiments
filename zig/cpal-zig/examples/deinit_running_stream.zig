const std = @import("std");
const cpal = @import("cpal_zig");

const SmokeError = error{
    StreamDidNotStart,
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

    const negotiated = try device.negotiateOutputConfig(allocator, .{
        .sample_formats = &.{.f32},
        .channels = 2,
        .sample_rate = 48_000,
    });

    var output_stream = try device.buildOutputStreamF32(
        negotiated.config,
        silence,
        null,
        null,
        null,
    );

    try output_stream.play();
    sleepNs(100 * std.time.ns_per_ms);
    if (!output_stream.isRunning()) return SmokeError.StreamDidNotStart;
    output_stream.deinit();

    try stdout.print("Deinitialized running output stream on {s}.\n", .{device.info().name});
}
