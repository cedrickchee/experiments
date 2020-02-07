/**
 * Output to the command line using Node.js
 */

// Color the output
//
// You can color the output of your text in the console by using escape
// sequences. An escape sequence is a set of characters that identifies a color.
// More about escape sequences and bash ANSI color codes:
// https://gist.github.com/iamnewton/8754917
console.log("\x1b[33m%s\x1b[0m", "hello");
// You can try that in the Node.js REPL, and it will print hello! in yellow.

// Tip: you can also do that with chalk package.
// Using chalk.yellow is much more convenient than trying to remember the escape
// codes, and the code is much more readable.
