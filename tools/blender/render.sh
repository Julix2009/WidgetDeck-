#!/usr/bin/env bash
# Renders the weather card icons with Blender (only needed to REGENERATE them - the finished sprites are in the repository).
#   tools/blender/render.sh [--quick] [--only rain,clear_day] [--size 512] [--samples 48] ...      (see render_icons.py)
# Needs: blender (pacman -S blender; ~380 MiB installed plus dependencies), ImageMagick or cwebp for the WebP files.
set -euo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
BLENDER="${BLENDER:-blender}"      # BLENDER=/path/to/wrapper if blender is installed somewhere unusual
command -v "$BLENDER" >/dev/null 2>&1 || { echo "blender not found (pacman -S blender, or set BLENDER=...)" >&2; exit 1; }
exec "$BLENDER" --background --factory-startup --python "$HERE/render_icons.py" -- "$@"
