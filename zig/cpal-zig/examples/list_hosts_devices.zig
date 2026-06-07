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
            const device_description = device.description();
            try stdout.print("    {s}: {s} [{s}], available={any}\n", .{
                info.id,
                info.name,
                @tagName(info.direction),
                device.isAvailable(),
            });
            try stdout.print("      driver=", .{});
            try printOptional(stdout, device_description.driver);
            try stdout.print(", type={s}, interface={s}, address=", .{
                @tagName(device_description.device_type),
                @tagName(device_description.interface_type),
            });
            try printOptional(stdout, device_description.address);
            try stdout.print("\n", .{});
            if (info.description) |text| {
                if (!std.mem.eql(u8, text, info.name)) {
                    try stdout.print("      {s}\n", .{text});
                }
            }
        }
    }
}

fn printOptional(stdout: *std.Io.Writer, value: ?[]const u8) !void {
    if (value) |text| {
        try stdout.print("{s}", .{text});
    } else {
        try stdout.print("n/a", .{});
    }
}
