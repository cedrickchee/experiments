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

	// Retrieve a value from JS main thread.
	href := js.Global().Get("location").Get("href")
	fmt.Println(href)

	// Set up a recurring timer event to call updateTime() every 500 ms.

	// Create JS callback connected to updateTime()
	timerCallback := js.FuncOf(updateTime)
	// Set timer to call timerCallback() every 500 ms.
	js.Global().Call("setInterval", timerCallback, "500")

	// An empty select blocks, so the main() function will never exit.
	// This allows the event handler callbacks to continue operating.
	select {}
}

// Callback for the interval timer.
// Get the current time and update it in the DOM.
func updateTime(this js.Value, args []js.Value) interface{} {
	// fmt.Println("Hello ", val[0])

	// Get the current date in this locale
	date := js.Global().Get("Date").New()
	s := date.Call("toLocaleTimeString").String()

	// Update the text in <div id="clock">
	js.Global().Get("document").Call("getElementById", "clock").Set("textContent", s)
	return nil
}
