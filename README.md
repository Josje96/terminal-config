# terminal-config

My personal Fedora terminal setup: an installer script plus configs for
[starship](https://starship.rs), [Ghostty](https://ghostty.org), [Neovim
(LazyVim)](https://www.lazyvim.org) and [lsd](https://github.com/lsd-rs/lsd).

## What's in here

```
.
├── install.sh          # One-shot installer for Fedora (dnf-based)
├── configs/
│   ├── starship.toml   # Starship prompt config
│   ├── ghostty/
│   │   └── config.ghostty
│   └── nvim/           # LazyVim starter config + lazy-lock.json
```

## Usage

Run as a regular user (the script calls `sudo` internally where needed):

```bash
./install.sh
```

The script will:

1. Install `starship`, `ghostty`, `lsd`, `neovim` and `git` via `dnf`
2. Deploy configs to `~/.config/`, backing up any existing files as
   `<name>.bak.<timestamp>`
3. Copy the LazyVim config to `~/.config/nvim`, wipe `~/.local/share/nvim`
   and reinstall plugins headlessly from `lazy-lock.json`
4. Append starship init and `lsd` / `nvim` aliases to `~/.bashrc` (idempotent)

Then restart your shell (or open Ghostty) to pick up the changes.
