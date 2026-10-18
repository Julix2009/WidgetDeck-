# shellcheck shell=bash
# Helpers for migration scripts (sourced).

# merge_defaults <json file> '<json object>'   adds keys that are MISSING; existing values always win (deep merge)
merge_defaults() {
    local f="$1" defaults="$2" tmp
    [ -f "$f" ] || printf '{}\n' > "$f"
    tmp="$(mktemp "$f.XXXXXX")"
    if jq --argjson d "$defaults" '$d * .' "$f" > "$tmp"; then mv "$tmp" "$f"; else rm -f "$tmp"; return 1; fi
}
