/// Wrap crypto_box module.
///
/// crypto_box lets us generate public/private key pairs and
/// encrypt messages using the public key that can only be decrypted by the private
/// key.

const std = @import("std");

const sodium = @import("sodium.zig");
const SodiumError = @import("errors.zig").SodiumError;

const c = @cImport({
    @cInclude("sodium.h");
});

/// Wrap crypto_box_keypair function

pub const PUBLICKEYBYTES = c.crypto_box_PUBLICKEYBYTES;
pub const SECRETKEYBYTES = c.crypto_box_SECRETKEYBYTES;

/// Generate a public/private key pair for use in other functions in
/// this module.
pub fn keyPair(
    pub_key: *[PUBLICKEYBYTES]u8,
    secret_key: *[SECRETKEYBYTES]u8,
) !void {
    if (c.crypto_box_keypair(pub_key, secret_key) != 0) {
        return SodiumError.KeyGenError;
    }
}

test "generate key" {
    var pub_key: [PUBLICKEYBYTES]u8 = undefined;
    var secret_key: [SECRETKEYBYTES]u8 = undefined;
    try sodium.init();
    try keyPair(&pub_key, &secret_key);
}
