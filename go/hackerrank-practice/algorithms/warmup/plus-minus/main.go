package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"
)

// Complete the plusMinus function below.
func plusMinus(arr []int32) {
	// fmt.Println("arr:", arr)

	// fmt.Println("Integer is negative number :", math.Signbit(float64(arr[0])))
	// fmt.Println("Integer2 is negative number : ", math.Signbit(float64(arr[1])))

	var p, n, z int
	l := len(arr)

	for i := 0; i < l; i++ {
		num := arr[i]

		if num > 0 {
			p++
		} else if num < 0 {
			n++
		} else {
			z++
		}
	}

	pFrac := float64(p) / float64(l)
	nFrac := float64(n) / float64(l)
	zFrac := float64(z) / float64(l)

	fmt.Printf("%.6f\n", pFrac)
	fmt.Printf("%.6f\n", nFrac)
	fmt.Printf("%.6f\n", zFrac)
}

func main() {
	reader := bufio.NewReaderSize(os.Stdin, 1024*1024)

	nTemp, err := strconv.ParseInt(readLine(reader), 10, 64)
	checkError(err)
	n := int32(nTemp)

	arrTemp := strings.Split(readLine(reader), " ")

	var arr []int32

	for i := 0; i < int(n); i++ {
		arrItemTemp, err := strconv.ParseInt(arrTemp[i], 10, 64)
		checkError(err)
		arrItem := int32(arrItemTemp)
		arr = append(arr, arrItem)
	}

	plusMinus(arr)
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
