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

// function getPrimes(limit) {
//   // returns an array of prime numbers up to a given limit
  
//   let primes = [];
//   for (let i = 2; i <= limit; i++) {
//     let isPrime = true;
//     for (let j = 2; j < i; j++) {
//       if (i % j === 0) {
//         isPrime = false;
//         break;
//       }
//     }
//     if (isPrime) {
//       primes.push(i);
//     }
//   }
//   return primes;
// }

// This will return the prime numbers up to 20, which are [2, 3, 5, 7, 11, 13, 17, 19].
// console.log(getPrimes(20));

// 
// Refactor the above code.
// 

// The second variant uses an additional function `isPrime(n)` to test for
// primality.
function primeNumbers(n) {
  let primes = [];

  for (let i = 2; i < n; i++) {
    if (!isPrime(i)) continue;

    primes.push(i);
  }

  return primes;
}

// isPrime test for primality of a number, returns true if number is prime.
function isPrime(n) {
  for (let i = 2; i < n; i++) {
    if ( n % i == 0) return false;
  }
  return true;
}

// returns the same result as the above function, but the logic is different.

// function is_prime(n) {
//   if (n < 2) return false;
//   if (n % 2 == 0) return false;
//   for (var i = 3; i * i <= n; i += 2) {
//     if (n % i == 0) return false;
//   }
//   return true;
// }

console.log(primeNumbers(10));
