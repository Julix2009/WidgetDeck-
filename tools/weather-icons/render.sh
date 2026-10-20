#!/usr/bin/env bash
# Renders the weather icon sprites (layers) of the "Weather card" widget into qml/widgets/weathercard/icons/.
# Each part (sun, cloud, drop, ...) is described in parts.json and drawn by soft3d.frag (a small SDF ray marcher: soft, clay-like 3D objects,
# lit from the top left, with ambient occlusion and a highlight) through a Qt Quick window; the result is saved as a PNG with alpha.
# The widget only displays these PNGs - nothing is rendered at run time. Needs: qsb + qml6 (qt6-shadertools, qt6-declarative) and a graphical session,
# plus ImageMagick (magick) for the soft glow and shadow sprites. Own work, MIT; nothing here is copied from anywhere.
#   usage: tools/weather-icons/render.sh [size]        (default 320 px per sprite)
set -euo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
OUT="$HERE/../../qml/widgets/weathercard/icons"
SIZE="${1:-320}"
QSB=""; for q in qsb qsb6 qsb-qt6 /usr/lib/qt6/bin/qsb /usr/lib64/qt6/bin/qsb; do command -v "$q" >/dev/null 2>&1 && { QSB="$q"; break; }; done
[ -n "$QSB" ] || { echo "qsb not found (pacman -S qt6-shadertools)" >&2; exit 1; }
command -v qml6 >/dev/null 2>&1 || { echo "qml6 not found (pacman -S qt6-declarative)" >&2; exit 1; }
command -v magick >/dev/null 2>&1 || { echo "magick not found (pacman -S imagemagick)" >&2; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "jq not found (pacman -S jq)" >&2; exit 1; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT"
"$QSB" --qt6 -o "$TMP/soft3d.frag.qsb" "$HERE/soft3d.frag"
export QML_XHR_ALLOW_FILE_READ=1
for name in $(jq -r 'keys[]' "$HERE/parts.json"); do
    jq -c --arg n "$name" '.[$n]' "$HERE/parts.json" > "$TMP/$name.json"
    timeout 60 qml6 "$HERE/render.qml" -- "$TMP/$name.json" "$TMP/$name.png" "$SIZE" "$TMP/soft3d.frag.qsb" >/dev/null 2>&1 || true
    [ -s "$TMP/$name.png" ] || { echo "render failed: $name" >&2; exit 1; }
    magick "$TMP/$name.png" -strip -define png:compression-level=9 "$OUT/$name.png"
    echo "ok $name"
done
# soft sprites made with ImageMagick: the warm glow behind the sun / moon and the shadow below an icon (both pure alpha gradients)
magick -size "$SIZE"x"$SIZE" radial-gradient:'rgba(255,214,120,0.60)-rgba(255,214,120,0)' -strip "$OUT/glow.png"
magick -size "$SIZE"x$((SIZE / 3)) radial-gradient:'rgba(8,12,24,0.42)-rgba(8,12,24,0)' -strip "$OUT/shadow.png"
echo "icons written to $OUT"
