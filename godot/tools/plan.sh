#!/bin/sh
# plan miasta z góry (bez okna): ./tools/plan.sh wynik.png [x0,z0,x1,z1]
DIR="$(cd "$(dirname "$0")/.." && pwd)"
/Applications/Godot.app/Contents/MacOS/Godot --headless --audio-driver Dummy --path "$DIR" -- --autostart --test --plan="$1" ${2:+--box=$2} 2>&1 | grep -E "PLAN|ERROR|rror" | head -5
