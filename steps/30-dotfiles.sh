#!/usr/bin/env bash
# Step: dotfiles — symlink everything in home/ into ~ and hook bash up
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$REPO_DIR/lib/common.sh"

# Every *file* under home/ is linked to the same path under ~, so
# home/.config/sway/config  ->  ~/.config/sway/config
# Directories are created for real, which leaves room for untracked local files
# next to the tracked ones (e.g. ~/.config/bash/local.sh).
# Anything already in the way is moved to ~/.dotfiles-backup/<timestamp>/.

src_root="$REPO_DIR/home"
backup_root="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
linked=0 already=0

while IFS= read -r -d '' src; do
  rel="${src#"$src_root"/}"
  dest="$HOME/$rel"

  if [[ -L "$dest" && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
    already=$((already + 1))
    continue
  fi

  if [[ -e "$dest" || -L "$dest" ]]; then
    run mkdir -p "$(dirname "$backup_root/$rel")"
    run mv "$dest" "$backup_root/$rel"
    warn "moved existing ~/$rel to $backup_root/"
  fi

  run mkdir -p "$(dirname "$dest")"
  run ln -s "$src" "$dest"
  ok "linked ~/$rel"
  linked=$((linked + 1))
done < <(find "$src_root" -type f -print0 | sort -z)

[[ $already -gt 0 ]] && skip "$already files already linked"

# One line in ~/.bashrc loads our config; everything else lives in ~/.config/bash/.
# Ubuntu's own ~/.bashrc stays untouched otherwise.
# shellcheck disable=SC2016  # single quotes on purpose: expands when .bashrc runs
append_once "$HOME/.bashrc" "# linux-setup" \
  '[ -f "$HOME/.config/bash/init.sh" ] && . "$HOME/.config/bash/init.sh"  # linux-setup'

exit 0
