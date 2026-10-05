#!/bin/sh
# zrzut ekranu z gry (okno poza ekranem, bez dźwięku): ./shot.sh nazwa [argumenty gry...]
# wynik: $CR_OUT/nazwa.png (domyślnie folder tymczasowy); RES=1920x1080 zmienia rozdzielczość
DIR="$(cd "$(dirname "$0")" && pwd)"
SP="${CR_OUT:-${TMPDIR:-/tmp}/czarny-rynek}"
mkdir -p "$SP"
NAME=$1; shift
for try in 1 2 3; do
  : > "$SP/$NAME.log"
  (open -g -n -W -a /Applications/Godot.app --args --path "$DIR" --audio-driver Dummy --resolution ${RES:-1600x900} --log-file "$SP/$NAME.log" -- --shot="$SP/$NAME.png" --hidden --mute "$@" &)
  ok=0
  for i in $(seq 1 ${WAIT:-70}); do sleep 1; grep -q "SHOT" "$SP/$NAME.log" 2>/dev/null && { ok=1; break; }; done
  sleep 1
  [ $ok = 1 ] && break
  pkill -f "shot=$SP/$NAME.png"; sleep 1
done
grep -v "^\s*$" "$SP/$NAME.log" | grep -iE "error|warning|at:" | grep -v "_free_rids\|leaked\|still in use\|cleanup\|clear (core" | head -${N:-12}
ls -la "$SP/$NAME.png" 2>&1 | awk '{print $5, $9}'
