#!/usr/bin/env bash
# gpu-idle.sh [seconds]: how busy the GPU (Intel: share of time NOT in RC6 sleep, whole system) and the nested Quickshell (CPU) are over a period.
# Compare with the widgets on and off (ipc call widgetdeck setModule widgets off|on). Needs /sys/class/drm/card*/gt/gt0/rc6_residency_ms.
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=env.sh
. "$HERE/env.sh"
S=${1:-30}
rc6=""; for f in /sys/class/drm/card*/gt/gt0/rc6_residency_ms; do [ -r "$f" ] && rc6="$f" && break; done
[ -n "$rc6" ] || { echo "no rc6_residency_ms (not an Intel GPU?) - only CPU is measured"; }
pid=""; for p in /proc/[0-9]*; do c="$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null)"; case "$c" in *"quickshell -p $Q"*) pid="${p#/proc/}";; esac; done 2>/dev/null
cpu() { awk '{print $14+$15}' "/proc/$pid/stat"; }
a=0; [ -n "$rc6" ] && a=$(cat "$rc6"); c0=$(cpu); t0=$(date +%s.%N)
sleep "$S"
b=0; [ -n "$rc6" ] && b=$(cat "$rc6"); c1=$(cpu); t1=$(date +%s.%N)
awk -v a="$a" -v b="$b" -v c0="$c0" -v c1="$c1" -v t0="$t0" -v t1="$t1" -v hz="$(getconf CLK_TCK)" -v have="$([ -n "$rc6" ] && echo 1 || echo 0)" 'BEGIN{dt=t1-t0; if(have) printf "GPU busy (system-wide): %.2f %%\n", 100-(b-a)/(dt*10); printf "nested quickshell CPU: %.2f %%\n", (c1-c0)/hz/dt*100}'
