import { dlopen, FFIType, suffix, viewSource } from "bun:ffi";

// DEBUG
console.log("suffix:", suffix); // prints "so"
// console.log(
//         viewSource(
//             {
//             hello_world: {
//                 returns: "float",
//                 args: ["float"],
//             },
//             },
//             false
//         )[0]
//     );
// END DEBUG


// `suffix` is either "dylib", "so", or "dll" depending on the platform
// you don't have to use "suffix", it's just there for convenience
const path = `libsqlite3.${suffix}`;

const {
  symbols: {
    // sqlite3_libversion is the function we will call
    sqlite3_libversion,
  },
} =
  // dlopen() expects:
  // 1. a library name or file path
  // 2. a map of symbols
  dlopen(path, {
    // `sqlite3_libversion` is a function that returns a string
    sqlite3_libversion: {
      // sqlite3_libversion takes no arguments
      args: [],
      // sqlite3_libversion returns a pointer to a string
      returns: FFIType.cstring,
    },
  });

console.log(`SQLite 3 version: ${sqlite3_libversion()}`);
