// An example of linking Go program with C/C++ program
// so that Go code can call C/C++ code
// Reference: https://blog.golang.org/c-go-cgo
package main

// #include <stdio.h>
// #include <stdlib.h>
import "C"
import (
	"fmt"
	"unsafe"
)

func Random() int {
	return int(C.random())
}

func Seed(i int) {
	C.srandom(C.uint(i))
}

func Print(s string) {
	cs := C.CString(s)
	C.fputs(cs, (*C.FILE)(C.stdout))
	C.free(unsafe.Pointer(cs))
}

func main() {
	Seed(42)
	randNum := Random()
	fmt.Println("random number gen:", randNum)

	Print("Hello, world")
}
