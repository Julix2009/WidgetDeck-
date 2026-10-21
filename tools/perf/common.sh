# shellcheck shell=bash
# source me. Shared by tools/perf/*.sh and tools/visual-regression.sh: the nested test session (own Hyprland, own D-Bus, own HOME), a fixed
# virtual monitor, fixed wallpapers, a stub for curl (offline, replays recorded answers) and a layout builder.
# Nothing here touches your own session: no workspace switch (the virtual monitor is captured directly), no packages, no host files.
PERF_HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
export NB="${NB:-/tmp/widgetdeck-perf}"
# shellcheck source=../nested/env.sh
. "$PERF_HERE/../nested/env.sh"
MON="${PERF_MON:-HEAD-1}"; export MON_MODE; MON_MODE="${PERF_MON_MODE:-2560x1600@60}"
NDISP="${NDISP:-wayland-2}"; export NDISP
WP="$NB/wp"; OUT="${OUT:-$NB/out}"

nested_alive() { pgrep -f "Hyprland -c $N/.config/hypr/hyprland.conf" >/dev/null 2>&1; }
qs_pid() { for p in /proc/[0-9]*; do c="$(tr '\0' ' ' < "$p/cmdline" 2>/dev/null)"; case "$c" in "quickshell -p $Q"*) echo "${p#/proc/}"; return 0 ;; esac; done 2>/dev/null; return 1; }
wait_ping() { for _ in $(seq 1 "${1:-60}"); do [ "$(q ping 2>/dev/null)" = pong ] && return 0; sleep 0.5; done; return 1; }

make_wallpapers() {
    mkdir -p "$WP"
    [ -f "$WP/dark.png" ] || magick -size 2560x1600 gradient:'#0b1020-#2a3a66' "$WP/dark.png"
    [ -f "$WP/mid.png" ] || magick -seed 42 -size 2560x1600 plasma:fractal -modulate 100,60,100 "$WP/mid.png"
    [ -f "$WP/light.png" ] || magick -seed 7 -size 2560x1600 gradient:'#fdfdf8-#e6ecf2' -attenuate 0.3 +noise Gaussian "$WP/light.png"
}
set_wallpaper() { WAYLAND_DISPLAY="${NDISP:-wayland-2}" awww img -o "$MON" "$WP/$1.png" --transition-type none >/dev/null 2>&1 || WAYLAND_DISPLAY="${NDISP:-wayland-2}" awww img "$WP/$1.png" --transition-type none >/dev/null 2>&1; q reloadWallpaper >/dev/null 2>&1; }

# a curl that never reaches the network: it logs the host, and answers with a recorded fixture when there is one (else it fails like "offline")
install_stubs() {
    mkdir -p "$N/.local/bin" "$NB/fixtures"
    cat > "$N/.local/bin/curl" <<'STUB'
#!/bin/sh
# test stub for curl (tools/perf): no network. Logs "time host", replays $NB/fixtures/<host>.json when it exists.
url=""; for a in "$@"; do case "$a" in http*) url="$a" ;; esac; done
host=$(printf '%s' "$url" | sed 's#^[a-z]*://##; s#[/?].*##')
printf '%s %s\n' "$(date +%s)" "$host" >> "${NB:-/tmp/widgetdeck-perf}/net.log"
f="${NB:-/tmp/widgetdeck-perf}/fixtures/$host.json"
if [ -f "${NB:-/tmp/widgetdeck-perf}/record" ]; then /usr/bin/curl "$@" | tee "$f"; exit "$?"; fi       # recording once (up.sh): the real answer, kept
[ -f "$f" ] && { cat "$f"; exit 0; }
exit 6
STUB
    chmod +x "$N/.local/bin/curl"
    # nmcli would tell the widgets the REAL Wi-Fi name of this machine: an invented one instead (nothing personal in test pictures)
    cat > "$N/.local/bin/nmcli" <<'STUB'
#!/bin/sh
case "$*" in *"IN-USE,SIGNAL,SSID"*) printf '*:72:TestNet-5G\n' ;; *) exit 0 ;; esac
STUB
    chmod +x "$N/.local/bin/nmcli"
}

# the layout: every widget type once, packed in rows into the usable area (small|large sizes from the registry)
apply_layout() {   # apply_layout <small|large>
    local size="$1" id t x y w h
    for id in $(q list | tr -d '[]"' | tr ',' '\n' | awk '{print $1}'); do [ -n "$id" ] && q removeWidget "$id" >/dev/null; done
    node "$PERF_HERE/layout.js" "$size" "${PERF_W:-2560}" "${PERF_H:-1600}" | while read -r t x y w h; do
        id="$(q addWidget "$t")"; [ -n "$id" ] || continue
        q geom "$id" "$x" "$y" "$w" "$h" >/dev/null
        echo "$t $id $x $y $w $h"
    done > "$NB/layout.txt"
}
set_mode() {   # set_mode frosted|liquid  (every widget)
    local id
    for id in $(awk '{print $2}' "$NB/layout.txt"); do q style "$id" mode "\"$1\"" >/dev/null; done
}
# fixed test data: the widgets that have a demo / test switch use it; the rest shows what the machine delivers (masked in the comparison)
set_demo() {
    local t id
    while read -r t id _; do
        case "$t" in
            weathercard) q setProp "$id" debug_kind '"partly"' >/dev/null; q setProp "$id" debug_time '"day"' >/dev/null ;;
            f1)          q setProp "$id" debug_scenario '"weekend"' >/dev/null; q setProp "$id" debug_circuit '"monza"' >/dev/null ;;
            timetable)   q setProp "$id" source '"demo"' >/dev/null ;;
        esac
    done < "$NB/layout.txt"
}
