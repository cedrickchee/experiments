const std = @import("std");
const cpal = @import("cpal_zig");

test "default host is constructible and deinitializable" {
    const allocator = std.testing.allocator;
    var host = try cpal.defaultHost();
    defer host.deinit(allocator);
    try std.testing.expect(host.id() == .alsa or host.id() == .null);
}

test "audio errors map to public stream run statuses" {
    try std.testing.expectEqual(
        cpal.StreamRunStatus.stream_suspended,
        cpal.runStatusFromAudioError(cpal.AudioError.StreamSuspended),
    );
    try std.testing.expectEqual(
        cpal.StreamRunStatus.stream_invalidated,
        cpal.runStatusFromAudioError(cpal.AudioError.StreamInvalidated),
    );
    try std.testing.expectEqual(
        cpal.StreamRunStatus.xrun,
        cpal.runStatusFromAudioError(cpal.AudioError.Xrun),
    );
}

test "null host exposes a usable output device" {
    const allocator = std.testing.allocator;
    var host = try cpal.hostFromId(.null);
    defer host.deinit(allocator);

    const maybe_device = try host.defaultOutputDevice(allocator);
    try std.testing.expect(maybe_device != null);
    var device = maybe_device.?;
    defer device.deinit(allocator);
    try std.testing.expect(device.isAvailable());

    const config = try device.defaultOutputConfig();
    try std.testing.expectEqual(@as(u32, 48_000), config.sample_rate);
    try std.testing.expectEqual(cpal.SampleFormat.f32, config.sample_format);
}

test "device structured description exposes CPAL-like metadata" {
    const allocator = std.testing.allocator;
    var host = try cpal.hostFromId(.null);
    defer host.deinit(allocator);

    var device = (try host.defaultOutputDevice(allocator)).?;
    defer device.deinit(allocator);

    const description = device.description();
    try std.testing.expectEqual(cpal.HostId.null, description.host);
    try std.testing.expectEqualStrings("null:output", description.id);
    try std.testing.expectEqualStrings("Null Output Device", description.name);
    try std.testing.expectEqualStrings("cpal-zig null", description.driver.?);
    try std.testing.expectEqual(cpal.DeviceType.virtual, description.device_type);
    try std.testing.expectEqual(cpal.InterfaceType.virtual, description.interface_type);
    try std.testing.expectEqual(cpal.DeviceDirection.output, description.direction);
    try std.testing.expect(description.supportsOutput());
    try std.testing.expect(!description.supportsInput());
    try std.testing.expect(description.metadataFingerprint() != 0);
}

test "null output stream invokes callback" {
    const allocator = std.testing.allocator;
    var host = try cpal.hostFromId(.null);
    defer host.deinit(allocator);
    var device = (try host.defaultOutputDevice(allocator)).?;
    defer device.deinit(allocator);

    const State = struct {
        calls: usize = 0,

        fn callback(buffer: []f32, info: cpal.OutputCallbackInfo, userdata: ?*anyopaque) void {
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
    try std.testing.expectEqual(@as(u32, 128), try output_stream.bufferSize());
    try std.testing.expectEqual(cpal.StreamRunStatus.running, output_stream.status());
    const diagnostics = try output_stream.diagnostics();
    try std.testing.expectEqual(cpal.StreamRunStatus.running, diagnostics.run_status);
    try std.testing.expectEqual(cpal.StreamBackendState.running, diagnostics.backend_state);
    try std.testing.expectEqual(@as(?u32, 128), diagnostics.buffer_size_frames);
    try std.testing.expectEqual(@as(?u32, 128), diagnostics.period_size_frames);
    try std.testing.expectEqual(@as(?u32, 128), diagnostics.avail_min_frames);
    try std.testing.expectEqual(@as(?u32, 128), diagnostics.start_threshold_frames);
    try std.testing.expectEqual(@as(?u32, 128), diagnostics.available_max_frames);
    try std.testing.expectEqual(@as(?u32, 0), diagnostics.overrange_frames);
    try std.testing.expectEqual(cpal.LatencyStatus.estimated, diagnostics.timestamp_status);
    try std.testing.expectEqual(cpal.LatencyStatus.estimated, diagnostics.latency_status);
    try std.testing.expectEqual(@as(?u64, 0), diagnostics.latency_duration_ns);
    try std.testing.expectEqual(cpal.ThreadSchedulingStatus.unsupported, diagnostics.scheduling_status);
    try std.testing.expectEqual(@as(u64, 1), diagnostics.callback_count);
    try std.testing.expectEqual(@as(u64, 0), diagnostics.stream_error_count);
    try std.testing.expectEqual(@as(u64, 0), diagnostics.xrun_count);
    try std.testing.expectEqual(@as(u64, 0), diagnostics.recovery_count);
    try std.testing.expectEqual(@as(?u64, 2_666_666), diagnostics.expected_callback_interval_ns);
    try std.testing.expectEqual(@as(?u64, null), diagnostics.last_callback_interval_ns);
    try std.testing.expectEqual(@as(?i64, null), diagnostics.last_callback_drift_ns);
    try std.testing.expectEqual(@as(?u64, null), diagnostics.max_callback_interval_ns);
    try std.testing.expectEqual(@as(?u64, null), diagnostics.max_callback_drift_abs_ns);
}

test "null output stream supports pause and drain lifecycle calls" {
    const allocator = std.testing.allocator;
    var host = try cpal.hostFromId(.null);
    defer host.deinit(allocator);
    var device = (try host.defaultOutputDevice(allocator)).?;
    defer device.deinit(allocator);

    const State = struct {
        calls: usize = 0,

        fn callback(buffer: []f32, info: cpal.OutputCallbackInfo, userdata: ?*anyopaque) void {
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
        .buffer_size = .{ .fixed = 64 },
    }, State.callback, &state, null, null);
    defer output_stream.deinit();

    try std.testing.expect(!output_stream.isRunning());
    try std.testing.expectEqual(cpal.StreamRunStatus.stopped, output_stream.status());
    try output_stream.play();
    try std.testing.expect(output_stream.isRunning());
    try std.testing.expectEqual(cpal.StreamRunStatus.running, output_stream.status());
    try output_stream.pause();
    try std.testing.expect(!output_stream.isRunning());
    try std.testing.expectEqual(cpal.StreamRunStatus.stopped, output_stream.status());
    try output_stream.play();
    try std.testing.expect(output_stream.isRunning());
    try std.testing.expectEqual(cpal.StreamRunStatus.running, output_stream.status());
    try output_stream.drain();
    try std.testing.expect(!output_stream.isRunning());
    try std.testing.expectEqual(cpal.StreamRunStatus.stopped, output_stream.status());

    try std.testing.expectEqual(@as(usize, 2), state.calls);
    try std.testing.expectEqual(@as(u32, 64), try output_stream.bufferSize());
}

test "null output stream supports f64 callbacks" {
    const allocator = std.testing.allocator;
    var host = try cpal.hostFromId(.null);
    defer host.deinit(allocator);
    var device = (try host.defaultOutputDevice(allocator)).?;
    defer device.deinit(allocator);

    const negotiated = try device.negotiateOutputConfig(allocator, .{
        .sample_formats = &.{.f64},
        .channels = 2,
        .sample_rate = 48_000,
    });
    try std.testing.expectEqual(cpal.SampleFormat.f64, negotiated.supported.sample_format);

    const State = struct {
        calls: usize = 0,

        fn callback(buffer: []f64, info: cpal.OutputCallbackInfo, userdata: ?*anyopaque) void {
            _ = info;
            const state: *@This() = @ptrCast(@alignCast(userdata.?));
            state.calls += 1;
            @memset(buffer, 0);
        }
    };

    var state = State{};
    var output_stream = try device.buildOutputStreamF64(
        negotiated.config,
        State.callback,
        &state,
        null,
        null,
    );
    defer output_stream.deinit();

    try output_stream.play();
    try std.testing.expectEqual(@as(usize, 1), state.calls);
    try std.testing.expectEqual(cpal.StreamRunStatus.running, output_stream.status());
}

test "null output stream supports i8 callbacks" {
    const allocator = std.testing.allocator;
    var host = try cpal.hostFromId(.null);
    defer host.deinit(allocator);
    var device = (try host.defaultOutputDevice(allocator)).?;
    defer device.deinit(allocator);

    const negotiated = try device.negotiateOutputConfig(allocator, .{
        .sample_formats = &.{.i8},
        .channels = 2,
        .sample_rate = 48_000,
    });
    try std.testing.expectEqual(cpal.SampleFormat.i8, negotiated.supported.sample_format);

    const State = struct {
        calls: usize = 0,

        fn callback(buffer: []i8, info: cpal.OutputCallbackInfo, userdata: ?*anyopaque) void {
            _ = info;
            const state: *@This() = @ptrCast(@alignCast(userdata.?));
            state.calls += 1;
            for (buffer) |sample| {
                std.testing.expectEqual(@as(i8, 0), sample) catch unreachable;
            }
        }
    };

    var state = State{};
    var output_stream = try device.buildOutputStreamI8(
        negotiated.config,
        State.callback,
        &state,
        null,
        null,
    );
    defer output_stream.deinit();

    try output_stream.play();
    try std.testing.expectEqual(@as(usize, 1), state.calls);
    try std.testing.expectEqual(cpal.StreamRunStatus.running, output_stream.status());
}

test "null output stream supports u8 callbacks" {
    const allocator = std.testing.allocator;
    var host = try cpal.hostFromId(.null);
    defer host.deinit(allocator);
    var device = (try host.defaultOutputDevice(allocator)).?;
    defer device.deinit(allocator);

    const negotiated = try device.negotiateOutputConfig(allocator, .{
        .sample_formats = &.{.u8},
        .channels = 2,
        .sample_rate = 48_000,
    });
    try std.testing.expectEqual(cpal.SampleFormat.u8, negotiated.supported.sample_format);

    const State = struct {
        calls: usize = 0,

        fn callback(buffer: []u8, info: cpal.OutputCallbackInfo, userdata: ?*anyopaque) void {
            _ = info;
            const state: *@This() = @ptrCast(@alignCast(userdata.?));
            state.calls += 1;
            for (buffer) |sample| {
                std.testing.expectEqual(@as(u8, 128), sample) catch unreachable;
            }
        }
    };

    var state = State{};
    var output_stream = try device.buildOutputStreamU8(
        negotiated.config,
        State.callback,
        &state,
        null,
        null,
    );
    defer output_stream.deinit();

    try output_stream.play();
    try std.testing.expectEqual(@as(usize, 1), state.calls);
    try std.testing.expectEqual(cpal.StreamRunStatus.running, output_stream.status());
}

test "null output stream supports u32 callbacks" {
    const allocator = std.testing.allocator;
    var host = try cpal.hostFromId(.null);
    defer host.deinit(allocator);
    var device = (try host.defaultOutputDevice(allocator)).?;
    defer device.deinit(allocator);

    const negotiated = try device.negotiateOutputConfig(allocator, .{
        .sample_formats = &.{.u32},
        .channels = 2,
        .sample_rate = 48_000,
    });
    try std.testing.expectEqual(cpal.SampleFormat.u32, negotiated.supported.sample_format);

    const State = struct {
        calls: usize = 0,

        fn callback(buffer: []u32, info: cpal.OutputCallbackInfo, userdata: ?*anyopaque) void {
            _ = info;
            const state: *@This() = @ptrCast(@alignCast(userdata.?));
            state.calls += 1;
            for (buffer) |sample| {
                std.testing.expectEqual(@as(u32, 0x80000000), sample) catch unreachable;
            }
        }
    };

    var state = State{};
    var output_stream = try device.buildOutputStreamU32(
        negotiated.config,
        State.callback,
        &state,
        null,
        null,
    );
    defer output_stream.deinit();

    try output_stream.play();
    try std.testing.expectEqual(@as(usize, 1), state.calls);
    try std.testing.expectEqual(cpal.StreamRunStatus.running, output_stream.status());
}

test "null output stream supports comptime generic builders" {
    const allocator = std.testing.allocator;
    var host = try cpal.hostFromId(.null);
    defer host.deinit(allocator);
    var device = (try host.defaultOutputDevice(allocator)).?;
    defer device.deinit(allocator);

    try std.testing.expectEqual(cpal.SampleFormat.f32, cpal.sampleFormatForType(f32).?);
    try std.testing.expectEqual(cpal.SampleFormat.i8, cpal.sampleFormatForType(i8).?);
    try std.testing.expectEqual(cpal.SampleFormat.u8, cpal.sampleFormatForType(u8).?);
    try std.testing.expectEqual(cpal.SampleFormat.i24, cpal.sampleFormatForType(i24).?);
    try std.testing.expectEqual(cpal.SampleFormat.u24, cpal.sampleFormatForType(u24).?);
    try std.testing.expectEqual(cpal.SampleFormat.u32, cpal.sampleFormatForType(u32).?);
    try std.testing.expectEqual(cpal.SampleFormat.f64, cpal.sampleFormatForType(f64).?);
    try std.testing.expectEqual(@as(?cpal.SampleFormat, null), cpal.sampleFormatForType(i64));
    try std.testing.expectEqual(@as(?cpal.SampleFormat, null), cpal.sampleFormatForType(u64));

    const State = struct {
        calls: usize = 0,

        fn callback(buffer: []f32, info: cpal.OutputCallbackInfo, userdata: ?*anyopaque) void {
            _ = info;
            const state: *@This() = @ptrCast(@alignCast(userdata.?));
            state.calls += 1;
            @memset(buffer, 0);
        }
    };

    var state = State{};
    var output_stream = try device.buildOutputStream(
        f32,
        .{ .channels = 2, .sample_rate = 48_000 },
        State.callback,
        &state,
        null,
        null,
    );
    defer output_stream.deinit();

    try output_stream.play();
    try std.testing.expectEqual(@as(usize, 1), state.calls);
}

test "null i24 and u24 streams invoke callbacks with correct silence" {
    const allocator = std.testing.allocator;
    var host = try cpal.hostFromId(.null);
    defer host.deinit(allocator);

    var output_device = (try host.defaultOutputDevice(allocator)).?;
    defer output_device.deinit(allocator);
    var input_device = (try host.defaultInputDevice(allocator)).?;
    defer input_device.deinit(allocator);

    const i24_output = try output_device.negotiateOutputConfig(allocator, .{
        .sample_formats = &.{.i24},
        .channels = 2,
        .sample_rate = 48_000,
        .buffer_size = .{ .fixed = 64 },
    });
    const u24_input = try input_device.negotiateInputConfig(allocator, .{
        .sample_formats = &.{.u24},
        .channels = i24_output.config.channels,
        .sample_rate = i24_output.config.sample_rate,
        .buffer_size = i24_output.config.buffer_size,
    });

    const State = struct {
        output_calls: usize = 0,
        input_calls: usize = 0,
        input_samples: usize = 0,

        fn output(buffer: []i24, info: cpal.OutputCallbackInfo, userdata: ?*anyopaque) void {
            _ = info;
            const state: *@This() = @ptrCast(@alignCast(userdata.?));
            state.output_calls += 1;
            for (buffer) |sample| {
                std.debug.assert(sample == 0);
            }
            @memset(buffer, 0);
        }

        fn input(buffer: []const u24, info: cpal.InputCallbackInfo, userdata: ?*anyopaque) void {
            _ = info;
            const state: *@This() = @ptrCast(@alignCast(userdata.?));
            state.input_calls += 1;
            state.input_samples += buffer.len;
            for (buffer) |sample| {
                std.debug.assert(sample == 0x800000);
            }
        }
    };

    var state = State{};
    var output_stream = try output_device.buildOutputStream(
        i24,
        i24_output.config,
        State.output,
        &state,
        null,
        null,
    );
    defer output_stream.deinit();
    var input_stream = try input_device.buildInputStream(
        u24,
        u24_input.config,
        State.input,
        &state,
        null,
        null,
    );
    defer input_stream.deinit();

    try output_stream.play();
    try input_stream.play();
    try std.testing.expectEqual(@as(usize, 1), state.output_calls);
    try std.testing.expectEqual(@as(usize, 1), state.input_calls);
    try std.testing.expectEqual(@as(usize, 128), state.input_samples);
}

test "null host exposes a usable input device" {
    const allocator = std.testing.allocator;
    var host = try cpal.hostFromId(.null);
    defer host.deinit(allocator);

    const maybe_device = try host.defaultInputDevice(allocator);
    try std.testing.expect(maybe_device != null);
    var device = maybe_device.?;
    defer device.deinit(allocator);

    const config = try device.defaultInputConfig();
    try std.testing.expectEqual(@as(u32, 48_000), config.sample_rate);
    try std.testing.expectEqual(cpal.SampleFormat.f32, config.sample_format);
}

test "null input stream invokes callback" {
    const allocator = std.testing.allocator;
    var host = try cpal.hostFromId(.null);
    defer host.deinit(allocator);
    var device = (try host.defaultInputDevice(allocator)).?;
    defer device.deinit(allocator);

    const State = struct {
        calls: usize = 0,
        samples: usize = 0,

        fn callback(buffer: []const f32, info: cpal.InputCallbackInfo, userdata: ?*anyopaque) void {
            _ = info;
            const state: *@This() = @ptrCast(@alignCast(userdata.?));
            state.calls += 1;
            state.samples += buffer.len;
            for (buffer) |sample| {
                std.debug.assert(sample == 0);
            }
        }
    };

    var state = State{};
    var input_stream = try device.buildInputStreamF32(.{
        .channels = 2,
        .sample_rate = 48_000,
        .buffer_size = .{ .fixed = 64 },
    }, State.callback, &state, null, null);
    defer input_stream.deinit();

    try input_stream.play();
    try std.testing.expectEqual(@as(usize, 1), state.calls);
    try std.testing.expectEqual(@as(usize, 128), state.samples);
    try std.testing.expectEqual(@as(u32, 64), try input_stream.bufferSize());
}

test "null i16 output and input streams invoke callbacks" {
    const allocator = std.testing.allocator;
    var host = try cpal.hostFromId(.null);
    defer host.deinit(allocator);

    var output_device = (try host.defaultOutputDevice(allocator)).?;
    defer output_device.deinit(allocator);
    var input_device = (try host.defaultInputDevice(allocator)).?;
    defer input_device.deinit(allocator);

    const output_negotiated = try output_device.negotiateOutputConfig(allocator, .{
        .sample_formats = &.{.i16},
        .channels = 2,
        .sample_rate = 48_000,
        .buffer_size = .{ .fixed = 64 },
    });
    const input_negotiated = try input_device.negotiateInputConfig(allocator, .{
        .sample_formats = &.{.i16},
        .channels = output_negotiated.config.channels,
        .sample_rate = output_negotiated.config.sample_rate,
        .buffer_size = output_negotiated.config.buffer_size,
    });

    const State = struct {
        output_calls: usize = 0,
        input_calls: usize = 0,
        input_samples: usize = 0,

        fn output(buffer: []i16, info: cpal.OutputCallbackInfo, userdata: ?*anyopaque) void {
            _ = info;
            const state: *@This() = @ptrCast(@alignCast(userdata.?));
            state.output_calls += 1;
            @memset(buffer, 0);
        }

        fn input(buffer: []const i16, info: cpal.InputCallbackInfo, userdata: ?*anyopaque) void {
            _ = info;
            const state: *@This() = @ptrCast(@alignCast(userdata.?));
            state.input_calls += 1;
            state.input_samples += buffer.len;
            for (buffer) |sample| {
                std.debug.assert(sample == 0);
            }
        }
    };

    var state = State{};
    var output_stream = try output_device.buildOutputStreamI16(
        output_negotiated.config,
        State.output,
        &state,
        null,
        null,
    );
    defer output_stream.deinit();
    var input_stream = try input_device.buildInputStreamI16(
        input_negotiated.config,
        State.input,
        &state,
        null,
        null,
    );
    defer input_stream.deinit();

    try output_stream.play();
    try input_stream.play();
    try std.testing.expectEqual(@as(usize, 1), state.output_calls);
    try std.testing.expectEqual(@as(usize, 1), state.input_calls);
    try std.testing.expectEqual(@as(usize, 128), state.input_samples);
}

test "null i32 output and input streams invoke callbacks" {
    const allocator = std.testing.allocator;
    var host = try cpal.hostFromId(.null);
    defer host.deinit(allocator);

    var output_device = (try host.defaultOutputDevice(allocator)).?;
    defer output_device.deinit(allocator);
    var input_device = (try host.defaultInputDevice(allocator)).?;
    defer input_device.deinit(allocator);

    const output_negotiated = try output_device.negotiateOutputConfig(allocator, .{
        .sample_formats = &.{.i32},
        .channels = 2,
        .sample_rate = 48_000,
        .buffer_size = .{ .fixed = 64 },
    });
    const input_negotiated = try input_device.negotiateInputConfig(allocator, .{
        .sample_formats = &.{.i32},
        .channels = output_negotiated.config.channels,
        .sample_rate = output_negotiated.config.sample_rate,
        .buffer_size = output_negotiated.config.buffer_size,
    });

    const State = struct {
        output_calls: usize = 0,
        input_calls: usize = 0,
        input_samples: usize = 0,

        fn output(buffer: []i32, info: cpal.OutputCallbackInfo, userdata: ?*anyopaque) void {
            _ = info;
            const state: *@This() = @ptrCast(@alignCast(userdata.?));
            state.output_calls += 1;
            @memset(buffer, 0);
        }

        fn input(buffer: []const i32, info: cpal.InputCallbackInfo, userdata: ?*anyopaque) void {
            _ = info;
            const state: *@This() = @ptrCast(@alignCast(userdata.?));
            state.input_calls += 1;
            state.input_samples += buffer.len;
            for (buffer) |sample| {
                std.debug.assert(sample == 0);
            }
        }
    };

    var state = State{};
    var output_stream = try output_device.buildOutputStreamI32(
        output_negotiated.config,
        State.output,
        &state,
        null,
        null,
    );
    defer output_stream.deinit();
    var input_stream = try input_device.buildInputStreamI32(
        input_negotiated.config,
        State.input,
        &state,
        null,
        null,
    );
    defer input_stream.deinit();

    try output_stream.play();
    try input_stream.play();
    try std.testing.expectEqual(@as(usize, 1), state.output_calls);
    try std.testing.expectEqual(@as(usize, 1), state.input_calls);
    try std.testing.expectEqual(@as(usize, 128), state.input_samples);
}

test "null u16 output and input streams invoke callbacks with midpoint silence" {
    const allocator = std.testing.allocator;
    var host = try cpal.hostFromId(.null);
    defer host.deinit(allocator);

    var output_device = (try host.defaultOutputDevice(allocator)).?;
    defer output_device.deinit(allocator);
    var input_device = (try host.defaultInputDevice(allocator)).?;
    defer input_device.deinit(allocator);

    const output_negotiated = try output_device.negotiateOutputConfig(allocator, .{
        .sample_formats = &.{.u16},
        .channels = 2,
        .sample_rate = 48_000,
        .buffer_size = .{ .fixed = 64 },
    });
    const input_negotiated = try input_device.negotiateInputConfig(allocator, .{
        .sample_formats = &.{.u16},
        .channels = output_negotiated.config.channels,
        .sample_rate = output_negotiated.config.sample_rate,
        .buffer_size = output_negotiated.config.buffer_size,
    });

    const State = struct {
        output_calls: usize = 0,
        input_calls: usize = 0,
        input_samples: usize = 0,

        fn output(buffer: []u16, info: cpal.OutputCallbackInfo, userdata: ?*anyopaque) void {
            _ = info;
            const state: *@This() = @ptrCast(@alignCast(userdata.?));
            state.output_calls += 1;
            for (buffer) |sample| {
                std.debug.assert(sample == 32768);
            }
            @memset(buffer, 32768);
        }

        fn input(buffer: []const u16, info: cpal.InputCallbackInfo, userdata: ?*anyopaque) void {
            _ = info;
            const state: *@This() = @ptrCast(@alignCast(userdata.?));
            state.input_calls += 1;
            state.input_samples += buffer.len;
            for (buffer) |sample| {
                std.debug.assert(sample == 32768);
            }
        }
    };

    var state = State{};
    var output_stream = try output_device.buildOutputStreamU16(
        output_negotiated.config,
        State.output,
        &state,
        null,
        null,
    );
    defer output_stream.deinit();
    var input_stream = try input_device.buildInputStreamU16(
        input_negotiated.config,
        State.input,
        &state,
        null,
        null,
    );
    defer input_stream.deinit();

    try output_stream.play();
    try input_stream.play();
    try std.testing.expectEqual(@as(usize, 1), state.output_calls);
    try std.testing.expectEqual(@as(usize, 1), state.input_calls);
    try std.testing.expectEqual(@as(usize, 128), state.input_samples);
}
