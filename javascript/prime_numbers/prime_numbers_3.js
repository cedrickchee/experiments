/**
 * List prime numbers
 *
 * There's a lot of space to optimize it. For instance, we could look for the
 * divisors from `2` to square root of `i`. But anyway, if we want to be really
 * efficient for large intervals, we need to change the approach and rely on
 * advanced maths and complex algorithms like [Quadratic
 * sieve](https://en.wikipedia.org/wiki/Quadratic_sieve), [General number field
 * sieve](https://en.wikipedia.org/wiki/General_number_field_sieve) etc.
 *
 */

"use strict";

// An optimized version of the prime number generation function using the
// Quadratic Sieve algorithm.
//
// This implementation uses a Sieve of Eratosthenes-based algorithm, which is
// faster than the simple trial division used in the previous version. The time
// complexity of this optimized algorithm is O(n log log n).
function primeNumbers(limit) {
  let primes = [];
  let isComposite = new Array(limit + 1).fill(false);
  let sqrtLimit = Math.floor(Math.sqrt(limit));

  for (let i = 2; i <= sqrtLimit; i++) {
    if (!isComposite[i]) {
      for (let j = i * i; j <= limit; j += i) {
        isComposite[j] = true;
      }
    }
  }

  for (let i = 2; i <= limit; i++) {
    if (!isComposite[i]) {
      primes.push(i);
    }
  }

  return primes;
}

console.log(primeNumbers(100_000));
