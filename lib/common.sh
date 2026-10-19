# shellcheck shell=bash
# Shared helpers of install.sh / update.sh / uninstall.sh (sourced, never executed).

if [ -t 1 ]; then C_B=$'\033[1m'; C_G=$'\033[32m'; C_Y=$'\033[33m'; C_R=$'\033[31m'; C_0=$'\033[0m'; else C_B=""; C_G=""; C_Y=""; C_R=""; C_0=""; fi

DRY_RUN=0
ASSUME_YES=0
LOG_FILE=""

# ---- texts: English is the source language; German from lib/i18n.sh (WIDGETDECK_LANG, else LC_ALL / LC_MESSAGES / LANG) ----
_wd_lang="${WIDGETDECK_LANG:-${LC_ALL:-${LC_MESSAGES:-${LANG:-}}}}"; _wd_lang="${_wd_lang:0:2}"
declare -gA DE=()
# shellcheck source=lib/i18n.sh
[ -f "${SCRIPT_DIR:-.}/lib/i18n.sh" ] && . "${SCRIPT_DIR:-.}/lib/i18n.sh"
# t "format with %s" args...   -> the (translated) text, printf-formatted
t() {
    local f="$1"; shift
    if [ "$_wd_lang" = de ] && [ -n "${DE[$f]:-}" ]; then f="${DE[$f]}"; fi
    # shellcheck disable=SC2059
    printf "$f" "$@"
}

# ---- paths (one place for install.sh / update.sh / doctor): XDG-aware, or below --prefix ----
# wd_paths <home> <prefix-or-empty>
wd_paths() {
    H="$1"
    if [ -n "$2" ]; then CONFIG_HOME="$H/.config"; CACHE_HOME="$H/.cache"
    else CONFIG_HOME="${XDG_CONFIG_HOME:-$H/.config}"; CACHE_HOME="${XDG_CACHE_HOME:-$H/.cache}"; fi
    QML_DEST="$CONFIG_HOME/quickshell/widgetdeck"
    BIN_DIR="$H/.local/bin"; BIN_DEST="$BIN_DIR/widgetdeck"; UPD_DEST="$BIN_DIR/widgetdeck-update"; DOC_DEST="$BIN_DIR/widgetdeck-doctor"
    CONF_DIR="$CONFIG_HOME/widgetdeck"; CACHE_DIR="$CACHE_HOME/widgetdeck"; MATUGEN_DIR="$CONFIG_HOME/matugen"
    STATE_FILE="$CACHE_DIR/install-state"
}

_log() { [ -n "$LOG_FILE" ] && [ "$DRY_RUN" = 0 ] && printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG_FILE" || true; }
say()  { printf '%s\n' "$*"; _log "$*"; }
step() { printf '\n%s== %s ==%s\n' "$C_B" "$*" "$C_0"; _log "== $* =="; }
ok()   { printf '  %s[ ok ]%s %s\n' "$C_G" "$C_0" "$*"; _log "ok: $*"; }
warn() { printf '  %s[warn]%s %s\n' "$C_Y" "$C_0" "$*" >&2; _log "warn: $*"; }
info() { printf '         %s\n' "$*"; _log "$*"; }
die()  { printf '%s[ERROR]%s %s\n' "$C_R" "$C_0" "$*" >&2; _log "ERROR: $*"; [ -n "$LOG_FILE" ] && printf '         Log: %s\n' "$LOG_FILE" >&2; exit 1; }

# ask "question" default(y|n): returns 0 for yes. --yes answers the default... for yes-by-default questions it says yes, for no-by-default questions it says no.
ask() {
    local q="$1" def="${2:-y}" a hint
    if [ "$ASSUME_YES" = 1 ]; then [ "$def" = y ]; return; fi
    if [ ! -t 0 ]; then _log "no terminal: '$q' -> default $def"; [ "$def" = y ]; return; fi
    if [ "$_wd_lang" = de ]; then if [ "$def" = y ]; then hint="[J/n]"; else hint="[j/N]"; fi; else if [ "$def" = y ]; then hint="[Y/n]"; else hint="[y/N]"; fi; fi
    while true; do
        read -r -p "  ? $q $hint " a || a=""
        a="${a,,}"
        case "$a" in "") [ "$def" = y ]; return ;; j|ja|y|yes) return 0 ;; n|nein|no) return 1 ;; esac
    done
}

# run <cmd...>: executes, or only prints in --dry-run mode.
run() {
    if [ "$DRY_RUN" = 1 ]; then printf '  [dry-run] %s\n' "$*"; return 0; fi
    _log "run: $*"
    "$@"
}

# vercmp <a> <b>: prints -1, 0 or 1 (version strings like 0.55.4)
vercmp() {
    local a="$1" b="$2"
    [ "$a" = "$b" ] && { echo 0; return; }
    if [ "$(printf '%s\n%s\n' "$a" "$b" | sort -V | head -n1)" = "$a" ]; then echo -1; else echo 1; fi
}
# first x.y.z-looking version in a string
ver_of() { printf '%s' "$1" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1; }
sha_of() { if [ -f "$1" ]; then sha256sum "$1" | cut -d' ' -f1; else echo none; fi; }
stamp() { date '+%Y%m%d-%H%M%S'; }

# state file (key=value) used by uninstall
state_set() { [ "$DRY_RUN" = 1 ] && return 0; mkdir -p "$(dirname "$STATE_FILE")"; touch "$STATE_FILE"; grep -v "^$1=" "$STATE_FILE" > "$STATE_FILE.tmp" || true; printf '%s=%s\n' "$1" "$2" >> "$STATE_FILE.tmp"; mv "$STATE_FILE.tmp" "$STATE_FILE"; }
state_get() { [ -f "$STATE_FILE" ] && grep -m1 "^$1=" "$STATE_FILE" | cut -d= -f2- || true; }
