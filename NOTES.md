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
- **kitty** for the terminal, with **foot** as a fallback.
- **Catppuccin Mocha** theme everywhere. Easy to change later.
- **Plain-text bar labels** ("cpu 12%") instead of icon glyphs. Can switch to
  Nerd Font icons later; the font is already installed.
- **Click to focus** (`focus_follows_mouse no`). Worth trying `yes` for a day.
- **install.sh enables universe itself.** The live USB ships with only
  main + restricted, so sway, kitty, fzf etc. had no install candidate and
  were silently skipped. A bootstrap block now enables universe and installs
  curl, ca-certificates and gnupg before any step runs.

## Open questions / ideas

- Node version manager: fnm, volta, or mise?
- Git config (name, email, aliases): add `home/.config/git/config`?
- Timekeeper app: needs a Linux build target.
- Claude Desktop's Quick Entry hotkey needs the GlobalShortcuts portal, which
  Sway's portal doesn't provide. Possible workaround: a Sway binding that
  launches or focuses the app.
- Clipboard history (cliphist), a wallpaper, an idle-inhibit toggle for
  watching video.
- Bluetooth applet (blueman) if needed.
