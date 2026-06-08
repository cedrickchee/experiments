const std = @import("std");
const vaxis = @import("vaxis");
const cpal = @import("cpal_zig");

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
};

const presets = [_]StreamPreset{
    .{ .title = "Groove Salad", .source = "SomaFM", .format = "mp3", .bitrate = "128k", .kind = "live" },
    .{ .title = "DEF CON Radio", .source = "SomaFM", .format = "mp3", .bitrate = "128k", .kind = "live" },
    .{ .title = "Drone Zone", .source = "SomaFM", .format = "mp3", .bitrate = "128k", .kind = "live" },
    .{ .title = "Beat Blender", .source = "SomaFM", .format = "aac", .bitrate = "128k", .kind = "live" },
    .{ .title = "Cliqhop IDM", .source = "SomaFM", .format = "mp3", .bitrate = "128k", .kind = "live" },
};

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
    device_name: []const u8 = "ALSA: default",

    fn snapshot(self: App) PlayerSnapshot {
        return .{
            .state = self.state,
            .selected_index = self.selected_index,
            .playing_index = self.playing_index,
            .elapsed_seconds = self.elapsed_seconds,
            .volume_percent = self.volume_percent,
            .sample_rate = 44_100,
            .channels = 2,
            .bitrate = presets[self.playing_index].bitrate,
            .device_name = self.device_name,
            .decoder = "ffmpeg",
            .callback_health = if (self.state == .failed) "retry available" else "output callback healthy",
            .buffer_health = switch (self.state) {
                .buffering => "buffering stable",
                .playing => "stream stable",
                .paused => "paused",
                .stopped => "stopped",
                .failed => "stream error",
            },
        };
    }

    fn tick(self: *App) void {
        self.frame +%= 1;
        if (self.state == .playing and self.frame % 30 == 0) self.elapsed_seconds +|= 1;
        if (self.state == .buffering and self.frame > 36) self.state = .playing;
    }

    fn handleKey(self: *App, key: vaxis.Key) bool {
        if (key.matches('q', .{}) or key.matches('c', .{ .ctrl = true })) return true;
        if (key.matches(vaxis.Key.down, .{})) {
            self.selected_index = @min(self.selected_index + 1, presets.len - 1);
        } else if (key.matches(vaxis.Key.up, .{})) {
            self.selected_index -|= 1;
        } else if (key.matches(vaxis.Key.enter, .{})) {
            self.playing_index = self.selected_index;
            self.elapsed_seconds = 0;
            self.state = .buffering;
        } else if (key.matches(vaxis.Key.space, .{})) {
            self.state = switch (self.state) {
                .playing => .paused,
                .paused, .stopped => .playing,
                .buffering => .paused,
                .failed => .buffering,
            };
        } else if (key.matches('s', .{})) {
            self.state = .stopped;
        } else if (key.matches('r', .{})) {
            self.state = .buffering;
            self.frame = 0;
        } else if (key.matches('+', .{}) or key.matches('=', .{})) {
            self.volume_percent = @min(self.volume_percent + 5, 100);
        } else if (key.matches('-', .{})) {
            self.volume_percent = self.volume_percent -| 5;
        } else if (key.matches('e', .{})) {
            self.state = .failed;
        }
        return false;
    }
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.gpa;

    var app_state: App = .{ .ascii = try shouldUseAscii(init, allocator) };
    var device_name_owned = false;
    if (detectDefaultOutputName(allocator)) |device_name| {
        app_state.device_name = device_name;
        device_name_owned = true;
    } else |_| {
        app_state.device_name = "ALSA: default";
    }
    defer if (device_name_owned) allocator.free(app_state.device_name);

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
                .key_press => |key| if (app_state.handleKey(key)) return,
                .winsize => |ws| try vx.resize(allocator, tty.writer(), ws),
                .focus_in => {},
            }
        }

        app_state.tick();
        try render(&vx, tty.writer(), app_state);
        try std.Io.sleep(io, .fromMilliseconds(33), .awake);
    }
}

fn shouldUseAscii(init: std.process.Init, allocator: std.mem.Allocator) !bool {
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, allocator);
    defer args.deinit();

    _ = args.next();
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--ascii")) return true;
    }
    return false;
}

fn detectDefaultOutputName(allocator: std.mem.Allocator) ![]const u8 {
    var host = try cpal.defaultHost();
    defer host.deinit(allocator);
    var device = (try host.defaultOutputDevice(allocator)) orelse return allocator.dupe(u8, "ALSA: default");
    defer device.deinit(allocator);
    return std.fmt.allocPrint(allocator, "{s}: {s}", .{ device.info().host.stableName(), device.info().name });
}

fn render(vx: *vaxis.Vaxis, tty: *std.Io.Writer, app_state: App) !void {
    const root = vx.window();
    root.hideCursor();
    root.fill(.{ .style = app_state.palette.bg });

    const snapshot = app_state.snapshot();
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
    drawMeter(win, 12, 1, win.width / 2, levelForFrame(app_state.frame, snapshot.state), palette.green, app_state.ascii);

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
        const value = spectrumValue(app_state.frame, col, snapshot.state);
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

fn levelForFrame(frame: u32, state: PlaybackState) u8 {
    return switch (state) {
        .playing => 45 + @as(u8, @intCast((frame * 7) % 42)),
        .buffering => 22 + @as(u8, @intCast((frame * 5) % 24)),
        .paused => 38,
        .stopped => 0,
        .failed => 8,
    };
}

fn spectrumValue(frame: u32, col: u16, state: PlaybackState) u8 {
    if (state == .stopped) return 0;
    if (state == .failed) return if (col % 8 == 0) 18 else 4;
    const moving = if (state == .paused) 42 else frame;
    const a = (moving * 13 + @as(u32, col) * 17) % 100;
    const b = (moving * 5 + @as(u32, col) * @as(u32, col)) % 80;
    const base: u8 = @intCast((a + b) / 2);
    return switch (state) {
        .buffering => @min(@as(u8, 55), base / 2 + @as(u8, @intCast((moving + col) % 25))),
        .paused => @max(@as(u8, 8), base / 3),
        else => @max(@as(u8, 12), base),
    };
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
