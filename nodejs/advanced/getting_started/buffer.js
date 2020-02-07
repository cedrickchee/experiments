/**
 * Node.js Buffers
 *
 * **What is a buffer?**
 * A buffer is an area of memory. JavaScript developers are not familiar with
 * this concept, much less than C, C++ or Go developers (or any programmer that
 * uses a system programming language), which interact with memory every day.
 *
 * It represents a fixed-size chunk of memory (can't be resized) allocated
 * outside of the V8 JavaScript engine.
 *
 * You can think of a buffer like an array of integers, which each represent a
 * byte of data.
 *
 * It is implemented by the Node.js Buffer class.
 *
 *
 * **Why do we need a buffer?**
 * Buffers were introduced to help developers deal with binary data, in an
 * ecosystem that traditionally only dealt with strings rather than binaries.
 *
 * Buffers are deeply linked with streams. When a stream processor receives data
 * faster than it can digest, it puts the data in a buffer.
 *
 * A simple visualization of a buffer is when you are watching a YouTube video
 * and the red line goes beyond your visualization point: you are downloading
 * data faster than you're viewing it, and your browser buffers it.
 *
 *
 * **How to create a buffer**
 * A buffer is created using the `Buffer.from()`, `Buffer.alloc()`, and
 * `Buffer.allocUnsafe()` methods.
 */
const buf1 = Buffer.from("Hey!");

// You can also just initialize the buffer passing the size.
// This creates a 1KB buffer:
const buf2 = Buffer.alloc(1624);
// or
// const buf2 = Buffer.allocUnsafe(1024);

// While both alloc and allocUnsafe allocate a Buffer of the specified size in
// bytes, the Buffer created by alloc will be initialized with zeroes and the
// one created by allocUnsafe will be uninitialized. This means that while
// allocUnsafe would be quite fast in comparison to alloc, the allocated
// segment of memory may contain old data which could potentially be sensitve.
//
// Older data, if present in the memory, can be accessed or leaked when the
// Buffer memory is read. This is what really makes allocUnsafe unsafe and extra
// care must be taken while using it.

// **Using a buffer**
//
// Access the content of a buffer
// A buffer, being an array of bytes, can be accessed like an array:
const buf3 = Buffer.from("Hey!");
console.log(buf3[0]); // 72
console.log(buf3[1]); // 101
console.log(buf3[2]); // 121
// Those numbers are the Unicode Code that identifies the character in
// the buffer position (H => 72, e => 101, y => 121)

// You can print the full content of the buffer using the toString() method:
console.log(buf3.toString());

// Get the length of a buffer
console.log(buf3.length); // 4

// Iterate over the contents of a buffer
for (const item of buf3) {
  console.log(item); // 72 101 121 33
}

// Changing the content of a buffer
const buf4 = Buffer.alloc(4); // allocate 4 bytes
buf4.write("Hey!");
// Just like you can access a buffer with an array syntax, you can also
// set the contents of the buffer in the same way:
buf4[1] = 111; // o
console.log(buf4.toString()); // 'Hoy!'

// Copy a buffer
let buf4copy = Buffer.alloc(4);
buf4.copy(buf4copy);
console.log(buf4copy.toString()); // 'Hoy!'

// By default you copy the whole buffer.
// 3 more parameters let you define the starting position, the ending position,
// and the new buffer length:
const buf5 = Buffer.from("John");
let buf5copy = Buffer.alloc(2);
buf5.copy(buf5copy, 0, 0, 2);
console.log(buf5copy.toString()); // 'Jo'

// Slice a buffer
//
// If you want to create a partial visualization of a buffer, you can create
// a slice. A slice is not a copy: the original buffer is still the source of
// truth. If that changes, your slice changes.
//
// The first parameter is the starting position, and you can specify an optional
// second parameter with the end position:
const buf6 = Buffer.from("Hello");
console.log(buf6.slice(0).toString()); // 'Hello'
const slice = buf6.slice(0, 2);
console.log(slice.toString()); // 'He'
buf6[1] = 111; // o
console.log(slice.toString()); // 'Ho'
