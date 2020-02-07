/**
 * Error handling in Node.js
 *
 * Errors in Node.js are handled through exceptions.
 *
 * An exception is created using the throw keyword:
 * `throw value`
 *
 * As soon as JavaScript executes this line, the normal program flow is halted
 * and the control is held back to the nearest exception handler.
 *
 * Usually in client-side code value can be any JavaScript value including a
 * string, a number or an object.
 *
 * In Node.js, we don't throw strings, we just throw Error objects.
 *
 *
 * **Error objects**
 * An error object is an object that is either an instance of the Error object, or extends the Error class, provided in the Error core module:
 * `throw new Error('Ran out of coffee');`
 *
 *
 * **Handling exceptions**
 * An exception handler is a try/catch statement.
 *
 *
 * **Catching uncaught exceptions**
 * If an uncaught exception gets thrown during the execution of your program,
 * your program will crash.
 *
 * To solve this, you listen for the uncaughtException event
 * on the process object:
 */
process.on("uncaughtException", err => {
  console.log("There was an uncaught error", err);
  process.exit(1); // mandatory (as per the Node.js docs)
});
