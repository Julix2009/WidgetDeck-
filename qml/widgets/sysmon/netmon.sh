#!/usr/bin/env bash
# Network monitor feed: one JSON line per second while it runs (the widget starts it only while it is visible).
#   rx / tx   bytes per second of the interface that carries the default route (follows it when it changes)
#   ssid, signal   from nmcli (every 10 s, wifi only);  ping   latency in ms to the ping target
# usage: netmon.sh [ping-target]      (the widget passes its "ping_target" prop; default 1.1.1.1)
export LC_ALL=C
TARGET="${1:-1.1.1.1}"
[[ "$TARGET" =~ ^[A-Za-z0-9._:][A-Za-z0-9._:-]*$ ]] || TARGET="1.1.1.1"
PF=$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/netmon-ping.XXXXXX")
cleanup() { jobs -p | xargs -r kill 2>/dev/null; rm -f "$PF"; }
trap cleanup EXIT
trap 'exit 0' TERM INT
echo x > "$PF"

IF=""; PRX=0; PTX=0; PT=0; SSID=""; SIG=-1; tick=0

# counters <interface>: sets RX / TX (bytes). Shell builtins only: this runs every second
counters() {
    local l v
    RX=""; TX=""
    while read -r l; do
        [ "${l%%:*}" = "$1" ] || continue
        read -r -a v <<<"${l#*:}"; RX=${v[0]}; TX=${v[8]}; return
    done < /proc/net/dev
}
# json <variable> <text>: the text as the inside of a JSON string
json() {
    local s=${2//[[:cntrl:]]/} bs='\' q='"'
    s=${s//"$bs"/"$bs$bs"}; s=${s//"$q"/"$bs$q"}
    printf -v "$1" '%s' "$s"
}
json JTARGET "$TARGET"

FORCE_OFFLINE="${XDG_RUNTIME_DIR:-/tmp}/quickshell/netmon-force-offline"      # test hook: touch this file -> the widget shows "Offline"

while true; do
    if [ -e "$FORCE_OFFLINE" ]; then printf '{"online":false}\n'; IF=""; sleep 1; continue; fi
    # the interface of the default route (ip fails -> no route -> offline)
    NIF=""; [[ "$(ip -4 route get 1.1.1.1 2>/dev/null)" =~ " dev "([^ $'\n']+) ]] && NIF=${BASH_REMATCH[1]}
    if [ -z "$NIF" ]; then
        printf '{"online":false}\n'
        IF=""; sleep 1; continue
    fi
    if [ "$NIF" != "$IF" ]; then IF="$NIF"; PRX=0; PTX=0; PT=0; SSID=""; SIG=-1; tick=0; fi

    counters "$IF"
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
    else KIND="link"; fi

    if [ "$KIND" = wifi ] && [ $(( tick % 10 )) -eq 0 ]; then
        while IFS= read -r LINE; do                    # "*:<signal>:<ssid>" is the network in use
            [ "${LINE:0:2}" = "*:" ] || continue
            LINE=${LINE:2}; SIG=${LINE%%:*}; SSID=${LINE#*:}; break
        done < <(nmcli -t -e no -f IN-USE,SIGNAL,SSID dev wifi list --rescan no 2>/dev/null)
    fi
    # one ping every 3 s, in the background: the loop never waits for it
    if [ $(( tick % 3 )) -eq 0 ]; then
        ( r=x; [[ "$(ping -n -c1 -W1 -- "$TARGET" 2>/dev/null)" =~ time=([0-9.]+)\ ms ]] && r=${BASH_REMATCH[1]}; echo "$r" > "$PF" ) &
    fi
    read -r PING < "$PF"; [ "$PING" = x ] && PING=null

    json JIF "$IF"; json JSSID "$SSID"
    [[ "$SIG" =~ ^-?[0-9]+$ ]] || SIG=-1
    [[ "$PING" =~ ^[0-9]+(\.[0-9]+)?$ ]] || PING=null
    printf '{"online":true,"iface":"%s","kind":"%s","ssid":"%s","signal":%s,"rx":%s,"tx":%s,"ping":%s,"target":"%s"}\n' \
        "$JIF" "$KIND" "$JSSID" "$SIG" "$RATE_RX" "$RATE_TX" "$PING" "$JTARGET"
    tick=$(( tick + 1 ))
    sleep 1
done
