// Benchmark run
//
// $ go test -bench=.
//
// goos: linux
// goarch: amd64
// pkg: github.com/cedrickchee/experiments/go/everyday-go/prime-sieve
// BenchmarkSieve10-4     	   13772	     82555 ns/op
// BenchmarkSieve100-4    	     649	   1872222 ns/op
// BenchmarkSieve1000-4   	      12	 138705203 ns/op
// BenchmarkSieve5000-4   	       1	10146371301 ns/op
// PASS
// ok  	github.com/cedrickchee/experiments/go/everyday-go/prime-sieve	17.928s

package main

import "testing"

func BenchmarkSieve10(b *testing.B) {
	benchmarkSieve(10, b)
}

func BenchmarkSieve100(b *testing.B) {
	benchmarkSieve(100, b)
}

func BenchmarkSieve1000(b *testing.B) {
	benchmarkSieve(1000, b)
}

func BenchmarkSieve5000(b *testing.B) {
	benchmarkSieve(10000, b)
}

func benchmarkSieve(i int, b *testing.B) {
	// run the Sieve function b.N times
	for n := 0; n < b.N; n++ {
		Sieve(i)
	}
}
