# Pure-Zig

A [Pure](https://github.com/sindresorhus/pure)-inspired prompt written in Zig.

Even more minimal, definitively faster and at least as pretty as the original Pure by [Sindre Sohrus](https://github.com/sindresorhus).

## Installation — Usage

1. Set up your Zig environment (0.11.0 or later)
1. `$ zig build -Doptimize=ReleaseSafe`

### ZSH

Add the following to your `~/.zshrc`:

```zsh
function zle-line-init zle-keymap-select {
  PROMPT=`/PATH/TO/PURE-ZIG/zig-out/bin/pure prompt -k "$KEYMAP" -r "$?" --venv "${${VIRTUAL_ENV:t}%-*}"`
  zle reset-prompt
}
zle -N zle-line-init
zle -N zle-keymap-select

autoload -Uz add-zsh-hook

function _prompt_pure_precmd() {
  /PATH/TO/PURE-ZIG/zig-out/bin/pure precmd
}
add-zsh-hook precmd _prompt_pure_precmd
```

### Fish

Add the following to your `~/.config/fish/config.fish`:

```fish
set -x PURE_ZIG_PATH /PATH/TO/PURE-ZIG/zig-out/bin/pure

function fish_prompt
  set -l last_status $status
  set -l venv_name ""

  if set -q VIRTUAL_ENV
    set venv_name (basename $VIRTUAL_ENV)
    # Strip version suffix if present (e.g., "myenv-3.11" -> "myenv")
    set venv_name (string replace -r '-.*' '' $venv_name)
  end

  set -l keymap $fish_bind_mode
  $PURE_ZIG_PATH prompt -r "$last_status" -k "$keymap" --venv "$venv_name"
end

function _pure_fish_prompt --on-event fish_prompt
  $PURE_ZIG_PATH precmd
end

# Optional: hide default mode prompt if using vi mode
function fish_mode_prompt
  # Return empty to hide default mode indicator
end

# Enable vi mode (optional)
fish_vi_key_bindings
```

## Features

- **Path shortening**: Replaces home directory with `~` and compresses long paths
- **Git status**: Shows branch, modified files, and git action (rebase, merge, etc.)
- **Vi mode indication**: Different symbols for INSERT (`❯`) and COMMAND (`⬢`) modes
- **Return code indication**: Prompt color changes based on last command exit status
- **Python virtual environment**: Shows active venv name

## Building

```bash
zig build
```

For release build:
```bash
zig build -Doptimize=ReleaseSafe
```

## Running

```bash
# Show precmd (directory + git status)
zig-out/bin/pure precmd

# Show precmd with detailed git status
zig-out/bin/pure precmd --git-detailed

# Show prompt
zig-out/bin/pure prompt -k "vicmd" -r "0" --venv "myenv"
```

## Why?

1. Learn Zig
2. Learn to work with AI

## License

MIT
