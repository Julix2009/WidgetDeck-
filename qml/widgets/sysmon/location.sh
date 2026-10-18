#!/usr/bin/env bash
# Prints the location the widgets use, as one JSON line: {"lat":..,"lon":..,"name":"..","source":"manual|auto|none"}
#   1. config.json  location.lat / location.lon (set in the builder: Settings -> Location)      -> "manual"
#   2. location.auto (default true): a one-off lookup by IP address (ipwho.is), cached 7 days     -> "auto"
#   3. otherwise "none" - the widgets then show a hint instead of a wrong place.
# Privacy: step 2 sends your IP address to ipwho.is. Set  "location": {"auto": false}  in config.json to switch it off.
# shellcheck source=common.sh
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"

lat=$(cfg '.location.lat' ""); lon=$(cfg '.location.lon' "")
if [[ "$lat" =~ ^-?[0-9]+(\.[0-9]+)?$ && "$lon" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
    jq -nc --argjson la "$lat" --argjson lo "$lon" --arg n "$(cfg '.location.name' "")" '{lat:$la, lon:$lo, name:$n, source:"manual"}'
    exit 0
fi
if [ "$(cfg '.location.auto' true)" = "true" ]; then
    cache="$WD_CACHE/location.json"
    if [ "$(file_age "$cache")" -gt 604800 ]; then
        r=$(curl -sf --max-time 6 "https://ipwho.is/?fields=success,latitude,longitude,city" 2>/dev/null) || r=""
        if [ -n "$r" ] && [ "$(jq -r '.success' <<<"$r" 2>/dev/null)" = "true" ]; then
            jq -c '{lat:.latitude, lon:.longitude, name:(.city // ""), source:"auto"}' <<<"$r" > "$cache.tmp" && mv "$cache.tmp" "$cache"
        fi
    fi
    if [ -s "$cache" ]; then cat "$cache"; exit 0; fi
fi
echo '{"lat":null,"lon":null,"name":"","source":"none"}'
