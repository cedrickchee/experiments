# REST API

Web services built in Go and [Echo](https://github.com/labstack/echo) web framework.

## Development

We're using [Reflex](https://github.com/cespare/reflex) to auto-reload application when the code changes.

```sh
# Build and run a server; rebuild and restart when .go files change:
$ reflex -r '\.go$' -s -- sh -c 'go run server.go'
```
