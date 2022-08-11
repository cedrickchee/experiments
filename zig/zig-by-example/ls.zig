// 1 - List Directory
//
// List all files and directories present in the current directory or the given
// path.

const std = @import("std");
const stdout = std.io.getStdOut().writer();

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpose_allocator.allocator();
    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);
    const dir = try std.fs.cwd().openIterableDir(if (args.len < 2) "." else args[1], .{});
    var dir_iterator = dir.iterate();

    // Iterate Over the Path's
    while (try dir_iterator.next()) |path| {
        try stdout.print("{s}\n", .{path.name});
    }
}
