package main

import (
	"fmt"
)

// First attempt
type Animal struct{}

func (a Animal) MakeSound() {
	fmt.Printf("%v\n", a.Sound())
}

func (a Animal) Sound() string {
	panic("This is abstract method - please provide implementation")
}

type Cat struct{ Animal }

func (c Cat) Sound() string {
	return "meow"
}

type Dog struct{ Animal }

func (d Dog) Sound() string {
	return "bark"
}

func main() {
	// After running the program we would see:
	//
	// "panic: This is abstract method - please provide implementation"
	c := Cat{Animal{}}
	c.MakeSound()

	d := Dog{Animal{}}
	d.MakeSound()
}
