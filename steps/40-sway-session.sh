#!/usr/bin/env bash
# Step: sway-session — add "Sway (linux-setup)" to the login screen (and make it the default on the live USB)
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$REPO_DIR/lib/common.sh"

# Ubuntu's sway package already adds a plain "Sway" session, but it won't start
# on NVIDIA's proprietary driver without an extra flag. This session goes through
# system/sway-session.sh, which adds that flag only when it's needed.
# These are copies, not symlinks (the login screen runs before ~ is available),
# so re-run this step after editing system/sway-session.sh.

write_root_file /usr/local/bin/sway-session 0755 <"$REPO_DIR/system/sway-session.sh"

write_root_file /usr/share/wayland-sessions/sway-linux-setup.desktop 0644 <<'EOF'
[Desktop Entry]
Name=Sway (linux-setup)
Comment=Sway tiling session configured by the linux-setup repo
Exec=/usr/local/bin/sway-session
Type=Application
DesktopNames=sway
EOF

# The live USB user has no password and logs in automatically, so the login
# screen never shows the gear menu. It just starts the session stored for the
# user in AccountsService, so store ours there. (A real install has a password,
# so the gear shows up and the choice stays yours.)
# To go back to GNOME: Ctrl+Alt+F3, log in, then run the busctl command below
# with "ubuntu" in place of "$session".
if is_live_session; then
  session=sway-linux-setup
  user_path=/org/freedesktop/Accounts/User$(id -u)
  current="$(busctl get-property org.freedesktop.Accounts "$user_path" \
    org.freedesktop.Accounts.User Session 2>/dev/null || true)"
  if [[ "$current" == "s \"$session\"" ]]; then
    skip "login already defaults to $session"
  elif run busctl call org.freedesktop.Accounts "$user_path" \
      org.freedesktop.Accounts.User SetSession s "$session"; then
    ok "login now defaults to $session (live session has no gear menu)"
  else
    warn "couldn't set the default session; pick Sway from a text console instead (see README > Troubleshooting)"
  fi
fi
