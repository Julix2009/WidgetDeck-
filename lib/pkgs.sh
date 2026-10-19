# shellcheck shell=bash
# Package handling of install.sh. Every package below is in the OFFICIAL Arch repositories (checked with pacman -Si);
# nothing needs the AUR. The code path for an AUR-only package exists anyway and never installs anything without asking.
#
# why each package (checked against the code):
#   quickshell            the shell runtime (QML, layer-shell windows, IPC, notifications, tray)
#   qt6-declarative       QtQuick / Effects / Shapes
#   qt6-wayland           Qt's Wayland platform plugin
#   qt6-shadertools       qsb: compiles the Liquid Glass shaders
#   jq curl iproute2 iputils   data widgets (network, weather, air quality, system status) and the config handling
#   adwaita-fonts         "Adwaita Sans", the preferred UI font (without it the next installed font is used: Inter, Cantarell, Noto Sans ...)
#   networkmanager        nmcli: Wi-Fi name / signal in the network widget (optional)
#   playerctl             skip direction in the music widget (optional)
#   cava                  the audio visualizer widget (optional)
#   matugen               colours that follow the wallpaper (optional; without it the fixed default palette is used)
# Icons are drawn by WidgetDeck itself (qml/core/Icons.js): no icon font and no icon theme is needed.
PKGS_REQUIRED=(quickshell qt6-declarative qt6-wayland qt6-shadertools jq curl iproute2 iputils)
PKGS_RECOMMENDED=(adwaita-fonts)
PKGS_OPTIONAL=(networkmanager playerctl cava matugen)
declare -A PKG_WHY=(
    [quickshell]="shell runtime" [qt6-declarative]="QtQuick" [qt6-wayland]="Wayland plugin for Qt" [qt6-shadertools]="qsb (Liquid Glass shaders)"
    [jq]="JSON in the data widgets and config" [curl]="weather / air quality" [iproute2]="network widget (ip)" [iputils]="network widget (ping)"
    [adwaita-fonts]="preferred UI font"
    [networkmanager]="Wi-Fi name and signal (nmcli)" [playerctl]="music widget: skip direction" [cava]="visualizer widget" [matugen]="colours from the wallpaper"
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
    if [ "${#m_req[@]}" = 0 ]; then ok "$(t 'Required packages are installed')"; else warn "$(t 'Required packages are missing: %s' "${m_req[*]}")"; fi
    [ "${#m_rec[@]}" -gt 0 ] && warn "$(t 'Recommended packages are missing: %s' "${m_rec[*]}")"
    [ "${#m_opt[@]}" -gt 0 ] && info "$(t 'Optional packages are missing: %s' "${m_opt[*]}")"
    local want=() aur=()
    if [ "${#m_req[@]}" -gt 0 ]; then
        for p in "${m_req[@]}"; do info "  $p - $(t "${PKG_WHY[$p]:-}")"; done
        ask "$(t 'Install the required packages now (sudo pacman -S --needed)?')" y && want+=("${m_req[@]}")
    fi
    if [ "${#m_rec[@]}" -gt 0 ]; then
        for p in "${m_rec[@]}"; do info "  $p - $(t "${PKG_WHY[$p]:-}")"; done
        ask "$(t 'Install the recommended packages (font)?')" y && want+=("${m_rec[@]}")
    fi
    if [ "${#m_opt[@]}" -gt 0 ]; then
        for p in "${m_opt[@]}"; do info "  $p - $(t "${PKG_WHY[$p]:-}")"; done
        ask "$(t 'Install the optional packages (each one enables a widget or feature)?')" n && want+=("${m_opt[@]}")
    fi
    local repo=()
    for p in "${want[@]}"; do if in_repos "$p"; then repo+=("$p"); else aur+=("$p"); fi; done
    if [ "${#aur[@]}" -gt 0 ]; then
        warn "$(t 'AUR packages (NOT installed automatically): %s' "${aur[*]}")"
        info "$(t 'Install them yourself with your AUR helper if you want them.')"
    fi
    if [ "${#repo[@]}" -gt 0 ]; then
        local opts=(--needed); [ "$ASSUME_YES" = 1 ] && opts+=(--noconfirm)
        if [ "$(id -u)" = 0 ]; then run pacman -S "${opts[@]}" "${repo[@]}"
        elif command -v sudo >/dev/null 2>&1; then run sudo pacman -S "${opts[@]}" "${repo[@]}"
        else warn "$(t 'sudo not found. Run yourself:  pacman -S --needed %s' "${repo[*]}")"; fi
    fi
    # re-check what is REQUIRED (not in dry-run: nothing was installed)
    if [ "$DRY_RUN" = 0 ]; then
        mapfile -t m_req < <(missing "${PKGS_REQUIRED[@]}")
        if [ "${#m_req[@]}" -gt 0 ]; then warn "$(t 'Still missing: %s' "${m_req[*]}")"; return 1; fi
    fi
    return 0
}
