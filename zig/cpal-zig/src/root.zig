const std = @import("std");
const builtin = @import("builtin");

pub const config = @import("config.zig");
pub const stream = @import("stream.zig");
pub const backends = @import("backends/root.zig");

pub const SampleFormat = config.SampleFormat;
pub const BufferSize = config.BufferSize;
pub const SupportedBufferSize = config.SupportedBufferSize;
pub const StreamConfig = config.StreamConfig;
pub const SupportedStreamConfig = config.SupportedStreamConfig;
pub const SupportedStreamConfigRange = config.SupportedStreamConfigRange;
pub const StreamInstant = stream.StreamInstant;
pub const OutputCallbackInfo = stream.OutputCallbackInfo;
pub const InputCallbackInfo = stream.InputCallbackInfo;
pub const OutputCallbackF32 = stream.OutputCallbackF32;
pub const InputCallbackF32 = stream.InputCallbackF32;
pub const StreamErrorCallback = stream.StreamErrorCallback;

pub const AudioError = error{
    BackendUnavailable,
    BackendError,
    DeviceBusy,
    DeviceNotAvailable,
    InvalidInput,
    OutOfMemory,
    PermissionDenied,
    ResourceExhausted,
    StreamInvalidated,
    UnsupportedConfig,
    UnsupportedOperation,
    Xrun,
};

pub const HostId = enum {
    alsa,
    coreaudio,
    wasapi,
    jack,
    pulseaudio,
    null,

    pub fn name(self: HostId) []const u8 {
        return switch (self) {
            .alsa => "ALSA",
            .coreaudio => "CoreAudio",
            .wasapi => "WASAPI",
            .jack => "JACK",
            .pulseaudio => "PulseAudio",
            .null => "Null",
        };
    }

    pub fn stableName(self: HostId) []const u8 {
        return switch (self) {
            .alsa => "alsa",
            .coreaudio => "coreaudio",
            .wasapi => "wasapi",
            .jack => "jack",
            .pulseaudio => "pulseaudio",
            .null => "null",
        };
    }
};

pub const DeviceDirection = enum {
    input,
    output,
    duplex,
    unknown,

    pub fn supportsInput(self: DeviceDirection) bool {
        return self == .input or self == .duplex or self == .unknown;
    }

    pub fn supportsOutput(self: DeviceDirection) bool {
        return self == .output or self == .duplex or self == .unknown;
    }
};

pub const DeviceInfo = struct {
    host: HostId,
    id: []const u8,
    name: []const u8,
    direction: DeviceDirection,
};

pub const Device = union(HostId) {
    alsa: backends.alsa.Device,
    coreaudio: backends.stub.Device,
    wasapi: backends.stub.Device,
    jack: backends.stub.Device,
    pulseaudio: backends.stub.Device,
    null: backends.null_backend.Device,

    pub fn deinit(self: *Device, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .alsa => |*device| device.deinit(allocator),
            .coreaudio, .wasapi, .jack, .pulseaudio => |*device| device.deinit(allocator),
            .null => |*device| device.deinit(allocator),
        }
    }

    pub fn info(self: Device) DeviceInfo {
        return switch (self) {
            .alsa => |device| device.info(),
            .coreaudio, .wasapi, .jack, .pulseaudio => |device| device.info(),
            .null => |device| device.info(),
        };
    }

    pub fn supportedOutputConfigs(
        self: Device,
        allocator: std.mem.Allocator,
    ) AudioError![]SupportedStreamConfigRange {
        return switch (self) {
            .alsa => |device| device.supportedOutputConfigs(allocator),
            .coreaudio, .wasapi, .jack, .pulseaudio => |device| device.supportedOutputConfigs(allocator),
            .null => |device| device.supportedOutputConfigs(allocator),
        };
    }

    pub fn supportedInputConfigs(
        self: Device,
        allocator: std.mem.Allocator,
    ) AudioError![]SupportedStreamConfigRange {
        return switch (self) {
            .alsa => |device| device.supportedInputConfigs(allocator),
            .coreaudio, .wasapi, .jack, .pulseaudio => |device| device.supportedInputConfigs(allocator),
            .null => |device| device.supportedInputConfigs(allocator),
        };
    }

    pub fn defaultOutputConfig(self: Device) AudioError!SupportedStreamConfig {
        return switch (self) {
            .alsa => |device| device.defaultOutputConfig(),
            .coreaudio, .wasapi, .jack, .pulseaudio => |device| device.defaultOutputConfig(),
            .null => |device| device.defaultOutputConfig(),
        };
    }

    pub fn defaultInputConfig(self: Device) AudioError!SupportedStreamConfig {
        return switch (self) {
            .alsa => |device| device.defaultInputConfig(),
            .coreaudio, .wasapi, .jack, .pulseaudio => |device| device.defaultInputConfig(),
            .null => |device| device.defaultInputConfig(),
        };
    }

    pub fn buildOutputStreamF32(
        self: Device,
        config_value: StreamConfig,
        callback: OutputCallbackF32,
        userdata: ?*anyopaque,
        error_callback: ?StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) AudioError!stream.Stream {
        return switch (self) {
            .alsa => |device| .{ .alsa = try device.buildOutputStreamF32(config_value, callback, userdata, error_callback, error_userdata) },
            .coreaudio, .wasapi, .jack, .pulseaudio => |device| .{ .stub = try device.buildOutputStreamF32(config_value, callback, userdata, error_callback, error_userdata) },
            .null => |device| .{ .null = try device.buildOutputStreamF32(config_value, callback, userdata, error_callback, error_userdata) },
        };
    }

    pub fn buildInputStreamF32(
        self: Device,
        config_value: StreamConfig,
        callback: InputCallbackF32,
        userdata: ?*anyopaque,
        error_callback: ?StreamErrorCallback,
        error_userdata: ?*anyopaque,
    ) AudioError!stream.Stream {
        return switch (self) {
            .alsa => |device| .{ .alsa = try device.buildInputStreamF32(config_value, callback, userdata, error_callback, error_userdata) },
            .coreaudio, .wasapi, .jack, .pulseaudio => |device| .{ .stub = try device.buildInputStreamF32(config_value, callback, userdata, error_callback, error_userdata) },
            .null => |device| .{ .null = try device.buildInputStreamF32(config_value, callback, userdata, error_callback, error_userdata) },
        };
    }
};

pub const DeviceList = struct {
    allocator: std.mem.Allocator,
    items: []Device,

    pub fn deinit(self: *DeviceList) void {
        for (self.items) |*device| device.deinit(self.allocator);
        self.allocator.free(self.items);
        self.* = .{ .allocator = self.allocator, .items = &.{} };
    }
};

pub const Host = union(HostId) {
    alsa: backends.alsa.Host,
    coreaudio: backends.stub.Host,
    wasapi: backends.stub.Host,
    jack: backends.stub.Host,
    pulseaudio: backends.stub.Host,
    null: backends.null_backend.Host,

    pub fn id(self: Host) HostId {
        return switch (self) {
            .alsa => .alsa,
            .coreaudio => .coreaudio,
            .wasapi => .wasapi,
            .jack => .jack,
            .pulseaudio => .pulseaudio,
            .null => .null,
        };
    }

    pub fn deinit(self: *Host, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .alsa => |*host| host.deinit(allocator),
            .coreaudio, .wasapi, .jack, .pulseaudio => |*host| host.deinit(allocator),
            .null => |*host| host.deinit(allocator),
        }
    }

    pub fn devices(self: Host, allocator: std.mem.Allocator) AudioError!DeviceList {
        var list: std.ArrayList(Device) = .empty;
        errdefer {
            for (list.items) |*device| device.deinit(allocator);
            list.deinit(allocator);
        }

        switch (self) {
            .alsa => |host| {
                const backend_devices = try host.devices(allocator);
                defer allocator.free(backend_devices.items);
                for (backend_devices.items) |backend_device| {
                    try list.append(allocator, .{ .alsa = backend_device });
                }
            },
            .coreaudio => |host| {
                const backend_devices = try host.devices(allocator);
                defer allocator.free(backend_devices.items);
                for (backend_devices.items) |backend_device| {
                    try list.append(allocator, .{ .coreaudio = backend_device });
                }
            },
            .wasapi => |host| {
                const backend_devices = try host.devices(allocator);
                defer allocator.free(backend_devices.items);
                for (backend_devices.items) |backend_device| {
                    try list.append(allocator, .{ .wasapi = backend_device });
                }
            },
            .jack => |host| {
                const backend_devices = try host.devices(allocator);
                defer allocator.free(backend_devices.items);
                for (backend_devices.items) |backend_device| {
                    try list.append(allocator, .{ .jack = backend_device });
                }
            },
            .pulseaudio => |host| {
                const backend_devices = try host.devices(allocator);
                defer allocator.free(backend_devices.items);
                for (backend_devices.items) |backend_device| {
                    try list.append(allocator, .{ .pulseaudio = backend_device });
                }
            },
            .null => |host| {
                const backend_devices = try host.devices(allocator);
                defer allocator.free(backend_devices.items);
                for (backend_devices.items) |backend_device| {
                    try list.append(allocator, .{ .null = backend_device });
                }
            },
        }

        return .{ .allocator = allocator, .items = try list.toOwnedSlice(allocator) };
    }

    pub fn defaultOutputDevice(self: Host, allocator: std.mem.Allocator) AudioError!?Device {
        return switch (self) {
            .alsa => |host| if (try host.defaultOutputDevice(allocator)) |device| .{ .alsa = device } else null,
            .coreaudio => |host| if (try host.defaultOutputDevice(allocator)) |device| .{ .coreaudio = device } else null,
            .wasapi => |host| if (try host.defaultOutputDevice(allocator)) |device| .{ .wasapi = device } else null,
            .jack => |host| if (try host.defaultOutputDevice(allocator)) |device| .{ .jack = device } else null,
            .pulseaudio => |host| if (try host.defaultOutputDevice(allocator)) |device| .{ .pulseaudio = device } else null,
            .null => |host| if (try host.defaultOutputDevice(allocator)) |device| .{ .null = device } else null,
        };
    }

    pub fn defaultInputDevice(self: Host, allocator: std.mem.Allocator) AudioError!?Device {
        return switch (self) {
            .alsa => |host| if (try host.defaultInputDevice(allocator)) |device| .{ .alsa = device } else null,
            .coreaudio => |host| if (try host.defaultInputDevice(allocator)) |device| .{ .coreaudio = device } else null,
            .wasapi => |host| if (try host.defaultInputDevice(allocator)) |device| .{ .wasapi = device } else null,
            .jack => |host| if (try host.defaultInputDevice(allocator)) |device| .{ .jack = device } else null,
            .pulseaudio => |host| if (try host.defaultInputDevice(allocator)) |device| .{ .pulseaudio = device } else null,
            .null => |host| if (try host.defaultInputDevice(allocator)) |device| .{ .null = device } else null,
        };
    }
};

pub fn availableHosts(allocator: std.mem.Allocator) AudioError![]HostId {
    var ids: std.ArrayList(HostId) = .empty;
    errdefer ids.deinit(allocator);

    if (builtin.os.tag == .linux and backends.alsa.Host.isAvailable()) {
        try ids.append(allocator, .alsa);
    }

    try ids.append(allocator, .null);
    return ids.toOwnedSlice(allocator);
}

pub fn hostFromId(id_value: HostId) AudioError!Host {
    return switch (id_value) {
        .alsa => if (builtin.os.tag == .linux)
            .{ .alsa = try backends.alsa.Host.init() }
        else
            AudioError.BackendUnavailable,
        .coreaudio => .{ .coreaudio = backends.stub.Host.init(.coreaudio) },
        .wasapi => .{ .wasapi = backends.stub.Host.init(.wasapi) },
        .jack => .{ .jack = backends.stub.Host.init(.jack) },
        .pulseaudio => .{ .pulseaudio = backends.stub.Host.init(.pulseaudio) },
        .null => .{ .null = backends.null_backend.Host.init() },
    };
}

pub fn defaultHost() AudioError!Host {
    if (builtin.os.tag == .linux and backends.alsa.Host.isAvailable()) {
        return .{ .alsa = try backends.alsa.Host.init() };
    }
    return .{ .null = backends.null_backend.Host.init() };
}

test {
    _ = config;
    _ = stream;
    _ = backends;
}

test "host identifiers expose stable and display names" {
    try std.testing.expectEqualStrings("alsa", HostId.alsa.stableName());
    try std.testing.expectEqualStrings("ALSA", HostId.alsa.name());
}

test "available hosts always includes null fallback" {
    const allocator = std.testing.allocator;
    const ids = try availableHosts(allocator);
    defer allocator.free(ids);
    try std.testing.expect(ids.len >= 1);
    try std.testing.expect(ids[ids.len - 1] == .null);
}
