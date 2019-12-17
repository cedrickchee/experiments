// Migrate callbacks to promises
//
// Intro to promises: https://developers.google.com/web/fundamentals/primers/promises
//
// How do I convert an existing callback API to promises?
// https://stackoverflow.com/q/22519784/206570

const parseJson = response => {
  return JSON.parse(response);
};

// ****************************************************************************
// Callback
// ****************************************************************************
function fetch(url, successCallback, errorCallback) {
  if (url === "") {
    return errorCallback(new Error("Fetch error"));
  }

  setTimeout(() => {
    successCallback('{ "name": "foo", "bar": "baz" }');
  }, 1000);
}

fetch(
  "something.json",
  response => {
    console.log("JSON:", parseJson(response));
  },
  err => {
    console.log(err);
  }
);

// ****************************************************************************
// Promise
// ****************************************************************************
const fetchPromise = url => {
  // To convert a callback into a promise, you need to return a promise.
  return new Promise((resolve, reject) => {
    if (url === "") {
      return reject(new Error("Fetch error"));
    }

    setTimeout(() => {
      resolve('{ "name": "foo", "bar": "baz" }');
    }, 1000);
  });
};

fetchPromise("something.json")
  .then(parseJson)
  .then(res => {
    console.log("JSON:", res);
  })
  .catch(err => {
    console.log(err);
  });
