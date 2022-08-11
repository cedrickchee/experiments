const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const lib = b.addStaticLibrary("sodium", "src/sodium.zig");
    lib.setBuildMode(mode);
    lib.install();

    var tests = b.addTest("src/sodium.zig");
    tests.setBuildMode(mode);
    tests.linkSystemLibrary("c");
    tests.linkSystemLibrary("sodium");

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&tests.step);
}
