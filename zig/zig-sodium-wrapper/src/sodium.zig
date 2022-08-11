const std = @import("std");
const testing = std.testing;

const c = @cImport({
    @cInclude("sodium.h");
});

pub const crypto_box = @import("crypto_box.zig");
pub const SodiumError = @import("errors.zig").SodiumError;

/// Initialize libsodium. Call before other libsodium functions.
pub fn init() SodiumError!void {
    if (c.sodium_init() < 0) {
        return SodiumError.InitError;
    }
}

test "initialize" {
    try init();
    std.debug.print("libsodium init success\n", .{});
}

test "sodium" {
    // This is a Zig idiom for running tests in exported modules.
    _ = @import("crypto_box.zig");
}
