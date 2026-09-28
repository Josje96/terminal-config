# terminal-config

My personal terminal setup: an installer script plus configs for
[starship](https://starship.rs), [Ghostty](https://ghostty.org), [Neovim
(LazyVim)](https://www.lazyvim.org) and [lsd](https://github.com/lsd-rs/lsd).

## Supported platforms

| Platform      | Package manager | Notes                                            |
| ------------- | --------------- | ------------------------------------------------ |
| Fedora/RHEL   | dnf             | Fully supported (ghostty, lsd, etc. all in repos)|
| Arch          | pacman          | Fully supported                                  |
| Debian/Ubuntu | apt             | starship/lsd fall back to official install script if not packaged; ghostty is skipped if unavailable |
| macOS         | Homebrew        | Ghostty installed as a cask; config goes to `~/Library/Application Support/com.mitchellh.ghostty/` |
| Windows       | winget          | Run from Git Bash; ghostty is skipped (no Windows build yet) |

## What's in here

```
.
├── install.sh          # Cross-platform installer
├── configs/
│   ├── starship.toml   # Starship prompt config
│   ├── ghostty/
│   │   └── config.ghostty
│   └── nvim/           # LazyVim starter config + lazy-lock.json
```

## Usage

Run as a regular user (the script calls `sudo` internally on Linux where needed):

```bash
./install.sh
```

Preview what it will do without changing anything:

```bash
DRY_RUN=1 ./install.sh
```

The script will:

1. Detect your platform and install `starship`, `ghostty`, `lsd`, `neovim`
   and `git` (skipping anything not available, with a warning)
2. Deploy configs to the right location for your OS, backing up any existing
   files as `<name>.bak.<timestamp>`
3. Copy the LazyVim config to the nvim config dir, wipe plugin data dirs and
   reinstall plugins headlessly from `lazy-lock.json`
4. Append starship init and `lsd` / `nvim` aliases to your shell rc
   (`.bashrc`/`.zshrc`, idempotent)

Then restart your shell (or open Ghostty) to pick up the changes.
