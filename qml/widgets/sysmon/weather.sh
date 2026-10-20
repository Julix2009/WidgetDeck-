#!/usr/bin/env bash
# One-shot JSON for the weather widget (Open-Meteo, free, no API key). Cached for 10 minutes; offline -> the last values, "stale":true.
# usage: weather.sh [lat lon]      without arguments the location comes from location.sh
# Output: {"current_temp":"18.1","current_icon":"<glyph>","unit":"°C","wind_unit":"m/s","place":"..","forecast":[{"desc","max","min","feels_like","wind","humidity","icon"}],
#          "stale":false,"fetched":<epoch>}   or   {"error":"no-location"|"offline"}
# Added for the weather card (the weather widget ignores them): "current_code" (WMO), "is_day", "pop" (rain probability %, this hour),
#          "hourly":[{"t":"HH:MM","temp","code","day","pop"}] (from the current hour, 9 entries), "daily":[{"date","max","min","code","pop"}] (7 days).
# Both widgets call this script, so they share ONE request per 10 minutes (the cache file below).
# shellcheck source=common.sh
. "$(dirname "${BASH_SOURCE[0]}")/common.sh"
HERE="$(dirname "${BASH_SOURCE[0]}")"

if [ -n "${1:-}" ] && [ -n "${2:-}" ]; then place='{"lat":'"$1"',"lon":'"$2"',"name":"","source":"manual"}'
else place=$("$HERE/location.sh"); fi
lat=$(jq -r '.lat // empty' <<<"$place"); lon=$(jq -r '.lon // empty' <<<"$place"); name=$(jq -r '.name // ""' <<<"$place")
if [ -z "$lat" ] || [ -z "$lon" ]; then echo '{"error":"no-location"}'; exit 0; fi

units=$(sys_units); lang=$(sys_lang)
key="$lat,$lon,$units,$lang,i3"
cache="$WD_CACHE/weather.json"
if [ -s "$cache" ] && [ "$(file_age "$cache")" -lt 600 ] && [ "$(jq -r '.key' "$cache" 2>/dev/null)" = "$key" ]; then jq -c 'del(.key)' "$cache"; exit 0; fi

# several widgets may call this at the same moment (weather widget + weather cards): the first one fetches, the others wait for the lock and then
# read its cache - one request, not one per widget
if command -v flock >/dev/null 2>&1; then
    exec 9>"$WD_CACHE/weather.lock"
    flock -w 20 9 || true
    if [ -s "$cache" ] && [ "$(file_age "$cache")" -lt 600 ] && [ "$(jq -r '.key' "$cache" 2>/dev/null)" = "$key" ]; then jq -c 'del(.key)' "$cache"; exit 0; fi
fi
if [ "$units" = imperial ]; then tu=fahrenheit; wu=mph; tsym="°F"; wsym="mph"; else tu=celsius; wu=ms; tsym="°C"; wsym="m/s"; fi
raw=$(curl -sf --max-time 10 "https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m,is_day&hourly=temperature_2m,weather_code,is_day,precipitation_probability&daily=temperature_2m_max,temperature_2m_min,weather_code,precipitation_probability_max&forecast_days=7&timezone=auto&temperature_unit=${tu}&wind_speed_unit=${wu}" 2>/dev/null) || raw=""
if ! jq -e '.current.temperature_2m != null' >/dev/null 2>&1 <<<"$raw"; then
    if [ -s "$cache" ]; then jq -c 'del(.key) | .stale = true' "$cache"; else echo '{"error":"offline"}'; fi
    exit 0
fi
# WMO weather code -> icon name (drawn by core/Icon.qml) + description
out=$(jq -c --arg key "$key" --arg tsym "$tsym" --arg wsym "$wsym" --arg lang "$lang" --arg name "$name" --arg now "$(date +%s)" '
  def glyph($c; $day):
    if $c == 0 then (if $day == 1 then "sun" else "moon" end)
    elif $c <= 3 then "cloud"
    elif $c == 45 or $c == 48 then "mist"
    elif ($c >= 51 and $c <= 67) or ($c >= 80 and $c <= 82) then "rain"
    elif ($c >= 71 and $c <= 77) or $c == 85 or $c == 86 then "snow"
    elif $c >= 95 then "storm"
    else "cloud" end;
  def desc($c):
    (if $lang == "de" then
       {"0":"Klar","1":"Überwiegend klar","2":"Teils bewölkt","3":"Bewölkt","45":"Nebel","48":"Reifnebel","51":"Leichter Nieselregen","53":"Nieselregen","55":"Starker Nieselregen","56":"Gefrierender Nieselregen","57":"Gefrierender Nieselregen","61":"Leichter Regen","63":"Regen","65":"Starker Regen","66":"Gefrierender Regen","67":"Gefrierender Regen","71":"Leichter Schneefall","73":"Schneefall","75":"Starker Schneefall","77":"Schneegriesel","80":"Leichte Regenschauer","81":"Regenschauer","82":"Starke Regenschauer","85":"Leichte Schneeschauer","86":"Schneeschauer","95":"Gewitter","96":"Gewitter mit Hagel","99":"Gewitter mit Hagel"}
     else
       {"0":"Clear","1":"Mostly clear","2":"Partly cloudy","3":"Overcast","45":"Fog","48":"Rime fog","51":"Light drizzle","53":"Drizzle","55":"Heavy drizzle","56":"Freezing drizzle","57":"Freezing drizzle","61":"Light rain","63":"Rain","65":"Heavy rain","66":"Freezing rain","67":"Freezing rain","71":"Light snow","73":"Snow","75":"Heavy snow","77":"Snow grains","80":"Light showers","81":"Showers","82":"Heavy showers","85":"Light snow showers","86":"Snow showers","95":"Thunderstorm","96":"Thunderstorm with hail","99":"Thunderstorm with hail"}
     end)[($c|tostring)] // "";
  (.current.time[0:13]) as $h
  | [range(0; (.hourly.time | length)) as $i | select(.hourly.time[$i][0:13] >= $h)
     | {t: .hourly.time[$i][11:16], temp: (.hourly.temperature_2m[$i] | round), code: .hourly.weather_code[$i], day: .hourly.is_day[$i], pop: .hourly.precipitation_probability[$i]}][0:9] as $hours
  | [range(0; (.daily.time | length)) as $i
     | {date: .daily.time[$i], max: (.daily.temperature_2m_max[$i] | round), min: (.daily.temperature_2m_min[$i] | round), code: .daily.weather_code[$i], pop: .daily.precipitation_probability_max[$i]}] as $days
  | .current as $c | {
    key: $key, unit: $tsym, wind_unit: $wsym, place: $name, fetched: ($now|tonumber), stale: false,
    current_temp: ($c.temperature_2m | tostring), current_icon: glyph($c.weather_code; $c.is_day),
    current_code: $c.weather_code, is_day: $c.is_day, pop: ($hours[0].pop // null), hourly: $hours, daily: $days,
    forecast: [ { desc: desc($c.weather_code), icon: glyph($c.weather_code; $c.is_day),
                  max: (.daily.temperature_2m_max[0] | tostring), min: (.daily.temperature_2m_min[0] | tostring),
                  feels_like: ($c.apparent_temperature | tostring), wind: ($c.wind_speed_10m | round | tostring), humidity: ($c.relative_humidity_2m | tostring) } ]
  }' <<<"$raw") || out=""
if [ -z "$out" ]; then echo '{"error":"offline"}'; exit 0; fi
printf '%s\n' "$out" > "$cache.tmp" && mv "$cache.tmp" "$cache"
jq -c 'del(.key)' "$cache"
