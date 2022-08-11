# Wrapping a C Library with Zig

Follow along this [blog post](https://www.nmichaels.org/zig/wrap-sodium.html) by
Nathan Michaels.

> The code examples are going to start getting long, so instead of reproducing
> entire files here, I'll point you to [sourcehut][sr.ht] or, if you really prefer,
> [github][github] where I've made this project available.

[sr.ht]: https://hg.sr.ht/~nmichaels/sodium-wrapper
[github]: https://github.com/nmichaels/sodium-wrapper

## About Project

A Sodium wrapper for Zig.

[libsodium documentation](https://doc.libsodium.org)

Requires libsodium-dev or, if not on Debian, some package that provides
`sodium.h`. (see [setup][#setup] below)

## Wrapper

My wrapper currently only wrap Sodium [`crypto_box` function](https://doc.libsodium.org/public-key_cryptography/authenticated_encryption#key-pair-generation).

## Setup

_The following step is specific for my machine only._

```sh
# Sometimes, a compile failed for a Zig version.
# This let's me use different Zig version side-by-side in the same machine.
$ alias zig-060='~/download/software/old-zig/zig-linux-x86_64-0.6.0/zig'
$ alias zig-081='~/download/software/old-zig/zig-linux-x86_64-0.8.1/zig'
```

> I'm also assuming a version of libsodium along with development headers is
  installed. If you're running a sensible Linux distro, you should be able to
  install a package named something like libsodium-dev. I've got libsodium23
  and libsodium-dev 1.0.18-1 installed on my Debian system.

```sh
$ sudo apt install libsodium23 libsodium-dev
[...]
libsodium23 is already the newest version (1.0.18-1).
The following NEW packages will be installed:
  libsodium-dev
Need to get 169 kB of archives.
After this operation, 826 kB of additional disk space will be used.
[...]
```

Sanity check libsodium packages are installed correctly:

```sh
$ dpkg -L libsodium23
[...]
ls /usr/lib/x86_64-linux-gnu/libsodium.so.23.3.0
ls /usr/lib/x86_64-linux-gnu/libsodium.so.23
[...]

$ dpkg -L libsodium-dev
[...]
/usr/include/sodium.h
/usr/include/sodium/version.h
/usr/lib/x86_64-linux-gnu/libsodium.a
[...]
```
