# Shared helpers for install.sh and steps/*.sh. Sourced, never run directly.
# shellcheck shell=bash

REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
DRY_RUN="${DRY_RUN:-0}"

if [[ -t 1 ]]; then
  C_RESET=$'\e[0m' C_BOLD=$'\e[1m' C_DIM=$'\e[2m'
  C_BLUE=$'\e[34m' C_GREEN=$'\e[32m' C_YELLOW=$'\e[33m' C_RED=$'\e[31m'
else
  C_RESET='' C_BOLD='' C_DIM='' C_BLUE='' C_GREEN='' C_YELLOW='' C_RED=''
fi

log()  { printf '%s==>%s %s\n' "$C_BLUE$C_BOLD" "$C_RESET" "$*"; }
ok() {
  if [[ "$DRY_RUN" == 1 ]]; then printf '  %s→%s would: %s\n' "$C_YELLOW" "$C_RESET" "$*"
  else printf '  %s✓%s %s\n' "$C_GREEN" "$C_RESET" "$*"; fi
}
skip() { printf '  %s·%s %s\n' "$C_DIM" "$C_RESET" "$*"; }
warn() { printf '  %s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
die()  { printf '%sERROR:%s %s\n' "$C_RED$C_BOLD" "$C_RESET" "$*" >&2; exit 1; }

# run CMD ARGS...   Execute a command that changes something.
# Under --dry-run it only prints the command. Every change goes through this.
run() {
  if [[ "$DRY_RUN" == 1 ]]; then
    printf '  %s[dry-run]%s %s\n' "$C_YELLOW" "$C_RESET" "$*"
    return 0
  fi
  "$@"
}

have() { command -v "$1" >/dev/null 2>&1; }

# True when booted from the Ubuntu live USB rather than an installed system.
is_live_session() { grep -qw 'boot=casper' /proc/cmdline 2>/dev/null; }

# True if an apt package is installed.
# (These capture output instead of piping into `grep -q`: grep -q exits on the
# first match, the writer gets SIGPIPE, and under pipefail the check fails.)
pkg_installed() { [[ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null)" == *'install ok installed'* ]]; }

# True if apt can install the package on this release (after `apt-get update`).
pkg_available() { [[ "$(apt-cache policy "$1" 2>/dev/null)" =~ Candidate:\ [^\(] ]]; }

# True if an apt source enables the universe component (deb822 .sources or one-line .list).
universe_enabled() {
  grep -rqsE '^[[:space:]]*(Components:|deb[[:space:]]).*[[:space:]]universe([[:space:]]|$)' \
    /etc/apt/sources.list /etc/apt/sources.list.d/
}

# write_root_file DEST [MODE] < content
# Writes stdin to a root-owned file, only if the content actually changed.
write_root_file() {
  local dest="$1" mode="${2:-0644}" tmp
  tmp="$(mktemp)"
  cat >"$tmp"
  if [[ -f "$dest" ]] && cmp -s "$tmp" "$dest"; then
    skip "$dest is up to date"
  else
    run sudo install -D -m "$mode" "$tmp" "$dest"
    ok "wrote $dest"
  fi
  rm -f "$tmp"
}

# append_once FILE MARKER LINE
# Appends LINE to FILE unless a line containing MARKER is already there.
append_once() {
  local file="$1" marker="$2" line="$3"
  if [[ -f "$file" ]] && grep -qF -- "$marker" "$file"; then
    skip "$file already has the $marker hook"
    return 0
  fi
  if [[ "$DRY_RUN" == 1 ]]; then
    printf '  %s[dry-run]%s append to %s: %s\n' "$C_YELLOW" "$C_RESET" "$file" "$line"
  else
    printf '\n%s\n' "$line" >>"$file"
    ok "added hook to $file"
  fi
}
