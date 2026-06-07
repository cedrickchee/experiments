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
    description_text: []const u8,
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
            .description_text = try allocator.dupe(u8, "Synthetic in-memory audio endpoint"),
            .direction = direction,
        };
    }

    pub fn deinit(self: *Device, allocator: std.mem.Allocator) void {
        allocator.free(self.id_text);
        allocator.free(self.name_text);
        allocator.free(self.description_text);
    }

    pub fn info(self: Device) root.DeviceInfo {
        return .{
            .host = .null,
            .id = self.id_text,
            .name = self.name_text,
            .description = self.description_text,
            .direction = self.direction,
        };
    }

    pub fn description(self: Device) root.DeviceDescription {
        return .{
            .host = .null,
            .id = self.id_text,
            .name = self.name_text,
            .driver = "cpal-zig null",
            .device_type = .virtual,
            .interface_type = .virtual,
            .direction = self.direction,
            .address = self.id_text,
            .extended = self.description_text,
        };
    }

    pub fn isAvailable(self: Device) bool {
        _ = self;
        return true;
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

    pub fn supportedOutputCapabilities(
        self: Device,
        allocator: std.mem.Allocator,
    ) root.AudioError![]root.StreamCapability {
        if (!self.direction.supportsOutput()) return root.AudioError.UnsupportedOperation;
        return self.makeDefaultCapabilities(allocator, .output);
    }

    pub fn supportedInputCapabilities(
        self: Device,
        allocator: std.mem.Allocator,
    ) root.AudioError![]root.StreamCapability {
        if (!self.direction.supportsInput()) return root.AudioError.UnsupportedOperation;
        return self.makeDefaultCapabilities(allocator, .input);
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
        const configs = try allocator.alloc(root.SupportedStreamConfigRange, 10);
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
            .sample_format = .i8,
        };
        configs[2] = .{
            .channels = 2,
            .min_sample_rate = 44_100,
            .max_sample_rate = 48_000,
            .buffer_size = .{ .range = .{ .min = 64, .max = 4096 } },
            .sample_format = .u8,
        };
        configs[3] = .{
            .channels = 2,
            .min_sample_rate = 44_100,
            .max_sample_rate = 48_000,
            .buffer_size = .{ .range = .{ .min = 64, .max = 4096 } },
            .sample_format = .i16,
        };
        configs[4] = .{
            .channels = 2,
            .min_sample_rate = 44_100,
            .max_sample_rate = 48_000,
            .buffer_size = .{ .range = .{ .min = 64, .max = 4096 } },
            .sample_format = .u16,
        };
        configs[5] = .{
            .channels = 2,
            .min_sample_rate = 44_100,
            .max_sample_rate = 48_000,
            .buffer_size = .{ .range = .{ .min = 64, .max = 4096 } },
            .sample_format = .i24,
        };
        configs[6] = .{
            .channels = 2,
            .min_sample_rate = 44_100,
            .max_sample_rate = 48_000,
            .buffer_size = .{ .range = .{ .min = 64, .max = 4096 } },
            .sample_format = .u24,
        };
        configs[7] = .{
            .channels = 2,
            .min_sample_rate = 44_100,
            .max_sample_rate = 48_000,
            .buffer_size = .{ .range = .{ .min = 64, .max = 4096 } },
            .sample_format = .i32,
        };
        configs[8] = .{
            .channels = 2,
            .min_sample_rate = 44_100,
            .max_sample_rate = 48_000,
            .buffer_size = .{ .range = .{ .min = 64, .max = 4096 } },
            .sample_format = .u32,
        };
        configs[9] = .{
            .channels = 2,
            .min_sample_rate = 44_100,
            .max_sample_rate = 48_000,
            .buffer_size = .{ .range = .{ .min = 64, .max = 4096 } },
            .sample_format = .f64,
        };
        return configs;
    }

    fn makeDefaultCapabilities(
        self: Device,
        allocator: std.mem.Allocator,
        direction: root.StreamCapabilityDirection,
    ) root.AudioError![]root.StreamCapability {
        _ = self;
        const capabilities = try allocator.alloc(root.StreamCapability, 10);
        capabilities[0] = .{
            .direction = direction,
            .sample_format = .f32,
            .channels = .{ .min = 1, .max = 2 },
            .min_sample_rate = 44_100,
            .max_sample_rate = 48_000,
            .buffer_size = .{ .range = .{ .min = 64, .max = 4096 } },
            .total_buffer_size = .{ .range = .{ .min = 256, .max = 16_384 } },
        };
        capabilities[1] = .{
            .direction = direction,
            .sample_format = .i8,
            .channels = .{ .min = 1, .max = 2 },
            .min_sample_rate = 44_100,
            .max_sample_rate = 48_000,
            .buffer_size = .{ .range = .{ .min = 64, .max = 4096 } },
            .total_buffer_size = .{ .range = .{ .min = 256, .max = 16_384 } },
        };
        capabilities[2] = .{
            .direction = direction,
            .sample_format = .u8,
            .channels = .{ .min = 1, .max = 2 },
            .min_sample_rate = 44_100,
            .max_sample_rate = 48_000,
            .buffer_size = .{ .range = .{ .min = 64, .max = 4096 } },
            .total_buffer_size = .{ .range = .{ .min = 256, .max = 16_384 } },
        };
        capabilities[3] = .{
            .direction = direction,
            .sample_format = .i16,
            .channels = .{ .min = 1, .max = 2 },
            .min_sample_rate = 44_100,
            .max_sample_rate = 48_000,
            .buffer_size = .{ .range = .{ .min = 64, .max = 4096 } },
            .total_buffer_size = .{ .range = .{ .min = 256, .max = 16_384 } },
        };
        capabilities[4] = .{
            .direction = direction,
            .sample_format = .u16,
            .channels = .{ .min = 1, .max = 2 },
            .min_sample_rate = 44_100,
            .max_sample_rate = 48_000,
            .buffer_size = .{ .range = .{ .min = 64, .max = 4096 } },
            .total_buffer_size = .{ .range = .{ .min = 256, .max = 16_384 } },
        };
        capabilities[5] = .{
            .direction = direction,
            .sample_format = .i24,
            .channels = .{ .min = 1, .max = 2 },
            .min_sample_rate = 44_100,
            .max_sample_rate = 48_000,
            .buffer_size = .{ .range = .{ .min = 64, .max = 4096 } },
            .total_buffer_size = .{ .range = .{ .min = 256, .max = 16_384 } },
        };
        capabilities[6] = .{
            .direction = direction,
            .sample_format = .u24,
            .channels = .{ .min = 1, .max = 2 },
            .min_sample_rate = 44_100,
            .max_sample_rate = 48_000,
            .buffer_size = .{ .range = .{ .min = 64, .max = 4096 } },
            .total_buffer_size = .{ .range = .{ .min = 256, .max = 16_384 } },
        };
        capabilities[7] = .{
            .direction = direction,
            .sample_format = .i32,
            .channels = .{ .min = 1, .max = 2 },
            .min_sample_rate = 44_100,
            .max_sample_rate = 48_000,
            .buffer_size = .{ .range = .{ .min = 64, .max = 4096 } },
            .total_buffer_size = .{ .range = .{ .min = 256, .max = 16_384 } },
        };
        capabilities[8] = .{
            .direction = direction,
            .sample_format = .u32,
            .channels = .{ .min = 1, .max = 2 },
            .min_sample_rate = 44_100,
            .max_sample_rate = 48_000,
            .buffer_size = .{ .range = .{ .min = 64, .max = 4096 } },
            .total_buffer_size = .{ .range = .{ .min = 256, .max = 16_384 } },
        };
        capabilities[9] = .{
            .direction = direction,
            .sample_format = .f64,
            .channels = .{ .min = 1, .max = 2 },
            .min_sample_rate = 44_100,
            .max_sample_rate = 48_000,
            .buffer_size = .{ .range = .{ .min = 64, .max = 4096 } },
            .total_buffer_size = .{ .range = .{ .min = 256, .max = 16_384 } },
        };
        return capabilities;
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

    pub fn buildOutputStreamI8(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.OutputCallbackI8,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        if (!self.direction.supportsOutput()) return root.AudioError.UnsupportedOperation;
        try config_value.validate();
        return .{
            .direction = .output,
            .config = config_value,
            .callback = .{ .output_i8 = callback },
            .userdata = userdata,
            .error_callback = error_callback,
            .error_userdata = error_userdata,
        };
    }

    pub fn buildInputStreamI8(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.InputCallbackI8,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        if (!self.direction.supportsInput()) return root.AudioError.UnsupportedOperation;
        try config_value.validate();
        return .{
            .direction = .input,
            .config = config_value,
            .callback = .{ .input_i8 = callback },
            .userdata = userdata,
            .error_callback = error_callback,
            .error_userdata = error_userdata,
        };
    }

    pub fn buildOutputStreamU8(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.OutputCallbackU8,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        if (!self.direction.supportsOutput()) return root.AudioError.UnsupportedOperation;
        try config_value.validate();
        return .{
            .direction = .output,
            .config = config_value,
            .callback = .{ .output_u8 = callback },
            .userdata = userdata,
            .error_callback = error_callback,
            .error_userdata = error_userdata,
        };
    }

    pub fn buildInputStreamU8(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.InputCallbackU8,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        if (!self.direction.supportsInput()) return root.AudioError.UnsupportedOperation;
        try config_value.validate();
        return .{
            .direction = .input,
            .config = config_value,
            .callback = .{ .input_u8 = callback },
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

    pub fn buildOutputStreamU16(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.OutputCallbackU16,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        if (!self.direction.supportsOutput()) return root.AudioError.UnsupportedOperation;
        try config_value.validate();
        return .{
            .direction = .output,
            .config = config_value,
            .callback = .{ .output_u16 = callback },
            .userdata = userdata,
            .error_callback = error_callback,
            .error_userdata = error_userdata,
        };
    }

    pub fn buildInputStreamU16(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.InputCallbackU16,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        if (!self.direction.supportsInput()) return root.AudioError.UnsupportedOperation;
        try config_value.validate();
        return .{
            .direction = .input,
            .config = config_value,
            .callback = .{ .input_u16 = callback },
            .userdata = userdata,
            .error_callback = error_callback,
            .error_userdata = error_userdata,
        };
    }

    pub fn buildOutputStreamI24(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.OutputCallbackI24,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        if (!self.direction.supportsOutput()) return root.AudioError.UnsupportedOperation;
        try config_value.validate();
        return .{
            .direction = .output,
            .config = config_value,
            .callback = .{ .output_i24 = callback },
            .userdata = userdata,
            .error_callback = error_callback,
            .error_userdata = error_userdata,
        };
    }

    pub fn buildInputStreamI24(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.InputCallbackI24,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        if (!self.direction.supportsInput()) return root.AudioError.UnsupportedOperation;
        try config_value.validate();
        return .{
            .direction = .input,
            .config = config_value,
            .callback = .{ .input_i24 = callback },
            .userdata = userdata,
            .error_callback = error_callback,
            .error_userdata = error_userdata,
        };
    }

    pub fn buildOutputStreamU24(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.OutputCallbackU24,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        if (!self.direction.supportsOutput()) return root.AudioError.UnsupportedOperation;
        try config_value.validate();
        return .{
            .direction = .output,
            .config = config_value,
            .callback = .{ .output_u24 = callback },
            .userdata = userdata,
            .error_callback = error_callback,
            .error_userdata = error_userdata,
        };
    }

    pub fn buildInputStreamU24(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.InputCallbackU24,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        if (!self.direction.supportsInput()) return root.AudioError.UnsupportedOperation;
        try config_value.validate();
        return .{
            .direction = .input,
            .config = config_value,
            .callback = .{ .input_u24 = callback },
            .userdata = userdata,
            .error_callback = error_callback,
            .error_userdata = error_userdata,
        };
    }

    pub fn buildOutputStreamI32(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.OutputCallbackI32,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        if (!self.direction.supportsOutput()) return root.AudioError.UnsupportedOperation;
        try config_value.validate();
        return .{
            .direction = .output,
            .config = config_value,
            .callback = .{ .output_i32 = callback },
            .userdata = userdata,
            .error_callback = error_callback,
            .error_userdata = error_userdata,
        };
    }

    pub fn buildInputStreamI32(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.InputCallbackI32,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        if (!self.direction.supportsInput()) return root.AudioError.UnsupportedOperation;
        try config_value.validate();
        return .{
            .direction = .input,
            .config = config_value,
            .callback = .{ .input_i32 = callback },
            .userdata = userdata,
            .error_callback = error_callback,
            .error_userdata = error_userdata,
        };
    }

    pub fn buildOutputStreamU32(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.OutputCallbackU32,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        if (!self.direction.supportsOutput()) return root.AudioError.UnsupportedOperation;
        try config_value.validate();
        return .{
            .direction = .output,
            .config = config_value,
            .callback = .{ .output_u32 = callback },
            .userdata = userdata,
            .error_callback = error_callback,
            .error_userdata = error_userdata,
        };
    }

    pub fn buildInputStreamU32(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.InputCallbackU32,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        if (!self.direction.supportsInput()) return root.AudioError.UnsupportedOperation;
        try config_value.validate();
        return .{
            .direction = .input,
            .config = config_value,
            .callback = .{ .input_u32 = callback },
            .userdata = userdata,
            .error_callback = error_callback,
            .error_userdata = error_userdata,
        };
    }

    pub fn buildOutputStreamF64(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.OutputCallbackF64,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        if (!self.direction.supportsOutput()) return root.AudioError.UnsupportedOperation;
        try config_value.validate();
        return .{
            .direction = .output,
            .config = config_value,
            .callback = .{ .output_f64 = callback },
            .userdata = userdata,
            .error_callback = error_callback,
            .error_userdata = error_userdata,
        };
    }

    pub fn buildInputStreamF64(
        self: Device,
        config_value: root.StreamConfig,
        callback: root.InputCallbackF64,
        userdata: ?*anyopaque,
        error_callback: ?root.StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) root.AudioError!Stream {
        if (!self.direction.supportsInput()) return root.AudioError.UnsupportedOperation;
        try config_value.validate();
        return .{
            .direction = .input,
            .config = config_value,
            .callback = .{ .input_f64 = callback },
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
        output_i8: root.OutputCallbackI8,
        input_i8: root.InputCallbackI8,
        output_u8: root.OutputCallbackU8,
        input_u8: root.InputCallbackU8,
        output_i16: root.OutputCallbackI16,
        input_i16: root.InputCallbackI16,
        output_u16: root.OutputCallbackU16,
        input_u16: root.InputCallbackU16,
        output_i24: root.OutputCallbackI24,
        input_i24: root.InputCallbackI24,
        output_u24: root.OutputCallbackU24,
        input_u24: root.InputCallbackU24,
        output_i32: root.OutputCallbackI32,
        input_i32: root.InputCallbackI32,
        output_u32: root.OutputCallbackU32,
        input_u32: root.InputCallbackU32,
        output_f64: root.OutputCallbackF64,
        input_f64: root.InputCallbackF64,
    },
    userdata: ?*anyopaque,
    error_callback: ?root.StreamErrorCallback,
    error_userdata: ?*anyopaque,
    played: bool = false,
    callback_count: u64 = 0,

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
            .output_i8, .input_i8 => self.playI8(frames, now),
            .output_u8, .input_u8 => self.playU8(frames, now),
            .output_i16, .input_i16 => self.playI16(frames, now),
            .output_u16, .input_u16 => self.playU16(frames, now),
            .output_i24, .input_i24 => self.playI24(frames, now),
            .output_u24, .input_u24 => self.playU24(frames, now),
            .output_i32, .input_i32 => self.playI32(frames, now),
            .output_u32, .input_u32 => self.playU32(frames, now),
            .output_f64, .input_f64 => self.playF64(frames, now),
        }
        self.played = true;
        self.callback_count += 1;
    }

    fn playI8(self: *Stream, frames: usize, now: root.StreamInstant) void {
        var scratch: [4096]i8 = undefined;
        const samples = @min(scratch.len, frames * self.config.channels);
        @memset(scratch[0..samples], 0);
        switch (self.callback) {
            .output_i8 => |callback| callback(scratch[0..samples], .{
                .callback = now,
                .playback = now,
            }, self.userdata),
            .input_i8 => |callback| callback(scratch[0..samples], .{
                .callback = now,
                .capture = now,
            }, self.userdata),
            else => unreachable,
        }
    }

    fn playU8(self: *Stream, frames: usize, now: root.StreamInstant) void {
        var scratch: [4096]u8 = undefined;
        const samples = @min(scratch.len, frames * self.config.channels);
        @memset(scratch[0..samples], 128);
        switch (self.callback) {
            .output_u8 => |callback| callback(scratch[0..samples], .{
                .callback = now,
                .playback = now,
            }, self.userdata),
            .input_u8 => |callback| callback(scratch[0..samples], .{
                .callback = now,
                .capture = now,
            }, self.userdata),
            else => unreachable,
        }
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

    fn playU16(self: *Stream, frames: usize, now: root.StreamInstant) void {
        var scratch: [4096]u16 = undefined;
        const samples = @min(scratch.len, frames * self.config.channels);
        @memset(scratch[0..samples], 32768);
        switch (self.callback) {
            .output_u16 => |callback| callback(scratch[0..samples], .{
                .callback = now,
                .playback = now,
            }, self.userdata),
            .input_u16 => |callback| callback(scratch[0..samples], .{
                .callback = now,
                .capture = now,
            }, self.userdata),
            else => unreachable,
        }
    }

    fn playI24(self: *Stream, frames: usize, now: root.StreamInstant) void {
        var scratch: [4096]i24 = undefined;
        const samples = @min(scratch.len, frames * self.config.channels);
        @memset(scratch[0..samples], 0);
        switch (self.callback) {
            .output_i24 => |callback| callback(scratch[0..samples], .{
                .callback = now,
                .playback = now,
            }, self.userdata),
            .input_i24 => |callback| callback(scratch[0..samples], .{
                .callback = now,
                .capture = now,
            }, self.userdata),
            else => unreachable,
        }
    }

    fn playU24(self: *Stream, frames: usize, now: root.StreamInstant) void {
        var scratch: [4096]u24 = undefined;
        const samples = @min(scratch.len, frames * self.config.channels);
        @memset(scratch[0..samples], 0x800000);
        switch (self.callback) {
            .output_u24 => |callback| callback(scratch[0..samples], .{
                .callback = now,
                .playback = now,
            }, self.userdata),
            .input_u24 => |callback| callback(scratch[0..samples], .{
                .callback = now,
                .capture = now,
            }, self.userdata),
            else => unreachable,
        }
    }

    fn playI32(self: *Stream, frames: usize, now: root.StreamInstant) void {
        var scratch: [4096]i32 = undefined;
        const samples = @min(scratch.len, frames * self.config.channels);
        @memset(scratch[0..samples], 0);
        switch (self.callback) {
            .output_i32 => |callback| callback(scratch[0..samples], .{
                .callback = now,
                .playback = now,
            }, self.userdata),
            .input_i32 => |callback| callback(scratch[0..samples], .{
                .callback = now,
                .capture = now,
            }, self.userdata),
            else => unreachable,
        }
    }

    fn playU32(self: *Stream, frames: usize, now: root.StreamInstant) void {
        var scratch: [4096]u32 = undefined;
        const samples = @min(scratch.len, frames * self.config.channels);
        @memset(scratch[0..samples], 0x80000000);
        switch (self.callback) {
            .output_u32 => |callback| callback(scratch[0..samples], .{
                .callback = now,
                .playback = now,
            }, self.userdata),
            .input_u32 => |callback| callback(scratch[0..samples], .{
                .callback = now,
                .capture = now,
            }, self.userdata),
            else => unreachable,
        }
    }

    fn playF64(self: *Stream, frames: usize, now: root.StreamInstant) void {
        var scratch: [4096]f64 = undefined;
        const samples = @min(scratch.len, frames * self.config.channels);
        @memset(scratch[0..samples], 0);
        switch (self.callback) {
            .output_f64 => |callback| callback(scratch[0..samples], .{
                .callback = now,
                .playback = now,
            }, self.userdata),
            .input_f64 => |callback| callback(scratch[0..samples], .{
                .callback = now,
                .capture = now,
            }, self.userdata),
            else => unreachable,
        }
    }

    pub fn pause(self: *Stream) root.AudioError!void {
        self.played = false;
    }

    pub fn drain(self: *Stream) root.AudioError!void {
        self.played = false;
    }

    pub fn isRunning(self: *Stream) bool {
        return self.played;
    }

    pub fn status(self: *Stream) root.StreamRunStatus {
        return if (self.played) .running else .stopped;
    }

    pub fn bufferSize(self: *Stream) root.AudioError!u32 {
        return switch (self.config.buffer_size) {
            .default => 128,
            .fixed => |value| value,
        };
    }

    pub fn diagnostics(self: *Stream) root.AudioError!root.StreamDiagnostics {
        const available_frames = try self.bufferSize();
        return .{
            .timestamp = root.StreamInstant.nowMonotonic(),
            .timestamp_status = .estimated,
            .run_status = self.status(),
            .backend_state = if (self.played) .running else .setup,
            .buffer_size_frames = available_frames,
            .period_size_frames = available_frames,
            .avail_min_frames = available_frames,
            .start_threshold_frames = available_frames,
            .available_frames = available_frames,
            .available_max_frames = available_frames,
            .available_duration_ns = root.framesToUnsignedDurationNs(available_frames, self.config.sample_rate),
            .delay_frames = 0,
            .delay_duration_ns = root.framesToDurationNs(0, self.config.sample_rate),
            .latency_duration_ns = root.nonNegativeFramesToDurationNs(0, self.config.sample_rate),
            .overrange_frames = 0,
            .latency_status = .estimated,
            .scheduling_status = .unsupported,
            .callback_count = self.callback_count,
            .stream_error_count = 0,
            .xrun_count = 0,
            .recovery_count = 0,
            .expected_callback_interval_ns = root.framesToUnsignedDurationNs(available_frames, self.config.sample_rate),
            .last_callback_interval_ns = null,
            .last_callback_drift_ns = null,
            .max_callback_interval_ns = null,
            .max_callback_drift_abs_ns = null,
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
