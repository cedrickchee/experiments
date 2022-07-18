// Bun bindings for raylib. Requires raylib shared libraries to be
// available on your system.

import { Window, Color } from "./raylib";

const mainWindow = new Window("Raylib App", 500, 500);

mainWindow.draw((ctx) => {
  ctx.background(Color.black);
  ctx.text(90, 225, "Hello from Raylib!", 40);
});

mainWindow.close();
