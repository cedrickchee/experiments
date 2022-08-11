# Comparing build.zig to this Makefile will give you an idea of what build.zig
# does.

static:
	zig build-lib -fno-stage1 -femit-h zgo.zig
	go build -ldflags "-linkmode external -extldflags -static" bridge.go

dynamic:
	zig build-lib -dynamic -fno-stage1 -femit-h zgo.zig
	go build -ldflags "-linkmode external -extldflags -dynamic" bridge.go