/**
 * What are streams
 *
 * Streams are one of the fundamental concepts that power Node.js applications.
 *
 * They are a way to handle reading/writing files, network communications, or
 * any kind of end-to-end information exchange in an efficient way.
 *
 * Streams are not a concept unique to Node.js. They were introduced in the
 * Unix operating system decades ago, and programs can interact with each other
 * passing streams through the pipe operator (|).
 *
 * For example, in the traditional way, when you tell the program to read a
 * file, the file is read into memory, from start to finish, and then you
 * process it.
 *
 * Using streams you read it piece by piece, processing its content without
 * keeping it all in memory.
 *
 * The Node.js stream module provides the foundation upon which all streaming
 * APIs are build. All streams are instances of EventEmitter.
 *
 * Code-wise, a stream is an abstract interface for working with streaming data.
 *
 * There are many stream objects provided by Node.js. For instance,
 * a request to an HTTP server and process.stdout are both stream instances.
 *
 * Streams can be readable, writable, or both.
 *
 *
 * **Why streams**
 * Streams basically provide two major advantages using other data handling
 * methods:
 * - Memory efficiency: you don't need to load large amounts of data in memory
 * before you are able to process it
 * - Time efficiency: it takes way less time to start processing data as soon as
 * you have it, rather than waiting till the whole data payload is available
 * to start
 */

// Example: reading files from a disk.
// Using the Node.js fs module you can read a file, and serve it over HTTP when
// a new connection is established to your http server:
const http = require("http");
const fs = require("fs");

// const server = http.createServer((req, res) => {
//   fs.readFile(__dirname + "/sample_data.txt", (err, data) => {
//     res.end(data);
//   });
// });

// server.listen(3000);

// If the file is big, the operation will take quite a bit of time.
// Here is the same thing written using streams:
const server = http.createServer((req, res) => {
  // Instead of waiting until the file is fully read, we start streaming it to
  // the HTTP client as soon as we have a chunk of data ready to be sent.
  const stream = fs.createReadStream(__dirname + "/sample_data.txt");
  stream.pipe(res);
});

server.listen(3000);

// Pipe
// The above example uses the line stream.pipe(res): the pipe() method is called
// on the file stream.
//
// What does this code do? It takes the source, and pipes it into a destination.
//
// You call it on the source stream, so in this case, the file stream is piped
// to the HTTP response.
//
// The return value of the pipe() method is the destination stream, which is a
// very convenient thing that lets us chain multiple pipe() calls, like this:
// src.pipe(dest1).pipe(dest2);
// This construct is the same as doing
// src.pipe(dest1);
// dest1.pipe(dest2);

// Streams-powered Node.js APIs
//
// Due to their advantages, many Node.js core modules provide native stream
// handling capabilities, most notably:
// - `process.stdin` returns a stream connected to stdin
// - `fs.createReadStream()` creates a readable stream to a file
// - `net.connect()` initiates a stream-based connection
// - `http.request()` returns an instance of the http.ClientRequest class,
// which is a writable stream
// - `zlib.createGzip()` compress data using gzip (a compression algorithm)
// into a stream

// Different types of streams
//
// There are four classes of streams:
// - Readable: a stream you can pipe from, but not pipe into (you can receive
// data, but not send data to it). When you push data into a readable stream,
// it is buffered, until a consumer starts to read the data.
// - Writable: a stream you can pipe into, but not pipe from (you can send data,
// but not receive from it)
// - Duplex: a stream you can both pipe into and pipe from, basically a
// combination of a Readable and Writable stream
// - Transform: a Transform stream is similar to a Duplex, but the output is a
// transform of its input

// How to create a readable stream
//
// We get the Readable stream from the stream module, and we initialize it and
// implement the readable._read() method.

// First create a stream object:
const Stream = require("stream");
const readableStream = new Stream.Readable();

// then implement _read:
readableStream._read = () => {};

// You can also implement _read using the read option:
// const readableStream = new Stream.Readable({
//   read() {}
// });

// Now that the stream is initialized, we can send data to it:
readableStream.push("hi!");
readableStream.push("yo!");

// How to create a writable stream
//
// To create a writable stream we extend the base Writable object, and we
// implement its _write() method.

// First create a stream object:
const writableStream = new Stream.Writable();

// then implement _write:
writableStream._write = (chunk, encoding, next) => {
  console.log(chunk.toString());
  next();
};

// You can now pipe a readable stream in:
process.stdin.pipe(writableStream);

// How to get data from a readable stream
//
// How do we read data from a readable stream? Using a writable stream:
const readableStream2 = new Stream.Readable({
  read() {}
});
const writableStream2 = new Stream.Writable();

writableStream2._write = (chunk, encoding, next) => {
  console.log(chunk.toString());
  next();
};

readableStream2.pipe(writableStream2);

readableStream2.push("hi!");
readableStream2.push("yo!");

// You can also consume a readable stream directly, using the readable event:
readableStream2.on("readable", () => {
  console.log(readableStream2.read().toString());
});

// How to send data to a writable stream
//
// Using the stream write() method:
// writableStream2.write("hey!\n");

// Signaling a writable stream that you ended writing
//
// Use the end() method:
writableStream2.end();

/**
 * How `pipe` really works: readable source will be paused if the queue for the
 * writable/transform/duplex destination stream is full. Otherwise, the readable
 * will be resumed and read.
 * Source: https://nodejs.org/en/docs/guides/backpressuring-in-streams
 */

/**
 * Lifecycle of `.pipe()`
 *
 * To achieve a better understanding of backpressure, here is a flow-chart on
 * the lifecycle of a `Readable` stream being piped into a `Writable` stream:

                                                     +===================+
                         x-->  Piping functions   +-->   src.pipe(dest)  |
                         x     are set up during     |===================|
                         x     the .pipe method.     |  Event callbacks  |
  +===============+      x                           |-------------------|
  |   Your Data   |      x     They exist outside    | .on('close', cb)  |
  +=======+=======+      x     the data flow, but    | .on('data', cb)   |
          |              x     importantly attach    | .on('drain', cb)  |
          |              x     events, and their     | .on('unpipe', cb) |
+---------v---------+    x     respective callbacks. | .on('error', cb)  |
|  Readable Stream  +----+                           | .on('finish', cb) |
+-^-------^-------^-+    |                           | .on('end', cb)    |
  ^       |       ^      |                           +-------------------+
  |       |       |      |
  |       ^       |      |
  ^       ^       ^      |    +-------------------+         +=================+
  ^       |       ^      +---->  Writable Stream  +--------->  .write(chunk)  |
  |       |       |           +-------------------+         +=======+=========+
  |       |       |                                                 |
  |       ^       |                              +------------------v---------+
  ^       |       +-> if (!chunk)                |    Is this chunk too big?  |
  ^       |       |     emit .end();             |    Is the queue busy?      |
  |       |       +-> else                       +-------+----------------+---+
  |       ^       |     emit .write();                   |                |
  |       ^       ^                                   +--v---+        +---v---+
  |       |       ^-----------------------------------<  No  |        |  Yes  |
  ^       |                                           +------+        +---v---+
  ^       |                                                               |
  |       ^               emit .pause();          +=================+     |
  |       ^---------------^-----------------------+  return false;  <-----+---+
  |                                               +=================+         |
  |                                                                           |
  ^            when queue is empty     +============+                         |
  ^------------^-----------------------<  Buffering |                         |
               |                       |============|                         |
               +> emit .drain();       |  ^Buffer^  |                         |
               +> emit .resume();      +------------+                         |
                                       |  ^Buffer^  |                         |
                                       +------------+   add chunk to queue    |
                                       |            <---^---------------------<
                                       +============+

*/
