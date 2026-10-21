#!/usr/bin/env bash
# stop.sh: stop the nested test session(s) only (never your own Hyprland)
for p in $(pgrep -x Hyprland); do
    if tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | grep -q 'hyprland.conf' && tr '\0' ' ' < "/proc/$p/cmdline" | grep -q "${NB:-/tmp/widgetdeck-nested}"; then kill "$p"; fi
done
sleep 2
for p in $(pgrep -x dbus-run-session); do kill "$p" 2>/dev/null; done
