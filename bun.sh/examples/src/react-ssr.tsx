// requires Bun v0.1.0 or later
// react-ssr.tsx
import { renderToReadableStream } from "react-dom/server";

const dt = new Intl.DateTimeFormat();

export default {
  port: 8080,
  async fetch(request: Request) {
    return new Response(
      await renderToReadableStream(
        <html>
          <head>
            <title>Hello World</title>
          </head>
          <body>
            <h1>Hello from React SSR!</h1>
            <p>The date is {dt.format(new Date())}</p>
          </body>
        </html>
      )
    );
  },
};

// bun react-ssr.tsx
