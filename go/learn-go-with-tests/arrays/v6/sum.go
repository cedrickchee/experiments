package datamath

// Sum calculates the total from an array of numbers
func Sum(numbers []int) int {
	var sum int

	for _, v := range numbers {
		sum += v
	}

	return sum
}

// SumAllTails calculates the respective sums of every slice passed in
func SumAllTails(numbersToSum ...[]int) []int {
	var sums []int

	for _, numbers := range numbersToSum {
		tail := numbers[1:]
		sums = append(sums, Sum(tail))
	}

	return sums
}
