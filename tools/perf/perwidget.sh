#!/usr/bin/env bash
# perwidget.sh <label> [--mode liquid|frosted] [--seconds 40]: what every widget costs ALONE (bar and notifications only for "none"): idle CPU,
# wakeups, GPU time, GPU memory, PSS, process starts. Results: $NB/baseline/<label>/perwidget-<type>.json and a table.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=common.sh
. "$HERE/common.sh"
LABEL="${1:?label}"; shift || true
MODE=liquid; SECS=40
while [ $# -gt 0 ]; do case "$1" in --mode) MODE="$2"; shift ;; --seconds) SECS="$2"; shift ;; esac; shift; done
D="$NB/baseline/$LABEL"; mkdir -p "$D"
"$HERE/up.sh" >/dev/null
stop_shell() { local p; p="$(qs_pid || true)"; [ -n "$p" ] && kill "$p" 2>/dev/null; for _ in $(seq 1 30); do qs_pid >/dev/null || break; sleep 0.2; done; pkill -f "[c]ava -p /tmp/widgetdeck-cava" 2>/dev/null || true; }
qs_pid >/dev/null || { nexec "quickshell -p $Q"; wait_ping 60; sleep 3; }
apply_layout large; set_mode "$MODE"; set_demo
cp "$NB/layout.txt" "$NB/layout.all"
for t in none $(awk '{print $1}' "$NB/layout.all"); do
    qs_pid >/dev/null || { nexec "quickshell -p $Q"; wait_ping 60; sleep 3; }
    while read -r wt id _; do [ "$wt" = "$t" ] || q removeWidget "$id" >/dev/null; done < "$NB/layout.all"
    sleep 1; stop_shell; sleep 1
    nexec "quickshell -p $Q"; wait_ping 60; sleep 15
    python3 "$HERE/sample.py" --match "quickshell -p $Q" --seconds "$SECS" --label "$t" --json "$D/perwidget-$t.json" >/dev/null
    stop_shell
    # restore the full layout for the next round (the shell must run for the IPC)
    nexec "quickshell -p $Q"; wait_ping 60; sleep 3; apply_layout large; set_mode "$MODE"; set_demo; cp "$NB/layout.txt" "$NB/layout.all"
done
python3 - "$D" <<'PY'
import json, os, sys
d = sys.argv[1]; rows = []
for f in sorted(os.listdir(d)):
    if f.startswith("perwidget-"):
        j = json.load(open(os.path.join(d, f))); rows.append((f[10:-5], j))
base = next((j for n, j in rows if n == "none"), None)
print("| Widget (alone, with bar) | CPU %% | wakeups/s | GPU render %% | GPU mem MiB | PSS MiB | starts/min |\n|---|---|---|---|---|---|---|")
for n, j in sorted(rows, key=lambda r: r[0] != "none"):
    print("| %s | %.2f | %.0f | %.2f | %.0f | %.0f | %.0f |" % (n, j["cpu_pct"], j["wakeups_per_s"], j["gpu_render_pct"], j["gpu_mem_kib"] / 1024, j["pss_kib"] / 1024, j["spawned_per_min"]))
PY
