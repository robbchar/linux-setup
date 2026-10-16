#!/usr/bin/env bash
# linux-setup installer. Safe to re-run: each step checks before it changes anything.
#
#   bash install.sh                  run every step
#   bash install.sh --dry-run        show what would change, change nothing
#   bash install.sh --only dotfiles  run only the named steps (comma-separated)
#   bash install.sh --list           list the steps
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export REPO_DIR
# shellcheck source=lib/common.sh
source "$REPO_DIR/lib/common.sh"

step_name() { local n="${1##*/}"; n="${n%.sh}"; echo "${n#*-}"; }
step_desc() { sed -n 's/^# Step: [^ ]* — //p' "$1" | head -1; }

only=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run) export DRY_RUN=1 ;;
    --only) only="${2:?--only needs a comma-separated list of steps}"; shift ;;
    --list)
      for f in "$REPO_DIR"/steps/*.sh; do
        printf '  %-14s %s\n' "$(step_name "$f")" "$(step_desc "$f")"
      done
      exit 0 ;;
    -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
  shift
done

# --- preflight -------------------------------------------------------------
[[ $EUID -ne 0 ]] || die "run this as your normal user; it uses sudo itself when needed"

# shellcheck disable=SC1091
. /etc/os-release
if [[ "${ID:-}" != ubuntu && "${ID_LIKE:-}" != *ubuntu* ]]; then
  warn "this repo targets Ubuntu; you're on ${PRETTY_NAME:-something else}. Continuing anyway."
fi
log "linux-setup on ${PRETTY_NAME:-unknown}$([[ $DRY_RUN == 1 ]] && echo ' (dry run: nothing will change)')"
if is_live_session; then
  warn "live USB session: changes only survive a reboot if you booted with a Ventoy persistence file"
fi

if [[ -n "$only" ]]; then
  for want in ${only//,/ }; do
    found=0
    for f in "$REPO_DIR"/steps/*.sh; do [[ "$(step_name "$f")" == "$want" ]] && found=1; done
    [[ $found == 1 ]] || die "no step named '$want' (see --list)"
  done
fi

if [[ "$DRY_RUN" != 1 ]]; then
  sudo -n true 2>/dev/null || sudo -v || die "this needs sudo for package installs"
fi

# --- steps ------------------------------------------------------------------
for f in "$REPO_DIR"/steps/*.sh; do
  name="$(step_name "$f")"
  if [[ -n "$only" && ",$only," != *",$name,"* ]]; then continue; fi
  log "$name: $(step_desc "$f")"
  bash "$f" || die "step '$name' failed. Fix it and re-run; finished steps will just be skipped."
done

log "Done."
if [[ "$DRY_RUN" != 1 ]]; then
  cat <<'EOF'

  Next: log out, click your name, use the gear icon to pick "Sway (linux-setup)",
  and log in. Once you're in Sway, press Super+/ to see every key binding.
EOF
fi
