# Interop: Calling Go from Zig

Code in this project is based on Frank Denis's blog post: [ZGo (part 2): Calling Go from Zig](https://jedi.sh/goz)

> Following our last post Calling Zig from Go, we can also utilize Zig to call
> Go. There are two possible approaches here, using go tool to generate C and
> importing it in Zig, or building a library and linking it with Zig. I opted
> for the library route from Go. It should be a more general use-case that can
> be applied to other languages as well.

> `build.zig`
>
> There is not much that has changed from our last `build.zig`, other than the
> steps being reversed. We need to call the go step before our default step so
> we can link the produced library with our Zig program. Note that for the
> library to be found it must be named libhello.a and be produced in our defined
> Library search path (the current directory.)
>
> Running `zig build go && zig build` will compile the executable.

Calling Go from Zig:

```sh
$ ./zig-out/bin/hello
Hello Ziguana
Hello Gopher
```

> ## Conclusion
>
> Go has the advantage of a huge ecosystem of libraries and being able to tap
> into that with Zig seamlessly is a powerful tool. There has been a handful of
> times when I wanted to vendor a library that simply did not exist in C, and
> having Go as an additional option will help cover more bases.
