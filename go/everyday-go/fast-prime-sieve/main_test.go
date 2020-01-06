// Benchmark run
//
// $ go test -bench=.
//
// goos: linux
// goarch: amd64
// pkg: github.com/cedrickchee/experiments/go/everyday-go/fast-prime-sieve
// BenchmarkSieve10-4          	 5200050	       218 ns/op
// BenchmarkSieve100-4         	 1000000	      1071 ns/op
// BenchmarkSieve1000-4        	  143314	      8306 ns/op
// BenchmarkSieve5000-4        	   13491	     84335 ns/op
// BenchmarkSieve10000000-4    	       7	 150355492 ns/op
// BenchmarkSieve100000000-4   	       1	20211143544 ns/op
// PASS
// ok  	github.com/cedrickchee/experiments/go/everyday-go/fast-prime-sieve	28.280s

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

func BenchmarkSieve10000000(b *testing.B) {
	benchmarkSieve(10000000, b)
}

func BenchmarkSieve100000000(b *testing.B) {
	benchmarkSieve(1000000000, b)
}

func benchmarkSieve(i int, b *testing.B) {
	// run the Sieve function b.N times
	for n := 0; n < b.N; n++ {
		Sieve(i)
	}
}
