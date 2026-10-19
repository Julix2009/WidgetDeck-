#!/usr/bin/env bash
# Secret / personal-data scan of the working tree AND the whole git history.
#   tools/secret-scan.sh            exit 0 = clean, 1 = findings
# Looks for: personal home paths, tokens / keys, concrete coordinates, and every line of the (untracked) file .release-denylist
# Commit authors are not scanned (they are public by design: set a noreply address, see README).
# (one word per line: your name, city, Wi-Fi name, host name ...). Uses gitleaks too when it is installed.
set -uo pipefail
cd "$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)" || exit 2

PATTERNS=(
    '/home/[A-Za-z0-9._-]+/'
    '/Users/[A-Za-z0-9._-]+/'
    'ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|gho_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|sk-[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{30,}'
    '-----BEGIN [A-Z ]*PRIVATE KEY-----'
    '(api[_-]?key|apikey|secret|token|passwd|password)[[:space:]]*[:=][[:space:]]*["'"'"'][A-Za-z0-9_./+-]{12,}["'"'"']'
    '"(lat|lon|latitude|longitude)"[[:space:]]*:[[:space:]]*-?[0-9]+\.[0-9]{2,}'
    'untis://setschool|[A-Za-z0-9-]+\.webuntis\.com|[?&]key=[A-Z2-7]{16,}|schoolNumber=[0-9]+'
)
# personal words: the current user name and the denylist
WORDS=()
u="$(id -un 2>/dev/null)"
case "$u" in root|runner|nobody|builder|ubuntu|admin|user|vagrant) u="" ;; esac     # generic accounts (CI containers run as root) are not personal data
[ "${#u}" -ge 4 ] && WORDS+=("$u")
if [ -f .release-denylist ]; then while IFS= read -r w; do [ -n "$w" ] && [ "${w:0:1}" != "#" ] && WORDS+=("$w"); done < .release-denylist; fi

EXCL=(':!tools/secret-scan.sh' ':!tools/scan-allow.txt' ':!LICENSES' ':!.release-denylist')
bad=0
report() { printf '  [FUND] %s\n' "$1"; bad=1; }

scan_stream() {   # scan_stream <label>   (stdin = text)
    local label="$1" txt p w hit
    txt="$(cat)"
    if [ -f tools/scan-allow.txt ]; then
        while IFS= read -r w; do [ -n "$w" ] && [ "${w:0:1}" != "#" ] && txt="${txt//"$w"/}"; done < tools/scan-allow.txt
    fi
    for p in "${PATTERNS[@]}"; do
        hit="$(printf '%s\n' "$txt" | grep -nE -- "$p" | head -n3 || true)"; [ -n "$hit" ] && report "$label: Muster /$p/: $(printf '%s' "$hit" | head -n1 | cut -c1-120)"
    done
    for w in "${WORDS[@]}"; do
        hit="$(printf '%s\n' "$txt" | grep -niF -- "$w" | head -n1 || true)"; [ -n "$hit" ] && report "$label: persönliches Wort '$w'"
    done
}

echo "Suche in den Dateien ..."
while IFS= read -r f; do
    [ -f "$f" ] || continue
    case "$f" in tools/secret-scan.sh|tools/scan-allow.txt|LICENSES/*) continue ;; esac
    grep -Iq . "$f" 2>/dev/null || continue
    scan_stream "$f" < "$f"
done < <(git ls-files)

echo "Suche in der gesamten Git-Historie (Inhalte und Commit-Nachrichten) ..."
if git rev-parse --verify -q HEAD >/dev/null; then
    git log --all -p --no-color --format='commit %H%n%s%n%b' -- . "${EXCL[@]}" | grep -E '^(\+|commit|[^ +-])' | scan_stream "Historie"
fi

if command -v gitleaks >/dev/null 2>&1; then
    echo "gitleaks ..."
    gitleaks detect --no-banner --redact -s . >/dev/null 2>&1 || report "gitleaks hat etwas gefunden (gitleaks detect -s . für Details)"
else
    echo "Hinweis: gitleaks ist nicht installiert - nur die eingebaute Mustersuche lief (pacman -S gitleaks)."
fi

if [ "$bad" = 0 ]; then echo "Secret-Scan: sauber."; else echo "Secret-Scan: FUNDE - nicht veröffentlichen."; fi
exit "$bad"
