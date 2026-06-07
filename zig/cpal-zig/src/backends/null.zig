const std = @import("std");
const root = @import("../root.zig");

pub const Host = struct {
    pub fn init() Host {
        return .{};
    }

    pub fn isAvailable() bool {
        return true;
    }

    pub fn deinit(self: *Host, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
    }

    pub fn devices(self: Host, allocator: std.mem.Allocator) root.AudioError!DeviceList {
        _ = self;
        const items = try allocator.alloc(Device, 1);
        items[0] = try Device.init(allocator, "null:default", "Null Output Device", .output);
        return .{ .items = items };
    }

    pub fn defaultOutputDevice(self: Host, allocator: std.mem.Allocator) root.AudioError!?Device {
        _ = self;
        return try Device.init(allocator, "null:default", "Null Output Device", .output);
    }
};

pub const DeviceList = struct {
    items: []Device,

    pub fn deinit(self: *DeviceList, allocator: std.mem.Allocator) void {
        for (self.items) |*device| device.deinit(allocator);
        allocator.free(self.items);
    }
};

pub const Device = struct {
    id_text: []const u8,
    name_text: []const u8,
    direction: root.DeviceDirection,

    pub fn init(
        allocator: std.mem.Allocator,
        id_text: []const u8,
        name_text: []const u8,
        direction: root.DeviceDirection,
    ) root.AudioError!Device {
        return .{
            .id_text = try allocator.dupe(u8, id_text),
            .name_text = try allocator.dupe(u8, name_text),
            .direction = direction,
        };
    }

    pub fn deinit(self: *Device, allocator: std.mem.Allocator) void {
        allocator.free(self.id_text);
        allocator.free(self.name_text);
    }

    pub fn info(self: Device) root.DeviceInfo {
        return .{
            .host = .null,
            .id = self.id_text,
            .name = self.name_text,
            .direction = self.direction,
        };
    }

    pub fn supportedOutputConfigs(
        self: Device,
        allocator: std.mem.Allocator,
    ) root.AudioError![]root.SupportedStreamConfigRange {
        _ = self;
        const configs = try allocator.alloc(root.SupportedStreamConfigRange, 1);
        configs[0] = .{
            .channels = 2,
            .min_sample_rate = 44_100,
            .max_sample_rate = 48_000,
            .buffer_size = .{ .range = .{ .min = 64, .max = 4096 } },
            .sample_format = .f32,
        };
        return configs;
    }

    pub fn defaultOutputConfig(self: Device) root.AudioError!root.SupportedStreamConfig {
        _ = self;
        return .{
            .channels = 2,
            .sample_rate = 48_000,
            .buffer_size = .{ .range = .{ .min = 64, .max = 4096 } },
            .sample_format = .f32,
        };
    }

    pub fn buildOutputStreamF32(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.OutputCallbackF32,
        userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        _ = self;
        try config_value.validate();
        return .{
            .config = config_value,
            .callback = callback,
            .userdata = userdata,
        };
    }
};

pub const Stream = struct {
    config: root.StreamConfig,
    callback: root.OutputCallbackF32,
    userdata: ?*anyopaque,
    played: bool = false,

    pub fn play(self: *Stream) root.AudioError!void {
        const frames: usize = switch (self.config.buffer_size) {
            .default => 128,
            .fixed => |value| value,
        };
        var scratch: [4096]f32 = undefined;
        const samples = @min(scratch.len, frames * self.config.channels);
        @memset(scratch[0..samples], 0);
        self.callback(scratch[0..samples], .{
            .callback = root.StreamInstant.nowMonotonic(),
            .playback = root.StreamInstant.nowMonotonic(),
        }, self.userdata);
        self.played = true;
    }

    pub fn pause(self: *Stream) root.AudioError!void {
        self.played = false;
    }

    pub fn deinit(self: *Stream) void {
        _ = self;
    }
};

test "null backend can build and play a callback stream" {
    const allocator = std.testing.allocator;
    var host = Host.init();
    defer host.deinit(allocator);
    var device = (try host.defaultOutputDevice(allocator)).?;
    defer device.deinit(allocator);

    const State = struct {
        calls: usize = 0,

        fn callback(buffer: []f32, info: root.OutputCallbackInfo, userdata: ?*anyopaque) void {
            _ = info;
            const state: *@This() = @ptrCast(@alignCast(userdata.?));
            state.calls += 1;
            @memset(buffer, 0);
        }
    };

    var state = State{};
    var output_stream = try device.buildOutputStreamF32(.{
        .channels = 2,
        .sample_rate = 48_000,
    }, State.callback, &state);
    defer output_stream.deinit();

    try output_stream.play();
    try std.testing.expectEqual(@as(usize, 1), state.calls);
}
