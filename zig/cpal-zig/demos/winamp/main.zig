const std = @import("std");
const vaxis = @import("vaxis");
const cpal = @import("cpal_zig");

const c = @cImport({
    @cInclude("errno.h");
    @cInclude("libavformat/avformat.h");
    @cInclude("libavcodec/avcodec.h");
    @cInclude("libavutil/avutil.h");
    @cInclude("libavutil/opt.h");
    @cInclude("libswresample/swresample.h");
});

const Cell = vaxis.Cell;
const Segment = vaxis.Segment;
const Style = vaxis.Style;
const Window = vaxis.Window;

const Event = union(enum) {
    key_press: vaxis.Key,
    winsize: vaxis.Winsize,
    focus_in,
};

const Palette = struct {
    bg: Style = .{ .fg = .{ .rgb = .{ 0xd5, 0xdd, 0xe5 } }, .bg = .{ .rgb = .{ 0x08, 0x0b, 0x10 } } },
    panel: Style = .{ .fg = .{ .rgb = .{ 0xbf, 0xc8, 0xd2 } }, .bg = .{ .rgb = .{ 0x11, 0x16, 0x1f } } },
    border: Style = .{ .fg = .{ .rgb = .{ 0x7d, 0x8b, 0x9a } }, .bg = .{ .rgb = .{ 0x11, 0x16, 0x1f } } },
    title: Style = .{ .fg = .{ .rgb = .{ 0xf0, 0xf6, 0xff } }, .bg = .{ .rgb = .{ 0x11, 0x16, 0x1f } }, .bold = true },
    muted: Style = .{ .fg = .{ .rgb = .{ 0x79, 0x86, 0x96 } }, .bg = .{ .rgb = .{ 0x11, 0x16, 0x1f } } },
    cyan: Style = .{ .fg = .{ .rgb = .{ 0x53, 0xd5, 0xff } }, .bg = .{ .rgb = .{ 0x11, 0x16, 0x1f } }, .bold = true },
    amber: Style = .{ .fg = .{ .rgb = .{ 0xff, 0xc8, 0x57 } }, .bg = .{ .rgb = .{ 0x11, 0x16, 0x1f } }, .bold = true },
    green: Style = .{ .fg = .{ .rgb = .{ 0x62, 0xe6, 0x8f } }, .bg = .{ .rgb = .{ 0x11, 0x16, 0x1f } }, .bold = true },
    red: Style = .{ .fg = .{ .rgb = .{ 0xff, 0x6b, 0x6b } }, .bg = .{ .rgb = .{ 0x11, 0x16, 0x1f } }, .bold = true },
    selected: Style = .{ .fg = .{ .rgb = .{ 0x06, 0x0a, 0x10 } }, .bg = .{ .rgb = .{ 0x53, 0xd5, 0xff } }, .bold = true },
    active: Style = .{ .fg = .{ .rgb = .{ 0x06, 0x0a, 0x10 } }, .bg = .{ .rgb = .{ 0x62, 0xe6, 0x8f } }, .bold = true },
};

const PlaybackState = enum {
    playing,
    paused,
    buffering,
    stopped,
    failed,
};

const StreamPreset = struct {
    title: []const u8,
    source: []const u8,
    format: []const u8,
    bitrate: []const u8,
    kind: []const u8,
    url: []const u8,
};

const presets = [_]StreamPreset{
    .{ .title = "Groove Salad", .source = "SomaFM", .format = "mp3", .bitrate = "128k", .kind = "live", .url = "https://ice1.somafm.com/groovesalad-128-mp3" },
    .{ .title = "DEF CON Radio", .source = "SomaFM", .format = "mp3", .bitrate = "128k", .kind = "live", .url = "https://ice1.somafm.com/defcon-128-mp3" },
    .{ .title = "Drone Zone", .source = "SomaFM", .format = "mp3", .bitrate = "128k", .kind = "live", .url = "https://ice1.somafm.com/dronezone-128-mp3" },
    .{ .title = "Beat Blender", .source = "SomaFM", .format = "aac", .bitrate = "128k", .kind = "live", .url = "https://ice1.somafm.com/beatblender-128-aac" },
    .{ .title = "Cliqhop IDM", .source = "SomaFM", .format = "mp3", .bitrate = "128k", .kind = "live", .url = "https://ice1.somafm.com/cliqhop-128-mp3" },
};

const DecoderStatus = enum(u8) {
    idle,
    connecting,
    decoding,
    ended,
    failed,
};

const AudioEngine = struct {
    allocator: std.mem.Allocator,
    host: cpal.Host,
    device: cpal.Device,
    output_stream: cpal.stream.Stream,
    config: cpal.StreamConfig,
    ring: []f32,
    read_index: std.atomic.Value(usize) = .init(0),
    write_index: std.atomic.Value(usize) = .init(0),
    generation: std.atomic.Value(u64) = .init(1),
    output_enabled: std.atomic.Value(bool) = .init(false),
    paused: std.atomic.Value(bool) = .init(false),
    status: std.atomic.Value(u8) = .init(@intFromEnum(DecoderStatus.idle)),
    level_percent: std.atomic.Value(u8) = .init(0),
    volume_percent: std.atomic.Value(u8) = .init(75),
    samples_played: std.atomic.Value(u64) = .init(0),
    decoder_thread: ?std.Thread = null,

    fn init(allocator: std.mem.Allocator) !*AudioEngine {
        const self = try allocator.create(AudioEngine);
        errdefer allocator.destroy(self);

        var host = try cpal.defaultHost();
        errdefer host.deinit(allocator);

        var device = (try host.defaultOutputDevice(allocator)) orelse return error.NoOutputDevice;
        errdefer device.deinit(allocator);

        const config = (try device.defaultOutputConfig()).config();
        const ring_samples = @max(@as(usize, config.sample_rate) * @as(usize, config.channels) * 8, 16_384);
        const ring = try allocator.alloc(f32, ring_samples);
        errdefer allocator.free(ring);
        @memset(ring, 0);

        self.* = AudioEngine{
            .allocator = allocator,
            .host = host,
            .device = device,
            .output_stream = undefined,
            .config = config,
            .ring = ring,
        };
        self.output_stream = try self.device.buildOutputStreamF32(
            config,
            AudioEngine.outputCallback,
            self,
            AudioEngine.errorCallback,
            self,
        );
        try self.output_stream.play();
        return self;
    }

    fn deinit(self: *AudioEngine) void {
        self.stopDecoder();
        self.output_stream.deinit();
        self.allocator.free(self.ring);
        self.device.deinit(self.allocator);
        self.host.deinit(self.allocator);
        self.allocator.destroy(self);
    }

    fn start(self: *AudioEngine, url: []const u8) !void {
        self.stopDecoder();
        self.clearRing();
        self.status.store(@intFromEnum(DecoderStatus.connecting), .seq_cst);
        self.output_enabled.store(true, .seq_cst);
        self.paused.store(false, .seq_cst);
        self.samples_played.store(0, .seq_cst);
        self.level_percent.store(0, .seq_cst);
        const owned_url = try self.allocator.dupeZ(u8, url);
        const next_generation = self.generation.fetchAdd(1, .seq_cst) + 1;
        self.decoder_thread = try std.Thread.spawn(.{}, AudioEngine.decoderMain, .{ self, owned_url, next_generation });
    }

    fn stopDecoder(self: *AudioEngine) void {
        _ = self.generation.fetchAdd(1, .seq_cst);
        self.output_enabled.store(false, .seq_cst);
        self.paused.store(false, .seq_cst);
        if (self.decoder_thread) |thread| {
            thread.join();
            self.decoder_thread = null;
        }
        self.status.store(@intFromEnum(DecoderStatus.idle), .seq_cst);
        self.clearRing();
    }

    fn setPaused(self: *AudioEngine, paused_value: bool) void {
        self.paused.store(paused_value, .seq_cst);
        self.output_enabled.store(true, .seq_cst);
    }

    fn setVolume(self: *AudioEngine, percent: u8) void {
        self.volume_percent.store(percent, .seq_cst);
    }

    fn decoderStatus(self: *AudioEngine) DecoderStatus {
        return @enumFromInt(self.status.load(.seq_cst));
    }

    fn bufferPercent(self: *AudioEngine) u8 {
        const read = self.read_index.load(.seq_cst);
        const write = self.write_index.load(.seq_cst);
        const used = write -| read;
        return @intCast(@min(@as(usize, 100), (used * 100) / @max(self.ring.len, 1)));
    }

    fn level(self: *AudioEngine) u8 {
        return self.level_percent.load(.seq_cst);
    }

    fn elapsedSeconds(self: *AudioEngine) u32 {
        const samples = self.samples_played.load(.seq_cst);
        const denom = @as(u64, self.config.sample_rate) * @as(u64, self.config.channels);
        return if (denom == 0) 0 else @intCast(samples / denom);
    }

    fn clearRing(self: *AudioEngine) void {
        self.read_index.store(0, .seq_cst);
        self.write_index.store(0, .seq_cst);
        @memset(self.ring, 0);
    }

    fn shouldContinue(self: *AudioEngine, generation: u64) bool {
        return self.generation.load(.seq_cst) == generation;
    }

    fn writeSamples(self: *AudioEngine, generation: u64, samples: []const f32) void {
        var offset: usize = 0;
        while (offset < samples.len and self.shouldContinue(generation)) {
            const read = self.read_index.load(.seq_cst);
            const write = self.write_index.load(.seq_cst);
            const used = write -| read;
            const space = self.ring.len -| used;
            if (space == 0) {
                sleepMs(4);
                continue;
            }
            const count = @min(space, samples.len - offset);
            const ring_offset = write % self.ring.len;
            const first = @min(count, self.ring.len - ring_offset);
            @memcpy(self.ring[ring_offset .. ring_offset + first], samples[offset .. offset + first]);
            if (first < count) {
                @memcpy(self.ring[0 .. count - first], samples[offset + first .. offset + count]);
            }
            self.write_index.store(write + count, .seq_cst);
            offset += count;
        }
    }

    fn outputCallback(buffer: []f32, info: cpal.OutputCallbackInfo, userdata: ?*anyopaque) void {
        _ = info;
        const self: *AudioEngine = @ptrCast(@alignCast(userdata.?));
        if (!self.output_enabled.load(.seq_cst) or self.paused.load(.seq_cst)) {
            @memset(buffer, 0);
            self.level_percent.store(0, .seq_cst);
            return;
        }

        const read = self.read_index.load(.seq_cst);
        const write = self.write_index.load(.seq_cst);
        const available = write -| read;
        const count = @min(available, buffer.len);
        const ring_offset = read % self.ring.len;
        const first = @min(count, self.ring.len - ring_offset);
        if (first > 0) @memcpy(buffer[0..first], self.ring[ring_offset .. ring_offset + first]);
        if (first < count) @memcpy(buffer[first..count], self.ring[0 .. count - first]);
        if (count < buffer.len) @memset(buffer[count..], 0);
        self.read_index.store(read + count, .seq_cst);

        const volume = @as(f32, @floatFromInt(self.volume_percent.load(.seq_cst))) / 100.0;
        var peak: f32 = 0;
        for (buffer) |*sample| {
            sample.* = std.math.clamp(sample.* * volume, -1.0, 1.0);
            peak = @max(peak, @abs(sample.*));
        }
        const percent: u8 = @intFromFloat(@min(100.0, peak * 160.0));
        self.level_percent.store(percent, .seq_cst);
        _ = self.samples_played.fetchAdd(count, .seq_cst);
    }

    fn errorCallback(_: cpal.AudioError, userdata: ?*anyopaque) void {
        const self: *AudioEngine = @ptrCast(@alignCast(userdata.?));
        self.status.store(@intFromEnum(DecoderStatus.failed), .seq_cst);
    }

    fn decoderMain(self: *AudioEngine, url: [:0]u8, generation: u64) void {
        defer self.allocator.free(url);
        decodeStream(self, url, generation) catch {
            if (self.shouldContinue(generation)) {
                self.status.store(@intFromEnum(DecoderStatus.failed), .seq_cst);
            }
        };
    }
};

const DecoderInterrupt = struct {
    engine: *AudioEngine,
    generation: u64,
};

fn ffmpegInterruptCallback(ctx: ?*anyopaque) callconv(.c) c_int {
    const interrupt: *DecoderInterrupt = @ptrCast(@alignCast(ctx.?));
    return if (interrupt.engine.shouldContinue(interrupt.generation)) 0 else 1;
}

fn decodeStream(engine: *AudioEngine, url: [:0]const u8, generation: u64) !void {
    _ = c.avformat_network_init();

    var interrupt: DecoderInterrupt = .{ .engine = engine, .generation = generation };
    var fmt_ctx: ?*c.AVFormatContext = c.avformat_alloc_context();
    if (fmt_ctx == null) return error.FFmpegOpenFailed;
    fmt_ctx.?.*.interrupt_callback.callback = ffmpegInterruptCallback;
    fmt_ctx.?.*.interrupt_callback.@"opaque" = &interrupt;
    errdefer c.avformat_close_input(&fmt_ctx);

    var options: ?*c.AVDictionary = null;
    defer c.av_dict_free(&options);
    _ = c.av_dict_set(&options, "user_agent", "cpal-zig-winamp/0.1", 0);
    _ = c.av_dict_set(&options, "rw_timeout", "5000000", 0);

    if (c.avformat_open_input(&fmt_ctx, url.ptr, null, &options) < 0) return error.FFmpegOpenFailed;
    if (c.avformat_find_stream_info(fmt_ctx.?, null) < 0) return error.FFmpegStreamInfoFailed;

    const stream_index = findAudioStream(fmt_ctx.?) orelse return error.NoAudioStream;
    const stream = fmt_ctx.?.*.streams[@intCast(stream_index)];
    const codecpar = stream.*.codecpar;
    const decoder = c.avcodec_find_decoder(codecpar.*.codec_id) orelse return error.DecoderUnavailable;
    var codec_ctx = c.avcodec_alloc_context3(decoder) orelse return error.DecoderUnavailable;
    defer c.avcodec_free_context(&codec_ctx);
    if (c.avcodec_parameters_to_context(codec_ctx, codecpar) < 0) return error.DecoderUnavailable;
    if (c.avcodec_open2(codec_ctx, decoder, null) < 0) return error.DecoderUnavailable;

    const out_channels: c_int = @intCast(engine.config.channels);
    const out_rate: c_int = @intCast(engine.config.sample_rate);
    const out_layout = c.av_get_default_channel_layout(out_channels);
    const in_channels = if (codec_ctx.*.channels > 0) codec_ctx.*.channels else out_channels;
    const in_layout = if (codec_ctx.*.channel_layout != 0)
        @as(i64, @intCast(codec_ctx.*.channel_layout))
    else
        c.av_get_default_channel_layout(in_channels);

    var swr: ?*c.SwrContext = c.swr_alloc_set_opts(
        null,
        out_layout,
        c.AV_SAMPLE_FMT_FLT,
        out_rate,
        in_layout,
        codec_ctx.*.sample_fmt,
        codec_ctx.*.sample_rate,
        0,
        null,
    ) orelse return error.ResamplerUnavailable;
    defer c.swr_free(&swr);
    if (c.swr_init(swr.?) < 0) return error.ResamplerUnavailable;

    const packet = c.av_packet_alloc() orelse return error.OutOfMemory;
    defer c.av_packet_free(@constCast(&packet));
    const frame = c.av_frame_alloc() orelse return error.OutOfMemory;
    defer c.av_frame_free(@constCast(&frame));

    engine.status.store(@intFromEnum(DecoderStatus.decoding), .seq_cst);
    while (engine.shouldContinue(generation)) {
        const read_rc = c.av_read_frame(fmt_ctx.?, packet);
        if (read_rc < 0) break;
        defer c.av_packet_unref(packet);
        if (packet.*.stream_index != stream_index) continue;
        if (c.avcodec_send_packet(codec_ctx, packet) < 0) continue;
        try drainDecoder(engine, generation, codec_ctx, swr.?, frame, out_rate, out_channels);
    }

    if (engine.shouldContinue(generation)) {
        _ = c.avcodec_send_packet(codec_ctx, null);
        try drainDecoder(engine, generation, codec_ctx, swr.?, frame, out_rate, out_channels);
        engine.status.store(@intFromEnum(DecoderStatus.ended), .seq_cst);
    }
}

fn drainDecoder(
    engine: *AudioEngine,
    generation: u64,
    codec_ctx: *c.AVCodecContext,
    swr: *c.SwrContext,
    frame: *c.AVFrame,
    out_rate: c_int,
    out_channels: c_int,
) !void {
    while (engine.shouldContinue(generation)) {
        const receive_rc = c.avcodec_receive_frame(codec_ctx, frame);
        if (receive_rc == -c.EAGAIN or receive_rc == c.AVERROR_EOF) return;
        if (receive_rc < 0) return error.DecodeFailed;

        const delay = c.swr_get_delay(swr, codec_ctx.*.sample_rate);
        const out_samples = c.av_rescale_rnd(
            delay + frame.*.nb_samples,
            out_rate,
            codec_ctx.*.sample_rate,
            c.AV_ROUND_UP,
        );
        if (out_samples <= 0) {
            c.av_frame_unref(frame);
            continue;
        }

        const total_samples: usize = @intCast(out_samples * out_channels);
        const converted = try engine.allocator.alloc(f32, total_samples);
        defer engine.allocator.free(converted);

        var out_data = [_][*c]u8{@ptrCast(converted.ptr)};
        const converted_per_channel = c.swr_convert(
            swr,
            @ptrCast(&out_data),
            @intCast(out_samples),
            @ptrCast(frame.*.extended_data),
            frame.*.nb_samples,
        );
        c.av_frame_unref(frame);
        if (converted_per_channel <= 0) continue;

        const converted_total: usize = @intCast(converted_per_channel * out_channels);
        engine.writeSamples(generation, converted[0..@min(converted_total, converted.len)]);
        engine.status.store(@intFromEnum(DecoderStatus.decoding), .seq_cst);
    }
}

fn findAudioStream(fmt_ctx: *c.AVFormatContext) ?c_int {
    var index: c_uint = 0;
    while (index < fmt_ctx.*.nb_streams) : (index += 1) {
        const stream = fmt_ctx.*.streams[index];
        if (stream.*.codecpar.*.codec_type == c.AVMEDIA_TYPE_AUDIO) return @intCast(index);
    }
    return null;
}

fn sleepMs(ms: u64) void {
    var ts = std.os.linux.timespec{
        .sec = @intCast(ms / 1000),
        .nsec = @intCast((ms % 1000) * std.time.ns_per_ms),
    };
    _ = std.os.linux.nanosleep(&ts, null);
}

const PlayerSnapshot = struct {
    state: PlaybackState,
    selected_index: usize,
    playing_index: usize,
    elapsed_seconds: u32,
    volume_percent: u8,
    sample_rate: u32,
    channels: u8,
    bitrate: []const u8,
    device_name: []const u8,
    decoder: []const u8,
    callback_health: []const u8,
    buffer_health: []const u8,
    buffer_percent: u8,
    level_percent: u8,
};

const App = struct {
    palette: Palette = .{},
    state: PlaybackState = .buffering,
    selected_index: usize = 0,
    playing_index: usize = 0,
    elapsed_seconds: u32 = 222,
    volume_percent: u8 = 75,
    frame: u32 = 0,
    ascii: bool = false,
    url_override: ?[]const u8 = null,
    device_name: []const u8 = "ALSA: default",

    fn currentUrl(self: App) []const u8 {
        return self.url_override orelse presets[self.selected_index].url;
    }

    fn snapshot(self: App, engine: *AudioEngine) PlayerSnapshot {
        const decoder_status = engine.decoderStatus();
        const buffer_percent = engine.bufferPercent();
        return .{
            .state = self.state,
            .selected_index = self.selected_index,
            .playing_index = self.playing_index,
            .elapsed_seconds = engine.elapsedSeconds(),
            .volume_percent = self.volume_percent,
            .sample_rate = engine.config.sample_rate,
            .channels = @intCast(engine.config.channels),
            .bitrate = presets[self.playing_index].bitrate,
            .device_name = self.device_name,
            .decoder = "ffmpeg",
            .callback_health = if (decoder_status == .failed) "retry available" else "output callback healthy",
            .buffer_health = switch (decoder_status) {
                .idle => "idle",
                .connecting => "connecting stream",
                .decoding => if (buffer_percent < 5) "buffer low" else "buffering stable",
                .ended => "stream ended",
                .failed => "stream error",
            },
            .buffer_percent = buffer_percent,
            .level_percent = engine.level(),
        };
    }

    fn tick(self: *App, engine: *AudioEngine) void {
        self.frame +%= 1;
        if (self.state == .paused or self.state == .stopped) return;
        self.state = switch (engine.decoderStatus()) {
            .idle => .stopped,
            .connecting => .buffering,
            .decoding => if (engine.bufferPercent() > 2 or engine.elapsedSeconds() > 0) .playing else .buffering,
            .ended => .stopped,
            .failed => .failed,
        };
    }

    fn handleKey(self: *App, key: vaxis.Key, engine: *AudioEngine) bool {
        if (key.matches('q', .{}) or key.matches('c', .{ .ctrl = true })) return true;
        if (key.matches(vaxis.Key.down, .{})) {
            self.selected_index = @min(self.selected_index + 1, presets.len - 1);
        } else if (key.matches(vaxis.Key.up, .{})) {
            self.selected_index -|= 1;
        } else if (key.matches(vaxis.Key.enter, .{})) {
            self.playing_index = self.selected_index;
            self.elapsed_seconds = 0;
            engine.start(self.currentUrl()) catch {
                self.state = .failed;
                return false;
            };
            self.state = .buffering;
        } else if (key.matches(vaxis.Key.space, .{})) {
            self.state = switch (self.state) {
                .playing, .buffering => blk: {
                    engine.setPaused(true);
                    break :blk .paused;
                },
                .paused, .stopped => blk: {
                    engine.setPaused(false);
                    break :blk .playing;
                },
                .failed => blk: {
                    engine.start(self.currentUrl()) catch break :blk .failed;
                    break :blk .buffering;
                },
            };
        } else if (key.matches('s', .{})) {
            engine.stopDecoder();
            self.state = .stopped;
        } else if (key.matches('r', .{})) {
            engine.start(self.currentUrl()) catch {
                self.state = .failed;
                return false;
            };
            self.frame = 0;
            self.state = .buffering;
        } else if (key.matches('+', .{}) or key.matches('=', .{})) {
            self.volume_percent = @min(self.volume_percent + 5, 100);
            engine.setVolume(self.volume_percent);
        } else if (key.matches('-', .{})) {
            self.volume_percent = self.volume_percent -| 5;
            engine.setVolume(self.volume_percent);
        } else if (key.matches('e', .{})) {
            self.state = .failed;
        }
        return false;
    }
};

const CliOptions = struct {
    ascii: bool = false,
    url: ?[]const u8 = null,
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.gpa;

    const cli = try parseCli(init, allocator);
    var app_state: App = .{
        .ascii = cli.ascii,
        .url_override = cli.url,
    };
    var device_name_owned = false;
    if (detectDefaultOutputName(allocator)) |device_name| {
        app_state.device_name = device_name;
        device_name_owned = true;
    } else |_| {
        app_state.device_name = "ALSA: default";
    }
    defer if (device_name_owned) allocator.free(app_state.device_name);

    const audio_engine = try AudioEngine.init(allocator);
    defer audio_engine.deinit();
    audio_engine.setVolume(app_state.volume_percent);
    audio_engine.start(app_state.currentUrl()) catch {
        app_state.state = .failed;
    };

    var tty_buffer: [1024]u8 = undefined;
    var tty = try vaxis.Tty.init(io, &tty_buffer);
    defer tty.deinit();

    var vx = try vaxis.init(io, allocator, init.environ_map, .{});
    defer vx.deinit(allocator, tty.writer());

    var loop: vaxis.Loop(Event) = .init(io, &tty, &vx);
    try loop.start();
    defer loop.stop();

    try vx.enterAltScreen(tty.writer());
    try vx.queryTerminal(tty.writer(), .fromSeconds(1));

    while (true) {
        while (try loop.tryEvent()) |event| {
            switch (event) {
                .key_press => |key| if (app_state.handleKey(key, audio_engine)) return,
                .winsize => |ws| try vx.resize(allocator, tty.writer(), ws),
                .focus_in => {},
            }
        }

        app_state.tick(audio_engine);
        try render(&vx, tty.writer(), app_state, audio_engine);
        try std.Io.sleep(io, .fromMilliseconds(33), .awake);
    }
}

fn parseCli(init: std.process.Init, allocator: std.mem.Allocator) !CliOptions {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, allocator);
    defer args.deinit();

    var options: CliOptions = .{};
    _ = args.next();
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--ascii")) {
            options.ascii = true;
        } else if (std.mem.eql(u8, arg, "--url")) {
            options.url = args.next() orelse return error.MissingUrlArgument;
        }
    }
    return options;
}

fn detectDefaultOutputName(allocator: std.mem.Allocator) ![]const u8 {
    var host = try cpal.defaultHost();
    defer host.deinit(allocator);
    var device = (try host.defaultOutputDevice(allocator)) orelse return allocator.dupe(u8, "ALSA: default");
    defer device.deinit(allocator);
    return std.fmt.allocPrint(allocator, "{s}: {s}", .{ device.info().host.stableName(), device.info().name });
}

fn render(vx: *vaxis.Vaxis, tty: *std.Io.Writer, app_state: App, engine: *AudioEngine) !void {
    const root = vx.window();
    root.hideCursor();
    root.fill(.{ .style = app_state.palette.bg });

    const snapshot = app_state.snapshot(engine);
    if (root.width < 70 or root.height < 20) {
        drawCompact(root, app_state, snapshot);
    } else {
        drawFull(root, app_state, snapshot);
    }

    try vx.render(tty);
}

fn drawFull(root: Window, app_state: App, snapshot: PlayerSnapshot) void {
    const width = @min(root.width, @as(u16, 118));
    const left: i17 = @intCast((root.width - width) / 2);
    const top: i17 = if (root.height > 32) @intCast((root.height - 32) / 2) else 0;
    const height = @min(root.height, @as(u16, 32));
    const shell = root.child(.{ .x_off = left, .y_off = top, .width = width, .height = height });
    shell.fill(.{ .style = app_state.palette.panel });

    const transport_h: u16 = if (shell.height >= 28) 6 else 5;
    const playlist_h: u16 = if (shell.height >= 28) 8 else 6;
    const status_h: u16 = 3;
    const spectrum_h = shell.height -| transport_h -| playlist_h -| status_h;

    const transport = panel(shell, 0, transport_h, " CPAL-Zig Winamp ", sampleText(snapshot, app_state));
    drawTransport(transport, app_state, snapshot);

    const spectrum_y: i17 = @intCast(transport_h);
    const spectrum = panel(shell, spectrum_y, spectrum_h, " Spectrum ", "");
    drawSpectrum(spectrum, app_state, snapshot);

    const playlist_y: i17 = @intCast(transport_h + spectrum_h);
    const playlist = panel(shell, playlist_y, playlist_h, " Playlist ", playlistCountText());
    drawPlaylist(playlist, app_state, snapshot);

    const status_y: i17 = @intCast(transport_h + spectrum_h + playlist_h);
    const status = panel(shell, status_y, status_h, " Status ", "");
    drawStatus(status, app_state, snapshot);
}

fn drawCompact(root: Window, app_state: App, snapshot: PlayerSnapshot) void {
    const shell = root.child(.{ .width = root.width, .height = root.height });
    shell.fill(.{ .style = app_state.palette.panel });

    const transport_h: u16 = @min(shell.height, 5);
    const status_h: u16 = if (shell.height >= 9) 3 else 1;
    const playlist_h: u16 = if (shell.height >= 14) 3 else 1;
    const spectrum_h: u16 = shell.height -| transport_h -| playlist_h -| status_h;

    const transport = panel(shell, 0, transport_h, " Winamp ", sampleText(snapshot, app_state));
    drawTransport(transport, app_state, snapshot);

    if (spectrum_h > 0) {
        const spectrum = panel(shell, @intCast(transport_h), spectrum_h, " Spectrum ", "");
        drawSpectrum(spectrum, app_state, snapshot);
    }

    const playlist = panel(shell, @intCast(transport_h + spectrum_h), playlist_h, " Now ", "");
    drawPlaylist(playlist, app_state, snapshot);

    if (status_h > 0) {
        const status = panel(shell, @intCast(transport_h + spectrum_h + playlist_h), status_h, " Status ", "");
        drawStatus(status, app_state, snapshot);
    }
}

fn panel(parent: Window, y: i17, height: u16, title: []const u8, right: []const u8) Window {
    const palette: Palette = .{};
    const bordered = parent.child(.{
        .y_off = y,
        .height = height,
        .border = .{
            .where = .all,
            .glyphs = .single_square,
            .style = palette.border,
        },
    });
    if (height > 1) {
        _ = parent.printSegment(.{ .text = title, .style = palette.title }, .{ .row_offset = @intCast(@max(y, 0)), .col_offset = 2, .wrap = .none });
        if (right.len > 0 and parent.width > right.len + 4) {
            const col: u16 = @intCast(parent.width - right.len - 2);
            _ = parent.printSegment(.{ .text = right, .style = palette.muted }, .{ .row_offset = @intCast(@max(y, 0)), .col_offset = col, .wrap = .none });
        }
    }
    return bordered;
}

fn drawTransport(win: Window, app_state: App, snapshot: PlayerSnapshot) void {
    const palette = app_state.palette;
    win.fill(.{ .style = palette.panel });
    const track = presets[snapshot.playing_index];

    const state_style = stateStyle(palette, snapshot.state);
    const state_label = stateLabel(snapshot.state);
    const live = if (app_state.ascii) "*" else "●";

    const row0 = [_]Segment{
        .{ .text = track.source, .style = palette.muted },
        .{ .text = " ", .style = palette.panel },
        .{ .text = track.title, .style = palette.title },
    };
    _ = win.print(&row0, .{ .row_offset = 0, .col_offset = 1, .wrap = .none });
    printRight(win, 0, &.{
        .{ .text = state_label, .style = state_style },
        .{ .text = "  ", .style = palette.panel },
        .{ .text = snapshot.bitrate, .style = palette.amber },
        .{ .text = "  ", .style = palette.panel },
        .{ .text = live, .style = state_style },
    });

    var time_buf: [16]u8 = undefined;
    const time_text = std.fmt.bufPrint(&time_buf, "{d:0>2}:{d:0>2}:{d:0>2}", .{
        snapshot.elapsed_seconds / 3600,
        (snapshot.elapsed_seconds / 60) % 60,
        snapshot.elapsed_seconds % 60,
    }) catch "00:00:00";
    _ = win.printSegment(.{ .text = time_text, .style = palette.cyan }, .{ .row_offset = 1, .col_offset = 1, .wrap = .none });
    drawMeter(win, 12, 1, win.width / 2, snapshot.level_percent, palette.green, app_state.ascii);

    var vol_buf: [8]u8 = undefined;
    const vol_text = std.fmt.bufPrint(&vol_buf, "VOL {d:0>3}", .{snapshot.volume_percent}) catch "VOL";
    const vol_col = if (win.width > 28) win.width - 28 else 1;
    _ = win.printSegment(.{ .text = vol_text, .style = palette.amber }, .{ .row_offset = 1, .col_offset = vol_col, .wrap = .none });
    drawMeter(win, vol_col + 8, 1, 16, snapshot.volume_percent, palette.amber, app_state.ascii);

    const controls = if (app_state.ascii) "[<<] [■] [>/||] [R]" else "[◀] [■] [▶/Ⅱ] [↻]";
    _ = win.printSegment(.{ .text = controls, .style = state_style }, .{ .row_offset = @min(@as(u16, 2), win.height -| 1), .col_offset = 1, .wrap = .none });
    printRight(win, @min(@as(u16, 2), win.height -| 1), &.{.{ .text = snapshot.device_name, .style = palette.muted }});

    if (win.height > 3) {
        const hint = "Enter play  Space pause  s stop  r reconnect  +/- volume  q quit";
        _ = win.printSegment(.{ .text = hint, .style = palette.muted }, .{ .row_offset = 3, .col_offset = 1, .wrap = .none });
    }
}

fn drawSpectrum(win: Window, app_state: App, snapshot: PlayerSnapshot) void {
    const palette = app_state.palette;
    win.fill(.{ .style = palette.panel });
    if (win.height == 0 or win.width == 0) return;

    const bars = @min(@as(u16, 64), @max(@as(u16, 8), win.width -| 2));
    const max_h = win.height -| 1;
    var col: u16 = 1;
    while (col <= bars and col < win.width) : (col += 1) {
        const value = spectrumValue(app_state.frame, col, snapshot.state, snapshot.level_percent);
        const bar_h: u16 = @intCast((@as(u32, value) * @as(u32, @max(max_h, 1))) / 100);
        const style = if (snapshot.state == .paused or snapshot.state == .stopped) palette.muted else if (value > 78) palette.amber else palette.green;
        var row: u16 = 0;
        while (row < max_h) : (row += 1) {
            const fill = max_h - row <= bar_h;
            const glyph = if (app_state.ascii) "|" else if (fill and row == max_h -| 1) lowerBlock(value) else "█";
            if (fill) win.writeCell(col, row, .{ .char = .{ .grapheme = glyph, .width = 1 }, .style = style });
        }
    }

    const footer = switch (snapshot.state) {
        .playing => "output analyzer",
        .paused => "paused spectrum",
        .buffering => "buffering pulse",
        .stopped => "stopped",
        .failed => "retry with r",
    };
    _ = win.printSegment(.{ .text = footer, .style = stateStyle(palette, snapshot.state) }, .{ .row_offset = win.height -| 1, .col_offset = 1, .wrap = .none });
}

fn drawPlaylist(win: Window, app_state: App, snapshot: PlayerSnapshot) void {
    const palette = app_state.palette;
    win.fill(.{ .style = palette.panel });
    if (win.height == 0) return;

    const visible = @min(@as(usize, win.height), presets.len);
    const start = if (snapshot.selected_index >= visible) snapshot.selected_index + 1 - visible else 0;
    for (0..visible) |offset| {
        const idx = start + offset;
        if (idx >= presets.len) break;
        const preset = presets[idx];
        const row: u16 = @intCast(offset);
        const is_selected = idx == snapshot.selected_index;
        const is_playing = idx == snapshot.playing_index;
        const style = if (is_selected) palette.selected else if (is_playing) palette.active else palette.panel;
        fillRow(win, row, style);

        const mark = if (is_playing) (if (app_state.ascii) ">" else "▶") else " ";
        _ = win.printSegment(.{ .text = mark, .style = style }, .{ .row_offset = row, .col_offset = 1, .wrap = .none });
        _ = win.printSegment(.{ .text = preset.title, .style = style }, .{ .row_offset = row, .col_offset = 3, .wrap = .none });
        if (win.width >= 58) {
            _ = win.printSegment(.{ .text = preset.source, .style = style }, .{ .row_offset = row, .col_offset = 27, .wrap = .none });
            _ = win.printSegment(.{ .text = preset.format, .style = style }, .{ .row_offset = row, .col_offset = 41, .wrap = .none });
            _ = win.printSegment(.{ .text = preset.bitrate, .style = style }, .{ .row_offset = row, .col_offset = 48, .wrap = .none });
            _ = win.printSegment(.{ .text = preset.kind, .style = style }, .{ .row_offset = row, .col_offset = 56, .wrap = .none });
        } else if (win.width >= 38) {
            _ = win.printSegment(.{ .text = preset.source, .style = style }, .{ .row_offset = row, .col_offset = 24, .wrap = .none });
        }
    }
}

fn drawStatus(win: Window, app_state: App, snapshot: PlayerSnapshot) void {
    const palette = app_state.palette;
    win.fill(.{ .style = palette.panel });
    if (win.height == 0) return;

    const style = stateStyle(palette, snapshot.state);
    const separator = if (app_state.ascii) " | " else " · ";
    _ = win.print(&.{
        .{ .text = snapshot.buffer_health, .style = style },
        .{ .text = separator, .style = palette.muted },
        .{ .text = "decoder ", .style = palette.muted },
        .{ .text = snapshot.decoder, .style = palette.cyan },
        .{ .text = separator, .style = palette.muted },
        .{ .text = "buffer ", .style = palette.muted },
        .{ .text = bufferText(snapshot.buffer_percent), .style = palette.amber },
        .{ .text = separator, .style = palette.muted },
        .{ .text = snapshot.callback_health, .style = if (snapshot.state == .failed) palette.red else palette.green },
    }, .{ .row_offset = 0, .col_offset = 1, .wrap = .none });
    if (win.height > 1 and snapshot.state == .failed) {
        _ = win.printSegment(.{ .text = "[r] retry stream", .style = palette.red }, .{ .row_offset = 1, .col_offset = 1, .wrap = .none });
    }
}

fn drawMeter(win: Window, col: u16, row: u16, width: u16, percent: u8, style: Style, ascii: bool) void {
    const bounded_width = @min(width, win.width -| col);
    const filled: u16 = @intCast((@as(u32, bounded_width) * percent) / 100);
    var i: u16 = 0;
    while (i < bounded_width) : (i += 1) {
        const is_filled = i < filled;
        const glyph = if (ascii) (if (is_filled) "#" else "-") else (if (is_filled) "▰" else "▱");
        win.writeCell(col + i, row, .{
            .char = .{ .grapheme = glyph, .width = 1 },
            .style = if (is_filled) style else .{ .fg = .{ .rgb = .{ 0x50, 0x5a, 0x66 } }, .bg = .{ .rgb = .{ 0x11, 0x16, 0x1f } } },
        });
    }
}

fn printRight(win: Window, row: u16, segments: []const Segment) void {
    var width: u16 = 0;
    for (segments) |segment| width +|= win.gwidth(segment.text);
    if (width + 1 >= win.width) return;
    _ = win.print(segments, .{ .row_offset = row, .col_offset = win.width - width - 1, .wrap = .none });
}

fn fillRow(win: Window, row: u16, style: Style) void {
    var col: u16 = 0;
    while (col < win.width) : (col += 1) {
        win.writeCell(col, row, .{ .style = style });
    }
}

fn stateLabel(state: PlaybackState) []const u8 {
    return switch (state) {
        .playing => "LIVE",
        .paused => "PAUSED",
        .buffering => "BUFFER",
        .stopped => "STOP",
        .failed => "ERROR",
    };
}

fn stateStyle(palette: Palette, state: PlaybackState) Style {
    return switch (state) {
        .playing => palette.green,
        .paused, .stopped => palette.amber,
        .buffering => palette.cyan,
        .failed => palette.red,
    };
}

fn sampleText(snapshot: PlayerSnapshot, app_state: App) []const u8 {
    _ = app_state;
    return if (snapshot.channels == 2) "44.1kHz Stereo" else "44.1kHz Mono";
}

fn playlistCountText() []const u8 {
    return "5 items";
}

fn spectrumValue(frame: u32, col: u16, state: PlaybackState, level: u8) u8 {
    if (state == .stopped) return 0;
    if (state == .failed) return if (col % 8 == 0) 18 else 4;
    const moving = if (state == .paused) 42 else frame;
    const a = (moving * 13 + @as(u32, col) * 17) % 100;
    const b = (moving * 5 + @as(u32, col) * @as(u32, col)) % 80;
    const base: u8 = @intCast((a + b + @as(u32, level) * 2) / 4);
    return switch (state) {
        .buffering => @min(@as(u8, 45), base / 2 + @as(u8, @intCast((moving + col) % 18))),
        .paused => @max(@as(u8, 4), base / 4),
        else => @max(@as(u8, 4), base),
    };
}

fn bufferText(percent: u8) []const u8 {
    if (percent >= 75) return "full";
    if (percent >= 30) return "good";
    if (percent >= 5) return "low";
    return "empty";
}

fn lowerBlock(value: u8) []const u8 {
    return if (value > 87)
        "█"
    else if (value > 72)
        "▇"
    else if (value > 56)
        "▆"
    else if (value > 42)
        "▅"
    else if (value > 28)
        "▃"
    else
        "▁";
}

test "playlist count remains stable" {
    try std.testing.expectEqual(@as(usize, 5), presets.len);
}
