package datamath

// Sum calculates the total from an array of numbers
func Sum(numbers []int) int {
	var sum int

	for _, v := range numbers {
		sum += v
	}

	return sum
}

// SumAll calculates the respective sums of every slice passed in
func SumAll(numbersToSum ...[]int) []int {
	lengthOfNumbers := len(numbersToSum)
	sums := make([]int, lengthOfNumbers)

	for i, numbers := range numbersToSum {
		sums[i] = Sum(numbers)
	}

	return sums
}
