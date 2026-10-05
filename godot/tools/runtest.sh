#!/bin/sh
# autotest bez okna: ./tools/runtest.sh [sekundy] [dodatkowe argumenty gry]
#   ./tools/runtest.sh 90                                  — test rozgrywki
#   ./tools/runtest.sh 240 --sim=48 --runs=3 --lazy=0.35   — symulacja ekonomii
T=${1:-60}; [ $# -gt 0 ] && shift
DIR="$(cd "$(dirname "$0")/.." && pwd)"
SP="${CR_OUT:-${TMPDIR:-/tmp}/czarny-rynek}"
mkdir -p "$SP"
LOG="$SP/test.log"
/Applications/Godot.app/Contents/MacOS/Godot --headless --audio-driver Dummy --path "$DIR" -- --autostart --test "$@" > "$LOG" 2>&1 &
PID=$!
i=0
while kill -0 $PID 2>/dev/null && [ $i -lt $T ]; do sleep 1; i=$((i+1)); done
kill $PID 2>/dev/null && echo "PRZERWANO po $T s"
grep -E "TEST|SIM|ZYSK|ERROR|at: |rror" "$LOG" | grep -v "_free_rids\|leaked\|still in use" | head -${N:-150}
