package main

import "fmt"

// Recursively merge two sorted lists.
func merge(arr1 []int, arr2 []int, result *[]int) {
	switch {
	case len(arr1) == 0 && len(arr2) == 0:
		return
	case len(arr1) > 0 && len(arr2) == 0:
		*result = append(*result, arr1...)
		return
	case len(arr1) == 0 && len(arr2) > 0:
		*result = append(*result, arr2...)
		return
	default:
		if arr1[0] < arr2[0] {
			*result = append(*result, arr1[0])
			merge(arr1[1:], arr2, result)
		} else {
			*result = append(*result, arr2[0])
			merge(arr1, arr2[1:], result)
		}
	}
}

func main() {
	arr1 := []int{1, 3, 5}
	arr2 := []int{2, 3, 4}
	result := []int{}
	merge(arr1, arr2, &result)
	fmt.Println(result)
}
