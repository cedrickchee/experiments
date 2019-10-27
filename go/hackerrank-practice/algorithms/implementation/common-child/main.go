// Longest Common Subsequence (LCS) problem
// Reference: https://en.wikipedia.org/wiki/Longest_common_subsequence_problem

package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"strings"
)

func commonChild(s1 string, s2 string) int32 {
	m, n := len(s1), len(s2)

	prev, cur := make([]int, n+1), make([]int, n+1)

	for i := 1; i < m+1; i++ {
		for j := 1; j < n+1; j++ {
			if s1[i-1] == s2[j-1] {
				cur[j] = 1 + prev[j-1]
			} else {
				cur[j] = Max(cur[j-1], prev[j])
			}
		}

		cur, prev = prev, cur
	}
	ret := int32(prev[n])

	return ret
}

// Max compare the maximum of two integers
func Max(x, y int) int {
	if x > y {
		return x
	}
	return y
}

func main() {
	reader := bufio.NewReaderSize(os.Stdin, 1024*1024)

	stdout, err := os.Create(os.Getenv("OUTPUT_PATH"))
	checkError(err)

	defer stdout.Close()

	writer := bufio.NewWriterSize(stdout, 1024*1024)

	s1 := readLine(reader)

	s2 := readLine(reader)

	result := commonChild(s1, s2)

	fmt.Fprintf(writer, "%d\n", result)

	writer.Flush()
}

func readLine(reader *bufio.Reader) string {
	str, _, err := reader.ReadLine()
	if err == io.EOF {
		return ""
	}

	return strings.TrimRight(string(str), "\r\n")
}

func checkError(err error) {
	if err != nil {
		panic(err)
	}
}
