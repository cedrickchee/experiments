// 5 - Word Generator
//
// Generates random words by the given length (words, letters).

const std = @import("std");
const stdout = std.io.getStdOut().writer();

fn generateWords(allocator: std.mem.Allocator, word_len: usize, letter_len: usize) !void {
    // Randomizer engine: generates a new random number
    const rand_engine = std.rand.DefaultPrng.init(@intCast(u64, std.time.milliTimestamp())).random(); // std.time.milliTimestamp() is the seed

    // Word Index
    var wl: usize = 0;

    // allocate word
    var word = try allocator.alloc(u8, letter_len); // The word: list of letters
    defer allocator.free(word);
    while (wl < word_len) : (wl += 1) {
        // Previous letter
        var prev_letter: u8 = 0;

        // Letter index
        var li: usize = 0;

        while (li < letter_len) {
            // Generate a random letter
            const letter = rand_engine.intRangeLessThanBiased(u7, 'a', 'z');

            // We dont want repeated characters
            if (prev_letter == letter)
                continue;

            word[li] = letter; // Append letter to word
            prev_letter = letter;
            li += 1;
        }

        // Print the word
        try stdout.print("{s}\n", .{word});
    }
}

pub fn main() anyerror!void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = general_purpose_allocator.allocator();

    // Init words and letters count
    var letter_len: usize = 5;
    var word_len: usize = 5;

    // Get arguments
    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    // Check for arguments
    for (args[1..]) |arg, i| {
        const count = try std.fmt.parseUnsigned(usize, arg, 0);
        if (i == 1)
            letter_len = count
        else if (i == 2)
            word_len = count;
    }

    try generateWords(gpa, word_len, letter_len);
}

// Run executable with this command:
// $ zig run word-generator.zig -- 5 4 # <letters count> <words count>
// vral
// wdsl
// ubne
// eabn
// fmva
