+++
title = "My third post"
date = 2022-11-23
+++

## Third Post

This is my third blog post.

### Heading L3

Something. Blah...

A [test script](testscript.js). It's **really cool free-software**!

### Photos Gallery

![Squid Game](sg-logo-640.jpg)

![Catup](catup.jpg)

![Grugbrain](images/grugbrain_dev.jpg)

# Something manual! {#manual .header .bold}

Demo of heading id and anchor insertion.

You can also manually specify an id with a {#...} suffix on the heading line as
well as CSS classes:

```md
# Something manual! {#manual .header .bold}
```

This is useful for making deep links robust, either proactively (so that you can
later change the text of a heading without breaking links to it) or
retroactively (keeping the slug of the old header text when changing the text).
It can also be useful for migration of existing sites with different header id
schemes, so that you can keep deep links working.

### Internal links (Demo)

Linking to other pages and their headings is so common that Zola adds a special
syntax to Markdown links to handle them: start the link with `@/` and point to
the `.md` file you want to link to. The path to the file starts from the
`content` directory.

For example, linking to a file located at `content/pages/about.md` would be `[my link](@/pages/about.md)`. You can still link to an anchor directly; `[my link](@/pages/about.md#example)` will work as expected.

[Project](@/project/_index.md) | [About](@/about/index.md) | [Contact](@/contact.md)

Featured posts:
- [Third post](@/blog/third/index.md#manual)
- [Fourth post](@/blog/fourth.md#heading-2)
- Coming soon...