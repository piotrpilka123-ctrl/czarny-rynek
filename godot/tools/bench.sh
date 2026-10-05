#!/bin/sh
# Pomiar wydajności w kilku stałych miejscach (okno poza ekranem, 2448x1440): ./tools/bench.sh etykieta [argumenty gry]
DIR="$(cd "$(dirname "$0")/.." && pwd)"
SP="${CR_OUT:-${TMPDIR:-/tmp}/czarny-rynek}"; mkdir -p "$SP"
L=$1; shift
i=0
for v in "20,-60 200 14" "-28,-100 40 14" "62,16 300 14" "0,100 180 22.5" "60,88 90 18.2"; do
  set -- $v "$@"; pos=$1; yaw=$2; hour=$3; shift; shift; shift
  i=$((i+1)); n="bench_${L}_$i"
  for try in 1 2; do
    : > "$SP/$n.log"
    (open -g -n -W -a /Applications/Godot.app --args --path "$DIR" --audio-driver Dummy --resolution 2448x1440 --log-file "$SP/$n.log" -- --shot="$SP/$n.png" --hidden --mute --autostart --loc=out --frames=140 --hour=$hour --yaw=$yaw --pos=$pos --quality=${Q:-med} "$@" &)
    ok=0; for k in $(seq 1 80); do sleep 1; grep -q "SHOT" "$SP/$n.log" 2>/dev/null && { ok=1; break; }; done; sleep 1
    [ $ok = 1 ] && break; pkill -f "shot=$SP/$n.png"; sleep 1
  done
  echo "$n pos=$pos $(grep -E '^RENDER' "$SP/$n.log") $(grep -E '^SHOT' "$SP/$n.log" | sed 's/.*draw_calls/draw_calls/' | cut -c1-90)"
done
