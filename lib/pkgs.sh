# shellcheck shell=bash
# Package handling of install.sh. Every package below is in the OFFICIAL Arch repositories (checked with pacman -Si);
# nothing needs the AUR. The code path for an AUR-only package exists anyway and never installs anything without asking.
#
# why each package (checked against the code):
#   quickshell            the shell runtime (QML, layer-shell windows, IPC)
#   qt6-declarative       QtQuick / Effects / Shapes
#   qt6-wayland           Qt's Wayland platform plugin
#   qt6-shadertools       qsb: compiles the Liquid Glass shaders
#   jq curl iproute2 iputils   data widgets (network, weather, air quality, system status)
#   adwaita-fonts         "Adwaita Sans", the default widget font
#   ttf-iosevka-nerd      "Iosevka Nerd Font": the icons inside the widgets
#   networkmanager        nmcli: Wi-Fi name / signal in the network widget (optional)
#   playerctl             media keys / skip direction in the music widget (optional)
#   cava                  the audio visualizer widget (optional)
#   matugen               colours that follow the wallpaper (optional)
PKGS_REQUIRED=(quickshell qt6-declarative qt6-wayland qt6-shadertools jq curl iproute2 iputils)
PKGS_RECOMMENDED=(adwaita-fonts ttf-iosevka-nerd)
PKGS_OPTIONAL=(networkmanager playerctl cava matugen)
declare -A PKG_WHY=(
    [quickshell]="Shell-Laufzeit" [qt6-declarative]="QtQuick" [qt6-wayland]="Wayland-Plugin für Qt" [qt6-shadertools]="qsb (Liquid-Glass-Shader)"
    [jq]="JSON in den Daten-Widgets" [curl]="Wetter / Luftqualität" [iproute2]="Netzwerk-Widget (ip)" [iputils]="Netzwerk-Widget (ping)"
    [adwaita-fonts]="Standardschrift" [ttf-iosevka-nerd]="Icons in den Widgets"
    [networkmanager]="WLAN-Name und Signal (nmcli)" [playerctl]="Musik-Widget: Tasten und Richtung" [cava]="Visualizer-Widget" [matugen]="Farben aus dem Wallpaper"
)

# missing <pkg...>: prints the packages that are NOT installed (provides are honoured: quickshell-git satisfies quickshell)
missing() { pacman -T "$@" 2>/dev/null || true; }
in_repos() { pacman -Si "$1" >/dev/null 2>&1; }

# the package step: returns 0 when everything REQUIRED is (or becomes) available
install_packages() {
    local m_req m_rec m_opt p
    mapfile -t m_req < <(missing "${PKGS_REQUIRED[@]}")
    mapfile -t m_rec < <(missing "${PKGS_RECOMMENDED[@]}")
    mapfile -t m_opt < <(missing "${PKGS_OPTIONAL[@]}")
    if [ "${#m_req[@]}" = 0 ]; then ok "Pflichtpakete vorhanden"; else warn "Pflichtpakete fehlen: ${m_req[*]}"; fi
    [ "${#m_rec[@]}" -gt 0 ] && warn "empfohlene Pakete fehlen: ${m_rec[*]}"
    [ "${#m_opt[@]}" -gt 0 ] && info "optionale Pakete fehlen: ${m_opt[*]}"
    local want=() aur=()
    if [ "${#m_req[@]}" -gt 0 ]; then
        for p in "${m_req[@]}"; do info "  $p - ${PKG_WHY[$p]:-}"; done
        ask "Pflichtpakete jetzt installieren (sudo pacman -S --needed)?" y && want+=("${m_req[@]}")
    fi
    if [ "${#m_rec[@]}" -gt 0 ]; then
        for p in "${m_rec[@]}"; do info "  $p - ${PKG_WHY[$p]:-}"; done
        ask "empfohlene Pakete (Schrift und Icons) installieren?" y && want+=("${m_rec[@]}")
    fi
    if [ "${#m_opt[@]}" -gt 0 ]; then
        for p in "${m_opt[@]}"; do info "  $p - ${PKG_WHY[$p]:-}"; done
        ask "optionale Pakete installieren (jedes schaltet ein Widget bzw. eine Funktion frei)?" n && want+=("${m_opt[@]}")
    fi
    local repo=()
    for p in "${want[@]}"; do if in_repos "$p"; then repo+=("$p"); else aur+=("$p"); fi; done
    if [ "${#aur[@]}" -gt 0 ]; then
        warn "AUR-Pakete (werden NICHT automatisch installiert): ${aur[*]}"
        info "Installiere sie selbst mit deinem AUR-Helper, wenn du sie willst."
    fi
    if [ "${#repo[@]}" -gt 0 ]; then
        local opts=(--needed); [ "$ASSUME_YES" = 1 ] && opts+=(--noconfirm)
        if [ "$(id -u)" = 0 ]; then run pacman -S "${opts[@]}" "${repo[@]}"
        elif command -v sudo >/dev/null 2>&1; then run sudo pacman -S "${opts[@]}" "${repo[@]}"
        else warn "kein sudo gefunden. Führe selbst aus:  pacman -S --needed ${repo[*]}"; fi
    fi
    # re-check what is REQUIRED (not in dry-run: nothing was installed)
    if [ "$DRY_RUN" = 0 ]; then
        mapfile -t m_req < <(missing "${PKGS_REQUIRED[@]}")
        if [ "${#m_req[@]}" -gt 0 ]; then warn "weiterhin fehlend: ${m_req[*]}"; return 1; fi
    fi
    return 0
}
