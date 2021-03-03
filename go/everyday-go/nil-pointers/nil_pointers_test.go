// Contrived examples
// Nil pointer derefences

package nilpointers

import (
	"fmt"
	"testing"
	"time"
)

type S struct {
	Name string
}

func NilPointer() int {
	// The variable s is initialized to nil because that is the zero value for
	// any pointer, regardless of what type it points to.
	var s *S
	// The pointer s is automatically dereferenced when we attempt to access
	// the Name property of the S struct that s points to-- except it does not
	// point to one.
	fmt.Println(s.Name)
	return 1

	// In a language that is not memory safe, the runtime behavior under these
	// circumstances is not well-defined. This can lead to buffer overruns,
	// wildly unpredictable behavior, and dangerous vulnerabilities.
	//
	// Go, however, is memory safe, meaning the runtime behavior under these
	// circumstances is well-defined. Under these circumstances, a Go program
	// will panic and halt execution.
}

// Run test command from root dir:
// `go test -v ./nil-pointers -run ^TestNilPointer$`
// - or -
// `cd nil-pointers; go test -v nil_pointers_test.go`
func TestNilPointer(t *testing.T) {
	// Running the program above yields:
	// panic: runtime error: invalid memory address or nil pointer dereference [recovered]
	// panic: runtime error: invalid memory address or nil pointer dereference
	// [signal SIGSEGV: segmentation violation code=0x1 addr=0x0 pc=0x50a283]
	//
	// goroutine 6 [running]:
	// testing.tRunner.func1.2(0x521ea0, 0x614a50)
	// 		/usr/local/go/src/testing/testing.go:1144 +0x332
	// testing.tRunner.func1(0xc000001380)
	// 		/usr/local/go/src/testing/testing.go:1147 +0x4b6
	// panic(0x521ea0, 0x614a50)
	// 		/usr/local/go/src/runtime/panic.go:965 +0x1b9
	// command-line-arguments.NilPointer(0xc0294bc459)
	// 		.../examples/pointers/pointers_test.go:16 +0x23
	got := NilPointer()
	if got != 1 {
		t.Errorf("NilPointer() = %d, want 1", got)
	}
}

// Run test command from root dir:
// `go test -v ./nil-pointers -run ^TestNilPointerAndConcurrency$`
func NilPointerAndConcurrency() {
	// Running the program above yields:
	// 0
	// 1
	// 2
	// 3
	// 4
	// panic: runtime error: invalid memory address or nil pointer dereference
	// [signal SIGSEGV: segmentation violation code=0x1 addr=0x0 pc=0x50a890]
	//
	// goroutine 8 [running]:
	// github.com/cedrickchee/experiments/go/everyday-go/nil-pointers.NilPointerAndConcurrency.func2()
	//         .../experiments/go/everyday-go/nil-pointers/nil_pointers_test.go:74 +0x50
	doneCh := make(chan struct{})

	go func() {
		defer close(doneCh)
		for i := 0; i < 10; i++ {
			fmt.Println(i)
			<-time.After(time.Second)
		}
	}()

	go func() {
		<-time.After(5 * time.Second)
		var s *S
		fmt.Println(s.Name)
	}()

	<-doneCh

	// We count in one goroutine while, in another, waiting for 5s before
	// deliberately triggering a panic via nil pointer dereference.
	// This terminates the entire program and the first goroutine doesn’t
	// continue counting. This is the safest possible behavior, because suppose
	// that one goroutine that continued on were dependent on sending values
	// to or receiving values from (over a channel) the goroutine that had
	// encountered a nil pointer dereference and died.
	// This could rapidly deadlock the program.
}

func TestNilPointerAndConcurrency(t *testing.T) {
	NilPointerAndConcurrency()
}
