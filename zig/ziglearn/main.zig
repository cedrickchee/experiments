const std = @import("std");
const int_sort = @import("int_sort.zig");

pub fn main() void {
    std.debug.print("Hello, {s}!\n", .{"World"});
}