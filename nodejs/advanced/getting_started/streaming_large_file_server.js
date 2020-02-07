/**
 * Streaming for servers
 */
const path = require("path");
const fileName = path.join(__dirname, process.argv[2] || "nasa_log.tsv"); // 149 MB
const fs = require("fs");
const server = require("http").createServer();

server.on("request", (req, res) => {
  if (req.url === "/normal") {
    // Node process using 147 MB memory
    fs.readFile(fileName, (err, data) => {
      if (err) return console.error(err);
      res.end(data);
    });
  } else if (req.url === "/stream") {
    // Node process using 19 MB memory
    const src = fs.createReadStream(fileName);
    src.pipe(res);
  }
});

server.listen(3000);
