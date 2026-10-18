#!/usr/bin/env bash
# WidgetDeck update (normally started through `widgetdeck-update`).
#   ./update.sh [--yes] [--dry-run] [--channel main|stable] [--version vX.Y.Z] [--rollback]
# Only PROGRAM files are replaced. Everything in ~/.config/widgetdeck stays as it is (format changes are handled by migrations/, with a backup).
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
# shellcheck source=lib/changelog.sh
. "$SCRIPT_DIR/lib/changelog.sh"

usage() {
    cat <<USAGE
WidgetDeck - Update

  widgetdeck-update [Optionen]      (oder ./update.sh im geklonten Ordner)

  --yes, -y            keine Rückfragen (Änderungen an lokalen Dateien werden gesichert, Pakete nach Standardantwort)
  --dry-run            zeigt nur, was passieren würde (holt dafür den Remote-Stand, ändert aber nichts)
  --channel main|stable  main = immer der neueste Stand (Standard), stable = nur getaggte Releases (wird gemerkt)
  --version vX.Y.Z     eine bestimmte Version installieren
  --rollback           zurück auf die Version vor dem letzten Update (samt Einstellungs-Backup)
  --no-packages        Paketprüfung überspringen
  --no-restart         die Widgets nicht neu starten
  --prefix <Pfad>      Test: <Pfad> ersetzt dein Home
  --help
USAGE
}

PREFIX=""; CHANNEL_OPT=""; VERSION_OPT=""; ROLLBACK=0; NO_PACKAGES=0; NO_RESTART=0

main() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run) DRY_RUN=1 ;;
            --yes|-y) ASSUME_YES=1 ;;
            --channel) shift; [ $# -gt 0 ] || die "--channel braucht main oder stable"; CHANNEL_OPT="$1" ;;
            --channel=*) CHANNEL_OPT="${1#--channel=}" ;;
            --version) shift; [ $# -gt 0 ] || die "--version braucht eine Version, z. B. v0.2.0"; VERSION_OPT="$1" ;;
            --version=*) VERSION_OPT="${1#--version=}" ;;
            --rollback) ROLLBACK=1 ;;
            --no-packages) NO_PACKAGES=1 ;;
            --no-restart) NO_RESTART=1 ;;
            --prefix) shift; [ $# -gt 0 ] || die "--prefix braucht einen Pfad"; PREFIX="$1" ;;
            --prefix=*) PREFIX="${1#--prefix=}" ;;
            --help|-h) usage; exit 0 ;;
            *) usage >&2; die "unbekannte Option: $1" ;;
        esac
        shift
    done
    case "$CHANNEL_OPT" in ""|main|stable) ;; *) die "--channel: main oder stable erwartet, nicht '$CHANNEL_OPT'" ;; esac

    if [ -n "$PREFIX" ]; then H="$(realpath -m -- "$PREFIX")"; else H="${HOME:?HOME ist nicht gesetzt}"; fi
    CONF_DIR="$H/.config/widgetdeck"; CACHE_DIR="$H/.cache/widgetdeck"; QML_DEST="$H/.config/quickshell/widgetdeck"
    BIN_DEST="$H/.local/bin/widgetdeck"
    STATE_FILE="$CACHE_DIR/install-state"; LOG_FILE=""
    if [ "$DRY_RUN" = 0 ]; then mkdir -p "$CACHE_DIR"; LOG_FILE="$CACHE_DIR/install.log"; : >> "$LOG_FILE"; fi
    _log "== update.sh $* (H=$H) =="
    if [ "$DRY_RUN" = 0 ]; then       # two updates at the same time would corrupt each other
        exec 9> "$CACHE_DIR/update.lock"
        flock -n 9 || die "Es läuft bereits ein Update (oder ein zweiter Aufruf gleichzeitig). Bitte warten."
    fi

    command -v git >/dev/null 2>&1 || die "git fehlt (pacman -S git)."
    git -C "$SCRIPT_DIR" rev-parse --git-dir >/dev/null 2>&1 || die "$SCRIPT_DIR ist kein Git-Klon - ein Update ist nur in einem geklonten Ordner möglich."

    local cur_ver cur_rev
    cur_ver="$(tr -d '[:space:]' < "$QML_DEST/VERSION" 2>/dev/null || true)"; cur_ver="${cur_ver:-0.0.0}"
    cur_rev="$(state_get INSTALLED_REV)"; [ -n "$cur_rev" ] || cur_rev="$(tr -d '[:space:]' < "$QML_DEST/REV" 2>/dev/null || true)"

    say "${C_B}WidgetDeck-Update${C_0}  -  installiert: ${cur_ver}${cur_rev:+ (${cur_rev:0:7})}$([ "$DRY_RUN" = 1 ] && echo '  (--dry-run)')"

    if [ "$ROLLBACK" = 1 ]; then do_rollback; return; fi

    # ---------------------------------------------------------------- channel
    local channel="$CHANNEL_OPT"
    if [ -z "$channel" ]; then channel="$(jq -r '.update.channel // "main"' "$CONF_DIR/config.json" 2>/dev/null || echo main)"; fi
    case "$channel" in main|stable) ;; *) channel=main ;; esac
    if [ -n "$CHANNEL_OPT" ] && [ "$DRY_RUN" = 0 ] && [ -f "$CONF_DIR/config.json" ]; then
        local t; t="$(mktemp "$CONF_DIR/config.json.XXXXXX")"
        jq --arg ch "$CHANNEL_OPT" '.update.channel = $ch' "$CONF_DIR/config.json" > "$t" && mv "$t" "$CONF_DIR/config.json"
    fi

    # ---------------------------------------------------------------- fetch
    step "Remote-Stand holen (Kanal: $channel)"
    if ! gitnet fetch --tags --prune origin >> "${LOG_FILE:-/dev/null}" 2>&1; then
        warn "Das Repository ist nicht erreichbar (kein Netz, oder kein Zugriff auf ein privates Repo). Es wurde nichts verändert."
        exit 1
    fi
    ok "Remote-Stand geholt"

    # ---------------------------------------------------------------- target
    local ref target_rev target_ver default_branch
    default_branch="$(git -C "$SCRIPT_DIR" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || true)"; default_branch="${default_branch:-main}"
    if [ -n "$VERSION_OPT" ]; then
        local v="v${VERSION_OPT#v}"
        ref="refs/tags/$v"
        git -C "$SCRIPT_DIR" rev-parse -q --verify "$ref^{commit}" >/dev/null || die "Version $v gibt es nicht. Vorhandene: $(git -C "$SCRIPT_DIR" tag -l 'v[0-9]*' --sort=-v:refname | head -n8 | tr '\n' ' ')"
    elif [ "$channel" = stable ]; then
        local latest; latest="$(git -C "$SCRIPT_DIR" tag -l 'v[0-9]*' --sort=-v:refname | head -n1)"
        [ -n "$latest" ] || die "Es gibt noch kein veröffentlichtes Release (keine Tags v*). Nutze --channel main."
        ref="refs/tags/$latest"
    else
        ref="refs/remotes/origin/$default_branch"
        git -C "$SCRIPT_DIR" rev-parse -q --verify "$ref^{commit}" >/dev/null || die "Branch origin/$default_branch nicht gefunden."
    fi
    target_rev="$(git -C "$SCRIPT_DIR" rev-parse "$ref^{commit}")"
    target_ver="$(git -C "$SCRIPT_DIR" show "$target_rev:VERSION" 2>/dev/null | tr -d '[:space:]' || true)"; target_ver="${target_ver:-?}"

    if [ "$target_rev" = "$cur_rev" ]; then
        ok "Bereits aktuell: Version $cur_ver (${cur_rev:0:7})."
        return 0
    fi
    say ""
    say "  Aktuell:  $cur_ver${cur_rev:+ (${cur_rev:0:7})}"
    say "  Neu:      $target_ver (${target_rev:0:7})   [${VERSION_OPT:+Version $VERSION_OPT}${VERSION_OPT:-Kanal $channel}]"
    if [ "$target_ver" != "?" ] && [ "$(vercmp "$target_ver" "$cur_ver")" = -1 ]; then warn "Die Zielversion ist älter als die installierte (Downgrade)."; fi

    # changelog excerpt since the installed version
    local notes
    notes="$(git -C "$SCRIPT_DIR" show "$target_rev:CHANGELOG.md" 2>/dev/null | changelog_since "$cur_ver" || true)"
    if [ -n "$notes" ]; then
        say ""; say "  Änderungen:"; printf '%s\n' "$notes" | sed -e '/^[[:space:]]*$/d' -e 's/^/    /'
    elif [ -n "$cur_rev" ] && git -C "$SCRIPT_DIR" cat-file -e "$cur_rev^{commit}" 2>/dev/null; then
        say ""; say "  Änderungen (Commits):"; git -C "$SCRIPT_DIR" log --oneline --no-merges -n 15 "$cur_rev..$target_rev" 2>/dev/null | sed 's/^/    /' || true
    fi
    if [ -n "$cur_rev" ] && git -C "$SCRIPT_DIR" cat-file -e "$cur_rev^{commit}" 2>/dev/null; then
        say ""; say "  Geänderte Dateien:"; git -C "$SCRIPT_DIR" diff --stat "$cur_rev" "$target_rev" 2>/dev/null | tail -n 12 | sed 's/^/   /' || true
    fi
    # pending config migrations in the target?
    local cur_schema=0 new_schema=0 f n
    [ -f "$CONF_DIR/config.json" ] && cur_schema="$(jq -r '.schema // 0' "$CONF_DIR/config.json" 2>/dev/null || echo 0)"
    while IFS= read -r f; do n="$(basename "$f")"; n=$((10#${n%%_*})); [ "$n" -gt "$new_schema" ] && new_schema="$n"; done < <(git -C "$SCRIPT_DIR" ls-tree --name-only "$target_rev" migrations/ 2>/dev/null | grep -E '/[0-9]{4}_.*\.sh$' || true)
    if [ "$new_schema" -gt "$cur_schema" ]; then say ""; say "  Deine Einstellungen werden von Schema $cur_schema auf $new_schema migriert (vorher Backup nach ~/.config/widgetdeck.bak-<Datum>)."; fi

    # ---------------------------------------------------------------- local changes
    handle_local_changes "$cur_rev"

    # clone must be able to fast-forward on the main channel
    if [ -z "$VERSION_OPT" ] && [ "$channel" = main ] && git -C "$SCRIPT_DIR" rev-parse -q --verify "refs/heads/$default_branch" >/dev/null; then
        if ! git -C "$SCRIPT_DIR" merge-base --is-ancestor "refs/heads/$default_branch" "$target_rev"; then
            die "Der Klon enthält eigene Commits auf '$default_branch', die nicht im Remote stehen (git log origin/$default_branch..$default_branch). Sichere sie oder nutze --channel stable."
        fi
    fi

    say ""
    if [ "$DRY_RUN" = 1 ]; then
        say "  [dry-run] würde auf $target_ver aktualisieren: Stand auswählen, install.sh ausführen, Widgets neu starten. Es wurde nichts verändert."
        return 0
    fi
    ask "Jetzt auf $target_ver aktualisieren?" y || { say "Abgebrochen. Es wurde nichts verändert."; return 0; }

    # ---------------------------------------------------------------- apply
    state_set PREV_REV "$cur_rev"; state_set PREV_VERSION "$cur_ver"; state_set CONFIG_BACKUP ""
    local was_running=0
    if [ "$NO_RESTART" = 0 ] && [ -x "$BIN_DEST" ] && HOME="$H" "$BIN_DEST" status >/dev/null 2>&1 9>&-; then was_running=1; fi
    if [ "$was_running" = 1 ]; then HOME="$H" "$BIN_DEST" stop >/dev/null 2>&1 9>&- || true; sleep 0.5; fi     # nobody writes the settings during the update

    step "Programmdateien aktualisieren"
    checkout_target "$target_rev" "$default_branch" "$channel"
    if ! run_install; then
        warn "Die Installation der neuen Version ist fehlgeschlagen. Ich stelle die vorherige Version wieder her ..."
        if [ -n "$cur_rev" ]; then
            checkout_detached "$cur_rev"
            local bak; bak="$(state_get CONFIG_BACKUP)"
            [ -n "$bak" ] && [ -d "$bak" ] && { rm -rf "$CONF_DIR"; cp -a "$bak" "$CONF_DIR"; state_set CONFIG_BACKUP ""; }
            run_install || warn "Auch die Wiederherstellung hatte Probleme - siehe $LOG_FILE"
        fi
        [ "$was_running" = 1 ] && restart_shell
        die "Update fehlgeschlagen; die alte Version ist wieder eingespielt. Details: $LOG_FILE"
    fi
    rm -f "$CACHE_DIR/update-check.json"
    state_set LAST_UPDATE "$(date '+%F %T')"
    [ "$was_running" = 1 ] && restart_shell
    step "Fertig"
    say "  WidgetDeck $target_ver ist installiert. Zurück auf die vorige Version: widgetdeck-update --rollback"
}

# ------------------------------------------------------------------ helpers
gitnet() {       # git against the clone: never asks for credentials, bounded time
    GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh} -o BatchMode=yes -o ConnectTimeout=10" \
        timeout 90 git -C "$SCRIPT_DIR" "$@"
}

run_install() {
    local a=("$SCRIPT_DIR/install.sh")
    [ "$ASSUME_YES" = 1 ] && a+=(--yes)
    [ "$NO_PACKAGES" = 1 ] && a+=(--no-packages)
    [ -n "$PREFIX" ] && a+=(--prefix "$PREFIX")
    a+=(--update)
    "${a[@]}"
}

restart_shell() {
    if [ -x "$BIN_DEST" ]; then HOME="$H" "$BIN_DEST" restart >/dev/null 2>&1 9>&- && ok "Widgets neu gestartet" || warn "Neustart ging nicht: starte selbst mit 'widgetdeck restart'"; fi
}

checkout_target() {       # checkout_target <rev> <default branch> <channel>: main channel stays on the branch, tags / versions are detached
    if [ -z "$VERSION_OPT" ] && [ "$3" = main ] && git -C "$SCRIPT_DIR" rev-parse -q --verify "refs/heads/$2" >/dev/null; then
        git -C "$SCRIPT_DIR" checkout -q "$2" && git -C "$SCRIPT_DIR" merge -q --ff-only "$1"
    else
        git -C "$SCRIPT_DIR" checkout -q --detach "$1"
    fi
}
checkout_detached() { git -C "$SCRIPT_DIR" checkout -q --detach "$1"; }

# local modifications of the clone (tracked files) and of the INSTALLED program files
handle_local_changes() {
    local cur_rev="$1" changed stamp_s copy
    stamp_s="$(stamp)"
    changed="$(git -C "$SCRIPT_DIR" status --porcelain --untracked-files=no)"
    if [ -n "$changed" ]; then
        say ""; warn "Im Klon sind Dateien lokal verändert:"
        printf '%s\n' "$changed" | head -n 12 | sed 's/^/    /'
        local choice=1
        if [ "$DRY_RUN" = 1 ]; then say "  [dry-run] würde sie per git stash sichern."
        else
            if [ "$ASSUME_YES" = 0 ]; then
                [ -t 0 ] || die "Lokale Änderungen im Klon und kein Terminal für die Rückfrage. Sichere sie (git stash) oder nutze --yes (sichert per stash)."
                say "  [1] sichern per git stash (später: git stash pop)   [2] Kopie mit Zeitstempel anlegen, dann verwerfen   [3] abbrechen"
                read -r -p "  ? Auswahl [1] " choice || choice=3
                choice="${choice:-1}"
            fi
            case "$choice" in
                1) git -C "$SCRIPT_DIR" stash push -m "widgetdeck-update $stamp_s" >> "${LOG_FILE:-/dev/null}" 2>&1 && ok "Änderungen gesichert (git stash list)" || die "git stash ist fehlgeschlagen." ;;
                2) copy="$CACHE_DIR/local-changes-$stamp_s"; mkdir -p "$copy"
                   git -C "$SCRIPT_DIR" diff HEAD > "$copy/changes.patch"
                   git -C "$SCRIPT_DIR" diff HEAD --name-only | while IFS= read -r f; do [ -f "$SCRIPT_DIR/$f" ] && install -Dm644 "$SCRIPT_DIR/$f" "$copy/files/$f"; done
                   git -C "$SCRIPT_DIR" checkout -q -- . && ok "Kopie: $copy (Patch und Dateien); Änderungen verworfen" ;;
                *) die "Abgebrochen. Es wurde nichts verändert." ;;
            esac
        fi
    fi
    # edited copies in ~/.config/quickshell/widgetdeck
    if [ -n "$cur_rev" ] && [ -d "$QML_DEST" ] && git -C "$SCRIPT_DIR" cat-file -e "$cur_rev^{commit}" 2>/dev/null; then
        local tmp; tmp="$(mktemp -d)"
        if git -C "$SCRIPT_DIR" archive "$cur_rev" qml 2>/dev/null | tar -x -C "$tmp" 2>/dev/null \
           && ! diff -rq -x VERSION -x REV -x SOURCE -x '*.qsb' "$tmp/qml" "$QML_DEST" >/dev/null 2>&1; then
            say ""; warn "Die installierten Programmdateien ($QML_DEST) unterscheiden sich vom Stand der Installation (selbst bearbeitet?)."
            if [ "$DRY_RUN" = 1 ]; then say "  [dry-run] würde eine Kopie unter $CACHE_DIR/program-backup-$stamp_s anlegen."
            else copy="$CACHE_DIR/program-backup-$stamp_s"; cp -a "$QML_DEST" "$copy"; ok "Kopie der bisherigen Programmdateien: $copy (das Update ersetzt sie)"; fi
        fi
        rm -rf "$tmp"
    fi
}

do_rollback() {
    local prev prev_ver bak
    prev="$(state_get PREV_REV)"; prev_ver="$(state_get PREV_VERSION)"; bak="$(state_get CONFIG_BACKUP)"
    [ -n "$prev" ] || die "Es ist keine vorherige Version gespeichert (noch kein Update ausgeführt oder bereits zurückgerollt)."
    git -C "$SCRIPT_DIR" cat-file -e "$prev^{commit}" 2>/dev/null || die "Der vorherige Stand ${prev:0:7} ist im Klon nicht mehr vorhanden."
    say ""; say "  Zurück auf: ${prev_ver:-?} (${prev:0:7})"
    if [ -n "$bak" ] && [ -d "$bak" ]; then say "  Einstellungen: Backup $bak wird zurückgespielt (die jetzigen werden vorher nach ~/.config/widgetdeck.pre-rollback-<Datum> kopiert)."
    else say "  Einstellungen: bleiben unverändert (das letzte Update hat sie nicht migriert)."; fi
    if [ "$DRY_RUN" = 1 ]; then say "  [dry-run] Es wurde nichts verändert."; return 0; fi
    handle_local_changes "$(state_get INSTALLED_REV)"
    ask "Rollback jetzt ausführen?" y || { say "Abgebrochen."; return 0; }
    local was_running=0
    if [ "$NO_RESTART" = 0 ] && [ -x "$BIN_DEST" ] && HOME="$H" "$BIN_DEST" status >/dev/null 2>&1 9>&-; then was_running=1; HOME="$H" "$BIN_DEST" stop >/dev/null 2>&1 9>&- || true; sleep 0.5; fi
    if [ -n "$bak" ] && [ -d "$bak" ]; then
        local pre="$H/.config/widgetdeck.pre-rollback-$(stamp)"
        [ -d "$CONF_DIR" ] && cp -a "$CONF_DIR" "$pre"
        rm -rf "$CONF_DIR"; cp -a "$bak" "$CONF_DIR"
        ok "Einstellungen aus dem Backup wiederhergestellt (vorheriger Stand: ${pre:-keiner})"
    fi
    checkout_detached "$prev"
    if ! run_install; then die "Die Installation der alten Version ist fehlgeschlagen - siehe $LOG_FILE"; fi
    state_set PREV_REV ""; state_set PREV_VERSION ""; state_set CONFIG_BACKUP ""
    rm -f "$CACHE_DIR/update-check.json"
    [ "$was_running" = 1 ] && restart_shell
    step "Fertig"
    say "  Rollback auf ${prev_ver:-?} abgeschlossen. Der nächste normale Update-Lauf holt wieder den neuesten Stand."
}

main "$@"; exit $?
