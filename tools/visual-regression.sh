#!/usr/bin/env bash
# visual-regression.sh: pixel comparison of the whole look before / after a change (safety net for performance work).
#
#   tools/visual-regression.sh baseline <refdir>   two complete capture passes (the second one more than a minute later), the reference pictures
#                                                  are the first pass; everything that differs between the passes (clock, countdowns, live values,
#                                                  particles ...) is the "moving part" mask - it is measured, not guessed
#   tools/visual-regression.sh check <refdir> [outdir]   one more pass, compared with the reference outside the mask; difference pictures
#                                                  and a list go to <outdir>; exit 1 when something differs
#   tools/visual-regression.sh capture <outdir>    just the pictures
#   tools/visual-regression.sh frames <refdir>|<outdir>  see "Animations" below
#
# Where the pictures come from: the nested test session of tools/nested (own Hyprland / D-Bus / HOME, nothing of your own desktop is touched, no
# workspace is switched): one virtual 2560x1600 monitor that is captured directly with grim, fixed wallpapers (dark, mid, very light), curl replaced by a stub
# that replays recorded answers, an invented Wi-Fi name, a mock music player, the widgets' own demo switches (invented data). Pictures stay OUTSIDE the repository.
#
# States: all widgets small and large x Frosted / Liquid x 3 wallpapers; weather icons (day / night, every kind); Formula 1 scenarios; music turntable;
#         bar, power panel, notification; builder (grid, selected widget, settings); the three Liquid Glass presets.
# Animations (frames): frame series of a size change, the turntable, a weather icon and the hover turn, taken as fast as grim allows; compared by their
#         progress curves (timing, shape, end state), not frame by frame.
set -uo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
export NB="${NB:-/tmp/widgetdeck-vr}"
# shellcheck source=perf/common.sh
. "$HERE/perf/common.sh"
CMD="${1:-}"; shift || true
FUZZ="${VR_FUZZ:-1%}"; MASK_GROW="${VR_MASK_GROW:-5}"

shot() {   # shot <outdir> <name>
    sleep "${SETTLE:-2.5}"
    WAYLAND_DISPLAY="$NDISP" timeout 30 grim -o "$MON" -t png "$1/$2.png" 2>/dev/null || { echo "  no picture: $2"; return 1; }
}
preset() {   # preset <id> <name>: applies a Liquid Glass preset (Pearl | Clear | Subtle) with the style IPC
    node -e "
const fs=require('fs');const s=fs.readFileSync('$HERE/../qml/core/Defaults.js','utf8').replace('.pragma library','');
const D=new Function(s+';return {P:LIQUID_PRESETS};')();const o=D.P['$2'];for(const k in o)console.log(k+' '+JSON.stringify(o[k]));" | while read -r k v; do q style "$1" "$k" "$v" >/dev/null; done
}
builder_open() { q openBuilder >/dev/null; for _ in $(seq 1 40); do nh clients -j 2>/dev/null | jq -e '.[] | select(.title=="WidgetDeck")' >/dev/null && break; sleep 0.25; done; sleep 2; }
builder_close() { q closeBuilder >/dev/null; for _ in $(seq 1 40); do nh clients -j 2>/dev/null | jq -e '.[] | select(.title=="WidgetDeck")' >/dev/null || break; sleep 0.25; done; }
wid() { awk -v t="$1" '$1==t {print $2; exit}' "$NB/layout.txt"; }

capture_pass() {   # capture_pass <outdir>
    local out="$1" size mode wp k id s n=0
    mkdir -p "$out"
    "$HERE/perf/up.sh" >/dev/null || { echo "session does not start"; return 1; }
    qs_pid >/dev/null || { nexec "quickshell -p $Q"; wait_ping 60; sleep 4; }
    q setGrid grid false >/dev/null 2>&1 || true
    # 1) all widgets, both sizes, both glass modes, three wallpapers
    for size in small large; do
        apply_layout "$size"; set_demo; sleep 2
        for mode in frosted liquid; do
            set_mode "$mode"
            for wp in dark mid light; do set_wallpaper "$wp"; shot "$out" "w-$size-$mode-$wp" && n=$((n + 1)); done
        done
    done
    # everything below: large layout, mid wallpaper, Liquid Glass unless said otherwise
    apply_layout large; set_demo; set_mode liquid; set_wallpaper mid; sleep 2
    # 2) weather card: every kind by day and night
    id="$(wid weathercard)"
    for k in clear mostly_clear partly cloudy fog drizzle rain heavy_rain thunder snow sleet hail unknown; do
        for s in day night; do q setProp "$id" debug_kind "\"$k\"" >/dev/null; q setProp "$id" debug_time "\"$s\"" >/dev/null; SETTLE=1.8 shot "$out" "wc-$k-$s" && n=$((n + 1)); done
    done
    q setProp "$id" debug_kind '"partly"' >/dev/null; q setProp "$id" debug_time '"day"' >/dev/null
    id="$(wid weather)"; for k in rain snow off; do q setProp "$id" debug_weather "\"$k\"" >/dev/null; SETTLE=2 shot "$out" "weather-$k" && n=$((n + 1)); done; q setProp "$id" debug_weather '"auto"' >/dev/null
    # 3) Formula 1 scenarios
    id="$(wid f1)"
    for s in sprint running finished seasonend cancelled noresult; do q setProp "$id" debug_scenario "\"$s\"" >/dev/null; SETTLE=2 shot "$out" "f1-$s" && n=$((n + 1)); done
    q setProp "$id" debug_scenario '"weekend"' >/dev/null
    # 4) music: turntable, large and small; timetable demo variants
    id="$(wid music)"; q setProp "$id" skin '"turntable"' >/dev/null
    for s in large small; do q animateSize "$id" "$s" >/dev/null; SETTLE=2 shot "$out" "music-turntable-$s" && n=$((n + 1)); done
    q setProp "$id" skin '"normal"' >/dev/null; q animateSize "$id" large >/dev/null
    id="$(wid timetable)"; q setProp "$id" source '"demo-holiday"' >/dev/null; SETTLE=2 shot "$out" "timetable-holiday" && n=$((n + 1)); q setProp "$id" source '"demo"' >/dev/null
    # 5) glass presets of one widget (Liquid) and frosted for comparison
    id="$(wid clock)"
    for k in Pearl Clear Subtle; do preset "$id" "$k"; SETTLE=2 shot "$out" "preset-$k" && n=$((n + 1)); done; preset "$id" Pearl
    # 6) chrome: power panel, notification card
    q powerPanel >/dev/null; shot "$out" "bar-power-panel" && n=$((n + 1)); q powerPanel >/dev/null; sleep 1
    nexec "notify-send -a WidgetDeck 'Test notification' 'Invented text for the picture'"; SETTLE=1.5 shot "$out" "notification" && n=$((n + 1))
    q dismissNotifications >/dev/null 2>&1; sleep 1
    # 7) builder: plain, grid, a selected widget, settings
    builder_open; SETTLE=1.5 shot "$out" "builder" && n=$((n + 1))
    q setGrid grid true >/dev/null 2>&1; SETTLE=1.5 shot "$out" "builder-grid" && n=$((n + 1))
    q select "$(wid weathercard)" >/dev/null; SETTLE=1.5 shot "$out" "builder-selected" && n=$((n + 1))
    q settingsPanel true >/dev/null 2>&1; SETTLE=1.5 shot "$out" "builder-settings" && n=$((n + 1))
    q settingsPanel false >/dev/null 2>&1; builder_close; q setGrid grid false >/dev/null 2>&1
    echo "  $n pictures in $out"
}

make_masks() {   # make_masks <refdir>: the moving parts = everything that differs between pass A and pass B
    local f n; mkdir -p "$1/mask"
    for f in "$1"/A/*.png; do
        n="$(basename "$f")"; [ -f "$1/B/$n" ] || continue
        magick "$f" "$1/B/$n" -compose difference -composite -colorspace Gray -fuzz "$FUZZ" -threshold 2% -morphology Dilate "Disk:$MASK_GROW" "$1/mask/$n"
    done
}

compare_pass() {   # compare_pass <refdir> <newdir> <diffdir>: lists the states that differ outside the mask
    local ref="$1" new="$2" dd="$3" f n px bad=0 tot=0
    mkdir -p "$dd"
    for f in "$ref"/A/*.png; do
        n="$(basename "$f")"; tot=$((tot + 1))
        if [ ! -f "$new/$n" ]; then printf '  MISSING  %s\n' "${n%.png}"; bad=$((bad + 1)); continue; fi
        # difference, minus the moving parts
        magick "$f" "$new/$n" -compose difference -composite -colorspace Gray -fuzz "$FUZZ" -threshold 2% "$dd/_raw.png"
        magick "$dd/_raw.png" "$ref/mask/$n" -compose Minus -composite "$dd/$n"
        px="$(magick "$dd/$n" -format '%[fx:round(mean*w*h)]' info:)"
        if [ "${px:-0}" -gt "${VR_MAX_PIXELS:-0}" ]; then printf '  DIFF     %-28s %s pixels\n' "${n%.png}" "$px"; bad=$((bad + 1)); else rm -f "$dd/$n"; fi
    done
    rm -f "$dd/_raw.png"
    printf '%s of %s states identical (outside the measured moving parts)\n' "$((tot - bad))" "$tot"
    [ "$bad" = 0 ]
}

case "$CMD" in
    capture) [ -n "${1:-}" ] || { sed -n 2,12p "$0"; exit 1; }; capture_pass "$1" ;;
    baseline)
        REF="${1:?reference directory (outside the repository)}"; mkdir -p "$REF"
        echo "pass A"; capture_pass "$REF/A"
        t0=$SECONDS; echo "pass B (the clock must have moved on)"
        while [ $((SECONDS - t0)) -lt 62 ]; do sleep 1; done
        capture_pass "$REF/B"; make_masks "$REF"; echo "reference in $REF (masks: $REF/mask)" ;;
    check)
        REF="${1:?reference directory}"; NEW="${2:-$NB/check-$(date +%H%M%S)}"
        capture_pass "$NEW" || exit 2
        compare_pass "$REF" "$NEW" "$NEW/diff"; rc=$?
        echo "pictures and differences: $NEW"; exit $rc ;;
    *) sed -n 2,22p "$0"; exit 1 ;;
esac
