/**
 * Making HTTP requests with Node.js
 */

// Perform a GET Request
// to: https://httpbin.org/#/Anything/get_anything
const https = require("https");
const options = {
  hostname: "httpbin.org",
  port: 443,
  path: "/anything",
  method: "GET"
};

const req = https.request(options, res => {
  console.log(`statusCode: ${res.statusCode}`);

  res.on("data", d => {
    process.stdout.write(d);
  });
});

req.on("error", err => {
  console.log(err);
});

req.end();

// Perform a POST Request
const data = JSON.stringify({
  todo: "Buy the milk"
});

const options2 = {
  hostname: "httpbin.org",
  port: 443,
  path: "/anything",
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    "Content-Length": data.length
  }
};

const req2 = https.request(options2, res => {
  console.log(`statusCode: ${res.statusCode}`);

  res.on("data", d => {
    process.stdout.write(d);
  });
});

req2.on("error", err => {
  console.error(err);
});

req2.write(data);
req2.end();
