const std = @import("std");
const root = @import("root.zig");

pub const SampleFormat = enum {
    i8,
    i16,
    i24,
    i32,
    i64,
    u8,
    u16,
    u24,
    u32,
    u64,
    f32,
    f64,
    dsd_u8,
    dsd_u16,
    dsd_u32,

    pub fn sampleSize(self: SampleFormat) usize {
        return switch (self) {
            .i8, .u8, .dsd_u8 => 1,
            .i16, .u16, .dsd_u16 => 2,
            .i24, .u24, .i32, .u32, .f32, .dsd_u32 => 4,
            .i64, .u64, .f64 => 8,
        };
    }

    pub fn bitsPerSample(self: SampleFormat) u16 {
        return switch (self) {
            .i8, .u8 => 8,
            .i16, .u16 => 16,
            .i24, .u24 => 24,
            .i32, .u32, .f32 => 32,
            .i64, .u64, .f64 => 64,
            .dsd_u8, .dsd_u16, .dsd_u32 => 1,
        };
    }

    pub fn isFloat(self: SampleFormat) bool {
        return self == .f32 or self == .f64;
    }
};

pub const BufferSize = union(enum) {
    default,
    fixed: u32,

    pub fn validate(self: BufferSize) root.AudioError!void {
        switch (self) {
            .default => {},
            .fixed => |frames| if (frames == 0) return root.AudioError.InvalidInput,
        }
    }
};

pub const SupportedBufferSize = union(enum) {
    unknown,
    range: struct {
        min: u32,
        max: u32,
    },

    pub fn supports(self: SupportedBufferSize, buffer_size: BufferSize) bool {
        return switch (buffer_size) {
            .default => true,
            .fixed => |frames| switch (self) {
                .unknown => true,
                .range => |range| frames >= range.min and frames <= range.max,
            },
        };
    }
};

pub const StreamConfig = struct {
    channels: u16,
    sample_rate: u32,
    buffer_size: BufferSize = .default,
    total_buffer_size: BufferSize = .default,

    pub fn validate(self: StreamConfig) root.AudioError!void {
        if (self.channels == 0 or self.sample_rate == 0) {
            return root.AudioError.InvalidInput;
        }
        try self.buffer_size.validate();
        try self.total_buffer_size.validate();
        if (self.buffer_size == .fixed and self.total_buffer_size == .fixed and
            self.total_buffer_size.fixed < self.buffer_size.fixed)
        {
            return root.AudioError.InvalidInput;
        }
    }
};

pub const SupportedStreamConfig = struct {
    channels: u16,
    sample_rate: u32,
    buffer_size: SupportedBufferSize,
    total_buffer_size: SupportedBufferSize = .unknown,
    sample_format: SampleFormat,

    pub fn config(self: SupportedStreamConfig) StreamConfig {
        return .{
            .channels = self.channels,
            .sample_rate = self.sample_rate,
            .buffer_size = .default,
            .total_buffer_size = .default,
        };
    }

    pub fn configWithBufferSize(self: SupportedStreamConfig, buffer_size: BufferSize) root.AudioError!StreamConfig {
        if (!self.buffer_size.supports(buffer_size)) return root.AudioError.UnsupportedConfig;
        return .{
            .channels = self.channels,
            .sample_rate = self.sample_rate,
            .buffer_size = buffer_size,
            .total_buffer_size = .default,
        };
    }

    pub fn configWithBufferSizes(
        self: SupportedStreamConfig,
        buffer_size: BufferSize,
        total_buffer_size: BufferSize,
    ) root.AudioError!StreamConfig {
        if (!self.buffer_size.supports(buffer_size)) return root.AudioError.UnsupportedConfig;
        if (!self.total_buffer_size.supports(total_buffer_size)) return root.AudioError.UnsupportedConfig;
        const config_value: StreamConfig = .{
            .channels = self.channels,
            .sample_rate = self.sample_rate,
            .buffer_size = buffer_size,
            .total_buffer_size = total_buffer_size,
        };
        try config_value.validate();
        return config_value;
    }
};

pub const SupportedStreamConfigRange = struct {
    channels: u16,
    min_sample_rate: u32,
    max_sample_rate: u32,
    buffer_size: SupportedBufferSize,
    total_buffer_size: SupportedBufferSize = .unknown,
    sample_format: SampleFormat,

    pub fn containsRate(self: SupportedStreamConfigRange, sample_rate: u32) bool {
        return sample_rate >= self.min_sample_rate and sample_rate <= self.max_sample_rate;
    }

    pub fn supportsBufferSize(self: SupportedStreamConfigRange, buffer_size: BufferSize) bool {
        return self.buffer_size.supports(buffer_size);
    }

    pub fn supportsTotalBufferSize(self: SupportedStreamConfigRange, buffer_size: BufferSize) bool {
        return self.total_buffer_size.supports(buffer_size);
    }

    pub fn withSampleRate(self: SupportedStreamConfigRange, sample_rate: u32) ?SupportedStreamConfig {
        if (!self.containsRate(sample_rate)) return null;
        return .{
            .channels = self.channels,
            .sample_rate = sample_rate,
            .buffer_size = self.buffer_size,
            .total_buffer_size = self.total_buffer_size,
            .sample_format = self.sample_format,
        };
    }

    pub fn withStandardSampleRate(self: SupportedStreamConfigRange) SupportedStreamConfig {
        if (self.withSampleRate(48_000)) |config_value| return config_value;
        if (self.withSampleRate(44_100)) |config_value| return config_value;
        return .{
            .channels = self.channels,
            .sample_rate = self.max_sample_rate,
            .buffer_size = self.buffer_size,
            .total_buffer_size = self.total_buffer_size,
            .sample_format = self.sample_format,
        };
    }
};

const default_sample_format_preferences = [_]SampleFormat{ .f32, .i16, .i32, .u16, .u32, .f64, .i8, .u8 };

pub fn defaultSampleFormatPreferences() []const SampleFormat {
    return &default_sample_format_preferences;
}

pub const StreamCapabilityDirection = enum {
    input,
    output,
};

pub const ChannelRange = struct {
    min: u16,
    max: u16,

    pub fn supports(self: ChannelRange, channels: u16) bool {
        return channels >= self.min and channels <= self.max;
    }

    pub fn representative(self: ChannelRange) u16 {
        if (self.supports(2)) return 2;
        return self.min;
    }

    pub fn preferredCandidates(self: ChannelRange, output: []u16) []u16 {
        if (output.len == 0) return output[0..0];
        var count: usize = 0;
        appendCandidate(self, output, &count, self.representative());

        const common = [_]u16{ 1, 2, 4, 6, 8, 10, 12, 16, 24, 32 };
        for (common) |channels| appendCandidate(self, output, &count, channels);
        appendCandidate(self, output, &count, self.min);
        appendCandidate(self, output, &count, self.max);
        return output[0..count];
    }

    fn appendCandidate(self: ChannelRange, output: []u16, count: *usize, channels: u16) void {
        if (count.* >= output.len or !self.supports(channels)) return;
        for (output[0..count.*]) |existing| {
            if (existing == channels) return;
        }
        output[count.*] = channels;
        count.* += 1;
    }
};

pub const StreamCapability = struct {
    direction: StreamCapabilityDirection,
    sample_format: SampleFormat,
    channels: ChannelRange,
    min_sample_rate: u32,
    max_sample_rate: u32,
    buffer_size: SupportedBufferSize,
    total_buffer_size: SupportedBufferSize = .unknown,

    pub fn containsRate(self: StreamCapability, sample_rate: u32) bool {
        return sample_rate >= self.min_sample_rate and sample_rate <= self.max_sample_rate;
    }

    pub fn supportsBufferSize(self: StreamCapability, buffer_size: BufferSize) bool {
        return self.buffer_size.supports(buffer_size);
    }

    pub fn supportsTotalBufferSize(self: StreamCapability, buffer_size: BufferSize) bool {
        return self.total_buffer_size.supports(buffer_size);
    }

    pub fn representativeConfigRange(self: StreamCapability) SupportedStreamConfigRange {
        return .{
            .channels = self.channels.representative(),
            .min_sample_rate = self.min_sample_rate,
            .max_sample_rate = self.max_sample_rate,
            .buffer_size = self.buffer_size,
            .total_buffer_size = self.total_buffer_size,
            .sample_format = self.sample_format,
        };
    }

    pub fn withRequest(self: StreamCapability, request: StreamConfigRequest) ?SupportedStreamConfig {
        const channels = request.channels orelse self.channels.representative();
        if (!self.channels.supports(channels)) return null;
        if (!self.supportsBufferSize(request.buffer_size)) return null;
        if (!self.supportsTotalBufferSize(request.total_buffer_size)) return null;

        const sample_rate = if (request.sample_rate) |rate| blk: {
            if (!self.containsRate(rate)) return null;
            break :blk rate;
        } else if (self.containsRate(48_000))
            48_000
        else if (self.containsRate(44_100))
            44_100
        else
            self.max_sample_rate;

        return .{
            .channels = channels,
            .sample_rate = sample_rate,
            .buffer_size = self.buffer_size,
            .total_buffer_size = self.total_buffer_size,
            .sample_format = self.sample_format,
        };
    }
};

pub const StreamConfigRequest = struct {
    sample_formats: []const SampleFormat = &default_sample_format_preferences,
    channels: ?u16 = null,
    sample_rate: ?u32 = null,
    buffer_size: BufferSize = .default,
    total_buffer_size: BufferSize = .default,

    pub fn validate(self: StreamConfigRequest) root.AudioError!void {
        try self.buffer_size.validate();
        try self.total_buffer_size.validate();
        if (self.buffer_size == .fixed and self.total_buffer_size == .fixed and
            self.total_buffer_size.fixed < self.buffer_size.fixed)
        {
            return root.AudioError.InvalidInput;
        }
    }
};

pub const NegotiatedStreamConfig = struct {
    supported: SupportedStreamConfig,
    config: StreamConfig,
};

pub fn negotiateStreamConfig(
    ranges: []const SupportedStreamConfigRange,
    request: StreamConfigRequest,
) root.AudioError!NegotiatedStreamConfig {
    try request.validate();
    for (request.sample_formats) |sample_format| {
        for (ranges) |range| {
            if (range.sample_format != sample_format) continue;
            if (request.channels) |channels| {
                if (range.channels != channels) continue;
            }
            if (!range.supportsBufferSize(request.buffer_size)) continue;
            if (!range.supportsTotalBufferSize(request.total_buffer_size)) continue;

            const supported = if (request.sample_rate) |sample_rate|
                range.withSampleRate(sample_rate) orelse continue
            else
                range.withStandardSampleRate();

            return .{
                .supported = supported,
                .config = try supported.configWithBufferSizes(request.buffer_size, request.total_buffer_size),
            };
        }
    }
    return root.AudioError.UnsupportedConfig;
}

pub fn negotiateStreamCapability(
    capabilities: []const StreamCapability,
    request: StreamConfigRequest,
) root.AudioError!NegotiatedStreamConfig {
    try request.validate();
    for (request.sample_formats) |sample_format| {
        for (capabilities) |capability| {
            if (capability.sample_format != sample_format) continue;
            const supported = capability.withRequest(request) orelse continue;
            return .{
                .supported = supported,
                .config = try supported.configWithBufferSizes(request.buffer_size, request.total_buffer_size),
            };
        }
    }
    return root.AudioError.UnsupportedConfig;
}

test "sample format sizing mirrors storage size" {
    try std.testing.expectEqual(@as(usize, 4), SampleFormat.f32.sampleSize());
    try std.testing.expectEqual(@as(usize, 4), SampleFormat.i24.sampleSize());
    try std.testing.expectEqual(@as(u16, 24), SampleFormat.i24.bitsPerSample());
}

test "stream config validation rejects zero values" {
    try std.testing.expectError(root.AudioError.InvalidInput, (StreamConfig{
        .channels = 0,
        .sample_rate = 48_000,
    }).validate());
    try std.testing.expectError(root.AudioError.InvalidInput, (StreamConfig{
        .channels = 2,
        .sample_rate = 0,
    }).validate());
    try std.testing.expectError(root.AudioError.InvalidInput, (StreamConfig{
        .channels = 2,
        .sample_rate = 48_000,
        .buffer_size = .{ .fixed = 0 },
    }).validate());
    try std.testing.expectError(root.AudioError.InvalidInput, (StreamConfig{
        .channels = 2,
        .sample_rate = 48_000,
        .total_buffer_size = .{ .fixed = 0 },
    }).validate());
    try std.testing.expectError(root.AudioError.InvalidInput, (StreamConfig{
        .channels = 2,
        .sample_rate = 48_000,
        .buffer_size = .{ .fixed = 512 },
        .total_buffer_size = .{ .fixed = 256 },
    }).validate());
}

test "standard sample rate prefers 48 kHz" {
    const range = SupportedStreamConfigRange{
        .channels = 2,
        .min_sample_rate = 8_000,
        .max_sample_rate = 96_000,
        .buffer_size = .unknown,
        .sample_format = .f32,
    };
    try std.testing.expectEqual(@as(u32, 48_000), range.withStandardSampleRate().sample_rate);
}

test "default sample format preferences favor common high-quality PCM formats" {
    const preferences = defaultSampleFormatPreferences();
    try std.testing.expectEqual(SampleFormat.f32, preferences[0]);
    try std.testing.expectEqual(SampleFormat.i16, preferences[1]);
    try std.testing.expectEqual(SampleFormat.i32, preferences[2]);
    try std.testing.expectEqual(SampleFormat.u8, preferences[preferences.len - 1]);
}

test "negotiation honors format, rate, channels, and fixed buffer" {
    const ranges = [_]SupportedStreamConfigRange{
        .{
            .channels = 1,
            .min_sample_rate = 44_100,
            .max_sample_rate = 48_000,
            .buffer_size = .{ .range = .{ .min = 64, .max = 256 } },
            .sample_format = .f32,
        },
        .{
            .channels = 2,
            .min_sample_rate = 44_100,
            .max_sample_rate = 96_000,
            .buffer_size = .{ .range = .{ .min = 128, .max = 512 } },
            .total_buffer_size = .{ .range = .{ .min = 512, .max = 2048 } },
            .sample_format = .i16,
        },
    };

    const negotiated = try negotiateStreamConfig(&ranges, .{
        .sample_formats = &.{.i16},
        .channels = 2,
        .sample_rate = 48_000,
        .buffer_size = .{ .fixed = 256 },
        .total_buffer_size = .{ .fixed = 1024 },
    });
    try std.testing.expectEqual(SampleFormat.i16, negotiated.supported.sample_format);
    try std.testing.expectEqual(@as(u16, 2), negotiated.config.channels);
    try std.testing.expectEqual(@as(u32, 48_000), negotiated.config.sample_rate);
    try std.testing.expectEqual(BufferSize{ .fixed = 256 }, negotiated.config.buffer_size);
    try std.testing.expectEqual(BufferSize{ .fixed = 1024 }, negotiated.config.total_buffer_size);
    try std.testing.expectEqual(SupportedBufferSize{ .range = .{ .min = 512, .max = 2048 } }, negotiated.supported.total_buffer_size);
}

test "negotiation rejects unsupported fixed period or total buffer" {
    const ranges = [_]SupportedStreamConfigRange{.{
        .channels = 2,
        .min_sample_rate = 44_100,
        .max_sample_rate = 48_000,
        .buffer_size = .{ .range = .{ .min = 128, .max = 512 } },
        .total_buffer_size = .{ .range = .{ .min = 512, .max = 2048 } },
        .sample_format = .f32,
    }};
    try std.testing.expectError(root.AudioError.UnsupportedConfig, negotiateStreamConfig(&ranges, .{
        .buffer_size = .{ .fixed = 64 },
    }));
    try std.testing.expectError(root.AudioError.UnsupportedConfig, negotiateStreamConfig(&ranges, .{
        .total_buffer_size = .{ .fixed = 4096 },
    }));
    try std.testing.expectError(root.AudioError.InvalidInput, negotiateStreamConfig(&ranges, .{
        .buffer_size = .{ .fixed = 512 },
        .total_buffer_size = .{ .fixed = 256 },
    }));
}

test "channel range candidate helper keeps preferred unique supported counts" {
    var candidates_buffer: [8]u16 = undefined;
    const candidates = (ChannelRange{ .min = 1, .max = 8 }).preferredCandidates(&candidates_buffer);
    try std.testing.expectEqualSlices(u16, &.{ 2, 1, 4, 6, 8 }, candidates);

    const mono_candidates = (ChannelRange{ .min = 1, .max = 1 }).preferredCandidates(&candidates_buffer);
    try std.testing.expectEqualSlices(u16, &.{1}, mono_candidates);

    const surround_candidates = (ChannelRange{ .min = 4, .max = 12 }).preferredCandidates(&candidates_buffer);
    try std.testing.expectEqualSlices(u16, &.{ 4, 6, 8, 10, 12 }, surround_candidates);
}

test "capability negotiation supports channel ranges" {
    const capabilities = [_]StreamCapability{.{
        .direction = .output,
        .sample_format = .i16,
        .channels = .{ .min = 1, .max = 8 },
        .min_sample_rate = 8_000,
        .max_sample_rate = 96_000,
        .buffer_size = .{ .range = .{ .min = 64, .max = 1024 } },
        .total_buffer_size = .{ .range = .{ .min = 256, .max = 4096 } },
    }};
    const negotiated = try negotiateStreamCapability(&capabilities, .{
        .sample_formats = &.{.i16},
        .channels = 6,
        .sample_rate = 48_000,
        .buffer_size = .{ .fixed = 256 },
        .total_buffer_size = .{ .fixed = 1024 },
    });
    try std.testing.expectEqual(@as(u16, 6), negotiated.config.channels);
    try std.testing.expectEqual(@as(u32, 48_000), negotiated.config.sample_rate);
    try std.testing.expectEqual(BufferSize{ .fixed = 1024 }, negotiated.config.total_buffer_size);
    try std.testing.expectEqual(SampleFormat.i16, negotiated.supported.sample_format);
    try std.testing.expectEqual(SupportedBufferSize{ .range = .{ .min = 256, .max = 4096 } }, negotiated.supported.total_buffer_size);
    try std.testing.expectEqual(SupportedBufferSize{ .range = .{ .min = 256, .max = 4096 } }, capabilities[0].total_buffer_size);
}
