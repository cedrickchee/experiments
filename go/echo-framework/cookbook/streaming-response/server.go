// A streaming response example
//
// Send data as it is produced.
// Streaming JSON response with chunked transfer encoding

package main

import (
	"encoding/json"
	"net/http"
	"time"

	"github.com/labstack/echo/v4"
)

type Geolocation struct {
	Altitude  float64
	Latitude  float64
	Longitude float64
}

var locations = []Geolocation{
	{-97, 37.819929, -122.478255},
	{1899, 39.096849, -120.032351},
	{2619, 37.865101, -119.538329},
	{42, 33.812092, -117.918974},
	{15, 37.77493, -122.419416},
}

func main() {
	e := echo.New()

	e.GET("/", func(c echo.Context) error {
		c.Response().Header().Set(echo.HeaderContentType, echo.MIMEApplicationJSON)
		c.Response().WriteHeader(http.StatusOK)

		enc := json.NewEncoder(c.Response())
		for _, l := range locations {
			if err := enc.Encode(l); err != nil {
				return err
			}
			c.Response().Flush()
			time.Sleep(1 * time.Second)
		}
		return nil
	})

	e.Logger.Fatal(e.Start(":3000"))

	// Testing
	// Client: `curl localhost:3000`
	// Response:
	// {"Altitude":-97,"Latitude":37.819929,"Longitude":-122.478255}
	// {"Altitude":1899,"Latitude":39.096849,"Longitude":-120.032351}
	// {"Altitude":2619,"Latitude":37.865101,"Longitude":-119.538329}
	// {"Altitude":42,"Latitude":33.812092,"Longitude":-117.918974}
	// {"Altitude":15,"Latitude":37.77493,"Longitude":-122.419416}
}
