const std = @import("std");

fn addCpalImport(root_module: *std.Build.Module, cpal_mod: *std.Build.Module) void {
    root_module.addImport("cpal_zig", cpal_mod);
}

fn linkAudioLibraries(module: *std.Build.Module) void {
    module.link_libc = true;
    module.linkSystemLibrary("alsa", .{ .use_pkg_config = .yes });
    module.linkSystemLibrary("pthread", .{});
}

fn linkWinampLibraries(module: *std.Build.Module) void {
    linkAudioLibraries(module);
    module.linkSystemLibrary("avformat", .{ .use_pkg_config = .yes });
    module.linkSystemLibrary("avcodec", .{ .use_pkg_config = .yes });
    module.linkSystemLibrary("avutil", .{ .use_pkg_config = .yes });
    module.linkSystemLibrary("swresample", .{ .use_pkg_config = .yes });
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const vaxis_dep = b.dependency("vaxis", .{
        .target = target,
        .optimize = optimize,
    });

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
        .{ .name = "open_fixed_buffer_stream", .path = "examples/open_fixed_buffer_stream.zig" },
        .{ .name = "deinit_running_stream", .path = "examples/deinit_running_stream.zig" },
        .{ .name = "stream_lifecycle", .path = "examples/stream_lifecycle.zig" },
        .{ .name = "sine_wave", .path = "examples/sine_wave.zig" },
        .{ .name = "record_input", .path = "examples/record_input.zig" },
        .{ .name = "input_output_feedback", .path = "examples/input_output_feedback.zig" },
        .{ .name = "open_f32_streams", .path = "examples/open_f32_streams.zig" },
        .{ .name = "open_i8_streams", .path = "examples/open_i8_streams.zig" },
        .{ .name = "open_u8_streams", .path = "examples/open_u8_streams.zig" },
        .{ .name = "open_i16_streams", .path = "examples/open_i16_streams.zig" },
        .{ .name = "open_u16_streams", .path = "examples/open_u16_streams.zig" },
        .{ .name = "open_i24_streams", .path = "examples/open_i24_streams.zig" },
        .{ .name = "open_u24_streams", .path = "examples/open_u24_streams.zig" },
        .{ .name = "open_i32_streams", .path = "examples/open_i32_streams.zig" },
        .{ .name = "open_u32_streams", .path = "examples/open_u32_streams.zig" },
        .{ .name = "open_f64_streams", .path = "examples/open_f64_streams.zig" },
        .{ .name = "print_rich_capabilities", .path = "examples/print_rich_capabilities.zig" },
        .{ .name = "hotplug_snapshot", .path = "examples/hotplug_snapshot.zig" },
        .{ .name = "stream_diagnostics", .path = "examples/stream_diagnostics.zig" },
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

    const winamp_mod = b.createModule(.{
        .root_source_file = b.path("demos/winamp/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "cpal_zig", .module = cpal_mod },
            .{ .name = "vaxis", .module = vaxis_dep.module("vaxis") },
        },
    });
    linkWinampLibraries(winamp_mod);

    const winamp_exe = b.addExecutable(.{
        .name = "winamp",
        .root_module = winamp_mod,
    });
    b.installArtifact(winamp_exe);

    const run_winamp = b.addRunArtifact(winamp_exe);
    if (b.args) |args| run_winamp.addArgs(args);

    const winamp_step = b.step("winamp", "Build the Winamp-style TUI demo");
    winamp_step.dependOn(&winamp_exe.step);

    const run_winamp_step = b.step("run-winamp", "Run the Winamp-style TUI demo");
    run_winamp_step.dependOn(&run_winamp.step);

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
