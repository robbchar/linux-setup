# Aliases.
# shellcheck shell=bash

alias ..='cd ..'
alias ...='cd ../..'

# Ubuntu installs these under different names to avoid clashes.
command -v batcat >/dev/null && ! command -v bat >/dev/null && alias bat='batcat'
command -v fdfind >/dev/null && ! command -v fd  >/dev/null && alias fd='fdfind'

if command -v eza >/dev/null; then
  alias ls='eza --group-directories-first'
  alias ll='eza -la --git --group-directories-first'
  alias lt='eza --tree --level=2 --group-directories-first'
else
  alias ll='ls -alF'
fi

alias g='git'
alias gs='git status -sb'
alias gl='git log --oneline --graph --decorate -20'

# Copy with a progress bar (%, speed, ETA). Works for files and directories.
alias cpv='rsync -ah --info=progress2'

alias reload='exec bash'       # pick up shell config changes
alias swayreload='swaymsg reload'
