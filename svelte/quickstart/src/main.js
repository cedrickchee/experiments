import App from "./App.svelte";

const app = new App({
  target: document.body,
  // we'll learn about props later
  props: {
    name: "world"
  }
});

export default app;
