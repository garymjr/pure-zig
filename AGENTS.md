# AGENTS.md

Pure-Zig - Pure-inspired prompt written in Zig.

## Build / Lint / Test Commands

```bash
# Build
just build                    # Debug
just build-release            # ReleaseSafe (production)
just build-fast               # ReleaseFast
just build-small              # ReleaseSmall

# Run
just run                      # Debug build
just run-args arg1 arg2       # With args
just run-release              # Release build

# Test
just test                     # All tests
just test-verbose             # Verbose
just check                    # fmt-check + test

# Format
just fmt                      # Format code
just fmt-check                # Check formatting

# Clean / Rebuild
just clean                    # Clean artifacts
just rebuild                  # clean + build-release + test

# Install / Uninstall
just install                  # Install to ~/.local/bin/pure
just uninstall                # Uninstall

# Info
just info                     # Version info
just --list                   # All recipes
```

### Build Config

**build.zig**: `b.standardTargetOptions()`, `b.standardOptimizeOption()`, `b.addExecutable()`, run/test steps

**justfile**: Preferred workflow. Install: `brew install just` (macOS) or `cargo install just` (Linux)

**Artifacts**:
- `zig-out/bin/pure` - Binary
- `zig-cache/`, `.zig-cache/` - Cache (gitignored)

## Code Style

### Version
- Current: 0.15.2 (verify with `zig version`)
- Minimum: 0.11.0 (README.md)

### Module System
```zig
const std = @import("std");
const array_list = std.array_list;
// No file extensions: @import("src/main.zig")
```

### Naming
- Variables/Functions: `camelCase`
- Constants: `UPPER_SNAKE_CASE`
- Types: `PascalCase`
- Enums: PascalCase enum, UPPER_SNAKE_CASE values (or descriptive camelCase)

### Formatting
- `just fmt` (wraps `zig fmt`)
- 4 space indent
- Single chars: `'\n'`, strings: `"hello"`

### Type Usage
```zig
fn getRepoStatus(allocator: std.mem.Allocator, cwd: []const u8) !?GitStatus {}  // Error union
const branch: ?[]const u8 = null;  // Optional
const symbol = if (condition) NORMAL_SYMBOL else INSERT_SYMBOL;  // Inferred
fn promptCommand(allocator: std.mem.Allocator, ...) !void  // Explicit types for API
```

### Memory Management
```zig
const path = try std.fmt.allocPrint(allocator, "{s}/.git", .{repo_path});
defer allocator.free(path);
const result = try result.toOwnedSlice();
```

### Error Handling
```zig
const cwd = try std.fs.cwd().realpathAlloc(allocator, ".");  // try propagation
const git_dir = std.fmt.allocPrint(allocator, "{s}/.git", .{repo_path}) catch return null;  // catch
var status = GitStatus{ .allocator = allocator };
errdefer status.deinit();  // errdefer
// Return errors directly; don't wrap
```

### Testing
```zig
test "description" {
    const allocator = std.testing.allocator;
    const input = "...";
    const result = try functionUnderTest(allocator, input);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("expected", result);
}
```
- Use `std.testing.allocator` for leak detection
- Clean up allocations in defer

### Structs with Cleanup
```zig
const GitStatus = struct {
    branch: ?[]const u8 = null,
    allocator: std.mem.Allocator,
    fn deinit(self: *const GitStatus) void {
        if (self.branch) |b| self.allocator.free(b);
    }
};
```

### Config Pattern
```zig
const Config = struct {
    detailed_git: bool = true,
    icons: struct {
        ahead: []const u8 = GIT_ICONS.ahead,
        behind: []const u8 = GIT_ICONS.behind,
    } = .{},
};
fn readConfigFromEnv(allocator: std.mem.Allocator) !Config {
    var config = Config{};
    if (std.process.getEnvVarOwned(allocator, "PURE_DETAILED_GIT")) |val| {
        defer allocator.free(val);
        config.detailed_git = std.mem.eql(u8, val, "1");
    } else |_| {}
    return config;
}
```

### CLI Parsing
```zig
const args = try std.process.argsAlloc(allocator);
defer std.process.argsFree(allocator, args);
if (args.len < 2) { /* error */ }
const command = args[1];
var arg_idx: usize = 2;
while (arg_idx < args.len) : (arg_idx += 1) {
    if (std.mem.eql(u8, args[arg_idx], "--flag")) {
        arg_idx += 1;
        if (arg_idx < args.len) { /* process value */ }
    }
}
```

### Strings & Files
```zig
// Strings: []const u8 slices, not null-terminated
// Compare: std.mem.eql(u8, a, b), not ==
// Trim: std.mem.trim(u8, str, &std.ascii.whitespace)
// Startswith: std.mem.startsWith(u8, str, prefix)

// File I/O
const file = try std.fs.openFileAbsolute(path, .{});
defer file.close();
const content = try file.readToEndAlloc(allocator, max_size);
defer allocator.free(content);
const absolute = try std.fs.path.resolve(allocator, &[_][]const u8{path});
defer allocator.free(absolute);

// Enums
@intFromEnum(myEnum)
@enumFromInt(myInt)
```

## Architecture

### Structure
```
pure-zig/
├── src/main.zig    # Single-file (637 lines)
├── build.zig       # Zig build config
├── justfile        # Just recipes (preferred)
├── README.md       # User docs
├── LICENSE         # MIT
├── AGENTS.md       # This file
├── zig-out/        # Build output
└── zig-cache/      # Cache
```

### Key Abstractions

**Color Enum**: ANSI codes. `fg()`, `fgBright()`, `bg()`, `bold()`, global `reset`

**GIT_ICONS**: Default icon constants struct, overridden via Config

**Config**: `detailed_git` flag, nested `icons` struct, env var overrides

**GitStatus**: Branch, ahead/behind, changes, action. Has `deinit()`

**Commands**: `init <shell>`, `precmd`, `prompt`

### Design Patterns
- Allocator-first: explicit `std.mem.Allocator` params
- Error unions (`!T`) + `try`
- No external deps: std lib only
- Shell integration: generate functions calling binary

### Important Patterns
- String allocation: `allocPrint`/`dupe` + `defer allocator.free()`
- Path: `std.fs.path`, resolve absolute first
- Shell init: binary path via `std.fs.selfExePathAlloc()`
- Exit: `std.process.exit(1)` after stderr
- Shell generation: `print{Shell}Init()`, `getExecutablePath()`, functions call back:
  - `pure_precmd()` → `pure precmd`
  - `pure_prompt()` → `pure prompt -r $? -k $KEYMAP --venv $venv -j $jobs`
- Git detection: `findGitRepo()` walks tree for `.git`
- Output: `std.fs.File.stdout().deprecatedWriter()`, stderr same
- Array lists: `std.array_list.AlignedManaged` with allocator
- Testing: inline/module test blocks, `just test`, `std.testing.allocator`

## Development Workflow

```bash
git clone <repo>
cd pure-zig
just build-release
eval "$(./zig-out/bin/pure init zsh)"
```

### Changes
1. Edit `src/main.zig`
2. `just fmt`
3. `just build`
4. `just test` (add tests)
5. `eval "$(./zig-out/bin/pure init zsh)"` to verify

### Single-File Notes
- All in `src/main.zig` (637 lines)
- Split if >500 lines:
  - `src/config.zig`: Config, GIT_ICONS, readConfigFromEnv
  - `src/color.zig`: Color enum, ANSI codes
  - `src/git.zig`: GitStatus, findGitRepo, getRepoStatus, formatGitStatus
  - `src/shell.zig`: print{Bash,Zsh,Fish}Init
  - `src/path.zig`: shortenPath
  - `src/main.zig`: main, promptCommand, precmdCommand
- `@import("src/config")` - no extensions

### Adding Features
- Follow patterns (enum colors, struct state)
- Add `deinit()` to structs owning memory
- Handle errors with try/catch
- User-facing: document in README.md

## Extension Points

### Add Shell Support
1. Shell detection in `main()`
2. `print{Shell}Init()` function
3. `pure_precmd()`, `pure_prompt()` functions
4. Hooks for integration
5. Update README.md
6. Add justfile recipe

### Add Git Features
- Extend `GitStatus` struct
- Add cleanup in `deinit()`
- Update `countGitStatus()`/related
- Update `formatGitStatus()`
- Add tests

### Custom Prompt Symbols
- Modify `INSERT_SYMBOL`, `NORMAL_SYMBOL`, `JOB_SYMBOL`
- Colors in `promptCommand()` shell_color logic
- Add env vars for new symbols

### New Features
- Add command to `main()` dispatcher
- Create function following `promptCommand()`/`precmdCommand()` pattern
- Update `printUsage()`
- Add Config fields
- Update `readConfigFromEnv()`
- Add tests

## Dependencies

**Zig std lib only**:
- `std.mem` - strings, comparisons, allocation
- `std.fs` - filesystem, paths
- `std.process` - process, args, env
- `std.fmt` - formatting, printing
- `std.testing` - test framework
- `std.ascii` - ASCII classification
- `std.array_list` - dynamic arrays
- `std.heap.page_allocator` - default allocator

## Pitfalls

### Memory
- Always pair allocations with `defer allocator.free()`
- `toOwnedSlice()` only for ownership transfer
- Use `std.heap.page_allocator` in main, `std.testing.allocator` in tests
- Array lists: `deinit` + free items in defer blocks

### Errors
- Use `try`, `catch`, `orelse` - don't silently ignore
- `errdefer` for cleanup on error paths
- Return errors directly; don't wrap

### Strings
- Check bounds before slice indexing
- Compare with `std.mem.eql(u8, a, b)`, not `==`
- Check `.len > 0` for emptiness, not `!= null`
- Trim: `std.mem.trim(u8, str, &std.ascii.whitespace)`

### CLI Parsing
- Check `arg_idx < args.len` before access
- Increment index after checking bounds for flag values
- Provide defaults for optional args
- Print usage on invalid input

### Git
- Not in git repo: return null/empty status
- Detached HEAD: show short commit hash
- Missing .git files: handle gracefully
- Resolve absolute paths before .git check

### Shell
- Re-run init if binary moves
- Env vars may not be set - use catch blocks
- Vi mode: check for "vicmd" keymap
- Different shells = different syntax

### File I/O
- `defer file.close()`
- Handle file operation errors
- `resolve()` before absolute path ops
- Set reasonable limits for `readToEndAlloc()`

## Testing

### Current State
- No tests exist
- Add tests with new features
- `just test` runs all
- `just test-verbose` for verbose

### Placement
- Inline after functions
- Module-level for integration
```zig
test "shortenPath should replace home directory with ~" {
    const allocator = std.testing.allocator;
    const home = try std.process.getEnvVarOwned(allocator, "HOME");
    defer allocator.free(home);
    const test_path = try std.fmt.allocPrint(allocator, "{s}/Projects/foo", .{home});
    defer allocator.free(test_path);
    const result = try shortenPath(allocator, test_path);
    defer allocator.free(result);
    try std.testing.expectEqualStrings("~/Projects/foo", result);
}
```

### Memory Leak Testing
- `std.testing.allocator` detects leaks
- All test allocations use this allocator
- Tests fail on leaks

### Specific Tests
- `zig test src/main.zig --filter "test name"`

## Shell Integration

### Communication
Shell → Binary via function calls:
1. `precmd`: directory + git status
2. `prompt`: colored prompt symbol

### Environment Variables
- `HOME` - path shortening
- `VIRTUAL_ENV` - Python venv
- `KEYMAP` - current keymap (vicmd = normal)
- `PURE_DETAILED_GIT` - detailed git ("1" or "true")
- `PURE_ICON_AHEAD` / `BEHIND` / `CLEAN` / `STAGED` / `CONFLICTED` / `MODIFIED` / `UNTRACKED` - custom icons

### Generated Functions
- `pure_precmd()` → `pure precmd`
- `pure_prompt()` → `pure prompt -r $? -k $KEYMAP --venv $venv -j $jobs`

### Vi Mode
- zsh: `bindkey -v`
- bash: `set -o vi`
- fish: `fish_vi_key_bindings`
- Detected via `keymap == "vicmd"`
