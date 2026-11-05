#!/bin/bash
# Tests for spotlight-watchdog. Fakes mdfind, so they run anywhere and touch nothing real.
# Usage: tests/run.sh
# Assertions are single-quoted on purpose: check() evals them after each run.
# shellcheck disable=SC2016
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
pass=0 fail=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Fake mdfind: answers the probe query if FAKE_PROBE=1, and app queries from $FAKE_INDEX.
FAKE_MDFIND="$TMP/mdfind"
cat > "$FAKE_MDFIND" <<'EOF'
#!/bin/bash
dir=$2
case "$3" in
  -name) [ "${FAKE_PROBE:-1}" = 1 ] && ls "$dir"/"$4"* ;;
  kMDItemContentType*) grep -F "$dir/" "$FAKE_INDEX" ;;
esac 2>/dev/null
exit 0
EOF
chmod +x "$FAKE_MDFIND"

setup() {
  T=$(mktemp -d "$TMP/case.XXXX")
  T=$(cd "$T" && pwd -P)
  mkdir -p "$T/apps"
  : > "$T/index"
  export MDFIND="$FAKE_MDFIND" FAKE_INDEX="$T/index" FAKE_PROBE=1 \
    SPOTLIGHT_WATCHDOG_PROBE_DIR="$T/probe" SPOTLIGHT_WATCHDOG_APP_DIRS="$T/apps" \
    SPOTLIGHT_WATCHDOG_LOG="$T/log" SPOTLIGHT_WATCHDOG_TIMEOUT=0 SPOTLIGHT_WATCHDOG_INTERVAL=0 SPOTLIGHT_WATCHDOG_GRACE=0
}

# add_app NAME [indexed]
add_app() {
  mkdir -p "$T/apps/$1.app"
  [ "${2:-}" = indexed ] && echo "$T/apps/$1.app" >> "$T/index"
  return 0
}

run() { out=$("$ROOT/spotlight-watchdog" --quiet 2>&1); code=$?; }

check() { # check NAME CONDITION
  if eval "$2"; then pass=$((pass + 1)); echo "ok   $1"
  else fail=$((fail + 1)); echo "FAIL $1"; echo "     output: $out (exit $code)"; fi
}

setup; add_app Alpha indexed; add_app "Beta Two" indexed; run
check "healthy index exits 0" '[ $code -eq 0 ] && [ "$out" = "Spotlight OK" ]'
check "healthy run is logged" 'grep -q " OK$" "$T/log"'

setup; FAKE_PROBE=0; add_app Alpha indexed; run
check "unindexed probe file is reported" '[ $code -eq 1 ] && [[ $out == *"new file was not indexed"* ]]'
check "broken run is logged" 'grep -q "BROKEN" "$T/log"'

setup; add_app Alpha indexed; add_app "Beta Two"; add_app Gamma; run
check "missing apps are listed" '[ $code -eq 1 ] && [[ $out == *"apps not indexed: Beta Two, Gamma"* ]]'
check "indexed app is not listed" '[[ $out != *Alpha* ]]'

setup; SPOTLIGHT_WATCHDOG_GRACE=60; add_app Fresh; run
check "recently installed app is skipped" '[ $code -eq 0 ]'

setup; add_app Real indexed; ln -s "$T/apps/Real.app" "$T/apps/Link.app"; run
check "symlinked app is skipped" '[ $code -eq 0 ]'

setup; SPOTLIGHT_WATCHDOG_APP_DIRS="$T/apps/"; add_app Alpha indexed; run
check "trailing slash in app folder is fine" '[ $code -eq 0 ]'

setup; touch "$T/apps/NotAnApp.app"; run
check "plain file named .app is ignored" '[ $code -eq 0 ]'

setup; run
check "probe file is cleaned up" '[ -z "$(ls "$T/probe")" ]'

setup; SPOTLIGHT_WATCHDOG_APP_DIRS="$T/apps:$T/does-not-exist"; add_app Alpha indexed; run
check "missing app folder is ignored" '[ $code -eq 0 ]'

setup; out=$("$ROOT/spotlight-watchdog" --bogus 2>&1); code=$?
check "unknown flag exits 2" '[ $code -eq 2 ]'

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
