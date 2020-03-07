// Ultimate Go training by Ardan labs
//
// -----------------------------------------------------------------------------
// Language mechanics - syntax
// Stack and pointers
//
// Topic: https://github.com/ardanlabs/gotraining/blob/master/topics/go/language/pointers/README.md
//
// Reading: https://www.ardanlabs.com/blog/2017/05/language-mechanics-on-stacks-and-pointers.html
// -----------------------------------------------------------------------------

package main

func main() {
	// Listing 1 - frame boundaries

	// Declare variable of type int with a value of 10.
	count := 10

	// Display the "value of" and "address of" count.
	println("count:\tValue Of[", count, "]\tAddr Of[", &count, "]")

	// Pass the "value of" the count.
	increment(count)

	println("count:\tValue Of[", count, "]\tAddr Of[", &count, "]")

	// Prints:
	// count:  Value Of[ 10 ]  Addr Of[ 0xc000038748 ]
	// inc:    Value Of[ 11 ]  Addr Of[ 0xc000038740 ]
	// count:  Value Of[ 10 ]  Addr Of[ 0xc000038748 ]
}

//go: noinline
func increment(inc int) {
	// Increment the "value of" inc.
	inc++
	println("inc:\tValue Of[", inc, "]\tAddr Of[", &inc, "]")
}
