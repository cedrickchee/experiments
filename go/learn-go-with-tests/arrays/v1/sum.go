package datamath

// Sum calculates the total from an array of numbers
func Sum(numbers [5]int) int {
	var sum int

	for i := 0; i < len(numbers); i++ {
		sum += numbers[i]
	}

	return sum
}
