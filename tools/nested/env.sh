# shellcheck shell=bash
# source me. NB = base dir of the nested sessions, N = the session home (default $NB/n1)
NB=${NB:-/tmp/widgetdeck-nested}; N=${N:-$NB/n1}
export REPO; REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
Q=$N/.config/quickshell/widgetdeck
SIG=$(ls -t /run/user/${UID:-1000}/hypr 2>/dev/null | head -1)
nh() { HYPRLAND_INSTANCE_SIGNATURE=$SIG hyprctl "$@"; }
q() { HOME=$N XDG_RUNTIME_DIR=/run/user/${UID:-1000} WAYLAND_DISPLAY=${NDISP:-wayland-2} timeout 15 quickshell -p "$Q" ipc call widgetdeck "$@"; }
qlog() { HOME=$N XDG_RUNTIME_DIR=/run/user/${UID:-1000} WAYLAND_DISPLAY=${NDISP:-wayland-2} quickshell -p "$Q" log 2>&1 | sed 's/\x1b\[[0-9;]*m//g'; }
nexec() { nh dispatch exec "$1" >/dev/null; }
