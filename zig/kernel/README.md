# Kernel

A simple hello world kernel in Zig.

## Prerequisites

First off, you'll need:
- The Zig compiler, at least version 0.7.0
- QEMU
- [GRUB][grub] as our bootloader to boot the kernel
- [xorriso][xorriso] - a command line ISO-9660 manipulation tool. It is required
  by `grub-mkrescue`
- [mtools][mtools] - tools for manipulating MSDOS files. It is required by `grub-mkrescue`

[grub]: https://wiki.osdev.org/GRUB
[xorriso]: https://www.gnu.org/software/xorriso/
[mtools]: https://www.gnu.org/software/mtools/ 

If you're on Debian-based system, you can install xorriso and mtools using `apt`:
```sh
$ sudo apt install xorriso
[...]
The following additional packages will be installed:
  libburn4 libisoburn1 libisofs6 libjte2

$ sudo apt install mtools
```

## Build

Build kernel by running the command below:

```sh
$ zig build
xorriso 1.5.2 : RockRidge filesystem manipulator, libburnia project.

Drive current: -outdev 'stdio:~/repo/github/experiments/zig/kernel/zig-out/bin/disk.iso'
Media current: stdio file, overwriteable
Media status : is blank
Media summary: 0 sessions, 0 data blocks, 0 data, 1000g free
Added to ISO image: directory '/'='/tmp/grub.9Jng2d'
xorriso : UPDATE :     574 files added in 1 seconds
Added to ISO image: directory '/'='~/repo/github/experiments/zig/kernel/zig-cache/iso_root'
xorriso : UPDATE :     576 files added in 1 seconds
xorriso : NOTE : Copying to System Area: 512 bytes from file '/usr/lib/grub/i386-pc/boot_hybrid.img'
ISO image produced: 5628 sectors
Written to medium : 5628 sectors at LBA 0
Writing to 'stdio:~/repo/github/experiments/zig/kernel/zig-out/bin/disk.iso' completed successfully.
```

To boot our kernel using QEMU, simply run this command:

```sh
$ zig build run
```

## Review

I experienced the following issues/problems:
- `zig-081 build` failed with error:
    ```sh
    ./build.zig:35:35: error: no member named 'path' in '[]const u8'
    kernel.setLinkerScriptPath(.{ .path = "src/linker.ld" });
    ```
    Related issue: https://github.com/FireFox317/avr-arduino-zig/issues/3
    
    Works with Zig 0.10.0-dev.3414+4c750016e.
- `zig build` failed with error "Segmentation fault (core dumped)"
    ```sh
    $ zig build-exe \
    src/main.zig \
    --name kernel.elf \
    -mcmodel kernel \
    -mcpu=pentium4-mmx+soft_float-sse-sse2 \
    -target i386-freestanding-none \
    --script src/linker.ld \
    --enable-cache
    ```
    It works if we remove this flag `-mcpu=pentium4-mmx+soft_float-sse-sse2`

    So, we do the same change but in `build.zig`:

    ```zig
    const target = CrossTarget{
        .cpu_arch = Target.Cpu.Arch.i386,
        .os_tag = Target.Os.Tag.freestanding,
        .abi = Target.Abi.none,
        .cpu_features_sub = disabled_features, // <-- remove this line
        .cpu_features_add = enabled_features // <-- remove this line
    };    
    ```
- "grub-mkrescue: error: xorriso not found.". See this [SO thread][so-thread-osdev-grub] for more info.
- "grub-mkrescue: error: `mformat` invocation failed". `mformat` is part of
  `mtools`. See this [GitHub Issue][gh-issue-mformat] for more info.
- [Making a GRUB bootable
  CD-ROM](https://www.gnu.org/software/grub/manual/grub/html_node/Making-a-GRUB-bootable-CD_002dROM.html)
  - Fix `grub-mkrescue grub.cfg` command.
- GRUB error "no multiboot header found". Fix linker script `linker.ld`. Changed
  from `*(.multiboot)` to `KEEP(*(.multiboot))`

[so-thread-osdev-grub]: https://stackoverflow.com/q/45991142/206570
[gh-issue-mformat]: https://github.com/Distroshare/distroshare-ubuntu-imager/issues/23

**QEMU**

[How to quit the QEMU monitor when not using a GUI?](https://superuser.com/questions/1087859/how-to-quit-the-qemu-monitor-when-not-using-a-gui).

## Acknowledgement

- [Zig Bare Bones](https://wiki.osdev.org/Zig_Bare_Bones)
- ["hello world" x86 kernel example](https://github.com/andrewrk/HellOS) by the
  Zig's creator
- [ClashOS](https://github.com/andrewrk/clashos) - multiplayer arcade game for
  bare metal Raspberry Pi 3 B+
