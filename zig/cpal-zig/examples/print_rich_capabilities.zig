const std = @import("std");
const cpal = @import("cpal_zig");

fn printBufferSize(stdout: *std.Io.Writer, buffer_size: cpal.SupportedBufferSize) !void {
    switch (buffer_size) {
        .unknown => try stdout.print("unknown", .{}),
        .range => |range| try stdout.print("{d}-{d} frames", .{ range.min, range.max }),
    }
}

fn printChannelCandidates(stdout: *std.Io.Writer, channels: cpal.ChannelRange) !void {
    var candidates_buffer: [12]u16 = undefined;
    const candidates = channels.preferredCandidates(&candidates_buffer);
    for (candidates, 0..) |candidate, index| {
        if (index != 0) try stdout.print("/", .{});
        try stdout.print("{d}", .{candidate});
    }
}

fn printCapabilities(
    stdout: *std.Io.Writer,
    label: []const u8,
    device: cpal.Device,
    capabilities: []const cpal.StreamCapability,
) !void {
    const info = device.info();
    try stdout.print("Default {s} device: {s} ({s})\n", .{ label, info.id, info.name });
    for (capabilities) |capability| {
        try stdout.print(
            "  {s}: channels={d}-{d} candidates=",
            .{
                @tagName(capability.sample_format),
                capability.channels.min,
                capability.channels.max,
            },
        );
        try printChannelCandidates(stdout, capability.channels);
        try stdout.print(
            ", rate={d}-{d} Hz, period=",
            .{
                capability.min_sample_rate,
                capability.max_sample_rate,
            },
        );
        try printBufferSize(stdout, capability.buffer_size);
        try stdout.print(", buffer=", .{});
        try printBufferSize(stdout, capability.total_buffer_size);
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

    if (try host.defaultOutputDevice(allocator)) |output| {
        var output_device = output;
        defer output_device.deinit(allocator);
        const capabilities = try output_device.supportedOutputCapabilities(allocator);
        defer allocator.free(capabilities);
        try printCapabilities(stdout, "output", output_device, capabilities);
    } else {
        try stdout.print("No default output device available.\n", .{});
    }

    if (try host.defaultInputDevice(allocator)) |input| {
        var input_device = input;
        defer input_device.deinit(allocator);
        const capabilities = try input_device.supportedInputCapabilities(allocator);
        defer allocator.free(capabilities);
        try printCapabilities(stdout, "input", input_device, capabilities);
    } else {
        try stdout.print("No default input device available.\n", .{});
    }
}
