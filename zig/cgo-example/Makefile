compile-c:
	# gcc -c greeter.c
	$(CC) -g -fPIC -c -o lib/greeter.o lib/greeter.c
	$(CC) -g -fPIC -shared -o libgreeter.so lib/greeter.o

run:
	LD_LIBRARY_PATH=. go run main.go

# Note: command will fail with error "# runtime/cgo gcc: error: x86_64: No such file or directory"
build-macos:
	CGO_ENABLED=1 GOOS=darwin GOARCH=amd64 go build

# Note: command will fail with error "# runtime/cgo gcc: error: unrecognized command line option ‘-mthreads’; did you mean ‘-pthread’?'
build-windows:
	CGO_ENABLED=1 GOOS=windows GOARCH=amd64 go build

# Currently Zig 0.9.1 (master build)
# Doesn't work. Error:
# # runtime/cgo
# Segmentation fault (core dumped)
# make: *** [Makefile:18: cross-compile-macos] Error 2
cross-compile-macos:
	CGO_ENABLED=1 GOOS=darwin GOARCH=amd64 CC="zcc" CXX="zxx" go build

# Currently Zig 0.9.1 (master build)
# Works!
cross-compile-windows:
	CGO_ENABLED=1 GOOS=windows GOARCH=amd64 CC="zcc" CXX="zxx" go build