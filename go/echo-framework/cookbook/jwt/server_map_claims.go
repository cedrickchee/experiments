// An JSON Web Token (JWT) example
//
// Server using Map claims
//
// JWT authentication using HS256 algorithm.
// JWT is retrieved from `Authorization` request header.
//
// We will be using jwt-go library: https://github.com/dgrijalva/jwt-go
// a Go implementation of JWT that supports the parsing and verification as well
// the generation and signing of JWTs.

package main

import (
	"net/http"
	"time"

	"github.com/dgrijalva/jwt-go"
	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
)

func login(c echo.Context) error {
	username := c.FormValue("username")
	password := c.FormValue("password")

	// Throws unauthorized error
	if username != "david" || password != "shhhhhhh!!" {
		return echo.ErrUnauthorized
	}

	// Create token
	token := jwt.New(jwt.SigningMethodHS256)

	// Set claims
	claims := token.Claims.(jwt.MapClaims)
	claims["name"] = "David James"
	claims["admin"] = true
	claims["exp"] = time.Now().Add(time.Hour * 72).Unix()

	// Generate encoded token and send it as response.
	t, err := token.SignedString([]byte("secret"))
	if err != nil {
		return err
	}

	return c.JSON(http.StatusOK, map[string]string{
		"token": t,
	})
}

func accessible(c echo.Context) error {
	return c.String(http.StatusOK, "Accessible")
}

func restricted(c echo.Context) error {
	user := c.Get("user").(*jwt.Token)
	claims := user.Claims.(jwt.MapClaims)
	name := claims["name"].(string)
	return c.String(http.StatusOK, "Welcome "+name+"!")
}

func main() {
	// Server using Map claims
	e := echo.New()

	// Middleware
	e.Use(middleware.Logger())
	e.Use(middleware.Recover())

	// Login route
	e.POST("/login", login)

	// Unauthenticated route
	e.GET("/", accessible)

	// Restricted group
	r := e.Group("/restricted")
	// JWT auth middleware
	// For valid token, it sets the user in context and calls next handler.
	// For invalid token, it sends "401 - Unauthorized" response.
	// For missing or invalid Authorization header, it sends "400 - Bad Request".
	r.Use(middleware.JWT([]byte("secret")))
	r.GET("", restricted)

	e.Logger.Fatal(e.Start(":3000"))

	// Testing
	// Use cURL. Commands:
	// - Login
	// `curl -X POST -d 'username=david' -d 'password=shhhhhhh!!' localhost:3000/login`
	// Response: {"token":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhZG1pbiI6dHJ1ZSwiZXhwIjoxNTgyNjQxNjM3LCJuYW1lIjoiRGF2aWQgSmFtZXMifQ.s6GijdEk4V1dGABwgF4nGonj8LqvYZ493SG4l9RgU78"}
	//
	// - Request
	// `curl localhost:3000/restricted -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhZG1pbiI6dHJ1ZSwiZXhwIjoxNTgyNjQxNjM3LCJuYW1lIjoiRGF2aWQgSmFtZXMifQ.s6GijdEk4V1dGABwgF4nGonj8LqvYZ493SG4l9RgU78"`
	// Response: Welcome David James!
}
