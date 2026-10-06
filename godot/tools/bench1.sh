#!/bin/sh
# Pomiar jednego widoku: ./tools/bench1.sh etykieta "x,z" yaw hour [argumenty gry]
DIR="$(cd "$(dirname "$0")/.." && pwd)"
SP="${CR_OUT:-${TMPDIR:-/tmp}/czarny-rynek}"; mkdir -p "$SP"
L=$1; pos=$2; yaw=$3; hour=$4; shift; shift; shift; shift
n="b1_$L"
for try in 1 2; do
  : > "$SP/$n.log"
  (open -g -n -W -a /Applications/Godot.app --args --path "$DIR" --audio-driver Dummy --resolution 2448x1440 --log-file "$SP/$n.log" -- --shot="$SP/$n.png" --hidden --mute --autostart --loc=out --frames=260 --bench --hour=$hour --yaw=$yaw --pos=$pos --quality=${Q:-med} "$@" &)
  ok=0; for k in $(seq 1 80); do sleep 1; grep -q "SHOT" "$SP/$n.log" 2>/dev/null && { ok=1; break; }; done; sleep 1
  [ $ok = 1 ] && break; pkill -f "shot=$SP/$n.png"; sleep 1
done
echo "$n $(grep -E '^BENCH' "$SP/$n.log") $(grep -E '^SHOT' "$SP/$n.log" | sed 's/.*draw_calls/draw_calls/' | cut -c1-60)"
