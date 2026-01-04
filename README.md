# Pure-Zig

A [Pure](https://github.com/sindresorhus/pure)-inspired prompt written in Zig.

## Installation — Usage

### Using Just (Recommended)

If you have [just](https://github.com/casey/just) installed:

```bash
# Build release and install to ~/.local/bin/pure
just install

# Then add to your shell config
eval "$(~/.local/bin/pure init zsh)"

# Uninstall later
just uninstall
```

To install just:

- macOS: `brew install just`
- Linux: `cargo install just` or download from [releases](https://github.com/casey/just/releases)
- Or run via `cargo binstall just` for fast binary install

### Manual Build

1. Set up your Zig environment (0.11.0 or later)
2. `$ zig build -Doptimize=ReleaseSafe`
3. Add the appropriate init to your shell config:

### ZSH

```zsh
# Add to ~/.zshrc
eval "$(zig-out/bin/pure init zsh)"
```

### Bash

```bash
# Add to ~/.bashrc
eval "$(zig-out/bin/pure init bash)"
```

### Fish

```fish
# Add to ~/.config/fish/config.fish
zig-out/bin/pure init fish | source
```

**Note:** The init command generates shell configuration that embeds the full path to the `pure` binary. If you move the binary, you'll need to re-run the init command.

### Optional: Vi Mode

For vi mode indication in the prompt, enable vi bindings in your shell:

**ZSH:**

```zsh
bindkey -v
```

**Bash:**

```bash
set -o vi
```

**Fish:**

```fish
fish_vi_key_bindings
```

## Customization

The `init` command accepts flags to customize the prompt appearance:

### Git Info

- `--detailed` - Show detailed git info (ahead/behind counts, file change counts) - **default**
- `--no-detailed` - Show minimal git info (only branch and dirty indicator)

### Git Icons

Customize the icons used for git status indicators:

| Flag | Description | Default |
|------|-------------|---------|
| `--icon-ahead` | Ahead commits | `↑` |
| `--icon-behind` | Behind commits | `↓` |
| `--icon-clean` | Clean working tree | `✔` |
| `--icon-staged` | Staged changes | `♦` |
| `--icon-conflict` | Conflicts | `✖` |
| `--icon-modified` | Modified files | `✚` |
| `--icon-untracked` | Untracked files | `…` |

### Examples

```bash
# Minimal git info with ASCII icons
eval "$(zig-out/bin/pure init --no-detailed --icon-conflict '!' bash)"

# Custom icons for all git status
eval "$(zig-out/bin/pure init --icon-ahead 'A' --icon-behind 'B' --icon-clean '✓' zsh)"

# Mix of default and custom icons
zig-out/bin/pure init --icon-staged '+' --icon-conflict 'x' fish | source
```

### Runtime Customization

Icons and settings can also be changed at runtime by setting environment variables in your shell config:

```bash
export PURE_DETAILED_GIT="0"
export PURE_ICON_AHEAD="A"
export PURE_ICON_CLEAN="✓"
export PURE_ICON_MODIFIED="M"
```

## Features

- **Path shortening**: Replaces home directory with `~` and compresses long paths
- **Git status**: Shows branch, modified files, and git action (rebase, merge, etc.)
- **Vi mode indication**: Different symbols for INSERT (`❯`) and NORMAL (`❮`) modes
- **Return code indication**: Prompt color changes based on last command exit status
- **Python virtual environment**: Shows active venv name

## Building

### Using Just

If you have [just](https://github.com/casey/just) installed, use the provided `justfile`:

```bash
# Show all available recipes
just --list

# Build debug
just build

# Build release (recommended)
just build-release

# Run tests
just test

# Format code
just fmt

# Clean build artifacts
just clean

# Full rebuild cycle
just rebuild
```

See `just --list` for all available recipes.

### Manual Build

```bash
# Debug build
zig build

# Release build (recommended)
zig build -Doptimize=ReleaseSafe

# Other release modes
zig build -Doptimize=ReleaseFast    # Fastest runtime, slower compile
zig build -Doptimize=ReleaseSmall   # Smallest binary size
```

## Running

```bash
# Generate and source shell init script
eval "$(zig-out/bin/pure init bash)"
eval "$(zig-out/bin/pure init zsh)"
zig-out/bin/pure init fish | source
```

## Why?

1. Learn Zig
2. Learn to work with AI

## License

MIT
