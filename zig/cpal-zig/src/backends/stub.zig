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

    pub fn defaultInputDevice(self: Host, allocator: std.mem.Allocator) root.AudioError!?Device {
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
            .description = "Backend extension point is not implemented yet",
            .direction = self.direction,
        };
    }

    pub fn isAvailable(self: Device) bool {
        _ = self;
        return false;
    }

    pub fn supportedOutputConfigs(
        self: Device,
        allocator: std.mem.Allocator,
    ) root.AudioError![]root.SupportedStreamConfigRange {
        _ = allocator;
        _ = self;
        return root.AudioError.UnsupportedOperation;
    }

    pub fn supportedInputConfigs(
        self: Device,
        allocator: std.mem.Allocator,
    ) root.AudioError![]root.SupportedStreamConfigRange {
        _ = allocator;
        _ = self;
        return root.AudioError.UnsupportedOperation;
    }

    pub fn supportedOutputCapabilities(
        self: Device,
        allocator: std.mem.Allocator,
    ) root.AudioError![]root.StreamCapability {
        _ = allocator;
        _ = self;
        return root.AudioError.UnsupportedOperation;
    }

    pub fn supportedInputCapabilities(
        self: Device,
        allocator: std.mem.Allocator,
    ) root.AudioError![]root.StreamCapability {
        _ = allocator;
        _ = self;
        return root.AudioError.UnsupportedOperation;
    }

    pub fn defaultOutputConfig(self: Device) root.AudioError!root.SupportedStreamConfig {
        _ = self;
        return root.AudioError.UnsupportedOperation;
    }

    pub fn defaultInputConfig(self: Device) root.AudioError!root.SupportedStreamConfig {
        _ = self;
        return root.AudioError.UnsupportedOperation;
    }

    pub fn buildOutputStreamF32(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.OutputCallbackF32,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        _ = self;
        _ = config_value;
        _ = callback;
        _ = userdata;
        _ = error_callback;
        _ = error_userdata;
        return root.AudioError.UnsupportedOperation;
    }

    pub fn buildInputStreamF32(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.InputCallbackF32,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        _ = self;
        _ = config_value;
        _ = callback;
        _ = userdata;
        _ = error_callback;
        _ = error_userdata;
        return root.AudioError.UnsupportedOperation;
    }

    pub fn buildOutputStreamI8(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.OutputCallbackI8,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        _ = self;
        _ = config_value;
        _ = callback;
        _ = userdata;
        _ = error_callback;
        _ = error_userdata;
        return root.AudioError.UnsupportedOperation;
    }

    pub fn buildInputStreamI8(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.InputCallbackI8,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        _ = self;
        _ = config_value;
        _ = callback;
        _ = userdata;
        _ = error_callback;
        _ = error_userdata;
        return root.AudioError.UnsupportedOperation;
    }

    pub fn buildOutputStreamU8(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.OutputCallbackU8,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        _ = self;
        _ = config_value;
        _ = callback;
        _ = userdata;
        _ = error_callback;
        _ = error_userdata;
        return root.AudioError.UnsupportedOperation;
    }

    pub fn buildInputStreamU8(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.InputCallbackU8,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        _ = self;
        _ = config_value;
        _ = callback;
        _ = userdata;
        _ = error_callback;
        _ = error_userdata;
        return root.AudioError.UnsupportedOperation;
    }

    pub fn buildOutputStreamI16(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.OutputCallbackI16,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        _ = self;
        _ = config_value;
        _ = callback;
        _ = userdata;
        _ = error_callback;
        _ = error_userdata;
        return root.AudioError.UnsupportedOperation;
    }

    pub fn buildInputStreamI16(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.InputCallbackI16,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        _ = self;
        _ = config_value;
        _ = callback;
        _ = userdata;
        _ = error_callback;
        _ = error_userdata;
        return root.AudioError.UnsupportedOperation;
    }

    pub fn buildOutputStreamU16(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.OutputCallbackU16,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        _ = self;
        _ = config_value;
        _ = callback;
        _ = userdata;
        _ = error_callback;
        _ = error_userdata;
        return root.AudioError.UnsupportedOperation;
    }

    pub fn buildInputStreamU16(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.InputCallbackU16,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        _ = self;
        _ = config_value;
        _ = callback;
        _ = userdata;
        _ = error_callback;
        _ = error_userdata;
        return root.AudioError.UnsupportedOperation;
    }

    pub fn buildOutputStreamI32(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.OutputCallbackI32,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        _ = self;
        _ = config_value;
        _ = callback;
        _ = userdata;
        _ = error_callback;
        _ = error_userdata;
        return root.AudioError.UnsupportedOperation;
    }

    pub fn buildInputStreamI32(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.InputCallbackI32,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        _ = self;
        _ = config_value;
        _ = callback;
        _ = userdata;
        _ = error_callback;
        _ = error_userdata;
        return root.AudioError.UnsupportedOperation;
    }

    pub fn buildOutputStreamU32(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.OutputCallbackU32,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        _ = self;
        _ = config_value;
        _ = callback;
        _ = userdata;
        _ = error_callback;
        _ = error_userdata;
        return root.AudioError.UnsupportedOperation;
    }

    pub fn buildInputStreamU32(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.InputCallbackU32,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        _ = self;
        _ = config_value;
        _ = callback;
        _ = userdata;
        _ = error_callback;
        _ = error_userdata;
        return root.AudioError.UnsupportedOperation;
    }

    pub fn buildOutputStreamF64(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.OutputCallbackF64,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        _ = self;
        _ = config_value;
        _ = callback;
        _ = userdata;
        _ = error_callback;
        _ = error_userdata;
        return root.AudioError.UnsupportedOperation;
    }

    pub fn buildInputStreamF64(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.InputCallbackF64,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        _ = self;
        _ = config_value;
        _ = callback;
        _ = userdata;
        _ = error_callback;
        _ = error_userdata;
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

    pub fn drain(self: *Stream) root.AudioError!void {
        _ = self;
        return root.AudioError.UnsupportedOperation;
    }

    pub fn isRunning(self: *Stream) bool {
        _ = self;
        return false;
    }

    pub fn status(self: *Stream) root.StreamRunStatus {
        _ = self;
        return .unsupported_operation;
    }

    pub fn bufferSize(self: *Stream) root.AudioError!u32 {
        _ = self;
        return root.AudioError.UnsupportedOperation;
    }

    pub fn diagnostics(self: *Stream) root.AudioError!root.StreamDiagnostics {
        _ = self;
        return root.AudioError.UnsupportedOperation;
    }

    pub fn deinit(self: *Stream) void {
        _ = self;
    }
};
