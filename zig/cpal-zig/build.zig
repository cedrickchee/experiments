const std = @import("std");

fn addCpalImport(root_module: *std.Build.Module, cpal_mod: *std.Build.Module) void {
    root_module.addImport("cpal_zig", cpal_mod);
}

fn linkAudioLibraries(module: *std.Build.Module) void {
    module.link_libc = true;
    module.linkSystemLibrary("alsa", .{ .use_pkg_config = .yes });
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const cpal_mod = b.addModule("cpal_zig", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    linkAudioLibraries(cpal_mod);

    const lib = b.addLibrary(.{
        .name = "cpal_zig",
        .root_module = cpal_mod,
    });
    b.installArtifact(lib);

    const examples = [_]struct {
        name: []const u8,
        path: []const u8,
    }{
        .{ .name = "list_hosts_devices", .path = "examples/list_hosts_devices.zig" },
        .{ .name = "print_stream_configs", .path = "examples/print_stream_configs.zig" },
        .{ .name = "open_output_stream", .path = "examples/open_output_stream.zig" },
        .{ .name = "sine_wave", .path = "examples/sine_wave.zig" },
        .{ .name = "record_input", .path = "examples/record_input.zig" },
        .{ .name = "input_output_feedback", .path = "examples/input_output_feedback.zig" },
    };

    inline for (examples) |example| {
        const exe_mod = b.createModule(.{
            .root_source_file = b.path(example.path),
            .target = target,
            .optimize = optimize,
            .imports = &.{.{ .name = "cpal_zig", .module = cpal_mod }},
        });
        linkAudioLibraries(exe_mod);

        const exe = b.addExecutable(.{
            .name = example.name,
            .root_module = exe_mod,
        });
        b.installArtifact(exe);
    }

    const unit_tests = b.addTest(.{ .root_module = cpal_mod });
    const run_unit_tests = b.addRunArtifact(unit_tests);

    const integration_mod = b.createModule(.{
        .root_source_file = b.path("tests/api.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "cpal_zig", .module = cpal_mod }},
    });
    linkAudioLibraries(integration_mod);
    const integration_tests = b.addTest(.{ .root_module = integration_mod });
    const run_integration_tests = b.addRunArtifact(integration_tests);

    const test_step = b.step("test", "Run library and integration tests");
    test_step.dependOn(&run_unit_tests.step);
    test_step.dependOn(&run_integration_tests.step);
}
