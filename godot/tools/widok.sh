#!/bin/sh
# widok z gry bez okna (gdy nie wolno otwierać okien testowych): gra eksportuje wycinek świata, Blender go renderuje
#   ./tools/widok.sh wynik.png "x,z" yaw [pitch=0] [promień=70] [oczy=1.7] [fov=75]
# x,z — miejsce kamery na planie miasta; yaw jak w grze (0 patrzy na −z, 90 na −x). RES=960x540 zmienia rozdzielczość.
DIR="$(cd "$(dirname "$0")/.." && pwd)"
SP="${CR_OUT:-${TMPDIR:-/tmp}/czarny-rynek}"
mkdir -p "$SP"
OUT=$1; AT=$2; YAW=${3:-0}; PITCH=${4:-0}; R=${5:-70}; EYE=${6:-1.7}; FOV=${7:-75}
X=${AT%,*}; Z=${AT#*,}
LINE=$(/Applications/Godot.app/Contents/MacOS/Godot --headless --audio-driver Dummy --path "$DIR" -- --autostart --test --glb="$SP/widok.glb" --at="$AT" --r="$R" 2>&1 | grep "^GLB")
Y=$(echo "$LINE" | sed -n 's/.*y=\([-0-9.]*\).*/\1/p')
[ -z "$Y" ] && { echo "eksport nieudany: $LINE"; exit 1; }
RES=${RES:-960x540}
/Applications/Blender.app/Contents/MacOS/Blender -b --python "$DIR/tools/blender/widok.py" -- "$SP/widok.glb" "$OUT" \
  "$(echo "$X * 0.56" | bc -l)" "$(echo "$Y + $EYE" | bc -l)" "$(echo "$Z * 0.56" | bc -l)" "$YAW" "$PITCH" "$FOV" "${RES%x*}" "${RES#*x}" 2>&1 | grep -E "WIDOK|Error|Traceback" | head -3
