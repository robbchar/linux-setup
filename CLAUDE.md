# CLAUDE.md

Context for Claude sessions working in this repo.

## What this is

Robb's Ubuntu + Sway desktop, as code. `install.sh` takes a fresh Ubuntu (or the
Ubuntu live USB with Ventoy persistence, where most of the building happens) to
his full setup. The goal is to iterate on the setup through real use, then
reproduce it on a real install with one command. Read `README.md` for layout
and `NOTES.md` for decisions, the wishlist and open questions.

## Who you're working with

- Experienced developer (25+ years, frontend-heavy: JS/TS/React). Skip basics,
  but explain Linux-desktop specifics; he's coming from Windows + WSL2.
- New to tiling window managers. Wants a keyboard-driven setup but learns keys
  gradually, and the mouse should always keep working. Discoverability matters:
  the Super+/ key list is a core feature, not decoration.
- Picked Sway over Hyprland/Omarchy for Ubuntu stability. Hyprland may come later.

## Hardware

- Ryzen 9 5900XT, ASUS PRIME X570-PRO, NVIDIA RTX 3070 Ti
- The live USB runs nouveau. A real install will run NVIDIA's proprietary driver,
  which Sway only supports with `--unsupported-gpu` (handled in
  `system/sway-session.sh`). Consider both drivers when touching anything
  graphics-related.

## Layout

```
install.sh            runs steps/*.sh in order; --dry-run, --only, --list
lib/common.sh         helpers: run (dry-run aware), ok/skip/warn/die, pkg_installed, write_root_file, append_once
steps/NN-name.sh      one concern each; second line is "# Step: name — description"
packages/apt.txt      apt packages, one per line
packages/flatpak.txt  Flathub app IDs
home/                 mirrors ~; every file is symlinked to the same path under ~
system/               files copied outside ~ (need sudo; re-run the step after edits)
```

## Rules

1. **Change config by editing files in this repo**, never by writing into `~`
   directly. Files in `home/` are symlinked, so repo edits apply immediately.
   New config files go in `home/` and get linked with
   `bash install.sh --only dotfiles`.
2. **Ask before** any `sudo` command, editing anything outside this repo,
   removing packages, or running `apt upgrade`. In the live session, never
   upgrade the kernel; it can break the persistence overlay.
3. **Keep steps idempotent.** Check before changing, route every change
   through `run` (so `--dry-run` stays honest), and make re-runs no-ops.
4. **Invoke scripts with `bash path/to/script.sh`.** Don't rely on the
   executable bit; this repo was started on Windows and git may not record it.
5. **LF line endings only** (enforced by `.gitattributes`).
6. **Every new Sway binding gets a `## description` line directly above it.**
   That's how it shows up in the Super+/ menu. Use `## [keys] description` for
   grouped bindings. Don't silently reassign an existing binding; say what it
   replaces.
7. **New packages go in `packages/apt.txt`** (or `flatpak.txt`) with a short
   comment if their purpose isn't obvious.
8. **No secrets in the repo.** Machine-specific settings go in
   `~/.config/bash/local.sh` (untracked).
9. **Keep the theme consistent.** Catppuccin Mocha hex values are used in kitty,
   sway, waybar, fuzzel and mako. A color change usually touches all five.
10. When a decision gets made or a wishlist item lands, update `NOTES.md`.

## Checking your work

```bash
bash -n install.sh steps/*.sh lib/common.sh     # syntax
shellcheck install.sh steps/*.sh lib/common.sh   # if installed
bash install.sh --dry-run                        # what would change
sway -C                                          # validate sway config
bash home/.config/sway/scripts/keyhints.sh --print   # check the key list renders
```

Apply changes live:

- Sway (also restarts Waybar): `swaymsg reload`
- Mako: `makoctl reload`
- Kitty: Ctrl+Shift+F5 inside kitty
- Bash: `exec bash`

## Commits

Small and focused. The message says what changed and why
(e.g. "sway: Super+Tab toggles last workspace"). Commit after each working change
so the history shows how the setup evolved.
