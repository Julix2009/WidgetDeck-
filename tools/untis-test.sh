#!/usr/bin/env bash
# End-to-end test of the Untis client against the local mock server (invented data, test key, self-signed cert, HTTPS + verification ON).
# Needs: python3, openssl, jq.   tools/untis-test.sh
set -u
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
CLIENT="$HERE/../qml/widgets/timetable/untis.py"; MOCK="$HERE/untis-mock.py"
T="$(mktemp -d)"; PORT=$((20000 + RANDOM % 20000)); fail=0; MPID=""
cleanup() { [ -n "$MPID" ] && kill "$MPID" 2>/dev/null; rm -rf "$T"; }; trap cleanup EXIT
ok() { echo "ok   $1"; }; bad() { echo "FAIL $1 ($2)"; fail=1; }
check() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "got '$2', wanted '$3'"; fi; }
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$T/key.pem" -out "$T/cert.pem" -days 2 -subj "/CN=localhost" -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" 2>/dev/null
printf '{"server":"localhost:%s","school":"testschule","user":"test.user","key":"GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"}\n' "$PORT" > "$T/secret.json"; chmod 600 "$T/secret.json"
export WIDGETDECK_UNTIS_FILE="$T/secret.json" WIDGETDECK_UNTIS_CAFILE="$T/cert.pem" XDG_CACHE_HOME="$T/cache"
start() { [ -n "$MPID" ] && kill "$MPID" 2>/dev/null; wait "$MPID" 2>/dev/null; python3 "$MOCK" "$PORT" "$T/cert.pem" "$T/key.pem" "$1" >"$T/mock.log" 2>&1 & MPID=$!; sleep 1; }
st() { python3 -I "$CLIENT" fetch | jq -r .state; }
python3 -I -c "
import importlib.util
sp=importlib.util.spec_from_file_location('u','$CLIENT'); u=importlib.util.module_from_spec(sp); sp.loader.exec_module(u)
assert u.totp('GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ', 59)=='287082'" && ok "TOTP matches the RFC 6238 vector" || bad "TOTP" "vector"
check "no secret -> unconfigured" "$(WIDGETDECK_UNTIS_FILE=$T/nonexistent python3 -I "$CLIENT" fetch | jq -r .state)" unconfigured
start ok;       check "login + timetable" "$(st)" ok
n="$(python3 -I "$CLIENT" fetch | jq '.lessons|length')"; check "lessons returned" "$n" 6
note="$(python3 -I "$CLIENT" fetch | jq -r '[.lessons[].note]|join(" ")')"
case "$note" in *@*|*123456789*) bad "sanitising" "$note" ;; *) ok "e-mail address and long number removed from notes" ;; esac
check "cache file is private" "$(stat -c %a "$T/cache/widgetdeck/timetable.json")" 600
check "verify ok" "$(python3 -I "$CLIENT" verify)" ok
start revoked;  check "revoked key -> expired, cache kept" "$(python3 -I "$CLIENT" fetch | jq -r '"\(.state) \(.lessons|length)"')" "expired 6"
check "verify auth" "$(python3 -I "$CLIENT" verify)" auth
start broken;   check "server error -> stale with cache" "$(python3 -I "$CLIENT" fetch | jq -r '"\(.state) \(.lessons|length)"')" "stale 6"
kill "$MPID"; wait "$MPID" 2>/dev/null; MPID=""
check "server down -> stale with cache" "$(st)" stale
rm -rf "$T/cache"; check "server down, no cache -> offline" "$(st)" offline
start ok;       check "untrusted certificate is refused" "$(WIDGETDECK_UNTIS_CAFILE='' python3 -I "$CLIENT" verify)" net
if grep -rq GEZDGNBVGY3TQOJQ "$T/cache" "$T/mock.log" 2>/dev/null; then bad "secrecy" "key found in cache or log"; else ok "key is not in the cache or the server log"; fi
out="$(python3 -I "$CLIENT" fetch; python3 -I "$CLIENT" verify; python3 -I "$CLIENT" doctor 2>&1)"
case "$out" in *GEZDGNBVGY3TQOJQ*|*test.user*|*testschule*|*localhost*) bad "output" "secret value printed" ;; *) ok "no key, user, school or server name in any output" ;; esac
exit "$fail"
