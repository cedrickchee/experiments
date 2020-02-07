/**
 * The Node.js os module
 *
 * This module provides many functions that you can use to retrieve information
 * from the underlying operating system and the computer the program runs on,
 * and interact with it.
 *
 * There are a few useful properties that tell us some key things related to
 * handling files:
 * - `os.EOL` gives the line delimiter sequence. It's `\n` on Linux and macOS,
 * and `\r\n` on Windows.
 * - `os.constants.signals` tells us all the constants related to handling
 * process signals, like SIGHUP, SIGKILL and so on.
 * - `os.constants.errno` sets the constants for error reporting, like
 * EADDRINUSE, EOVERFLOW and more.
 *
 * Let's now see the main methods that os provides:
 */
const os = require("os");

// Return the string that identifies the underlying architecture, like arm, x64,
// arm64.
console.log("os.arch():", os.arch());

// Return information on the CPUs available on your system.
console.log("os.cpus():", os.cpus());

// Return BE or LE depending if Node.js was compiled with Big Endian
// or Little Endian.
console.log("os.endianness():", os.endianness());

// Return the number of bytes that represent the free memory in the system.
console.log("os.freemem():", os.freemem());

// Return the path to the home directory of the current user.
console.log("os.homedir():", os.homedir());

// Return the hostname.
console.log("os.hostname():", os.hostname());

// Return the calculation made by the operating system on the load average.
console.log("os.loadavg():", os.loadavg());

// Returns the details of the network interfaces available on your system.
console.log("os.networkInterfaces():", os.networkInterfaces());

// Return the platform that Node.js was compiled for.
console.log("os.platform():", os.platform());

// Returns a string that identifies the operating system release number.
console.log("os.release():", os.release());

// Returns the path to the assigned temp folder.
console.log("os.tmpdir():", os.tmpdir());

// Returns the number of bytes that represent the total memory available
// in the system.
console.log("os.totalmem():", os.totalmem());

// Identifies the operating system
console.log("os.type():", os.type());

// Returns the number of seconds the computer has been running since it was
// last rebooted.
console.log("os.uptime():", os.uptime());

// Returns user info.
console.log("os.userInfo():", os.userInfo());
