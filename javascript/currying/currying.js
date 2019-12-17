// Curring is partial invocation of a function.
// Currying means first few arguments of a function is pre-processed and a function is returned.
// The returning function can add more arguments to the curried function.
//
// It's like if you have given one or two spice to the curry and cooked little
// bit, still you can add further spice to it.
//
// A simple example will look like:
function addBase(base) {
  return function(num) {
    return base + num;
  };
}

// You can add a curry method to the prototype of Function. If now parameters
// is passed to curry, you simply return the current function.
Function.prototype.curry = function() {
  if (arguments.length < 1) {
    return this; // nothing to curry. return function.
  }

  var self = this;
  var args = toArray(arguments); // example of arguments is [1.62, 'km']

  return function() {
    // example of arguments is [Arguments] { '0': 2 }
    return self.apply(this, args.concat(toArray(arguments)));
  };
};

function converter(factor, symbol, input) {
  return factor * input + " " + symbol;
}

function toArray(args) {
  // Args is not an array rather an array like object.
  // This function convert array like object to array.
  return Array.prototype.slice.call(args);
}

module.exports = { addBase, converter };
