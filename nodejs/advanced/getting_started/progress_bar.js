/**
 * Output to the command line using Node.js
 */

// Create a progress bar
//
// Progress is an awesome package to create a progress bar in the console.
//
// This snippet creates a 10-step progress bar, and every 100ms one step is
// completed. When the bar completes we clear the interval:
const ProgressBar = require("progress");

const bar = new ProgressBar(":bar", { total: 10 });
const timer = setInterval(() => {
  bar.tick();

  if (bar.complete) {
    clearInterval(timer);
  }
}, 100);
