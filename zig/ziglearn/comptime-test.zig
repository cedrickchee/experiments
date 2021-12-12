const expect = @import("std").testing.expect;

// ************************************************************************
// Basics
// ************************************************************************

//
// Comptime
// 
// Blocks of code may be forcibly executed at compile time using the
// `comptime` keyword.
//

// The variables x and y are equivalent.
test "comptime blocks" {
    var x = comptime fibonacci(10);
    _ = x;

    var y = comptime blk: {
        break :blk fibonacci(10);
    };
    _ = y;
}


fn fibonacci(n: u16) u16 {
    if (n == 0 or n == 1) return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}

// Integer literals are of the type comptime_int.
// These are special in that they have no size (they cannot be used at
// runtime!), and they have arbitrary precision.
test "comptime_int" {
    const a = 12;
    const b = a + 10;

    const c: u4 = a;
    _ = c;
    const d: f32 = b;
    _ = d;
}

// Types in Zig are values of the type type. These are available at
// compile time.
test "branching on types" {
    const a = 5;
    const b: if (a < 10) f32 else i32 = 5;
    _ = b;
}

// Function parameters in Zig can be tagged as being comptime.
// This means that the value passed to that function parameter must be known
// at compile time.
fn Matrix(
    comptime T: type,
    comptime width: comptime_int,
    comptime height: comptime_int,
) type {
    return [height][width]T;
}

test "returning a type" {
    try expect(Matrix(f32, 4, 4) == [4][4]f32);
}

// We can reflect upon types using the built-in @typeInfo.
test "typeinfo switch" {
    const x = addSmallInts(u16, 20, 30);
    try expect(@TypeOf(x) == u16);
    try expect(x == 50);
}

fn addSmallInts(comptime T: type, a: T, b: T) T {
    return switch (@typeInfo(T)) {
        .ComptimeInt => a + b,
        .Int => |info| if (info.bits <= 16)
            a + b
        else
            @compileError("ints too large"),
        else => @compileError("only ints accepted"),
    };
}

// We can use the @Type function to create a type from a @typeInfo.
test "@Type" {
    try expect(GetBiggerInt(u8) == u9);
    try expect(GetBiggerInt(i31) == i32);
}

fn GetBiggerInt(comptime T: type) type {
    return @Type(.{
        .Int = .{
            .bits = @typeInfo(T).Int.bits + 1,
            .signedness = @typeInfo(T).Int.signedness,
        },
    });
}

// Returning a struct type is how you make generic data structures in Zig.
const eql = @import("std").mem.eql;

test "generic vector" {
    const x = Vec(3, f32).init([_]f32{ 10, -10, 5 });
    const y = x.abs();
    try expect(eql(f32, &y.data, &[_]f32{ 10, 10, 5 }));
}

fn Vec(
    comptime count: comptime_int,
    comptime T: type,
) type {
    return struct {
        data: [count]T,
        const Self = @This();

        fn abs(self: Self) Self {
            var tmp = Self{ .data = undefined };
            for (self.data) |elem, i| {
                tmp.data[i] = if (elem < 0)
                    -elem
                else
                    elem;
            }
            return tmp;
        }

        fn init(data: [count]T) Self {
            return Self{ .data = data };
        }
    };
}

// The types of function parameters can also be inferred by using anytype in
// place of a type.
test "inferred function parameter" {
    try expect(plusOne(@as(u32, 1)) == 2);
}

fn plusOne(x: anytype) @TypeOf(x) {
    return x + 1;
}

// Comptime also introduces the operators ++ and ** for concatenating and
// repeating arrays and slices. These operators do not work at runtime.
test "++" {
    const x: [4]u8 = undefined;
    const y = x[0..];

    const a: [6]u8 = undefined;
    const b = a[0..];

    const new = y ++ b;
    try expect(new.len == 10);
}

test "**" {
    const pattern = [_]u8{ 0xCC, 0xAA };
    const memory = pattern ** 3;
    try expect(eql(
        u8,
        &memory,
        &[_]u8{ 0xCC, 0xAA, 0xCC, 0xAA, 0xCC, 0xAA }
    ));
}