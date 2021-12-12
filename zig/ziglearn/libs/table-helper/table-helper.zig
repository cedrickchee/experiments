const std = @import("std");

pub fn Table(comptime headers: []const []const u8) type {
    return struct {
        data: []const [headers.len][]const u8,
        pub fn format(
            self: @This(),
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = options;
            _ = fmt;
            _ = options;
            _ = fmt;
            var max_row_len = comptime blk: {
                var tmp: []const usize = &[_]usize{};
                inline for (headers) |header| {
                    tmp = tmp ++ [_]usize{header.len};
                }
                var new: [tmp.len]usize = undefined;
                std.mem.copy(usize, &new, tmp);
                break :blk new;
            };

            for (self.data) |row| {
                for (row) |col, i| {
                    if (col.len > max_row_len[i]) {
                        max_row_len[i] = col.len;
                    }
                }
            }

            inline for (headers) |header, i| {
                _ = header;
                try writer.writeAll(header);
                var j: usize = 1 + max_row_len[i] - header.len;
                while (j > 0) {
                    try writer.writeAll(" ");
                    j -= 1;
                }
            }

            try writer.writeAll("\n");

            inline for (headers) |header, i| {
                _ = header;
                var j: usize = max_row_len[i];
                while (j > 0) {
                    try writer.writeAll("-");
                    j -= 1;
                }
                try writer.writeAll(" ");
            }

            try writer.writeAll("\n");

            for (self.data) |d, i| {
                for (d) |column, j| {
                    try writer.writeAll(column);
                    var k: usize = 1 + max_row_len[j] - column.len;
                    while (k > 0) {
                        try writer.writeAll(" ");
                        k -= 1;
                    }
                }
                if (i < self.data.len - 1) try writer.writeAll("\n");
            }
        }
    };
}
