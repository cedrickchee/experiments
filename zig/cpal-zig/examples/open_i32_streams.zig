const smoke = @import("stream_smoke_common.zig");

pub fn main(init: @import("std").process.Init) !void {
    try smoke.runDuplexSmoke(i32, .i32, "i32", 0, init);
}
