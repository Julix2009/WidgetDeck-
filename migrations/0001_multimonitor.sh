#!/usr/bin/env bash
# Several monitors: adds the "monitors" settings (main monitor, what unplugged monitors do, bar, notifications) to config.json.
# The LAYOUT (widgets.json) is converted by the program itself on its first start (it needs to know the monitors): a timestamped
# backup widgets.json.v<old>-backup-<date> is written first, positions do not change, widgets stay on the main monitor.
set -euo pipefail
conf="$1"
. "$(dirname "$0")/lib.sh"
merge_defaults "$conf/config.json" '{ "monitors": { "primary": "", "unplugged": "wait", "cross_edge": false, "notify": "focused", "bar": "all" } }'
