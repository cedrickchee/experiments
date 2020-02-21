package main

import (
	"net/http"

	rice "github.com/GeertJohan/go.rice"
	"github.com/labstack/echo/v4"
)

func main() {
	e := echo.New()

	// the file server for rice. "http-files" is the folder where the files come from.
	assetHandler := http.FileServer(rice.MustFindBox("http-files").HTTPBox())

	// serves the index.html from rice
	e.GET("/", echo.WrapHandler(assetHandler))

	// servers other static files
	e.GET("/static/*", echo.WrapHandler(http.StripPrefix("/static/", assetHandler)))

	e.Logger.Fatal(e.Start(":3000"))
}
