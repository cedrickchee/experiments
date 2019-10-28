// Solution for HackerRank "Algorithmic Crush" challenge.
// https://www.hackerrank.com/challenges/crush/problem
//
// How this solution works?
//
// Instead of storing the actual values in the array, you store the difference
// between the current element and the previous element. So you add sum to a[p]
// showing that a[p] is greater than its previous element by sum. You subtract
// sum from a[q+1] to show that a[q+1] is less than a[q] by sum (since a[q] was
// the last element that was added to sum). By the end of all this, you have an
// array that shows the difference between every successive element. By adding
// all the positive differences, you get the value of the maximum element.
package main

import (
	"bufio"
	"fmt"
	"math"
	"os"
)

func main() {
	// Input format:
	// 5 3
	// 1 2 100
	// 2 5 100
	// 3 4 100
	//
	// The first line contains two space-separated integers `n` and `m`, the size of the array and the number of operations.
	// Each of the next `m` lines contains three space-separated integers `a`, `b` and `k`, the left index, right index and summand.
	//
	// In this example of input, our:
	// n = 5, m = 3
	// line m = 1: a = 1, b = 2, k = 100
	// line m = 2: a = 2, b = 5, k = 100
	// ...
	// Size of array, n:
	// In our example, n = 5. Our array of zeroes looks like this:
	// [0, 0, 0, 0, 0]
	var n, m, a, b, k int

	io := bufio.NewReader(os.Stdin)
	fmt.Fscan(io, &n)   // grab n from stdin
	fmt.Fscan(io, &m)   // grab m from stdin
	l := make([]int, n) // make array of zeroes

	// loop each line for m times
	// i.e of stdin input when m is 1: 1 2 100
	for i := 1; i <= m; i++ {
		fmt.Fscan(io, &a) // a is left index. grab it from stdin
		fmt.Fscan(io, &b) // b is right index, grab it from stdin
		fmt.Fscan(io, &k) // k is summand, grab it from stdin

		// Store the difference between the current element and the previous
		// element in the array.
		l[a-1] += k // a is 1-indexed. so, we need to minus 1.
		if b <= n-1 {
			l[b] -= k
		}
	}

	// Get largest value from array, l
	// The array shows the difference between every successive element.
	max := math.MinInt64 // using MinInt64 to avoid edge cases
	sum := 0
	for _, v := range l {
		sum += v // By adding all the positive differences, you get the value of the maximum element
		if sum >= max {
			max = sum
		}
	}
	fmt.Print(max)
}
