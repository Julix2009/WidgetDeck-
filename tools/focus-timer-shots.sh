#!/usr/bin/env bash
# focus-timer-shots.sh <outdir>: pictures of the focus timer next to the weather card (same glass material), small and large, Frosted and Liquid Glass,
# on the dark / mid / very light test wallpaper, in the states focus (running), short break (paused), long break (running), and on a 1080p and a 4K output.
# Uses the nested session (tools/nested, virtual outputs: nothing of your desktop is touched). Pictures stay outside the repository.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
export NB="${NB:-/tmp/widgetdeck-vr}"
# shellcheck source=perf/common.sh
. "$HERE/perf/common.sh"
nested_need || exit 2
OUTD="${1:?output directory}"; mkdir -p "$OUTD"
CONF="$N/.config/widgetdeck"
now_ms() { date +%s%3N; }
restart_shell() { local p; p="$(qs_pid || true)"; [ -n "$p" ] && kill "$p"; for _ in $(seq 1 30); do qs_pid >/dev/null || break; sleep 0.2; done; nexec "quickshell -p $Q"; wait_ping 60; sleep 5; }
state() {   # state <phase> <running 0|1> <remaining_ms> <cycle>: writes the saved state of the timer and restarts the shell
    local ph="$1" run="$2" rem="$3" cyc="$4" ends=0; [ "$run" = 1 ] && ends=$(( $(now_ms) + rem + 8000 ))
    printf '{"v":1,"phase":"%s","cycle":%s,"running":%s,"endsAt":%s,"remainingMs":%s,"settings":{},"dnd":{"owned":false,"backend":""}}\n' "$ph" "$cyc" "$([ "$run" = 1 ] && echo true || echo false)" "$ends" "$rem" > "$CONF/focus-state.json"
    restart_shell
}
shot() { sleep 2; WAYLAND_DISPLAY="$NDISP" grim -g "$2" -t png "$OUTD/$1.png"; }
qs_pid >/dev/null || { nexec "quickshell -p $Q"; wait_ping 60; sleep 4; }
for id in $(q list | tr -d '[]"' | tr ',' '\\n' | awk '{print $1}'); do [ -n "$id" ] && q removeWidget "$id" >/dev/null; done
# a row per glass mode: weather card, big and small focus timer
: > "$NB/layout.txt"
for mode in frosted liquid; do
    y=40; [ "$mode" = liquid ] && y=470
    wc="$(q addWidget weathercard)"; q geom "$wc" 40 "$y" 520 340 >/dev/null; q style "$wc" mode "\"$mode\"" >/dev/null; q setProp "$wc" debug_kind '"partly"' >/dev/null; q setProp "$wc" debug_time '"day"' >/dev/null
    big="$(q addWidget focustimer)"; q geom "$big" 600 "$y" 300 380 >/dev/null; q style "$big" mode "\"$mode\"" >/dev/null
    small="$(q addWidget focustimer)"; q geom "$small" 940 "$y" 200 200 >/dev/null; q style "$small" mode "\"$mode\"" >/dev/null
    echo "weathercard $wc 40 $y 520 340" >> "$NB/layout.txt"; echo "focustimer $big 600 $y 300 380" >> "$NB/layout.txt"; echo "focustimer $small 940 $y 200 200" >> "$NB/layout.txt"
done
sleep 2
for wp in dark mid light; do
    set_wallpaper "$wp"; state focus 1 900000 1
    shot "focus-$wp" "0,0 1200x900"
done
set_wallpaper mid
state short 0 240000 2; shot "short-paused" "0,0 1200x900"
state long 1 420000 4; shot "long-running" "0,0 1200x900"
state focus 0 1500000 0; shot "focus-fresh" "0,0 1200x900"
echo "pictures in $OUTD"
