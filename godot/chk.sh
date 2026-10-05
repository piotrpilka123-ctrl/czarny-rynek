#!/bin/sh
# szybkie sprawdzenie skryptów: wczytuje projekt bez okna i wypisuje błędy
cd "$(dirname "$0")"
/Applications/Godot.app/Contents/MacOS/Godot --headless --audio-driver Dummy --path . --quit-after ${1:-3} -- $2 $3 $4 $5 2>&1 | grep -v "^\s*$" | grep -iE "error|warning|at:|TEST|SHOT" | head -${N:-40}
