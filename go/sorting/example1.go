package main

import (
	"fmt"
	"sort"
)

func main() {
	strs := []string{"e", "b", "c"}
	sort.Strings(strs)
	fmt.Println("Strings:", strs)

	ints := []int{8, 3, 5}
	sort.Ints(ints)
	fmt.Println("Ints:", ints)

	s := sort.IntsAreSorted(ints)
	fmt.Println("Sorted:", s)
}
