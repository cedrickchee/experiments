const std = @import("std");

/// A simple example function, we export the symbol in the library. Note we use
/// the C ABI compatible type c_int.

pub export fn x(y: c_int) c_int {
    return y+2;
}