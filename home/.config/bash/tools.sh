# Tool integrations. Starship goes last because it takes over the prompt.
# shellcheck shell=bash

# zoxide: `z proj` jumps to your most-used directory matching "proj".
command -v zoxide >/dev/null && eval "$(zoxide init bash)"

# fzf: Ctrl+R fuzzy history, Ctrl+T insert a file path, Alt+C cd into a dir.
# Newer fzf can print its own bash setup; older Ubuntu releases ship a script instead.
if command -v fzf >/dev/null; then
  if _ls_fzf="$(fzf --bash 2>/dev/null)"; then
    eval "$_ls_fzf"
  elif [[ -f /usr/share/doc/fzf/examples/key-bindings.bash ]]; then
    # shellcheck disable=SC1091
    . /usr/share/doc/fzf/examples/key-bindings.bash
  fi
  unset _ls_fzf
fi

command -v starship >/dev/null && eval "$(starship init bash)"
