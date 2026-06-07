const std = @import("std");
const root = @import("../root.zig");

pub const Host = struct {
    host_id: root.HostId,

    pub fn init(host_id: root.HostId) Host {
        return .{ .host_id = host_id };
    }

    pub fn isAvailable(host_id: root.HostId) bool {
        _ = host_id;
        return false;
    }

    pub fn deinit(self: *Host, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
    }

    pub fn devices(self: Host, allocator: std.mem.Allocator) root.AudioError!DeviceList {
        _ = allocator;
        _ = self;
        return .{ .items = &.{} };
    }

    pub fn defaultOutputDevice(self: Host, allocator: std.mem.Allocator) root.AudioError!?Device {
        _ = allocator;
        _ = self;
        return null;
    }
};

pub const DeviceList = struct {
    items: []Device,

    pub fn deinit(self: *DeviceList, allocator: std.mem.Allocator) void {
        _ = allocator;
        _ = self;
    }
};

pub const Device = struct {
    host_id: root.HostId,
    id_text: []const u8 = "unsupported",
    name_text: []const u8 = "Unsupported backend",
    direction: root.DeviceDirection = .unknown,

    pub fn deinit(self: *Device, allocator: std.mem.Allocator) void {
        _ = allocator;
        _ = self;
    }

    pub fn info(self: Device) root.DeviceInfo {
        return .{
            .host = self.host_id,
            .id = self.id_text,
            .name = self.name_text,
            .direction = self.direction,
        };
    }

    pub fn supportedOutputConfigs(
        self: Device,
        allocator: std.mem.Allocator,
    ) root.AudioError![]root.SupportedStreamConfigRange {
        _ = allocator;
        _ = self;
        return root.AudioError.UnsupportedOperation;
    }

    pub fn defaultOutputConfig(self: Device) root.AudioError!root.SupportedStreamConfig {
        _ = self;
        return root.AudioError.UnsupportedOperation;
    }

    pub fn buildOutputStreamF32(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.OutputCallbackF32,
        userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        _ = self;
        _ = config_value;
        _ = callback;
        _ = userdata;
        return root.AudioError.UnsupportedOperation;
    }
};

pub const Stream = struct {
    pub fn play(self: *Stream) root.AudioError!void {
        _ = self;
        return root.AudioError.UnsupportedOperation;
    }

    pub fn pause(self: *Stream) root.AudioError!void {
        _ = self;
        return root.AudioError.UnsupportedOperation;
    }

    pub fn deinit(self: *Stream) void {
        _ = self;
    }
};
