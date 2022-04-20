package main

import (
	"fmt"
	"syscall/js"
)

func main() {
	fmt.Println("Ohai, WebAssembly, wasm!")
	js.Global().Call("updateDOM", "Hello from Go")
}
