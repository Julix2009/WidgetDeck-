#!/usr/bin/env bash
# focus-timer-dnd-test.sh: qml/widgets/focustimer/dnd.sh against stand-ins of dunst, mako and swaync (stub commands that keep their state in a file) and a
# flag file: detection, get, set, and what the focus timer relies on (get after set gives the same). Nothing real is touched. Usage: tools/focus-timer-dnd-test.sh
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
DND="$HERE/../qml/widgets/focustimer/dnd.sh"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/bin" "$T/hm"
fails=0; ok() { if [ "$2" = 1 ]; then echo "ok   $1"; else echo "FAIL $1   ($3)"; fails=$((fails + 1)); fi; }
run() { env -i HOME="$T/hm" PATH="$T/bin:/usr/bin:/bin" STATE="$T/state" ${FAKE_OWNER+FAKE_OWNER="$FAKE_OWNER"} ${QS_CACHE_DND:+QS_CACHE_DND="$QS_CACHE_DND"} "$DND" "$@"; }

# fake busctl: the owner of the notification name is a process whose comm is $FAKE_OWNER
cat > "$T/bin/busctl" <<'S'
#!/bin/sh
[ -n "$FAKE_OWNER" ] || exit 1
mkdir -p "$STATE.proc"; printf '%s\n' "$FAKE_OWNER" > "$STATE.proc/comm"
echo "PID=$$"
S
# detect() reads the owner's /proc comm: the test replaces owner() in a COPY of the script by one that answers with $FAKE_OWNER
cp "$DND" "$T/dnd.sh"; sed -i 's#^owner() {#owner() { if [ -n "${FAKE_OWNER+x}" ]; then printf "%s" "$FAKE_OWNER"; return; fi#' "$T/dnd.sh"; chmod +x "$T/dnd.sh"; DND="$T/dnd.sh"

cat > "$T/bin/dunstctl" <<'S'
#!/bin/sh
case "$1" in is-paused) cat "$STATE.dunst" 2>/dev/null || echo false ;; set-paused) echo "$2" > "$STATE.dunst" ;; esac
S
cat > "$T/bin/makoctl" <<'S'
#!/bin/sh
f="$STATE.mako"; touch "$f"
case "$1" in
    mode) case "${2:-}" in -a) grep -qx "$3" "$f" || echo "$3" >> "$f" ;; -r) grep -vx "$3" "$f" > "$f.n"; mv "$f.n" "$f" ;; *) echo default; cat "$f" ;; esac ;;
esac
S
cat > "$T/bin/swaync-client" <<'S'
#!/bin/sh
case "$1" in -D) cat "$STATE.swaync" 2>/dev/null || echo false ;; -dn) echo true > "$STATE.swaync" ;; -df) echo false > "$STATE.swaync" ;; esac
S
chmod +x "$T/bin/"*

for pair in "dunst:dunst" "mako:mako" "swaync:swaync"; do
    owner="${pair%%:*}"; b="${pair##*:}"
    export FAKE_OWNER="$owner"
    ok "detect $owner" "$([ "$(run detect)" = "$b" ] && echo 1 || echo 0)" "$(run detect)"
    ok "$b: off at the start" "$([ "$(run get "$b")" = off ] && echo 1 || echo 0)" "$(run get "$b")"
    run set "$b" on; ok "$b: on after set on" "$([ "$(run get "$b")" = on ] && echo 1 || echo 0)" "$(run get "$b")"
    run set "$b" off; ok "$b: off after set off" "$([ "$(run get "$b")" = off ] && echo 1 || echo 0)" "$(run get "$b")"
done
ok "dunstctl was asked with set-paused true / false" "$(grep -q false "$T/state.dunst" && echo 1 || echo 0)" "$(cat "$T/state.dunst" 2>/dev/null)"
ok "mako: the mode do-not-disturb is added and removed again" "$([ "$(grep -c . "$T/state.mako")" = 0 ] && echo 1 || echo 0)" "$(cat "$T/state.mako")"

# a notification shell with a flag file (no dunst / mako / swaync owner)
export FAKE_OWNER="quickshell"
ok "no flag directory: none" "$([ "$(run detect)" = none ] && echo 1 || echo 0)" "$(run detect)"
mkdir -p "$T/hm/.cache/quickshell/dnd"
ok "flag directory: flagfile" "$([ "$(run detect)" = flagfile ] && echo 1 || echo 0)" "$(run detect)"
ok "flagfile: no file = off" "$([ "$(run get flagfile)" = off ] && echo 1 || echo 0)" "$(run get flagfile)"
run set flagfile on; ok "flagfile: on writes 1" "$([ "$(cat "$T/hm/.cache/quickshell/dnd/state")" = 1 ] && [ "$(run get flagfile)" = on ] && echo 1 || echo 0)" "$(cat "$T/hm/.cache/quickshell/dnd/state")"
run set flagfile off; ok "flagfile: off writes 0" "$([ "$(cat "$T/hm/.cache/quickshell/dnd/state")" = 0 ] && [ "$(run get flagfile)" = off ] && echo 1 || echo 0)" "$(cat "$T/hm/.cache/quickshell/dnd/state")"
QS_CACHE_DND="$T/other" run set flagfile on 2>/dev/null; ok "flagfile: QS_CACHE_DND moves the directory" "$([ -f "$T/other/state" ] && echo 1 || echo 0)" "$(ls "$T" | tr '\n' ' ')"
ok "unknown backend: unknown / error, nothing happens" "$([ "$(run get nothing)" = unknown ] && ! run set nothing on 2>/dev/null && echo 1 || echo 0)" "-"
ok "set needs on or off" "$(! run set flagfile maybe 2>/dev/null && echo 1 || echo 0)" "-"
echo; [ "$fails" = 0 ] && echo "dnd test: all ok" || echo "dnd test: $fails failed"; exit "$fails"
