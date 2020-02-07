/**
 * Node.js file stats
 *
 * Every file comes with a set of details that we can inspect using Node.js.
 *
 * In particular, using the `stat()` method provided by the `fs` module.
 */
const fs = require("fs");
fs.stat("./sample_data.txt", (err, stats) => {
  if (err) {
    console.error(err);
    return;
  }
  // we have access to the file stats in `stats`
});

// Node.js provides also a sync method, which blocks the thread until the file
// stats are ready.

// The file information is included in the stats variable.
// What kind of information can we extract using the stats?
// - if the file is a directory or a file, using `stats.isFile()`
// and `stats.isDirectory()`
// - if the file is a symbolic link using `stats.isSymbolicLink()`
// - the file size in bytes using `stats.size`.
fs.stat("./sample_data.txt", (err, stats) => {
  if (err) {
    console.error(err);
    return;
  }

  console.log(stats.isFile()); // true
  console.log(stats.isDirectory()); // false
  console.log(stats.isSymbolicLink()); // false
  console.log(stats.size);
});
