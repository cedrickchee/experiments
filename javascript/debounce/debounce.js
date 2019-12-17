/* Window's resize event for example: the event fires at each step in the resize,
 * so if you have a taxing event listener, your user's browser will get bogged down quickly.
 *
 * Use debouncing to temper the amount of time the method runs.
 * Instead of the listener function firing on each iteration of the resize event,
 * we can ensure it fires only every n milliseconds during the resize, allowing
 * our functionality to fire but at a rate so as to not ruin the user's experience.
 */

// Returns a function, that, as long as it continues to be invoked, will not
// be triggered. The function will be called after it stops being called for
// N milliseconds. If `immediate` is passed, trigger the function on the
// leading edge, instead of the trailing.
//
// Original implementation is from underscore.js which also has an MIT license.
function debounce(func, wait, immediate) {
  let timeout;

  return () => {
    let context = this,
      args = arguments;

    let later = () => {
      timeout = null;
      if (!immediate) func.apply(context, args);
    };

    let callNow = immediate && !timeout;
    clearTimeout(timeout);
    timeout = setTimeout(later, wait);
    if (callNow) func.apply(context, args);
  };
}

module.exports = debounce;
