package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"
)

/*
 * Complete the 'diagonalDifference' function below.
 *
 * The function is expected to return an INTEGER.
 * The function accepts 2D_INTEGER_ARRAY arr as parameter.
 */

func diagonalDifference(arr [][]int32) int32 {
	// Possible solution 1

	/*
		fmt.Println("arr:", arr)
		var ltrDiagSum int32
		var rtlDiagSum int32
		for i, row := range arr {
			k := len(row) - 1 - i
			// fmt.Println("row:", row)
			for j, num := range row {
				fmt.Println("num:", num)
				if i == j {
					ltrDiagSum += num
				}
				if k == j {
					rtlDiagSum += num
				}
			}
		}
		fmt.Printf("ltrDiagSum: %d, rtlDiagSum: %d\n", ltrDiagSum, rtlDiagSum)
		result := Abs(ltrDiagSum - rtlDiagSum)
		fmt.Println("result:", result)
		return result
	*/

	// Possible solution 2
	var (
		ltrDiagSum int32
		rtlDiagSum int32
		n          int = len(arr[0])
	)

	for i := 0; i < n; i++ {
		fmt.Println("i:", i)
		ltrDiagSum += arr[i][i]
		rtlDiagSum += arr[(n-1)-i][i]
	}
	result := Abs(ltrDiagSum - rtlDiagSum)
	fmt.Println("result:", result)
	return result
}

// Abs computes absolute values
func Abs(x int32) int32 {
	if x < 0 {
		return -x
	}
	return x
}

func main() {
	reader := bufio.NewReaderSize(os.Stdin, 16*1024*1024)

	stdout, err := os.Create(os.Getenv("OUTPUT_PATH"))
	checkError(err)

	defer stdout.Close()

	writer := bufio.NewWriterSize(stdout, 16*1024*1024)

	nTemp, err := strconv.ParseInt(strings.TrimSpace(readLine(reader)), 10, 64)
	checkError(err)
	n := int32(nTemp)

	var arr [][]int32
	for i := 0; i < int(n); i++ {
		arrRowTemp := strings.Split(strings.TrimRight(readLine(reader), " \t\r\n"), " ")

		var arrRow []int32
		for _, arrRowItem := range arrRowTemp {
			arrItemTemp, err := strconv.ParseInt(arrRowItem, 10, 64)
			checkError(err)
			arrItem := int32(arrItemTemp)
			arrRow = append(arrRow, arrItem)
		}

		if len(arrRow) != int(n) {
			panic("Bad input")
		}

		arr = append(arr, arrRow)
	}

	result := diagonalDifference(arr)

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
