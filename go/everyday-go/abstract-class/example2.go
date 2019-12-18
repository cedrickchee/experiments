package main

import (
	"fmt"
)

// Second attempt
type Animal interface {
	Sound() string

	MakeSound()
}

type abstractAnimal struct{ Animal }

func (a abstractAnimal) MakeSound() {
	fmt.Printf("%v\n", a.Sound())
}

type Cat struct{ abstractAnimal }

func (c Cat) Sound() string {
	return "meow"
}

func NewCat() *Cat {
	cat := Cat{abstractAnimal{}}
	cat.abstractAnimal.Animal = cat
	return &cat
}

type Dog struct{ abstractAnimal }

func (d Dog) Sound() string {
	return "bark"
}

func NewDog() *Dog {
	dog := Dog{abstractAnimal{}}
	dog.abstractAnimal.Animal = dog
	return &dog
}

func main() {
	c := NewCat()
	c.MakeSound()

	d := NewDog()
	d.MakeSound()
}
