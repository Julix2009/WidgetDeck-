#!/usr/bin/env bash
# What would a module replace? Prints one line per conflict, nothing when there is none. Never stops or changes anything.
#   conflicts.sh bar            other bars / panels that are running or installed as the session's bar
#   conflicts.sh notifications  the program that owns org.freedesktop.Notifications right now
# Exit code 0 always; the caller reads the output.
what="${1:-}"
case "$what" in
    bar)
        for p in waybar ags eww hyprpanel yambar ironbar sfwbar nwg-panel lemonbar polybar; do
            pgrep -x "$p" >/dev/null 2>&1 && echo "$p (running)"
        done
        # another Quickshell instance that is not us (other bars are often Quickshell configs)
        { pgrep -ax quickshell; pgrep -ax qs; } 2>/dev/null | grep -v -- 'widgetdeck' | sed 's/^[0-9]* /quickshell config: /' | sort -u | head -n3
        ;;
    notifications)
        owner=""
        if command -v busctl >/dev/null 2>&1; then
            pid="$(busctl --user status org.freedesktop.Notifications 2>/dev/null | sed -n 's/^PID=//p' | head -n1)"
            [ -n "$pid" ] && owner="$(cat "/proc/$pid/comm" 2>/dev/null)"
        fi
        if [ -z "$owner" ]; then
            for p in dunst mako swaync hyprpanel deadd-notification-center fnott wired; do pgrep -x "$p" >/dev/null 2>&1 && owner="$p"; done
        fi
        # quickshell owning it is only "us" when it is this very config - cannot tell cheaply, so name it
        [ -n "$owner" ] && echo "$owner (owns org.freedesktop.Notifications)"
        ;;
esac
exit 0
