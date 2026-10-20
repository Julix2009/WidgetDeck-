#!/usr/bin/env bash
# Prints the path of the current wallpaper (one line, empty when nothing is found). Never fails.
# Chain: awww -> swww -> hyprpaper (running / config) -> swaybg -> wpaperd (config). A manual path in the settings wins over all of it (handled in Wallpaper.qml).
# Prints "<tool>\t<path>" with --verbose (used by `widgetdeck doctor`).
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
VERBOSE=0; [ "${1:-}" = "--verbose" ] && VERBOSE=1
[ "${1:-}" = "--all" ] && VERBOSE=1

# the literal "~/" prefix is matched on purpose
# shellcheck disable=SC2088
expand() { local p="$1"; case "$p" in "~/"*) p="$HOME/${p#"~/"}" ;; esac; printf '%s' "$p"; }
clean() { sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'\$//"; }
isimg() { case "${1,,}" in *.png|*.jpg|*.jpeg|*.webp|*.bmp|*.gif|*.avif|*.jxl|*.tiff) return 0 ;; esac; return 1; }
# a directory (wpaperd, hyprpaper) -> its first image
resolve() {
    local p; p="$(expand "$1")"
    if [ -d "$p" ]; then p="$(find "$p" -maxdepth 2 -type f 2>/dev/null | sort | while IFS= read -r f; do isimg "$f" && { echo "$f"; break; }; done)"; fi
    [ -n "$p" ] && [ -f "$p" ] && printf '%s' "$p"
}
found() {   # found <tool> <path>
    local r; r="$(resolve "$2")"
    [ -n "$r" ] || return 1
    if [ "$VERBOSE" = 1 ]; then printf '%s\t%s\n' "$1" "$r"; else printf '%s\n' "$r"; fi
    exit 0
}

# --all: one line per output "<output>\t<tool>\t<path>" ("*" = the same picture on every output / not told per output). Used for several monitors.
if [ "${1:-}" = "--all" ] || [ "${2:-}" = "--all" ]; then
    emitted=0
    emit() { local r; r="$(resolve "$3")"; [ -n "$r" ] || return 0; printf '%s\t%s\t%s\n' "$1" "$2" "$r"; emitted=1; }
    if command -v awww >/dev/null 2>&1; then
        while IFS= read -r l; do                         # ": DP-1: 2560x1440, scale: 1, currently displaying: image: /path"
            o="$(sed -n 's/^[: ]*\([^:]*\):.*image: .*/\1/p' <<<"$l" | clean)"; p="$(sed -n 's/.*image: //p' <<<"$l" | clean)"
            [ -n "$o" ] && [ -n "$p" ] && emit "$o" awww "$p"
        done < <(awww query 2>/dev/null)
    fi
    if [ "$emitted" = 0 ] && command -v swww >/dev/null 2>&1; then
        while IFS= read -r l; do
            o="$(sed -n 's/^[: ]*\([^:]*\):.*image: .*/\1/p' <<<"$l" | clean)"; p="$(sed -n 's/.*image: //p' <<<"$l" | clean)"
            [ -n "$o" ] && [ -n "$p" ] && emit "$o" swww "$p"
        done < <(swww query 2>/dev/null)
    fi
    if [ "$emitted" = 0 ] && command -v hyprctl >/dev/null 2>&1; then
        while IFS= read -r l; do                         # "DP-1 = /path"  (hyprpaper listactive)
            case "$l" in *" = "*) emit "$(clean <<<"${l%% = *}")" hyprpaper "$(clean <<<"${l#* = }")" ;; esac
        done < <(hyprctl hyprpaper listactive 2>/dev/null)
    fi
    f="$CFG/hypr/hyprpaper.conf"
    if [ "$emitted" = 0 ] && [ -f "$f" ]; then
        # old syntax: wallpaper = DP-1,/path (an empty monitor = all)     new syntax: wallpaper { monitor = DP-1 / path = /path }
        while IFS= read -r l; do
            v="$(sed -E 's/^[^=]*=//' <<<"$l" | clean)"; emit "$(clean <<<"${v%%,*}" | sed 's/^$/*/')" hyprpaper "${v#*,}"
        done < <(grep -E '^[[:space:]]*wallpaper[[:space:]]*=' "$f")
        awk '/^[[:space:]]*wallpaper[[:space:]]*\{/ {inb=1; m=""; p=""; next} inb && /^[[:space:]]*monitor[[:space:]]*=/ {sub(/^[^=]*=/,""); gsub(/^[ \t]+|[ \t]+$/,""); m=$0} inb && /^[[:space:]]*path[[:space:]]*=/ {sub(/^[^=]*=/,""); gsub(/^[ \t]+|[ \t]+$/,""); p=$0} inb && /\}/ {inb=0; if (p != "") print (m==""?"*":m) "\t" p}' "$f" | while IFS=$'\t' read -r o p; do emit "$o" hyprpaper "$p"; done
    fi
    if [ "$emitted" = 0 ]; then
        while IFS= read -r l; do                         # swaybg -o DP-1 -i /path   (one process per output)
            o="$(sed -n 's/.* -o \([^ ]*\).*/\1/p; s/.* --output \([^ ]*\).*/\1/p' <<<"$l" | head -n1)"; p="$(sed -n 's/.* -i \([^ ]*\).*/\1/p; s/.* --image \([^ ]*\).*/\1/p' <<<"$l" | head -n1)"
            [ -n "$p" ] && emit "${o:-*}" swaybg "$p"
        done < <(pgrep -a swaybg 2>/dev/null)
    fi
    if [ "$emitted" = 0 ]; then
        for f in "$CFG/wpaperd/config.toml" "$CFG/wpaperd/wallpaper.toml"; do
            [ -f "$f" ] || continue
            awk '/^\[/ {sec=$0; gsub(/[\[\]" ]/,"",sec)} /^[[:space:]]*path[[:space:]]*=/ {v=$0; sub(/^[^=]*=/,"",v); gsub(/^[ \t"]+|[ \t"]+$/,"",v); print (sec==""||sec=="default"||sec=="any"?"*":sec) "\t" v}' "$f" | while IFS=$'\t' read -r o p; do emit "$o" wpaperd "$p"; done
        done
    fi
    exit 0
fi

if command -v awww >/dev/null 2>&1; then p="$(awww query 2>/dev/null | sed -n 's/.*image: //p' | head -n1 | clean)"; [ -n "$p" ] && found awww "$p"; fi
if command -v swww >/dev/null 2>&1; then p="$(swww query 2>/dev/null | sed -n 's/.*image: //p' | head -n1 | clean)"; [ -n "$p" ] && found swww "$p"; fi
if command -v hyprctl >/dev/null 2>&1; then
    p="$(hyprctl hyprpaper listactive 2>/dev/null | head -n1 | sed 's/.*= //' | clean)"; [ -n "$p" ] && found hyprpaper "$p"
fi
f="$CFG/hypr/hyprpaper.conf"
if [ -f "$f" ]; then
    # old syntax: preload/wallpaper = monitor,path     new syntax: wallpaper { monitor = ...  path = ... }
    p="$(grep -E '^[[:space:]]*path[[:space:]]*=' "$f" | head -n1 | sed -E 's/^[^=]*=//' | clean)"
    [ -z "$p" ] && p="$(grep -E '^[[:space:]]*wallpaper[[:space:]]*=' "$f" | head -n1 | sed -E 's/^[^=]*=//; s/^[^,]*,//' | clean)"
    [ -n "$p" ] && found hyprpaper "$p"
fi
p="$(pgrep -a swaybg 2>/dev/null | sed -n 's/.* -i \([^ ]*\).*/\1/p; s/.*--image \([^ ]*\).*/\1/p' | head -n1 | clean)"
[ -n "$p" ] && found swaybg "$p"
for f in "$CFG/wpaperd/config.toml" "$CFG/wpaperd/wallpaper.toml"; do
    [ -f "$f" ] || continue
    p="$(grep -E '^[[:space:]]*path[[:space:]]*=' "$f" | head -n1 | sed -E 's/^[^=]*=//' | clean)"
    [ -n "$p" ] && found wpaperd "$p"
done
exit 0
