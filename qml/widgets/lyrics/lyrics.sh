#!/usr/bin/env bash
# lyrics.sh <artist> <title> <album> <seconds> : prints ONE json line {"state": "ok" | "none" | "error", "synced": "<LRC>", "plain": "<text>", "instrumental": false}.
# Source: LRCLIB (https://lrclib.net, free, no key). Sent: artist, title, album, length and - like with every connection - your IP address.
# Found lyrics are cached in ~/.cache/widgetdeck/lyrics/ (private files, 30 days), "not found" for one day; a network error is never cached.
export LC_ALL=C
artist="${1:-}"; title="${2:-}"; album="${3:-}"; secs="${4:-0}"
[ -n "$title" ] || { echo '{"state":"none","synced":"","plain":"","instrumental":false}'; exit 0; }
case "$secs" in ''|*[!0-9]*) secs=0 ;; esac

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/widgetdeck/lyrics"
key=$(printf '%s\n%s\n%s\n%s' "$artist" "$title" "$album" "$secs" | sha1sum | cut -d' ' -f1)
cache="$cache_dir/$key.json"
if [ -f "$cache" ]; then
    state=$(jq -r '.state // ""' "$cache" 2>/dev/null)
    age=$(( $(date +%s) - $(stat -c %Y "$cache" 2>/dev/null || echo 0) ))
    limit=2592000; [ "$state" = "none" ] && limit=86400
    if [ -n "$state" ] && [ "$age" -lt "$limit" ]; then cat "$cache"; exit 0; fi
fi

api="https://lrclib.net/api"
ua="WidgetDeck (https://github.com/Julix2009/WidgetDeck-)"
get() { curl -sS -m 15 --fail -A "$ua" -G "$@" 2>/dev/null; }

reply=""; net=ok
args=(--data-urlencode "track_name=$title")
[ -n "$artist" ] && args+=(--data-urlencode "artist_name=$artist")
[ -n "$album" ] && args+=(--data-urlencode "album_name=$album")
[ "$secs" -gt 0 ] && args+=(--data-urlencode "duration=$secs")
reply=$(get "$api/get" "${args[@]}"); rc=$?
if [ "$rc" -ne 0 ]; then
    # 22 = HTTP error (404 = not found): try the search; anything else = no network
    if [ "$rc" -eq 22 ]; then
        res=$(get "$api/search" --data-urlencode "track_name=$title" ${artist:+--data-urlencode "artist_name=$artist"}); rc2=$?
        if [ "$rc2" -eq 0 ]; then
            # the first hit with synchronised lyrics, whose length is close to the song (when the length is known)
            reply=$(printf '%s' "$res" | jq -c --argjson d "$secs" '[.[] | select((.syncedLyrics // "") != "") | select($d == 0 or ((.duration - $d) | fabs) <= 5)] | .[0] // empty' 2>/dev/null)
        else
            net=down
        fi
    else
        net=down
    fi
fi
if [ "$net" = "down" ]; then echo '{"state":"error","synced":"","plain":"","instrumental":false}'; exit 0; fi

out=$(printf '%s' "${reply:-null}" | jq -c 'if . == null or (type != "object") then {state:"none",synced:"",plain:"",instrumental:false}
    else {state: (if ((.syncedLyrics // "") != "" or (.plainLyrics // "") != "" or (.instrumental // false)) then "ok" else "none" end),
          synced: (.syncedLyrics // ""), plain: (.plainLyrics // ""), instrumental: (.instrumental // false)} end' 2>/dev/null) \
    || out='{"state":"none","synced":"","plain":"","instrumental":false}'
umask 077
mkdir -p "$cache_dir" 2>/dev/null && printf '%s\n' "$out" > "$cache"
printf '%s\n' "$out"
