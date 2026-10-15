#!/usr/bin/env bash
# Step: shell-tools — Starship prompt and the JetBrainsMono Nerd Font (for icons)
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$REPO_DIR/lib/common.sh"

# --- Starship: prefer Ubuntu's package; older releases don't have it, so fall
# back to the official installer into ~/.local/bin (no sudo).
if have starship; then
  skip "starship already installed ($(starship --version | head -1))"
elif pkg_available starship; then
  run sudo apt-get install -y starship
  ok "installed starship (apt)"
else
  run mkdir -p "$HOME/.local/bin"
  run sh -c 'curl -fsSL https://starship.rs/install.sh | sh -s -- --yes --bin-dir "$HOME/.local/bin"'
  ok "installed starship into ~/.local/bin"
fi

# --- Nerd Font: not packaged by Ubuntu. Kitty, Waybar and Starship use it for icons.
font_dir="$HOME/.local/share/fonts/JetBrainsMonoNerd"
if compgen -G "$font_dir/*.ttf" >/dev/null; then
  skip "JetBrainsMono Nerd Font already installed"
else
  tmp="$(mktemp -d)"
  run curl -fsSL -o "$tmp/font.tar.xz" \
    https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz
  run mkdir -p "$font_dir"
  run tar -xJf "$tmp/font.tar.xz" -C "$font_dir"
  run fc-cache -f "$font_dir"
  rm -rf "$tmp"
  ok "installed JetBrainsMono Nerd Font"
fi
