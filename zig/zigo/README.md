# Interop: Calling Zig from Go

Code in this project is based on Frank Denis's blog post: [ZGo (part 1): Calling Zig from Go](https://jedi.sh/zigo)

> Interop with C has always been a key feature of Zig.

> It turns out to be quite simple to interface with Zig from Go. By utilizing
> Cgo and the new features of the zig compiler we can easily make calls into
> Zig.

## Building a Library

The `build.zig` code that was given by the blog post doesn't work. It's missing
a few things.

The issue is that modern linkers expect (and modern C compilers emit)
position-independent code (PIC). It's easy to tell Zig's build system to do the
same, by adding the line `lib.force_pic = true;`. Otherwise, running `zig build go`
command will fail with error:

"/usr/bin/ld: ./libzgo.a(./libzgo.a.o): relocation R_X86_64_32against `.bss' can not be used when making a PIE object; recompile with -fPIE"

## Compile

First, build Zig library:

```sh
$ zig build
```

This will output two files: `zgo.h` and `libzgo.a`.

Then, build Go binary:

```sh
$ zig build go
```

Run Go binary:

```sh
$ ./bridge
Invoking zig library!
Done  12
```

Success!
