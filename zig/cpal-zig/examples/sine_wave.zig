const std = @import("std");
const cpal = @import("cpal_zig");

fn sleepNs(ns: u64) void {
    var ts = std.os.linux.timespec{
        .sec = @intCast(ns / std.time.ns_per_s),
        .nsec = @intCast(ns % std.time.ns_per_s),
    };
    _ = std.os.linux.nanosleep(&ts, null);
}

const Oscillator = struct {
    phase: f32 = 0,
    sample_rate: f32,
    channels: usize,

    fn callback(buffer: []f32, info: cpal.OutputCallbackInfo, userdata: ?*anyopaque) void {
        _ = info;
        const osc: *Oscillator = @ptrCast(@alignCast(userdata.?));
        const step = 440.0 * 2.0 * std.math.pi / osc.sample_rate;
        var index: usize = 0;
        while (index < buffer.len) : (index += osc.channels) {
            const value = @sin(osc.phase) * 0.20;
            osc.phase += step;
            if (osc.phase > 2.0 * std.math.pi) osc.phase -= 2.0 * std.math.pi;
            for (buffer[index..@min(index + osc.channels, buffer.len)]) |*sample| {
                sample.* = value;
            }
        }
    }
};

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

    const supported = try device.defaultOutputConfig();
    const stream_config = supported.config();
    var oscillator = Oscillator{
        .sample_rate = @floatFromInt(stream_config.sample_rate),
        .channels = stream_config.channels,
    };

    var output_stream = try device.buildOutputStreamF32(
        stream_config,
        Oscillator.callback,
        &oscillator,
    );
    defer output_stream.deinit();

    try output_stream.play();
    try stdout.print("Playing 440 Hz sine wave on {s}.\n", .{device.info().name});
    sleepNs(1 * std.time.ns_per_s);
    try output_stream.pause();
}
