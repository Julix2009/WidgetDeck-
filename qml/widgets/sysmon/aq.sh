#!/usr/bin/env bash
# One-shot JSON: air quality from Open-Meteo (free, no key).   usage: aq.sh [lat lon]
# Location: the arguments (widget props), else location.sh (config.json / automatic). Cached for 30 minutes;
# offline -> the last value, marked "stale".
# shellcheck source=common.sh
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"
HERE="$(dirname "${BASH_SOURCE[0]}")"
CACHE="$WD_CACHE/aq.json"; MAXAGE=1800
now=$(date +%s)

emit() {   # emit <stale 0|1>
    jq -c --argjson stale "$1" --argjson age "$(( now - $(jq -r '.fetched // 0' "$CACHE") ))" '. + {stale:($stale==1), age:$age}' "$CACHE"
}

if [ -n "${1:-}" ] && [ -n "${2:-}" ]; then place='{"lat":'"$1"',"lon":'"$2"',"name":"","source":"manual"}'
else place=$("$HERE/location.sh"); fi
lat=$(jq -r '.lat // empty' <<<"$place"); lon=$(jq -r '.lon // empty' <<<"$place"); name=$(jq -r '.name // ""' <<<"$place")
if [ -z "$lat" ] || [ -z "$lon" ]; then echo '{"error":"no-location"}'; exit 0; fi

key="$lat,$lon"
fresh=0
if [ -s "$CACHE" ] && [ "$(jq -r '.key // ""' "$CACHE")" = "$key" ] && [ $(( now - $(jq -r '.fetched // 0' "$CACHE") )) -lt "$MAXAGE" ]; then fresh=1; fi
if [ "$fresh" = 0 ]; then
    r=$(curl -sf --max-time 10 "https://air-quality-api.open-meteo.com/v1/air-quality?latitude=${lat}&longitude=${lon}&current=european_aqi,pm10,pm2_5,ozone&timezone=auto") || r=""
    if jq -e '.current.european_aqi != null' >/dev/null 2>&1 <<<"$r"; then
        jq -c --argjson f "$now" --arg place "$name" --arg key "$key" \
            '{key:$key, aqi:.current.european_aqi, pm25:.current.pm2_5, pm10:.current.pm10, o3:.current.ozone, time:.current.time, place:$place, fetched:$f}' <<<"$r" > "$CACHE.tmp" && mv "$CACHE.tmp" "$CACHE"
        emit 0; exit 0
    fi
    if [ -s "$CACHE" ] && [ "$(jq -r '.key // ""' "$CACHE")" = "$key" ]; then emit 1; else echo '{"error":"offline"}'; fi
    exit 0
fi
emit 0
