const smoke = @import("stream_smoke_common.zig");

pub fn main(init: @import("std").process.Init) !void {
    try smoke.runDuplexSmoke(u8, .u8, "u8", 128, init);
}
