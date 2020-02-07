/**
 * Modern Asynchronous JavaScript with Async and Await
 *
 * JavaScript evolved in a very short time from callbacks to promises (ES2015),
 * and since ES2017 asynchronous JavaScript is even simpler with the
 * async/await syntax.
 *
 * Async functions are a combination of promises and generators, and basically,
 * they are a higher level abstraction over promises.
 *
 *
 * **Why were async/await introduced?**
 *
 * They reduce the boilerplate around promises, and the "don't break the chain"
 * limitation of chaining promises.
 *
 * Promises were introduced to solve the famous callback hell problem, but they
 * introduced complexity on their own, and syntax complexity.
 *
 * They were good primitives around which a better syntax could be exposed to
 * the developers, so when the time was right we got async functions.
 *
 * They make the code look like it's synchronous, but it's asynchronous and
 * non-blocking behind the scenes.
 *
 *
 * **How it works**
 */

// An async function returns a promise, like in this example:
const doSomethingAsync = () => {
  return new Promise(resolve => {
    setTimeout(() => resolve("I did something"), 3000);
  });
};

// When you want to call this function you prepend `await`, and the calling code
// will stop until the promise is resolved or rejected.
// One caveat: the client function must be defined as `async`.
// Here's an example:
const doSomething = async () => {
  console.log(await doSomethingAsync());
};

// Prints:
// Before
// After
// I did something
console.log("Before");
doSomething();
console.log("After");

/**
 * Promise all the things
 *
 * Prepending the `async` keyword to any function means that the function will
 * return a promise.
 *
 * Even if it's not doing so explicitly, it will internally make it return a
 * promise.
 */

// Multiple async functions in series
//
// Async functions can be chained very easily, and the syntax is much more
// readable than with plain promises:
const promiseToDoSomething = () => {
  return new Promise(resolve => {
    setTimeout(() => resolve("I did something"), 10000);
  });
};

const watchOverSomeoneDoingSomething = async () => {
  const something = await promiseToDoSomething();
  return something + "\nand I watched";
};

const watchOverSomeoneWatchingSomeoneDoingSomething = async () => {
  const something = await watchOverSomeoneDoingSomething();
  return something + "\nand I watched as well";
};

watchOverSomeoneWatchingSomeoneDoingSomething().then(res => {
  console.log(res);
});

/**
 * Easier debugging
 *
 * Debugging promises is hard because the debugger will not step over
 * asynchronous code.
 *
 * Async/await makes this very easy because to the compiler it's just
 * like synchronous code.
 */
