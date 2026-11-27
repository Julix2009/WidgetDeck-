#!/usr/bin/env bash
# Shell parts: paths with spaces, markers, uninstall --purge, widgetdeck-update texts. Everything in a temporary home: bash tools/low-test.sh
set -u
REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fails=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi; }
# shellcheck source=lib/hypr.sh
SCRIPT_DIR="$REPO"; . "$REPO/lib/common.sh"; . "$REPO/lib/hypr.sh"

# ---- the program path in the Hyprland templates
check "harmless path stays as it is" '[ "$(hypr_bin_word /opt/x/bin/widgetdeck conf)" = /opt/x/bin/widgetdeck ]'
for p in "/home/a b/bin/widgetdeck" "/home/a&b|c/widgetdeck" "/home/it's/widgetdeck" '/home/q"uote/widgetdeck'; do
    w="$(hypr_bin_word "$p" conf)"
    check "shell reads back: $p" '[ "$(eval "printf %s $w")" = "$p" ]'
done
BIN_DEST="/home/a b&c/widgetdeck"
check "rendered autostart line" 'hypr_render "$REPO/hypr/widgetdeck.conf.in" | grep -qxF "exec-once = '"'"'/home/a b&c/widgetdeck'"'"' daemon"'
BIN_DEST='/home/q"u/widgetdeck'
check "quote inside a Lua string is escaped" 'hypr_render "$REPO/hypr/widgetdeck.lua.in" | grep -qF "hl.exec_cmd(\"'"'"'/home/q\\\"u/widgetdeck'"'"' daemon\")"'

# ---- running config with a space, markers
mkdir -p "$T/my cfg"; touch "$T/my cfg/hyprland.lua"
printf 'Hyprland\0-c\0%s\0' "$T/my cfg/hyprland.lua" > "$T/cmdline"
check "config path with a space is found" '[ "$(hypr_config_of "$T/cmdline")" = "$T/my cfg/hyprland.lua" ]'
printf 'a\n# %s\nx\n# %s\nb\n' "$HYPR_MARK_BEGIN" "$HYPR_MARK_END" > "$T/full"
printf 'a\n# %s\nx\nb\n' "$HYPR_MARK_BEGIN" > "$T/open"
check "complete block accepted, block without end refused" 'hypr_block_complete "$T/full" && ! hypr_block_complete "$T/open"'

# ---- uninstall --purge in a temporary home; a secret-tool stand-in records whether the keyring would be touched
mkdir -p "$T/stub"; printf '#!/bin/sh\necho "$@" >> "%s/keyring-calls"\n' "$T" > "$T/stub/secret-tool"; chmod +x "$T/stub/secret-tool"
H="$T/home"; mkdir -p "$H/.config/widgetdeck" "$H/.local/share/widgetdeck-private" "$H/.local/share/widgetdeck"
echo secret > "$H/.local/share/widgetdeck-private/untis.json"
git -c init.defaultBranch=main init -q "$H/.local/share/widgetdeck/repo"
out="$(PATH="$T/stub:$PATH" WIDGETDECK_LANG=en bash "$REPO/install.sh" --uninstall --purge --yes --prefix "$H" 2>&1)"; rc=$?
export rc
check "purge ends cleanly, without 'No such file'" '[ $rc = 0 ] && ! grep -qE "No such file|Datei oder Verzeichnis" <<<"$out"'
check "Untis file, settings, cache and empty clone are gone" '[ ! -e "$H/.local/share/widgetdeck-private" ] && [ ! -e "$H/.config/widgetdeck" ] && [ ! -e "$H/.cache/widgetdeck" ] && [ ! -e "$H/.local/share/widgetdeck" ]'
check "--prefix never touches the keyring" '[ ! -e "$T/keyring-calls" ]'
mkdir -p "$H/.local/share/widgetdeck"; git -c init.defaultBranch=main init -q "$H/.local/share/widgetdeck/repo"; echo mine > "$H/.local/share/widgetdeck/repo/mine.txt"
PATH="$T/stub:$PATH" bash "$REPO/install.sh" --uninstall --purge --yes --prefix "$H" >/dev/null 2>&1
check "a clone with own files is kept" '[ -f "$H/.local/share/widgetdeck/repo/mine.txt" ]'

# ---- swaybg picture with a space in its path (a stand-in process carries the arguments; the other wallpaper tools answer nothing)
mkdir -p "$T/wp/stub" "$T/wp/my pictures"; touch "$T/wp/my pictures/a b.png"
for tool in awww swww hyprctl; do printf '#!/bin/sh\nexit 0\n' > "$T/wp/stub/$tool"; done
bash -c 'sleep 20; :' swaybg -o DP-1 -i "$T/wp/my pictures/a b.png" & fake=$!
printf '#!/bin/sh\necho %s\n' "$fake" > "$T/wp/stub/pgrep"; chmod +x "$T"/wp/stub/*
wp() { env PATH="$T/wp/stub:/usr/bin:/bin" HOME="$T/wp" XDG_CONFIG_HOME="$T/wp/cfg" bash "$REPO/qml/core/wallpaper.sh" "$@"; }
check "swaybg: single picture" '[ "$(wp)" = "$T/wp/my pictures/a b.png" ]'
check "swaybg: per output" '[ "$(wp --all)" = "$(printf "DP-1\tswaybg\t%s" "$T/wp/my pictures/a b.png")" ]'
kill "$fake" 2>/dev/null

# ---- widgetdeck-update: the terminal wrapper speaks the user's language
printf '#!/bin/sh\nshift\nprintf "%%s\\n" "$@" > "%s/term-args"\n' "$T" > "$T/stub/faketerm"; chmod +x "$T/stub/faketerm"
PATH="$T/stub:$PATH" TERMINAL=faketerm LC_ALL=C sh "$REPO/bin/widgetdeck-update" --terminal
check "English system: English prompt" 'grep -q "Press Enter to close" "$T/term-args" && ! grep -q Schliessen "$T/term-args"'

[ "$fails" = 0 ] && echo "all shell tests passed" || echo "$fails failed"
[ "$fails" = 0 ]
