/**
 * Node.js, accept arguments from the command line
 */

// You can iterate over all the arguments (including the node path and the file
// path) using a loop:
process.argv.forEach((val, index) => {
  console.log(`${index}: ${val}`);
});

// You can get only the additional arguments by creating a new array that
// excludes the first 2 params:
const args = process.argv.slice(2);
// Command line: `node accept_args_cmdline.js greet=hello`
args.forEach((val, index) => {
  console.log(`${index}: ${val}`); // prints 0: greet=hello
});

// Parse arguments
// The way to do so is by using the minimist library, which helps dealing
// with arguments:
const parsedArgs = require("minimist")(args);
// Command line: `node accept_args_cmdline.js --greet=hello`
console.log(parsedArgs["greet"]); // prints hello
