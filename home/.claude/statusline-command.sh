#!/usr/bin/env bash
# Claude Code status line
# Shows: working dir (green) | git branch (cyan) | model | ctx bar | 5h bar | 5h reset time

PYTHON=$(command -v python3 python 2>/dev/null | head -1)

input=$(cat)

_py_json() {
  printf '%s' "$input" | "$PYTHON" -c "
import sys, json
try:
    d = json.load(sys.stdin)
    v = $1
    print(v if v else '', end='')
except Exception:
    print('', end='')
"
}

cwd=$(        _py_json "d.get('workspace', {}).get('current_dir') or d.get('cwd') or ''")
model=$(       _py_json "d.get('model', {}).get('display_name') or ''")
used_pct=$(    _py_json "str(d.get('context_window', {}).get('used_percentage', '') or '')")
five_hr_pct=$( _py_json "str(d.get('rate_limits', {}).get('five_hour', {}).get('used_percentage', '') or '')")

# Time until 5h reset: try reset_at (epoch) first, then remaining_seconds
five_hr_remaining=$(printf '%s' "$input" | "$PYTHON" -c "
import sys, json, time
try:
    d = json.load(sys.stdin)
    fh = d.get('rate_limits', {}).get('five_hour', {})
    reset_at = fh.get('resets_at')
    remaining = fh.get('remaining_seconds')
    if reset_at:
        secs = max(0, int(reset_at) - int(time.time()))
        print(secs, end='')
    elif remaining is not None:
        print(int(remaining), end='')
    else:
        print('', end='')
except Exception:
    print('', end='')
")

# One rev-parse yields the worktree root, both git dirs, and the branch, so it
# replaces the separate symbolic-ref call rather than adding a process.
# --path-format=absolute is required: without it a nested main checkout returns
# a relative common dir and would be misread as a linked worktree.
git_out=""
if [ -n "$cwd" ]; then
  git_out=$(git -C "$cwd" --no-optional-locks rev-parse \
    --path-format=absolute --show-toplevel --git-dir --git-common-dir \
    --path-format=relative --abbrev-ref HEAD 2>/dev/null)
fi

short_cwd=""
git_branch=""
if [ -n "$git_out" ]; then
  { read -r toplevel; read -r git_dir; read -r common_dir; read -r git_branch; } <<< "$git_out"

  repo_name="${toplevel##*/}"

  # The suffix is only shown when cwd is provably inside toplevel. Path case
  # and separators vary between the two, so compare normalized and lowercased.
  norm_cwd="${cwd//\\//}"
  suffix=""
  if [[ "${norm_cwd,,}" == "${toplevel,,}"/* ]]; then
    suffix="/${norm_cwd:$(( ${#toplevel} + 1 ))}"
  fi

  if [ "$git_dir" != "$common_dir" ]; then
    short_cwd="⑂ ${repo_name}${suffix}"    # linked worktree
  else
    short_cwd="⌂ ${repo_name}${suffix}"    # main checkout
  fi
  [ "$git_branch" = "HEAD" ] && git_branch="detached"
else
  parent="${cwd%/*}"
  short_cwd="../${parent##*/}/${cwd##*/}"
fi

# ── color helpers ─────────────────────────────────────────────────────────────
GREEN="\033[32m"
CYAN="\033[36m"
YELLOW="\033[33m"
RED="\033[31m"
DIM="\033[2m"
BOLD="\033[1m"
RESET="\033[0m"

# ── progress bar ──────────────────────────────────────────────────────────────
make_bar() {
  local pct="${1:-0}"
  local width="${2:-8}"
  local filled=$(printf '%.0f' "$(echo "$pct $width" | awk '{printf "%.0f", $1 * $2 / 100}')")
  local empty=$(( width - filled ))
  [ "$filled" -gt "$width" ] && filled=$width
  [ "$empty" -lt 0 ] && empty=0

  local color="$GREEN"
  if   [ "$(printf '%.0f' "$pct")" -ge 90 ]; then color="$RED"
  elif [ "$(printf '%.0f' "$pct")" -ge 70 ]; then color="$YELLOW"
  fi

  local bar=""
  [ "$filled" -gt 0 ] && bar+=$(printf "${color}%0.s▓${RESET}" $(seq 1 "$filled"))
  [ "$empty"  -gt 0 ] && bar+=$(printf "${DIM}%0.s░${RESET}" $(seq 1 "$empty"))
  printf "%b" "$bar"
}

# ── format seconds → Xh XXm ──────────────────────────────────────────────────
format_remaining() {
  local secs="$1"
  local h=$(( secs / 3600 ))
  local m=$(( (secs % 3600) / 60 ))
  printf "%dh %02dm" "$h" "$m"
}

# ── build line ────────────────────────────────────────────────────────────────
parts=""
case "$short_cwd" in
  "⑂ "*) parts+=$(printf "${BOLD}${GREEN}%s${RESET}" "$short_cwd") ;;
  *)     parts+=$(printf "${GREEN}%s${RESET}" "$short_cwd") ;;
esac

if [ -n "$git_branch" ]; then
  parts+=$(printf " ${CYAN}(%s)${RESET}" "$git_branch")
fi

if [ -n "$model" ]; then
  parts+=$(printf " %s" "$model")
fi

if [ -n "$used_pct" ]; then
  bar=$(make_bar "$used_pct" 8)
  pct_int=$(printf '%.0f' "$used_pct")
  lcolor="$GREEN"
  [ "$pct_int" -ge 90 ] && lcolor="$RED"
  [ "$pct_int" -ge 70 ] && [ "$pct_int" -lt 90 ] && lcolor="$YELLOW"
  parts+=$(printf " ctx:%b ${lcolor}%s%%${RESET}" "$bar" "$pct_int")
fi

if [ -n "$five_hr_pct" ]; then
  bar=$(make_bar "$five_hr_pct" 8)
  pct_int=$(printf '%.0f' "$five_hr_pct")
  lcolor="$GREEN"
  [ "$pct_int" -ge 90 ] && lcolor="$RED"
  [ "$pct_int" -ge 70 ] && [ "$pct_int" -lt 90 ] && lcolor="$YELLOW"
  parts+=$(printf " 5h:%b ${lcolor}%s%%${RESET}" "$bar" "$pct_int")

  # Append reset countdown if available
  if [ -n "$five_hr_remaining" ] && [ "$five_hr_remaining" -gt 0 ] 2>/dev/null; then
    countdown=$(format_remaining "$five_hr_remaining")
    parts+=$(printf " ${DIM}(%s)${RESET}" "$countdown")
  fi
fi

printf "%b" "$parts"