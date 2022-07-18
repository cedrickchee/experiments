// http.ts
export default {
  port: 8080,
  fetch(request: Request) {
    return new Response("Hello World");
  },
};

// bun ./http.ts
