// Original idea on how to test debounced functions
// was based on SO: https://stackoverflow.com/q/52224447/206570
//
// Docs for Jest timers mocks: https://jestjs.io/docs/en/timer-mocks

const debounce = require("./debounce");

describe("debounce", () => {
  beforeEach(() => {
    jest.useFakeTimers();
    jest.spyOn(global, "setTimeout");
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  it("wait 1 second before triggering function", () => {
    const callback = jest.fn();

    // Call it immediately
    // debounceFunc();
    debounce(callback, 1000)();

    // At this point in time, there should have been a single call to
    // setTimeout to schedule the function call in 1 second.
    expect(setTimeout).toBeCalledTimes(1);
    expect(setTimeout).toHaveBeenNthCalledWith(1, expect.any(Function), 1000);
  });

  it("calls the callback after 1 second via runAllTimers", () => {
    const callback = jest.fn();
    const debouncedFunc = debounce(callback, 1000);

    debouncedFunc();

    // At this point in time, the callback should not have been called yet
    expect(callback).not.toBeCalled();

    // Fast-forward until all timers have been executed
    jest.runAllTimers();

    // Now our callback should have been called!
    expect(callback).toBeCalled();
    expect(callback).toBeCalledTimes(1);
  });

  it("calls debounce several times but only calls the callback after 1 second", () => {
    const callback = jest.fn();
    const timeout = 1000;
    const debouncedFunc = debounce(callback, timeout);

    // Call it several times with 100ms between each call
    let numTimes = 10;
    for (let i = 0; i < numTimes; i++) {
      jest.advanceTimersByTime(timeout / numTimes);
      debouncedFunc();
    }

    expect(setTimeout).toBeCalledTimes(numTimes);
    expect(callback).toHaveBeenCalledTimes(0);

    // wait 1000ms
    jest.advanceTimersByTime(timeout); // or fast-forward time using `jest.runAllTimers()`
    expect(callback).toHaveBeenCalledTimes(1);
  });
});
