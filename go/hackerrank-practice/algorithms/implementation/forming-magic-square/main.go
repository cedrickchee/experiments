package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"sort"
	"strconv"
	"strings"
)

// Complete the formingMagicSquare function below.
func formingMagicSquare(s [][]int32) int32 {
	magSqr := [][]int32{
		[]int32{8, 1, 6, 3, 5, 7, 4, 9, 2},
		[]int32{8, 3, 4, 1, 5, 9, 6, 7, 2},
		[]int32{2, 7, 6, 9, 5, 1, 4, 3, 8},
		[]int32{2, 9, 4, 7, 5, 3, 6, 1, 8},
		[]int32{6, 1, 8, 7, 5, 3, 2, 9, 4},
		[]int32{6, 7, 2, 1, 5, 9, 8, 3, 4},
		[]int32{4, 3, 8, 9, 5, 1, 2, 7, 6},
		[]int32{4, 9, 2, 3, 5, 7, 8, 1, 6},
	}
	replacement := make([]int32, 8)
	for i := 0; i < 8; i++ {
		_ = append(replacement, 0)

		for j := 0; j < 9; j++ {
			replacement[i] += Abs(magSqr[i][j] - s[int32(j/3)][j%3])
		}
	}
	cost := MinIntSlice(replacement)

	return cost
}

// MinIntSlice ...
func MinIntSlice(v []int32) int32 {
	sort.Slice(v, func(i, j int) bool { return v[i] < v[j] })
	return v[0]
}

// Abs ...
func Abs(x int32) int32 {
	if x < 0 {
		return -x
	}
	return x
}

func main() {
	reader := bufio.NewReaderSize(os.Stdin, 1024*1024)

	stdout, err := os.Create(os.Getenv("OUTPUT_PATH"))
	checkError(err)

	defer stdout.Close()

	writer := bufio.NewWriterSize(stdout, 1024*1024)

	var s [][]int32
	for i := 0; i < 3; i++ {
		sRowTemp := strings.Split(readLine(reader), " ")

		var sRow []int32
		for _, sRowItem := range sRowTemp {
			sItemTemp, err := strconv.ParseInt(sRowItem, 10, 64)
			checkError(err)
			sItem := int32(sItemTemp)
			sRow = append(sRow, sItem)
		}

		if len(sRow) != 3 {
			panic("Bad input")
		}

		s = append(s, sRow)
	}

	result := formingMagicSquare(s)

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
