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
        const items = try allocator.alloc(Device, 2);
        items[0] = try Device.init(allocator, "null:output", "Null Output Device", .output);
        items[1] = try Device.init(allocator, "null:input", "Null Input Device", .input);
        return .{ .items = items };
    }

    pub fn defaultOutputDevice(self: Host, allocator: std.mem.Allocator) root.AudioError!?Device {
        _ = self;
        return try Device.init(allocator, "null:output", "Null Output Device", .output);
    }

    pub fn defaultInputDevice(self: Host, allocator: std.mem.Allocator) root.AudioError!?Device {
        _ = self;
        return try Device.init(allocator, "null:input", "Null Input Device", .input);
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
        if (!self.direction.supportsOutput()) return root.AudioError.UnsupportedOperation;
        return self.makeDefaultConfigs(allocator);
    }

    pub fn supportedInputConfigs(
        self: Device,
        allocator: std.mem.Allocator,
    ) root.AudioError![]root.SupportedStreamConfigRange {
        if (!self.direction.supportsInput()) return root.AudioError.UnsupportedOperation;
        return self.makeDefaultConfigs(allocator);
    }

    pub fn defaultOutputConfig(self: Device) root.AudioError!root.SupportedStreamConfig {
        if (!self.direction.supportsOutput()) return root.AudioError.UnsupportedOperation;
        return defaultF32Config();
    }

    pub fn defaultInputConfig(self: Device) root.AudioError!root.SupportedStreamConfig {
        if (!self.direction.supportsInput()) return root.AudioError.UnsupportedOperation;
        return defaultF32Config();
    }

    fn makeDefaultConfigs(self: Device, allocator: std.mem.Allocator) root.AudioError![]root.SupportedStreamConfigRange {
        _ = self;
        const configs = try allocator.alloc(root.SupportedStreamConfigRange, 2);
        configs[0] = .{
            .channels = 2,
            .min_sample_rate = 44_100,
            .max_sample_rate = 48_000,
            .buffer_size = .{ .range = .{ .min = 64, .max = 4096 } },
            .sample_format = .f32,
        };
        configs[1] = .{
            .channels = 2,
            .min_sample_rate = 44_100,
            .max_sample_rate = 48_000,
            .buffer_size = .{ .range = .{ .min = 64, .max = 4096 } },
            .sample_format = .i16,
        };
        return configs;
    }

    fn defaultF32Config() root.SupportedStreamConfig {
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
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        if (!self.direction.supportsOutput()) return root.AudioError.UnsupportedOperation;
        try config_value.validate();
        return .{
            .direction = .output,
            .config = config_value,
            .callback = .{ .output = callback },
            .userdata = userdata,
            .error_callback = error_callback,
            .error_userdata = error_userdata,
        };
    }

    pub fn buildInputStreamF32(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.InputCallbackF32,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        if (!self.direction.supportsInput()) return root.AudioError.UnsupportedOperation;
        try config_value.validate();
        return .{
            .direction = .input,
            .config = config_value,
            .callback = .{ .input = callback },
            .userdata = userdata,
            .error_callback = error_callback,
            .error_userdata = error_userdata,
        };
    }

    pub fn buildOutputStreamI16(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.OutputCallbackI16,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        if (!self.direction.supportsOutput()) return root.AudioError.UnsupportedOperation;
        try config_value.validate();
        return .{
            .direction = .output,
            .config = config_value,
            .callback = .{ .output_i16 = callback },
            .userdata = userdata,
            .error_callback = error_callback,
            .error_userdata = error_userdata,
        };
    }

    pub fn buildInputStreamI16(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.InputCallbackI16,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        if (!self.direction.supportsInput()) return root.AudioError.UnsupportedOperation;
        try config_value.validate();
        return .{
            .direction = .input,
            .config = config_value,
            .callback = .{ .input_i16 = callback },
            .userdata = userdata,
            .error_callback = error_callback,
            .error_userdata = error_userdata,
        };
    }
};

pub const Stream = struct {
    direction: root.DeviceDirection,
    config: root.StreamConfig,
    callback: union(enum) {
        output: root.OutputCallbackF32,
        input: root.InputCallbackF32,
        output_i16: root.OutputCallbackI16,
        input_i16: root.InputCallbackI16,
    },
    userdata: ?*anyopaque,
    error_callback: ?root.StreamErrorCallback,
    error_userdata: ?*anyopaque,
    played: bool = false,

    pub fn play(self: *Stream) root.AudioError!void {
        const frames: usize = switch (self.config.buffer_size) {
            .default => 128,
            .fixed => |value| value,
        };
        var scratch: [4096]f32 = undefined;
        const samples = @min(scratch.len, frames * self.config.channels);
        @memset(scratch[0..samples], 0);
        const now = root.StreamInstant.nowMonotonic();
        switch (self.callback) {
            .output => |callback| callback(scratch[0..samples], .{
                .callback = now,
                .playback = now,
            }, self.userdata),
            .input => |callback| callback(scratch[0..samples], .{
                .callback = now,
                .capture = now,
            }, self.userdata),
            .output_i16, .input_i16 => self.playI16(frames, now),
        }
        self.played = true;
    }

    fn playI16(self: *Stream, frames: usize, now: root.StreamInstant) void {
        var scratch: [4096]i16 = undefined;
        const samples = @min(scratch.len, frames * self.config.channels);
        @memset(scratch[0..samples], 0);
        switch (self.callback) {
            .output_i16 => |callback| callback(scratch[0..samples], .{
                .callback = now,
                .playback = now,
            }, self.userdata),
            .input_i16 => |callback| callback(scratch[0..samples], .{
                .callback = now,
                .capture = now,
            }, self.userdata),
            else => unreachable,
        }
    }

    pub fn pause(self: *Stream) root.AudioError!void {
        self.played = false;
    }

    pub fn bufferSize(self: *Stream) root.AudioError!u32 {
        return switch (self.config.buffer_size) {
            .default => 128,
            .fixed => |value| value,
        };
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
    }, State.callback, &state, null, null);
    defer output_stream.deinit();

    try output_stream.play();
    try std.testing.expectEqual(@as(usize, 1), state.calls);
}
