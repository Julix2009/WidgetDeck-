#!/usr/bin/env bash
# qsgtiming.sh [mode] [seconds]: frame statistics of the scene graph (QSG_RENDER_TIMING=1): frames per second and mean frame time at idle, with hover
# and during size animations. An idle shell should render (almost) nothing; every frame that is drawn without a visible change is wasted work.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=common.sh
. "$HERE/common.sh"
MODE="${1:-liquid}"; SECS="${2:-20}"
"$HERE/up.sh" >/dev/null
qs_pid >/dev/null || { nexec "quickshell -p $Q"; wait_ping 60; sleep 3; }
apply_layout large; set_mode "$MODE"; set_demo; sleep 1
p="$(qs_pid || true)"; [ -n "$p" ] && kill "$p"; sleep 2
LOG="$NB/qsg.log"; : > "$LOG"
nexec "sh -c 'QSG_RENDER_TIMING=1 QT_LOGGING_RULES=qt.scenegraph.time.renderloop=true exec quickshell -p $Q > $LOG 2>&1'"
wait_ping 60; sleep 12
frames() { grep -c -E "Frame rendered|renderloop" "$LOG"; }
phase() {   # phase <name> <command-in-background...>
    local name="$1" a b; shift
    a=$(frames); "$@" & local pid=$!; sleep "$SECS"; kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null; b=$(frames)
    awk -v n="$name" -v a="$a" -v b="$b" -v s="$SECS" 'BEGIN{printf "%-10s %6.1f frames/s\n", n, (b-a)/s}'
}
hover() { while :; do while read -r _ _ x y w h; do nh dispatch movecursor "$((x + w / 2))" "$((y + h / 2 + 46))" >/dev/null; sleep 0.4; done < "$NB/layout.txt"; done; }
animate() { while :; do for w in small large; do while read -r _ id _; do q animateSize "$id" "$w" >/dev/null 2>&1; done < "$NB/layout.txt"; sleep 1.2; done; done; }
phase idle sleep "$SECS"; phase hover hover; phase animation animate
sed -n 's/.*total[ =:]*\([0-9.]*\) *ms.*/\1/p' "$LOG" | awk '{s+=$1; n++} END{ if (n) printf "mean frame time (all frames): %.2f ms over %d frames\n", s/n, n }'
grep -m2 -E "Frame rendered|renderloop" "$LOG" | cut -c1-200
