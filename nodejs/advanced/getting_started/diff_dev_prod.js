/**
 * Node.js, the difference between development and production
 *
 * You can have different configurations for production and development
 * environments.
 *
 * Node.js assumes it's always running in a development environment.
 * You can signal Node.js that you are running in production by
 * setting the `NODE_ENV=production` environment variable.
 *
 * This is usually done by executing the command
 * `export NODE_ENV=production`
 * in the shell, but it's better to put it in your shell configuration
 * file (e.g. `.bash_profile` with the Bash shell) because otherwise the setting
 * does not persist in case of a system restart.
 *
 * You can also apply the environment variable by prepending it to your
 * application initialization command:
 * `NODE_ENV=production node app.js`
 *
 * This environment variable is a convention that is widely used in external
 * libraries as well.
 *
 * Setting the environment to production generally ensures that
 * - logging is kept to a minimum, essential level
 * - more caching levels take place to optimize performance
 *
 * For example Express, views are compiled in every request in development mode,
 * while in production they are cached.
 */
const express = require("express");
const app = express();

const ENV = process.env.NODE_ENV;

if (ENV === "development") {
  console.log("Environment: %s", ENV);
  // app.use(express.errorHandler({ dumpExceptions: true, showStack: true }));
} else if (ENV === "production") {
  console.log("Environment: %s", ENV);
  // app.use(express.errorHandler());
}
