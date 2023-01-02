# Personal Knowledge Management (PKM)

**_Work-In-Progress_**

This is a project part of my PKM.

It's an information "warehouse" in the form of a wiki that contains "raw materials" (resources) for writing.

This is in the first stage of my PKM. Here is where raw information is keep. Once information is processed, it will flow to my digital garden (Obsidian vault).

## Wiki System

This website is built using [Docusaurus 2](https://docusaurus.io/), a modern static website generator.

### Installation

```
$ pnpm
```

### Local Development

```
$ pnpm start
```

This command starts a local development server and opens up a browser window. Most changes are reflected live without having to restart the server.

### Build

```
$ pnpm build
```

This command generates static content into the `build` directory and can be served using any static contents hosting service.

### Deployment

Using SSH:

```
$ USE_SSH=true pnpm deploy
```

Not using SSH:

```
$ GIT_USER=<Your GitHub username> pnpm deploy
```

If you are using GitHub pages for hosting, this command is a convenient way to build the website and push to the `gh-pages` branch.
