#!/usr/bin/env bash
# Copy Claude Desktop's Code-tab session presets from Windows to Linux.
#
# Each Windows preset whose folder C:\Users\Admin\Projects\<name> exists here
# as ~/projects/<name> is added with the same name, model and effort. Presets
# already present (by name) are left alone; nothing is removed.
#
# The app rewrites this file while it runs, so quit Claude Desktop first
# (File > Quit, or the tray icon; closing the window isn't enough), run this
# from a normal terminal, then reopen the app.
#
# Usage: bash scripts/import-windows-presets.sh [--dry-run] [WINDOWS_PROFILE]
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$REPO_DIR/lib/common.sh"

[[ "${1:-}" == "--dry-run" || "${1:-}" == "-n" ]] && { DRY_RUN=1; shift; }

win="${1:-}"
if [[ -z "$win" ]]; then
  for d in /run/media/"$USER"/*/Users/Admin /media/"$USER"/*/Users/Admin /mnt/*/Users/Admin; do
    [[ -d "$d" ]] && { win="$d"; break; }
  done
fi
src="$(ls "$win"/AppData/Local/Packages/Claude_*/LocalCache/Roaming/Claude/ccd-session-presets.json 2>/dev/null | head -1 || true)"
[[ -f "$src" ]] || die "no Windows ccd-session-presets.json found; mount the drive or pass its Users/Admin path"
dest="$HOME/.config/Claude/ccd-session-presets.json"
[[ -f "$dest" ]] || die "$dest not found; open Claude Desktop once and sign in first"

if [[ "$DRY_RUN" != 1 ]] && pgrep -x claude-desktop >/dev/null; then
  die "Claude Desktop is still running; quit it (File > Quit or the tray icon) and re-run"
fi

log "importing presets from $src"
python3 - "$src" "$dest" "$HOME/projects" "$DRY_RUN" <<'EOF'
import json, os, shutil, sys, time

src, dest, projects, dry = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4] == "1"
win = json.load(open(src))
lin = json.load(open(dest))
changed = False

for acct, wv in win.get("byAccount", {}).items():
    lv = lin.setdefault("byAccount", {}).setdefault(acct, {"presets": []})
    have = {p.get("name") for p in lv.setdefault("presets", [])}
    for p in wv.get("presets", []):
        name = p.get("name")
        cwd = (p.get("target") or {}).get("cwd", "")
        folder = cwd.replace("\\", "/").rstrip("/").rsplit("/", 1)[-1]
        target = os.path.join(projects, folder)
        if name in have:
            print(f"  · preset {name} already exists")
            continue
        if p.get("target", {}).get("kind") != "local" or not os.path.isdir(target):
            print(f"  ! preset {name}: {target} not found; skipped")
            continue
        new = dict(p, target={"kind": "local", "cwd": target}, lastUsedAt=int(time.time() * 1000))
        lv["presets"].append(new)
        changed = True
        verb = "would add" if dry else "added"
        print(f"  ✓ {verb} preset {name} -> {target}")

if changed and not dry:
    shutil.copy2(dest, dest + ".bak")
    tmp = dest + ".tmp"
    with open(tmp, "w") as f:
        json.dump(lin, f, indent="\t")
    os.replace(tmp, dest)
    print(f"  ✓ saved (previous version at {dest}.bak)")
elif not changed:
    print("  · nothing to add")
EOF
