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

// Complete the birthdayCakeCandles function below.
func birthdayCakeCandles(ar []int32) int32 {
	return Count(ar, MaxIntSlice(ar))
}

// Count unique value and get max value count
func Count(arr []int32, max int32) int32 {
	dict := make(map[int32]int32)
	for _, num := range arr {
		dict[num]++
	}
	return dict[max]
}

// MinIntSlice returns the minimum of a slice of int arguments
func MinIntSlice(v []int32) int32 {
	sort.Slice(v, func(i, j int) bool { return v[i] < v[j] })
	return v[0]
}

// MaxIntSlice returns the maximum of a slice of int arguments
func MaxIntSlice(v []int32) int32 {
	sort.Slice(v, func(i, j int) bool { return v[i] < v[j] })
	return v[len(v)-1]
}

func main() {
	reader := bufio.NewReaderSize(os.Stdin, 1024*1024)

	stdout, err := os.Create(os.Getenv("OUTPUT_PATH"))
	checkError(err)

	defer stdout.Close()

	writer := bufio.NewWriterSize(stdout, 1024*1024)

	arCount, err := strconv.ParseInt(readLine(reader), 10, 64)
	checkError(err)

	arTemp := strings.Split(readLine(reader), " ")

	var ar []int32

	for i := 0; i < int(arCount); i++ {
		arItemTemp, err := strconv.ParseInt(arTemp[i], 10, 64)
		checkError(err)
		arItem := int32(arItemTemp)
		ar = append(ar, arItem)
	}

	result := birthdayCakeCandles(ar)

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
