import { dlopen, FFIType, suffix, viewSource } from "bun:ffi";

// `suffix` is either "dylib", "so", or "dll" depending on the platform
// you don't have to use "suffix", it's just there for convenience
const path = `./libfoo.${suffix}`;

const {
  symbols: {
    // foo is the function we will call
    foo,
    // add is the function we will call
    add,
  },
} =
  // dlopen() expects:
  // 1. a library name or file path
  // 2. a map of symbols
  dlopen(path, {
    // `foo` is a function that returns void
    foo: {
      // foo takes no arguments
      args: [],
      returns: FFIType.ptr,
    },
    // `add` is a function that returns an integer
    add: {
      // add takes two arguments of both integer
      args: [FFIType.i32, FFIType.i32],
      // add returns an integer
      returns: FFIType.i32,
    }
  });

console.log(`foo: ${foo()}`);
console.log(`add: ${add(10, 29)}`);
