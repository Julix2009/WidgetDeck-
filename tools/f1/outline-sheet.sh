#!/usr/bin/env bash
# outline-sheet.sh <calendar.json> <out.png>: overview picture of the track outlines of a calendar (output of `f1.py fetch`), rendered offscreen
set -euo pipefail
here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
cal="$(realpath "$1")"; out="$(realpath -m "$2")"
tmp="$(mktemp "$here/.sheet-XXXXXX.qml")"; trap 'rm -f "$tmp"' EXIT
sed -e "s|@CAL@|$cal|" -e "s|@OUT@|$out|" "$here/outline-sheet.qml" > "$tmp"
QML_XHR_ALLOW_FILE_READ=1 QT_FORCE_STDERR_LOGGING=1 QT_QPA_PLATFORM=offscreen timeout 60 /usr/lib/qt6/bin/qml "$tmp"
