// An example of graceful shutdown of Go http.Handler servers
//
// A side note: if you are using Go 1.8+, you may not need to use external
// library. Consider using
// http.Server's built-in [Shutdown()](https://golang.org/pkg/net/http/#Server.Shutdown)
// method for graceful shutdowns.

package main

import (
	"context"
	"net/http"
	"os"
	"os/signal"
	"time"

	"github.com/labstack/echo/v4"
	"github.com/labstack/gommon/log"
)

func main() {
	// Setup
	e := echo.New()
	e.Logger.SetLevel(log.INFO)
	e.GET("/", func(c echo.Context) error {
		time.Sleep(5 * time.Second)
		return c.JSON(http.StatusOK, "OK")
	})

	// Start server
	go func() {
		if err := e.Start(":3000"); err != nil {
			e.Logger.Info("shutting down the server")
		}
	}()

	// Wait for interrupt signal to gracefully shutdown the server with a
	// timeout of 10 seconds.
	quit := make(chan os.Signal)
	signal.Notify(quit, os.Interrupt)
	<-quit
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// echo.Shutdown stops the server gracefully.
	// It internally calls `http.Server#Shutdown()`.
	if err := e.Shutdown(ctx); err != nil {
		e.Logger.Fatal(err)
	}
}
