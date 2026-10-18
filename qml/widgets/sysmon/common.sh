# shellcheck shell=bash
# Shared helpers of the WidgetDeck data scripts (sourced, never executed).
#   config:  ${WIDGETDECK_DIR:-~/.config/widgetdeck}/config.json   (location, units, language - edited in the builder)
#   cache:   ${XDG_CACHE_HOME:-~/.cache}/widgetdeck/
# remember the user's locale (language / unit system) BEFORE the scripts switch to the C locale for number formatting
WD_ORIG_LANG="${LC_MESSAGES:-${LC_ALL:-${LANG:-en_GB}}}"
WD_ORIG_MEAS="${LC_MEASUREMENT:-${LC_ALL:-${LANG:-en_GB}}}"
export LC_ALL=C
WD_DIR="${WIDGETDECK_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/widgetdeck}"
WD_CONFIG="$WD_DIR/config.json"
WD_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/widgetdeck"
mkdir -p "$WD_CACHE"

# cfg <jq filter> <default>: read a value from config.json (missing file / key -> default)
cfg() {
    local v
    # (jq's  // empty  would swallow a literal false, so test for null explicitly)
    v=$(jq -r "$1 | if . == null then empty else . end" "$WD_CONFIG" 2>/dev/null) || v=""
    printf '%s' "${v:-$2}"
}
# file_age <path>: seconds since the file was last written (huge when it does not exist)
file_age() {
    if [ -f "$1" ]; then echo $(( $(date +%s) - $(stat -c %Y "$1") )); else echo 999999999; fi
}
# The language / unit system of the user: config value, else derived from the environment (LANG / LC_MEASUREMENT).
sys_lang() {
    local l; l=$(cfg '.language' auto)
    if [ "$l" = auto ]; then l="$WD_ORIG_LANG"; fi
    case "$l" in de*) echo de ;; *) echo en ;; esac
}
sys_units() {
    local u; u=$(cfg '.units' auto)
    if [ "$u" = auto ]; then
        case "$WD_ORIG_MEAS" in *_US*|*_LR*|*_MM*) u=imperial ;; *) u=metric ;; esac
    fi
    echo "$u"
}
