#!/usr/bin/env bash
# One-shot JSON: uptime (s), kernel, failed systemd units (system and user). The widget runs it every 30 s while visible.
export LC_ALL=C
up=$(cut -d' ' -f1 /proc/uptime)
names() { awk 'NF { sub(/^[^[:alnum:]]+/, "", $1); print $1 }'; }
sys=$(systemctl --failed --no-legend --plain --no-pager 2>/dev/null | names)
usr=$(systemctl --user --failed --no-legend --plain --no-pager 2>/dev/null | names)
jq -nc --argjson up "${up:-0}" --arg kernel "$(uname -r)" --arg sys "$sys" --arg usr "$usr" \
    '{up:$up, kernel:$kernel, sys:($sys|split("\n")|map(select(length>0))), user:($usr|split("\n")|map(select(length>0)))}'
