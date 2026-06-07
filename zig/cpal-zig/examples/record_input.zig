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

const Meter = struct {
    const Snapshot = struct {
        peak: f32,
        frames: usize,
        errors: usize,
    };

    lock_value: SpinLock = .{},
    channels: u16,
    peak: f32 = 0,
    frames: usize = 0,
    errors: usize = 0,

    fn callback(buffer: []const f32, info: cpal.InputCallbackInfo, userdata: ?*anyopaque) void {
        _ = info;
        const meter: *Meter = @ptrCast(@alignCast(userdata.?));
        var peak: f32 = 0;
        for (buffer) |sample| peak = @max(peak, @abs(sample));

        meter.lock_value.lock();
        defer meter.lock_value.unlock();
        meter.peak = @max(meter.peak, peak);
        meter.frames += buffer.len / @as(usize, @max(meter.channels, 1));
    }

    fn errorCallback(err: cpal.AudioError, userdata: ?*anyopaque) void {
        if (@errorName(err).len == 0) unreachable;
        const meter: *Meter = @ptrCast(@alignCast(userdata.?));
        meter.lock_value.lock();
        defer meter.lock_value.unlock();
        meter.errors += 1;
    }

    fn readAndReset(self: *Meter) Snapshot {
        self.lock_value.lock();
        defer self.lock_value.unlock();
        const snapshot: Snapshot = .{ .peak = self.peak, .frames = self.frames, .errors = self.errors };
        self.peak = 0;
        self.frames = 0;
        return snapshot;
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

    var device = (try host.defaultInputDevice(allocator)) orelse {
        try stdout.print("No input device available.\n", .{});
        return;
    };
    defer device.deinit(allocator);

    const stream_config = (try device.defaultInputConfig()).config();
    var meter = Meter{ .channels = stream_config.channels };
    var input_stream = try device.buildInputStreamF32(
        stream_config,
        Meter.callback,
        &meter,
        Meter.errorCallback,
        &meter,
    );
    defer input_stream.deinit();

    const buffer_size = try input_stream.bufferSize();
    try input_stream.play();
    try stdout.print(
        "Recording from {s}: {d} channels at {d} Hz, buffer={d} frames.\n",
        .{ device.info().name, stream_config.channels, stream_config.sample_rate, buffer_size },
    );

    var tick: usize = 0;
    while (tick < 10) : (tick += 1) {
        sleepNs(200 * std.time.ns_per_ms);
        const snapshot = meter.readAndReset();
        try stdout.print(
            "  peak={d:.4}, frames={d}, callback_errors={d}\n",
            .{ snapshot.peak, snapshot.frames, snapshot.errors },
        );
    }

    try input_stream.pause();
}
