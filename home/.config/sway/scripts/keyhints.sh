#!/usr/bin/env bash
# Searchable list of every documented key binding (Super+/, or "? keys" in the bar).
#
# Reads the sway config: a "## description" line directly above a bindsym line
# becomes one entry. "## [keys] description" shows those keys instead, which is
# how grouped bindings (arrows, workspaces) get a single tidy entry.
#
#   bash keyhints.sh --print    print the list to the terminal instead
set -euo pipefail

config="$HOME/.config/sway/config"

list() {
  awk '
    function pretty(k,    parts, n, i, p, out) {
      n = split(k, parts, /\+/)
      out = ""
      for (i = 1; i <= n; i++) {
        p = parts[i]
        if (p == "$mod" || p == "Mod4") p = "Super"
        else if (p == "Mod1") p = "Alt"
        else if (p == "Return") p = "Enter"
        else if (p == "slash") p = "/"
        else if (p == "minus") p = "-"
        else if (p == "space") p = "Space"
        else if (length(p) == 1) p = toupper(p)
        out = out (i > 1 ? " + " : "") p
      }
      return out
    }
    /^[[:space:]]*## / {
      desc = $0; sub(/^[[:space:]]*## /, "", desc)
      if (substr(desc, 1, 1) == "[" && index(desc, "]") > 0) {
        close_at = index(desc, "]")
        keys = substr(desc, 2, close_at - 2)
        text = substr(desc, close_at + 1); sub(/^[[:space:]]+/, "", text)
        printf "%-33s %s\n", keys, text
        desc = ""
      }
      next
    }
    desc != "" && /^[[:space:]]*bindsym[[:space:]]/ {
      n = split($0, f, /[[:space:]]+/)
      for (i = 1; i <= n; i++) {
        if (f[i] == "" || f[i] == "bindsym" || f[i] ~ /^--/) continue
        printf "%-33s %s\n", pretty(f[i]), desc
        break
      }
      desc = ""; next
    }
    desc != "" && !/^[[:space:]]*$/ { desc = "" }
  ' "$config"
}

if [[ "${1:-}" == "--print" ]]; then
  list
else
  list | fuzzel --dmenu --prompt 'keys › ' --width 80 --lines 24 >/dev/null || true
fi
