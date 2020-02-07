/**
 * How to exit from a Node.js program
 *
 * The `process` core module provides a handy method that allows you
 * to programmatically exit from a Node.js program: `process.exit()`.
 *
 * When Node.js runs this line, the process is immediately forced to terminate.
 *
 * This means that any callback that's pending, any network request still
 * being sent, any filesystem access, or processes writing to `stdout` or
 * `stderr` - all is going to be ungracefully terminated right away.
 *
 * If you call `process.exit()`, any currently pending or running request is
 * going to be aborted. This is not nice.
 *
 * In this case you need to send the command a SIGTERM signal, and handle that
 * with the process signal handler:
 */

const express = require("express");

const app = express();

app.get("/", (req, res) => {
  res.send("Hey!");
});

const server = app.listen(3000, () => console.log("Server ready"));

// Gracefully terminate process.
//
// SIGTERM is the signal that tells a process to gracefully terminate.
// It is the signal that's sent from process managers like upstart or
// supervisord and many others.
process.on("SIGTERM", () => {
  server.close(() => {
    console.log("Process terminated");
  });
});

// You can send this signal from inside the program, in another function:
// process.kill(process.pid, 'SIGTERM');

// Or from another Node.js running program, or any other app running in your
// system that knows the PID of the process you want to terminate.
//
// Go to your terminal and run `kill -15 [pid]`. pid is the node.js process ID.
// You can get the process ID using `ps a | grep -i node`.
