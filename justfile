# Pure-Zig Justfile
# Install: https://github.com/casey/just

# Default recipe
default:
    @just --list

# Build debug binary
build:
    zig build

# Build release binary (recommended for production)
build-release:
    zig build -Doptimize=ReleaseSafe

# Build release-fast (fastest runtime, slower compile)
build-fast:
    zig build -Doptimize=ReleaseFast

# Build release-small (smallest binary size)
build-small:
    zig build -Doptimize=ReleaseSmall

# Run debug build
run:
    zig build run

# Run with arguments (use: just run-args arg1 arg2)
run-args *args:
    zig build run -- {{args}}

# Run release build
run-release:
    @just build-release
    ./zig-out/bin/pure

# Run all tests
test:
    zig build test

# Run tests with verbose output
test-verbose:
    zig test src/main.zig --summary all

# Format code
fmt:
    zig fmt src/

# Check formatting (dry run)
fmt-check:
    zig fmt --check src/

# Install release build to ~/.local/bin/pure
install:
    @#!/usr/bin/env sh
    set -e
    echo "Building release..."
    zig build -Doptimize=ReleaseSafe
    mkdir -p ~/.local/bin
    cp zig-out/bin/pure ~/.local/bin/pure
    echo "Installed to ~/.local/bin/pure"

# Uninstall from ~/.local/bin/pure
uninstall:
    @#!/usr/bin/env sh
    set -e
    if [ -f ~/.local/bin/pure ]; then
    rm ~/.local/bin/pure
    echo "Removed ~/.local/bin/pure"
    else
    echo "pure not installed in ~/.local/bin"
    fi

# Clean build artifacts
clean:
    rm -rf zig-out zig-cache .zig-cache

# Run all checks (fmt + test)
check:
    @just fmt-check
    @just test

# Full rebuild cycle (clean + build-release + test)
rebuild: clean build-release test

# Display version and zig info
info:
    @echo "Pure-Zig Build Info"
    @echo "==================="
    @zig version
    @echo ""
    @if [ -f ./zig-out/bin/pure ]; then \
    echo "Binary: ./zig-out/bin/pure"; \
    ls -lh ./zig-out/bin/pure; \
    else \
    echo "No binary built yet. Run 'just build' or 'just build-release'"; \
    fi
