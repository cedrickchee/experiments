const std = @import("std");
const Builder = std.build.Builder;
const builtin = std.builtin;

// The builder breaks the process down into build step objects that can depend
// on each other and contain build semantics.

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const lib = b.addStaticLibrary("zgo", "zgo.zig");
    lib.bundle_compiler_rt = true;
    lib.use_stage1 = false;
    lib.emit_h = true;
    // Override the default output location with .emit_bin for simplicity.
    lib.emit_bin = .{ .emit_to = "libzgo.a"};    
    // fix error - tell Zig's build system (linker/compiler) to emit position-independent code (PIC)
    lib.force_pic = true;
    lib.setBuildMode(mode);
    lib.install();

    const go = build_go(b);
    const make_step = b.step("go", "Make go executable");
    make_step.dependOn(&go.step);
}

fn build_go(b: *std.build.Builder) *std.build.RunStep {
    // Generally compiler flags are exposed as fields or methods.
    const go = b.addSystemCommand(
        &[_][]const u8{
            "go",
            "build",
            "-ldflags", "-linkmode external -extldflags -static",
            "bridge.go",
        },
    );
    return go;
}