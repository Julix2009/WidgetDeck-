#!/usr/bin/env bash
# WidgetDeck uninstall: removes only what install.sh installed, asks before deleting your settings and rolls back the Hyprland change.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
exec "$SCRIPT_DIR/install.sh" --uninstall "$@"
