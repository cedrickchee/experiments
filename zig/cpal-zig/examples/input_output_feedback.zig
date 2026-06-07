const std = @import("std");
const cpal = @import("cpal_zig");

const SpinLock = struct {
    locked: std.atomic.Value(bool) = .init(false),

    fn lock(self: *SpinLock) void {
        while (self.locked.swap(true, .acquire)) {
            std.atomic.spinLoopHint();
        }
    }

    fn unlock(self: *SpinLock) void {
        self.locked.store(false, .release);
    }
};

fn sleepNs(ns: u64) void {
    var ts = std.os.linux.timespec{
        .sec = @intCast(ns / std.time.ns_per_s),
        .nsec = @intCast(ns % std.time.ns_per_s),
    };
    _ = std.os.linux.nanosleep(&ts, null);
}

const FeedbackState = struct {
    const Snapshot = struct {
        queued: usize,
        dropped: usize,
        underruns: usize,
        errors: usize,
    };

    lock_value: SpinLock = .{},
    ring: []f32,
    read_index: usize = 0,
    write_index: usize = 0,
    available: usize = 0,
    dropped: usize = 0,
    underruns: usize = 0,
    errors: usize = 0,

    fn push(self: *FeedbackState, sample: f32) void {
        if (self.available == self.ring.len) {
            self.read_index = (self.read_index + 1) % self.ring.len;
            self.available -= 1;
            self.dropped += 1;
        }
        self.ring[self.write_index] = sample;
        self.write_index = (self.write_index + 1) % self.ring.len;
        self.available += 1;
    }

    fn pop(self: *FeedbackState) ?f32 {
        if (self.available == 0) return null;
        const sample = self.ring[self.read_index];
        self.read_index = (self.read_index + 1) % self.ring.len;
        self.available -= 1;
        return sample;
    }

    fn inputCallback(buffer: []const f32, info: cpal.InputCallbackInfo, userdata: ?*anyopaque) void {
        _ = info;
        const state: *FeedbackState = @ptrCast(@alignCast(userdata.?));
        state.lock_value.lock();
        defer state.lock_value.unlock();
        for (buffer) |sample| state.push(sample);
    }

    fn outputCallback(buffer: []f32, info: cpal.OutputCallbackInfo, userdata: ?*anyopaque) void {
        _ = info;
        const state: *FeedbackState = @ptrCast(@alignCast(userdata.?));
        state.lock_value.lock();
        defer state.lock_value.unlock();
        for (buffer) |*sample| {
            sample.* = if (state.pop()) |value| value * 0.35 else underrun: {
                state.underruns += 1;
                break :underrun 0;
            };
        }
    }

    fn errorCallback(err: cpal.AudioError, userdata: ?*anyopaque) void {
        if (@errorName(err).len == 0) unreachable;
        const state: *FeedbackState = @ptrCast(@alignCast(userdata.?));
        state.lock_value.lock();
        defer state.lock_value.unlock();
        state.errors += 1;
    }

    fn snapshot(self: *FeedbackState) Snapshot {
        self.lock_value.lock();
        defer self.lock_value.unlock();
        return .{
            .queued = self.available,
            .dropped = self.dropped,
            .underruns = self.underruns,
            .errors = self.errors,
        };
    }
};

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const io = init.io;

    var stdout_buffer: [2048]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout = &stdout_file_writer.interface;
    defer stdout.flush() catch {};

    var host = try cpal.defaultHost();
    defer host.deinit(allocator);

    var input_device = (try host.defaultInputDevice(allocator)) orelse {
        try stdout.print("No input device available.\n", .{});
        return;
    };
    defer input_device.deinit(allocator);

    var output_device = (try host.defaultOutputDevice(allocator)) orelse {
        try stdout.print("No output device available.\n", .{});
        return;
    };
    defer output_device.deinit(allocator);

    const output_capabilities = try output_device.supportedOutputCapabilities(allocator);
    const input_capabilities = try input_device.supportedInputCapabilities(allocator);
    const shared_config = (try cpal.negotiateSharedStreamCapability(
        output_capabilities,
        input_capabilities,
        .{ .sample_formats = &.{.f32} },
    )).config;

    const ring_samples = @as(usize, shared_config.sample_rate) * shared_config.channels;
    const ring = try allocator.alloc(f32, ring_samples);
    @memset(ring, 0);
    var state = FeedbackState{ .ring = ring };

    var input_stream = try input_device.buildInputStreamF32(
        shared_config,
        FeedbackState.inputCallback,
        &state,
        FeedbackState.errorCallback,
        &state,
    );
    defer input_stream.deinit();

    var output_stream = try output_device.buildOutputStreamF32(
        shared_config,
        FeedbackState.outputCallback,
        &state,
        FeedbackState.errorCallback,
        &state,
    );
    defer output_stream.deinit();

    try input_stream.play();
    try output_stream.play();
    try stdout.print(
        "Monitoring {s} -> {s}: {d} channels at {d} Hz.\n",
        .{ input_device.info().name, output_device.info().name, shared_config.channels, shared_config.sample_rate },
    );

    var tick: usize = 0;
    while (tick < 10) : (tick += 1) {
        sleepNs(200 * std.time.ns_per_ms);
        const stats = state.snapshot();
        try stdout.print(
            "  queued={d}, dropped={d}, underruns={d}, callback_errors={d}\n",
            .{ stats.queued, stats.dropped, stats.underruns, stats.errors },
        );
    }

    try output_stream.pause();
    try input_stream.pause();
}
