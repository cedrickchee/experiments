# PocketBase as Backend

PocketBase is an open source backend.

Docs: https://pocketbase.io/docs/

This project is using the prebuilt PocketBase executable as a web backend.

PocketBase version: 0.12.1

## Run

You could start the application by running the following console command in this
directory: `./pocketbase serve`

And that's it! A web server will be started with the following routes:

- http://127.0.0.1:8090 - if `pb_public` directory exists, serves the static content from it (html, css, images, etc.)
- http://127.0.0.1:8090/_/ - Admin dashboard UI
- http://127.0.0.1:8090/api/ - REST API

The prebuilt PocketBase executable will automatically create and manage 2 new
directories alongside the executable:

- `pb_data` - stores your application data, uploaded files, etc. (usually should be added in `.gitignore`).
- `pb_migrations` - contains JS migration files with your collection changes (can be safely commited in your repository). You can even write custom migration scripts.

You could find all available commands and their options by running `./pocketbase --help` or `./pocketbase [command] --help`.

## Testing

You can test PocketBase JavaScript SDK either in:
- Browser: http://127.0.0.1:8090
- Node.js: `cd` into the `web` directory and run:

```sh
$ npm i
$ node bookjmarks/list.js`
```
