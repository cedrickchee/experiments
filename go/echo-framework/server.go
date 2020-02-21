package main

import (
	"io"
	"net/http"
	"os"

	"github.com/labstack/echo/v4"
	"github.com/labstack/echo/v4/middleware"
)

func main() {
	// Echo instance
	e := echo.New()

	// Root level middleware
	e.Use(middleware.Logger())
	e.Use(middleware.Recover())

	// Group level middleware
	g := e.Group("/admin")
	g.Use(middleware.BasicAuth(userAuth))

	// Route level middleware
	track := func(next echo.HandlerFunc) echo.HandlerFunc {
		return func(c echo.Context) error {
			println("request to /users")
			return next(c)
		}
	}

	// Routes
	e.GET("/", hello)
	e.GET("/users/:id", getUser)
	e.GET("/users", listUser, track)
	e.GET("/show", show)
	e.POST("/save", save)
	e.POST("/users/save", saveUser)
	e.POST("/books", saveBook)
	// Serve any file from static directory for path /assets/*
	// i.e.: GET http://localhost:3000/static/balloon1.jpg
	e.Static("/static", "assets")

	// Start server
	e.Logger.Fatal(e.Start(":3000"))
}

func hello(c echo.Context) error {
	return c.String(http.StatusOK, "Hello, World")
}

func getUser(c echo.Context) error {
	// User ID from path `users/:id`
	id := c.Param("id")
	return c.String(http.StatusOK, id)
}

func show(c echo.Context) error {
	// Get team and member from the query string
	team := c.QueryParam("team")
	member := c.QueryParam("member")
	return c.String(http.StatusOK, "team:"+team+", member:"+member)
}

func save(c echo.Context) error {
	// Get name and email
	name := c.FormValue("name")
	email := c.FormValue("email")
	return c.String(http.StatusOK, "name:"+name+", email:"+email)
}

func saveUser(c echo.Context) error {
	// Terminal:
	// `curl -F "name=John Doe" -F "avatar=@/home/cedric/Downloads/my_avatar.jpg" http://localhost:3000/users/save`

	// Get name
	name := c.FormValue("name")

	// Get avatar
	avatar, err := c.FormFile("avatar")
	if err != nil {
		return err
	}

	// Source
	src, err := avatar.Open()
	if err != nil {
		return err
	}
	defer src.Close()

	// Destination
	dst, err := os.Create(avatar.Filename)
	if err != nil {
		return err
	}
	defer dst.Close()

	// Copy
	if _, err := io.Copy(dst, src); err != nil {
		return err
	}

	return c.HTML(http.StatusOK, "<strong>Thank you!"+name+"</strong>")
}

type Book struct {
	Title  string `json:"title" xml:"title" form:"title" query:"title"`
	Author string `json:"author" xml:"author" form:"author" query:"author"`
}

func saveBook(c echo.Context) error {
	// Handling Request
	// Bind json, xml, form or query payload into Go struct based on
	// `Content-Type` request header.
	//
	// Test in terminal:
	// POST JSON data: `curl -H "Content-Type: application/json" -d '{"author":"Martin Fowler", "title":"Refactoring"}' -X POST http://localhost:3000/books`
	// POST url encoded data: `curl -H "Content-Type: application/x-www-form-urlencoded" -d "author=Martin Fowler&year=2008&title=Refactoring" -X POST http://localhost:3000/books`
	u := new(Book)
	if err := c.Bind(u); err != nil {
		return err
	}
	// Render response as json with status code.
	return c.JSON(http.StatusCreated, u)
	// or
	// c.XML(http.StatusCreated, u)
}

func userAuth(username, password string, c echo.Context) (bool, error) {
	if username == "john" && password == "s3creT" {
		return true, nil
	}
	return false, nil
}

func listUser(c echo.Context) error {
	return c.String(http.StatusOK, "/users")
}
