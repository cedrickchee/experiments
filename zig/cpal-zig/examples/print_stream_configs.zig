const std = @import("std");
const cpal = @import("cpal_zig");

fn printBufferSize(stdout: *std.Io.Writer, buffer_size: cpal.SupportedBufferSize) !void {
    switch (buffer_size) {
        .unknown => try stdout.print("unknown", .{}),
        .range => |range| try stdout.print("{d}-{d} frames", .{ range.min, range.max }),
    }
}

fn printConfigs(
    stdout: *std.Io.Writer,
    label: []const u8,
    device: cpal.Device,
    configs: []const cpal.SupportedStreamConfigRange,
) !void {
    const info = device.info();
    try stdout.print("Default {s} device: {s} ({s})\n", .{ label, info.id, info.name });
    for (configs) |config| {
        const channels = config.channelRange();
        if (channels.min == channels.max) {
            try stdout.print("  {d} channels", .{config.channels});
        } else {
            try stdout.print("  channels={d}-{d} representative={d}", .{ channels.min, channels.max, config.channels });
        }
        try stdout.print(", {d}-{d} Hz, {s}, buffer=", .{
            config.min_sample_rate,
            config.max_sample_rate,
            @tagName(config.sample_format),
        });
        try printBufferSize(stdout, config.buffer_size);
        try stdout.print(", total_buffer=", .{});
        try printBufferSize(stdout, config.total_buffer_size);
        try stdout.print("\n", .{});
    }
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const io = init.io;

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};

    var host = try cpal.defaultHost();
    defer host.deinit(allocator);

    const maybe_output_device = try host.defaultOutputDevice(allocator);
    if (maybe_output_device == null) {
        try stdout.print("No default output device available.\n", .{});
    } else {
        var output_device = maybe_output_device.?;
        defer output_device.deinit(allocator);
        const configs = try output_device.supportedOutputConfigs(allocator);
        defer allocator.free(configs);
        try printConfigs(stdout, "output", output_device, configs);
    }

    const maybe_input_device = try host.defaultInputDevice(allocator);
    if (maybe_input_device == null) {
        try stdout.print("No default input device available.\n", .{});
    } else {
        var input_device = maybe_input_device.?;
        defer input_device.deinit(allocator);
        const configs = try input_device.supportedInputConfigs(allocator);
        defer allocator.free(configs);
        try printConfigs(stdout, "input", input_device, configs);
    }
}
