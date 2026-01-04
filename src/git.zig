const std = @import("std");
const array_list = std.array_list;
const color = @import("color.zig");
const config = @import("config.zig");

pub const GitStatus = struct {
    branch: ?[]const u8 = null,
    ahead: usize = 0,
    behind: usize = 0,
    index_changes: usize = 0,
    wt_changes: usize = 0,
    conflicted: usize = 0,
    untracked: usize = 0,
    action: ?[]const u8 = null,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *const GitStatus) void {
        if (self.branch) |b| self.allocator.free(b);
        if (self.action) |a| self.allocator.free(a);
    }
};

fn findGitRepo(cwd: []const u8) ?[]const u8 {
    var path = cwd;
    while (path.len > 0) {
        const git_dir = std.fmt.allocPrint(std.heap.page_allocator, "{s}/.git", .{path}) catch return null;
        defer std.heap.page_allocator.free(git_dir);

        if (std.fs.openFileAbsolute(git_dir, .{})) |file| {
            file.close();
            return path;
        } else |_| {}

        const last_sep = if (std.mem.lastIndexOfScalar(u8, path, std.fs.path.sep)) |i| i else break;
        if (last_sep == 0) break;
        path = path[0..last_sep];
    }
    return null;
}

fn getHeadShortname(allocator: std.mem.Allocator, git_dir: []const u8) !?[]const u8 {
    const head_path = try std.fmt.allocPrint(allocator, "{s}/HEAD", .{git_dir});
    defer allocator.free(head_path);
    const head_file = try std.fs.openFileAbsolute(head_path, .{});
    defer head_file.close();

    const content = try head_file.readToEndAlloc(allocator, 1024);
    defer allocator.free(content);

    if (std.mem.startsWith(u8, content, "ref: refs/heads/")) {
        const line_end = std.mem.indexOfScalar(u8, content, '\n') orelse content.len;
        return try allocator.dupe(u8, content[16..line_end]);
    }

    const hash = std.mem.trim(u8, content, &std.ascii.whitespace);
    if (hash.len > 7) {
        return try std.fmt.allocPrint(allocator, ":{s}", .{hash[0..7]});
    }
    return null;
}

fn checkGitFile(allocator: std.mem.Allocator, git_dir: []const u8, comptime suffix: []const u8) bool {
    const path = std.fmt.allocPrint(allocator, "{s}" ++ suffix, .{git_dir}) catch return false;
    defer allocator.free(path);
    const file = std.fs.openFileAbsolute(path, .{}) catch return false;
    file.close();
    return true;
}

fn getGitAction(allocator: std.mem.Allocator, git_dir: []const u8) !?[]const u8 {
    if (checkGitFile(allocator, git_dir, "/rebase-apply/rebasing")) return try allocator.dupe(u8, "rebase");
    if (checkGitFile(allocator, git_dir, "/rebase-apply/applying")) return try allocator.dupe(u8, "am");
    if (checkGitFile(allocator, git_dir, "/rebase-apply")) return try allocator.dupe(u8, "am/rebase");
    if (checkGitFile(allocator, git_dir, "/rebase-merge/interactive")) return try allocator.dupe(u8, "rebase-i");
    if (checkGitFile(allocator, git_dir, "/rebase-merge")) return try allocator.dupe(u8, "rebase-m");
    if (checkGitFile(allocator, git_dir, "/MERGE_HEAD")) return try allocator.dupe(u8, "merge");
    if (checkGitFile(allocator, git_dir, "/BISECT_LOG")) return try allocator.dupe(u8, "bisect");
    if (checkGitFile(allocator, git_dir, "/CHERRY_PICK_HEAD")) {
        if (checkGitFile(allocator, git_dir, "/sequencer")) return try allocator.dupe(u8, "cherry-seq");
        return try allocator.dupe(u8, "cherry");
    }
    if (checkGitFile(allocator, git_dir, "/sequencer")) return try allocator.dupe(u8, "cherry-or-revert");

    return null;
}

fn countGitStatus(allocator: std.mem.Allocator, git_dir: []const u8) !struct { index: usize, wt: usize, conflicted: usize, untracked: usize } {
    _ = allocator;
    _ = git_dir;
    return .{ 0, 0, 0, 0 };
}

pub fn getRepoStatus(allocator: std.mem.Allocator, cwd: []const u8, cfg: config.Config) !?GitStatus {
    const repo_path = findGitRepo(cwd) orelse return null;
    const git_dir = try std.fmt.allocPrint(allocator, "{s}/.git", .{repo_path});
    defer allocator.free(git_dir);

    var status = GitStatus{ .allocator = allocator };
    errdefer status.deinit();

    status.branch = getHeadShortname(allocator, git_dir) catch null;

    if (cfg.detailed_git) {
        status.action = getGitAction(allocator, git_dir) catch null;
    }

    return status;
}

pub fn formatGitStatus(allocator: std.mem.Allocator, status: GitStatus, cfg: config.Config) ![]const u8 {
    const PartsList = array_list.AlignedManaged([]const u8, null);
    var parts = PartsList.init(allocator);
    defer {
        for (parts.items) |p| allocator.free(p);
        parts.deinit();
    }

    if (status.branch) |branch| {
        try parts.append(try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ color.Color.fg(color.Color.cyan), branch, color.reset }));
    }

    if (!cfg.detailed_git) {
        const has_changes = status.index_changes > 0 or status.wt_changes > 0 or status.conflicted > 0 or status.untracked > 0;
        if (has_changes) {
            try parts.append(try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ color.Color.bold(color.Color.red), cfg.icons.conflicted, color.reset }));
        }
    } else {
        if (status.ahead > 0) {
            try parts.append(try std.fmt.allocPrint(allocator, "{s}{s}{d}{s}", .{ color.Color.fg(color.Color.cyan), cfg.icons.ahead, status.ahead, color.reset }));
        }
        if (status.behind > 0) {
            try parts.append(try std.fmt.allocPrint(allocator, "{s}{s}{d}{s}", .{ color.Color.fg(color.Color.cyan), cfg.icons.behind, status.behind, color.reset }));
        }

        const clean = status.index_changes == 0 and status.wt_changes == 0 and status.conflicted == 0 and status.untracked == 0;
        if (clean) {
            try parts.append(try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ color.Color.fg(color.Color.green), cfg.icons.clean, color.reset }));
        } else {
            if (status.index_changes > 0) {
                try parts.append(try std.fmt.allocPrint(allocator, "{s}{s}{d}{s}", .{ color.Color.fg(color.Color.green), cfg.icons.staged, status.index_changes, color.reset }));
            }
            if (status.conflicted > 0) {
                try parts.append(try std.fmt.allocPrint(allocator, "{s}{s}{d}{s}", .{ color.Color.fg(color.Color.red), cfg.icons.conflicted, status.conflicted, color.reset }));
            }
            if (status.wt_changes > 0) {
                try parts.append(try std.fmt.allocPrint(allocator, "{s}{d}", .{ cfg.icons.modified, status.wt_changes }));
            }
            if (status.untracked > 0) {
                try parts.append(try allocator.dupe(u8, cfg.icons.untracked));
            }
        }

        if (status.action) |action| {
            try parts.append(try std.fmt.allocPrint(allocator, "{s}{s}{s}{s}", .{ config.GIT_ICONS.separator, color.Color.fg(color.Color.magenta), action, color.reset }));
        }
    }

    const ResultList = array_list.AlignedManaged(u8, null);
    var result = ResultList.init(allocator);
    for (parts.items, 0..) |part, i| {
        if (i > 0) try result.appendSlice(config.GIT_ICONS.separator);
        try result.appendSlice(part);
    }

    return result.toOwnedSlice();
}
