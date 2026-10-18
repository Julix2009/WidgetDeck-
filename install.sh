#!/usr/bin/env bash
# WidgetDeck installer (Arch Linux + Hyprland + Quickshell).
#   git clone https://github.com/<user>/widgetdeck && cd widgetdeck && ./install.sh
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
UPDATE_MODE=0; PREFIX=""; CHANNEL=""; NO_HYPR=0; NO_PACKAGES=0; DO_UNINSTALL=0; PURGE=0

usage() {
    cat <<USAGE
WidgetDeck $VERSION - Installer

  ./install.sh [Optionen]

  --dry-run          zeigt nur, was passieren würde (ändert nichts)
  --yes, -y          keine Rückfragen (Standardantworten; Hyprland-Verweis wird eingetragen)
  --no-hypr-config   fasst die Hyprland-Config nicht an (zeigt nur, was einzutragen wäre)
  --no-packages      überspringt die Paketprüfung / Installation
  --prefix <Pfad>    Test-Installation: <Pfad> ersetzt dein Home (Config, Cache, Programm, Hyprland-Dateien liegen darunter)
  --channel <c>      Update-Kanal: main (Standard, immer der neueste Stand) oder stable (nur getaggte Releases)
  --uninstall        entfernt, was installiert wurde (siehe auch uninstall.sh)
  --purge            (mit --uninstall) löscht auch deine Einstellungen und den Cache
  --help             diese Hilfe

Installiert nach:   ~/.config/quickshell/widgetdeck   (Programm, wird bei Updates ersetzt)
                    ~/.local/bin/widgetdeck            (Starter)
Deine Einstellungen: ~/.config/widgetdeck/             (wird nie überschrieben)
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
        --prefix) shift; [ $# -gt 0 ] || die "--prefix braucht einen Pfad"; PREFIX="$1" ;;
        --prefix=*) PREFIX="${1#--prefix=}" ;;
        --channel) shift; [ $# -gt 0 ] || die "--channel braucht main oder stable"; CHANNEL="$1" ;;
        --channel=*) CHANNEL="${1#--channel=}" ;;
        --uninstall) DO_UNINSTALL=1 ;;
        --purge) PURGE=1 ;;
        --help|-h) usage; exit 0 ;;
        --version) echo "$VERSION"; exit 0 ;;
        *) usage >&2; die "unbekannte Option: $1" ;;
    esac
    shift
done

# ---------------------------------------------------------------- locations
if [ -n "$PREFIX" ]; then H="$(realpath -m -- "$PREFIX")"; else H="${HOME:?HOME ist nicht gesetzt}"; fi
QML_DEST="$H/.config/quickshell/widgetdeck"
BIN_DIR="$H/.local/bin"
BIN_DEST="$BIN_DIR/widgetdeck"
UPD_DEST="$BIN_DIR/widgetdeck-update"
CONF_DIR="$H/.config/widgetdeck"
CACHE_DIR="$H/.cache/widgetdeck"
MATUGEN_DIR="$H/.config/matugen"
STATE_FILE="$CACHE_DIR/install-state"
LOG_FILE="$CACHE_DIR/install.log"

case "$CHANNEL" in ""|main|stable) ;; *) die "--channel: main oder stable erwartet, nicht '$CHANNEL'" ;; esac
if [ "$DRY_RUN" = 0 ]; then mkdir -p "$CACHE_DIR"; : >> "$LOG_FILE"; else LOG_FILE=""; fi
_log "== install.sh $VERSION $* (H=$H) =="

# ---------------------------------------------------------------- checks
check_system() {
    step "System prüfen"
    if [ -f /etc/arch-release ] || grep -qiE '^(ID|ID_LIKE)=.*arch' /etc/os-release 2>/dev/null; then ok "Arch Linux (oder Derivat)"; else die "Dieses Skript ist nur für Arch Linux gedacht (/etc/arch-release fehlt)."; fi
    if [ "$(id -u)" = 0 ]; then die "Bitte nicht als root ausführen. Das Skript fragt bei Bedarf selbst nach sudo (nur für pacman)."; fi

    local hv qv qt
    if command -v Hyprland >/dev/null 2>&1 || command -v hyprctl >/dev/null 2>&1; then
        hv="$(hypr_version)"
        ok "Hyprland ${hv:-(Version unbekannt)}"
        if [ -n "$hv" ]; then
            if [ "$(vercmp "$hv" 0.53.0)" = -1 ]; then warn "Hyprland $hv ist älter als 0.53: die Regeln werden in der alten Syntax geschrieben (nicht getestet)."; fi
            if [ "$(vercmp "$hv" "$TESTED_HYPR")" = 1 ]; then info "Hyprland $hv ist neuer als die getestete Version $TESTED_HYPR - sollte funktionieren."; fi
        fi
    elif [ "$NO_HYPR" = 1 ]; then warn "Hyprland nicht gefunden (--no-hypr-config: wird übergangen)."
    else die "Hyprland ist nicht installiert (pacman -S hyprland). Mit --no-hypr-config kannst du trotzdem fortfahren."; fi

    if command -v quickshell >/dev/null 2>&1; then
        qv="$(ver_of "$(quickshell --version 2>/dev/null | head -n1)")"
        if [ -n "$qv" ] && [ "$(vercmp "$qv" 0.2.0)" = -1 ]; then warn "Quickshell $qv ist älter als 0.2.0 - WidgetDeck braucht eine neuere Version."
        else ok "Quickshell ${qv:-?} (getestet: $TESTED_QS)"; fi
    else warn "Quickshell ist noch nicht installiert (wird unten angeboten)."; fi
    if pacman -Q qt6-declarative >/dev/null 2>&1; then
        qt="$(ver_of "$(pacman -Q qt6-declarative | cut -d' ' -f2)")"
        if [ -n "$qt" ] && [ "$(vercmp "$qt" 6.7.0)" = -1 ]; then warn "Qt $qt ist älter als 6.7: der Weichzeichner und die Pfad-Renderer brauchen 6.7+."; else ok "Qt (qt6-declarative) $qt"; fi
    fi
    # other bars / widget tools / notification daemons: only a hint, nothing is stopped (not repeated on updates)
    [ "$UPDATE_MODE" = 1 ] && return 0
    local c found=()
    for c in waybar eww ags astal-shell conky dunst mako swaync; do
        if pgrep -x "$c" >/dev/null 2>&1 || pacman -Q "$c" >/dev/null 2>&1; then found+=("$c"); fi
    done
    if [ "${#found[@]}" -gt 0 ]; then warn "Gefunden: ${found[*]}. WidgetDeck zeichnet nur Desktop-Widgets (Bottom-Layer) und braucht keine Bar oder Benachrichtigungen; eww/ags/conky-Widgets können sich aber optisch überlappen. Es wird nichts beendet."; fi
}

# ---------------------------------------------------------------- program files
install_files() {
    step "Programmdateien"
    [ -f "$SCRIPT_DIR/qml/shell.qml" ] || die "qml/shell.qml fehlt - läuft das Skript aus dem Repository?"
    local tmp="$QML_DEST.new.$$"
    if [ -d "$QML_DEST" ]; then info "vorhandene Installation wird aktualisiert: $QML_DEST"; fi
    run mkdir -p "$(dirname "$QML_DEST")"
    run rm -rf "$tmp"
    run cp -a "$SCRIPT_DIR/qml" "$tmp"
    if [ "$DRY_RUN" = 0 ]; then
        printf '%s\n' "$VERSION" > "$tmp/VERSION"; chmod +x "$tmp"/widgets/sysmon/*.sh "$tmp"/core/*.sh
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
    ok "Programm: $QML_DEST"
    run install -Dm755 "$SCRIPT_DIR/bin/widgetdeck" "$BIN_DEST"
    ok "Starter: $BIN_DEST"
    run install -Dm755 "$SCRIPT_DIR/bin/widgetdeck-update" "$UPD_DEST"
    ok "Update-Befehl: $UPD_DEST   (holt später neue Versionen)"
    case ":$PATH:" in *":$BIN_DIR:"*) ;; *) [ "$UPDATE_MODE" = 1 ] || warn "$BIN_DIR ist nicht in deinem PATH. Füge es in deine Shell-Config ein (z. B. export PATH=\"\$HOME/.local/bin:\$PATH\")." ;; esac
    state_set QML_DEST "$QML_DEST"; state_set BIN_DEST "$BIN_DEST"; state_set UPD_DEST "$UPD_DEST"; state_set VERSION "$VERSION"

    # your settings: created only where nothing exists yet
    run mkdir -p "$CONF_DIR"
    if [ ! -e "$CONF_DIR/config.json" ]; then
        if [ "$DRY_RUN" = 1 ]; then printf '  [dry-run] würde %s/config.json anlegen\n' "$CONF_DIR"
        else
            local auto=false
            info "Wetter und Luftqualität brauchen einen Standort. Er kann einmalig per IP-Adresse (Dienst ipwho.is, Ergebnis 7 Tage lokal gespeichert)"
            info "bestimmt werden - oder du trägst später Breite/Länge im Builder ein (Einstellungen > Standort). Es werden keine Zugangsdaten benötigt."
            ask "Standort automatisch per IP bestimmen?" y && auto=true
            jq -n --argjson auto "$auto" --argjson schema "$(migrate_latest)" --arg ch "${CHANNEL:-main}" \
                '{schema: $schema, location: {auto: $auto, lat: null, lon: null, name: ""}, units: "auto", language: "auto", update: {check: true, channel: $ch}}' > "$CONF_DIR/config.json"
            ok "Beispiel-Einstellungen: $CONF_DIR/config.json (Standort automatisch: $auto)"
        fi
    else
        ok "vorhandene Einstellungen bleiben unverändert ($CONF_DIR)"
        if [ -n "$CHANNEL" ] && [ "$DRY_RUN" = 0 ]; then
            local t; t="$(mktemp "$CONF_DIR/config.json.XXXXXX")"
            jq --arg ch "$CHANNEL" '.update.channel = $ch' "$CONF_DIR/config.json" > "$t" && mv "$t" "$CONF_DIR/config.json" && ok "Update-Kanal: $CHANNEL"
        fi
    fi
    if [ "$DRY_RUN" = 0 ]; then migrate_run || die "Migration fehlgeschlagen; deine Einstellungen wurden aus dem Backup zurückgespielt. Die Programmdateien sind schon ersetzt: widgetdeck-update stellt sie automatisch zurück; sonst: ./update.sh --rollback."; else migrate_run; fi
}

# ---------------------------------------------------------------- shaders
build_shaders() {
    step "Liquid-Glass-Shader kompilieren"
    local q="" c
    for c in qsb qsb6 qsb-qt6 /usr/lib/qt6/bin/qsb /usr/lib64/qt6/bin/qsb; do command -v "$c" >/dev/null 2>&1 && { q="$c"; break; }; done
    if [ -z "$q" ]; then warn "qsb nicht gefunden (pacman -S qt6-shadertools). Liquid Glass fällt auf Frosted Glass zurück, bis es installiert ist."; return 0; fi
    local f built=0
    for f in glass drops; do
        if [ "$DRY_RUN" = 1 ]; then printf '  [dry-run] %s --qt6 -o %s/%s.frag.qsb %s/core/%s.frag\n' "$q" "$CACHE_DIR" "$f" "$QML_DEST" "$f"; built=$((built + 1)); continue; fi
        if "$q" --qt6 -o "$CACHE_DIR/$f.frag.qsb" "$QML_DEST/core/$f.frag" >> "$LOG_FILE" 2>&1; then
            cp -f "$CACHE_DIR/$f.frag.qsb" "$QML_DEST/core/$f.frag.qsb"     # fallback copy next to the source (used when qsb is missing later)
            built=$((built + 1))
        else warn "Shader $f.frag ließ sich nicht kompilieren (Details im Log). Liquid Glass fällt auf Frosted Glass zurück."; fi
    done
    [ "$built" = 2 ] && ok "Shader kompiliert (glass.frag, drops.frag)"
    return 0
}

# ---------------------------------------------------------------- matugen (optional)
matugen_setup() {
    local tpl="$MATUGEN_DIR/templates/widgetdeck-theme.json.template" toml="$MATUGEN_DIR/config.toml"
    if ! command -v matugen >/dev/null 2>&1 && [ ! -d "$MATUGEN_DIR" ]; then info "matugen nicht installiert: WidgetDeck nutzt die eingebaute Farbpalette (optional: pacman -S matugen)."; return 0; fi
    step "Matugen (Farben aus dem Wallpaper)"
    run install -Dm644 "$SCRIPT_DIR/matugen/widgetdeck-theme.json.template" "$tpl"
    state_set MATUGEN_TEMPLATE "$tpl"
    if [ -f "$toml" ] && grep -q 'widgetdeck-theme.json' "$toml"; then ok "matugen kennt die WidgetDeck-Vorlage bereits"; return 0; fi
    local block
    block="$(printf '# >>> widgetdeck (install.sh) >>>\n[templates.widgetdeck]\ninput_path = "%s"\noutput_path = "%s/theme.json"\n# <<< widgetdeck <<<\n' "$tpl" "$CONF_DIR")"
    if [ -f "$toml" ]; then
        say "  Diesen Block würde ich an $toml anhängen:"; printf '%s\n' "$block" | sed 's/^/  | /'
        if ask "In die matugen-Config eintragen (Backup wird angelegt)?" y; then
            local bak="$toml.widgetdeck-backup-$(stamp)"
            if [ "$DRY_RUN" = 1 ]; then printf '  [dry-run] Backup %s, Block anhängen\n' "$bak"; else
                cp -p "$toml" "$bak"; { printf '\n'; printf '%s\n' "$block"; } >> "$toml"
                state_set MATUGEN_TOML "$toml"; state_set MATUGEN_BACKUP "$bak"; ok "matugen-Config ergänzt (Backup: $bak)"; fi
        else info "Nicht eingetragen. Ohne diesen Block erzeugt matugen keine WidgetDeck-Palette."; fi
    else
        info "Keine $toml gefunden. Lege sie selbst an oder füge diesen Block in deine matugen-Config ein:"; printf '%s\n' "$block" | sed 's/^/  | /'
    fi
}

# ---------------------------------------------------------------- uninstall
do_uninstall() {
    step "WidgetDeck entfernen"
    [ -f "$STATE_FILE" ] || warn "Keine Installationsdaten gefunden ($STATE_FILE) - entferne die Standardorte."
    local qml bin tpl
    qml="$(state_get QML_DEST)"; qml="${qml:-$QML_DEST}"; bin="$(state_get BIN_DEST)"; bin="${bin:-$BIN_DEST}"
    # stop the daemon first
    if [ -x "$bin" ] && [ "$DRY_RUN" = 0 ]; then "$bin" stop >/dev/null 2>&1 || true; fi
    [ -d "$qml" ] && { run rm -rf "$qml"; ok "entfernt: $qml"; } || info "nicht vorhanden: $qml"
    [ -f "$bin" ] && { run rm -f "$bin"; ok "entfernt: $bin"; }
    local upd; upd="$(state_get UPD_DEST)"; upd="${upd:-$UPD_DEST}"
    [ -f "$upd" ] && { run rm -f "$upd"; ok "entfernt: $upd"; }
    tpl="$(state_get MATUGEN_TEMPLATE)"
    [ -n "$tpl" ] && [ -f "$tpl" ] && { run rm -f "$tpl"; ok "entfernt: $tpl"; }
    local toml bak
    toml="$(state_get MATUGEN_TOML)"; bak="$(state_get MATUGEN_BACKUP)"
    if [ -n "$toml" ] && [ -f "$toml" ] && grep -qF "$HYPR_MARK_BEGIN" "$toml"; then
        if [ "$DRY_RUN" = 0 ]; then local t; t="$(mktemp)"; sed "/$HYPR_MARK_BEGIN/,/$HYPR_MARK_END/d" "$toml" > "$t" && cat "$t" > "$toml"; rm -f "$t"; else printf '  [dry-run] Block aus %s entfernen\n' "$toml"; fi
        ok "WidgetDeck-Block aus der matugen-Config entfernt (Backup bleibt: ${bak:-keins})"
    fi
    hypr_remove
    if [ -d "$CONF_DIR" ]; then
        if [ "$PURGE" = 1 ] || ask "Auch DEINE Einstellungen löschen ($CONF_DIR: Layout, Glas-Regler, Standort)?" n; then
            run rm -rf "$CONF_DIR"; ok "Einstellungen gelöscht"
        else ok "deine Einstellungen bleiben: $CONF_DIR"; fi
    fi
    if [ "$PURGE" = 1 ] && [ "$DRY_RUN" = 0 ]; then rm -rf "$CACHE_DIR"; else info "Cache und Log bleiben: $CACHE_DIR (--purge löscht sie)"; fi
    say ""; say "Fertig. Backups mit der Endung .widgetdeck-backup-* neben deinen Configs kannst du löschen, wenn alles passt."
}

# ---------------------------------------------------------------- main
if [ "$DO_UNINSTALL" = 1 ]; then
    do_uninstall
    exit 0
fi

say "${C_B}WidgetDeck $VERSION${C_0}  -  Installation nach $H$([ "$DRY_RUN" = 1 ] && echo '  (--dry-run: es wird nichts geändert)')"
check_system
if [ "$NO_PACKAGES" = 1 ]; then step "Pakete"; info "übersprungen (--no-packages)"; else
    step "Pakete"
    install_packages || die "Pflichtpakete fehlen. Installiere sie (pacman -S --needed ${PKGS_REQUIRED[*]}) und starte das Skript erneut."
fi
install_files
build_shaders
matugen_setup
step "Hyprland"
hypr_apply
if [ "$UPDATE_MODE" = 1 ]; then
    ok "Programmdateien sind aktuell (Version $VERSION)"
else
    step "Fertig"
    say "  Starten:        widgetdeck builder      (öffnet den Editor; beim ersten Start entsteht ein Standard-Layout)"
    say "  Prüfen:         widgetdeck doctor"
    say "  Update später:  widgetdeck-update       (oder im Builder: Einstellungen > Version & Updates)"
    [ "$DRY_RUN" = 0 ] && say "  Log:            $LOG_FILE"
fi
exit 0
