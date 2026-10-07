#!/bin/sh
# kadr scenki z paczką pod drzwiami, bez okna: ./tools/widok_paczka.sh wynik.png [worek=1] [strunowy=1] [najazd=1]
# worek / strunowy: 0 = jeszcze za drzwiami, 1 = leży w pokoju; najazd: postęp ruchu kamery 0…1 (dojazd do drzwi), 1…2 (zbliżenie z góry)
DIR="$(cd "$(dirname "$0")/.." && pwd)"
SP="${CR_OUT:-${TMPDIR:-/tmp}/czarny-rynek}"
mkdir -p "$SP"
OUT=$1; K=${2:-1}; K2=${3:-1}; KAM=${4:-1}
LINE=$(/Applications/Godot.app/Contents/MacOS/Godot --headless --audio-driver Dummy --path "$DIR" -- --autostart --test --glb="$SP/pokoj.glb" --room=safe --paczka="$K,$K2" --kam="$KAM" 2>&1 | grep "^CAM")
[ -z "$LINE" ] && { echo "eksport nieudany"; exit 1; }
set -- $LINE
RES=${RES:-960x540}
/Applications/Blender.app/Contents/MacOS/Blender -b --python "$DIR/tools/blender/widok.py" -- "$SP/pokoj.glb" "$OUT" "$2" "$3" "$4" 0 0 "$8" "${RES%x*}" "${RES#*x}" "cel=$5,$6,$7" wnetrze=1 2>&1 | grep -E "WIDOK|Error|Traceback" | head -3
