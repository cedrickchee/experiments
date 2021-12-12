const std = @import("std");
const expect = std.testing.expect;

// ************************************************************************
// Standard Patterns
// ************************************************************************

//
// Allocators
// 

// The Zig standard library provides a pattern for allocating memory, which
// allows the programmer to choose exactly how memory allocations are done 
// within the standard library.

// Allocate 100 bytes as a []u8. Notice how defer is used in conjunction
// with a free - this is a common pattern for memory management in Zig.
test "allocation" {
    const allocator = std.heap.page_allocator;

    const memory = try allocator.alloc(u8, 100);
    defer allocator.free(memory);

    try expect(memory.len == 100);
    try expect(@TypeOf(memory) == []u8);
}

// An allocator that allocates memory into a fixed buffer, and does not make
// any heap allocations. This is useful when heap usage is not wanted, for
// example when writing a kernel. It may also be considered for
// performance reasons.
test "fixed buffer allocator" {
    var buffer: [1000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    var allocator = &fba.allocator;

    const memory = try allocator.alloc(u8, 100);
    defer allocator.free(memory);

    try expect(memory.len == 100);
    try expect(@TypeOf(memory) == []u8);
}

// Arena allocator takes in a child allocator, and allows you to allocate many
// times and only free once.
test "arena allocator" {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = &arena.allocator;

    _ = try allocator.alloc(u8, 1);
    _ = try allocator.alloc(u8, 10);
    _ = try allocator.alloc(u8, 100);
}