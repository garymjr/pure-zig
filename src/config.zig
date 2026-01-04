const std = @import("std");

pub const GIT_ICONS = struct {
    pub const ahead = "↑";
    pub const behind = "↓";
    pub const clean = "✔";
    pub const staged = "♦";
    pub const conflicted = "✖";
    pub const modified = "✚";
    pub const untracked = "…";
    pub const dirty = "*";
    pub const separator = " ";
};

pub const Config = struct {
    detailed_git: bool = true,
    icons: struct {
        ahead: []const u8 = GIT_ICONS.ahead,
        behind: []const u8 = GIT_ICONS.behind,
        clean: []const u8 = GIT_ICONS.clean,
        staged: []const u8 = GIT_ICONS.staged,
        conflicted: []const u8 = GIT_ICONS.conflicted,
        modified: []const u8 = GIT_ICONS.modified,
        untracked: []const u8 = GIT_ICONS.untracked,
    } = .{},
};

pub fn readConfigFromEnv(allocator: std.mem.Allocator) !Config {
    var config = Config{};

    if (std.process.getEnvVarOwned(allocator, "PURE_DETAILED_GIT")) |val| {
        defer allocator.free(val);
        config.detailed_git = std.mem.eql(u8, val, "1") or std.mem.eql(u8, val, "true");
    } else |_| {}

    const icon_vars = [_]struct { []const u8, *[]const u8 }{
        .{ "PURE_ICON_AHEAD", &config.icons.ahead },
        .{ "PURE_ICON_BEHIND", &config.icons.behind },
        .{ "PURE_ICON_CLEAN", &config.icons.clean },
        .{ "PURE_ICON_STAGED", &config.icons.staged },
        .{ "PURE_ICON_CONFLICTED", &config.icons.conflicted },
        .{ "PURE_ICON_MODIFIED", &config.icons.modified },
        .{ "PURE_ICON_UNTRACKED", &config.icons.untracked },
    };

    for (icon_vars) |icon_var| {
        if (std.process.getEnvVarOwned(allocator, icon_var[0])) |val| {
            icon_var[1].* = val;
        } else |_| {}
    }

    return config;
}
