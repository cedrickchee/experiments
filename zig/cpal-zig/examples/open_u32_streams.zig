const smoke = @import("stream_smoke_common.zig");

pub fn main(init: @import("std").process.Init) !void {
    try smoke.runDuplexSmoke(u32, .u32, "u32", 0x80000000, init);
}
