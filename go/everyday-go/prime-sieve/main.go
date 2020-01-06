// Sieve of Eratosthenes
//
// It is an ancient method for generating a list of primes up to some limit N.
//
// This is a concurrent Sieve algorithm.

package main

// Send the sequence 2, 3, 4, ..., N to channel 'ch'.
func generate(ch chan<- int) {
	for i := 2; ; i++ {
		ch <- i // send number to channel.
	}
}

// Copy the values from channel 'in' to channel 'out', removing those divisible
// by 'prime'.
func filter(in <-chan int, out chan<- int, prime int) {
	for {
		num := <-in // receive generated number from 'in' channel.

		if num % prime != 0 {
			// 'num' is prime number
			out <- num
		}
	}
}

// Prime Sieve function that put it all together as a chain of filter steps.
// Input argument, 'searchSize' is how far (upper bound) we look for primes.
func Sieve(searchSize int) (primes []int) {
	// Create an empty slice (dynamic array) with non-zero length to hold primes.
	// Slice length is how many (density) primes are there less than some
	// integer N. We can estimate that using the "prime number theorem".
	// numOfPrimes := float64(searchSize) / math.Log(float64(searchSize))
	// print("numOfPrimes ", int(numOfPrimes), "\n")
	// var primes []int

	in := make(chan int)
	go generate(in) // start 'generate' goroutine.

	for i := 0; i < searchSize; i++ {
		prime := <-in
		primes = append(primes, prime)

		out := make(chan int)
		go filter(in, out, prime) // start 'filter' goroutine.
		in = out
	}

	return
}

func main() {
	primeLimit := 100 // input how large a list of primes you need.
	primes := Sieve(primeLimit) // call the Sieve algorithm.

	for _, p := range primes {
		print(p, "\n")
	}
}
