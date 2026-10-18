# shellcheck shell=bash
# Config migrations (sourced by install.sh). Needs: CONF_DIR, H, SCRIPT_DIR, STATE_FILE, DRY_RUN and lib/common.sh.

migrate_latest() {      # highest migration number shipped with this version (0 = none)
    local f n max=0
    for f in "$SCRIPT_DIR"/migrations/[0-9][0-9][0-9][0-9]_*.sh; do
        [ -e "$f" ] || continue
        n="$(basename "$f")"; n=$((10#${n%%_*}))
        [ "$n" -gt "$max" ] && max="$n"
    done
    echo "$max"
}
migrate_current() {     # schema number of the user's config.json (0 when missing)
    local v
    v="$(jq -r '.schema // 0' "$CONF_DIR/config.json" 2>/dev/null || echo 0)"
    case "$v" in ''|*[!0-9]*) v=0 ;; esac
    echo "$v"
}
migrate_set_schema() {  # migrate_set_schema <n>
    local tmp
    tmp="$(mktemp "$CONF_DIR/config.json.XXXXXX")"
    if jq --argjson n "$1" '.schema = $n' "$CONF_DIR/config.json" > "$tmp"; then mv "$tmp" "$CONF_DIR/config.json"; else rm -f "$tmp"; return 1; fi
}

# migrate_run: runs pending migrations. Returns 1 (config restored) when one fails.
migrate_run() {
    [ -f "$CONF_DIR/config.json" ] || return 0
    local cur latest f n pending=() bak
    cur="$(migrate_current)"; latest="$(migrate_latest)"
    if [ "$cur" -ge "$latest" ]; then
        [ "$cur" -gt "$latest" ] && info "Einstellungen haben Schema $cur (neuer als dieses Programm, $latest) - es wird nichts migriert."
        return 0
    fi
    for f in "$SCRIPT_DIR"/migrations/[0-9][0-9][0-9][0-9]_*.sh; do
        [ -e "$f" ] || continue
        n="$(basename "$f")"; n=$((10#${n%%_*}))
        [ "$n" -gt "$cur" ] && pending+=("$f")
    done
    step "Einstellungen migrieren (Schema $cur -> $latest)"
    bak="$H/.config/widgetdeck.bak-$(stamp)"
    if [ "$DRY_RUN" = 1 ]; then
        printf '  [dry-run] Backup %s\n' "$bak"
        for f in "${pending[@]}"; do printf '  [dry-run] bash %s %s\n' "$(basename "$f")" "$CONF_DIR"; done
        return 0
    fi
    cp -a "$CONF_DIR" "$bak"
    state_set CONFIG_BACKUP "$bak"
    ok "Backup der Einstellungen: $bak"
    for f in "${pending[@]}"; do
        n="$(basename "$f")"; n=$((10#${n%%_*}))
        if bash "$f" "$CONF_DIR" >> "${LOG_FILE:-/dev/null}" 2>&1 && migrate_set_schema "$n"; then
            ok "Migration $(basename "$f")"
        else
            warn "Migration $(basename "$f") ist fehlgeschlagen - stelle die Einstellungen aus dem Backup wieder her."
            rm -rf "$CONF_DIR" && cp -a "$bak" "$CONF_DIR"
            state_set CONFIG_BACKUP ""
            return 1
        fi
    done
}
