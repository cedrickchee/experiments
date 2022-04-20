package main

import (
	"encoding/json"
	"fmt"
	"syscall/js"
)

type Person struct {
	Name string `json:"name"`
	Age  int    `json:"age"`
}

func main() {
	fmt.Println("Ohai, WebAssembly, wasm!")

	js.Global().Set("aBoolean", true)
	js.Global().Set("aString", "Hello world")
	js.Global().Set("aNumber", 42)

	// A simple workaround to marshal a struct into JSON by leveraging
	// JavaScript's `JSON.parse`.
	alice := &Person{Name: "Alice", Age: 19}
	p, err := json.Marshal(alice)
	if err != nil {
		fmt.Println(err)
		return
	}
	obj := js.Global().Get("JSON").Call("parse", string(p))
	js.Global().Set("aObject", obj)

	js.Global().Call("updateDOM", "Hello from Go")
	js.Global().Call("showValues")
}
