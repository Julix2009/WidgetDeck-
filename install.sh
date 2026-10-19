#!/usr/bin/env bash
# WidgetDeck installer (Arch Linux + Hyprland + Quickshell).
#   git clone https://github.com/Julix2009/WidgetDeck-.git && cd WidgetDeck- && ./install.sh
# Running it again is an update: program files are replaced, YOUR settings (layout, glass sliders, location) are never touched.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/pkgs.sh
. "$SCRIPT_DIR/lib/pkgs.sh"
# shellcheck source=lib/hypr.sh
. "$SCRIPT_DIR/lib/hypr.sh"
# shellcheck source=lib/migrate.sh
. "$SCRIPT_DIR/lib/migrate.sh"

VERSION="$(tr -d '[:space:]' < "$SCRIPT_DIR/VERSION" 2>/dev/null || echo 0.0.0)"
TESTED_HYPR="0.55.4"; TESTED_QS="0.3.0"
UPDATE_MODE=0; PREFIX=""; CHANNEL=""; NO_HYPR=0; NO_PACKAGES=0; DO_UNINSTALL=0; PURGE=0; MODULES_OPT=""

usage() {
    cat <<USAGE
WidgetDeck $VERSION - $(t 'installer')

  ./install.sh [$(t 'options')]

  --dry-run          $(t 'show what would happen (changes nothing)')
  --yes, -y          $(t 'no questions (default answers; the Hyprland include line is added)')
  --modules <list>   $(t 'what to install and switch on: widgets,builder,bar,notifications (default: widgets,builder)')
  --no-hypr-config   $(t 'do not touch your Hyprland config (only show what to add)')
  --no-packages      $(t 'skip the package check / installation')
  --prefix <path>    $(t 'test installation: <path> replaces your home (config, cache, program, Hyprland files live below it)')
  --channel <c>      $(t 'update channel: main (default, newest tested state) or stable (tagged releases only)')
  --uninstall        $(t 'remove what was installed (see also uninstall.sh)')
  --purge            $(t '(with --uninstall) also delete your settings and the cache')
  --help             $(t 'this help')

$(t 'Installs to'):   ~/.config/quickshell/widgetdeck   ($(t 'program, replaced on updates; start: qs -c widgetdeck'))
                    ~/.local/bin/widgetdeck, widgetdeck-update, widgetdeck-doctor
$(t 'Your settings'): ~/.config/widgetdeck/             ($(t 'never overwritten'))
Log:                ~/.cache/widgetdeck/install.log
USAGE
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --yes|-y) ASSUME_YES=1 ;;
        --no-hypr-config) NO_HYPR=1 ;;
        --no-packages) NO_PACKAGES=1 ;;
        --update) UPDATE_MODE=1 ;;
        --modules) shift; [ $# -gt 0 ] || die "$(t '--modules needs a list, e.g. widgets,builder,bar')"; MODULES_OPT="$1" ;;
        --modules=*) MODULES_OPT="${1#--modules=}" ;;
        --prefix) shift; [ $# -gt 0 ] || die "$(t '--prefix needs a path')"; PREFIX="$1" ;;
        --prefix=*) PREFIX="${1#--prefix=}" ;;
        --channel) shift; [ $# -gt 0 ] || die "$(t '--channel needs main or stable')"; CHANNEL="$1" ;;
        --channel=*) CHANNEL="${1#--channel=}" ;;
        --uninstall) DO_UNINSTALL=1 ;;
        --purge) PURGE=1 ;;
        --help|-h) usage; exit 0 ;;
        --version) echo "$VERSION"; exit 0 ;;
        *) usage >&2; die "$(t 'unknown option: %s' "$1")" ;;
    esac
    shift
done

# ---------------------------------------------------------------- locations
if [ -n "$PREFIX" ]; then H="$(realpath -m -- "$PREFIX")"; else H="${HOME:?HOME is not set}"; fi
wd_paths "$H" "$PREFIX"
LOG_FILE="$CACHE_DIR/install.log"

case "$CHANNEL" in ""|main|stable) ;; *) die "$(t '--channel: expected main or stable, not %s' "$CHANNEL")" ;; esac
if [ "$DRY_RUN" = 0 ]; then mkdir -p "$CACHE_DIR"; : >> "$LOG_FILE"; else LOG_FILE=""; fi
_log "== install.sh $VERSION $* (H=$H) =="

# ---------------------------------------------------------------- checks
check_system() {
    step "$(t 'Checking the system')"
    if [ -f /etc/arch-release ] || grep -qiE '^(ID|ID_LIKE)=.*arch' /etc/os-release 2>/dev/null; then ok "$(t 'Arch Linux (or a derivative)')"
    else die "$(t 'This installer is for Arch Linux only (/etc/arch-release is missing).')"; fi
    if [ "$(id -u)" = 0 ]; then die "$(t 'Please do not run this as root. It asks for sudo itself when needed (only for pacman).')"; fi

    local hv qv qt
    if command -v Hyprland >/dev/null 2>&1 || command -v hyprctl >/dev/null 2>&1; then
        hv="$(hypr_version)"
        ok "Hyprland ${hv:-$(t '(version unknown)')}"
        if [ -n "$hv" ]; then
            if [ "$(vercmp "$hv" "$HYPR_MIN")" = -1 ]; then
                die "$(t 'Hyprland %s is too old (minimum %s). Update Hyprland (pacman -Syu) or use --no-hypr-config and set the rules up by hand.' "$hv" "$HYPR_MIN")"; fi
            if [ "$(vercmp "$hv" "$HYPR_LEGACY_BELOW")" = -1 ]; then warn "$(t 'Hyprland %s is older than %s: the rules are written in the old syntax (untested).' "$hv" "$HYPR_LEGACY_BELOW")"; fi
            if [ "$(vercmp "$hv" "$TESTED_HYPR")" = 1 ]; then info "$(t 'Hyprland %s is newer than the tested version %s - it should work.' "$hv" "$TESTED_HYPR")"; fi
        fi
    elif [ "$NO_HYPR" = 1 ]; then warn "$(t 'Hyprland not found (--no-hypr-config: continuing).')"
    else die "$(t 'Hyprland is not installed (pacman -S hyprland). With --no-hypr-config you can continue anyway.')"; fi

    if command -v quickshell >/dev/null 2>&1; then
        qv="$(ver_of "$(quickshell --version 2>/dev/null | head -n1)")"
        if [ -n "$qv" ] && [ "$(vercmp "$qv" 0.2.0)" = -1 ]; then warn "$(t 'Quickshell %s is older than 0.2.0 - WidgetDeck needs a newer version.' "$qv")"
        else ok "$(t 'Quickshell %s (tested: %s)' "${qv:-?}" "$TESTED_QS")"; fi
    else warn "$(t 'Quickshell is not installed yet (offered below).')"; fi
    if pacman -Q qt6-declarative >/dev/null 2>&1; then
        qt="$(ver_of "$(pacman -Q qt6-declarative | cut -d' ' -f2)")"
        if [ -n "$qt" ] && [ "$(vercmp "$qt" 6.7.0)" = -1 ]; then warn "$(t 'Qt %s is older than 6.7: the blur and path renderers need 6.7+.' "$qt")"; else ok "Qt (qt6-declarative) $qt"; fi
    fi
    [ "$UPDATE_MODE" = 1 ] && return 0
    # other bars / widget tools / notification daemons: only a hint, nothing is stopped
    local c found=()
    for c in waybar eww ags astal-shell hyprpanel conky dunst mako swaync; do
        if pgrep -x "$c" >/dev/null 2>&1 || pacman -Q "$c" >/dev/null 2>&1; then found+=("$c"); fi
    done
    if [ "${#found[@]}" -gt 0 ]; then
        warn "$(t 'Found: %s. WidgetDeck only draws desktop widgets (bottom layer) unless you switch on its bar or notification module; widgets of eww/ags/conky can overlap visually. Nothing is stopped or disabled.' "${found[*]}")"
    fi
    return 0
}

# ---------------------------------------------------------------- modules
# MOD_<name>=1/0; MODULES_TOUCH=1 when the config has to be written. Asks only on a fresh install (or with --modules).
MOD_widgets=1; MOD_builder=1; MOD_bar=0; MOD_notifications=0; MODULES_TOUCH=0
module_conflict() {   # module_conflict <bar|notifications>: prints what it would replace
    bash "$SCRIPT_DIR/qml/modules/conflicts.sh" "$1" 2>/dev/null || true
}
decide_modules() {
    local m list c
    if [ -n "$MODULES_OPT" ]; then
        MODULES_TOUCH=1; MOD_widgets=0; MOD_builder=0; MOD_bar=0; MOD_notifications=0
        IFS=',' read -ra list <<< "$MODULES_OPT"
        for m in "${list[@]}"; do
            case "$m" in
                widgets|builder|bar|notifications) printf -v "MOD_$m" '%s' 1 ;;
                none) ;;
                *) die "$(t 'unknown module: %s (widgets, builder, bar, notifications)' "$m")" ;;
            esac
        done
    elif [ "$UPDATE_MODE" = 0 ] && [ ! -e "$CONF_DIR/config.json" ]; then
        MODULES_TOUCH=1
        step "$(t 'Modules')"
        info "$(t 'WidgetDeck consists of parts; install only what you want. You can switch them later in the builder settings.')"
        info "$(t '(Other UI parts from the author dotfiles are not part of this repository: no free licence.)')"
        ask "$(t 'Widgets (weather, network, sensors, system, air quality, music)?')" y || MOD_widgets=0
        ask "$(t 'Widget builder and snap grid (the editor)?')" y || MOD_builder=0
        if ask "$(t 'Bar (a slim top bar with workspaces, clock, tray)? It would sit next to or replace your current bar.')" n; then MOD_bar=1; fi
        if ask "$(t 'Notifications and power menu? It replaces your notification daemon.')" n; then MOD_notifications=1; fi
    fi
    [ "$MODULES_TOUCH" = 1 ] || return 0
    for m in bar notifications; do
        [ "$(eval "echo \$MOD_$m")" = 1 ] || continue
        c="$(module_conflict "$m")"
        if [ -n "$c" ]; then
            warn "$(t 'The module %s would collide with:' "$m")"; printf '%s\n' "$c" | sed 's/^/         | /'
            if [ "$m" = bar ]; then info "$(t 'WidgetDeck does not stop it. Turn the other bar off first (e.g. remove it from your Hyprland autostart), or both will be visible.')"
            else info "$(t 'Only one program can own the notification service. WidgetDeck does not stop the other one: disable it first (e.g. systemctl --user disable --now <name>, or remove it from your autostart).')"; fi
            if [ -z "$MODULES_OPT" ] && ! ask "$(t 'Switch the %s module on anyway?' "$m")" n; then printf -v "MOD_$m" '%s' 0; info "$(t 'Left off. Switch it on later in the builder settings.')"; fi
        fi
    done
    ok "$(t 'Modules: widgets=%s builder=%s bar=%s notifications=%s' "$MOD_widgets" "$MOD_builder" "$MOD_bar" "$MOD_notifications")"
}
modules_json() {
    jq -nc --argjson w "$MOD_widgets" --argjson b "$MOD_builder" --argjson r "$MOD_bar" --argjson n "$MOD_notifications" \
        '{widgets: ($w == 1), builder: ($b == 1), bar: ($r == 1), notifications: ($n == 1)}'
}

# ---------------------------------------------------------------- program files
install_files() {
    step "$(t 'Program files')"
    [ -f "$SCRIPT_DIR/qml/shell.qml" ] || die "$(t 'qml/shell.qml is missing - is the script running from the repository?')"
    local tmp="$QML_DEST.new.$$"
    if [ -d "$QML_DEST" ]; then info "$(t 'updating the existing installation: %s' "$QML_DEST")"; fi
    run mkdir -p "$(dirname "$QML_DEST")"
    run rm -rf "$tmp"
    run cp -a "$SCRIPT_DIR/qml" "$tmp"
    if [ "$DRY_RUN" = 0 ]; then
        printf '%s\n' "$VERSION" > "$tmp/VERSION"; chmod +x "$tmp"/widgets/sysmon/*.sh "$tmp"/core/*.sh "$tmp"/modules/*.sh
        # where updates come from (read by widgetdeck-update and the update hint in the settings)
        local url="" rev=""
        if command -v git >/dev/null 2>&1 && git -C "$SCRIPT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
            url="$(git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null || true)"; rev="$(git -C "$SCRIPT_DIR" rev-parse HEAD 2>/dev/null || true)"
        fi
        printf 'url=%s\nrepo=%s\nupdater=%s\n' "$url" "$SCRIPT_DIR" "$UPD_DEST" > "$tmp/SOURCE"
        printf '%s\n' "$rev" > "$tmp/REV"
        state_set REPO_DIR "$SCRIPT_DIR"; state_set REMOTE_URL "$url"; state_set INSTALLED_REV "$rev"
    fi
    if [ -d "$QML_DEST" ] && [ "$DRY_RUN" = 0 ]; then rm -rf "$QML_DEST.old.$$"; mv "$QML_DEST" "$QML_DEST.old.$$"; fi
    run mv "$tmp" "$QML_DEST"
    [ "$DRY_RUN" = 0 ] && rm -rf "$QML_DEST.old.$$"
    ok "$(t 'Program: %s' "$QML_DEST")"
    run install -Dm755 "$SCRIPT_DIR/bin/widgetdeck" "$BIN_DEST"
    ok "$(t 'Launcher: %s' "$BIN_DEST")"
    run install -Dm755 "$SCRIPT_DIR/bin/widgetdeck-update" "$UPD_DEST"
    run install -Dm755 "$SCRIPT_DIR/bin/widgetdeck-doctor" "$DOC_DEST"
    ok "$(t 'Update and check commands: %s, %s' "$UPD_DEST" "$DOC_DEST")"
    case ":$PATH:" in *":$BIN_DIR:"*) ;; *) [ "$UPDATE_MODE" = 1 ] || warn "$(t '%s is not in your PATH. Add it to your shell config (e.g. export PATH="$HOME/.local/bin:$PATH").' "$BIN_DIR")" ;; esac
    state_set QML_DEST "$QML_DEST"; state_set BIN_DEST "$BIN_DEST"; state_set UPD_DEST "$UPD_DEST"; state_set DOC_DEST "$DOC_DEST"; state_set VERSION "$VERSION"

    # your settings: created only where nothing exists yet
    run mkdir -p "$CONF_DIR"
    if [ ! -e "$CONF_DIR/config.json" ]; then
        if [ "$DRY_RUN" = 1 ]; then printf '  [dry-run] %s\n' "$(t 'would create %s' "$CONF_DIR/config.json")"
        else
            # the location question is asked by the first-run assistant (with the privacy note); nothing is looked up before that
            jq -n --argjson schema "$(migrate_latest)" --arg ch "${CHANNEL:-main}" --argjson mods "$(modules_json)" \
                '{schema: $schema, setup: {done: false}, location: {auto: true, lat: null, lon: null, name: ""}, units: "auto", time_format: "auto", language: "auto", modules: $mods, update: {check: true, channel: $ch}}' > "$CONF_DIR/config.json"
            ok "$(t 'Starter settings: %s (the first-run assistant asks the rest)' "$CONF_DIR/config.json")"
        fi
    else
        ok "$(t 'Your existing settings stay unchanged (%s)' "$CONF_DIR")"
        if [ "$DRY_RUN" = 0 ]; then
            local tf
            if [ -n "$CHANNEL" ]; then tf="$(mktemp "$CONF_DIR/config.json.XXXXXX")"; jq --arg ch "$CHANNEL" '.update.channel = $ch' "$CONF_DIR/config.json" > "$tf" && mv "$tf" "$CONF_DIR/config.json" && ok "$(t 'Update channel: %s' "$CHANNEL")"; fi
            if [ "$MODULES_TOUCH" = 1 ]; then
                tf="$(mktemp "$CONF_DIR/config.json.XXXXXX")"
                jq --argjson m "$(modules_json)" '.modules = $m' "$CONF_DIR/config.json" > "$tf" && mv "$tf" "$CONF_DIR/config.json" && ok "$(t 'Modules saved in your settings')"
            fi
        fi
    fi
    if [ "$DRY_RUN" = 0 ]; then migrate_run || die "$(t 'Migration failed; your settings were restored from the backup. The program files are already replaced: widgetdeck-update restores them automatically; otherwise: ./update.sh --rollback.')"; else migrate_run; fi
}

# ---------------------------------------------------------------- shaders
build_shaders() {
    step "$(t 'Compiling the Liquid Glass shaders')"
    local q="" c
    for c in qsb qsb6 qsb-qt6 /usr/lib/qt6/bin/qsb /usr/lib64/qt6/bin/qsb; do command -v "$c" >/dev/null 2>&1 && { q="$c"; break; }; done
    if [ -z "$q" ]; then warn "$(t 'qsb not found (pacman -S qt6-shadertools). Liquid Glass falls back to Frosted Glass until it is installed.')"; return 0; fi
    local f built=0
    for f in glass drops; do
        if [ "$DRY_RUN" = 1 ]; then printf '  [dry-run] %s --qt6 -o %s/%s.frag.qsb %s/core/%s.frag\n' "$q" "$CACHE_DIR" "$f" "$QML_DEST" "$f"; built=$((built + 1)); continue; fi
        if "$q" --qt6 -o "$CACHE_DIR/$f.frag.qsb" "$QML_DEST/core/$f.frag" >> "$LOG_FILE" 2>&1; then
            cp -f "$CACHE_DIR/$f.frag.qsb" "$QML_DEST/core/$f.frag.qsb"     # fallback copy next to the source (used when qsb is missing later)
            built=$((built + 1))
        else warn "$(t 'Shader %s.frag did not compile (see the log). Liquid Glass falls back to Frosted Glass.' "$f")"; fi
    done
    [ "$built" = 2 ] && ok "$(t 'Shaders compiled (glass.frag, drops.frag)')"
    return 0
}

# ---------------------------------------------------------------- matugen (optional)
matugen_setup() {
    local tpl="$MATUGEN_DIR/templates/widgetdeck-theme.json.template" toml="$MATUGEN_DIR/config.toml"
    if ! command -v matugen >/dev/null 2>&1; then info "$(t 'matugen is not installed: WidgetDeck uses its fixed default palette (optional: pacman -S matugen).')"; return 0; fi
    step "$(t 'Matugen (colours from the wallpaper)')"
    run install -Dm644 "$SCRIPT_DIR/matugen/widgetdeck-theme.json.template" "$tpl"
    state_set MATUGEN_TEMPLATE "$tpl"
    if [ -f "$toml" ] && grep -q 'widgetdeck-theme.json' "$toml"; then ok "$(t 'matugen already knows the WidgetDeck template')"; return 0; fi
    local block
    block="$(printf '# >>> widgetdeck (install.sh) >>>\n[templates.widgetdeck]\ninput_path = "%s"\noutput_path = "%s/theme.json"\n# <<< widgetdeck <<<\n' "$tpl" "$CONF_DIR")"
    if [ -f "$toml" ]; then
        say "  $(t 'I would append this block to %s:' "$toml")"; printf '%s\n' "$block" | sed 's/^/  | /'
        if ask "$(t 'Add it to the matugen config (a backup is made)?')" y; then
            local bak="$toml.widgetdeck-backup-$(stamp)"
            if [ "$DRY_RUN" = 1 ]; then printf '  [dry-run] %s\n' "$(t 'backup %s, append the block' "$bak")"; else
                cp -p "$toml" "$bak"; { printf '\n'; printf '%s\n' "$block"; } >> "$toml"
                state_set MATUGEN_TOML "$toml"; state_set MATUGEN_BACKUP "$bak"; ok "$(t 'matugen config extended (backup: %s)' "$bak")"; fi
        else info "$(t 'Not added. Without this block matugen does not write a WidgetDeck palette.')"; fi
    else
        info "$(t 'No %s found. Create it yourself or add this block to your matugen config:' "$toml")"; printf '%s\n' "$block" | sed 's/^/  | /'
    fi
}

# ---------------------------------------------------------------- uninstall
do_uninstall() {
    step "$(t 'Removing WidgetDeck')"
    [ -f "$STATE_FILE" ] || warn "$(t 'No installation data found (%s) - removing the default locations.' "$STATE_FILE")"
    local qml bin tpl upd doc
    qml="$(state_get QML_DEST)"; qml="${qml:-$QML_DEST}"; bin="$(state_get BIN_DEST)"; bin="${bin:-$BIN_DEST}"
    # stop the daemon first
    if [ -x "$bin" ] && [ "$DRY_RUN" = 0 ]; then HOME="$H" "$bin" stop >/dev/null 2>&1 || true; fi
    if [ -d "$qml" ]; then run rm -rf "$qml"; ok "$(t 'removed: %s' "$qml")"; else info "$(t 'not present: %s' "$qml")"; fi
    if [ -f "$bin" ]; then run rm -f "$bin"; ok "$(t 'removed: %s' "$bin")"; fi
    upd="$(state_get UPD_DEST)"; upd="${upd:-$UPD_DEST}"
    if [ -f "$upd" ]; then run rm -f "$upd"; ok "$(t 'removed: %s' "$upd")"; fi
    doc="$(state_get DOC_DEST)"; doc="${doc:-$DOC_DEST}"
    if [ -f "$doc" ]; then run rm -f "$doc"; ok "$(t 'removed: %s' "$doc")"; fi
    tpl="$(state_get MATUGEN_TEMPLATE)"
    if [ -n "$tpl" ] && [ -f "$tpl" ]; then run rm -f "$tpl"; ok "$(t 'removed: %s' "$tpl")"; fi
    local toml bak
    toml="$(state_get MATUGEN_TOML)"; bak="$(state_get MATUGEN_BACKUP)"
    if [ -n "$toml" ] && [ -f "$toml" ] && grep -qF "$HYPR_MARK_BEGIN" "$toml"; then
        if [ "$DRY_RUN" = 0 ]; then local t; t="$(mktemp)"; sed "/$HYPR_MARK_BEGIN/,/$HYPR_MARK_END/d" "$toml" > "$t" && cat "$t" > "$toml"; rm -f "$t"; else printf '  [dry-run] %s\n' "$(t 'remove the block from %s' "$toml")"; fi
        ok "$(t 'WidgetDeck block removed from the matugen config (backup stays: %s)' "${bak:-none}")"
    fi
    hypr_remove
    if [ -d "$CONF_DIR" ]; then
        if [ "$PURGE" = 1 ] || ask "$(t 'Also delete YOUR settings (%s: layout, glass sliders, location)?' "$CONF_DIR")" n; then
            run rm -rf "$CONF_DIR"; ok "$(t 'Settings deleted')"
        else ok "$(t 'your settings stay: %s' "$CONF_DIR")"; fi
    fi
    if [ "$PURGE" = 1 ] && [ "$DRY_RUN" = 0 ]; then rm -rf "$CACHE_DIR"; else info "$(t 'Cache and log stay: %s (--purge deletes them)' "$CACHE_DIR")"; fi
    say ""; say "$(t 'Done. Backups ending in .widgetdeck-backup-* next to your configs can be deleted when everything is fine.')"
}

# ---------------------------------------------------------------- main
if [ "$DO_UNINSTALL" = 1 ]; then
    do_uninstall
    exit 0
fi

say "${C_B}WidgetDeck $VERSION${C_0}  -  $(t 'installing to %s' "$H")$([ "$DRY_RUN" = 1 ] && echo "  ($(t '--dry-run: nothing is changed'))")"
check_system
if [ "$NO_PACKAGES" = 1 ]; then step "$(t 'Packages')"; info "$(t 'skipped (--no-packages)')"; else
    step "$(t 'Packages')"
    install_packages || die "$(t 'Required packages are missing. Install them (pacman -S --needed %s) and run the script again.' "${PKGS_REQUIRED[*]}")"
fi
decide_modules
install_files
build_shaders
matugen_setup
step "Hyprland"
hypr_apply
if [ "$UPDATE_MODE" = 1 ]; then
    ok "$(t 'Program files are current (version %s)' "$VERSION")"
else
    step "$(t 'Done')"
    say "  $(t 'Start:          widgetdeck daemon (or run "hyprctl reload": the autostart line starts it at the next login)')"
    say "  $(t 'First start:    the setup assistant opens once (wallpaper, location, units, style, widgets)')"
    say "  $(t 'Editor:         widgetdeck builder')"
    say "  $(t 'Check:          widgetdeck-doctor   (copy its output into a GitHub issue)')"
    say "  $(t 'Update later:   widgetdeck-update')"
    [ "$DRY_RUN" = 0 ] && say "  Log:            $LOG_FILE"
fi
exit 0
