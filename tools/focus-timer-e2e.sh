#!/usr/bin/env bash
# focus-timer-e2e.sh: the focus timer in a running nested session (tools/nested, own Hyprland / D-Bus / HOME: nothing of your desktop is touched), with the
# debug switch (phases of 10 / 4 / 6 seconds). Needs: tools/perf/up.sh state, jq, node. Usage: NB=/tmp/widgetdeck-vr tools/focus-timer-e2e.sh [scenario ...]
#   scenarios: set skipreset restart missed hidden damaged shared sound dnd dndfile   (default: all)
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
export NB="${NB:-/tmp/widgetdeck-vr}"
# shellcheck source=perf/common.sh
. "$HERE/perf/common.sh"
nested_need || exit 2
FT="$HERE/../bin/focus-timer"
ft() { WAYLAND_DISPLAY="$NDISP" HOME="$N" XDG_RUNTIME_DIR="/run/user/${UID:-1000}" WIDGETDECK_QML="$Q" LC_ALL=C "$FT" "$@"; }
st() { ft status --json | jq -r "$1"; }
fails=0; ok() { if [ "$2" = 1 ]; then echo "ok   $1"; else echo "FAIL $1   ($3)"; fails=$((fails + 1)); fi; }
chimes() { local n; n="$(grep -c "pw-play" "$NB/audio.log" 2>/dev/null)"; echo "${n:-0}"; }
CONF="$N/.config/widgetdeck"
restart_shell() { local p; p="$(qs_pid || true)"; [ -n "$p" ] && kill "$p"; for _ in $(seq 1 30); do qs_pid >/dev/null || break; sleep 0.2; done; nexec "quickshell -p $Q"; wait_ping 60; sleep 3; }
stop_shell() { local p; p="$(qs_pid || true)"; [ -n "$p" ] && kill "$p"; for _ in $(seq 1 30); do qs_pid >/dev/null || break; sleep 0.2; done; }
prep() {   # prep: a layout with ONE focus timer, fast phases, defaults otherwise
    qs_pid >/dev/null || { nexec "quickshell -p $Q"; wait_ping 60; sleep 3; }
    for id in $(q list | tr -d '[]"' | tr ',' '\n' | awk '{print $1}'); do [ -n "$id" ] && q removeWidget "$id" >/dev/null; done
    ID="$(q addWidget focustimer)"; q geom "$ID" 40 40 300 380 >/dev/null; q style "$ID" mode '"liquid"' >/dev/null
    q setProp "$ID" debug_fast true >/dev/null; q setProp "$ID" cycles 2 >/dev/null; q setProp "$ID" auto_next false >/dev/null
    q setProp "$ID" focus_mode false >/dev/null; q setProp "$ID" sound true >/dev/null; q setProp "$ID" notify true >/dev/null
    ft reset >/dev/null; sleep 1; BASE="$(st '.today.sessions')"
}
sess() { echo $(( $(st '.today.sessions') - BASE )); }
file_sessions() { jq -r '[.days[]?.sessions] | add // 0' "$CONF/focus-stats.json" 2>/dev/null || echo 0; }
want() { local n=0; while [ "$n" -lt "${3:-40}" ]; do [ "$(st "$1")" = "$2" ] && return 0; sleep 0.25; n=$((n + 1)); done; return 1; }
: > "$NB/audio.log"
SCEN="${*:-set skipreset restart missed hidden damaged shared sound dnd dndfile}"
has() { case " $SCEN " in *" $1 "*) return 0 ;; esac; return 1; }

if has set; then
    echo "== a whole set with auto-next: focus, short, focus, long, focus"
    prep; q setProp "$ID" auto_next true >/dev/null; sleep 1; ft start >/dev/null
    seq=""; last=""; t0=$SECONDS
    while [ $((SECONDS - t0)) -lt 36 ]; do p="$(st '.phase')"; [ "$p" != "$last" ] && { seq="$seq $p"; last="$p"; }; [ "$(echo "$seq" | wc -w)" -ge 5 ] && break; sleep 0.3; done
    ok "phases in order" "$([ "$(echo $seq)" = "focus short focus long focus" ] && echo 1 || echo 0)" "$seq"
    ok "two focus sessions counted" "$([ "$(sess)" = 2 ] && echo 1 || echo 0)" "$(st '.today')"
    ok "after the long break a new set (cycle 0), running (auto-next)" "$([ "$(st '.cycle')" = 0 ] && echo 1 || echo 0)" "$(st '.')"
    ft pause >/dev/null
fi
if has skipreset; then
    echo "== skip and reset"
    prep; ft start >/dev/null; sleep 2; ft skip >/dev/null
    ok "skip: the break runs, the focus phase did not count" "$([ "$(st '.phase')" = short ] && [ "$(sess)" = 0 ] && [ "$(st '.running')" = true ] && echo 1 || echo 0)" "$(st '.')"
    ft pause >/dev/null; ft reset >/dev/null; sleep 0.5
    ok "reset: paused focus phase, full time" "$([ "$(st '.phase')" = focus ] && [ "$(st '.remaining')" = "00:10" ] && [ "$(st '.running')" = false ] && echo 1 || echo 0)" "$(st '.')"
    ft toggle >/dev/null; sleep 0.5; a="$(st '.running')"; ft toggle >/dev/null; sleep 0.5; b="$(st '.running')"
    ok "toggle starts and pauses" "$([ "$a" = true ] && [ "$b" = false ] && echo 1 || echo 0)" "$a $b"
    ft reset >/dev/null
fi
if has restart; then
    echo "== restart of the shell in the middle of a phase"
    prep; ft start >/dev/null; sleep 3; c0="$(chimes)"; restart_shell
    ok "the timer goes on after the restart (running, about 6 s left)" "$([ "$(st '.running')" = true ] && [ "$(st '.remaining_ms')" -lt 8000 ] && [ "$(st '.remaining_ms')" -gt 2000 ] && echo 1 || echo 0)" "$(st '.')"
    want '.phase' short 40; sleep 1
    ok "its end after the restart: exactly one chime, one session" "$([ "$(( $(chimes) - c0 ))" = 1 ] && [ "$(sess)" = 1 ] && echo 1 || echo 0)" "chimes +$(( $(chimes) - c0 )) $(st '.today')"
fi
if has missed; then
    echo "== the phase ended while the shell was not running (standby, crash)"
    prep; ft start >/dev/null; sleep 1; stop_shell; c0="$(chimes)"; s0="$(file_sessions)"; sleep 13; nexec "quickshell -p $Q"; wait_ping 60; sleep 3
    ok "counted once, next phase waits paused" "$([ "$(st '.phase')" = short ] && [ "$(st '.running')" = false ] && [ "$(( $(st '.today.sessions') - s0 ))" = 1 ] && echo 1 || echo 0)" "$(st '.') s0=$s0"
    ok "no sound for a missed end" "$([ "$(chimes)" = "$c0" ] && echo 1 || echo 0)" "chimes +$(( $(chimes) - c0 ))"
fi
if has hidden; then
    echo "== hidden widget, monitor removed: the timer does not care"
    prep; ft start >/dev/null; sleep 1; q setHidden "$ID" true >/dev/null; sleep 1
    nh output create headless HEAD-2 >/dev/null 2>&1; nh keyword monitor "HEAD-2,1920x1080@60,2560x0,1" >/dev/null; sleep 1; nh output remove HEAD-2 >/dev/null 2>&1; sleep 1
    ok "still running, the same phase" "$([ "$(st '.running')" = true ] && echo 1 || echo 0)" "$(st '.')"
    want '.phase' short 60; ok "and it ended on time although nobody could see it" "$([ "$(sess)" = 1 ] && echo 1 || echo 0)" "$(st '.today')"
    q setHidden "$ID" false >/dev/null
fi
if has damaged; then
    echo "== damaged files"
    prep; ft start >/dev/null; want '.phase' short 60; stop_shell
    printf '{"v":1,"days":{"2026-10-22":{"sessions":"x"' > "$CONF/focus-stats.json"; printf 'not json at all' > "$CONF/focus-state.json"
    nexec "quickshell -p $Q"; wait_ping 60; sleep 3
    ok "the shell starts anyway, with a fresh timer" "$([ "$(st '.phase')" = focus ] && [ "$(st '.running')" = false ] && echo 1 || echo 0)" "$(st '.')"
    ok "the damaged statistics were kept as a copy" "$([ "$(ls "$CONF"/focus-stats.json.damaged-* 2>/dev/null | wc -l)" -ge 1 ] && echo 1 || echo 0)" "$(ls "$CONF" | tr '\n' ' ')"
    ft start >/dev/null; want '.phase' short 60; sleep 1
    ok "a new statistics file is written and valid" "$(jq -e '.v == 1 and (.days | length) == 1' "$CONF/focus-stats.json" >/dev/null 2>&1 && echo 1 || echo 0)" "$(cat "$CONF/focus-stats.json")"
    rm -f "$CONF"/focus-stats.json.damaged-*
fi
if has shared; then
    echo "== several instances: one timer, one set of settings"
    prep; ID2="$(q addWidget focustimer)"; q setMonitor "$ID2" all >/dev/null
    q setProp "$ID" focus_min 30 >/dev/null; sleep 1
    v="$(jq -r --arg a "$ID" --arg b "$ID2" '[.widgets[] | select(.id == $a or .id == $b) | .props.focus_min] | @csv' "$CONF/widgets.json")"
    ok "a setting changed on one instance is the same on the other" "$([ "$v" = "30,30" ] && echo 1 || echo 0)" "$v"
    ID3="$(q addWidget focustimer)"; sleep 1; v3="$(jq -r --arg a "$ID3" '.widgets[] | select(.id == $a) | .props.focus_min' "$CONF/widgets.json")"
    ok "a new instance takes the settings over" "$([ "$v3" = 30 ] && echo 1 || echo 0)" "$v3"
    q removeWidget "$ID2" >/dev/null; q removeWidget "$ID3" >/dev/null; q setProp "$ID" focus_min 25 >/dev/null
fi
if has sound; then
    echo "== sound and notification at the end, switched off separately"
    prep; q setProp "$ID" sound false >/dev/null; q setProp "$ID" notify true >/dev/null; sleep 1; c0="$(chimes)"; ft start >/dev/null; want '.phase' short 60; sleep 1
    ok "sound off: no chime" "$([ "$(chimes)" = "$c0" ] && echo 1 || echo 0)" "+$(( $(chimes) - c0 ))"
    q setProp "$ID" sound true >/dev/null; q setProp "$ID" volume 30 >/dev/null; sleep 1; ft skip >/dev/null; ft start >/dev/null; want '.phase' short 60; sleep 1
    ok "sound on, volume 30: the chime plays with volume 0.30" "$(tail -1 "$NB/audio.log" | grep -q -- '--volume=0.30' && echo 1 || echo 0)" "$(tail -1 "$NB/audio.log")"
    q setProp "$ID" volume 70 >/dev/null
fi
if has dnd; then
    echo "== focus mode: notifications are silent during focus and the old state comes back"
    prep; q setProp "$ID" focus_mode true >/dev/null; sleep 1
    ok "backend: WidgetDeck's own notification module" "$([ "$(st '.dnd.backend')" = widgetdeck ] && echo 1 || echo 0)" "$(st '.dnd')"
    ft start >/dev/null; sleep 2
    ok "during focus: 'do not disturb' is on (ours)" "$([ "$(st '.dnd.active')" = true ] && echo 1 || echo 0)" "$(st '.dnd')"
    ft pause >/dev/null; sleep 1
    ok "pause: back to normal" "$([ "$(st '.dnd.active')" = false ] && echo 1 || echo 0)" "$(st '.dnd')"
    ft start >/dev/null; want '.phase' short 60; sleep 2
    ok "end of the focus phase: back to normal" "$([ "$(st '.dnd.active')" = false ] && echo 1 || echo 0)" "$(st '.dnd')"
fi
if has dndfile; then
    echo "== focus mode with a notification shell that follows a flag file (the backend of dotfile shells): $N/.cache/quickshell/dnd/state"
    FLAG="$N/.cache/quickshell/dnd/state"; mkdir -p "$(dirname "$FLAG")"; rm -f "$FLAG"
    q setModule notifications off >/dev/null; sleep 1
    printf '#!/bin/sh\necho "$(date +%%s.%%N) $*" >> "%s/notify.log"\n' "$NB" > "$N/.local/bin/notify-send"; chmod +x "$N/.local/bin/notify-send"; : > "$NB/notify.log"
    prep; q setProp "$ID" focus_mode true >/dev/null; restart_shell
    flag() { cat "$FLAG" 2>/dev/null | tr -d '\n'; }
    ok "backend: the flag file" "$([ "$(st '.dnd.backend')" = flagfile ] && echo 1 || echo 0)" "$(st '.dnd')"
    ft start >/dev/null; sleep 2
    ok "focus running: the flag is 1 (ours)" "$([ "$(flag)" = 1 ] && [ "$(st '.dnd.active')" = true ] && echo 1 || echo 0)" "flag=$(flag) $(st '.dnd')"
    ft pause >/dev/null; sleep 2
    ok "pause: the flag is 0 again" "$([ "$(flag)" = 0 ] && echo 1 || echo 0)" "flag=$(flag)"
    # the user's own silence is never lifted
    printf '1\n' > "$FLAG"; ft reset >/dev/null; ft start >/dev/null; sleep 2
    ok "the user had 'do not disturb' on: untouched, and not ours" "$([ "$(flag)" = 1 ] && [ "$(st '.dnd.active')" = false ] && echo 1 || echo 0)" "flag=$(flag) $(st '.dnd')"
    want '.phase' short 60; sleep 2
    ok "after the focus phase the user's silence is still there" "$([ "$(flag)" = 1 ] && echo 1 || echo 0)" "flag=$(flag)"
    # the user lifts it during our focus: we do not put it back
    printf '0\n' > "$FLAG"; ft reset >/dev/null; ft start >/dev/null; sleep 2; printf '0\n' > "$FLAG"; want '.phase' short 60; sleep 3
    ok "lifted by the user during focus: stays lifted" "$([ "$(flag)" = 0 ] && echo 1 || echo 0)" "flag=$(flag)"
    # the end of the phase notice comes AFTER the silence is lifted (the shell polls the file once a second)
    : > "$NB/notify.log"; printf '0\n' > "$FLAG"; ft reset >/dev/null; ft start >/dev/null; sleep 1; t_on="$(flag)"; want '.phase' short 60; sleep 3
    ok "end notice sent, flag already 0 when it was sent" "$([ "$t_on" = 1 ] && [ "$(flag)" = 0 ] && [ "$(wc -l < "$NB/notify.log")" -ge 1 ] && echo 1 || echo 0)" "on=$t_on off=$(flag) notices=$(wc -l < "$NB/notify.log")"
    # crash in the middle of a focus phase: after the restart the phase goes on and the silence is still ours; when the shell comes back too late it is lifted
    ft reset >/dev/null; ft start >/dev/null; sleep 2
    p="$(qs_pid)"; kill -9 "$p"; sleep 1; nexec "quickshell -p $Q"; wait_ping 60; sleep 3
    ok "crash and restart in the middle of focus: still running, flag 1, still ours" "$([ "$(st '.running')" = true ] && [ "$(flag)" = 1 ] && [ "$(st '.dnd.active')" = true ] && echo 1 || echo 0)" "flag=$(flag) $(st '.dnd')"
    p="$(qs_pid)"; kill -9 "$p"; sleep 12; nexec "quickshell -p $Q"; wait_ping 60; sleep 4
    ok "crash, the phase ended meanwhile: the silence is lifted after the restart" "$([ "$(flag)" = 0 ] && [ "$(st '.dnd.active')" = false ] && echo 1 || echo 0)" "flag=$(flag) $(st '.dnd')"
    rm -f "$N/.local/bin/notify-send"
    q setModule notifications on >/dev/null
fi
echo; [ "$fails" = 0 ] && echo "focus timer e2e: all ok" || echo "focus timer e2e: $fails failed"
exit "$fails"
