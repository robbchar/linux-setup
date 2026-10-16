#!/usr/bin/env bash
# Step: claude — Claude Code (CLI) and the Claude desktop app
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$REPO_DIR/lib/common.sh"

# Commands follow Anthropic's docs:
#   https://code.claude.com/docs/en/setup          (Claude Code)
#   https://code.claude.com/docs/en/desktop-linux  (desktop app, beta)

# --- Claude Code: native installer. Lands in ~/.local/bin and updates itself.
if have claude || [[ -x "$HOME/.local/bin/claude" ]]; then
  skip "Claude Code already installed"
else
  run bash -c 'curl -fsSL https://claude.ai/install.sh | bash'
  ok "installed Claude Code (run \`claude\` to sign in)"
fi

# --- Claude desktop app: Anthropic's apt repo, so updates come with apt upgrade.
keyring=/usr/share/keyrings/claude-desktop-archive-keyring.asc
expected_fpr=31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE

if pkg_installed claude-desktop; then
  skip "Claude desktop app already installed"
else
  if [[ ! -f "$keyring" ]]; then
    run sudo curl -fsSLo "$keyring" https://downloads.claude.ai/claude-desktop/key.asc
  fi
  if [[ "$DRY_RUN" != 1 ]]; then
    fpr="$(gpg --show-keys --with-colons "$keyring" 2>/dev/null | awk -F: '/^fpr/{print $10; exit}')"
    if [[ "$fpr" != "$expected_fpr" ]]; then
      run sudo rm -f "$keyring"
      die "Claude signing key fingerprint was '$fpr', expected $expected_fpr. Removed the key; not installing."
    fi
    ok "signing key fingerprint verified"
  fi
  echo "deb [arch=amd64,arm64 signed-by=$keyring] https://downloads.claude.ai/claude-desktop/apt/stable stable main" \
    | write_root_file /etc/apt/sources.list.d/claude-desktop.list
  run sudo apt-get update -qq
  run sudo apt-get install -y claude-desktop
  ok "installed Claude desktop app"
fi

# --- Cowork runs tasks in a local VM and needs your user in the kvm group.
# (SVM is already on in this machine's BIOS.)
if [[ " $(id -nG "$USER") " == *" kvm "* ]]; then
  skip "$USER is already in the kvm group"
else
  run sudo usermod -aG kvm "$USER"
  ok "added $USER to the kvm group (takes effect after you log out and back in)"
fi
