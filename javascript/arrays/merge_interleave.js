// Merge elements from two arrays interleavingly.

function mergeTwoArray(a, b) {
  let result = [];

  if (a.length > b.length) {
    for (i = 0; i < a.length; i++) {
      result.push(a[i]);
      if (i < b.length) {
        result.push(b[i]);
      }
    }
  } else {
    for (i = 0; i < b.length; i++) {
      result.push(b[i]);
      if (i < a.length) {
        result.push(a[i]);
      }
    }
  }

  return result;
}

module.exports = mergeTwoArray;
