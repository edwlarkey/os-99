# Shared helpers. Sourced, never run.

os99_hypr_candidates() {
  local dir
  [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && printf '%s\n' "$HYPRLAND_INSTANCE_SIGNATURE"
  hyprctl instances -j 2>/dev/null |
    sed -n 's/.*"instance": *"\([^"]*\)".*/\1/p'
  dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr"
  [[ -d $dir ]] && ls -t "$dir" 2>/dev/null
  return 0
}

os99_hypr_instance() {
  local sig seen=""
  while read -r sig; do
    [[ -n $sig ]] || continue
    case " $seen " in *" $sig "*) continue ;; esac
    seen="$seen $sig"
    if HYPRLAND_INSTANCE_SIGNATURE="$sig" hyprctl version >/dev/null 2>&1; then
      printf '%s\n' "$sig"
      return 0
    fi
  done < <(os99_hypr_candidates)
  return 1
}

os99_use_hyprland() {
  local sig
  sig=$(os99_hypr_instance) || return 1
  export HYPRLAND_INSTANCE_SIGNATURE="$sig"
  return 0
}

os99_state_dir() {
  local d="${XDG_STATE_HOME:-$HOME/.local/state}/os99"
  mkdir -p "$d" 2>/dev/null
  printf '%s\n' "$d"
}

os99_root() {
  local here src
  here=$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd) || here=""
  if [[ -n $here && -f $here/plugin/hyprbars/main.cpp ]]; then
    printf '%s\n' "$here"
    return 0
  fi
  src=$(cat "$(os99_state_dir)/source" 2>/dev/null) || src=""
  if [[ -n $src && -f $src/plugin/hyprbars/main.cpp ]]; then
    printf '%s\n' "$src"
    return 0
  fi
  return 1
}

os99_art_dir() {
  printf '%s\n' "${OS99_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/os99/decor}"
}

os99_config() {
  local c
  for c in "${OS99_CONFIG:-}" \
           "${XDG_CONFIG_HOME:-$HOME/.config}/hypr/os99-theme.toml"; do
    [[ -n $c && -f $c ]] && { printf '%s\n' "$c"; return 0; }
  done
  return 1
}

os99_newest_so() {
  local c newest=""
  for c in "$(cat "$HOME/.local/lib/libhyprbars-os99.path" 2>/dev/null)" \
           "$HOME/.local/lib/libhyprbars-os99.so"; do
    [[ -n $c && -f $c ]] || continue
    [[ -z $newest || $c -nt $newest ]] && newest="$c"
  done
  [[ -n $newest ]] || return 1
  printf '%s\n' "$newest"
}

os99_loaded_so() {
  local pid
  pid=$(pgrep -x Hyprland 2>/dev/null | head -1)
  [[ -n $pid && -r /proc/$pid/maps ]] || return 1
  grep -o "/[^ ]*libhyprbars[^ ]*" "/proc/$pid/maps" 2>/dev/null | sort -u | head -1
}

os99_hyprbars_paths() {
  local p
  for p in $(pgrep -x Hyprland 2>/dev/null); do
    grep -ho '/[^ ]*libhyprbars[^ ]*\.so' "/proc/$p/maps" 2>/dev/null
  done | sort -u
}

os99_hypr_abi() {
  local abi
  abi=$(hyprctl version 2>/dev/null | sed -n 's/^Version ABI string: *//p' | head -1)
  [[ -n $abi ]] || return 1
  printf '%s\n' "$abi"
}

os99_built_abi() {
  local abi
  abi=$(sed -n 's/^HYPRLAND_ABI=//p' "$HOME/.local/lib/libhyprbars-os99.built" 2>/dev/null | head -1)
  [[ -n $abi ]] || return 1
  printf '%s\n' "$abi"
}

os99_abi_stale() {
  local built running
  built=$(os99_built_abi)  || return 1
  running=$(os99_hypr_abi) || return 1
  [[ $built != "$running" ]] || return 1
  printf '%s\t%s\n' "$built" "$running"
}

os99_plugin_src() {
  local root
  if [[ -n ${OS99_PLUGIN_SRC:-} ]]; then
    [[ -f $OS99_PLUGIN_SRC/Makefile && -f $OS99_PLUGIN_SRC/main.cpp ]] || return 1
    printf '%s\n' "$OS99_PLUGIN_SRC"
    return 0
  fi
  root=$(os99_root) || return 1
  [[ -f $root/plugin/hyprbars/Makefile ]] || return 1
  printf '%s\n' "$root/plugin/hyprbars"
}

# Atomic replace. Follows a symlink once so a dotfiles link is not detached.
read -r -d '' _os99_publish_py <<'PYEOF' || true
import os, stat, sys, tempfile
target = os.path.realpath(sys.argv[1])
data = sys.stdin.buffer.read()
if not data:
    sys.exit("os99: refusing to write an empty file to %s" % target)
dirname = os.path.dirname(target) or "."
mode = stat.S_IMODE(os.stat(target).st_mode) if os.path.exists(target) else 0o644
fd, tmp = tempfile.mkstemp(prefix=".os99-", suffix=".tmp", dir=dirname)
try:
    os.fchmod(fd, mode)
    with os.fdopen(fd, "wb") as fh:
        fh.write(data)
        fh.flush()
        os.fsync(fh.fileno())
    os.replace(tmp, target)
    tmp = None
finally:
    if tmp is not None:
        try: os.unlink(tmp)
        except OSError: pass
dfd = os.open(dirname, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0))
try: os.fsync(dfd)
finally: os.close(dfd)
PYEOF

os99_publish() {
  python3 -c "$_os99_publish_py" "$1"
}
