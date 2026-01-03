const std = @import("std");
const array_list = std.array_list;

const ARROW_SYMBOL = "➜";
const INSERT_SYMBOL = "❯";
const COMMAND_SYMBOL = "⬢";
const JOB_SYMBOL = "●";
const COMMAND_KEYMAP = "vicmd";

const Color = enum {
    black,
    red,
    green,
    yellow,
    blue,
    magenta,
    cyan,
    white,

    fn fg(self: Color) []const u8 {
        const codes = [_][]const u8{
            "\x1b[30m", "\x1b[31m", "\x1b[32m", "\x1b[33m",
            "\x1b[34m", "\x1b[35m", "\x1b[36m", "\x1b[37m",
        };
        return codes[@intFromEnum(self)];
    }

    fn fgBright(self: Color) []const u8 {
        const codes = [_][]const u8{
            "\x1b[90m", "\x1b[91m", "\x1b[92m", "\x1b[93m",
            "\x1b[94m", "\x1b[95m", "\x1b[96m", "\x1b[97m",
        };
        return codes[@intFromEnum(self)];
    }

    fn bg(self: Color) []const u8 {
        const codes = [_][]const u8{
            "\x1b[40m", "\x1b[41m", "\x1b[42m", "\x1b[43m",
            "\x1b[44m", "\x1b[45m", "\x1b[46m", "\x1b[47m",
        };
        return codes[@intFromEnum(self)];
    }

    fn bold(self: Color) []const u8 {
        const codes = [_][]const u8{
            "\x1b[1;30m", "\x1b[1;31m", "\x1b[1;32m", "\x1b[1;33m",
            "\x1b[1;34m", "\x1b[1;35m", "\x1b[1;36m", "\x1b[1;37m",
        };
        return codes[@intFromEnum(self)];
    }
};

const reset = "\x1b[0m";

fn promptCommand(allocator: std.mem.Allocator, last_return_code: []const u8, keymap: []const u8, venv_name: []const u8, job_count: usize) !void {
    const symbol = if (std.mem.eql(u8, keymap, COMMAND_KEYMAP)) COMMAND_SYMBOL else INSERT_SYMBOL;

    const shell_color: Color = blk: {
        if (std.mem.eql(u8, symbol, COMMAND_SYMBOL)) break :blk Color.yellow;
        if (std.mem.eql(u8, last_return_code, "0")) break :blk Color.magenta;
        break :blk Color.red;
    };

    const venv = if (venv_name.len > 0)
        try std.fmt.allocPrint(allocator, "{s}|{s}|{s} ", .{ Color.fgBright(Color.green), venv_name, reset })
    else
        "";

    defer if (venv.len > 0) allocator.free(venv);

    const jobs = if (job_count > 0)
        try std.fmt.allocPrint(allocator, "{s}{s}{d}{s} ", .{ Color.fgBright(Color.yellow), JOB_SYMBOL, job_count, reset })
    else
        "";

    defer if (jobs.len > 0) allocator.free(jobs);

    const stdout = std.fs.File.stdout().deprecatedWriter();
    try stdout.print("{s}{s}{s}{s}{s} ", .{ venv, jobs, Color.fgBright(shell_color), symbol, reset });
}

fn shortenPath(allocator: std.mem.Allocator, path: []const u8) ![]const u8 {
    const home_dir = try std.fs.path.resolve(allocator, &[_][]const u8{try std.process.getEnvVarOwned(allocator, "HOME")});
    defer allocator.free(home_dir);

    const friendly_path = if (std.mem.startsWith(u8, path, home_dir))
        try std.fmt.allocPrint(allocator, "~{s}", .{path[home_dir.len..]})
    else
        try allocator.dupe(u8, path);

    // Simple path shortening - replace each path component with first character,
    // except keep the final component intact
    var it = std.mem.splitScalar(u8, friendly_path, std.fs.path.sep);
    const PartsList = array_list.AlignedManaged([]const u8, null);
    var parts = PartsList.init(allocator);
    defer {
        for (parts.items) |p| allocator.free(p);
        parts.deinit();
    }

    const PartsList2 = array_list.AlignedManaged([]const u8, null);
    var all_parts = PartsList2.init(allocator);
    defer {
        for (all_parts.items) |p| allocator.free(p);
        all_parts.deinit();
    }

    while (it.next()) |part| {
        if (part.len == 0) continue;
        try all_parts.append(try allocator.dupe(u8, part));
    }

    const num_parts = all_parts.items.len;
    for (all_parts.items, 0..) |part, i| {
        if (i == 0) {
            // First component (e.g., "~" or drive letter) - keep as-is
            try parts.append(try allocator.dupe(u8, part));
        } else if (i == num_parts - 1) {
            // Last component - keep as-is
            try parts.append(try allocator.dupe(u8, part));
        } else {
            // Middle component - shorten to first character
            const shortened = try allocator.dupe(u8, part[0..1]);
            try parts.append(shortened);
        }
    }

    const result = try std.fs.path.join(allocator, parts.items);
    return result;
}

const GitStatus = struct {
    branch: ?[]const u8 = null,
    ahead: usize = 0,
    behind: usize = 0,
    index_changes: usize = 0,
    wt_changes: usize = 0,
    conflicted: usize = 0,
    untracked: usize = 0,
    action: ?[]const u8 = null,
    allocator: std.mem.Allocator,

    fn deinit(self: *const GitStatus) void {
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

    // Detached HEAD - show short commit hash
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

fn getRepoStatus(allocator: std.mem.Allocator, cwd: []const u8, detailed: bool) !?GitStatus {
    const repo_path = findGitRepo(cwd) orelse return null;
    const git_dir = try std.fmt.allocPrint(allocator, "{s}/.git", .{repo_path});
    defer allocator.free(git_dir);

    var status = GitStatus{ .allocator = allocator };
    errdefer status.deinit();

    status.branch = getHeadShortname(allocator, git_dir) catch null;

    if (detailed) {
        status.action = getGitAction(allocator, git_dir) catch null;
    }

    return status;
}

fn formatGitStatus(allocator: std.mem.Allocator, status: GitStatus, detailed: bool) ![]const u8 {
    const PartsList = array_list.AlignedManaged([]const u8, null);
    var parts = PartsList.init(allocator);
    defer {
        for (parts.items) |p| allocator.free(p);
        parts.deinit();
    }

    if (status.branch) |branch| {
        try parts.append(try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ Color.fg(Color.cyan), branch, reset }));
    }

    if (!detailed) {
        const has_changes = status.index_changes > 0 or status.wt_changes > 0 or status.conflicted > 0 or status.untracked > 0;
        if (has_changes) {
            try parts.append(try std.fmt.allocPrint(allocator, "{s}*{s}", .{ Color.bold(Color.red), reset }));
        }
    } else {
        if (status.ahead > 0) {
            try parts.append(try std.fmt.allocPrint(allocator, "{s}↑{d}{s}", .{ Color.fg(Color.cyan), status.ahead, reset }));
        }
        if (status.behind > 0) {
            try parts.append(try std.fmt.allocPrint(allocator, "{s}↓{d}{s}", .{ Color.fg(Color.cyan), status.behind, reset }));
        }

        const clean = status.index_changes == 0 and status.wt_changes == 0 and status.conflicted == 0 and status.untracked == 0;
        if (clean) {
            try parts.append(try std.fmt.allocPrint(allocator, "{s}✔{s}", .{ Color.fg(Color.green), reset }));
        } else {
            if (status.index_changes > 0) {
                try parts.append(try std.fmt.allocPrint(allocator, "{s}♦{d}{s}", .{ Color.fg(Color.green), status.index_changes, reset }));
            }
            if (status.conflicted > 0) {
                try parts.append(try std.fmt.allocPrint(allocator, "{s}✖{d}{s}", .{ Color.fg(Color.red), status.conflicted, reset }));
            }
            if (status.wt_changes > 0) {
                try parts.append(try std.fmt.allocPrint(allocator, "✚{d}", .{status.wt_changes}));
            }
            if (status.untracked > 0) {
                try parts.append(try allocator.dupe(u8, "…"));
            }
        }

        if (status.action) |action| {
            try parts.append(try std.fmt.allocPrint(allocator, " {s}{s}{s}", .{ Color.fg(Color.magenta), action, reset }));
        }
    }

    const ResultList = array_list.AlignedManaged(u8, null);
    var result = ResultList.init(allocator);
    for (parts.items, 0..) |part, i| {
        if (i > 0) try result.append(' ');
        try result.appendSlice(part);
    }

    return result.toOwnedSlice();
}

fn precmdCommand(allocator: std.mem.Allocator, detailed: bool) !void {
    const cwd = try std.fs.cwd().realpathAlloc(allocator, ".");
    defer allocator.free(cwd);

    const short_path = try shortenPath(allocator, cwd);
    defer allocator.free(short_path);

    const stdout = std.fs.File.stdout().deprecatedWriter();
    try stdout.print("\n{s}{s}{s}", .{ Color.fg(Color.blue), short_path, reset });

    if (try getRepoStatus(allocator, cwd, detailed)) |status| {
        defer status.deinit();
        const status_str = try formatGitStatus(allocator, status, detailed);
        defer allocator.free(status_str);
        if (status_str.len > 0) {
            try stdout.print(" {s}", .{status_str});
        }
    }

    try stdout.print("\n", .{});
}

fn printUsage(writer: anytype) !void {
    try writer.print(
        \\Pure - Pure-inspired prompt in Zig
        \\
        \\Usage:
        \\  pure prompt -r <return_code> -k <keymap> [--venv <name>] [-j <job_count>]
        \\  pure precmd [--git-detailed]
        \\
        \\Commands:
        \\  prompt    Generate the prompt line
        \\  precmd    Generate the pre-command line (directory + git status)
        \\
        \\Options:
        \\  prompt:
        \\    -r, --last-return-code  Last command return code
        \\    -k, --keymap            Vi keymap (vicmd for command mode)
        \\    --venv                  Python virtual environment name
        \\    -j, --jobs              Number of background jobs
        \\  precmd:
        \\    -d, --git-detailed      Show detailed git status
        \\
    , .{});
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try printUsage(std.fs.File.stdout().deprecatedWriter());
        return;
    }

    const command = args[1];
    var arg_idx: usize = 2;

    if (std.mem.eql(u8, command, "precmd")) {
        var detailed = false;
        while (arg_idx < args.len) : (arg_idx += 1) {
            if (std.mem.eql(u8, args[arg_idx], "--git-detailed") or std.mem.eql(u8, args[arg_idx], "-d")) {
                detailed = true;
            }
        }
        try precmdCommand(allocator, detailed);
    } else if (std.mem.eql(u8, command, "prompt")) {
        var last_return_code: []const u8 = "0";
        var keymap: []const u8 = "US";
        var venv_name: []const u8 = "";
        var job_count: usize = 0;

        while (arg_idx < args.len) : (arg_idx += 1) {
            if (std.mem.eql(u8, args[arg_idx], "-r") or std.mem.eql(u8, args[arg_idx], "--last-return-code")) {
                arg_idx += 1;
                if (arg_idx < args.len) last_return_code = args[arg_idx];
            } else if (std.mem.eql(u8, args[arg_idx], "-k") or std.mem.eql(u8, args[arg_idx], "--keymap")) {
                arg_idx += 1;
                if (arg_idx < args.len) keymap = args[arg_idx];
            } else if (std.mem.eql(u8, args[arg_idx], "--venv")) {
                arg_idx += 1;
                if (arg_idx < args.len) venv_name = args[arg_idx];
            } else if (std.mem.eql(u8, args[arg_idx], "-j") or std.mem.eql(u8, args[arg_idx], "--jobs")) {
                arg_idx += 1;
                if (arg_idx < args.len) job_count = std.fmt.parseInt(usize, args[arg_idx], 10) catch 0;
            }
        }
        try promptCommand(allocator, last_return_code, keymap, venv_name, job_count);
    } else if (std.mem.eql(u8, command, "help") or std.mem.eql(u8, command, "-h") or std.mem.eql(u8, command, "--help")) {
        try printUsage(std.fs.File.stdout().deprecatedWriter());
    } else {
        const stderr = std.fs.File.stderr().deprecatedWriter();
        try stderr.print("Unknown command: {s}\n\n", .{command});
        try printUsage(std.fs.File.stdout().deprecatedWriter());
        std.process.exit(1);
    }
}
