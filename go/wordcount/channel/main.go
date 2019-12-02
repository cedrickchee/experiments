// My take on wc with Go language for fun in response to Chris Penner's blog post
// "Beating C with 80 Lines of Haskell".
package main

import (
	"io"
	"os"
	"runtime"
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

	chunks := make(chan Chunk)
	counts := make(chan Count)

	numWorkers := runtime.NumCPU()
	for i := 0; i < numWorkers; i++ {
		go SumChunk(chunks, counts)
	}

	for {
		b, err := file.Read(buffer)
		if err != nil {
			if err == io.EOF {
				break
			} else {
				panic(err)
			}
		}

		chunks <- Chunk{lastCharIsSpace, buffer[:b]}
		lastCharIsSpace = IsSpace(buffer[b-1])
	}
	close(chunks)

	for i := 0; i < numWorkers; i++ {
		count := <-counts
		totalCount.LineCount += count.LineCount
		totalCount.WordCount += count.WordCount
	}
	close(counts)

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

func SumChunk(chunks <-chan Chunk, counts chan<- Count) {
	totalCount := Count{}

	for {
		chunk, ok := <-chunks
		if !ok {
			break
		}
		count := GetCount(chunk)
		totalCount.LineCount += count.LineCount
		totalCount.WordCount += count.WordCount
	}

	counts <- totalCount
}
