/**
 * Understanding process.nextTick()
 *
 * As you try to understand the Node.js event loop, one important part of it is
 * process.nextTick().
 *
 * Every time the event loop takes a full trip, we call it a tick.
 */

// When we pass a function to `process.nextTick()`, we instruct the engine to
// invoke this function at the end of the current operation, before the next
// event loop tick starts.

// Example below was based on this SO question:
// https://stackoverflow.com/questions/40629456/why-and-when-to-use-process-nexttick
function myFunc(name) {
  return f;

  function f() {
    var n = name;
    console.log("Next TICK " + n);
  }
}

function myTimeout(time, msg) {
  setTimeout(function() {
    console.log("TIMEOUT " + msg);
  }, time);
}

// Prints:
// Next TICK one
// Next TICK two
// Next TICK three
// Next TICK four
// TIMEOUT after one
// TIMEOUT after two
// TIMEOUT after three
process.nextTick(myFunc("one"));
myTimeout(0, "after one");

process.nextTick(myFunc("two"));
myTimeout(0, "after two");

process.nextTick(myFunc("three"));
myTimeout(0, "after three");

process.nextTick(myFunc("four"));

/**
 * It's the way we can tell the JS engine to process a function asynchronously
 * (after the current function), but as soon as possible, not queue it.
 *
 * Calling setTimeout(() => {}, 0) will execute the function at the end of
 * next tick, much later than when using nextTick() which prioritizes the call
 * and executes it just before the beginning of the next tick.
 *
 * Use nextTick() when you want to make sure that in the next event loop
 * iteration that code is already executed.
 */
