import { Database } from "bun:sqlite";

const db = new Database("mydb.sqlite");
db.run(
  "CREATE TABLE IF NOT EXISTS foo (id INTEGER PRIMARY KEY AUTOINCREMENT, greeting TEXT)"
);
db.run("INSERT INTO foo (greeting) VALUES (?)", "Welcome to bun!");
db.run("INSERT INTO foo (greeting) VALUES (?)", "Hello World!");

// get the first row
const getRow = db.query("SELECT * FROM foo").get();
console.log("getRow:", getRow);
// { id: 1, greeting: "Welcome to bun!" }

// get all rows
db.query("SELECT * FROM foo").all();
// [
//   { id: 1, greeting: "Welcome to bun!" },
//   { id: 2, greeting: "Hello World!" },
// ]

// get all rows matching a condition
db.query("SELECT * FROM foo WHERE greeting = ?").all("Welcome to bun!");
// [
//   { id: 1, greeting: "Welcome to bun!" },
// ]

// get first row matching a named condition
db.query("SELECT * FROM foo WHERE greeting = $greeting").get({
  $greeting: "Welcome to bun!",
});
// [
//   { id: 1, greeting: "Welcome to bun!" },
// ]
