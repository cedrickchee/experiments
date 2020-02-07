/**
 * How to read environment variables from Node.js
 *
 * The `process` core module of Node.js provides the `env` property which hosts all
 * the environment variables that were set at the moment the process was
 * started.
 */

// Here is an example that accesses the `NODE_ENV` environment variable,
// which is set to `development` by default.
//
// Setting it to "production" before the script runs will tell Node.js that this
// is a production environment.
// Command: `NODE_ENV=production node read_env_vars.js`
//
// In the same way you can access any custom environment variable you set.
console.log("Node environment:", process.env.NODE_ENV);
