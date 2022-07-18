# Bun.js Examples

Bun examples. Mostly learning `bun:ffi`, Bun's Foreign Function Interface (FFI).

I am also attempting to compile embeddable WireGuard C library into a shared library (`*.so` shared object) aka. dynamic-linked library. I want to create a Bun bindings for WireGuard. Bun also supports the N-API method (Node.js native module) but N-API is slower (and has not received proper maintenance for a long time).

I managed to create one that binds to Raylib shared library. I can create a simple game (graphics) demo using that binding. It's quite cool that we can create game in JavaScript.

This is an exciting experiment. I learned so much about FFI, C compiler (compiling shared libs with GCC on Linux), some Zig, compiling Go library into shared library and Bun's internals.

I am currently stuck. Bun's FFIType doesn't support object/complex type (for example passing C struct from JS). They do support the `ptr` type but this feels clunky. I think Bun's team are still considering a better way to implement this feature which will provide good performance when switching between the two worlds (JS<->C) through FFI.

I stop this hacking for now and plan to revisit this project later.
