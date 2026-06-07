const std = @import("std");
const cpal = @import("cpal_zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const io = init.io;

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};

    var host = try cpal.defaultHost();
    defer host.deinit(allocator);

    const maybe_device = try host.defaultOutputDevice(allocator);
    if (maybe_device == null) {
        try stdout.print("No default output device available.\n", .{});
        return;
    }

    var device = maybe_device.?;
    defer device.deinit(allocator);

    const info = device.info();
    try stdout.print("Default output device: {s} ({s})\n", .{ info.id, info.name });

    const configs = try device.supportedOutputConfigs(allocator);
    defer allocator.free(configs);
    for (configs) |config| {
        try stdout.print("  {d} channels, {d}-{d} Hz, {s}, buffer=", .{
            config.channels,
            config.min_sample_rate,
            config.max_sample_rate,
            @tagName(config.sample_format),
        });
        switch (config.buffer_size) {
            .unknown => try stdout.print("unknown\n", .{}),
            .range => |range| try stdout.print("{d}-{d} frames\n", .{ range.min, range.max }),
        }
    }
}
