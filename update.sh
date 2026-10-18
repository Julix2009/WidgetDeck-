#!/usr/bin/env bash
# WidgetDeck update: fetches the newest version of the repository and reinstalls the program files.
# Your settings (~/.config/widgetdeck) are never touched. All options of install.sh work here too (--dry-run, --yes, ...).
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$SCRIPT_DIR"

if [ -d .git ] && command -v git >/dev/null 2>&1; then
    printf 'Hole die neueste Version ...\n'
    if ! git pull --ff-only; then
        printf '[FEHLER] git pull ging nicht glatt (lokale Änderungen im Ordner?). Prüfe: git status\n' >&2
        exit 1
    fi
else
    printf '[warn] %s ist kein Git-Klon - es wird nur neu installiert, was hier liegt.\n' "$SCRIPT_DIR" >&2
fi
exec "$SCRIPT_DIR/install.sh" "$@"
