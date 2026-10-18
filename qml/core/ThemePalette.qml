// GENERATED from matugen/ROLES - one animated colour per Material role.
// ThemeStore assigns the targets; the Behavior makes every consumer fade smoothly (no flicker, no restart).
import QtQuick

QtObject {
    id: pal
    property bool animate: false
    property int duration: 700
    readonly property var roles: ["primary", "on_primary", "primary_container", "on_primary_container", "secondary", "on_secondary", "secondary_container", "on_secondary_container", "tertiary", "on_tertiary", "tertiary_container", "on_tertiary_container", "error", "on_error", "error_container", "on_error_container", "background", "on_background", "surface", "on_surface", "surface_variant", "on_surface_variant", "outline", "outline_variant", "shadow", "scrim", "inverse_surface", "inverse_on_surface", "inverse_primary", "surface_dim", "surface_bright", "surface_container_lowest", "surface_container_low", "surface_container", "surface_container_high", "surface_container_highest", "surface_tint"]

    property color primary: "#aac7ff"
    Behavior on primary { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color on_primary: "#0b305f"
    Behavior on on_primary { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color primary_container: "#284777"
    Behavior on primary_container { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color on_primary_container: "#d7e3ff"
    Behavior on on_primary_container { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color secondary: "#bec6dc"
    Behavior on secondary { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color on_secondary: "#283141"
    Behavior on on_secondary { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color secondary_container: "#3e4759"
    Behavior on secondary_container { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color on_secondary_container: "#dae2f9"
    Behavior on on_secondary_container { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color tertiary: "#ddbce0"
    Behavior on tertiary { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color on_tertiary: "#3f2844"
    Behavior on on_tertiary { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color tertiary_container: "#573e5c"
    Behavior on tertiary_container { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color on_tertiary_container: "#fad8fd"
    Behavior on on_tertiary_container { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color error: "#ffb4ab"
    Behavior on error { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color on_error: "#690005"
    Behavior on on_error { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color error_container: "#93000a"
    Behavior on error_container { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color on_error_container: "#ffdad6"
    Behavior on on_error_container { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color background: "#111318"
    Behavior on background { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color on_background: "#e2e2e9"
    Behavior on on_background { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color surface: "#111318"
    Behavior on surface { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color on_surface: "#e2e2e9"
    Behavior on on_surface { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color surface_variant: "#44474e"
    Behavior on surface_variant { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color on_surface_variant: "#c4c6d0"
    Behavior on on_surface_variant { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color outline: "#8e9099"
    Behavior on outline { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color outline_variant: "#44474e"
    Behavior on outline_variant { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color shadow: "#000000"
    Behavior on shadow { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color scrim: "#000000"
    Behavior on scrim { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color inverse_surface: "#e2e2e9"
    Behavior on inverse_surface { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color inverse_on_surface: "#2e3036"
    Behavior on inverse_on_surface { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color inverse_primary: "#415f91"
    Behavior on inverse_primary { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color surface_dim: "#111318"
    Behavior on surface_dim { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color surface_bright: "#37393e"
    Behavior on surface_bright { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color surface_container_lowest: "#0c0e13"
    Behavior on surface_container_lowest { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color surface_container_low: "#191c20"
    Behavior on surface_container_low { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color surface_container: "#1e2025"
    Behavior on surface_container { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color surface_container_high: "#282a2f"
    Behavior on surface_container_high { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color surface_container_highest: "#33353a"
    Behavior on surface_container_highest { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
    property color surface_tint: "#aac7ff"
    Behavior on surface_tint { enabled: pal.animate; ColorAnimation { duration: pal.duration; easing.type: Easing.OutCubic } }
}
