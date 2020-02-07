/**
 * HTTP/2 Server Push
 */

// Setup note: generate self-signed SSL cert first
// Run command in your terminal:
// `openssl req -x509 -newkey rsa:2048 -nodes -sha256 -subj '/C=US/ST=CA/L=SF/O=NO\x08A/OU=NA' -keyout server.key -out server.crt`

const http2 = require("http2");
const fs = require("fs");

const server = http2.createSecureServer({
  key: fs.readFileSync("server.key"),
  cert: fs.readFileSync("server.crt")
});

server.on("error", err => console.error(err));
server.on("socketError", err => console.error(err));

server.on("stream", (stream, headers) => {
  stream.respond({
    "content-type": "text/html",
    ":status": 200
  });

  stream.pushStream({ ":path": "/bundle.js" }, (err, pushStream) => {
    if (err === null) {
      pushStream.respond({
        "content-type": "text/javascript",
        ":status": 200
      });

      pushStream.end(`alert('you win')`);
    } else {
      console.error("Error:", err);
    }
  });

  stream.end(
    '<script src="/bundle.js"></script><h3>Demo HTTP/2 server push</h3>'
  );
});

server.listen(3000);
