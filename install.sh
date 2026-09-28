#!/usr/bin/env bash
# Installs starship, ghostty, lsd, neovim (LazyVim) and deploys configs.
# Expects the `configs/` directory to sit next to this script.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS="$SCRIPT_DIR/configs"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m==>\033[0m %s\n' "$*"; }

# --- sanity checks ---
if [[ ! -d "$CONFIGS" ]]; then
    echo "Error: $CONFIGS not found next to this script." >&2
    exit 1
fi
if [[ $EUID -eq 0 ]]; then
    echo "Error: run as a regular user (sudo is used internally)." >&2
    exit 1
fi

command -v dnf >/dev/null || { echo "This script targets Fedora (dnf)." >&2; exit 1; }

# --- 1. Packages (RPM, as currently installed) ---
log "Installing packages: starship, ghostty, lsd, neovim, git"
sudo dnf install -y starship ghostty lsd neovim git

# --- 2. Helper for idempotent, backed-up config deployment ---
backup() {
    if [[ -e "$1" || -L "$1" ]]; then
        warn "Backing up existing $1 -> $1.bak.$(date +%Y%m%d%H%M%S)"
        mv "$1" "$1.bak.$(date +%Y%m%d%H%M%S)"
    fi
    mkdir -p "$(dirname "$1")"
}

# --- 3. Starship ---
log "Deploying starship config"
backup "$HOME/.config/starship.toml"
install -m 644 "$CONFIGS/starship.toml" "$HOME/.config/starship.toml"

# --- 4. Ghostty ---
log "Deploying ghostty config"
backup "$HOME/.config/ghostty/config.ghostty"
install -m 644 "$CONFIGS/ghostty/config.ghostty" "$HOME/.config/ghostty/config.ghostty"

# --- 5. Neovim (LazyVim starter + your plugin lockfile) ---
log "Deploying LazyVim config to ~/.config/nvim"
if [[ -e "$HOME/.config/nvim" && ! -d "$HOME/.config/nvim/.git" ]]; then
    backup "$HOME/.config/nvim"
elif [[ -d "$HOME/.config/nvim/.git" ]]; then
    warn "~/.config/nvim is a git repo; replacing with a backup"
    backup "$HOME/.config/nvim"
fi
cp -a "$CONFIGS/nvim" "$HOME/.config/nvim"
chmod -R u+rwX "$HOME/.config/nvim"

# Plugin data dirs: start fresh so lazy.nvim re-installs from lazy-lock.json
rm -rf "$HOME/.local/share/nvim"

# Bootstrap plugins headlessly
log "Installing plugins (headless nvim)..."
nvim --headless "+Lazy! restore" +qa 2>&1 | tail -n 5

# --- 6. Shell integration in ~/.bashrc ---
log "Configuring shell aliases and starship init in ~/.bashrc"
touch "$HOME/.bashrc"

add_line() {
    # $1 = marker, $2 = line
    if ! grep -qxF "$1" "$HOME/.bashrc"; then
        printf '\n%s\n' "$2" >>"$HOME/.bashrc"
    fi
}
add_line 'eval "$(starship init bash)"' 'eval "$(starship init bash)"'
add_line "alias ls='lsd'"                "alias ls='lsd'"
add_line 'alias vi="nvim"'               'alias vi="nvim"'

log "Done. Restart your shell (or open Ghostty) to pick up the changes."
