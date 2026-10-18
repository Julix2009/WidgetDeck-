#!/usr/bin/env bash
# Prints the path of the current wallpaper (one line, empty when nothing is found). Never fails.
# Chain: awww -> swww -> hyprpaper (running / config) -> swaybg -> wpaperd (config). A manual path in the settings wins over all of it (handled in Wallpaper.qml).
# Prints "<tool>\t<path>" with --verbose (used by `widgetdeck doctor`).
CFG="${XDG_CONFIG_HOME:-$HOME/.config}"
VERBOSE=0; [ "${1:-}" = "--verbose" ] && VERBOSE=1

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
