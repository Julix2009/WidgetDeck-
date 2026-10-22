#!/bin/sh
# Focus timer: "do not disturb" of the notification daemon that is running (the widget only asks / sets, it never stops a daemon).
#   dnd.sh detect                 prints: dunst | mako | swaync | flagfile | none
#   dnd.sh get <backend>          prints: on | off | unknown
#   dnd.sh set <backend> on|off
# dunst: dunstctl set-paused · mako: makoctl mode (the mode "do-not-disturb") · swaync: swaync-client -dn / -df
# flagfile: a notification shell whose popups follow the file $QS_CACHE_DND/state (default ~/.cache/quickshell/dnd/state): 1 = silent, 0 or no file = on
# (WidgetDeck's own notification module is handled inside the program, not here.)
flag_dir() { printf '%s' "${QS_CACHE_DND:-$HOME/.cache/quickshell/dnd}"; }
owner() {
    pid=$(busctl --user status org.freedesktop.Notifications 2>/dev/null | sed -n 's/^PID=//p' | head -n1)
    [ -n "$pid" ] && cat "/proc/$pid/comm" 2>/dev/null
}
case "${1:-}" in
    detect)
        o=$(owner)
        case "$o" in
            dunst) echo dunst ;;
            mako) echo mako ;;
            swaync) echo swaync ;;
            "") [ -d "$(flag_dir)" ] && echo flagfile || echo none ;;
            *) [ -d "$(flag_dir)" ] && echo flagfile || echo none ;;
        esac ;;
    get)
        case "${2:-}" in
            dunst) case "$(dunstctl is-paused 2>/dev/null)" in true) echo on ;; false) echo off ;; *) echo unknown ;; esac ;;
            mako) if makoctl mode 2>/dev/null | grep -qx 'do-not-disturb'; then echo on; else echo off; fi ;;
            swaync) case "$(swaync-client -D 2>/dev/null)" in true) echo on ;; false) echo off ;; *) echo unknown ;; esac ;;
            flagfile) if [ "$(cat "$(flag_dir)/state" 2>/dev/null)" = 1 ]; then echo on; else echo off; fi ;;
            *) echo unknown ;;
        esac ;;
    set)
        v="${3:-}"; [ "$v" = on ] || [ "$v" = off ] || exit 2
        case "${2:-}" in
            dunst) [ "$v" = on ] && dunstctl set-paused true || dunstctl set-paused false ;;
            mako) [ "$v" = on ] && makoctl mode -a do-not-disturb >/dev/null || makoctl mode -r do-not-disturb >/dev/null ;;
            swaync) [ "$v" = on ] && swaync-client -dn >/dev/null || swaync-client -df >/dev/null ;;
            flagfile) mkdir -p "$(flag_dir)" && { [ "$v" = on ] && printf '1\n' || printf '0\n'; } > "$(flag_dir)/state" ;;
            *) exit 2 ;;
        esac ;;
    *) echo "usage: dnd.sh detect | get <backend> | set <backend> on|off" >&2; exit 2 ;;
esac
