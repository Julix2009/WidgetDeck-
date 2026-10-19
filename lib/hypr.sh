# shellcheck shell=bash
# Hyprland integration of install.sh / uninstall. Never edits the main config without asking; always backs it up first;
# everything it adds sits between marker lines so that it can be removed again exactly. Before anything is changed, the result is
# checked with `Hyprland --verify-config` on a COPY, so a syntax problem is reported (line + reason) instead of breaking the session.
HYPR_MARK_BEGIN=">>> widgetdeck (install.sh)"
HYPR_MARK_END="<<< widgetdeck"
# oldest version the rules are written for / newest version the author could test
HYPR_MIN="0.40.0"; HYPR_LEGACY_BELOW="0.53.0"; HYPR_LUA_FROM="0.55.0"

hypr_version() {
    local v
    v="$(Hyprland --version 2>/dev/null | head -n1)" || v=""
    [ -z "$v" ] && v="$(hyprctl version 2>/dev/null | head -n1)" || true
    ver_of "$v"
}

# the config file the RUNNING Hyprland was started with (-c / --config), if any
hypr_running_config() {
    local line f
    line="$(pgrep -ax Hyprland 2>/dev/null | head -n1)"
    f="$(printf '%s\n' "$line" | sed -nE 's/.* (-c|--config)[ =]([^ ]+).*/\2/p')"
    [ -n "$f" ] && [ -f "$f" ] && printf '%s' "$f"
}

# sets HYPR_DIR, HYPR_MODE (lua | conf | none), HYPR_MAIN, HYPR_SNIPPET, HYPR_MANUAL (1 = we must not edit the file) and HYPR_WHY
hypr_detect() {
    local run; HYPR_MANUAL=0; HYPR_WHY=""
    run=""; if [ -z "$PREFIX" ]; then run="$(hypr_running_config || true)"; fi
    if [ -n "$run" ]; then HYPR_MAIN="$run"; HYPR_DIR="$(dirname "$run")"
        case "$run" in *.lua) HYPR_MODE=lua ;; *) HYPR_MODE=conf ;; esac
    else
        HYPR_DIR="$CONFIG_HOME/hypr"
        if   [ -f "$HYPR_DIR/hyprland.lua" ];  then HYPR_MODE=lua;  HYPR_MAIN="$HYPR_DIR/hyprland.lua"
        elif [ -f "$HYPR_DIR/hyprland.conf" ]; then HYPR_MODE=conf; HYPR_MAIN="$HYPR_DIR/hyprland.conf"
        else HYPR_MODE=none; HYPR_MAIN=""; fi
    fi
    if [ "$HYPR_MODE" = lua ]; then HYPR_SNIPPET="$HYPR_DIR/widgetdeck.lua"; else HYPR_SNIPPET="$HYPR_DIR/widgetdeck.conf"; fi
    # configs we must not touch: managed by something else (Home Manager / Nix store symlinks, read-only files)
    if [ -n "$HYPR_MAIN" ]; then
        local real; real="$(readlink -f "$HYPR_MAIN" 2>/dev/null || echo "$HYPR_MAIN")"
        case "$real" in /nix/store/*) HYPR_MANUAL=1; HYPR_WHY="$(t 'it is a symlink into /nix/store (Home Manager / Nix): edit your Nix configuration instead')" ;; esac
        if [ "$HYPR_MANUAL" = 0 ] && [ ! -w "$real" ]; then HYPR_MANUAL=1; HYPR_WHY="$(t 'the file is not writable')"; fi
        if [ "$HYPR_MANUAL" = 0 ] && [ -L "$HYPR_MAIN" ]; then
            # a symlink into a dotfiles repository is fine to edit, but say so
            info "$(t 'note: %s is a symlink to %s; the include line is added to that file' "$HYPR_MAIN" "$real")"
        fi
        [ "$HYPR_MANUAL" = 0 ] && [ ! -w "$HYPR_DIR" ] && HYPR_MANUAL=1 && HYPR_WHY="$(t 'the folder is not writable')"
    fi
    return 0
}

# which template for this mode / version
hypr_template() {
    local v="$1"
    if [ "$HYPR_MODE" = lua ]; then echo "$SCRIPT_DIR/hypr/widgetdeck.lua.in"; return; fi
    if [ -n "$v" ] && [ "$(vercmp "$v" "$HYPR_LEGACY_BELOW")" = -1 ]; then echo "$SCRIPT_DIR/hypr/widgetdeck-legacy.conf.in"; else echo "$SCRIPT_DIR/hypr/widgetdeck.conf.in"; fi
}
hypr_render() { sed "s|@BIN@|$BIN_DEST|g" "$1"; }

hypr_include_block() {
    if [ "$HYPR_MODE" = lua ]; then
        printf -- '-- %s\ndofile("%s")\n-- %s\n' "$HYPR_MARK_BEGIN" "$HYPR_SNIPPET" "$HYPR_MARK_END"
    else
        printf '# %s\nsource = %s\n# %s\n' "$HYPR_MARK_BEGIN" "$HYPR_SNIPPET" "$HYPR_MARK_END"
    fi
}

# hypr_verify <file>: prints the problems Hyprland reports for that config file (empty = ok or cannot check). Uses a copy, never the live session.
hypr_verify() {
    command -v Hyprland >/dev/null 2>&1 || return 0
    Hyprland --help 2>&1 | grep -q -- '--verify-config' || return 0
    local out
    out="$(cd /tmp && env -u WAYLAND_DISPLAY -u HYPRLAND_INSTANCE_SIGNATURE timeout 20 Hyprland --verify-config -c "$1" 2>&1)" || true
    printf '%s\n' "$out" | sed 's/\x1b\[[0-9;]*m//g' | sed -n '/Config parsing result/,$p' | grep -vE 'Config parsing result|^config ok|^[[:space:]]*$' || true
}

# would our include break the user's config? Checks main + include on a copy next to the original (so relative `source =` lines keep working)
hypr_preflight() {
    local copy="$HYPR_MAIN.widgetdeck-check" before after
    cp -p "$HYPR_MAIN" "$copy" 2>/dev/null || return 0
    before="$(hypr_verify "$copy")"
    { printf '\n'; hypr_include_block; } >> "$copy"
    after="$(hypr_verify "$copy")"
    rm -f "$copy"
    HYPR_PRE_BEFORE="$before"
    # problems that mention OUR file are ours; problems that were there before are the user's own
    printf '%s\n' "$after" | grep -F "$(basename "$HYPR_SNIPPET")" || true
}

# problems in the rules for this Hyprland version: says where, why and what to do
hypr_explain() {
    local hv="$1" problems="$2"
    warn "$(t 'Hyprland %s does not accept the WidgetDeck rules:' "${hv:-?}")"
    printf '%s\n' "$problems" | sed 's/^/         | /'
    info "$(t 'Reason: the rule syntax changed between Hyprland versions (blocks since 0.53, Lua since 0.55).')"
    info "$(t 'What to do: nothing was changed. Run with --no-hypr-config, add the rules by hand from %s, and report the line above in an issue (include the output of widgetdeck-doctor).' "$SCRIPT_DIR/hypr/")"
}

hypr_apply() {
    hypr_detect
    local hv tpl content want_sha old_sha rec_sha
    hv="$(hypr_version)"
    if [ -n "$hv" ] && [ "$(vercmp "$hv" "$HYPR_MIN")" = -1 ]; then
        warn "$(t 'Hyprland %s is older than %s: the rules are not written. See %s for the lines to add by hand.' "$hv" "$HYPR_MIN" "$SCRIPT_DIR/hypr/")"; return 0
    fi
    if [ "$HYPR_MODE" = none ]; then
        warn "$(t 'no Hyprland config found in %s (hyprland.conf or hyprland.lua).' "$HYPR_DIR")"
        info "$(t 'The rules are in %s - include them from your config yourself, or create the config first.' "$SCRIPT_DIR/hypr/")"
        hypr_uwsm_note; return 0
    fi
    if [ "$HYPR_MODE" = lua ] && [ -n "$hv" ] && [ "$(vercmp "$hv" "$HYPR_LUA_FROM")" = -1 ]; then
        warn "$(t 'A Lua config needs Hyprland %s or newer (this is %s). Nothing is written.' "$HYPR_LUA_FROM" "$hv")"; return 0
    fi
    tpl="$(hypr_template "$hv")"
    content="$(hypr_render "$tpl")"
    ok "$(t 'Hyprland config: %s (%s, Hyprland %s)' "$HYPR_MAIN" "$HYPR_MODE" "${hv:-unknown}")"
    hypr_uwsm_note

    # --- the snippet file (ours): create, update when untouched, never overwrite when the user edited it
    want_sha="$(printf '%s\n' "$content" | sha256sum | cut -d' ' -f1)"
    rec_sha="$(state_get HYPR_SNIPPET_SHA)"
    if [ -f "$HYPR_SNIPPET" ]; then
        old_sha="$(sha_of "$HYPR_SNIPPET")"
        if [ "$old_sha" = "$want_sha" ]; then ok "$(t 'Rules file is current: %s' "$HYPR_SNIPPET")"
        elif [ -n "$rec_sha" ] && [ "$old_sha" = "$rec_sha" ]; then
            if [ "$DRY_RUN" = 0 ]; then printf '%s\n' "$content" > "$HYPR_SNIPPET"; fi
            ok "$(t 'Rules file updated: %s' "$HYPR_SNIPPET")"; state_set HYPR_SNIPPET_SHA "$want_sha"
        else
            if [ "$DRY_RUN" = 0 ]; then printf '%s\n' "$content" > "$HYPR_SNIPPET.new"; fi
            warn "$(t '%s was changed by you and stays as it is; the new version is in %s' "$HYPR_SNIPPET" "$HYPR_SNIPPET.new")"
        fi
    else
        if [ "$DRY_RUN" = 1 ]; then printf '  [dry-run] %s\n' "$(t 'would write %s' "$HYPR_SNIPPET")"
        elif [ "$HYPR_MANUAL" = 1 ] && [ ! -w "$HYPR_DIR" ]; then :
        else mkdir -p "$HYPR_DIR"; printf '%s\n' "$content" > "$HYPR_SNIPPET"; state_set HYPR_SNIPPET_SHA "$want_sha"; ok "$(t 'Rules file written: %s' "$HYPR_SNIPPET")"; fi
    fi
    say ""; say "  ----- $(basename "$HYPR_SNIPPET") -----"; printf '%s\n' "$content" | sed 's/^/  | /'; say "  -----"

    # --- manual mode: the config is managed elsewhere, never edit it
    if [ "$HYPR_MANUAL" = 1 ]; then
        warn "$(t 'Your config %s is not edited automatically: %s' "$HYPR_MAIN" "$HYPR_WHY")"
        info "$(t 'Add these lines yourself (and put the rules above into %s):' "$(basename "$HYPR_SNIPPET")")"; hypr_include_block | sed 's/^/  | /'; return 0
    fi

    # --- the include line in the main config
    if grep -qF "$HYPR_MARK_BEGIN" "$HYPR_MAIN"; then ok "$(t 'The include line is already in %s' "$(basename "$HYPR_MAIN")")"; return 0; fi
    if grep -qE 'widgetdeck\.(conf|lua)' "$HYPR_MAIN"; then ok "$(t '%s already includes widgetdeck itself - nothing to do' "$(basename "$HYPR_MAIN")")"; return 0; fi
    # a split config: the file we edit might not be the one that is loaded last - say where the rules could also go
    local dup
    dup="$(grep -rlE 'widgetdeck (daemon|builder)' "$HYPR_DIR" 2>/dev/null | grep -v "$HYPR_SNIPPET" | head -n3 || true)"
    [ -n "$dup" ] && warn "$(t 'An autostart for widgetdeck already exists in: %s - otherwise it starts twice.' "$(echo "$dup" | tr '\n' ' ')")"
    if [ "${UPDATE_MODE:-0}" = 1 ] && [ "$NO_HYPR" = 0 ]; then info "$(t 'No include line in %s (not wanted at install time). The rules file was updated anyway.' "$(basename "$HYPR_MAIN")")"; return 0; fi
    if [ "$NO_HYPR" = 1 ]; then info "$(t '(--no-hypr-config) include line not added. Add it yourself:')"; hypr_include_block | sed 's/^/  | /'; return 0; fi
    # check on a copy first: only offer the change when it works
    local problems=""
    if [ "$DRY_RUN" = 0 ] || [ -f "$HYPR_SNIPPET" ]; then problems="$(hypr_preflight)"; fi
    if [ -n "$problems" ]; then hypr_explain "$hv" "$problems"; return 0; fi
    HYPR_PRE_BEFORE="$(hypr_verify "$HYPR_MAIN")"
    [ -n "${HYPR_PRE_BEFORE:-}" ] && warn "$(t 'Your Hyprland config already reports problems (not caused by WidgetDeck):')" && printf '%s\n' "$HYPR_PRE_BEFORE" | head -n3 | sed 's/^/         | /'
    if ask "$(t 'Add the include line to %s (a backup is made first)?' "$HYPR_MAIN")" y; then
        local bak; bak="$HYPR_MAIN.widgetdeck-backup-$(stamp)"
        if [ "$DRY_RUN" = 1 ]; then printf '  [dry-run] %s\n' "$(t 'backup %s, then append the include line' "$bak")"; return 0; fi
        cp -p "$HYPR_MAIN" "$bak"
        { printf '\n'; hypr_include_block; } >> "$HYPR_MAIN"
        state_set HYPR_MAIN "$HYPR_MAIN"; state_set HYPR_BACKUP "$bak"; state_set HYPR_MAIN_SHA "$(sha_of "$HYPR_MAIN")"; state_set HYPR_INCLUDE added
        ok "$(t 'Include line added (backup: %s)' "$bak")"
        info "$(t 'Reload with:  hyprctl reload   (or restart Hyprland)')"
    else
        info "$(t 'Include line not added. Add it yourself:')"; hypr_include_block | sed 's/^/  | /'
    fi
}

# uwsm: sessions started through it keep working with exec-once; just say so
hypr_uwsm_note() {
    if command -v uwsm >/dev/null 2>&1 && { [ -n "${UWSM_FINALIZE_VARNAMES:-}" ] || pgrep -f 'uwsm' >/dev/null 2>&1; }; then
        info "$(t 'uwsm detected: exec-once works as usual. Prefer systemd? Start it with: uwsm app -- %s daemon' "$BIN_DEST")"
    fi
}

hypr_remove() {
    hypr_detect
    local main snip bak
    main="$(state_get HYPR_MAIN)"; [ -z "$main" ] && main="$HYPR_MAIN"
    if [ -n "$main" ] && [ -f "$main" ] && grep -qF "$HYPR_MARK_BEGIN" "$main"; then
        bak="$(state_get HYPR_BACKUP)"
        if [ -n "$bak" ] && [ -f "$bak" ] && [ "$(sha_of "$main")" = "$(state_get HYPR_MAIN_SHA)" ]; then
            # the file is exactly as we left it: the backup is the exact rollback
            run cp -p "$bak" "$main"; ok "$(t '%s restored from the backup (%s)' "$main" "$bak")"
        else
            # the user changed the file since: remove only our marked block
            if [ "$DRY_RUN" = 0 ]; then
                local tmp; tmp="$(mktemp)"
                sed "/$HYPR_MARK_BEGIN/,/$HYPR_MARK_END/d" "$main" > "$tmp" && cat "$tmp" > "$main"; rm -f "$tmp"
            else printf '  [dry-run] %s\n' "$(t 'remove the include block from %s' "$main")"; fi
            ok "$(t 'Include block removed from %s (your other changes stay)' "$main")"
        fi
    else info "$(t 'no WidgetDeck include in the Hyprland config')"; fi
    snip="$HYPR_SNIPPET"
    if [ -f "$snip" ]; then
        if [ "$(sha_of "$snip")" = "$(state_get HYPR_SNIPPET_SHA)" ]; then run rm -f "$snip"; ok "$(t 'Rules file removed: %s' "$snip")"
        else warn "$(t '%s was changed by you and is kept.' "$snip")"; fi
    fi
    run rm -f "$snip.new"
}
