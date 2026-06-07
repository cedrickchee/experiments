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

    var monitor = try host.snapshotMonitor(allocator, 250 * std.time.ns_per_ms);
    defer monitor.deinit();
    try stdout.print("Native device-change signal support: {any}\n", .{host.supportsDeviceChangeSignals()});
    try stdout.print("Initial device snapshot: {d} devices\n", .{monitor.snapshot().len});

    const changes = try monitor.waitForChanges(host, 500 * std.time.ns_per_ms);
    defer cpal.freeDeviceSnapshotChanges(allocator, changes);

    try stdout.print("Refreshed device snapshot: {d} devices, {d} changes\n", .{ monitor.snapshot().len, changes.len });
    for (changes) |change| {
        try stdout.print("  {s}: {s} ({s}) [{s}], available={any}, fingerprint={x}", .{
            @tagName(change.kind),
            change.item.id,
            change.item.name,
            @tagName(change.item.direction),
            change.item.available,
            change.item.fingerprint(),
        });
        if (change.previous) |previous| {
            try stdout.print(", previous_available={any}, previous_fingerprint={x}", .{
                previous.available,
                previous.fingerprint(),
            });
            try stdout.print(", changed: availability={any}, name={any}, description={any}, direction={any}", .{
                change.availabilityChanged(),
                change.nameChanged(),
                change.descriptionChanged(),
                change.directionChanged(),
            });
        }
        try stdout.print("\n", .{});
    }
}
