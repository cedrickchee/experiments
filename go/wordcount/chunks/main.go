// My take on wc with Go language for fun in response to Chris Penner's blog post
// "Beating C with 80 Lines of Haskell".
package main

import (
	"io"
	"os"
)

type Chunk struct {
	PrevCharIsSpace bool
	Buffer          []byte
}

type Count struct {
	LineCount int
	WordCount int
}

func main() {
	if len(os.Args) < 2 {
		panic("no file path specified")
	}
	filePath := os.Args[1]

	file, err := os.Open(filePath)
	if err != nil {
		panic(err)
	}
	defer file.Close()

	lastCharIsSpace := true
	totalCount := Count{}

	const bufferSize = 16 * 1024
	buffer := make([]byte, bufferSize)

	for {
		b, err := file.Read(buffer)
		if err != nil {
			if err == io.EOF {
				break
			} else {
				panic(err)
			}
		}

		count := GetCount(Chunk{lastCharIsSpace, buffer[:b]})
		lastCharIsSpace = IsSpace(buffer[b-1])

		totalCount.LineCount += count.LineCount
		totalCount.WordCount += count.WordCount
	}

	fileStat, err := file.Stat()
	if err != nil {
		panic(err)
	}
	byteCount := fileStat.Size()

	println(totalCount.LineCount, totalCount.WordCount, byteCount, file.Name())
}

func GetCount(chunk Chunk) Count {
	count := Count{}

	prevCharIsSpace := chunk.PrevCharIsSpace

	for _, b := range chunk.Buffer {
		switch b {
		case '\n':
			count.LineCount++
			prevCharIsSpace = true
		case ' ', '\t', '\r', '\v', '\f':
			prevCharIsSpace = true
		default:
			if prevCharIsSpace {
				count.WordCount++
				prevCharIsSpace = false
			}
		}
	}

	return count
}

func IsSpace(b byte) bool {
	return b == ' ' || b == '\t' || b == '\r' || b == '\v' || b == '\f'
}
