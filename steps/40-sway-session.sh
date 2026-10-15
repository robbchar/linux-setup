#!/usr/bin/env bash
# Step: sway-session — add "Sway (linux-setup)" to the login screen's session menu
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
