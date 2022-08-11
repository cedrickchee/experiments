// 3 - Hasher
//
// Takes the input and hash it with Blake 3 algorithm.

const std = @import("std");
const stdout = std.io.getStdOut().writer();
const hash = std.crypto.hash;

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpose_allocator.allocator();

    // Get Arguments
    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    // Check for Arguments
    if (args.len < 2) {
        try stdout.writeAll("expected input argument\n");
        return;
    }

    var input = args[1]; // hash input from first argument
    var output: [hash.Blake3.digest_length]u8 = undefined; // this will be hash result

    hash.Blake3.hash(input, &output, .{});

    try stdout.print("{s}\n", .{std.fmt.fmtSliceHexLower(&output)});
}

// Run executable with this command:
// $ zig run hasher.zig -- "hello"
// ea8f163db38682925e4491c5e58d4bb3506ef8c14eb78a86e908c5624a67200f
