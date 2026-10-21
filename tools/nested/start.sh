#!/usr/bin/env bash
# start.sh: create the session home (first time) and start the nested Hyprland; its window opens on workspace 9
set -euo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=env.sh
. "$HERE/env.sh"
if [ ! -d "$N/.config/hypr" ]; then
    mkdir -p "$N/.config/hypr" "$N/.config/quickshell/widgetdeck" "$N/.config/widgetdeck" "$N/.cache" "$N/.local/bin"
    cat > "$N/.config/hypr/hyprland.conf" <<CONF
monitor = , preferred, auto, 1
ecosystem { no_update_news = true; no_donation_nag = true }
misc { disable_hyprland_logo = true; disable_splash_rendering = true; force_default_wallpaper = 0 }
exec-once = quickshell -p $N/.config/quickshell/widgetdeck
layerrule {
    name = widgetdeck_layers
    match:namespace = ^widgetdeck\$
    blur = on
    ignore_alpha = 0.22
    no_anim = on
}
windowrule {
    name = widgetdeck_builder
    match:title = ^WidgetDeck\$
    float = on
    center = on
    size = 1500 920
    rounding = 30
    border_size = 0
}
CONF
    cp -a "$REPO/qml/." "$N/.config/quickshell/widgetdeck/"
    printf '{"setup":{"done":true},"location":{"auto":false,"lat":10,"lon":10,"name":"Testville"},"units":"auto","time_format":"auto","language":"auto","modules":{"widgets":true,"builder":true,"bar":false,"notifications":false},"update":{"check":false,"channel":"main"}}\n' > "$N/.config/widgetdeck/config.json"
fi
ws0="$(hyprctl activeworkspace -j | jq .id)"
hyprctl dispatch workspace 9 >/dev/null; sleep 0.5
(cd "$N" && env -u HYPRLAND_INSTANCE_SIGNATURE HOME="$N" XDG_CONFIG_HOME="$N/.config" XDG_CACHE_HOME="$N/.cache" PATH="$N/.local/bin:$PATH" LANG="${NLANG:-en_US.UTF-8}" setsid dbus-run-session -- Hyprland -c "$N/.config/hypr/hyprland.conf" > "$N/hypr.out" 2>&1 &)
sleep 9
hyprctl dispatch workspace "$ws0" >/dev/null
