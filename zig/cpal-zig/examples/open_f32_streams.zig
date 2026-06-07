const smoke = @import("stream_smoke_common.zig");

pub fn main(init: @import("std").process.Init) !void {
    try smoke.runDuplexSmoke(f32, .f32, "f32", 0, init);
}
