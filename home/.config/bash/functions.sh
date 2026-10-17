# Small shell functions, mostly from the dotfiles repo (Paul Irish's, forked).
# shellcheck shell=bash

# md DIR: make a directory (and parents) and cd into it.
md() { mkdir -p "$@" && cd "$@" || return; }

# whichlink CMD: where a command really lives, following symlinks.
whichlink() { readlink -f "$(command -v "$1")"; }

# server [PORT]: serve the current directory on localhost and open it.
server() {
  local port="${1:-8011}"
  (sleep 1 && xdg-open "http://localhost:$port/" >/dev/null 2>&1) &
  python3 -m http.server --bind 127.0.0.1 "$port"
}

# gz FILE: original vs gzipped size, in bytes.
gz() {
  printf 'orig size    (bytes): %s\n' "$(wc -c <"$1")"
  printf 'gzipped size (bytes): %s\n' "$(gzip -c "$1" | wc -c)"
}

# csvpreview FILE: scrollable aligned table of a CSV.
csvpreview() { sed 's/,,/, ,/g;s/,,/, ,/g' "$@" | column -s, -t | less -#2 -N -S; }

# extract ARCHIVE: unpack into a folder named after it, and cd there.
extract() {
  [[ -f "$1" ]] || { echo "'$1' is not a valid file" >&2; return 1; }
  local file folder existed=false
  file="$(realpath "$1")"
  folder="$(basename "$1")"; folder="${folder%%.*}"
  if [[ -d "$folder" ]]; then
    existed=true
    read -r -p "$folder already exists, extract into it anyway? (y/n) " -n 1; echo
    [[ $REPLY =~ ^[Yy]$ ]] || return
  fi
  mkdir -p "$folder" && cd "$folder" || return
  case "$file" in
    *.tar.bz2|*.tb2|*.tbz|*.tbz2) tar xjf "$file" ;;
    *.tar.gz|*.tgz|*.taz|*.tar.Z) tar xzf "$file" ;;
    *.tar.xz|*.txz)               tar xJf "$file" ;;
    *.tar.zst)                    tar --zstd -xf "$file" ;;
    *.tar)                        tar xf "$file" ;;
    *.zip)                        unzip -q "$file" ;;
    *)
      echo "'$1' cannot be extracted by extract" >&2
      cd .. || return
      $existed || rmdir "$folder"
      return 1 ;;
  esac
}
