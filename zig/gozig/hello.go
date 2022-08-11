package main

import "fmt"
import "C"

func main() {
}

// Here we need the comment decoration to export our HelloGopher symbol for Zig
// to use.

//export HelloGopher
func HelloGopher() {
	fmt.Println("Hello Gopher")
}
