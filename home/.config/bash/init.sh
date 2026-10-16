# Loaded by one line in ~/.bashrc (added by install.sh, marked "# linux-setup").
# Ubuntu's own ~/.bashrc runs first; this layers our setup on top.
# shellcheck shell=bash

[[ $- == *i* ]] || return 0   # interactive shells only

_ls_dir="$HOME/.config/bash"
for _ls_f in env aliases worktree tools; do
  # shellcheck disable=SC1090
  [[ -f "$_ls_dir/$_ls_f.sh" ]] && . "$_ls_dir/$_ls_f.sh"
done

# Untracked, machine-specific extras (tokens, client-specific aliases) go in
# ~/.config/bash/local.sh. It isn't in the repo, so it never gets committed.
# shellcheck disable=SC1091
[[ -f "$_ls_dir/local.sh" ]] && . "$_ls_dir/local.sh"

unset _ls_dir _ls_f
