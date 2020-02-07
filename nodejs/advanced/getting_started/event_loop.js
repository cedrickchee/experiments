/**
 * The Node.js Event Loop
 *
 * The Event Loop is one of the most important aspects to understand about
 * Node.js.
 *
 * Why is this so important? Because it explains how Node.js can be asynchronous
 * and have non-blocking I/O, and so it explains basically the "killer app" of
 * Node.js, the thing that made it this successful.
 *
 * The Node.js JavaScript code runs on a single thread. There is just one thing
 * happening at a time.
 *
 * This is a limitation that's actually very helpful, as it simplifies a lot how
 * you program without worrying about concurrency issues.
 *
 * You just need to pay attention to how you write your code and avoid anything
 * that could block the thread, like synchronous network calls or
 * infinite loops.
 *
 * You mainly need to be concerned that your code will run on a single event
 * loop, and write code with this thing in mind to avoid blocking it.
 *
 *
 * **Blocking the event loop**
 * Any JavaScript code that takes too long to return back control to the event
 * loop will block the execution of any JavaScript code in the page, even block
 * the UI thread, and the user cannot click around, scroll the page, and so on.
 *
 * Almost all the I/O primitives in JavaScript are non-blocking. Network
 * requests, filesystem operations, and so on. Being blocking is the exception,
 * and this is why JavaScript is based so much on callbacks, and more recently
 * on promises and async/await.
 *
 *
 * **The call stack**
 * The call stack is a LIFO queue (Last In, First Out).
 *
 * The event loop continuously checks the call stack to see if there's any
 * function that needs to run.
 *
 * While doing so, it adds any function call it finds to the call stack and
 * executes each one in order.
 *
 *
 * **Queuing function execution**
 * Let's see how to defer a function until the stack is clear.
 */

// The use case of `setTimeout(() => {}, 0)` is to call a function,
// but execute it once every other function in the code has executed.
const bar = () => console.log("bar");

const baz = () => console.log("baz");

const foo = () => {
  console.log("foo");
  setTimeout(bar, 0);
  baz();
};

foo(); // This code prints, maybe surprisingly: foo baz bar
// When this code runs, first foo() is called. Inside foo() we first call
// setTimeout, passing bar as an argument, and we instruct it to run immediately
// as fast as it can, passing 0 as the timer. Then we call baz().

// Why is this happening?

/**
 * **The Message Queue**
 * When setTimeout() is called, the Browser or Node.js start the timer. Once the
 * timer expires, in this case immediately as we put 0 as the timeout, the
 * callback function is put in the Message Queue.
 *
 * The Message Queue is also where user-initiated events like click or keyboard
 * events, or fetch responses are queued before your code has the opportunity to
 * react to them. Or also DOM events like `onLoad`.
 *
 * The loop gives priority to the call stack, and it first processes everything
 * it finds in the call stack, and once there's nothing in there, it goes to
 * pick up things in the message queue.
 */

/**
 * **ES6 Job Queue**
 * ECMAScript 2015 introduced the concept of the Job Queue, which is used by
 * Promises (also introduced in ES6/ES2015). It's a way to execute the result of
 * an async function as soon as possible, rather than being put at the end of
 * the call stack.
 *
 * Promises that resolve before the current function ends will be executed right
 * after the current function.
 */
const bar2 = () => console.log("bar2");

const baz2 = () => console.log("baz2");

const foo2 = () => {
  console.log("foo2");
  setTimeout(bar2, 0);
  new Promise((resolve, reject) => resolve("promise")).then(resolve =>
    console.log(resolve)
  );
  baz2();
};

foo2(); // This code prints: foo baz promise bar
// That's a big difference between Promises (and Async/await, which is built
// on promises) and plain old asynchronous functions through setTimeout() or
// other platform APIs.
