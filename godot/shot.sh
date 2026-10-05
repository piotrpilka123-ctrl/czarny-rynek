#!/bin/sh
# zrzut ekranu z gry (okno w tle, bez dźwięku): ./shot.sh nazwa [argumenty gry...]
# wynik trafia do folderu tymczasowego: $TMPDIR/czarny-rynek/nazwa.png
DIR="$(cd "$(dirname "$0")" && pwd)"
SP="${CR_OUT:-${TMPDIR:-/tmp}/czarny-rynek}"
mkdir -p "$SP"
NAME=$1; shift
: > "$SP/$NAME.log"
open -g -n -W -a /Applications/Godot.app --args --path "$DIR" --audio-driver Dummy --log-file "$SP/$NAME.log" -- --shot="$SP/$NAME.png" "$@"
grep -v "^\s*$" "$SP/$NAME.log" | grep -iE "error|warning|at:|SHOT" | head -${N:-30}
ls -la "$SP/$NAME.png" 2>&1 | awk '{print $5, $9}'
