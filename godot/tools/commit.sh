#!/bin/sh
# Testy i dopiero potem commit: ./tools/commit.sh "komunikat" — przy jakimkolwiek TEST FAIL albo błędzie skryptu nic nie zapisuje.
DIR="$(cd "$(dirname "$0")/.." && pwd)"
L="${TMPDIR:-/tmp}/czarny-rynek/test.log"
"$DIR/tools/runtest.sh" >/dev/null 2>&1
OK=$(grep -c "TEST ok" "$L")
BAD=$(grep -c "TEST FAIL\|SCRIPT ERROR\|Parse Error" "$L")
echo "testy: $OK ok, $BAD błędów"
if [ "$BAD" != "0" ] || [ "$OK" -lt 100 ]; then
  grep -n "TEST FAIL\|SCRIPT ERROR\|Parse Error\|   at: .*gd" "$L" | cut -c1-220 | head -12
  exit 1
fi
cd "$DIR/.." && git add -A && git commit -q -m "$1

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" && git log --oneline | head -1
