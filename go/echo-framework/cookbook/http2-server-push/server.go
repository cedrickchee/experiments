// An example of HTTP/2 server push
//
// Note: requires go 1.8+
// How to send web assets using HTTP/2 server push?
// Step 1: Generate a self-signed X.509 TLS certificate

package main

import (
	"net/http"

	"github.com/labstack/echo/v4"
)

func main() {
	e := echo.New()

	// Step 2: Register a route to serve web assets
	e.Static("/", "public/assets")

	// Step 3: Create a handler to serve `index.html` and push it’s dependencies
	e.GET("/", func(c echo.Context) (err error) {
		// If `http.Pusher` is supported, web assets are pushed; otherwise,
		// client makes separate requests to get them.
		pusher, ok := c.Response().Writer.(http.Pusher)
		if ok {
			if err = pusher.Push("/app.css", nil); err != nil {
				return
			}
			if err = pusher.Push("/app.js", nil); err != nil {
				return
			}
			if err = pusher.Push("/echo.png", nil); err != nil {
				return
			}
		}
		return c.File("public/index.html")
	})

	// Step 4: Configure TLS server using `cert.pem` and `key.pem`
	e.Logger.Fatal(e.StartTLS(":3000", "cert.pem", "key.pem"))

	// Step 5: Start the server and browse to https://localhost:3000
}
