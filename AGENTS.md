# AGENTS.md

Pure-Zig - Pure-inspired prompt written in Zig.

## Build / Lint / Test Commands

### Build
```bash
# Debug build
zig build

# Release build (recommended for production)
zig build -Doptimize=ReleaseSafe

# Other release modes
zig build -Doptimize=ReleaseFast    # Fastest runtime, slower compile
zig build -Doptimize=ReleaseSmall   # Smallest binary size
zig build -Doptimize=Debug          # Debug info, no optimizations
```

### Run
```bash
# Build and run
zig build run

# Run with arguments
zig build run -- args...

# Run the built binary directly
./zig-out/bin/pure
```

### Test
```bash
# Run all tests
zig build test

# Run tests for specific file (add test block in that file)
zig test src/main.zig

# Run tests with verbose output
zig test src/main.zig --summary all

# Run tests with release optimizations
zig test src/main.zig -Doptimize=ReleaseFast
```

### Lint / Format
```bash
# Format code (standard Zig formatter)
zig fmt src/

# Check what would be formatted (dry run)
zig fmt --check src/

# Format a specific file
zig fmt src/main.zig
```

## Code Style Guidelines

### Zig Version
- Minimum Zig version: 0.11.0 (currently using 0.15.2)
- Update `README.md` if minimum version changes

### Module System
- Use `const std = @import("std");` as standard library import
- Import specific modules for clarity: `const array_list = std.array_list;`
- No file extensions in imports - use `@import("src/main.zig")` pattern

### Naming Conventions

**Variables/Functions:** `camelCase`
```zig
const myVariable = 42;
const shortPath = try shortenPath(allocator, cwd);
fn promptCommand(allocator: std.mem.Allocator, ...) !void { }
```

**Constants (compile-time):** `UPPER_SNAKE_CASE`
```zig
const INSERT_SYMBOL = "❯";
const NORMAL_SYMBOL = "❮";
const NORMAL_KEYMAP = "vicmd";
```

**Types:** `PascalCase`
```zig
const Color = enum { ... };
const GitStatus = struct { ... };
```

**Enums:** PascalCase enum, UPPER_SNAKE_CASE values (or descriptive camelCase)
```zig
const Color = enum {
    black,
    red,
    green,
    // ...
};
```

### Formatting Conventions
- Use `zig fmt` for formatting - this is the authoritative style
- 4 space indentation
- Prefer single quotes for single characters: `'\n'`
- Double quotes for strings: `"hello"`

### Type Usage
- **Error union return types**: Use `!T` for functions that can fail
```zig
fn getRepoStatus(allocator: std.mem.Allocator, cwd: []const u8) !?GitStatus {
    // Returns ?GitStatus or error
}
```

- **Optionals**: Use `?T` for values that may be null
```zig
const branch: ?[]const u8 = null;
```

- **No explicit type annotations when inferable**:
```zig
const symbol = if (condition) NORMAL_SYMBOL else INSERT_SYMBOL;
// Type inferred to []const u8
```

- **Explicit types for public API and allocators**:
```zig
fn promptCommand(allocator: std.mem.Allocator, ...) !void
```

### Memory Management
- **Allocator pattern**: Pass `std.mem.Allocator` explicitly to allocating functions
- **Defer cleanup**: Always `defer allocator.free()` for allocations
```zig
const path = try std.fmt.allocPrint(allocator, "{s}/.git", .{repo_path});
defer allocator.free(path);
```

- **Owned slices**: Use `toOwnedSlice()` when transferring ownership
```zig
const result = try result.toOwnedSlice();
```

### Error Handling
- **Try propagation**: Use `try` for error propagation
```zig
const cwd = try std.fs.cwd().realpathAlloc(allocator, ".");
```

- **Catch blocks**: Handle specific errors when needed
```zig
const git_dir = std.fmt.allocPrint(allocator, "{s}/.git", .{repo_path}) catch return null;
```

- **Error unions**: Use `errdefer` for cleanup on error paths
```zig
var status = GitStatus{ .allocator = allocator };
errdefer status.deinit();
```

- **No error wrapping**: Return errors directly, don't wrap in custom errors unless needed

### Testing Conventions
```zig
test "description of what is tested" {
    const allocator = std.testing.allocator;
    // Arrange
    const input = "...";

    // Act
    const result = try functionUnderTest(allocator, input);
    defer allocator.free(result);

    // Assert
    try std.testing.expectEqualStrings("expected", result);
}
```

- Use `std.testing.allocator` to detect memory leaks
- Clean up allocations in test teardown
- Test both success and error paths

### Structs with Cleanup
- Include `deinit` method for structs owning memory
```zig
const GitStatus = struct {
    branch: ?[]const u8 = null,
    allocator: std.mem.Allocator,

    fn deinit(self: *const GitStatus) void {
        if (self.branch) |b| self.allocator.free(b);
    }
};
```

### String Handling
- Use `[]const u8` for string slices (not null-terminated)
- Use string literals: `"hello"`
- Compare with `std.mem.eql(u8, a, b)`, not `==`
- Trim whitespace: `std.mem.trim(u8, str, &std.ascii.whitespace)`
- Startswith: `std.mem.startsWith(u8, str, prefix)`

### Enum Usage
- Enum to int: `@intFromEnum(myEnum)`
- Int to enum: `@enumFromEnum(myInt)`
- Use enums for type-safe constants (like ANSI color codes)

### File I/O
```zig
// Open file
const file = try std.fs.openFileAbsolute(path, .{});
defer file.close();

// Read to end
const content = try file.readToEndAlloc(allocator, max_size);
defer allocator.free(content);

// Resolve path
const absolute = try std.fs.path.resolve(allocator, &[_][]const u8{path});
defer allocator.free(absolute);
```

## Architecture Overview

### Project Structure
```
pure-zig/
├── src/
│   └── main.zig          # Single-file application
├── build.zig             # Zig build configuration
├── README.md             # User documentation
├── LICENSE               # MIT license
└── AGENTS.md             # This file
```

### Key Abstractions

**Color Enum**: ANSI color code abstraction
- `fg()` - foreground color
- `fgBright()` - bright foreground
- `bg()` - background color
- `bold()` - bold foreground

**GitStatus**: Git repository state
- Branch name, ahead/behind counts, file changes
- Action state (rebase, merge, bisect, etc.)
- Has `deinit()` for memory cleanup

**Main Commands**:
1. `init <shell>` - Generate shell init script (bash/zsh/fish)
2. `precmd` - Show directory and git status (called by shell)
3. `prompt` - Show prompt symbol with status (called by shell)

### Design Patterns

**Allocator-first design**: All allocating functions take an explicit allocator parameter, enabling flexible memory management.

**Result-based error handling**: Uses Zig's error unions (`!T`) and `try` for clean error propagation.

**Minimal dependencies**: Only uses Zig's standard library - no external dependencies.

**Shell integration pattern**: Generates shell functions that call back into the binary with specific commands.

### Output Directories
- `zig-out/` - Build output directory (binaries)
- `zig-cache/` - Build cache (don't commit)
- `.zig-cache/` - Alternative cache location (don't commit)

### Important Patterns

**String allocation**: Always pair `allocPrint` or `dupe` with `defer allocator.free()`

**Path handling**: Use `std.fs.path` utilities, resolve absolute paths before use

**Shell integration**: Binary path is embedded in generated init scripts via `std.fs.selfExePathAlloc()`

**Exit codes**: Use `std.process.exit(1)` for errors in `main()` after printing to stderr

## Development Workflow

### Setting Up
```bash
# Clone and build
git clone <repo>
cd pure-zig
zig build -Doptimize=ReleaseSafe

# Test in your shell (e.g., zsh)
eval "$(zig-out/bin/pure init zsh)"
```

### Making Changes
1. Edit source in `src/main.zig`
2. Format: `zig fmt src/`
3. Build: `zig build`
4. Test: `zig build test` (add tests as you go)
5. Manual test: `eval "$(zig-out/bin/pure init zsh)"` and try it

### Adding Features
- Follow existing patterns (enum for colors, struct for state)
- Add deinit() to structs that own memory
- Add error handling with try/catch
- Document in README.md if user-facing

## Extension Points

### Adding Shell Support
1. Add shell detection in `main()`
2. Create `print{Shell}Init()` function
3. Update README.md with usage instructions

### Adding Git Status Features
- Extend `GitStatus` struct with new fields
- Update `countGitStatus()` implementation (currently stubbed)
- Update `formatGitStatus()` to display new info

### Customizing Prompt Symbols
- Modify `INSERT_SYMBOL`, `NORMAL_SYMBOL`, `JOB_SYMBOL` constants
- Colors controlled in `promptCommand()` shell_color logic

### New Features
- Add commands to `main()` command dispatcher
- Create dedicated functions following `promptCommand()` / `precmdCommand()` pattern
- Update `printUsage()` for help text

## Dependencies

**Zig Standard Library**:
- `std.mem` - String operations, comparisons, allocation
- `std.fs` - File system operations, paths
- `std.process` - Process info, arguments, environment
- `std.fmt` - Formatting and printing
- `std.testing` - Test framework
- `std.ascii` - ASCII character classification
- `std.array_list` - Dynamic arrays
- `std.heap.page_allocator` - Default allocator

**No external dependencies** - Pure Zig, all standard library.

## Shell Integration Details

### Communication Pattern
Shell → Binary (via function calls):
1. `precmd` command: prints directory + git status on newline
2. `prompt` command: prints colored prompt symbol

### Environment Variables Used
- `HOME` - User home directory for path shortening
- `VIRTUAL_ENV` - Python virtual environment path
- `KEYMAP` (zsh) - Current keymap (vicmd = normal mode)

### Shell Functions Generated
Each init script generates:
- `pure_precmd()` - Calls `pure precmd`
- `pure_prompt()` - Calls `pure prompt -r $? -k $KEYMAP --venv $venv -j $jobs`

### Vi Mode
- zsh: `bindkey -v`
- bash: `set -o vi`
- fish: `fish_vi_key_bindings`
- Detected via `keymap` argument ("vicmd" = normal mode)
