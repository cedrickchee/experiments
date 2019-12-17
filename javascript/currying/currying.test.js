const { addBase, converter } = require("./currying");

test("add base 8", () => {
  var addEight = addBase(8);

  expect(addEight(1)).toBe(9);
  expect(addEight(2)).toBe(10);
  expect(addEight(3)).toBe(11);
});

test("currying Function", () => {
  let milesToKm = converter.curry(1.62, "km");
  expect(milesToKm(2)).toBe("3.24 km");

  let kgToLb = converter.curry(2.2, "lb");
  expect(kgToLb(2)).toBe("4.4 lb");
});
