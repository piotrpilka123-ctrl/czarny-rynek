#!/bin/sh
# seria ujęć z kamery filmowej: ./tools/tour.sh lista.json katalog_wyjściowy [szerokość] [argumenty gry]
DIR="$(cd "$(dirname "$0")/.." && pwd)"
LIST=$1; OUT=$2; W=${3:-960}; shift; shift; [ $# -gt 0 ] && shift
SP="${CR_OUT:-${TMPDIR:-/tmp}/czarny-rynek}"; mkdir -p "$SP" "$OUT"
LOG="$SP/tour.log"
for try in 1 2 3; do
  : > "$LOG"
  (open ${HIDDEN:+-g} -n -W -a /Applications/Godot.app --args --path "$DIR" --audio-driver Dummy --resolution ${RES:-1600x900} --log-file "$LOG" -- --tour="$LIST" --out="$OUT" --tourw=$W ${HIDDEN:+--hidden} --mute --autostart --loc=out --quality=high "$@" &)
  n=0; last=-1; stall=0
  while [ $stall -lt 45 ]; do
    sleep 2
    grep -q "TOUR_END\|Quit" "$LOG" 2>/dev/null && break
    pgrep -f "tour=$LIST" >/dev/null || break
    n=$(grep -c "^TOUR " "$LOG" 2>/dev/null); [ "$n" = "$last" ] && stall=$((stall+1)) || stall=0; last=$n
  done
  pgrep -f "tour=$LIST" >/dev/null && { pkill -f "tour=$LIST"; sleep 2; echo "zawieszone po $n ujęciach, ponawiam"; continue; }
  break
done
echo "ujęć: $(grep -c '^TOUR ' "$LOG")"; grep -E "ERROR|rror" "$LOG" | grep -v _free_rids | head -5
