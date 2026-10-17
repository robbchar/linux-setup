#!/usr/bin/env bash
# Copy the private half of the Windows Claude Code setup into ~/.claude.
#
# The shareable half (CLAUDE.md, agents, commands, skills, hooks, settings) is
# tracked in home/.claude/. This script handles what must never enter this
# public repo: the "you" and "linear-issues" skills, per-project memories, and
# the Context7 MCP server with its API key.
#
# Usage: bash scripts/import-windows-claude.sh [--dry-run] [WINDOWS_PROFILE]
#   WINDOWS_PROFILE defaults to the first mounted .../Users/Admin.
#   Mount the drive first: udisksctl mount -b /dev/nvme0n1p3 -t ntfs -o ro
#
# Memories are keyed by project path. Windows C:\Users\Admin\Projects\<name>
# maps to ~/projects/<name>. Existing files are never overwritten.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$REPO_DIR/lib/common.sh"

[[ "${1:-}" == "--dry-run" || "${1:-}" == "-n" ]] && { DRY_RUN=1; shift; }

win="${1:-}"
if [[ -z "$win" ]]; then
  for d in /run/media/"$USER"/*/Users/Admin /media/"$USER"/*/Users/Admin /mnt/*/Users/Admin; do
    [[ -d "$d/.claude" ]] && { win="$d"; break; }
  done
fi
[[ -n "$win" && -d "$win/.claude" ]] || die "no Windows profile with a .claude folder found; mount the drive or pass its Users/Admin path"
src="$win/.claude"
log "importing from $src"

# Claude Code's project key: the absolute path with every non-alphanumeric
# character replaced by "-".
project_key() { printf '%s' "$1" | sed 's/[^A-Za-z0-9]/-/g'; }

# --- private skills
for s in you linear-issues; do
  if [[ ! -d "$src/skills/$s" ]]; then
    skip "skill $s not on Windows"
  elif [[ -e "$HOME/.claude/skills/$s" ]]; then
    skip "skill $s already in ~/.claude/skills"
  else
    run mkdir -p "$HOME/.claude/skills"
    run cp -r "$src/skills/$s" "$HOME/.claude/skills/$s"
    ok "copied skill $s"
  fi
done

# --- memories: match each Windows project folder to its encoded key, so names
# with spaces or underscores map back to the real folder name.
declare -A win_names=()
if [[ -d "$win/Projects" ]]; then
  for p in "$win/Projects"/*/; do
    n="$(basename "$p")"
    win_names["$(project_key "C:\\Users\\Admin\\Projects\\$n")"]="$n"
  done
fi

for mem in "$src"/projects/*/memory; do
  [[ -d "$mem" ]] || continue
  wkey="$(basename "$(dirname "$mem")")"
  name="${win_names[$wkey]:-}"
  if [[ -z "$name" ]]; then
    warn "no Windows project folder matches $wkey; skipped"
    continue
  fi
  dest="$HOME/.claude/projects/$(project_key "$HOME/projects/$name")/memory"
  new="$(rsync -a --ignore-existing --dry-run --out-format='%n' "$mem/" "$dest/" | grep -vc '/$' || true)"
  if [[ "$new" == 0 ]]; then
    skip "memories for $name already imported"
  else
    run mkdir -p "$dest"
    run rsync -a --ignore-existing --chmod=D755,F644 "$mem/" "$dest/"
    ok "$new memory files for ~/projects/$name"
  fi
done

# --- Context7 MCP server (user scope, stored in ~/.claude.json). The key is
# read from the Windows settings.json and never printed.
if ! have claude; then
  warn "claude not installed; skipping Context7"
elif claude mcp get context7 >/dev/null 2>&1; then
  skip "Context7 MCP server already configured"
else
  key="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("mcpServers",{}).get("context7",{}).get("headers",{}).get("CONTEXT7_API_KEY",""))' "$src/settings.json" 2>/dev/null || true)"
  if [[ -z "$key" ]]; then
    warn "no Context7 key in Windows settings.json; skipped"
  elif [[ "$DRY_RUN" == 1 ]]; then
    ok "add Context7 MCP server (user scope)"
  else
    claude mcp add --scope user --transport http context7 https://mcp.context7.com/mcp \
      --header "CONTEXT7_API_KEY: $key" >/dev/null
    ok "added Context7 MCP server (user scope)"
  fi
  unset key
fi
