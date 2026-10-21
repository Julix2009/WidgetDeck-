#!/usr/bin/env bash
# sync.sh: copy qml/ into the nested session (Quickshell reloads by itself; restart.sh restarts the shell)
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=env.sh
. "$HERE/env.sh"
cp -a "$REPO/qml/." "$Q/"
