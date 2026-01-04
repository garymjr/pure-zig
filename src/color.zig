const std = @import("std");

pub const Color = enum {
    black,
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    white,

    pub fn fg(self: Color) []const u8 {
        const codes = [_][]const u8{
            "\x1b[30m", "\x1b[31m", "\x1b[32m", "\x1b[33m",
            "\x1b[34m", "\x1b[35m", "\x1b[36m", "\x1b[37m",
        };
        return codes[@intFromEnum(self)];
    }

    pub fn fgBright(self: Color) []const u8 {
        const codes = [_][]const u8{
            "\x1b[90m", "\x1b[91m", "\x1b[92m", "\x1b[93m",
            "\x1b[94m", "\x1b[95m", "\x1b[96m", "\x1b[97m",
        };
        return codes[@intFromEnum(self)];
    }

    pub fn bg(self: Color) []const u8 {
        const codes = [_][]const u8{
            "\x1b[40m", "\x1b[41m", "\x1b[42m", "\x1b[43m",
            "\x1b[44m", "\x1b[45m", "\x1b[46m", "\x1b[47m",
        };
        return codes[@intFromEnum(self)];
    }

    pub fn bold(self: Color) []const u8 {
        const codes = [_][]const u8{
            "\x1b[1;30m", "\x1b[1;31m", "\x1b[1;32m", "\x1b[1;33m",
            "\x1b[1;34m", "\x1b[1;35m", "\x1b[1;36m", "\x1b[1;37m",
        };
        return codes[@intFromEnum(self)];
    }
};

pub const reset = "\x1b[0m";
