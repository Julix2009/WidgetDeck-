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
WidgetDeck - $(t 'update')

  widgetdeck-update [$(t 'options')]      ($(t 'or ./update.sh inside the cloned folder'))

  --yes, -y            $(t 'no questions (local changes are saved first, packages follow the default answer)')
  --dry-run            $(t 'show what would happen (fetches the remote state, but changes nothing)')
  --channel main|stable  $(t 'main = always the newest state (default), stable = tagged releases only (remembered)')
  --version vX.Y.Z     $(t 'install a specific version')
  --rollback           $(t 'back to the version before the last update (with the settings backup)')
  --no-packages        $(t 'skip the package check')
  --no-restart         $(t 'do not restart the widgets')
  --prefix <path>      $(t 'test: <path> replaces your home')
  --help
USAGE
}

PREFIX=""; CHANNEL_OPT=""; VERSION_OPT=""; ROLLBACK=0; NO_PACKAGES=0; NO_RESTART=0

main() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --dry-run) DRY_RUN=1 ;;
            --yes|-y) ASSUME_YES=1 ;;
            --channel) shift; [ $# -gt 0 ] || die "$(t '--channel needs main or stable')"; CHANNEL_OPT="$1" ;;
            --channel=*) CHANNEL_OPT="${1#--channel=}" ;;
            --version) shift; [ $# -gt 0 ] || die "$(t '--version needs a version, e.g. v0.2.0')"; VERSION_OPT="$1" ;;
            --version=*) VERSION_OPT="${1#--version=}" ;;
            --rollback) ROLLBACK=1 ;;
            --no-packages) NO_PACKAGES=1 ;;
            --no-restart) NO_RESTART=1 ;;
            --prefix) shift; [ $# -gt 0 ] || die "$(t '--prefix needs a path')"; PREFIX="$1" ;;
            --prefix=*) PREFIX="${1#--prefix=}" ;;
            --help|-h) usage; exit 0 ;;
            *) usage >&2; die "$(t 'unknown option: %s' "$1")" ;;
        esac
        shift
    done
    case "$CHANNEL_OPT" in ""|main|stable) ;; *) die "$(t '--channel: expected main or stable, not %s' "$CHANNEL_OPT")" ;; esac

    if [ -n "$PREFIX" ]; then H="$(realpath -m -- "$PREFIX")"; else H="${HOME:?HOME ist nicht gesetzt}"; fi
    wd_paths "$H" "$PREFIX"
    LOG_FILE=""
    if [ "$DRY_RUN" = 0 ]; then mkdir -p "$CACHE_DIR"; LOG_FILE="$CACHE_DIR/install.log"; : >> "$LOG_FILE"; fi
    _log "== update.sh $* (H=$H) =="
    if [ "$DRY_RUN" = 0 ]; then       # two updates at the same time would corrupt each other
        exec 9> "$CACHE_DIR/update.lock"
        flock -n 9 || die "$(t 'An update is already running (or a second call at the same time). Please wait.')"
    fi

    command -v git >/dev/null 2>&1 || die "$(t 'git is missing (pacman -S git).')"
    git -C "$SCRIPT_DIR" rev-parse --git-dir >/dev/null 2>&1 || die "$(t '%s is not a git clone - updating only works in a cloned folder.' "$SCRIPT_DIR")"

    local cur_ver cur_rev
    cur_ver="$(tr -d '[:space:]' < "$QML_DEST/VERSION" 2>/dev/null || true)"; cur_ver="${cur_ver:-0.0.0}"
    cur_rev="$(state_get INSTALLED_REV)"; [ -n "$cur_rev" ] || cur_rev="$(tr -d '[:space:]' < "$QML_DEST/REV" 2>/dev/null || true)"

    say "${C_B}WidgetDeck $(t 'update')${C_0}  -  $(t 'installed: %s' "${cur_ver}${cur_rev:+ (${cur_rev:0:7})}")$([ "$DRY_RUN" = 1 ] && echo '  (--dry-run)')"

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
    step "$(t 'Fetching the remote state (channel: %s)' "$channel")"
    if ! gitnet fetch --tags --prune origin >> "${LOG_FILE:-/dev/null}" 2>&1; then
        warn "$(t 'The repository is not reachable (no network, or no access to a private repo). Nothing was changed.')"
        exit 1
    fi
    ok "$(t 'Remote state fetched')"

    # ---------------------------------------------------------------- target
    local ref target_rev target_ver default_branch
    default_branch="$(git -C "$SCRIPT_DIR" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || true)"; default_branch="${default_branch:-main}"
    if [ -n "$VERSION_OPT" ]; then
        local v="v${VERSION_OPT#v}"
        ref="refs/tags/$v"
        git -C "$SCRIPT_DIR" rev-parse -q --verify "$ref^{commit}" >/dev/null || die "$(t 'Version %s does not exist. Available: %s' "$v" "$(git -C "$SCRIPT_DIR" tag -l 'v[0-9]*' --sort=-v:refname | head -n8 | tr '\n' ' ')")"
    elif [ "$channel" = stable ]; then
        local latest; latest="$(git -C "$SCRIPT_DIR" tag -l 'v[0-9]*' --sort=-v:refname | head -n1)"
        [ -n "$latest" ] || die "$(t 'There is no published release yet (no v* tags). Use --channel main.')"
        ref="refs/tags/$latest"
    else
        ref="refs/remotes/origin/$default_branch"
        git -C "$SCRIPT_DIR" rev-parse -q --verify "$ref^{commit}" >/dev/null || die "$(t 'Branch origin/%s not found.' "$default_branch")"
    fi
    target_rev="$(git -C "$SCRIPT_DIR" rev-parse "$ref^{commit}")"
    target_ver="$(git -C "$SCRIPT_DIR" show "$target_rev:VERSION" 2>/dev/null | tr -d '[:space:]' || true)"; target_ver="${target_ver:-?}"

    if [ "$target_rev" = "$cur_rev" ]; then
        ok "$(t 'Already up to date: version %s (%s).' "$cur_ver" "${cur_rev:0:7}")"
        return 0
    fi
    say ""
    say "  $(t 'Current:')  $cur_ver${cur_rev:+ (${cur_rev:0:7})}"
    say "  $(t 'New:')      $target_ver (${target_rev:0:7})   [$( [ -n "$VERSION_OPT" ] && echo "$(t 'version %s' "v${VERSION_OPT#v}")" || echo "$(t 'channel %s' "$channel")" )]"
    if [ "$target_ver" != "?" ] && [ "$(vercmp "$target_ver" "$cur_ver")" = -1 ]; then warn "$(t 'The target version is older than the installed one (downgrade).')"; fi

    # changelog excerpt since the installed version
    local notes
    notes="$(git -C "$SCRIPT_DIR" show "$target_rev:CHANGELOG.md" 2>/dev/null | changelog_since "$cur_ver" || true)"
    if [ -n "$notes" ]; then
        say ""; say "  $(t 'Changes:')"; printf '%s\n' "$notes" | sed -e '/^[[:space:]]*$/d' -e 's/^/    /'
    elif [ -n "$cur_rev" ] && git -C "$SCRIPT_DIR" cat-file -e "$cur_rev^{commit}" 2>/dev/null; then
        say ""; say "  $(t 'Changes (commits):')"; git -C "$SCRIPT_DIR" log --oneline --no-merges -n 15 "$cur_rev..$target_rev" 2>/dev/null | sed 's/^/    /' || true
    fi
    if [ -n "$cur_rev" ] && git -C "$SCRIPT_DIR" cat-file -e "$cur_rev^{commit}" 2>/dev/null; then
        say ""; say "  $(t 'Changed files:')"; git -C "$SCRIPT_DIR" diff --stat "$cur_rev" "$target_rev" 2>/dev/null | tail -n 12 | sed 's/^/   /' || true
    fi
    # pending config migrations in the target?
    local cur_schema=0 new_schema=0 f n
    [ -f "$CONF_DIR/config.json" ] && cur_schema="$(jq -r '.schema // 0' "$CONF_DIR/config.json" 2>/dev/null || echo 0)"
    while IFS= read -r f; do n="$(basename "$f")"; n=$((10#${n%%_*})); [ "$n" -gt "$new_schema" ] && new_schema="$n"; done < <(git -C "$SCRIPT_DIR" ls-tree --name-only "$target_rev" migrations/ 2>/dev/null | grep -E '/[0-9]{4}_.*\.sh$' || true)
    if [ "$new_schema" -gt "$cur_schema" ]; then say ""; say "  $(t 'Your settings will be migrated from schema %s to %s (a backup goes to ~/.config/widgetdeck.bak-<date> first).' "$cur_schema" "$new_schema")"; fi

    # ---------------------------------------------------------------- local changes
    handle_local_changes "$cur_rev"

    # clone must be able to fast-forward on the main channel
    if [ -z "$VERSION_OPT" ] && [ "$channel" = main ] && git -C "$SCRIPT_DIR" rev-parse -q --verify "refs/heads/$default_branch" >/dev/null; then
        if ! git -C "$SCRIPT_DIR" merge-base --is-ancestor "refs/heads/$default_branch" "$target_rev"; then
            die "$(t "The clone has its own commits on '%s' that are not in the remote (git log origin/%s..%s). Save them or use --channel stable." "$default_branch" "$default_branch" "$default_branch")"
        fi
    fi

    say ""
    if [ "$DRY_RUN" = 1 ]; then
        say "  [dry-run] $(t 'would update to %s: select the state, run install.sh, restart the widgets. Nothing was changed.' "$target_ver")"
        return 0
    fi
    ask "$(t 'Update to %s now?' "$target_ver")" y || { say "$(t 'Cancelled. Nothing was changed.')"; return 0; }

    # ---------------------------------------------------------------- apply
    state_set PREV_REV "$cur_rev"; state_set PREV_VERSION "$cur_ver"; state_set CONFIG_BACKUP ""
    local was_running=0
    if [ "$NO_RESTART" = 0 ] && [ -x "$BIN_DEST" ] && HOME="$H" "$BIN_DEST" status >/dev/null 2>&1 9>&-; then was_running=1; fi
    if [ "$was_running" = 1 ]; then HOME="$H" "$BIN_DEST" stop >/dev/null 2>&1 9>&- || true; sleep 0.5; fi     # nobody writes the settings during the update

    step "$(t 'Updating the program files')"
    checkout_target "$target_rev" "$default_branch" "$channel"
    if ! run_install; then
        warn "$(t 'Installing the new version failed. Restoring the previous version ...')"
        if [ -n "$cur_rev" ]; then
            checkout_detached "$cur_rev"
            local bak; bak="$(state_get CONFIG_BACKUP)"
            [ -n "$bak" ] && [ -d "$bak" ] && { rm -rf "$CONF_DIR"; cp -a "$bak" "$CONF_DIR"; state_set CONFIG_BACKUP ""; }
            run_install || warn "$(t 'The restore had problems too - see %s' "$LOG_FILE")"
        fi
        state_set PREV_REV ""; state_set PREV_VERSION ""
        [ "$was_running" = 1 ] && restart_shell
        die "$(t 'Update failed; the old version is back in place. Details: %s' "$LOG_FILE")"
    fi
    rm -f "$CACHE_DIR/update-check.json"
    state_set LAST_UPDATE "$(date '+%F %T')"
    [ "$was_running" = 1 ] && restart_shell
    step "$(t 'Done')"
    say "  $(t 'WidgetDeck %s is installed. Back to the previous version: widgetdeck-update --rollback' "$target_ver")"
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
    if [ -x "$BIN_DEST" ]; then HOME="$H" "$BIN_DEST" restart >/dev/null 2>&1 9>&- && ok "$(t 'Widgets restarted')" || warn "$(t 'Restart did not work: start it yourself with widgetdeck restart')"; fi
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
        say ""; warn "$(t 'Files in the clone are modified locally:')"
        printf '%s\n' "$changed" | head -n 12 | sed 's/^/    /'
        local choice=1
        if [ "$DRY_RUN" = 1 ]; then say "  [dry-run] $(t 'would save them with git stash.')"
        else
            if [ "$ASSUME_YES" = 0 ]; then
                [ -t 0 ] || die "$(t 'Local changes in the clone and no terminal to ask. Save them (git stash) or use --yes (saves with stash).')"
                say "  $(t '[1] save with git stash (later: git stash pop)   [2] make a timestamped copy, then discard   [3] cancel')"
                read -r -p "  ? $(t 'Choice') [1] " choice || choice=3
                choice="${choice:-1}"
            fi
            case "$choice" in
                1) git -C "$SCRIPT_DIR" stash push -m "widgetdeck-update $stamp_s" >> "${LOG_FILE:-/dev/null}" 2>&1 && ok "$(t 'Changes saved (git stash list)')" || die "$(t 'git stash failed.')" ;;
                2) copy="$CACHE_DIR/local-changes-$stamp_s"; mkdir -p "$copy"
                   git -C "$SCRIPT_DIR" diff HEAD > "$copy/changes.patch"
                   git -C "$SCRIPT_DIR" diff HEAD --name-only | while IFS= read -r f; do [ -f "$SCRIPT_DIR/$f" ] && install -Dm644 "$SCRIPT_DIR/$f" "$copy/files/$f"; done
                   git -C "$SCRIPT_DIR" checkout -q -- . && ok "$(t 'Copy: %s (patch and files); changes discarded' "$copy")" ;;
                *) die "$(t 'Cancelled. Nothing was changed.')" ;;
            esac
        fi
    fi
    # edited copies in ~/.config/quickshell/widgetdeck
    if [ -n "$cur_rev" ] && [ -d "$QML_DEST" ] && git -C "$SCRIPT_DIR" cat-file -e "$cur_rev^{commit}" 2>/dev/null; then
        local tmp; tmp="$(mktemp -d)"
        if git -C "$SCRIPT_DIR" archive "$cur_rev" qml 2>/dev/null | tar -x -C "$tmp" 2>/dev/null \
           && ! diff -rq -x VERSION -x REV -x SOURCE -x '*.qsb' "$tmp/qml" "$QML_DEST" >/dev/null 2>&1; then
            say ""; warn "$(t 'The installed program files (%s) differ from what was installed (edited by hand?).' "$QML_DEST")"
            if [ "$DRY_RUN" = 1 ]; then say "  [dry-run] $(t 'would copy them to %s' "$CACHE_DIR/program-backup-$stamp_s")"
            else copy="$CACHE_DIR/program-backup-$stamp_s"; cp -a "$QML_DEST" "$copy"; ok "$(t 'Copy of the previous program files: %s (the update replaces them)' "$copy")"; fi
        fi
        rm -rf "$tmp"
    fi
}

do_rollback() {
    local prev prev_ver bak
    prev="$(state_get PREV_REV)"; prev_ver="$(state_get PREV_VERSION)"; bak="$(state_get CONFIG_BACKUP)"
    [ -n "$prev" ] || die "$(t 'No previous version is stored (no update yet, or already rolled back).')"
    git -C "$SCRIPT_DIR" cat-file -e "$prev^{commit}" 2>/dev/null || die "$(t 'The previous state %s is no longer in the clone.' "${prev:0:7}")"
    say ""; say "  $(t 'Back to:') ${prev_ver:-?} (${prev:0:7})"
    if [ -n "$bak" ] && [ -d "$bak" ]; then say "  $(t 'Settings: backup %s is restored (the current ones are copied to ~/.config/widgetdeck.pre-rollback-<date> first).' "$bak")"
    else say "  $(t 'Settings: stay unchanged (the last update did not migrate them).')"; fi
    if [ "$DRY_RUN" = 1 ]; then say "  [dry-run] $(t 'Nothing was changed.')"; return 0; fi
    handle_local_changes "$(state_get INSTALLED_REV)"
    ask "$(t 'Roll back now?')" y || { say "$(t 'Cancelled.')"; return 0; }
    local was_running=0
    if [ "$NO_RESTART" = 0 ] && [ -x "$BIN_DEST" ] && HOME="$H" "$BIN_DEST" status >/dev/null 2>&1 9>&-; then was_running=1; HOME="$H" "$BIN_DEST" stop >/dev/null 2>&1 9>&- || true; sleep 0.5; fi
    if [ -n "$bak" ] && [ -d "$bak" ]; then
        local pre="$CONFIG_HOME/widgetdeck.pre-rollback-$(stamp)"
        [ -d "$CONF_DIR" ] && cp -a "$CONF_DIR" "$pre"
        rm -rf "$CONF_DIR"; cp -a "$bak" "$CONF_DIR"
        ok "$(t 'Settings restored from the backup (previous state: %s)' "${pre:-none}")"
    fi
    checkout_detached "$prev"
    if ! run_install; then die "$(t 'Installing the old version failed - see %s' "$LOG_FILE")"; fi
    state_set PREV_REV ""; state_set PREV_VERSION ""; state_set CONFIG_BACKUP ""
    rm -f "$CACHE_DIR/update-check.json"
    [ "$was_running" = 1 ] && restart_shell
    step "$(t 'Done')"
    say "  $(t 'Rollback to %s finished. The next normal update fetches the newest state again.' "${prev_ver:-?}")"
}

main "$@"; exit $?
