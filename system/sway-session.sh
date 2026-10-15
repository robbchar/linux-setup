#!/usr/bin/env bash
# Installed to /usr/local/bin/sway-session by steps/40-sway-session.sh.
# The login screen runs this for the "Sway (linux-setup)" session.
# Edit it here in the repo, then: bash install.sh --only sway-session

# Login screens start sessions with a bare environment. Load the normal login
# profile so PATH includes ~/.local/bin (claude, starship) and Flatpak apps show
# up in the launcher.
set +u
# shellcheck disable=SC1091
[ -r /etc/profile ] && . /etc/profile
# shellcheck disable=SC1091
[ -r "$HOME/.profile" ] && . "$HOME/.profile"

export XDG_CURRENT_DESKTOP=sway
export XDG_SESSION_DESKTOP=sway
export MOZ_ENABLE_WAYLAND=1                # Firefox: native Wayland
export ELECTRON_OZONE_PLATFORM_HINT=auto   # VS Code, Obsidian, Claude: native Wayland

args=()

# NVIDIA's proprietary driver: Sway refuses to start without --unsupported-gpu.
# (Not needed on the open-source nouveau driver the live USB uses.)
if [ -d /sys/module/nvidia_drm ]; then
  args+=(--unsupported-gpu)

  # If you see glitches, try these one at a time, then re-run the install step:
  # export WLR_NO_HARDWARE_CURSORS=1   # invisible or flickering mouse cursor
  # export WLR_RENDERER=vulkan         # flicker or rendering artifacts

  modeset="$(cat /sys/module/nvidia_drm/parameters/modeset 2>/dev/null)"
  if [ "$modeset" != "Y" ]; then
    logger -t sway-session "nvidia_drm modeset is '$modeset' but Sway needs Y; see README > NVIDIA"
  fi
fi

exec sway "${args[@]}" "$@"
