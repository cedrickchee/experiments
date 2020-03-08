// Ultimate Go training by Ardan labs
//
// -----------------------------------------------------------------------------
// Language mechanics - syntax
// Pointers
//
// Topic: https://github.com/ardanlabs/gotraining/blob/master/topics/go/language/pointers/README.md
//
// Reading: https://www.ardanlabs.com/blog/2014/12/using-pointers-in-go.html
// -----------------------------------------------------------------------------
//
// Sample program to show the basic concept of using a pointer
// to share data.
package main

func main() {
	// Declare variable of type int with a value of 10.
	count := 10

	// Display the "value of" and "address of" count.
	println("count:\tValue Of[", count, "]\t\tAddr Of[", &count, "]")

	// Pass the "address of" count.
	increment(&count)

	println("count:\tValue Of[", count, "]\t\tAddr Of[", &count, "]")
}

// increment declares count as a pointer variable whose value is
// always an address and points to values of type int.
//go:noinline
func increment(inc *int) {
	// Increment the "value of" count that the "pointer points to".
	*inc++

	println("inc:\tValue Of[", inc, "]\tAddr Of[", &inc, "]\tValue Points To[", *inc, "]")
}
