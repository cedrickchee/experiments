# PocketBase as Go Framework

This is an example of using PocketBase as a Go framework.

This enables you to build your own custom app specific business logic and still
have a single portable executable at the end.

Docs: https://pocketbase.io/docs/use-as-framework/

## Software Requirements

- Go: 1.18+ (for Windows, you may have to use go 1.19+ due to an incorrect JS mime type in the Windows Registry.)

## Setup

Installation

Add Go module requirements:

```sh
$ go mod tidy
go: finding module for package github.com/pocketbase/pocketbase
go: downloading github.com/pocketbase/pocketbase v0.12.1
go: found github.com/pocketbase/pocketbase in github.com/pocketbase/pocketbase v0.12.1
[... truncated ...]
go: downloading github.com/mattn/go-sqlite3 v1.14.16
go: downloading modernc.org/sqlite v1.20.3
[... truncated ...]
go: downloading modernc.org/z v1.7.0
```

## Running and Building

Running/building the application is the same as for any other Go program,
aka. just `go run main.go` and `go build`.

```sh
$ ./main serve # or ./pocketbase-as-framework serve
> Server started at: http://127.0.0.1:8090
  - REST API: http://127.0.0.1:8090/api/
  - Admin UI: http://127.0.0.1:8090/_/
```

## Testing

**Admin account**

```
Email: supradmin@foo.bar
Pass: supradmin@foo!123
```

## Extending PocketBase

PocketBase could be extended by:

- [Registering custom routes](https://pocketbase.io/docs/router), eg:

  ```go
  app.OnBeforeServe().Add(func(e *core.ServeEvent) error {
      e.Router.AddRoute(echo.Route{
          Method: http.MethodGet,
          Path:   "/api/hello",
          Handler: func(c echo.Context) error {
              return c.String(http.StatusOK, "Hello world!")
          },
          Middlewares: []echo.MiddlewareFunc{
              apis.ActivityLogger(app),
              apis.RequireAdminAuth(),
          },
      })

      return nil
  })
  ```

  Build and run the executable:

  ```sh
  $ go build
  $ ./pocketbase-as-framework serve
  ```

  Open `http://127.0.0.1:8090/hello` in your browser and you'll see the text
  "Hello world!".

- and much more... 

  You may also find useful checking the [repo source](https://github.com/pocketbase/pocketbase) and the [package documentation](https://pkg.go.dev/github.com/pocketbase/pocketbase).
