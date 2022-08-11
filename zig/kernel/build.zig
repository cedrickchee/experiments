const std = @import("std");
const Builder = @import("std").build.Builder;
const Target = @import("std").Target;
const CrossTarget = @import("std").zig.CrossTarget;
const Feature = @import("std").Target.Cpu.Feature;
 
pub fn build(b: *Builder) void {
    //const features = Target.x86.Feature;
 
    //var disabled_features = Feature.Set.empty;
    //var enabled_features = Feature.Set.empty;
 
    //disabled_features.addFeature(@enumToInt(features.mmx));
    //disabled_features.addFeature(@enumToInt(features.sse));
    //disabled_features.addFeature(@enumToInt(features.sse2));
    //disabled_features.addFeature(@enumToInt(features.avx));
    //disabled_features.addFeature(@enumToInt(features.avx2));
    //enabled_features.addFeature(@enumToInt(features.soft_float));
 
    const target = CrossTarget{
        .cpu_arch = Target.Cpu.Arch.i386,
        .os_tag = Target.Os.Tag.freestanding,
        .abi = Target.Abi.none,
        // .cpu_features_sub = disabled_features,
        // .cpu_features_add = enabled_features
    };
 
    const mode = b.standardReleaseOptions();
 
    // Build the kernel

    const kernel = b.addExecutable("kernel.elf", "src/main.zig");
    kernel.setTarget(target);
    kernel.setBuildMode(mode);
    //kernel.setLinkerScriptPath(.{ .path = "src/linker.ld" });
    // fix the previous problem
    kernel.setLinkerScriptPath(std.build.FileSource{ .path = "src/linker.ld" });
    kernel.code_model = .kernel;
    kernel.install();
 
    const kernel_step = b.step("kernel", "Build the kernel");
    kernel_step.dependOn(&kernel.install_step.?.step);
 
    // Build an ISO image

    const iso_dir = b.fmt("{s}/iso_root", .{b.cache_root});
    const kernel_path = b.getInstallPath(kernel.install_step.?.dest_dir, kernel.out_filename);
    const iso_path = b.fmt("{s}/disk.iso", .{b.exe_dir});
 
    const iso_cmd_str = &[_][]const u8{ 
        "/bin/sh", "-c",
        std.mem.concat(b.allocator, u8, &[_][]const u8{
            "mkdir -p ", iso_dir, " && ",
            "mkdir -p ", iso_dir, "/boot/grub && ",
            "cp ", kernel_path, " ", iso_dir, "/boot && ",
            "cp src/boot/grub/grub.cfg ", iso_dir, "/boot/grub && ",
            "grub-mkrescue -o ", iso_path, " ", iso_dir
        }) catch unreachable
    };
 
    const iso_cmd = b.addSystemCommand(iso_cmd_str);
    iso_cmd.step.dependOn(kernel_step);
 
    const iso_step = b.step("iso", "Build an ISO image");
    iso_step.dependOn(&iso_cmd.step);
    b.default_step.dependOn(iso_step);
 
    // Run the kernel using QEMU

    const run_cmd_str = &[_][]const u8{
        "sudo",
        "qemu-system-x86_64",
        "-cdrom", iso_path,
        // "-debugcon", "stdio", // disabled: causing error "cannot use stdio by multiple character devices"
        "-vga", "virtio",
        "-m", "256", // changed from 4G to 256
        "-machine", "q35,accel=kvm:whpx:tcg",
        // "-no-reboot", "-no-shutdown",
        // "-nographic" // disable graphical output so that QEMU is a simple command line program
    };
 
    const run_cmd = b.addSystemCommand(run_cmd_str);
    run_cmd.step.dependOn(b.getInstallStep());
 
    const run_step = b.step("run", "Run the kernel");
    run_step.dependOn(&run_cmd.step);
}