#!/usr/bin/env bash
# One-shot JSON for the "System info" widget, read from fastfetch: {"info": {Title, OS, Host, ...}, "logo": "<small ASCII logo>"}.
# `fastfetch.sh logo` also fetches the logo. Without fastfetch: {"missing": true}. The widget runs it about once a minute while visible.
export LC_ALL=C
command -v fastfetch >/dev/null 2>&1 || { echo '{"missing":true}'; exit 0; }
info=$(fastfetch --json -s Title:OS:Host:Kernel:Uptime:Packages:Shell:WM:CPU:GPU:Memory:Disk 2>/dev/null) || info='[]'
[ -n "$info" ] || info='[]'
logo=""
if [ "${1:-}" = "logo" ]; then
    id=$(. /etc/os-release 2>/dev/null; echo "${ID:-}")
    [ -n "$id" ] && logo=$(fastfetch --logo-type builtin --logo "${id}_small" -s none --pipe 2>/dev/null | head -n 12)
    [ -n "$logo" ] || logo=$(fastfetch -s none --pipe 2>/dev/null | head -n 12)
fi
jq -nc --argjson info "$info" --arg logo "$logo" '{info: ($info | map({(.type): .result}) | add // {}), logo: $logo}'
