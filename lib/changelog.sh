# shellcheck shell=bash
# changelog_since <CHANGELOG file content on stdin> <installed version>: prints the sections of versions NEWER than <installed>.
changelog_since() {
    local have="$1"
    awk -v have="$have" '
        function vgt(a, b,    x, y, i, n) {            # a > b ?
            n = split(a, x, "."); split(b, y, ".")
            for (i = 1; i <= 3; i++) { if ((x[i] + 0) > (y[i] + 0)) return 1; if ((x[i] + 0) < (y[i] + 0)) return 0 }
            return 0
        }
        /^## \[/ {
            v = $0; sub(/^## \[/, "", v); sub(/\].*/, "", v)
            show = (v ~ /^[0-9]+\.[0-9]+\.[0-9]+/) && vgt(v, have)
        }
        show { print }
    '
}
