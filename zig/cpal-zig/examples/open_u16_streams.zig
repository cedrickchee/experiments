const smoke = @import("stream_smoke_common.zig");

pub fn main(init: @import("std").process.Init) !void {
    try smoke.runDuplexSmoke(u16, .u16, "u16", 32768, init);
}
