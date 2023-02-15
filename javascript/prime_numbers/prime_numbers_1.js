/**
 * List prime numbers
 *
 * In other words, `n > 1` is a prime if it can't be evenly divided by anything
 * except `1` and `n`.
 *
 * For example, `5` is a prime, because it cannot be divided without a remainder
 * by `2`, `3` and `4`.
 *
 * Write the code which outputs prime numbers in the interval from `2` to `n`.
 *
 * For `n = 10` the result will be `2,3,5,7`.
 */

"use strict";

// The first variant uses a label.
function primeNumbers(n) {
  let primes = [];

  nextPrime:
  for (let i = 2; i <= n; i++) {
    for (let j = 2; j < i; j++) {
      if (i % j === 0) {
        continue nextPrime;
      }
    }
  
    primes.push(i);
  }

  return primes;
}

console.log(primeNumbers(10));
