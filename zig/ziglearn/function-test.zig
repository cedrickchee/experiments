const expect = @import("std").testing.expect;

// ************************************************************************
// Basics
// ************************************************************************

//
// Functions
//

// All function arguments are immutable.
fn addFive(x: u32) u32 {
    return x + 5;
}

// Declaring and calling a simple function.
test "function" {
    const y = addFive(0);
    try expect(@TypeOf(y) == u32);
    try expect(y == 5);
}

// Recursion is allowed.
fn fibonacci(n: u16) u16 {
    if (n == 0 or n == 1) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}

test "function recursion" {
    const x = fibonacci(10);
    try expect(x == 55);
}
