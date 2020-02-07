/**
 * Output to the command line using Node.js
 */

// Print the stack trace
//
// There might be cases where it's useful to print the call stack trace of a
// function, maybe to answer the question "how did you reach that part of
// the code?".
const func2 = () => console.trace();
const func1 = () => func2();
func1(); // this will print the stack trace.
