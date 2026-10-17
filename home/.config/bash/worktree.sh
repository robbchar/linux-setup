# Git worktree helpers, wrapping ~/.claude/wt/wt.py.
# shellcheck shell=bash

# wt            list worktrees that have live Claude Code sessions
# wt ls --all   include sessions whose process has exited
# wt cd <name>  cd into a live session's worktree (name or unique prefix)
# wt branch <branch|pr>  print the worktree path holding a branch or PR
# A function, not a script, so `wt cd` can change the current shell's directory.
wt() {
  local script="${HOME}/.claude/wt/wt.py"
  if [[ "${1:-}" == "cd" ]]; then
    local target
    target=$(python3 "$script" path "${2:-}") || return 1
    cd "$target" || return 1
  else
    python3 "$script" "$@"
  fi
}

# Start the dev server for a branch or PR number, from anywhere in the repo.
dev() {
  local target app
  if [[ -z "${1:-}" ]]; then
    echo "usage: dev <branch|pr-number>" >&2
    return 2
  fi
  target=$(python3 "${HOME}/.claude/wt/wt.py" branch "$1") || return 1
  app="$target/ui"
  [[ -d "$app" ]] || app="$target"
  # A fresh worktree has no node_modules, and vite is not on PATH without it.
  [[ -d "$app/node_modules" ]] || (cd "$app" && yarn install) || return 1
  cd "$app" && yarn dev
}
