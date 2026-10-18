#!/usr/bin/env bash
# Publish a new WidgetDeck version (for the maintainer).
#   ./release.sh patch|minor|major [--dry-run] [--no-shellcheck]
#   ./release.sh current            first release: tags the version that is already in VERSION
# Checks, bumps VERSION, writes the CHANGELOG from the commit messages (you can edit them), shows a summary and asks.
# Only after your "ja": commit, tag vX.Y.Z, push main + tag. Nothing is pushed before that; --dry-run changes nothing at all.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
cd "$SCRIPT_DIR"
# shellcheck source=lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"
REMOTE="${RELEASE_REMOTE:-origin}"
BRANCH="main"
KIND=""; SKIP_SC=0

usage() {
    cat <<USAGE
Verwendung: ./release.sh patch|minor|major|current [--dry-run] [--no-shellcheck]

  patch|minor|major  erhöht die Version (Fehlerbehebung | neue Funktion | grundlegende Änderung)
  current            erste Veröffentlichung: nimmt die Version aus VERSION, wie sie ist
  --dry-run          prüft und zeigt alles, ändert und pusht nichts
  --no-shellcheck    nur wenn shellcheck nicht installierbar ist (wird in der Zusammenfassung vermerkt)
USAGE
}

while [ $# -gt 0 ]; do
    case "$1" in
        patch|minor|major|current) KIND="$1" ;;
        --dry-run) DRY_RUN=1 ;;
        --no-shellcheck) SKIP_SC=1 ;;
        --help|-h) usage; exit 0 ;;
        *) usage >&2; die "unbekannte Option: $1" ;;
    esac
    shift
done
[ -n "$KIND" ] || { usage >&2; exit 1; }
[ "$DRY_RUN" = 1 ] && say "${C_B}--dry-run${C_0}: es wird nichts verändert."

FAILED=0
fail() { warn "$*"; FAILED=1; }

# ------------------------------------------------------------------ checks
step "Prüfungen"
git rev-parse --git-dir >/dev/null 2>&1 || die "Kein Git-Repository."
[ -f VERSION ] || die "Datei VERSION fehlt."
CUR="$(tr -d '[:space:]' < VERSION)"
[[ "$CUR" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "VERSION '$CUR' ist keine Version nach Semantic Versioning (x.y.z)."

if [ -z "$(git status --porcelain)" ]; then ok "Arbeitsbaum sauber"; else fail "Arbeitsbaum ist nicht sauber (git status): erst committen oder verwerfen."; git status --short | head -n 8 | sed 's/^/         /'; fi
cur_branch="$(git rev-parse --abbrev-ref HEAD)"
if [ "$cur_branch" = "$BRANCH" ]; then ok "Branch $BRANCH"; else fail "Du bist auf '$cur_branch', Releases kommen von '$BRANCH'."; fi
if git remote get-url "$REMOTE" >/dev/null 2>&1; then
    if GIT_TERMINAL_PROMPT=0 timeout 60 git fetch --quiet --tags "$REMOTE" 2>/dev/null; then
        behind="$(git rev-list --count "HEAD..$REMOTE/$BRANCH" 2>/dev/null || echo 0)"
        if [ "$behind" -gt 0 ]; then fail "Das Remote hat $behind Commit(s), die dir fehlen (git pull)."; else ok "Remote '$REMOTE' erreichbar und nicht voraus"; fi
    else
        if git ls-remote --exit-code "$REMOTE" >/dev/null 2>&1; then ok "Remote '$REMOTE' erreichbar"; else fail "Remote '$REMOTE' ist nicht erreichbar (Netz? Zugriff?)."; fi
    fi
else fail "Es gibt kein Remote '$REMOTE' (git remote add $REMOTE <url>)."; fi

# shellcheck on every shell script
SC_FILES=()
while IFS= read -r f; do
    case "$f" in *.sh|bin/widgetdeck|bin/widgetdeck-update) SC_FILES+=("$f") ;; esac
done < <(git ls-files)
if [ "$SKIP_SC" = 1 ]; then warn "shellcheck übersprungen (--no-shellcheck)."
elif command -v shellcheck >/dev/null 2>&1; then
    if shellcheck -x "${SC_FILES[@]}"; then ok "shellcheck: ${#SC_FILES[@]} Skripte ohne Warnungen"; else fail "shellcheck meldet Probleme (siehe oben)."; fi
else fail "shellcheck ist nicht installiert (pacman -S shellcheck)."; fi
for f in "${SC_FILES[@]}"; do bash -n "$f" 2>/dev/null || fail "Syntaxfehler in $f"; done
if "$SCRIPT_DIR/tools/secret-scan.sh" >/tmp/release-secret-scan.$$ 2>&1; then ok "Secret-Scan sauber (Pfade, Tokens, Standort, persönliche Wörter)"; else fail "Secret-Scan hat etwas gefunden:"; sed 's/^/         /' /tmp/release-secret-scan.$$; fi
rm -f /tmp/release-secret-scan.$$
if command -v node >/dev/null 2>&1 && [ -f tools/snapengine-test.js ]; then
    if node tools/snapengine-test.js 2>&1 | grep -q '^FAIL'; then fail "tools/snapengine-test.js: Tests schlagen fehl."; else ok "Raster-Tests bestanden"; fi
fi
grep -q '^## \[Unveröffentlicht\]' CHANGELOG.md || fail "CHANGELOG.md hat keine Überschrift '## [Unveröffentlicht]'."

LAST="$(git describe --tags --abbrev=0 --match 'v[0-9]*' 2>/dev/null || true)"
if [ "$KIND" = current ]; then
    [ -z "$LAST" ] || fail "Es gibt schon den Tag $LAST - nutze patch, minor oder major."
    NEW="$CUR"
    grep -q "^## \[$NEW\]" CHANGELOG.md || fail "CHANGELOG.md hat keinen Abschnitt für $NEW."
else
    IFS=. read -r MA MI PA <<<"$CUR"
    case "$KIND" in patch) PA=$((PA + 1)) ;; minor) MI=$((MI + 1)); PA=0 ;; major) MA=$((MA + 1)); MI=0; PA=0 ;; esac
    NEW="$MA.$MI.$PA"
    [ -n "$LAST" ] && [ "$LAST" != "v$CUR" ] && warn "VERSION ($CUR) entspricht nicht dem letzten Tag ($LAST)."
fi
git rev-parse -q --verify "refs/tags/v$NEW" >/dev/null && fail "Der Tag v$NEW existiert schon."

if [ "$FAILED" = 1 ]; then
    if [ "$DRY_RUN" = 1 ]; then warn "Es gibt Probleme (siehe oben). Ein echter Lauf würde hier abbrechen."; else die "Bitte die Probleme beheben, dann erneut starten. Es wurde nichts verändert."; fi
fi

# ------------------------------------------------------------------ changelog draft
RANGE="${LAST:+$LAST..}HEAD"
DRAFT="$(mktemp)"; SECTION="$(mktemp)"
cleanup() { rm -f "$DRAFT" "$SECTION"; }
trap cleanup EXIT

if [ "$KIND" = current ]; then
    awk -v v="$NEW" '$0 ~ "^## \\[" v "\\]" {p=1; next} /^## \[/ {p=0} p' CHANGELOG.md > "$DRAFT"
else
    added=(); fixed=(); changed=()
    while IFS= read -r subj; do
        [ -n "$subj" ] || continue
        case "$subj" in Release\ v*|Merge*) continue ;; esac
        txt="$(sed -E 's/^[A-Za-z]+(\([^)]*\))?:[[:space:]]*//' <<<"$subj")"; txt="${txt^}"
        case "${subj,,}" in
            feat*|add*|neu*|hinzu*) added+=("- $txt") ;;
            fix*|bug*|behebe*|korrigiere*) fixed+=("- $txt") ;;
            *) changed+=("- $txt") ;;
        esac
    done < <(git log --no-merges --pretty='%s' "$RANGE")
    [ $(( ${#added[@]} + ${#fixed[@]} + ${#changed[@]} )) -gt 0 ] || die "Seit ${LAST:-dem Anfang} gibt es keine Commits - nichts zu veröffentlichen."
    {
        [ "${#added[@]}" -gt 0 ] && { printf '\n### Hinzugefügt\n'; printf '%s\n' "${added[@]}"; }
        [ "${#changed[@]}" -gt 0 ] && { printf '\n### Geändert\n'; printf '%s\n' "${changed[@]}"; }
        [ "${#fixed[@]}" -gt 0 ] && { printf '\n### Behoben\n'; printf '%s\n' "${fixed[@]}"; }
    } > "$DRAFT"
    # edit
    if [ "$DRY_RUN" = 0 ] && [ -t 0 ]; then
        ED="${VISUAL:-${EDITOR:-}}"; [ -n "$ED" ] || for ED in nano vim vi; do command -v "$ED" >/dev/null 2>&1 && break; done
        say ""; say "  Der Changelog-Entwurf wird zum Bearbeiten geöffnet ($ED). Speichern und schließen, um fortzufahren."
        ask "Entwurf jetzt bearbeiten?" y && $ED "$DRAFT"
    fi
fi
{ printf '## [%s] - %s\n' "$NEW" "$(date +%F)"; cat "$DRAFT"; printf '\n'; } > "$SECTION"

# ------------------------------------------------------------------ summary
step "Zusammenfassung"
say "  Version:   $CUR  ->  ${C_B}$NEW${C_0}   (Tag v$NEW, Branch $BRANCH, Remote $REMOTE)"
[ "$SKIP_SC" = 1 ] && say "  ${C_Y}shellcheck wurde übersprungen${C_0}"
say ""; say "  Änderungen:"; sed '/^$/d; s/^/    /' "$DRAFT"
say ""; say "  Geänderte Dateien seit ${LAST:-dem Anfang}:"
if [ -n "$LAST" ]; then git diff --stat "$LAST" HEAD | tail -n 15 | sed 's/^/   /'; else git ls-files | wc -l | sed 's/^/    (erstes Release) Dateien: /'; fi

if [ "$DRY_RUN" = 1 ]; then
    say ""
    if [ "$KIND" = current ]; then say "  [dry-run] würde: Tag v$NEW setzen und 'git push --atomic $REMOTE $BRANCH v$NEW' ausführen."
    else say "  [dry-run] würde: VERSION auf $NEW setzen, CHANGELOG ergänzen, committen ('Release v$NEW'), Tag v$NEW setzen und 'git push --atomic $REMOTE $BRANCH v$NEW' ausführen."; fi
    say "  [dry-run] Es wurde nichts verändert."
    exit 0
fi
say ""
ask "Version $NEW jetzt veröffentlichen (commit, Tag, push)?" n || { say "Abgebrochen. Es wurde nichts verändert."; exit 0; }

# ------------------------------------------------------------------ apply
step "Veröffentlichen"
if [ "$KIND" != current ]; then
    printf '%s\n' "$NEW" > VERSION
    [ -f packaging/PKGBUILD ] && sed -i "s/^pkgver=.*/pkgver=$NEW/" packaging/PKGBUILD
    awk -v secfile="$SECTION" '
        BEGIN { while ((getline l < secfile) > 0) sec = sec l "\n" }
        /^## \[Unveröffentlicht\]/ { print; unrel = 1; next }
        unrel && /^## \[/ { printf "%s", sec; unrel = 0; done = 1 }
        { print }
        END { if (unrel && !done) printf "\n%s", sec }
    ' CHANGELOG.md > CHANGELOG.md.new && mv CHANGELOG.md.new CHANGELOG.md
    git add VERSION CHANGELOG.md packaging/PKGBUILD
    git commit -q -m "Release v$NEW"
    ok "Commit: Release v$NEW"
fi
git tag -a "v$NEW" -m "WidgetDeck $NEW"
ok "Tag v$NEW gesetzt"
if git push -q --atomic "$REMOTE" "$BRANCH" "v$NEW"; then
    ok "main und v$NEW gepusht"
else
    warn "Der Push ist fehlgeschlagen. Lokal sind Commit und Tag vorhanden. Erneut versuchen: git push --atomic $REMOTE $BRANCH v$NEW"
    warn "Oder zurücknehmen: git tag -d v$NEW && git reset --hard HEAD~1"
    exit 1
fi
say ""; say "  Dein Freund bekommt es mit:  widgetdeck-update"
