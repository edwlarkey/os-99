# The few things every OS 99 script needs, in one place. Sourced, never run.
#
#   source "$(dirname -- "$(readlink -f "$0")")/os99-lib.sh"
#
# Kept deliberately small. This is not a framework; it is the two or three
# answers that were being written out separately in every script, and were
# therefore wrong in every script at once.

# ---------------------------------------------------------------- Hyprland
#
# WHICH HYPRLAND. Every one of these scripts used to do this:
#
#     HYPRLAND_INSTANCE_SIGNATURE=$(ls -t "$XDG_RUNTIME_DIR/hypr" | head -1)
#
# -- the newest instance DIRECTORY. Those directories outlive the compositors
# that made them, and their mtimes do not order themselves the way you would
# hope, so on a machine that has logged in and out a few times this reliably
# picks a corpse. Everything downstream then talks to a socket nobody is
# listening on and reports, quite calmly, that nothing is wrong.
#
# So: ask, do not guess. `hyprctl instances` enumerates them, an explicit
# signature in the environment is tried first because it may be right and older,
# and every candidate is PROVED with a call that has to reach the compositor.
# `hyprctl version` exits 4 when it cannot connect, which is the whole test.
os99_hypr_candidates() {
  local dir
  [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && printf '%s\n' "$HYPRLAND_INSTANCE_SIGNATURE"
  hyprctl instances -j 2>/dev/null |
    sed -n 's/.*"instance": *"\([^"]*\)".*/\1/p'
  # Last resort: the directories themselves, newest first. Only ever reached
  # when hyprctl cannot enumerate, and still proved before it is used.
  dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr"
  [[ -d $dir ]] && ls -t "$dir" 2>/dev/null
  return 0
}

# Print the signature of a Hyprland that answers, or nothing.
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

# Export it, or leave the environment alone and say so. Callers that can work
# without a compositor (os99-install --status) check the return; callers that
# cannot should say what they are missing rather than talk to a dead socket.
os99_use_hyprland() {
  local sig
  sig=$(os99_hypr_instance) || return 1
  export HYPRLAND_INSTANCE_SIGNATURE="$sig"
  return 0
}

# ------------------------------------------------------------------- state
#
# One directory for everything OS 99 knows that is not configuration: whether
# the frame plugin loaded, whether the widget did, whether an install was
# interrupted. Nothing in here is precious -- deleting it costs a notification,
# not a setting.
os99_state_dir() {
  local d="${XDG_STATE_HOME:-$HOME/.local/state}/os99"
  mkdir -p "$d" 2>/dev/null
  printf '%s\n' "$d"
}

# ------------------------------------------------------------------- liveness
#
# Did OS 99's QML actually load into the running shell? A widget that failed to
# load cannot report that it failed to load, so the question has to be asked
# from outside -- and the plugin's panel registers an IPC target the moment it
# is constructed, which makes "does that target answer" exactly the right
# question. No pids, no heartbeat files, no clock skew.
#
#   0  loaded          1  not loaded          2  cannot tell
#
# NOTE for anyone tempted by `omarchy-shell -q`: quiet mode is best-effort and
# exits 0 even when the shell, the target or the method is missing. It is
# useless as a probe. This deliberately does not use it.
# Wait until omarchy-shell will answer at all, or give up.
#
# A theme switch keeps the shell busy for a second or two, and anything that
# talks to it in that window fails with "omarchy-shell is not responding" --
# `omarchy plugin add` did during the first from-scratch install, and `omarchy
# plugin remove` did twice from inside os99-install --remove, each time working
# immediately when run by hand a moment later. The caller looks broken; the
# shell was just busy.
os99_shell_ready() {
  local try
  command -v omarchy-shell >/dev/null 2>&1 || return 1
  for try in $(seq 1 "${1:-15}"); do
    [[ $(timeout 3 omarchy-shell shell ping 2>/dev/null) == ok ]] && return 0
    sleep 1
  done
  return 1
}

os99_widget_loaded() {
  local try
  command -v omarchy-shell >/dev/null 2>&1 || return 2
  [[ -n $(pgrep -x quickshell 2>/dev/null) ]] || return 2
  # Three tries, because one silence is not an answer. A shell in the middle of
  # applying a theme has better things to do than answer an IPC call, and a
  # single timeout there would report the widget as broken in the middle of the
  # very run that installs it.
  for try in 1 2 3; do
    [[ $(timeout 5 omarchy-shell os99 ping 2>/dev/null) == ok ]] && return 0
    sleep 1
  done
  return 1
}

# ----------------------------------------------------------------- helpers
#
# A companion script, found BESIDE this one first. The bar widget runs the copy
# in the installed plugin directory, and the shell process's PATH is not a login
# shell's -- it does not necessarily carry ~/.local/bin. Sibling, then the usual
# install location, then PATH.
os99_sibling() {
  local here candidate
  here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd) || here=""
  for candidate in "$here/$1" "$HOME/.local/bin/$1"; do
    [[ -n $candidate && -x $candidate ]] && { printf '%s\n' "$candidate"; return 0; }
  done
  command -v "$1" 2>/dev/null
}

# ---------------------------------------------------------------- the plugin
#
# WHERE THE .so COMES FROM, and which one wins.
#
#   ~/.local/lib, named by a pointer file -- a hand build, content-hashed
#     because Hyprland does not fully dlclose a plugin and dlopen on a
#     previously-seen PATH hands back the stale handle.
#   /usr/lib/libhyprbars-os99.so -- the package. One fixed path, which is fine
#     because a package is replaced by a session, not by a reload.
#
# The NEWEST wins rather than a fixed order. Preferring the hand build outright
# is right for somebody who has just rebuilt and wrong for somebody who ran
# --auto once and installed the package afterwards, whose package would be
# silently ignored. "Whichever was put there last" is right in both cases.
os99_newest_so() {
  local c newest=""
  for c in "$(cat "$HOME/.local/lib/libhyprbars-os99.path" 2>/dev/null)" \
           "$HOME/.local/lib/libhyprbars-os99.so" \
           /usr/lib/libhyprbars-os99.so /usr/lib64/libhyprbars-os99.so; do
    [[ -n $c && -f $c ]] || continue
    [[ -z $newest || $c -nt $newest ]] && newest="$c"
  done
  [[ -n $newest ]] || return 1
  printf '%s\n' "$newest"
}

# The .so Hyprland actually has mapped, if any. Read from the compositor rather
# than assumed, because the two can differ: installing a newer plugin does not
# swap the one already loaded, and nothing else would say so.
os99_loaded_so() {
  local pid
  pid=$(pgrep -x Hyprland 2>/dev/null | head -1)
  [[ -n $pid && -r /proc/$pid/maps ]] || return 1
  grep -o "/[^ ]*libhyprbars[^ ]*" "/proc/$pid/maps" 2>/dev/null | sort -u | head -1
}

# The INODE of the mapped library, from the same maps line. Field 5.
#
# Needed because a package replaces the file at a fixed path: the mapped path
# and the newest path are then the same string while the bytes behind them are
# not, and comparing paths says everything is fine. Hyprland keeps the old
# inode mapped until something unloads it, so the inode is the honest answer.
os99_loaded_so_inode() {
  local pid
  pid=$(pgrep -x Hyprland 2>/dev/null | head -1)
  [[ -n $pid && -r /proc/$pid/maps ]] || return 1
  awk '$6 ~ /libhyprbars/ { print $5; exit }' "/proc/$pid/maps" 2>/dev/null
}

# Is the running plugin something other than the newest one on disk?
# Prints the two paths when it is.
os99_so_stale() {
  local live newest live_ino disk_ino
  live=$(os99_loaded_so) || return 1
  newest=$(os99_newest_so) || return 1
  if [[ $live != "$newest" ]]; then
    [[ $newest -nt $live ]] || return 1
  else
    live_ino=$(os99_loaded_so_inode) || return 1
    disk_ino=$(stat -c %i "$newest" 2>/dev/null) || return 1
    [[ -n $live_ino && $live_ino != "$disk_ino" ]] || return 1
  fi
  printf '%s\n%s\n' "$live" "$newest"
}

# Every libhyprbars any running Hyprland has open, from /proc.
#
# Unload takes the path a plugin was loaded FROM, and that is not necessarily
# the path the pointer file names: rebuilding writes a new content-hashed .so
# and moves the pointer while the running Hyprland keeps the handle it dlopened
# at load time. Unloading by the pointer therefore quietly does nothing once
# the two diverge -- silently, because hyprctl's failure goes to /dev/null.
# That is how OS 9 title bars once survived a switch to another theme.
#
# The pid cannot be tied to a particular instance: Hyprland exports
# HYPRLAND_INSTANCE_SIGNATURE to its CHILDREN but does not carry it in its own
# environ, so there is nothing in /proc to match against. That is fine -- these
# are only candidates, and the unload itself goes through hyprctl, which
# already talks to the instance named by the signature. Unloading a path that
# instance does not have resident is a harmless no-op.
os99_hyprbars_paths() {
  local p
  for p in $(pgrep -x Hyprland 2>/dev/null); do
    grep -ho '/[^ ]*libhyprbars[^ ]*\.so' "/proc/$p/maps" 2>/dev/null
  done | sort -u
}

# --------------------------------------------------------------- the ABI pin
#
# THE IDENTIFIER THAT ACTUALLY DECIDES whether the plugin loads.
#
# Hyprland compares the plugin's compiled-in HYPRLAND_API_VERSION against its
# own, and that string is not the version anybody quotes:
#
#   efb5099...d9f_aq_0.15_hu_0.14_hg_0.5_hc_0.1_hlg_0.6
#
# -- the commit, plus aquamarine / hyprutils / hyprgraphics / hyprcursor /
# hyprlang. So a distro rebuild that bumps ONLY aquamarine breaks every plugin
# while `hyprctl version` still says v0.56.2 at commit efb5099.
#
# This mattered on 2026-09-09: the frames died, and every staleness check here
# compared tags, saw v0.56.2 == v0.56.2, and reported no drift. Comparing the
# ABI string turns "the frame plugin did not load" into a diagnosis and, better,
# makes the answer knowable WITHOUT attempting a load -- so the bar can say the
# frames are about to break rather than that they already have.
os99_hypr_abi() {
  local abi
  abi=$(hyprctl version 2>/dev/null | sed -n 's/^Version ABI string: *//p' | head -1)
  [[ -n $abi ]] || return 1
  printf '%s\n' "$abi"
}

# The ABI the installed .so was built for, from the .built stamp. Absent for a
# build made before this was recorded -- callers must treat "unknown" as "no
# opinion" and fall back to the tag rather than crying stale at everyone whose
# stamp predates the field.
os99_built_abi() {
  local abi
  abi=$(sed -n 's/^HYPRLAND_ABI=//p' "$HOME/.local/lib/libhyprbars-os99.built" 2>/dev/null | head -1)
  [[ -n $abi ]] || return 1
  printf '%s\n' "$abi"
}

# Will the built plugin refuse to load into the running Hyprland? Prints
# "built<TAB>running" when it will. Silent and non-zero when they match OR when
# either is unknown: an unanswerable question is not evidence of breakage.
os99_abi_stale() {
  local built running
  built=$(os99_built_abi)   || return 1
  running=$(os99_hypr_abi)  || return 1
  [[ $built != "$running" ]] || return 1
  printf '%s\t%s\n' "$built" "$running"
}

# The human-sized difference between two ABI strings: just the fields that
# moved, "aq 0.14 -> 0.15", because the full strings are 70 characters of
# mostly-identical hex and a notification has room for neither.
os99_abi_diff() {
  local built="$1" running="$2"
  BUILT="$built" RUNNING="$running" python3 -c '
import os, re
def fields(s):
    head, *rest = s.split("_", 1)
    out = {"commit": head[:7]}
    if rest:
        parts = rest[0].split("_")
        out.update(dict(zip(parts[::2], parts[1::2])))
    return out
a, b = fields(os.environ["BUILT"]), fields(os.environ["RUNNING"])
moved = [f"{k} {a.get(k, chr(63))} -> {b.get(k, chr(63))}"
         for k in dict.fromkeys([*a, *b]) if a.get(k) != b.get(k)]
print(", ".join(moved) if moved else "")
' 2>/dev/null
}

# ---------------------------------------------------- the break BEFORE it lands
#
# Everything above answers "are the frames broken". This answers "are they
# about to be", which is the question worth asking: an upgrade lands while the
# session is still running the OLD compositor, so the plugin keeps working
# until the next login and then does not. Told at the right moment that is a
# one-line chore; discovered at the next login it is a desktop that has lost
# every title bar for no visible reason.
#
# The running compositor reports its ABI. The INSTALLED HEADERS say what a
# rebuild would produce, and after an upgrade those two disagree -- so their
# disagreement is the upgrade, seen before the reboot that applies it.
os99_hypr_version_h() {
  local d
  for d in $(pkg-config --cflags-only-I hyprland 2>/dev/null); do
    d=${d#-I}
    [[ -f $d/version.h ]] && { printf '%s\n' "$d/version.h"; return 0; }
  done
  return 1
}

# Reassembled from version.h the way Hyprland assembles it: the commit, then
# aquamarine / hyprutils / hyprgraphics / hyprcursor / hyprlang as major.minor,
# in that order. Duplicating somebody else's format is a thing that rots, so
# nothing here is allowed to be load-bearing -- see the guard in
# os99_abi_pending, which refuses to speak if the shape has moved.
os99_headers_abi() {
  local h
  h=$(os99_hypr_version_h) || return 1
  VERSION_H="$h" python3 -c '
import os, re, sys
t = open(os.environ["VERSION_H"]).read()
def string(name):
    m = re.search(r"#define\s+%s\s+\"([^\"]*)\"" % name, t)
    return m.group(1) if m else None
def number(name):
    m = re.search(r"#define\s+%s\s+(\d+)" % name, t)
    return m.group(1) if m else None
def majmin(v):
    p = (v or "").split(".")
    return ".".join(p[:2]) if len(p) >= 2 else None
commit = string("GIT_COMMIT_HASH")
# aquamarine publishes split MAJOR/MINOR defines; the rest only a string.
aq = None
if number("AQUAMARINE_VERSION_MAJOR") and number("AQUAMARINE_VERSION_MINOR"):
    aq = "%s.%s" % (number("AQUAMARINE_VERSION_MAJOR"), number("AQUAMARINE_VERSION_MINOR"))
else:
    aq = majmin(string("AQUAMARINE_VERSION"))
fields = [("aq", aq),
          ("hu",  majmin(string("HYPRUTILS_VERSION"))),
          ("hg",  majmin(string("HYPRGRAPHICS_VERSION"))),
          ("hc",  majmin(string("HYPRCURSOR_VERSION"))),
          ("hlg", majmin(string("HYPRLANG_VERSION")))]
if not commit or any(v is None for _, v in fields):
    sys.exit(1)
print(commit + "".join("_%s_%s" % (k, v) for k, v in fields))
' 2>/dev/null
}

# The field NAMES of an ABI string, in order: "aq,hu,hg,hc,hlg".
_os99_abi_keys() {
  ABI="${1:-}" python3 -c '
import os
head, *rest = os.environ["ABI"].split("_", 1)
parts = rest[0].split("_") if rest else []
print(",".join(parts[::2]))
' 2>/dev/null
}

# Has Hyprland been upgraded under a session that is still running the old one?
# Prints "running<TAB>headers" when it has.
#
# Silent unless the two strings have the SAME SHAPE -- the same field names in
# the same order -- because the only reason they would not is that upstream
# changed the format and the reconstruction above is now wrong. A wrong
# reconstruction differs from the running ABI on every single boot, which would
# turn this into a warning that is always on and therefore never read. Refusing
# to guess is the whole safety margin here.
os99_abi_pending() {
  local hdr run
  hdr=$(os99_headers_abi) || return 1
  run=$(os99_hypr_abi)    || return 1
  [[ -n $hdr && -n $run && $hdr != "$run" ]] || return 1
  [[ $(_os99_abi_keys "$hdr") == "$(_os99_abi_keys "$run")" ]] || return 1
  printf '%s\t%s\n' "$run" "$hdr"
}

# ------------------------------------------------------ the plugin SOURCE dir
#
# Where to build FROM. This used to be one relative path -- ../plugin/hyprbars
# from the script -- which is right only for a checkout. The packaged copy in
# /usr/bin resolved it to /usr/plugin/hyprbars and the copy under
# ~/.config/omarchy/plugins/<id>/bin to a directory os99-install never creates,
# so `os99-hyprbars-rebuild` on $PATH was a command that could only fail. It
# failed loudly, which is why it went unnoticed: the one route people actually
# use is a dev checkout.
#
# So: ask several places, in the order that puts the most specific first.
# A directory is not enough. os99-install's non-checkout route creates bin/
# under the plugin directory without plugin/, and an empty directory would be
# "found" here and then fail at make with a far worse message than this one.
os99_is_plugin_src() {
  [[ -n ${1:-} && -f $1/Makefile && -f $1/main.cpp ]]
}

os99_plugin_src() {
  local here c
  # An explicit override is checked, not trusted. Pointing this at the wrong
  # directory should be a complaint about THAT directory -- falling through to
  # the search would quietly build from a source other than the one asked for,
  # which is the worse failure of the two.
  if [[ -n ${OS99_PLUGIN_SRC:-} ]]; then
    if os99_is_plugin_src "$OS99_PLUGIN_SRC"; then
      printf '%s\n' "$OS99_PLUGIN_SRC"
      return 0
    fi
    echo "os99: OS99_PLUGIN_SRC=$OS99_PLUGIN_SRC has no Makefile and main.cpp in it" >&2
    return 1
  fi
  here=$(cd -- "$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd) || here=""
  for c in ${here:+"$here/plugin/hyprbars"} \
           "$(cat "$(os99_state_dir)/plugin-src" 2>/dev/null)" \
           /usr/share/os99/plugin/hyprbars \
           /usr/local/share/os99/plugin/hyprbars \
           "$HOME/.config/omarchy/plugins/io.github.caariiboouu.os-99/plugin/hyprbars"; do
    os99_is_plugin_src "$c" || continue
    printf '%s\n' "$c"
    return 0
  done
  return 1
}

# ----------------------------------------------------------------------- art
#
# Copy freshly drawn art into the LIVE theme.
#
# `omarchy theme set` COPIES a theme into ~/.local/state/omarchy/current/theme;
# it does not symlink it. So regenerating art under ~/.config/omarchy/themes
# changes the SOURCE and not what is on screen, and everything looks like it
# worked. bars.lua rides along because it carries the BUTTON LIST and
# os99-window-bars evals the live copy -- without this, a box toggled in the
# config applies on the next theme switch rather than now.
#
# Returns non-zero when the live theme is not one of ours, which is not a
# failure: there is simply nothing of ours on screen to update.
os99_publish_art() {
  local live cur src
  live="$HOME/.local/state/omarchy/current/theme"
  cur=$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null || echo)
  [[ $cur == os-99-* ]] || return 1
  src="$HOME/.config/omarchy/themes/$cur"
  [[ -d $src/decor && -d $live/decor ]] || return 1
  cp -f "$src/decor/"*.png "$src/decor/bar.env" "$src/decor/bars.lua" \
        "$live/decor/" 2>/dev/null
}

# ------------------------------------------------------------------ sessions
#
# Setting OS 99 up is not one action. It copies a theme in, draws art at this
# display's scale, compiles a plugin into the compositor and switches the theme
# -- and somebody can log out in the middle of that. What makes this survivable
# is not a transaction log: it is that every one of those steps is idempotent,
# so recovery is simply running it again.
#
# What a record buys, then, is the one thing re-running cannot supply: the
# knowledge that something WAS interrupted, and what the theme was before it
# started. Written before the first change, removed only on success.
os99_session_begin() {
  local dir; dir=$(os99_state_dir)
  {
    echo "OP=$1"
    echo "PID=$$"
    echo "STARTED=$(date -Is)"
    echo "THEME_BEFORE=$(cat "$HOME/.local/state/omarchy/current/theme.name" 2>/dev/null || echo)"
  } > "$dir/session.tmp" && mv -f "$dir/session.tmp" "$dir/session"
}

os99_session_end() {
  rm -f "$(os99_state_dir)/session"
}

# Print the record if one was left behind, or nothing.
#
# A record whose process is still running is not an interruption, it is a run in
# progress -- checking that is what keeps `os99-install --status`, which the bar
# widget calls every minute, from announcing a crash every time somebody presses
# the setup button.
os99_session_interrupted() {
  local f pid
  f="$(os99_state_dir)/session"
  [[ -f $f ]] || return 1
  pid=$(sed -n 's/^PID=//p' "$f" | head -1)
  [[ -n $pid && -d /proc/$pid ]] && return 1
  cat "$f"
}

# --------------------------------------------------------------- publishing
#
# Replace a file's contents, or leave it exactly as it was. Used for every
# configuration file OS 99 writes.
#
# Follows a symlink once and then works on what it names: people keep these in
# dotfiles repositories, and renaming over the link would detach it. Writes to a
# private randomly named file beside the target (mkstemp: O_EXCL, mode 0600, a
# name nothing can predict and so nothing can pre-plant), forces it to disk, and
# renames it into place, which is atomic. A reader sees all of the old file or
# all of the new one. If anything fails, the temporary file goes and the
# original is untouched.
# The program lives in a variable rather than a heredoc, because a heredoc IS
# stdin -- `python3 - <<EOF` hands the interpreter its script on stdin and
# leaves nothing there for the data. That mistake writes an empty file, which is
# a very quiet way to lose somebody's bar layout.
read -r -d '' _os99_publish_py <<'PYEOF' || true
import os, stat, sys, tempfile

target = os.path.realpath(sys.argv[1])
data = sys.stdin.buffer.read()
if not data:
    sys.exit("os99_publish: refusing to write an empty file to %s" % target)

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
        try:
            os.unlink(tmp)
        except OSError:
            pass
dfd = os.open(dirname, os.O_RDONLY | getattr(os, "O_DIRECTORY", 0))
try:
    os.fsync(dfd)
finally:
    os.close(dfd)
PYEOF

os99_publish() {
  python3 -c "$_os99_publish_py" "$1"
}
