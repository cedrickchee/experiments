package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"
)

func stringReduction(s string) int32 {
	var n int = len(s)

	var as, bs, cs int = 0, 0, 0

	for i := 0; i < n; i++ {
		ch := string(s[i])
		if ch == "a" {
			as++
		}
		if ch == "b" {
			bs++
		}
		if ch == "c" {
			cs++
		}
	}

	var cond bool = true

	for cond {
		if as == 0 && bs == 0 {
			cond = false
		} else if as == 0 && cs == 0 {
			cond = false
		} else if bs == 0 && cs == 0 {
			cond = false
		}

		if as >= bs && bs >= cs {
			as--
			bs--
			cs++
		} else if as >= cs && cs >= bs {
			as--
			cs--
			bs++
		} else if bs >= as && as >= cs {
			bs--
			as--
			cs++
		} else if bs >= cs && cs >= as {
			bs--
			cs--
			as++
		} else if cs >= as && as >= bs {
			cs--
			as--
			bs++
		} else if cs >= bs && bs >= as {
			cs--
			bs--
			as++
		}
	}

	return int32(as + bs + cs + 1)
}

func main() {
	reader := bufio.NewReaderSize(os.Stdin, 1024*1024)

	stdout, err := os.Create(os.Getenv("OUTPUT_PATH"))
	checkError(err)

	defer stdout.Close()

	writer := bufio.NewWriterSize(stdout, 1024*1024)

	tTemp, err := strconv.ParseInt(readLine(reader), 10, 64)
	checkError(err)
	t := int32(tTemp)

	for tItr := 0; tItr < int(t); tItr++ {
		s := readLine(reader)

		result := stringReduction(s)

		fmt.Fprintf(writer, "%d\n", result)
	}

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
