#!/usr/bin/env bash
# Network monitor feed: one JSON line per second while it runs (the widget starts it only while it is visible).
#   rx / tx   bytes per second of the interface that carries the default route (follows it when it changes)
#   ssid, signal   from nmcli (every 5 s, wifi only);  ping   latency in ms to the ping target
# usage: netmon.sh [ping-target]      (the widget passes its "ping_target" prop; default 1.1.1.1)
export LC_ALL=C
TARGET="${1:-1.1.1.1}"
[[ "$TARGET" =~ ^[A-Za-z0-9._:-]+$ ]] || TARGET="1.1.1.1"
PF=$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/netmon-ping.XXXXXX")
cleanup() { kill $(jobs -p) 2>/dev/null; rm -f "$PF"; }
trap cleanup EXIT
trap 'exit 0' TERM INT
echo x > "$PF"

IF=""; PRX=0; PTX=0; PT=0; SSID=""; SIG=-1; tick=0

counters() { awk -v i="$1" '{ gsub(":", " ") } $1 == i { print $2, $10 }' /proc/net/dev; }

FORCE_OFFLINE="${XDG_RUNTIME_DIR:-/tmp}/quickshell/netmon-force-offline"      # test hook: touch this file -> the widget shows "Offline"

while true; do
    if [ -e "$FORCE_OFFLINE" ]; then printf '{"online":false}\n'; IF=""; sleep 1; continue; fi
    # the interface of the default route (ip fails -> no route -> offline)
    NIF=$(ip -4 route get 1.1.1.1 2>/dev/null | sed -n 's/.* dev \([^ ]*\).*/\1/p' | head -n1)
    if [ -z "$NIF" ]; then
        printf '{"online":false}\n'
        IF=""; sleep 1; continue
    fi
    if [ "$NIF" != "$IF" ]; then IF="$NIF"; PRX=0; PTX=0; PT=0; SSID=""; SIG=-1; tick=0; fi

    read -r RX TX < <(counters "$IF")
    NOW=${EPOCHREALTIME/[.,]/}
    if [ "$PT" -gt 0 ] && [ -n "$RX" ]; then
        DT=$(( NOW - PT )); [ "$DT" -lt 1 ] && DT=1
        RATE_RX=$(( (RX - PRX) * 1000000 / DT )); RATE_TX=$(( (TX - PTX) * 1000000 / DT ))
        [ "$RATE_RX" -lt 0 ] && RATE_RX=0; [ "$RATE_TX" -lt 0 ] && RATE_TX=0
    else
        RATE_RX=0; RATE_TX=0
    fi
    PRX=${RX:-0}; PTX=${TX:-0}; PT=$NOW

    if [ -d "/sys/class/net/$IF/wireless" ]; then KIND=wifi
    elif [ -d "/sys/class/net/$IF/device" ] || [[ "$IF" == e* ]]; then KIND=ethernet
    else KIND=link; fi

    if [ "$KIND" = wifi ] && [ $(( tick % 5 )) -eq 0 ]; then
        LINE=$(nmcli -t -e no -f IN-USE,SIGNAL,SSID dev wifi list --rescan no 2>/dev/null | grep '^\*' | head -n1)
        if [ -n "$LINE" ]; then SIG=$(cut -d: -f2 <<<"$LINE"); SSID=$(cut -d: -f3- <<<"$LINE"); fi
    fi
    # one ping every 3 s, in the background: the loop never waits for it
    if [ $(( tick % 3 )) -eq 0 ]; then
        ( r=$(ping -n -c1 -W1 "$TARGET" 2>/dev/null | sed -n 's/.*time=\([0-9.]*\) ms.*/\1/p'); echo "${r:-x}" > "$PF" ) &
    fi
    read -r PING < "$PF"; [ "$PING" = x ] && PING=null

    jq -nc --arg ifc "$IF" --arg kind "$KIND" --arg ssid "$SSID" --argjson sig "${SIG:--1}" \
        --argjson rx "$RATE_RX" --argjson tx "$RATE_TX" --argjson ping "${PING:-null}" --arg target "$TARGET" \
        '{online:true, iface:$ifc, kind:$kind, ssid:$ssid, signal:$sig, rx:$rx, tx:$tx, ping:$ping, target:$target}'
    tick=$(( tick + 1 ))
    sleep 1
done
