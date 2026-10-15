# linux-setup

My Ubuntu + Sway setup as code. One script takes a fresh Ubuntu install (or the
live USB) to my desktop: tiling window manager, terminal, shell, apps and config.
I develop it on a Ventoy live USB with persistence, and it installs the same way
on the real machine later.

```bash
bash install.sh --dry-run   # see what it would change
bash install.sh             # do it (safe to re-run any time)
bash install.sh --list      # list the steps
bash install.sh --only dotfiles,sway-session
```

## What you get

| Piece | What | Config |
|---|---|---|
| Window manager | Sway (tiling, keyboard-first, mouse still works) | `home/.config/sway/config` |
| Bar | Waybar | `home/.config/waybar/` |
| Launcher | fuzzel (Super+D) | `home/.config/fuzzel/fuzzel.ini` |
| Notifications | mako | `home/.config/mako/config` |
| Terminal | kitty (foot as fallback) | `home/.config/kitty/kitty.conf` |
| Shell | bash + Starship prompt, fzf, zoxide, eza, bat | `home/.config/bash/`, `home/.config/starship.toml` |
| Apps | Claude Code + Claude Desktop, Chrome, VS Code, Obsidian, TIDAL Hi-Fi | `steps/50-claude.sh`, `steps/60-apps.sh`, `packages/` |
| Theme | Catppuccin Mocha everywhere | the files above |

Linear runs as a Chrome app: open linear.app in Chrome, then use the install icon
in the address bar.

## How it works

- **`install.sh`** runs each script in `steps/` in order. Every step checks
  before it changes anything, so re-running only does what's missing.
  `--dry-run` prints the commands instead of running them.
- **`home/`** mirrors your home folder. Each file is symlinked to the same path
  under `~`, so `home/.config/sway/config` becomes `~/.config/sway/config`.
  Because they're symlinks, editing either one edits the repo copy, and the
  change shows up in `git diff`. Anything that was already in the way is moved
  to `~/.dotfiles-backup/<timestamp>/`.
- **`packages/apt.txt`** and **`packages/flatpak.txt`** list what gets installed.
  Add a line and re-run.
- **`system/`** holds files copied outside your home folder (the login-screen
  session launcher). Re-run `--only sway-session` after editing them.
- **Bash**: Ubuntu's `~/.bashrc` stays as it is, plus one added line that loads
  `~/.config/bash/init.sh`. Put machine-specific or secret settings in
  `~/.config/bash/local.sh`, which isn't tracked.

## On the live USB

1. Set up persistence for the Ubuntu ISO on the Ventoy stick (see
   [Ventoy persistence](https://www.ventoy.net/en/plugin_persistence.html)).
   A 16 GB `casper-rw` file leaves room for apps. Boot with persistence on.
2. Get the repo:
   ```bash
   sudo apt update && sudo apt install -y git gh
   gh auth login
   gh repo clone <you>/linux-setup ~/linux-setup
   cd ~/linux-setup
   ```
3. `bash install.sh --dry-run`, read it over, then `bash install.sh`.
4. Log out. On the login screen, pick **Sway (linux-setup)** from the gear menu
   and log in. Live sessions can be odd here. If logging out doesn't give you
   a login screen, press Ctrl+Alt+F3, log in on the text console, and run
   `sway-session`.
5. Press **Super+/** for the key bindings.

Avoid `apt upgrade` in the live session. Kernel updates in particular can break
the persistence overlay. Treat the stick as the place to build config, not as
your daily OS, and push to GitHub often.

## Installing for real

1. Install Ubuntu, and tick **"Install third-party software for graphics"**
   so you get NVIDIA's driver.
2. Clone the repo and run `bash install.sh`, same as above.
3. Log out, pick **Sway (linux-setup)**, and log in.

## Learning the keys

You don't have to go keyboard-only. Click, scroll and drag all work, and you can
pick up keys gradually. **Super+/** (or "? keys" in the bar) lists every binding.
These are the ones worth learning first:

| Keys | Does |
|---|---|
| Super+Enter | Terminal |
| Super+D | App launcher |
| Super+Q | Close window |
| Super+Arrows | Move focus |
| Super+Shift+Arrows | Move the window |
| Super+1…0 | Switch workspace |
| Super+Shift+1…0 | Send window to workspace |
| Super+F | Fullscreen |
| Super+W / Super+E | Tabbed / back to tiled |
| Super+drag | Move a window with the mouse (right-drag resizes) |

## NVIDIA

- Sway doesn't officially support NVIDIA's proprietary driver. The
  **Sway (linux-setup)** session adds the `--unsupported-gpu` flag it needs.
  It generally works on current drivers, but Sway's developers won't help
  with NVIDIA-specific bugs.
- The live USB uses the open-source nouveau driver, which Sway supports directly.
- Sway needs `nvidia_drm` modeset turned on. Check with
  `cat /sys/module/nvidia_drm/parameters/modeset` (it should print `Y`).
  If it doesn't, add `nvidia-drm.modeset=1` to the kernel command line.
- Cursor or rendering glitches: see the commented toggles in
  `system/sway-session.sh`.

## Troubleshooting

- **Sway won't start:** `journalctl --user -b | grep -i sway`, or switch to a
  text console (Ctrl+Alt+F3), log in, and run `sway-session` to see errors.
- **Config error after an edit:** `sway -C` validates the config without
  starting anything.
- **Bar missing:** run `waybar` in a terminal to see its error.
- **Undo a link:** delete the symlink in `~`, then restore the original from
  `~/.dotfiles-backup/` if you want it back.
