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
    channel_range: ?ChannelRange = null,
    min_sample_rate: u32,
    max_sample_rate: u32,
    buffer_size: SupportedBufferSize,
    total_buffer_size: SupportedBufferSize = .unknown,
    sample_format: SampleFormat,

    pub fn channelRange(self: SupportedStreamConfigRange) ChannelRange {
        return self.channel_range orelse .{ .min = self.channels, .max = self.channels };
    }

    pub fn supportsChannels(self: SupportedStreamConfigRange, channels: u16) bool {
        return self.channelRange().supports(channels);
    }

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

const default_sample_format_preferences = [_]SampleFormat{ .f32, .i16, .i32, .i24, .u16, .u32, .u24, .f64, .i8, .u8 };

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
            .channel_range = self.channels,
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

pub const NegotiatedSharedStreamConfig = struct {
    output_supported: SupportedStreamConfig,
    input_supported: SupportedStreamConfig,
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
                if (!range.supportsChannels(channels)) continue;
            }
            if (!range.supportsBufferSize(request.buffer_size)) continue;
            if (!range.supportsTotalBufferSize(request.total_buffer_size)) continue;

            var supported = if (request.sample_rate) |sample_rate|
                range.withSampleRate(sample_rate) orelse continue
            else
                range.withStandardSampleRate();
            if (request.channels) |channels| supported.channels = channels;

            return .{
                .supported = supported,
                .config = try supported.configWithBufferSizes(request.buffer_size, request.total_buffer_size),
            };
        }
    }
    return root.AudioError.UnsupportedConfig;
}

pub fn negotiateSharedStreamCapability(
    output_capabilities: []const StreamCapability,
    input_capabilities: []const StreamCapability,
    request: StreamConfigRequest,
) root.AudioError!NegotiatedSharedStreamConfig {
    try request.validate();
    for (request.sample_formats) |sample_format| {
        for (output_capabilities) |output_capability| {
            if (output_capability.direction != .output or output_capability.sample_format != sample_format) continue;
            if (!output_capability.supportsBufferSize(request.buffer_size)) continue;
            if (!output_capability.supportsTotalBufferSize(request.total_buffer_size)) continue;

            for (input_capabilities) |input_capability| {
                if (input_capability.direction != .input or input_capability.sample_format != sample_format) continue;
                if (!input_capability.supportsBufferSize(request.buffer_size)) continue;
                if (!input_capability.supportsTotalBufferSize(request.total_buffer_size)) continue;

                const channels = sharedCapabilityChannels(output_capability, input_capability, request.channels) orelse continue;
                const sample_rate = sharedCapabilitySampleRate(output_capability, input_capability, request.sample_rate) orelse continue;

                const config_value: StreamConfig = .{
                    .channels = channels,
                    .sample_rate = sample_rate,
                    .buffer_size = request.buffer_size,
                    .total_buffer_size = request.total_buffer_size,
                };
                try config_value.validate();

                return .{
                    .output_supported = .{
                        .channels = channels,
                        .sample_rate = sample_rate,
                        .buffer_size = output_capability.buffer_size,
                        .total_buffer_size = output_capability.total_buffer_size,
                        .sample_format = sample_format,
                    },
                    .input_supported = .{
                        .channels = channels,
                        .sample_rate = sample_rate,
                        .buffer_size = input_capability.buffer_size,
                        .total_buffer_size = input_capability.total_buffer_size,
                        .sample_format = sample_format,
                    },
                    .config = config_value,
                };
            }
        }
    }
    return root.AudioError.UnsupportedConfig;
}

fn sharedCapabilityChannels(
    output_capability: StreamCapability,
    input_capability: StreamCapability,
    requested_channels: ?u16,
) ?u16 {
    if (requested_channels) |channels| {
        if (output_capability.channels.supports(channels) and input_capability.channels.supports(channels)) {
            return channels;
        }
        return null;
    }

    var candidates_buffer: [16]u16 = undefined;
    const output_candidates = output_capability.channels.preferredCandidates(&candidates_buffer);
    for (output_candidates) |channels| {
        if (input_capability.channels.supports(channels)) return channels;
    }
    return null;
}

fn sharedCapabilitySampleRate(
    output_capability: StreamCapability,
    input_capability: StreamCapability,
    requested_sample_rate: ?u32,
) ?u32 {
    if (requested_sample_rate) |rate| {
        if (output_capability.containsRate(rate) and input_capability.containsRate(rate)) return rate;
        return null;
    }

    const min_rate = @max(output_capability.min_sample_rate, input_capability.min_sample_rate);
    const max_rate = @min(output_capability.max_sample_rate, input_capability.max_sample_rate);
    if (min_rate > max_rate) return null;
    if (48_000 >= min_rate and 48_000 <= max_rate) return 48_000;
    if (44_100 >= min_rate and 44_100 <= max_rate) return 44_100;
    return max_rate;
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

test "negotiation honors optional channel ranges on simple configs" {
    const ranges = [_]SupportedStreamConfigRange{.{
        .channels = 2,
        .channel_range = .{ .min = 1, .max = 8 },
        .min_sample_rate = 44_100,
        .max_sample_rate = 96_000,
        .buffer_size = .unknown,
        .sample_format = .f32,
    }};

    try std.testing.expect(ranges[0].supportsChannels(1));
    try std.testing.expect(ranges[0].supportsChannels(8));
    try std.testing.expect(!ranges[0].supportsChannels(10));
    try std.testing.expectEqual(ChannelRange{ .min = 1, .max = 8 }, ranges[0].channelRange());

    const negotiated = try negotiateStreamConfig(&ranges, .{
        .sample_formats = &.{.f32},
        .channels = 6,
        .sample_rate = 48_000,
    });
    try std.testing.expectEqual(@as(u16, 6), negotiated.config.channels);
    try std.testing.expectEqual(@as(u16, 6), negotiated.supported.channels);
    try std.testing.expectError(root.AudioError.UnsupportedConfig, negotiateStreamConfig(&ranges, .{
        .sample_formats = &.{.f32},
        .channels = 10,
        .sample_rate = 48_000,
    }));
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

test "shared capability negotiation picks common stereo 48 kHz config" {
    const output_capabilities = [_]StreamCapability{.{
        .direction = .output,
        .sample_format = .f32,
        .channels = .{ .min = 1, .max = 8 },
        .min_sample_rate = 44_100,
        .max_sample_rate = 96_000,
        .buffer_size = .{ .range = .{ .min = 64, .max = 1024 } },
        .total_buffer_size = .{ .range = .{ .min = 256, .max = 4096 } },
    }};
    const input_capabilities = [_]StreamCapability{.{
        .direction = .input,
        .sample_format = .f32,
        .channels = .{ .min = 2, .max = 2 },
        .min_sample_rate = 8_000,
        .max_sample_rate = 48_000,
        .buffer_size = .{ .range = .{ .min = 128, .max = 2048 } },
        .total_buffer_size = .{ .range = .{ .min = 512, .max = 8192 } },
    }};

    const negotiated = try negotiateSharedStreamCapability(&output_capabilities, &input_capabilities, .{
        .sample_formats = &.{.f32},
        .buffer_size = .{ .fixed = 256 },
        .total_buffer_size = .{ .fixed = 1024 },
    });

    try std.testing.expectEqual(@as(u16, 2), negotiated.config.channels);
    try std.testing.expectEqual(@as(u32, 48_000), negotiated.config.sample_rate);
    try std.testing.expectEqual(SampleFormat.f32, negotiated.output_supported.sample_format);
    try std.testing.expectEqual(SampleFormat.f32, negotiated.input_supported.sample_format);
    try std.testing.expectEqual(BufferSize{ .fixed = 256 }, negotiated.config.buffer_size);
    try std.testing.expectEqual(BufferSize{ .fixed = 1024 }, negotiated.config.total_buffer_size);
}

test "shared capability negotiation follows format and fallback preferences" {
    const output_capabilities = [_]StreamCapability{
        .{
            .direction = .output,
            .sample_format = .i16,
            .channels = .{ .min = 4, .max = 8 },
            .min_sample_rate = 32_000,
            .max_sample_rate = 44_000,
            .buffer_size = .unknown,
        },
        .{
            .direction = .output,
            .sample_format = .f32,
            .channels = .{ .min = 1, .max = 2 },
            .min_sample_rate = 44_100,
            .max_sample_rate = 48_000,
            .buffer_size = .unknown,
        },
    };
    const input_capabilities = [_]StreamCapability{
        .{
            .direction = .input,
            .sample_format = .f32,
            .channels = .{ .min = 1, .max = 1 },
            .min_sample_rate = 44_100,
            .max_sample_rate = 44_100,
            .buffer_size = .unknown,
        },
        .{
            .direction = .input,
            .sample_format = .i16,
            .channels = .{ .min = 4, .max = 4 },
            .min_sample_rate = 30_000,
            .max_sample_rate = 44_000,
            .buffer_size = .unknown,
        },
    };

    const negotiated = try negotiateSharedStreamCapability(&output_capabilities, &input_capabilities, .{
        .sample_formats = &.{ .f32, .i16 },
    });

    try std.testing.expectEqual(SampleFormat.f32, negotiated.output_supported.sample_format);
    try std.testing.expectEqual(@as(u16, 1), negotiated.config.channels);
    try std.testing.expectEqual(@as(u32, 44_100), negotiated.config.sample_rate);

    try std.testing.expectError(root.AudioError.UnsupportedConfig, negotiateSharedStreamCapability(
        &output_capabilities,
        &input_capabilities,
        .{ .sample_formats = &.{.f32}, .channels = 2 },
    ));
    try std.testing.expectError(root.AudioError.UnsupportedConfig, negotiateSharedStreamCapability(
        &output_capabilities,
        &input_capabilities,
        .{ .sample_formats = &.{.f32}, .sample_rate = 48_000 },
    ));
}
