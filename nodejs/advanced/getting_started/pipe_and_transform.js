/**
 * Pipe and Transform Node.js Streams
 */

// Example: encrypts and zips
const fs = require("fs");
const crypto = require("crypto");
const zlib = require("zlib");

const SECRET = "s0m3rnd53cret$042139";

const r = fs.createReadStream("sample_data.txt");
const e = crypto.createCipher("aes256", SECRET);
const z = zlib.createGzip();
const w = fs.createWriteStream("sample_data.txt.gz");

r.pipe(e)
  .pipe(z)
  // with pipe, we can listen to events too!
  .on("data", () => process.stdout.write(".")) // progress dot "."
  .pipe(w)
  .on("finish", () => console.log("all is done!")); // when all is done
