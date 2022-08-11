const std = @import("std");
const Builder = std.build.Builder;

pub fn build(b: *Builder) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("hello", "hello.zig");
    exe.linkLibC();
    exe.linkSystemLibrary("hello");
    exe.addIncludeDir("./");
    exe.addLibraryPath("./");
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const go = build_go(b);
    const make_step = b.step("go", "Make Go library");
    make_step.dependOn(&go.step);

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

fn build_go(b: *std.build.Builder) *std.build.RunStep {

    const go = b.addSystemCommand(
        &[_][]const u8{
            "go",
            "build",
            "-buildmode",
            "c-archive",
            "-o",
            "libhello.a",
            "hello.go",
        },
    );
    return go;
}