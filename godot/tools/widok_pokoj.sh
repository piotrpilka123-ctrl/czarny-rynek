#!/bin/sh
# widok wnętrza bez okna: ./tools/widok_pokoj.sh wynik.png pokój "x,y,z" "cel_x,cel_y,cel_z" [fov=70]
# współrzędne względem środka pokoju (x w prawo, y od podłogi, z w głąb); nazwy pokojów jak w D.ROOMS (safe, lab, klub…)
DIR="$(cd "$(dirname "$0")/.." && pwd)"
SP="${CR_OUT:-${TMPDIR:-/tmp}/czarny-rynek}"
mkdir -p "$SP"
OUT=$1; ROOM=$2; FROM=$3; TO=$4; FOV=${5:-70}
LINE=$(/Applications/Godot.app/Contents/MacOS/Godot --headless --audio-driver Dummy --path "$DIR" -- --autostart --test --glb="$SP/pokoj.glb" --room="$ROOM" $EXTRA 2>&1 | grep "^ROOM")
[ -z "$LINE" ] && { echo "eksport nieudany (pokój $ROOM?)"; exit 1; }
set -- $LINE
CX=$2
RES=${RES:-960x540}
P=$(python3 -c "import sys; cx=float(sys.argv[1]); f=[float(v) for v in sys.argv[2].split(',')]; t=[float(v) for v in sys.argv[3].split(',')]; print(cx+f[0], f[1], f[2], 'cel=%s,%s,%s' % (cx+t[0], t[1], t[2]))" "$CX" "$FROM" "$TO")
set -- $P
/Applications/Blender.app/Contents/MacOS/Blender -b --python "$DIR/tools/blender/widok.py" -- "$SP/pokoj.glb" "$OUT" "$1" "$2" "$3" 0 0 "$FOV" "${RES%x*}" "${RES#*x}" "$4" wnetrze=1 2>&1 | grep -E "WIDOK|Error|Traceback" | head -3
echo "pokój: $LINE"
