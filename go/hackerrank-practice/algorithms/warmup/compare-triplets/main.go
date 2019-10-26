package main

// First, set the environment variable:
// $ export OUTPUT_PATH=/tmp/hr1
//
// Next, create the output file
// $ touch /tmp/hr1
//
// Finally, run the program:
// $ go run compare-triplets.go

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"
)

// Complete the compareTriplets function below.
func compareTriplets(a []int32, b []int32) []int32 {
	// how to implement the python `zip` function in golang?
	// how to convert slices to tuple?
	// https://stackoverflow.com/a/26958771/206570
	//
	// how to iterate two arrays using one `range`:
	// https://stackoverflow.com/a/28047625/206570

	ret := make([]int32, 2)

	iter := zip(a, b)

	for tuple := iter(); tuple != nil; tuple = iter() {
		aliceScore := tuple[0]
		bobScore := tuple[1]
		if aliceScore > bobScore {
			ret[0]++
		} else if aliceScore < bobScore {
			ret[1]++
		}
	}

	return ret
}

func zip(lists ...[]int32) func() []int32 {
	zip := make([]int32, len(lists))
	i := 0
	return func() []int32 {
		for j := range lists {
			if i >= len(lists[j]) {
				return nil
			}
			zip[j] = lists[j][i]
		}
		i++
		return zip
	}
}

func main() {
	reader := bufio.NewReaderSize(os.Stdin, 16*1024*1024)

	stdout, err := os.Create(os.Getenv("OUTPUT_PATH"))
	checkError(err)

	defer stdout.Close()

	writer := bufio.NewWriterSize(stdout, 16*1024*1024)

	aTemp := strings.Split(strings.TrimSpace(readLine(reader)), " ")

	var a []int32

	for i := 0; i < 3; i++ {
		aItemTemp, err := strconv.ParseInt(aTemp[i], 10, 64)
		checkError(err)
		aItem := int32(aItemTemp)
		a = append(a, aItem)
	}

	bTemp := strings.Split(strings.TrimSpace(readLine(reader)), " ")

	var b []int32

	for i := 0; i < 3; i++ {
		bItemTemp, err := strconv.ParseInt(bTemp[i], 10, 64)
		checkError(err)
		bItem := int32(bItemTemp)
		b = append(b, bItem)
	}

	result := compareTriplets(a, b)

	for i, resultItem := range result {
		fmt.Fprintf(writer, "%d", resultItem)

		if i != len(result)-1 {
			fmt.Fprintf(writer, " ")
		}
	}

	fmt.Fprintf(writer, "\n")

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
