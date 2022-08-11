# Zig Cross Compilation

Read blog post by Loris: [Zig Makes Go Cross Compilation Just Work](https://dev.to/kristoff/zig-makes-go-cross-compilation-just-work-29ho)

> Zig can be used as a C/C++ cross compiler directly or from other toolchains.

> Let's see how to use Zig from Go.

## cgo Example

I need a quick and simple cgo example to try out cross compilation cgo with Zig.
The cgo example are mostly created based on this [cgo tutorial](https://karthikkaranth.me/blog/calling-c-code-from-go/).

## Compile

You can use the targets in the Makefile included.

## References

- [How to mix C and Go with cgo](https://github.com/AlekSi/cgo-by-example)

## Review

A bit off a tangent, [xmake](https://github.com/xmake-io/xmake) is a
cross-platform build utility based on Lua.
