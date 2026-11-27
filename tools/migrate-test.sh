#!/usr/bin/env bash
# Tests lib/migrate.sh in a temporary folder (never touches the real settings): bash tools/migrate-test.sh
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fails=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; fails=$((fails + 1)); fi; }

# run_case <name> <extra shell code, e.g. a broken cp> : settings in $T/<name>/widgetdeck, one failing or working migration
run_case() {
    local d="$T/$1" mig="$2" extra="$3"
    mkdir -p "$d/prog/migrations" "$d/prog/lib"
    printf '%s\n' "$mig" > "$d/prog/migrations/0001_test.sh"
    [ -e "$d/widgetdeck" ] || { mkdir -p "$d/widgetdeck"; echo '{"schema":0,"mine":1}' > "$d/widgetdeck/config.json"; echo layout > "$d/widgetdeck/widgets.json"; }
    bash -c 'set -euo pipefail
        . "$1/lib/common.sh"; . "$1/lib/migrate.sh"
        SCRIPT_DIR="$2/prog"; CONF_DIR="$2/widgetdeck"; STATE_FILE="$2/state"; H="$2"
        eval "$3"
        migrate_run || die "migration failed"' _ "$SCRIPT_DIR" "$d" "$extra" > "$d/out" 2>&1
}
break_conf='echo broken > "$1/config.json"; exit 1'

run_case ok 'echo "{\"schema\":0,\"mine\":1,\"new\":2}" > "$1/config.json"' ''
check "migration works" '[ $? = 0 ] && [ "$(jq .new "$T/ok/widgetdeck/config.json")" = 2 ]'
check "backup next to the settings folder" 'ls -d "$T"/ok/widgetdeck.bak-* >/dev/null 2>&1'

run_case fail "$break_conf" ''
check "failed migration restores the settings" '[ "$(jq .mine "$T/fail/widgetdeck/config.json")" = 1 ] && [ -f "$T/fail/widgetdeck/widgets.json" ]'

run_case nobackup "$break_conf" 'cp() { return 1; }'
check "no backup: nothing is migrated or deleted" '[ "$(jq .mine "$T/nobackup/widgetdeck/config.json")" = 1 ] && [ -f "$T/nobackup/widgetdeck/widgets.json" ]'

run_case norestore "$break_conf" 'cp() { case "$2" in *.bak-*/.) return 1 ;; esac; command cp "$@"; }'
check "failed restore: folder and backup are both still there" '[ -f "$T/norestore/widgetdeck/widgets.json" ] && [ "$(cat "$T"/norestore/widgetdeck.bak-*/widgets.json)" = layout ]'

mkdir -p "$T/link/dotfiles"; echo '{"schema":0,"mine":1}' > "$T/link/dotfiles/config.json"; ln -s dotfiles "$T/link/widgetdeck"
run_case link "$break_conf" ''
check "symlinked settings folder: restored, link kept" '[ -L "$T/link/widgetdeck" ] && [ "$(jq .mine "$T/link/dotfiles/config.json")" = 1 ]'

[ "$fails" = 0 ] && echo "all migration tests passed" || echo "$fails failed"
[ "$fails" = 0 ]
