#!/usr/bin/env bash
# Step: packages — install apt packages from packages/apt.txt
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$REPO_DIR/lib/common.sh"

mapfile -t wanted < <(sed -e 's/#.*//' -e 's/[[:space:]]//g' "$REPO_DIR/packages/apt.txt" | grep -v '^$')

missing=()
for pkg in "${wanted[@]}"; do
  pkg_installed "$pkg" || missing+=("$pkg")
done

if [[ ${#missing[@]} -eq 0 ]]; then
  skip "all ${#wanted[@]} packages already installed"
  exit 0
fi

run sudo apt-get update -qq

installable=()
for pkg in "${missing[@]}"; do
  if pkg_available "$pkg" || [[ "$DRY_RUN" == 1 ]]; then
    installable+=("$pkg")
  else
    warn "'$pkg' isn't available on this Ubuntu release, skipping"
  fi
done

if [[ ${#installable[@]} -gt 0 ]]; then
  run sudo apt-get install -y "${installable[@]}"
  ok "installed: ${installable[*]}"
fi
