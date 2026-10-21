#!/usr/bin/env bash
# up.sh: bring the nested test session into the defined measuring state (idempotent):
#   one virtual monitor (HEAD-1, 2560x1600), fixed wallpapers, curl stub with recorded answers, bar + notifications on, mock music player.
#   tools/perf/up.sh [--monitors 2]      --monitors 2 adds a second virtual output (HEAD-2, 2560x1440) to the right
set -euo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=common.sh
. "$HERE/common.sh"
MONS=1; [ "${1:-}" = "--monitors" ] && MONS="${2:-1}"
mkdir -p "$NB"
if ! nested_alive; then
    "$HERE/../nested/start.sh" > "$NB/start.log" 2>&1
    nested_find || { echo "the nested session did not come up"; exit 1; }
fi
make_wallpapers; install_stubs
# the monitors: HEAD-1 is the one at the origin, the nested window's own output is switched off (it is only a window of your session)
nh monitors | grep -q "^Monitor $MON " || nh output create headless "$MON" >/dev/null
nh keyword monitor "$MON,$MON_MODE,0x0,1" >/dev/null
nh keyword monitor "WAYLAND-1,disable" >/dev/null 2>&1 || true
if [ "$MONS" -ge 2 ]; then
    nh monitors | grep -q "^Monitor HEAD-2 " || nh output create headless HEAD-2 >/dev/null
    nh keyword monitor "HEAD-2,2560x1440@60,2560x0,1" >/dev/null
else
    nh monitors | grep -q "^Monitor HEAD-2 " && nh output remove HEAD-2 >/dev/null || true
fi
wait_ping 60 || { echo "the shell does not answer"; exit 1; }
# the wallpaper daemon inside the nested session
[ -S "/run/user/${UID:-1000}/$NDISP-awww-daemon.sock" ] || nexec "awww-daemon"
sleep 2; set_wallpaper mid
# one real answer per data host, recorded once (a made-up location, no personal data), then replayed forever
if [ ! -f "$NB/fixtures/api.open-meteo.com.json" ] || [ ! -f "$NB/fixtures/air-quality-api.open-meteo.com.json" ]; then
    touch "$NB/record"
    for s in weather.sh aq.sh; do HOME="$N" PATH="$N/.local/bin:$PATH" bash "$HERE/../../qml/widgets/sysmon/$s" --json >/dev/null 2>&1 || true; done
    rm -f "$NB/record" "$N/.cache/widgetdeck/weather.json" "$N/.cache/widgetdeck/aq.json"
fi
q setModule bar on >/dev/null; q setModule notifications on >/dev/null
# the mock music player (own D-Bus of the nested session)
pgrep -f "mock-mpris.py $NB/mock" >/dev/null || nexec "python3 $HERE/../mock-mpris.py $NB/mock"
sleep 2; echo "up: $(nh monitors | grep -c '^Monitor') monitor(s), shell pid $(qs_pid)"
