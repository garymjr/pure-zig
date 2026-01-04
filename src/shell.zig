const std = @import("std");
const config = @import("config.zig");

fn getExecutablePath(allocator: std.mem.Allocator) ![]const u8 {
    const self_path = try std.fs.selfExePathAlloc(allocator);
    return self_path;
}

pub fn printBashInit(allocator: std.mem.Allocator, writer: anytype, cfg: config.Config) !void {
    const exe_path = try getExecutablePath(allocator);
    defer allocator.free(exe_path);

    const detailed_val = if (cfg.detailed_git) "1" else "0";

    try writer.print(
        \\# Pure prompt initialization for bash
        \\
        \\# Configuration
        \\export PURE_DETAILED_GIT="{s}"
        \\export PURE_ICON_AHEAD="{s}"
        \\export PURE_ICON_BEHIND="{s}"
        \\export PURE_ICON_CLEAN="{s}"
        \\export PURE_ICON_STAGED="{s}"
        \\export PURE_ICON_CONFLICTED="{s}"
        \\export PURE_ICON_MODIFIED="{s}"
        \\export PURE_ICON_UNTRACKED="{s}"
        \\
        \\# Pre-command: show directory and git branch
        \\pure_precmd() {{
        \\    "{s}" precmd
        \\}}
        \\
        \\# Prompt symbol with color based on status
        \\pure_prompt() {{
        \\    local ret=$?
        \\    local keymap="${{KEYMAP:-}}"
        \\    local venv="${{VIRTUAL_ENV##*/}}"
        \\    local jobs=$(jobs -p | wc -l | tr -d ' ')
        \\    "{s}" prompt -r "$ret" -k "$keymap" --venv "$venv" -j "$jobs"
        \\}}
        \\
        \\# Set the prompt
        \\PS1='$(pure_precmd)$(pure_prompt)'
        \\
    , .{ detailed_val, cfg.icons.ahead, cfg.icons.behind, cfg.icons.clean, cfg.icons.staged, cfg.icons.conflicted, cfg.icons.modified, cfg.icons.untracked, exe_path, exe_path });
}

pub fn printZshInit(allocator: std.mem.Allocator, writer: anytype, cfg: config.Config) !void {
    const exe_path = try getExecutablePath(allocator);
    defer allocator.free(exe_path);

    const detailed_val = if (cfg.detailed_git) "1" else "0";

    try writer.print(
        \\# Pure prompt initialization for zsh
        \\
        \\# Configuration
        \\export PURE_DETAILED_GIT="{s}"
        \\export PURE_ICON_AHEAD="{s}"
        \\export PURE_ICON_BEHIND="{s}"
        \\export PURE_ICON_CLEAN="{s}"
        \\export PURE_ICON_STAGED="{s}"
        \\export PURE_ICON_CONFLICTED="{s}"
        \\export PURE_ICON_MODIFIED="{s}"
        \\export PURE_ICON_UNTRACKED="{s}"
        \\
        \\# Update prompt on keymap change (vi mode)
        \\zle-keymap-select() {{
        \\    zle reset-prompt
        \\}}
        \\zle -N zle-keymap-select
        \\
        \\# Pre-command: show directory and git branch
        \\pure_precmd() {{
        \\    "{s}" precmd
        \\}}
        \\
        \\# Prompt symbol with color based on status
        \\pure_prompt() {{
        \\    local ret=$?
        \\    local keymap="${{KEYMAP:-}}"
        \\    local venv="${{VIRTUAL_ENV:t}}"
        \\    local jobs=$(jobs -p | wc -l | tr -d ' ')
        \\    "{s}" prompt -r "$ret" -k "$keymap" --venv "$venv" -j "$jobs"
        \\}}
        \\
        \\# Set the prompt
        \\setopt PROMPT_SUBST
        \\PS1='$(pure_precmd)$(pure_prompt)'
        \\
    , .{ detailed_val, cfg.icons.ahead, cfg.icons.behind, cfg.icons.clean, cfg.icons.staged, cfg.icons.conflicted, cfg.icons.modified, cfg.icons.untracked, exe_path, exe_path });
}

pub fn printFishInit(allocator: std.mem.Allocator, writer: anytype, cfg: config.Config) !void {
    const exe_path = try getExecutablePath(allocator);
    defer allocator.free(exe_path);

    const detailed_val = if (cfg.detailed_git) "1" else "0";

    try writer.print(
        \\# Pure prompt initialization for fish
        \\
        \\# Configuration
        \\set -gx PURE_DETAILED_GIT "{s}"
        \\set -gx PURE_ICON_AHEAD "{s}"
        \\set -gx PURE_ICON_BEHIND "{s}"
        \\set -gx PURE_ICON_CLEAN "{s}"
        \\set -gx PURE_ICON_STAGED "{s}"
        \\set -gx PURE_ICON_CONFLICTED "{s}"
        \\set -gx PURE_ICON_MODIFIED "{s}"
        \\set -gx PURE_ICON_UNTRACKED "{s}"
        \\
        \\# Pre-command: show directory and git branch
        \\function pure_precmd
        \\    "{s}" precmd
        \\end
        \\
        \\# Prompt symbol with color based on status
        \\function pure_prompt
        \\    set -l ret $status
        \\    set -l keymap ""
        \\    if set -q fish_bind_mode
        \\        if test "$fish_bind_mode" = "default"
        \\            set keymap "vicmd"
        \\        end
        \\    end
        \\    set -l venv (string replace -r '.*/' '' -- "$VIRTUAL_ENV" 2>/dev/null; or echo "")
        \\    set -l jobs (count (jobs -p))
        \\    "{s}" prompt -r "$ret" -k "$keymap" --venv "$venv" -j "$jobs"
        \\end
        \\
        \\# Set the prompt
        \\function fish_prompt
        \\    pure_precmd
        \\    pure_prompt
        \\end
        \\
    , .{ detailed_val, cfg.icons.ahead, cfg.icons.behind, cfg.icons.clean, cfg.icons.staged, cfg.icons.conflicted, cfg.icons.modified, cfg.icons.untracked, exe_path, exe_path });
}
