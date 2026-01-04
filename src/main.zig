const std = @import("std");
const color = @import("color.zig");
const config = @import("config.zig");
const git = @import("git.zig");
const path_mod = @import("path.zig");
const shell = @import("shell.zig");

const INSERT_SYMBOL = "❯";
const NORMAL_SYMBOL = "❮";
const JOB_SYMBOL = "●";
const NORMAL_KEYMAP = "vicmd";

fn promptCommand(allocator: std.mem.Allocator, last_return_code: []const u8, keymap: []const u8, venv_name: []const u8, job_count: usize) !void {
    const symbol = if (std.mem.eql(u8, keymap, NORMAL_KEYMAP)) NORMAL_SYMBOL else INSERT_SYMBOL;

    const shell_color: color.Color = blk: {
        if (std.mem.eql(u8, symbol, NORMAL_SYMBOL)) break :blk color.Color.yellow;
        if (std.mem.eql(u8, last_return_code, "0")) break :blk color.Color.magenta;
        break :blk color.Color.red;
    };

    const venv_trimmed = std.mem.trim(u8, venv_name, &std.ascii.whitespace);
    const venv = if (venv_trimmed.len > 0)
        try std.fmt.allocPrint(allocator, "{s}|{s}|{s} ", .{ color.Color.fgBright(color.Color.green), venv_trimmed, color.reset })
    else
        "";

    defer if (venv.len > 0) allocator.free(venv);

    const jobs = if (job_count > 0)
        try std.fmt.allocPrint(allocator, "{s}{s}{d}{s} ", .{ color.Color.fgBright(color.Color.yellow), JOB_SYMBOL, job_count, color.reset })
    else
        "";

    defer if (jobs.len > 0) allocator.free(jobs);

    const stdout = std.fs.File.stdout().deprecatedWriter();
    try stdout.print("{s}{s}{s}{s}{s} ", .{ venv, jobs, color.Color.fgBright(shell_color), symbol, color.reset });
}

fn precmdCommand(allocator: std.mem.Allocator, cfg: config.Config) !void {
    const cwd = try std.fs.cwd().realpathAlloc(allocator, ".");
    defer allocator.free(cwd);

    const short_path = try path_mod.shortenPath(allocator, cwd);
    defer allocator.free(short_path);

    const stdout = std.fs.File.stdout().deprecatedWriter();
    try stdout.print("\n{s}{s}{s}", .{ color.Color.fg(color.Color.blue), short_path, color.reset });

    if (try git.getRepoStatus(allocator, cwd, cfg)) |status| {
        defer status.deinit();
        const status_str = try git.formatGitStatus(allocator, status, cfg);
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
        \\  pure init [OPTIONS] <shell>     Generate shell init script (bash|zsh|fish)
        \\
        \\Commands:
        \\  init      Generate shell initialization script
        \\
        \\Options:
        \\  init:
        \\    --detailed          Show detailed git info (default)
        \\    --no-detailed       Show minimal git info
        \\    --icon-ahead TEXT   Icon for ahead commits (default: ↑)
        \\    --icon-behind TEXT  Icon for behind commits (default: ↓)
        \\    --icon-clean TEXT   Icon for clean working tree (default: ✔)
        \\    --icon-staged TEXT  Icon for staged changes (default: ♦)
        \\    --icon-conflict TEXT Icon for conflicts (default: ✖)
        \\    --icon-modified TEXT Icon for modified files (default: ✚)
        \\    --icon-untracked TEXT Icon for untracked files (default: …)
        \\
        \\Arguments:
        \\    <shell>              Shell type: bash, zsh, or fish
        \\
        \\Note: precmd and prompt are internal commands used by the generated init.
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

    if (std.mem.eql(u8, command, "init")) {
        if (args.len < 3) {
            const stderr = std.fs.File.stderr().deprecatedWriter();
            try stderr.print("Error: shell type required\n\n", .{});
            try printUsage(std.fs.File.stdout().deprecatedWriter());
            std.process.exit(1);
        }

        var cfg = config.Config{};

        while (arg_idx < args.len - 1) : (arg_idx += 1) {
            if (std.mem.eql(u8, args[arg_idx], "--detailed")) {
                cfg.detailed_git = true;
            } else if (std.mem.eql(u8, args[arg_idx], "--no-detailed")) {
                cfg.detailed_git = false;
            } else if (std.mem.eql(u8, args[arg_idx], "--icon-ahead")) {
                arg_idx += 1;
                if (arg_idx < args.len - 1) cfg.icons.ahead = args[arg_idx];
            } else if (std.mem.eql(u8, args[arg_idx], "--icon-behind")) {
                arg_idx += 1;
                if (arg_idx < args.len - 1) cfg.icons.behind = args[arg_idx];
            } else if (std.mem.eql(u8, args[arg_idx], "--icon-clean")) {
                arg_idx += 1;
                if (arg_idx < args.len - 1) cfg.icons.clean = args[arg_idx];
            } else if (std.mem.eql(u8, args[arg_idx], "--icon-staged")) {
                arg_idx += 1;
                if (arg_idx < args.len - 1) cfg.icons.staged = args[arg_idx];
            } else if (std.mem.eql(u8, args[arg_idx], "--icon-conflict")) {
                arg_idx += 1;
                if (arg_idx < args.len - 1) cfg.icons.conflicted = args[arg_idx];
            } else if (std.mem.eql(u8, args[arg_idx], "--icon-modified")) {
                arg_idx += 1;
                if (arg_idx < args.len - 1) cfg.icons.modified = args[arg_idx];
            } else if (std.mem.eql(u8, args[arg_idx], "--icon-untracked")) {
                arg_idx += 1;
                if (arg_idx < args.len - 1) cfg.icons.untracked = args[arg_idx];
            } else {
                const stderr = std.fs.File.stderr().deprecatedWriter();
                try stderr.print("Error: unknown option '{s}'. Shell must be the last argument.\n\n", .{args[arg_idx]});
                try printUsage(std.fs.File.stdout().deprecatedWriter());
                std.process.exit(1);
            }
        }

        const shell_type = args[arg_idx];
        const stdout = std.fs.File.stdout().deprecatedWriter();

        if (std.mem.eql(u8, shell_type, "bash")) {
            try shell.printBashInit(allocator, stdout, cfg);
        } else if (std.mem.eql(u8, shell_type, "zsh")) {
            try shell.printZshInit(allocator, stdout, cfg);
        } else if (std.mem.eql(u8, shell_type, "fish")) {
            try shell.printFishInit(allocator, stdout, cfg);
        } else {
            const stderr = std.fs.File.stderr().deprecatedWriter();
            try stderr.print("Error: unsupported shell '{s}'. Supported shells: bash, zsh, fish\n\n", .{shell_type});
            try printUsage(std.fs.File.stdout().deprecatedWriter());
            std.process.exit(1);
        }
    } else if (std.mem.eql(u8, command, "precmd")) {
        const cfg = try config.readConfigFromEnv(allocator);
        try precmdCommand(allocator, cfg);
    } else if (std.mem.eql(u8, command, "prompt")) {
        var last_return_code: []const u8 = "0";
        var keymap: []const u8 = "";
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
