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
