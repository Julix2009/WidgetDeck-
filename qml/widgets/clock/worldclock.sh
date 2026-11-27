#!/usr/bin/env bash
# UTC offsets of time zones from the system's tzdata, for the world clock of the clock widget.
#   worldclock.sh ZONE [ZONE ...]        e.g. worldclock.sh Asia/Tokyo America/New_York
# Prints per zone and point in time one line "ZONE<TAB>unix time<TAB>+hhmm", or "ZONE<TAB>bad" for an unknown zone.
# Points in time: now and the next four quarter-hour boundaries, so the widget (which asks every 15 minutes) is also
# right just after a daylight saving change. WORLDCLOCK_NOW (unix time) replaces "now" for the tests.
set -u
ZI="${TZDIR:-/usr/share/zoneinfo}"
now="${WORLDCLOCK_NOW:-$(date +%s)}"
case "$now" in ''|*[!0-9]*) exit 1 ;; esac
q=$(( (now / 900 + 1) * 900 ))
times=("$now" "$q" $((q + 900)) $((q + 1800)) $((q + 2700)))
for z in "$@"; do
    # only real zone files: with an unknown zone, date silently uses UTC
    case "$z" in ''|/*|-*|*..*|*[!A-Za-z0-9/_+-]*) printf '%s\tbad\n' "$z"; continue ;; esac
    if [ ! -f "$ZI/$z" ] || [ "$(head -c 4 "$ZI/$z" 2>/dev/null)" != "TZif" ]; then printf '%s\tbad\n' "$z"; continue; fi
    mapfile -t offs < <(printf '@%s\n' "${times[@]}" | TZ=":$z" date -f - +%z 2>/dev/null)
    # no GNU date (no -f): say so instead of leaving the zone pending forever
    if [ -z "${offs[0]:-}" ]; then printf '%s\tbad\n' "$z"; continue; fi
    for i in "${!times[@]}"; do
        [ -n "${offs[$i]:-}" ] && printf '%s\t%s\t%s\n' "$z" "${times[$i]}" "${offs[$i]}"
    done
done
exit 0
