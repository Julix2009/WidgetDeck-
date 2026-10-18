# shellcheck shell=bash
# Hyprland integration of install.sh / uninstall. Never edits the main config without asking; always backs it up first;
# everything it adds sits between marker lines so that it can be removed again exactly.
HYPR_MARK_BEGIN=">>> widgetdeck (install.sh)"
HYPR_MARK_END="<<< widgetdeck"

hypr_version() {
    local v
    v="$(Hyprland --version 2>/dev/null | head -n1)" || v=""
    [ -z "$v" ] && v="$(hyprctl version 2>/dev/null | head -n1)" || true
    ver_of "$v"
}

# sets HYPR_DIR, HYPR_MODE (lua | conf | none), HYPR_MAIN, HYPR_SNIPPET
hypr_detect() {
    HYPR_DIR="$H/.config/hypr"
    if   [ -f "$HYPR_DIR/hyprland.lua" ];  then HYPR_MODE=lua;  HYPR_MAIN="$HYPR_DIR/hyprland.lua";  HYPR_SNIPPET="$HYPR_DIR/widgetdeck.lua"
    elif [ -f "$HYPR_DIR/hyprland.conf" ]; then HYPR_MODE=conf; HYPR_MAIN="$HYPR_DIR/hyprland.conf"; HYPR_SNIPPET="$HYPR_DIR/widgetdeck.conf"
    else HYPR_MODE=none; HYPR_MAIN=""; HYPR_SNIPPET="$HYPR_DIR/widgetdeck.conf"; fi
}

# which template for this mode / version
hypr_template() {
    local v="$1"
    if [ "$HYPR_MODE" = lua ]; then echo "$SCRIPT_DIR/hypr/widgetdeck.lua.in"; return; fi
    if [ -n "$v" ] && [ "$(vercmp "$v" 0.53.0)" = -1 ]; then echo "$SCRIPT_DIR/hypr/widgetdeck-legacy.conf.in"; else echo "$SCRIPT_DIR/hypr/widgetdeck.conf.in"; fi
}
hypr_render() { sed "s|@BIN@|$BIN_DEST|g" "$1"; }

hypr_include_block() {
    if [ "$HYPR_MODE" = lua ]; then
        printf -- '-- %s\ndofile("%s")\n-- %s\n' "$HYPR_MARK_BEGIN" "$HYPR_SNIPPET" "$HYPR_MARK_END"
    else
        printf '# %s\nsource = %s\n# %s\n' "$HYPR_MARK_BEGIN" "$HYPR_SNIPPET" "$HYPR_MARK_END"
    fi
}

hypr_apply() {
    hypr_detect
    local hv tpl content want_sha old_sha rec_sha
    hv="$(hypr_version)"
    if [ "$HYPR_MODE" = none ]; then
        warn "keine Hyprland-Config in $HYPR_DIR gefunden (hyprland.conf oder hyprland.lua)."
        info "Die nötigen Regeln liegen in $SCRIPT_DIR/hypr/ - binde sie selbst in deine Config ein."
        return 0
    fi
    tpl="$(hypr_template "$hv")"
    content="$(hypr_render "$tpl")"
    ok "Hyprland-Config: $HYPR_MAIN (${HYPR_MODE}, Hyprland ${hv:-unbekannt})"

    # --- the snippet file (ours): create, update when untouched, never overwrite when the user edited it
    want_sha="$(printf '%s\n' "$content" | sha256sum | cut -d' ' -f1)"
    rec_sha="$(state_get HYPR_SNIPPET_SHA)"
    if [ -f "$HYPR_SNIPPET" ]; then
        old_sha="$(sha_of "$HYPR_SNIPPET")"
        if [ "$old_sha" = "$want_sha" ]; then ok "Regeldatei aktuell: $HYPR_SNIPPET"
        elif [ -n "$rec_sha" ] && [ "$old_sha" = "$rec_sha" ]; then
            if [ "$DRY_RUN" = 0 ]; then printf '%s\n' "$content" > "$HYPR_SNIPPET"; fi
            ok "Regeldatei aktualisiert: $HYPR_SNIPPET"; state_set HYPR_SNIPPET_SHA "$want_sha"
        else
            if [ "$DRY_RUN" = 0 ]; then printf '%s\n' "$content" > "$HYPR_SNIPPET.new"; fi
            warn "$HYPR_SNIPPET wurde von dir geändert und bleibt unverändert; neue Fassung: $HYPR_SNIPPET.new"
        fi
    else
        if [ "$DRY_RUN" = 1 ]; then printf '  [dry-run] würde %s schreiben:\n' "$HYPR_SNIPPET"
        else mkdir -p "$HYPR_DIR"; printf '%s\n' "$content" > "$HYPR_SNIPPET"; state_set HYPR_SNIPPET_SHA "$want_sha"; ok "Regeldatei geschrieben: $HYPR_SNIPPET"; fi
    fi
    say ""; say "  ----- $(basename "$HYPR_SNIPPET") -----"; printf '%s\n' "$content" | sed 's/^/  | /'; say "  -----"

    # --- the include line in the main config
    if grep -qF "$HYPR_MARK_BEGIN" "$HYPR_MAIN"; then ok "Verweis in $(basename "$HYPR_MAIN") vorhanden"; return 0; fi
    if grep -qE 'widgetdeck\.(conf|lua)' "$HYPR_MAIN"; then ok "$(basename "$HYPR_MAIN") bindet widgetdeck bereits selbst ein - nichts zu tun"; return 0; fi
    local dup
    dup="$(grep -rlE 'widgetdeck (daemon|builder)' "$HYPR_DIR" 2>/dev/null | grep -v "$HYPR_SNIPPET" | head -n3 || true)"
    [ -n "$dup" ] && warn "Autostart für widgetdeck steht schon in: $(echo "$dup" | tr '\n' ' ') - sonst startet es doppelt."
    if [ "$NO_HYPR" = 1 ]; then info "(--no-hypr-config) Verweis nicht eingetragen. Füge selbst hinzu:"; hypr_include_block | sed 's/^/  | /'; return 0; fi
    if ask "Soll der Verweis in $HYPR_MAIN eingetragen werden (Backup wird angelegt)?" y; then
        local bak="$HYPR_MAIN.widgetdeck-backup-$(stamp)"
        if [ "$DRY_RUN" = 1 ]; then printf '  [dry-run] Backup %s, dann Verweis anhängen\n' "$bak"; return 0; fi
        cp -p "$HYPR_MAIN" "$bak"
        { printf '\n'; hypr_include_block; } >> "$HYPR_MAIN"
        state_set HYPR_MAIN "$HYPR_MAIN"; state_set HYPR_BACKUP "$bak"; state_set HYPR_MAIN_SHA "$(sha_of "$HYPR_MAIN")"; state_set HYPR_INCLUDE added
        ok "Verweis eingetragen (Backup: $bak)"
        info "Neu laden:  hyprctl reload   (oder Hyprland neu starten)"
    else
        info "Verweis nicht eingetragen. Füge selbst hinzu:"; hypr_include_block | sed 's/^/  | /'
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
            run cp -p "$bak" "$main"; ok "$main aus dem Backup wiederhergestellt ($bak)"
        else
            # the user changed the file since: remove only our marked block
            if [ "$DRY_RUN" = 0 ]; then
                local tmp; tmp="$(mktemp)"
                sed "/$HYPR_MARK_BEGIN/,/$HYPR_MARK_END/d" "$main" > "$tmp" && cat "$tmp" > "$main"; rm -f "$tmp"
            else printf '  [dry-run] Verweisblock aus %s entfernen\n' "$main"; fi
            ok "Verweisblock aus $main entfernt (übrige Änderungen von dir bleiben)"
        fi
    else info "kein Verweis von WidgetDeck in der Hyprland-Config"; fi
    snip="$HYPR_SNIPPET"
    if [ -f "$snip" ]; then
        if [ "$(sha_of "$snip")" = "$(state_get HYPR_SNIPPET_SHA)" ]; then run rm -f "$snip"; ok "Regeldatei entfernt: $snip"
        else warn "$snip wurde von dir geändert und bleibt erhalten."; fi
    fi
    run rm -f "$snip.new"
}
