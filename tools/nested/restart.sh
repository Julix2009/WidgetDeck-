#!/usr/bin/env bash
# restart.sh [seconds]: restart the Quickshell of the nested session
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=env.sh
. "$HERE/env.sh"
for p in /proc/[0-9]*; do c="$(tr "\0" " " < "$p/cmdline" 2>/dev/null)"; case "$c" in "quickshell -p $Q"*) kill "${p#/proc/}" 2>/dev/null ;; esac; done 2>/dev/null
sleep 2
nexec "quickshell -p $Q"
sleep "${1:-9}"
