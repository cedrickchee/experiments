pub fn main() void {
    // ************************************************************************
    // Basics
    // ************************************************************************

    //
    // Assignment
    //

    const constant: i32 = 5; // signed 32-bit constant
    var variable: u32 = 5000; // unsigned 32-bit variable
    
    // @as performs an explicit type coercion
    const inferred_constant = @as(i32, 5);
    var inferred_variable = @as(u32, 5000);

    // Constants and variables must have a value.
    const a: i32 = undefined;

    //
    // Arrays
    //
    const hello = [5]u8{ 'h', 'e', 'l', 'l', 'o' };
    const world = [_]u8{ 'w', 'o', 'r', 'l', 'd' };
    const length = world.len; // 5
}