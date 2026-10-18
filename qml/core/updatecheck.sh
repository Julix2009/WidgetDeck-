#!/usr/bin/env bash
# Update check: prints ONE json line, never fails, never prompts.
#   updatecheck.sh [--force]
# Runs at most once a day (result cached in ~/.cache/widgetdeck/update-check.json) unless --force. Disabled with config.json: update.check = false.
# Source: `git ls-remote` of the repository recorded in ../SOURCE (no API, no token). Stays silent (state "unknown") without network / access.
QML="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
export LC_ALL=C GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=true SSH_ASKPASS=true
export GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=8"
FORCE=0; [ "${1:-}" = "--force" ] && FORCE=1

CONF="${WIDGETDECK_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/widgetdeck}"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/widgetdeck"; CF="$CACHE/update-check.json"
VER="$(tr -d '[:space:]' < "$QML/VERSION" 2>/dev/null)"; VER="${VER:-0.0.0}"
REV="$(tr -d '[:space:]' < "$QML/REV" 2>/dev/null)"
src() { sed -n "s/^$1=//p" "$QML/SOURCE" 2>/dev/null | head -n1; }
URL="$(src url)"; REPO="$(src repo)"; UPDATER="$(src updater)"
[ -z "$URL" ] && [ -d "$REPO/.git" ] && URL="$(git -C "$REPO" remote get-url origin 2>/dev/null)"
CHECK="$(jq -r '.update.check // true' "$CONF/config.json" 2>/dev/null)"; CHANNEL="$(jq -r '.update.channel // "main"' "$CONF/config.json" 2>/dev/null)"
[ "$CHECK" = false ] && [ "$FORCE" = 0 ] && CHECK=false || CHECK=true
case "$CHANNEL" in stable|main) ;; *) CHANNEL=main ;; esac
now=$(date +%s)

emit() {   # emit <state> <latest> <notes>
    jq -nc --arg v "$VER" --arg s "$1" --arg l "$2" --arg n "$3" --arg c "$CHANNEL" --arg u "$UPDATER" --arg r "$REV" --argjson t "$now" \
        '{version:$v, state:$s, latest:$l, notes:$n, channel:$c, updater:$u, rev:$r, checked:$t}'
}

if [ "$CHECK" = false ]; then emit disabled "" ""; exit 0; fi

if [ "$FORCE" = 0 ] && [ -f "$CF" ]; then
    age=$(( now - $(jq -r '.checked // 0' "$CF" 2>/dev/null || echo 0) ))
    st="$(jq -r '.state // ""' "$CF" 2>/dev/null)"
    same="$(jq -r --arg v "$VER" --arg r "$REV" --arg c "$CHANNEL" '(.version == $v) and (.rev == $r) and (.channel == $c)' "$CF" 2>/dev/null)"
    limit=86400; [ "$st" = unknown ] && limit=3600
    if [ "$same" = true ] && [ "$age" -lt "$limit" ] && [ "$age" -ge 0 ]; then cat "$CF"; exit 0; fi
fi

save() { mkdir -p "$CACHE" 2>/dev/null && printf '%s\n' "$1" > "$CF.tmp" 2>/dev/null && mv "$CF.tmp" "$CF" 2>/dev/null; printf '%s\n' "$1"; }
unknown() { save "$(emit unknown "" "")"; exit 0; }

[ -n "$URL" ] && command -v git >/dev/null 2>&1 || unknown

notes_from() {   # notes_from <ref in clone>: changelog sections newer than the installed version
    git -C "$REPO" show "$1:CHANGELOG.md" 2>/dev/null | awk -v have="$VER" '
        function vgt(a, b,  x, y, i) { split(a, x, "."); split(b, y, "."); for (i = 1; i <= 3; i++) { if ((x[i]+0) > (y[i]+0)) return 1; if ((x[i]+0) < (y[i]+0)) return 0 } return 0 }
        /^## \[/ { v = $0; sub(/^## \[/, "", v); sub(/\].*/, "", v); show = (v ~ /^[0-9]+\.[0-9]+\.[0-9]+/) && vgt(v, have) }
        show && NF { print }' | head -c 1800
}

if [ "$CHANNEL" = stable ]; then
    out="$(timeout 20 git ls-remote --tags --refs "$URL" 'v[0-9]*' 2>/dev/null)" || unknown
    latest="$(printf '%s\n' "$out" | sed -n 's#.*refs/tags/v##p' | sort -V | tail -n1)"
    [ -n "$latest" ] || { save "$(emit current "" "")"; exit 0; }
    newer="$(printf '%s\n%s\n' "$VER" "$latest" | sort -V | tail -n1)"
    if [ "$latest" != "$VER" ] && [ "$newer" = "$latest" ]; then
        notes=""
        if [ -d "$REPO/.git" ] && timeout 30 git -C "$REPO" fetch --quiet --tags origin 2>/dev/null; then notes="$(notes_from "refs/tags/v$latest")"; fi
        save "$(emit available "$latest" "$notes")"
    else save "$(emit current "$latest" "")"; fi
else
    out="$(timeout 20 git ls-remote "$URL" refs/heads/main 2>/dev/null)" || unknown
    sha="$(printf '%s' "$out" | awk 'NR==1 {print $1}')"
    [ -n "$sha" ] || unknown
    if [ -n "$REV" ] && [ "$sha" != "$REV" ]; then
        latest=""; notes=""
        if [ -d "$REPO/.git" ] && timeout 30 git -C "$REPO" fetch --quiet --tags origin 2>/dev/null; then
            latest="$(git -C "$REPO" show origin/main:VERSION 2>/dev/null | tr -d '[:space:]')"; notes="$(notes_from origin/main)"
        fi
        save "$(emit available "${latest:-neuer Stand}" "$notes")"
    else save "$(emit current "" "")"; fi
fi
exit 0
