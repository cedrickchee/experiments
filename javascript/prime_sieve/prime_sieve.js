/*
 * Prime Sieve algorithm
 *
 * Algorithm is based on Khan Academy "Sieve of Eratosthenes" video,
 * which is an optimized variation of the ancient Sieve of Eratosthenes.
 * It's fast, very fast. Faster than the concurrent
 * implementation in Go language.
 */

// Find primes up to N.
// input: upperBound (or N, is how far we look for primes)
function sieve(upperBound) {
  // Ignore all input less than 2.
  if (upperBound < 2) {
    return;
  }

  // All unmarked numbers are prime.

  // Build array to mark numbers with.
  let isComposite = [];
  // Mark 0, 1 as not prime.
  isComposite[0] = 1;
  isComposite[1] = 1;

  // For all numbers a: from 2 to sqrt(upperBound)
  for (let a = 2; a * a <= upperBound; a++) {
    // If 'a' is unmarked (undefined value), then 'a' is prime.
    if (isComposite[a] !== 1) {
      // For all multiplies of 'a' (a < upperBound)
      for (let z = a * a; z <= upperBound; z = z + a) {
        // Mark off all multiples starting at a^2.
        isComposite[z] = 1; // mark position z as composite.
      }
    }
  }

  // Store primes in a separate array.
  let primes = []; // array to hold primes.
  let p = 0;
  // Print all primes by scanning array.
  for (let h = 0; h <= upperBound; h++) {
    // When you find a unmarked number.
    if (isComposite[h] !== 1) {
      // Put it in the prime array.
      primes[p] = h;
      // Increment to next cell in array.
      p++;
    }
  }

  return primes;
}

module.exports = sieve;

// TODO: Challenges & Questions:
//
// 1a. Speed up my method of building the primes[] array.
// 1b. How did I decide the size the primes[] array? The prime number theorem.
//
// 2. Can you turn this into a prime counting function?
