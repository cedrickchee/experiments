const std = @import("std");
const eql = std.mem.eql;
const expect = std.testing.expect;

// ************************************************************************
// Standard Patterns
// ************************************************************************

//
// Filesystem
// 

// Let’s create and open a file in our current working directory, write to it, 
// and then read from it. Here we have to use .seekTo in order to go back to 
// the start of the file before reading what we have written.
test "createFile, write, seekTo, read" {
    const file = try std.fs.cwd().createFile(
        "junk_file.txt",
        .{ .read = true },
    );
    defer file.close();

    const bytes_written = try file.writeAll("Hello File!");
    _ = bytes_written;

    var buffer: [100]u8 = undefined;
    try file.seekTo(0);
    const bytes_read = try file.readAll(&buffer);

    try expect(eql(u8, buffer[0..bytes_read], "Hello File!"));
}

// We can get various information about files by using .stat() on them.
test "file stat" {
    const file = try std.fs.cwd().createFile(
        "junk_file2.txt",
        .{},
    );
    defer file.close();
    const stat = try file.stat();
    try expect(stat.size == 0);
    try expect(stat.kind == .File);
    try expect(stat.ctime <= std.time.nanoTimestamp());
    try expect(stat.mtime <= std.time.nanoTimestamp());
    try expect(stat.atime <= std.time.nanoTimestamp());
}

// We can make directories and iterate over their contents.
test "make dir" {
    try std.fs.cwd().makeDir("test-tmp");
    const dir = try std.fs.cwd().openDir(
        "test-tmp",
        .{ .iterate = true },
    );
    defer {
        std.fs.cwd().deleteTree("test-tmp") catch unreachable;
    }

    _ = try dir.createFile("x", .{});
    _ = try dir.createFile("y", .{});
    _ = try dir.createFile("z", .{});

    var file_count: usize = 0;
    var iter = dir.iterate();
    while (try iter.next()) |entry| {
        if (entry.kind == .File) file_count += 1;
    }

    try expect(file_count == 3);
}