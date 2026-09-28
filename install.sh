#!/usr/bin/env bash
# Universal installer: deploys starship, ghostty, lsd and Neovim (LazyVim) configs.
#
# Supported platforms:
#   - Fedora/RHEL       (dnf)
#   - Debian/Ubuntu     (apt)
#   - Arch              (pacman)
#   - macOS             (Homebrew)
#   - Windows           (winget, run from Git Bash / MSYS2)
#
# Expects the `configs/` directory to sit next to this script.
# Set DRY_RUN=1 to preview actions without changing anything.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS="$SCRIPT_DIR/configs"
DRY_RUN="${DRY_RUN:-0}"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$*"; }

run() {
    if [[ $DRY_RUN == 1 ]]; then
        log "[dry-run] $*"
    else
        "$@"
    fi
}

# --- sanity checks ---
if [[ ! -d "$CONFIGS" ]]; then
    echo "Error: $CONFIGS not found next to this script." >&2
    exit 1
fi
if [[ $EUID -eq 0 && "$(uname -s)" != MINGW* && "$(uname -s)" != MSYS* ]]; then
    echo "Error: run as a regular user (sudo is used internally)." >&2
    exit 1
fi

# --- platform detection ---
OS="$(uname -s)"
SUDO=""
case "$OS" in
    MINGW*|MSYS*|CYGWIN*)
        PLATFORM="windows" ;;
    Darwin)
        PLATFORM="macos" ;;
    Linux)
        PLATFORM="linux"
        SUDO="sudo"
        if ! command -v dnf >/dev/null && ! command -v apt-get >/dev/null && ! command -v pacman >/dev/null; then
            echo "Error: no supported package manager found (dnf, apt, pacman)." >&2
            exit 1
        fi
        ;;
    *)
        echo "Error: unsupported platform ($OS)." >&2
        exit 1
        ;;
esac

log "Detected platform: $PLATFORM"

# --- 1. Packages ---
PKG=""
if [[ $PLATFORM == linux ]]; then
    if   command -v dnf      >/dev/null; then PKG="dnf"
    elif command -v apt-get  >/dev/null; then PKG="apt"
    elif command -v pacman   >/dev/null; then PKG="pacman"
    fi
elif [[ $PLATFORM == macos ]]; then
    PKG="brew"
    if ! command -v brew >/dev/null; then
        log "Homebrew not found; installing it first"
        run /bin/bash -c '$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)'
        if [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -x /usr/local/bin/brew ]]; then eval "$(/usr/local/bin/brew shellenv)"
        fi
    fi
elif [[ $PLATFORM == windows ]]; then
    PKG="winget"
    command -v winget >/dev/null || { echo "Error: winget not found. Install it from the Microsoft Store." >&2; exit 1; }
fi

pkg_install() {
    # $@ = package names, using the detected package manager
    case "$PKG" in
        dnf)    run $SUDO dnf install -y "$@" ;;
        apt)    run $SUDO apt-get update && run $SUDO apt-get install -y "$@" ;;
        pacman) run $SUDO pacman -S --needed --noconfirm "$@" ;;
        brew)   run brew install "$@" ;;
        winget) for p in "$@"; do run winget install --id "$p" -e --accept-source-agreements --accept-package-agreements; done ;;
    esac
}

have_pkg() {
    # True if a binary is available now (or will be after we just installed it)
    command -v "$1" >/dev/null
}

log "Installing core packages ($PKG)"
case "$PLATFORM" in
    linux)
        case "$PKG" in
            dnf)    pkg_install starship ghostty lsd neovim git ;;
            pacman) pkg_install starship ghostty lsd neovim git ;;
            apt)
                # starship/lsd availability varies by release; install what we can
                pkg_install neovim git || true
                have_pkg starship || pkg_install starship || true
                have_pkg lsd      || pkg_install lsd      || true
                ;;
        esac
        ;;
    macos)
        pkg_install starship lsd neovim git
        run brew install --cask ghostty
        ;;
    windows)
        pkg_install Starship.Starship Neovim.Neovim Git.Git
        pkg_install lsd-rs.lsd || warn "Could not install lsd via winget (skipping)"
        ;;
esac

# starship fallback for distros that don't package it (apt etc.)
if [[ $PLATFORM == linux ]] && ! have_pkg starship; then
    log "Installing starship via official install script"
    run sh -c 'curl -fsSL https://starship.rs/install.sh | sh -s -- -y'
fi

# --- 2. Helper for idempotent, backed-up config deployment ---
backup() {
    if [[ $DRY_RUN == 1 ]]; then
        [[ -e "$1" || -L "$1" ]] && log "[dry-run] Would back up $1"
    elif [[ -e "$1" || -L "$1" ]]; then
        warn "Backing up existing $1 -> $1.bak.$(date +%Y%m%d%H%M%S)"
        mv "$1" "$1.bak.$(date +%Y%m%d%H%M%S)"
    fi
    mkdir -p "$(dirname "$1")"
}

deploy_file() {
    # $1 = source, $2 = destination
    backup "$2"
    if [[ $DRY_RUN == 1 ]]; then
        log "[dry-run] Would install $1 -> $2"
    else
        install -m 644 "$1" "$2"
    fi
}

deploy_dir() {
    # $1 = source dir, $2 = destination dir
    backup "$2"
    if [[ $DRY_RUN == 1 ]]; then
        log "[dry-run] Would copy $1 -> $2"
    else
        cp -a "$1" "$2"
        chmod -R u+rwX "$2"
    fi
}

# --- 3. Starship ---
log "Deploying starship config"
if [[ $PLATFORM == windows ]]; then
    STARSHIP_DIR="${APPDATA:-$HOME/AppData/Roaming}/starship"
    deploy_file "$CONFIGS/starship.toml" "$STARSHIP_DIR/starship.toml"
else
    deploy_file "$CONFIGS/starship.toml" "$HOME/.config/starship.toml"
fi

# --- 4. Ghostty ---
case "$PLATFORM" in
    linux)
        log "Deploying ghostty config"
        deploy_file "$CONFIGS/ghostty/config.ghostty" "$HOME/.config/ghostty/config.ghostty"
        ;;
    macos)
        log "Deploying ghostty config"
        deploy_file "$CONFIGS/ghostty/config.ghostty" \
            "$HOME/Library/Application Support/com.mitchellh.ghostty/config"
        ;;
    windows)
        warn "Ghostty does not ship Windows builds yet; skipping its config"
        ;;
esac

# --- 5. Neovim (LazyVim starter + your plugin lockfile) ---
log "Deploying LazyVim config"
case "$PLATFORM" in
    windows) NVIM_DIR="${LOCALAPPDATA:-$HOME/AppData/Local}/nvim" ;;
    *)       NVIM_DIR="$HOME/.config/nvim" ;;
esac

deploy_dir "$CONFIGS/nvim" "$NVIM_DIR"

if [[ $DRY_RUN != 1 ]] && have_pkg nvim; then
    # Plugin data dirs: start fresh so lazy.nvim re-installs from lazy-lock.json
    case "$PLATFORM" in
        windows) rm -rf "${LOCALAPPDATA:-$HOME/AppData/Local}/nvim-data" ;;
        macos)   rm -rf "$HOME/.local/share/nvim" "$HOME/Library/Application Support/nvim" ;;
        *)       rm -rf "$HOME/.local/share/nvim" ;;
    esac

    log "Installing plugins (headless nvim)..."
    nvim --headless "+Lazy! restore" +qa 2>&1 | tail -n 5 || warn "Headless plugin install failed; run ':Lazy restore' manually"
else
    log "[dry-run] Would bootstrap plugins with 'nvim --headless \"+Lazy! restore\"'"
fi

# --- 6. Shell integration ---
case "$PLATFORM" in
    windows) RC_FILE="$HOME/.bashrc" ;;   # Git Bash
    macos|linux)
        case "$(basename "${SHELL:-bash}")" in
            zsh)  RC_FILE="$HOME/.zshrc"  ;;
            *)    RC_FILE="$HOME/.bashrc" ;;
        esac
        ;;
esac

log "Configuring shell integration in $RC_FILE"
run touch "$RC_FILE"

add_line() {
    # $1 = marker, $2 = line
    if [[ $DRY_RUN == 1 ]]; then
        grep -qxF "$1" "$RC_FILE" 2>/dev/null || log "[dry-run] Would append to $RC_FILE: $2"
    elif ! grep -qxF "$1" "$RC_FILE"; then
        printf '\n%s\n' "$2" >>"$RC_FILE"
    fi
}

if [[ "$(basename "${SHELL:-bash}")" == zsh ]]; then
    add_line 'eval "$(starship init zsh)"' 'eval "$(starship init zsh)"'
else
    add_line 'eval "$(starship init bash)"' 'eval "$(starship init bash)"'
fi
add_line "alias ls='lsd'"                  "alias ls='lsd'"
add_line 'alias vi="nvim"'                 'alias vi="nvim"'

log "Done. Restart your shell (or open Ghostty) to pick up the changes."
