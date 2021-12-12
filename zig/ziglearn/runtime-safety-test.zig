const expect = @import("std").testing.expect;

// ************************************************************************
// Basics
// ************************************************************************

//
// Runtime Safety
//

// Runtime safety protects you from out of bounds indices.
test "out of bounds" {
    const a = [3]u8{ 1, 2, 3 };
    var index: u8 = 5;
    const b = a[index];
    _ = b;
}

// The user may choose to disable runtime safety for the current block.
// test "out of bounds, no safety" {
//     @setRuntimeSafety(false);
//     const a = [3]u8{ 1, 2, 3 };
//     var index: u8 = 5;
//     const b = a[index];
//     _ = b;
// }