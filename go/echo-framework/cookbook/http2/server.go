// An HTTP/2 recipe
//
// How to run an HTTP/2 server?
// Step 1: Generate a self-signed X.509 TLS certificate
// Run the following command to generate `cert.pem` and `key.pem` files:
// `$ go run $GOROOT/src/crypto/tls/generate_cert.go --host localhost`
// Output:
// 2020/02/22 20:43:05 wrote cert.pem
// 2020/02/22 20:43:05 wrote key.pem
// > For demo purpose, we are using a self-signed certificate. Ideally, you
// should obtain a certificate from Certificate Authority.

package main

import (
	"fmt"
	"net/http"

	"github.com/labstack/echo/v4"
)

func main() {
	e := echo.New()

	// Step 2: Create a handler which simply outputs the request information to
	// the client
	e.GET("/request", func(c echo.Context) error {
		req := c.Request()
		format := `
			<code>
				Protocol: %s<br />
				Host: %s<br />
				Remote Address: %s<br />
				Method: %s<br />
				Path: %s<br />
			</code>
		`
		return c.HTML(http.StatusOK, fmt.Sprintf(format, req.Proto, req.Host, req.RemoteAddr, req.Method, req.URL.Path))
	})

	// Step 3: Configure TLS server using `cert.pem` and `key.pem`
	e.Logger.Fatal(e.StartTLS(":3000", "cert.pem", "key.pem"))

	// Step 4: Start the server and browse to https://localhost:3000/request to
	// see the following output:
	//
	// Protocol: HTTP/2.0
	// Host: localhost:3000
	// Remote Address: [::1]:47710
	// Method: GET
	// Path: /request
}
