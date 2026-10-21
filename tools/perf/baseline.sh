#!/usr/bin/env bash
# baseline.sh <label> [--quick] [--monitors 2] [--modes "frosted liquid"] : the measuring run (results in $NB/baseline/<label>/ as JSON, summary on stdout)
#   per glass mode: cold start (time until every widget has its window), memory right after the start and after 10 minutes, idle CPU /
#   wakeups / GPU / process starts over 60 s, hover, size animations, music track changes, network requests per hour (curl stub log), cache and log sizes.
#   --quick shortens every window (a smoke test of the script, not a measurement).
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=common.sh
. "$HERE/common.sh"
LABEL="${1:?label}"; shift || true
QUICK=0; MONS=1; MODES="frosted liquid"
while [ $# -gt 0 ]; do case "$1" in --quick) QUICK=1 ;; --monitors) MONS="$2"; shift ;; --modes) MODES="$2"; shift ;; esac; shift; done
W=60; SETTLE=20; LONG=600; [ "$QUICK" = 1 ] && { W=8; SETTLE=5; LONG=20; }
D="$NB/baseline/$LABEL"; mkdir -p "$D"
"$HERE/up.sh" --monitors "$MONS" >/dev/null

stop_shell() { local p; p="$(qs_pid || true)"; [ -n "$p" ] && kill "$p" 2>/dev/null; for _ in $(seq 1 30); do qs_pid >/dev/null || break; sleep 0.2; done; pkill -f "cava -p /tmp/widgetdeck-cava" 2>/dev/null || true; }
layer_count() { nh layers -j 2>/dev/null | jq '[.. | objects | select(.namespace? != null and (.namespace | test("^widgetdeck(-liquid)?$")))] | length'; }
start_shell() {   # start_shell <env...> : prints the seconds until all widgets have a window
    local want="$1" t0 t n; shift
    t0=$(date +%s.%N); nexec "env $* quickshell -p $Q"
    for _ in $(seq 1 400); do n="$(layer_count)"; [ "${n:-0}" -ge "$want" ] && break; sleep 0.1; done
    t=$(date +%s.%N); echo "$t - $t0" | bc -l | cut -c1-5
}
sample() { python3 "$HERE/sample.py" --match "quickshell -p $Q" --seconds "$1" --label "$2" --json "$D/$MODE-$2.json" | head -9; }
hover() {   # the pointer visits every widget (pointer moves of the nested compositor = hover events)
    local end=$((SECONDS + $1)) t id x y w h
    while [ $SECONDS -lt $end ]; do
        while read -r t id x y w h; do nh dispatch movecursor "$((x + w / 2))" "$((y + h / 2 + 62))" >/dev/null; sleep 0.4; [ $SECONDS -ge $end ] && break; done < "$NB/layout.txt"
    done
}
animate() {  # Small <-> Large of every widget that has a size table
    local end=$((SECONDS + $1)) t id
    while [ $SECONDS -lt $end ]; do
        for w in small large; do while read -r t id _; do q animateSize "$id" "$w" >/dev/null 2>&1; done < "$NB/layout.txt"; sleep 1.2; done
    done
}
music() { local end=$((SECONDS + $1)); while [ $SECONDS -lt $end ]; do nexec "playerctl -p widgetdeck_mock next"; sleep 3; done; }

for MODE in $MODES; do
    echo "=== $MODE, $MONS monitor(s) ==="
    qs_pid >/dev/null || { nexec "quickshell -p $Q"; wait_ping 60; sleep 3; }
    apply_layout large; set_mode "$MODE"; set_demo
    if [ "$MONS" -ge 2 ]; then while read -r t id _; do [ "$t" = clock ] || [ "$t" = f1 ] && q setMonitor "$id" all >/dev/null; done < "$NB/layout.txt"; fi
    sleep 1; stop_shell
    for _ in $(seq 1 50); do [ "$(layer_count)" = 0 ] && break; sleep 0.2; done
    : > "$NB/net.log"
    want=$(wc -l < "$NB/layout.txt"); [ "$MODE" = frosted ] && want=$((want + 1))
    [ "$MONS" -ge 2 ] && want=$((want + 2 * 2))
    T=$(start_shell "$want"); echo "start: ${T} s until $want windows"; echo "{\"start_s\": $T}" > "$D/$MODE-start.json"
    sleep "$SETTLE"
    sample 1 "$MODE-first" >/dev/null 2>&1 || true
    echo "-- first minute (idle)"; sample "$W" idle0
    echo "-- hover"; hover "$W" & sample "$W" hover; wait
    echo "-- size animations"; animate "$W" & sample "$W" anim; wait
    echo "-- music (track change every 3 s)"; music "$W" & sample "$W" music; wait
    echo "-- waiting for minute 10"; sleep "$LONG"
    echo "-- idle after 10 minutes"; sample "$W" idle10
    n=$(wc -l < "$NB/net.log"); echo "network: $n requests since the start; $(awk '{print $2}' "$NB/net.log" | sort | uniq -c | tr '\n' ';')"
    elapsed=$(( W * 4 + SETTLE + LONG + W + 10 ))
    echo "{\"requests\": $n, \"seconds\": $elapsed, \"per_hour\": $(echo "$n * 3600 / $elapsed" | bc -l | cut -c1-6)}" > "$D/$MODE-net.json"
    du -sk "$N/.cache/widgetdeck" 2>/dev/null | awk '{print "cache dir: " $1 " KiB"}'
    echo "{\"cache_kib\": $(du -sk "$N/.cache/widgetdeck" | cut -f1), \"log_lines\": $(qlog | wc -l), \"log_bytes\": $(qlog | wc -c)}" > "$D/$MODE-files.json"
done
echo "results in $D"
