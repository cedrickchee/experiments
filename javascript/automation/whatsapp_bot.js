const storeKey = 'WATracker';

// Select the node that will be observed for mutations
const targetNode = document.querySelector('#main header');

// Options for the observer (which mutations to observe)
const config = {
  attributes: true,
  childList: true,
  subtree: true
};

// Callback function to execute when mutations are observed
const callback = function(mutationsList, observer) {
  console.log('user status changed');

  let name = document.querySelector('#main header span[dir="auto"]');
  let onlineStatus = document.querySelector('span[title="online"]');
  let username = name.innerText;
  let date = new Date().toISOString();
  let status = onlineStatus ? 'online' : 'offline';

  let messageData = JSON.parse(localStorage.getItem(storeKey)) || {};

  const found = messageData[username];

  if (found) {
    messageData[username].push({ date, status });
  } else {
    messageData[username] = [{ date, status }];
  }

  let json = JSON.stringify(messageData);

  localStorage.setItem(storeKey, json);
};

// Create an observer instance linked to the callback function
const observer = new MutationObserver(callback);

// Start observing the target node for configured mutations
observer.observe(targetNode, config);

// Later, you can stop observing
// observer.disconnect();
