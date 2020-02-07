/**
 * Debugging server with memory leak
 *
 * **V8 Memory Scheme**
 * Resident Set:
 * - Code: Node/JS code
 * - Stack: Primitives, local variables, pointers to objects in the heap and
 * control flow
 * - Heap: Referenced types such as Objects, strings, closures
 *
 *
 * **Garbage Collection (GC)**
 *
 * The mechanism that allocates and frees heap memory is called
 * garbage collection.
 *
 * - Automatic in Node, thanks to V8
 * - Stops the world - expensive
 * - Objects with refs are not collected (memory leaks)
 */

// Example of leaky server
const express = require("express");

const app = express();

let ewallet = {};
const generateAddress = () => {
  const initialCryptoWallet = ewallet;
  const tempEwallet = () => {
    if (initialCryptoWallet) console.log("We received initial ewallet");
  };
  ewallet = {
    key: new Array(1e7).join("."),
    address: () => {
      // ref to tempEwallet ???
      console.log("address returned");
    }
  };
};

app.get("*", (req, res) => {
  generateAddress();
  console.log("Memory usage:", process.memoryUsage());
  return res.json({ msg: "ok" });
});

app.listen(3000);

// Starting the leak
//
// Run these commands in your terminal:
// `loadtest -c 100 --rps 100 http://localhost:3000`
//
// Terminal output:
// { rss: 1395490816,
//   heapTotal: 1469087744,
//   heapUsed: 1448368200,
//   external: 16416 }
// { rss: 1405501440,
//   heapTotal: 1479098368,
//   heapUsed: 1458377224,
//   external: 16416 }
// { rss: 1335377920,
//   heapTotal: 1409097728,
//   heapUsed: 1388386720,
//   external: 16416 }
//
// GCs
//
// <--- Last few GCs --->
//
// [35417:0x103000c00]    36302 ms: Mark-sweep 1324.1 (1345.3) -> 1324.1 (1345.3) MB, 22.8 / 0.0 ms  allocation failure GC in old space requested
// [35417:0x103000c00]    36328 ms: Mark-sweep 1324.1 (1345.3) -> 1324.1 (1330.3) MB, 26.4 / 0.0 ms  last resort GC in old space requested
// [35417:0x103000c00]    36349 ms: Mark-sweep 1324.1 (1330.3) -> 1324.1 (1330.3) MB, 20.9 / 0.0 ms  last resort GC in old space requested
//
// Line 12:
// ==== JS stack trace =========================================

// Security context: 0x3c69fae25ee1 <JSObject>
//     2: generateAddress [/Users/azat/Documents/Code/node-advanced/code/leaky-server/server.js:12] [bytecode=0x3c69df959db9 offset=42](this=0x3c69a7f0c0b9 <JSGlobal Object>)
//     4: /* anonymous */ [/Users/azat/Documents/Code/node-advanced/code/leaky-server/server.js:20] [bytecode=0x3c69df959991 offset=7](this=0x3c69a7f0c0b9 <JSGlobal Object>,req=0x3c69389c07c1 <IncomingMessage map = 0x3c693e7300f1...
//
//
//     FATAL ERROR: CALL_AND_RETRY_LAST Allocation failed - JavaScript heap out of memory

/**
 * **Memory Leak Mitigation**
 * - Reproduce the error/leak
 * - Check for variables and function arguments, pure functions are better
 * - Take heap dumps and compare (with debug and DevTools or heapdump modules)
 * - Update Node.js
 * - Get rid of extra npm modules
 * - Trial and error: remove code you think is leaky
 * - Modularize and refactor
 */

// Example of heap dumping
//
// const heapdump = require('heapdump');
// setInterval(function () {
//   heapdump.writeSnapshot();
// }, 2 * 1000);
// Creates files in the current folder:
// heapdump-205347232.998971.heapsnapshot
// heapdump-...
