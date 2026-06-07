const std = @import("std");
const cpal = @import("cpal_zig");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const io = init.io;

    var stdout_buffer: [4096]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};

    const ids = try cpal.availableHosts(allocator);
    try stdout.print("Available hosts:\n", .{});
    for (ids) |id| {
        try stdout.print("  {s} ({s})\n", .{ id.name(), id.stableName() });

        var host = cpal.hostFromId(id) catch continue;
        defer host.deinit(allocator);

        var devices = host.devices(allocator) catch continue;
        defer devices.deinit();
        for (devices.items) |device| {
            const info = device.info();
            try stdout.print("    {s}: {s} [{s}]\n", .{
                info.id,
                info.name,
                @tagName(info.direction),
            });
        }
    }
}
