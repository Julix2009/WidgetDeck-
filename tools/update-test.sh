#!/usr/bin/env bash
# What update.sh says after a failed install, with a stub install.sh in temporary clones (never touches the real installation): bash tools/update-test.sh
set -u
REPO="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fails=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1"; cat "$T"/*/out | tail -n 8; fails=$((fails + 1)); fi; }
g() { git -c user.name=t -c user.email=t@example.invalid -c init.defaultBranch=main "$@"; }

# run_case <name> <what the OLD install.sh does> <installed rev known: yes|no>: the new version's install.sh always fails
run_case() {
    local d="$T/$1" old="$2" known="$3" rev
    mkdir -p "$d/src/lib" "$d/user/.cache/widgetdeck"
    cp "$REPO/update.sh" "$d/src/"; cp "$REPO"/lib/*.sh "$d/src/lib/"
    printf '#!/bin/sh\n%s\n' "$old" > "$d/src/install.sh"; chmod +x "$d/src/install.sh"; echo 1.0.0 > "$d/src/VERSION"
    g -C "$d/src" init -q; g -C "$d/src" add -A; g -C "$d/src" commit -qm old
    g clone -q "$d/src" "$d/clone"; rev="$(git -C "$d/clone" rev-parse HEAD)"
    printf '#!/bin/sh\nexit 1\n' > "$d/src/install.sh"; echo 2.0.0 > "$d/src/VERSION"; g -C "$d/src" commit -qam new
    [ "$known" = yes ] && printf 'INSTALLED_REV=%s\n' "$rev" > "$d/user/.cache/widgetdeck/install-state"
    WIDGETDECK_LANG=en bash "$d/clone/update.sh" --yes --no-packages --no-restart --prefix "$d/user" > "$d/out" 2>&1
}
said() { grep -q -- "$2" "$T/$1/out"; }
kept() { grep -q '^PREV_REV=.' "$T/$1/user/.cache/widgetdeck/install-state"; }

run_case restored 'exit 0' yes
check "old version restored: says so" 'said restored "old version is back in place"'
run_case broken 'exit 1' yes
check "restore fails: does not claim it" '! said broken "is back in place" && said broken "could NOT be restored"'
check "restore fails: --rollback stays possible" 'kept broken'
run_case unknown 'exit 0' no
check "installed version unknown: says nothing was rolled back" '! said unknown "is back in place" && said unknown "nothing was rolled back"'

[ "$fails" = 0 ] && echo "all update tests passed" || echo "$fails failed"
[ "$fails" = 0 ]
