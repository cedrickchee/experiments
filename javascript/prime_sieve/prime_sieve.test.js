const primeSieve = require("./prime_sieve");

test("primes up to thirty", () => {
  const primeLimit = 30; // input how large a list of primes you need
  const primes = primeSieve(primeLimit); // call the sieve algorithm

  expect(primes.length).toEqual(10);
  expect(primes).toEqual([2, 3, 5, 7, 11, 13, 17, 19, 23, 29]);
});
