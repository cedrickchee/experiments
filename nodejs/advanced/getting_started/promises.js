/**
 * Understanding JavaScript Promises
 *
 * A promise is commonly defined as a proxy for a value that will eventually
 * become available.
 *
 * Promises have been part of the language for years (standardized and
 * introduced in ES2015), and have recently become more integrated, with
 * async and await in ES2017.
 *
 * Async functions use promises behind the scenes, so understanding how promises
 * work is fundamental to understanding how async and await work.
 *
 *
 * **How promises work, in brief**
 * Once a promise has been called, it will start in a pending state.
 * This means that the calling function continues executing, while the promise
 * is pending until it resolves, giving the calling function whatever data was
 * being requested.
 *
 * The created promise will eventually end in a resolved state, or in a
 * rejected state, calling the respective callback functions (passed to then
 * and catch) upon finishing.
 */

// Creating a promise
// The Promise API exposes a Promise constructor, which you initialize using
// `new Promise()`:
let done = true;

const isItDoneYet = new Promise((resolve, reject) => {
  if (done) {
    const workDone = "Here is the thing I built";
    resolve(workDone);
  } else {
    const why = "Still working on something else";
    reject(why);
  }
});

/**
 * Using resolve and reject, we can communicate back to the caller what the
 * resulting promise state was, and what to do with it. In the above case we
 * just returned a string, but it could be an object, or null as well.
 * Because we've created the promise in the above snippet, it has already
 * started executing.
 *
 * A more common example you may come across is a technique called Promisifying.
 * This technique is a way to be able to use a classic JavaScript function that
 * takes a callback, and have it return a promise:
 */
const fs = require("fs");

const getFile = fileName => {
  return new Promise((resolve, reject) => {
    fs.readFile(fileName, (err, data) => {
      if (err) {
        // calling `reject` will cause the promise to fail with or without the
        // error passed as an argument.
        reject(err); // and we don't want to go any further
        return;
      }
      resolve(data);
    });
  });
};

getFile("./sample_data.txt")
  .then(data => console.log(data))
  .catch(err => console.log(err));

/**
 * Consuming a promise
 *
 * Now let's see how the promise can be consumed or used.
 */
const checkIfItsDone = () => {
  isItDoneYet
    .then(ok => {
      console.log(ok);
    })
    .catch(err => {
      console.log(err);
    });
};

// Running checkIfItsDone() will specify functions to execute when the
// `isItDoneYet` promise resolves (in the `then` call) or
// rejects (in the `catch` call).
checkIfItsDone();

/**
 * Chaining promises
 *
 * A promise can be returned to another promise, creating a chain of promises.
 */
const status = response => {
  if (response.status >= 200 && response.status < 300) {
    return Promise.resolve(response);
  }
  return Promise.reject(new Error(response.statusText));
};

const json = response => response.json();

fetch("/todos.json")
  .then(status) // note that the `status` function is actually **called** here, and that it **returns a promise***
  .then(json) // likewise, the only difference here is that the `json` function here returns a promise that resolves with `data`
  .then(data => {
    // ... which is why `data` shows up here as the first parameter to the anonymous function
    console.log("Request succeeded with JSON response", data);
  })
  .catch(error => {
    console.log("Request failed", error);
  });

/**
 * Orchestrating promises
 */

/*
 * Promise.all()
 *
 * If you need to synchronize different promises, Promise.all() helps you
 * define a list of promises, and execute something when they are all resolved.
 */
const f1 = fetch("/something.json");
const f2 = fetch("/something2.json");

Promise.all([f1, f2])
  .then(res => {
    console.log("Array of results", res);
  })
  .catch(err => {
    console.error(err);
  });

/**
 * Promise.race()
 *
 * Promise.race() runs when the first of the promises you pass to it resolves,
 * and it runs the attached callback just once, with the result of the first
 * promise resolved.
 */
const first = new Promise((resolve, reject) => {
  setTimeout(resolve, 500, "first");
});
const second = new Promise((resolve, reject) => {
  setTimeout(resolve, 100, "second");
});

Promise.race([first, second]).then(result => {
  console.log(result); // second
});

/**
 * Common errors
 *
 * Uncaught TypeError: undefined is not a promise
 * If you get the Uncaught TypeError: undefined is not a promise error in the
 * console, make sure you use new Promise() instead of just Promise()
 *
 * UnhandledPromiseRejectionWarning
 * This means that a promise you called rejected, but there was no catch used
 * to handle the error. Add a catch after the offending then to
 * handle this properly.
 */
