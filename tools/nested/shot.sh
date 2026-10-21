#!/usr/bin/env bash
# shot.sh <out.png> [grim args]: screenshot of the NESTED session; workspace 9 is shown for a moment, then back
O="$1"; shift
ws0="$(hyprctl activeworkspace -j | jq .id)"; hyprctl dispatch workspace 9 >/dev/null; sleep "${SHOTWAIT:-2}"
WAYLAND_DISPLAY=${NDISP:-wayland-2} timeout 25 grim "$@" -t png "$O"
hyprctl dispatch workspace "$ws0" >/dev/null
