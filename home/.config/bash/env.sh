# Environment and shell behavior.
# shellcheck shell=bash

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

if command -v code >/dev/null; then
  export EDITOR="code --wait"
else
  export EDITOR=nano
fi
export VISUAL="$EDITOR"

# History: large, deduplicated, and shared across terminals as you go.
HISTSIZE=50000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend
PROMPT_COMMAND="history -a${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

shopt -s globstar      # ** matches nested directories
shopt -s checkwinsize
