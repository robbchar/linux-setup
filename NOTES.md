# Notes

## Wishlist: the things that would make it click

Add to this as you notice them while using it. These drive what gets built next.

- [ ]

## Decisions

- **Ubuntu LTS as the base.** Officially supported by the Claude desktop app,
  biggest community, and the UI gets customized anyway, so a distro's own look
  matters little. (Tried Mint: felt like a lesser Windows. Pop worked but added
  nothing over Ubuntu once the desktop is replaced.)
- **Sway, not Hyprland (for now).** Sway is stable and in Ubuntu's own repos.
  Hyprland, which Omarchy uses, is better on NVIDIA but awkward to keep updated
  on Ubuntu. Revisit if NVIDIA + Sway causes real problems.
- **bash + Starship.** Ubuntu's bash is already a current 5.x release, so
  there's nothing to build.
- **Git config lives in `home/.config/git/`**, carried over from the Windows
  Git Bash setup (rebase autostash/autosquash, rerere, histogram diffs, the
  `git bd` alias). Windows-only bits (longpaths, gitk) were dropped.
- **npm install scripts are off** via `npm_config_ignore_scripts` in env.sh,
  not `~/.npmrc`, because npm writes auth tokens into that file.
- **`wt` and `dev` came over from Windows** as `home/.claude/wt/wt.py` plus
  bash functions in `worktree.sh`. The only real change is the liveness check:
  `/proc/<pid>/stat` instead of Win32 OpenProcess, and the roster's
  `procStart` must match the process start time there, so a recycled pid
  doesn't count as a live session. `dev` needs yarn, which isn't installed
  yet (see the Node version manager question below).
- **Claude Code config is split public/private.** Shareable parts (global
  CLAUDE.md, agents, commands, skills, hooks, statusline, settings.json) live
  in `home/.claude/`. The `you` and `linear-issues` skills (personal and client
  details), project memories, and the Context7 key never enter this public
  repo: `scripts/import-windows-claude.sh` copies them from the Windows drive.
  Memories map `C:\Users\Admin\Projects\<name>` to `~/projects/<name>`.
  Dropped from settings: Windows-path permissions, the `term-here` plugin dir.
  Code-tab session presets come over with `scripts/import-windows-presets.sh`,
  run with Claude Desktop quit (it rewrites that file while open).
- **kitty** for the terminal, with **foot** as a fallback.
- **Catppuccin Mocha** theme everywhere. Easy to change later.
- **Plain-text bar labels** ("cpu 12%") instead of icon glyphs. Can switch to
  Nerd Font icons later; the font is already installed.
- **Click to focus** (`focus_follows_mouse no`). Worth trying `yes` for a day.
- **install.sh enables universe itself.** The live USB ships with only
  main + restricted, so sway, kitty, fzf etc. had no install candidate. A
  bootstrap block now enables universe and installs curl, ca-certificates and
  gnupg before any step runs.
- **No `cmd | grep -q` under pipefail.** grep -q exits on the first match, the
  writer dies of SIGPIPE (141) and the check fails. This made `pkg_available`
  call every package "not available", even ones in main. Capture the output
  and test it with `[[ ]]` instead.
- **Live USB logs straight into Sway.** The live user has no password, so GDM
  never shows the gear menu; it starts the session stored in AccountsService.
  The sway-session step sets that to Sway on live sessions only. A real
  install keeps the gear and the choice.
- **Live detection doesn't trust `boot=casper`.** The 26.04 ISO under Ventoy
  doesn't pass it; `is_live_session` also checks for `/casper/` in the kernel
  path and casper's `/cow` overlay root.

## Open questions / ideas

- Node version manager: fnm, volta, or mise?
- Timekeeper app: needs a Linux build target.
- Claude Desktop's Quick Entry hotkey needs the GlobalShortcuts portal, which
  Sway's portal doesn't provide. Possible workaround: a Sway binding that
  launches or focuses the app.
- Clipboard history (cliphist), a wallpaper, an idle-inhibit toggle for
  watching video.
- Bluetooth applet (blueman) if needed.
