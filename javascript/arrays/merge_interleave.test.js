const mergeTwoArray = require("./merge_interleave");

test("merge two array elements interleavingly", () => {
  let a = [2, 5, 8, 9, 15, 29];
  let b = [1, 2, 3, 13];

  let result = mergeTwoArray(a, b);

  expect(result).toEqual([2, 1, 5, 2, 8, 3, 9, 13, 15, 29]);
});

test("merge arrays with second array has more element than first array", () => {
  let a = [1, 5, 8, 16];
  let b = [4, 2, 6, 10, 13, 31];

  let result = mergeTwoArray(a, b);

  expect(result).toEqual([4, 1, 2, 5, 6, 8, 10, 16, 13, 31]); //[1, 4, 5, 2, 8, 6, 16, 10, 13, 31]
});
