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

# Version managers, each only if installed (the Node choice is still open in
# NOTES.md; these just make whichever one gets installed work).
if [[ -d "$HOME/.local/share/fnm" ]]; then
  export PATH="$HOME/.local/share/fnm:$PATH"
fi
command -v fnm >/dev/null && eval "$(fnm env --use-on-cd --shell bash)"

export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
[[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"
# shellcheck disable=SC1091
[[ -s "$NVM_DIR/bash_completion" ]] && . "$NVM_DIR/bash_completion"
# nvmu: switch to the Node version in this project's .nvmrc.
command -v nvm >/dev/null && alias nvmu='nvm use "$(cat .nvmrc)"'

if [[ -d "$HOME/.pyenv" ]]; then
  export PYENV_ROOT="$HOME/.pyenv"
  export PATH="$PYENV_ROOT/bin:$PATH"
  command -v pyenv >/dev/null && eval "$(pyenv init - bash)"
fi

if command -v starship >/dev/null; then
  eval "$(starship init bash)"
else
  # Fallback: the Windows Git Bash prompt. Green path, cyan (branch), then $.
  # shellcheck disable=SC1091
  [[ -f /usr/lib/git-core/git-sh-prompt ]] && . /usr/lib/git-core/git-sh-prompt
  if declare -F __git_ps1 >/dev/null; then
    PS1='\[\e[32m\]\w\[\e[m\] \[\e[36m\]$(__git_ps1 "(%s)")\[\e[m\]\$ '
  else
    PS1='\[\e[32m\]\w\[\e[m\] \$ '
  fi
fi
