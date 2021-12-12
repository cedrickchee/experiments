const std = @import("std");

// ************************************************************************
// Build System
// ************************************************************************

//
// Outputting an Executable
//

// Let’s create a tiny hello world.
// Run `zig build-exe ./tiny-hello.zig -O ReleaseSmall --strip --single-threaded`
// Currently for x86_64-linux, this produces a 5.4KiB ELF.
pub fn main() void {
    std.io.getStdOut().writeAll(
        "Hello World!",
    ) catch unreachable;
}