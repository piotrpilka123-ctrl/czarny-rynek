#!/bin/sh
# Testy i dopiero potem commit: ./tools/commit.sh "komunikat" — przy jakimkolwiek TEST FAIL albo błędzie skryptu nic nie zapisuje.
DIR="$(cd "$(dirname "$0")/.." && pwd)"
L="${TMPDIR:-/tmp}/czarny-rynek/test.log"
if ! "$DIR/tools/runtest.sh" > /dev/null 2>&1; then
  echo "Test nie zakończył się powodzeniem — bez commitu."
  tail -8 "$L"
  exit 1
fi
OK=$(grep -c "TEST ok" "$L")
BAD=$(grep -c "TEST FAIL\|SCRIPT ERROR\|Parse Error" "$L")
echo "testy: $OK ok, $BAD błędów"
if [ "$BAD" != "0" ] || [ "$OK" -lt 100 ] || ! grep -q "TEST PODSUMOWANIE: WSZYSTKO OK (0 błędów)" "$L"; then
  grep -n "TEST FAIL\|SCRIPT ERROR\|Parse Error\|   at: .*gd" "$L" | cut -c1-220 | head -12
  exit 1
fi
cd "$DIR/.." && git add -A && git commit -q -m "$1" && git log --oneline | head -1
