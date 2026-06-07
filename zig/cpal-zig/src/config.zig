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

    pub fn validate(self: StreamConfig) root.AudioError!void {
        if (self.channels == 0 or self.sample_rate == 0) {
            return root.AudioError.InvalidInput;
        }
        try self.buffer_size.validate();
    }
};

pub const SupportedStreamConfig = struct {
    channels: u16,
    sample_rate: u32,
    buffer_size: SupportedBufferSize,
    sample_format: SampleFormat,

    pub fn config(self: SupportedStreamConfig) StreamConfig {
        return .{
            .channels = self.channels,
            .sample_rate = self.sample_rate,
            .buffer_size = .default,
        };
    }

    pub fn configWithBufferSize(self: SupportedStreamConfig, buffer_size: BufferSize) root.AudioError!StreamConfig {
        if (!self.buffer_size.supports(buffer_size)) return root.AudioError.UnsupportedConfig;
        return .{
            .channels = self.channels,
            .sample_rate = self.sample_rate,
            .buffer_size = buffer_size,
        };
    }
};

pub const SupportedStreamConfigRange = struct {
    channels: u16,
    min_sample_rate: u32,
    max_sample_rate: u32,
    buffer_size: SupportedBufferSize,
    sample_format: SampleFormat,

    pub fn containsRate(self: SupportedStreamConfigRange, sample_rate: u32) bool {
        return sample_rate >= self.min_sample_rate and sample_rate <= self.max_sample_rate;
    }

    pub fn supportsBufferSize(self: SupportedStreamConfigRange, buffer_size: BufferSize) bool {
        return self.buffer_size.supports(buffer_size);
    }

    pub fn withSampleRate(self: SupportedStreamConfigRange, sample_rate: u32) ?SupportedStreamConfig {
        if (!self.containsRate(sample_rate)) return null;
        return .{
            .channels = self.channels,
            .sample_rate = sample_rate,
            .buffer_size = self.buffer_size,
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
            .sample_format = self.sample_format,
        };
    }
};

const default_sample_format_preferences = [_]SampleFormat{ .f32, .i16 };

pub const StreamConfigRequest = struct {
    sample_formats: []const SampleFormat = &default_sample_format_preferences,
    channels: ?u16 = null,
    sample_rate: ?u32 = null,
    buffer_size: BufferSize = .default,
};

pub const NegotiatedStreamConfig = struct {
    supported: SupportedStreamConfig,
    config: StreamConfig,
};

pub fn negotiateStreamConfig(
    ranges: []const SupportedStreamConfigRange,
    request: StreamConfigRequest,
) root.AudioError!NegotiatedStreamConfig {
    try request.buffer_size.validate();
    for (request.sample_formats) |sample_format| {
        for (ranges) |range| {
            if (range.sample_format != sample_format) continue;
            if (request.channels) |channels| {
                if (range.channels != channels) continue;
            }
            if (!range.supportsBufferSize(request.buffer_size)) continue;

            const supported = if (request.sample_rate) |sample_rate|
                range.withSampleRate(sample_rate) orelse continue
            else
                range.withStandardSampleRate();

            return .{
                .supported = supported,
                .config = try supported.configWithBufferSize(request.buffer_size),
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
            .sample_format = .i16,
        },
    };

    const negotiated = try negotiateStreamConfig(&ranges, .{
        .sample_formats = &.{.i16},
        .channels = 2,
        .sample_rate = 48_000,
        .buffer_size = .{ .fixed = 256 },
    });
    try std.testing.expectEqual(SampleFormat.i16, negotiated.supported.sample_format);
    try std.testing.expectEqual(@as(u16, 2), negotiated.config.channels);
    try std.testing.expectEqual(@as(u32, 48_000), negotiated.config.sample_rate);
    try std.testing.expectEqual(BufferSize{ .fixed = 256 }, negotiated.config.buffer_size);
}

test "negotiation rejects unsupported fixed buffer" {
    const ranges = [_]SupportedStreamConfigRange{.{
        .channels = 2,
        .min_sample_rate = 44_100,
        .max_sample_rate = 48_000,
        .buffer_size = .{ .range = .{ .min = 128, .max = 512 } },
        .sample_format = .f32,
    }};
    try std.testing.expectError(root.AudioError.UnsupportedConfig, negotiateStreamConfig(&ranges, .{
        .buffer_size = .{ .fixed = 64 },
    }));
}
