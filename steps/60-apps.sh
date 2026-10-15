#!/usr/bin/env bash
# Step: apps — Chrome, VS Code, and the Flatpak apps in packages/flatpak.txt
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$REPO_DIR/lib/common.sh"

# install_deb PACKAGE URL   Download a vendor .deb and install it with apt.
# Chrome and VS Code each add their own apt repo when installed this way,
# so after the first install they update with a normal `apt upgrade`.
install_deb() {
  local pkg="$1" url="$2" tmp
  if pkg_installed "$pkg"; then
    skip "$pkg already installed"
    return 0
  fi
  tmp="$(mktemp -d)"
  run curl -fsSL -o "$tmp/$pkg.deb" "$url"
  run sudo apt-get install -y "$tmp/$pkg.deb"
  rm -rf "$tmp"
  ok "installed $pkg"
}

install_deb google-chrome-stable \
  https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb

# VS Code's package asks whether to add Microsoft's apt repo; answer yes up front.
if ! pkg_installed code; then
  if [[ "$DRY_RUN" == 1 ]]; then
    printf '  [dry-run] preseed debconf: code code/add-microsoft-repo boolean true\n'
  else
    echo "code code/add-microsoft-repo boolean true" | sudo debconf-set-selections
  fi
fi
install_deb code 'https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64'

# --- Flatpak apps, installed for this user only (no sudo).
if ! have flatpak; then
  warn "flatpak isn't installed yet (it's in packages/apt.txt), skipping Flatpak apps"
  exit 0
fi
run flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

mapfile -t apps < <(sed -e 's/#.*//' -e 's/[[:space:]]//g' "$REPO_DIR/packages/flatpak.txt" | grep -v '^$')
for app in "${apps[@]}"; do
  if flatpak info --user "$app" >/dev/null 2>&1; then
    skip "$app already installed"
  else
    run flatpak install --user -y --noninteractive flathub "$app"
    ok "installed $app"
  fi
done
