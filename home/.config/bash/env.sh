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

# History: effectively unlimited (as on Windows), deduplicated, and shared
# across terminals as you go.
HISTSIZE=1000000
HISTFILESIZE=1000000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend
PROMPT_COMMAND="history -a${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

# Rust (rustup puts cargo and friends here).
[[ -d "$HOME/.cargo/bin" ]] && case ":$PATH:" in
  *":$HOME/.cargo/bin:"*) ;;
  *) export PATH="$HOME/.cargo/bin:$PATH" ;;
esac

shopt -s globstar      # ** matches nested directories
shopt -s checkwinsize

# npm/yarn: don't run package install scripts (supply-chain safety, carried over
# from Windows). Set here rather than in ~/.npmrc, which npm writes tokens into.
# Override once with `npm install --ignore-scripts=false`.
export npm_config_ignore_scripts=true
