#!/usr/bin/env bash
# frames.sh record <outdir> | compare <refdir> <newdir>: frame series of animations (size change, music track change, turntable, hover turn of the
# weather icon, hover over a widget), taken with grim as fast as it goes (about 15-25 frames/s on a small crop) with a time stamp per frame, and compared by
# their PROGRESS CURVES (when it starts, how fast it moves, where it ends), not frame by frame: timing, curve and end state must stay the same.
# Uses the nested session of tools/visual-regression.sh (same NB, same fixed data). Pictures stay outside the repository.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
export NB="${NB:-/tmp/widgetdeck-vr}"
# shellcheck source=common.sh
. "$HERE/common.sh"
CMD="${1:-}"; shift || true

rect() { awk -v t="$1" '$1==t {print $3, $4, $5, $6; exit}' "$NB/layout.txt"; }
wid() { awk -v t="$1" '$1==t {print $2; exit}' "$NB/layout.txt"; }
barh() { q areaInfo 2>/dev/null | jq -r '.area[1]' 2>/dev/null || echo 0; }

series() {   # series <outdir> <name> <crop "x,y WxH"> <seconds> <action-delay> <action command...>
    local out="$1" name="$2" crop="$3" secs="$4" delay="$5" i=0 t0 now
    shift 5; mkdir -p "$out/$name"; : > "$out/$name/times"
    t0=$(date +%s.%N)
    ( sleep "$delay"; "$@" >/dev/null 2>&1 ) &
    while :; do
        now=$(date +%s.%N)
        [ "$(echo "$now - $t0 > $secs" | bc -l)" = 1 ] && break
        WAYLAND_DISPLAY="$NDISP" grim -g "$crop" -t ppm "$out/$name/$(printf %03d $i).ppm" 2>/dev/null
        echo "$(echo "$now - $t0" | bc -l | cut -c1-6)" >> "$out/$name/times"; i=$((i + 1))
    done
    wait
}

record() {
    local out="$1" id x y w h by
    mkdir -p "$out"
    "$HERE/up.sh" >/dev/null; qs_pid >/dev/null || { nexec "quickshell -p $Q"; wait_ping 60; sleep 4; }
    apply_layout large; set_demo; set_mode liquid; set_wallpaper mid; sleep 3
    by=$(barh)
    # size changes (the widgets that have a size table): the exact size timeline of the widget's window, polled from the compositor
    for t in timetable weathercard f1; do
        id=$(wid "$t"); read -r x y w h <<<"$(rect "$t")"
        for dir in small large; do
            [ "$dir" = small ] && n=down || n=up
            ( sleep 0.3; q animateSize "$id" "$dir" >/dev/null ) &
            python3 "$HERE/layersample.py" "$SIG" 1.8 "$((x - 56))" "$((y + by - 80))" "$out/size-$t-$n.json"; wait; sleep 0.6
        done
    done
    # music: the next track (cover crossfade)
    read -r x y w h <<<"$(rect music)"; y=$((y + by))
    series "$out" "music-next" "$x,$y $((w + 40))x$((h + 40))" 2.6 0.4 nexec "playerctl -p widgetdeck_mock next"; sleep 1
    id=$(wid music); q setProp "$id" skin '"turntable"' >/dev/null; sleep 2
    series "$out" "turntable" "$x,$y $((w + 160))x$((h + 160))" 1.6 0 true
    q setProp "$id" skin '"normal"' >/dev/null
    # hover: the pointer enters the weather card (icon turn) and a clock (glass)
    read -r x y w h <<<"$(rect weathercard)"; y=$((y + by))
    series "$out" "hover-weathercard" "$x,$y $((w + 40))x$((h + 40))" 2.4 0.4 nh dispatch movecursor "$((x + 110))" "$((y + 90))"; sleep 1
    nh dispatch movecursor 5 800 >/dev/null
    echo "series in $out"
}

compare() { python3 "$HERE/frames.py" "$1" "$2"; }

case "$CMD" in
    record) record "${1:?outdir}" ;;
    compare) compare "${1:?refdir}" "${2:?newdir}" ;;
    *) sed -n 2,8p "$0"; exit 1 ;;
esac
