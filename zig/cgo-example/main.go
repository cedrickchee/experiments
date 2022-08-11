package main

// #cgo CFLAGS: -g -Wall
// #include <stdlib.h>			// for malloc and free
// #include "greeter.h"
import "C"
import (
	"fmt"
	"unsafe"
)

func main() {
	name := C.CString("Gemini")
	defer C.free(unsafe.Pointer(name))

	year := C.int(2019)

	g := C.struct_Greetee{
		name: name,
		year: year,
	}

	// The function C.malloc returns an object of type unsafe.Pointer.
	ptr := C.malloc(C.sizeof_char * 1024)
	defer C.free(unsafe.Pointer(ptr))

	// An unsafe pointer can be cast to a pointer of any type. We cast it to a
	// pointer to char before passing it to our greet function.
	size := C.greet(&g, (*C.char)(ptr))

	// Convert the C buffer to a go []byte object. The cgo function C.GoBytes
	// does this for us, using the pointer and the size of the written data. The
	// byte slice returned does not share memory with the bytes we allocated
	// using malloc. We can safely call free on ptr and continue to use the byte
	// slice returned by C.GoBytes.
	b := C.GoBytes(ptr, size)

	fmt.Println(string(b))
}
