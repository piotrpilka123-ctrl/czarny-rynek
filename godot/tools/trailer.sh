#!/bin/sh
# nagrywa klatki zwiastuna: ./tools/trailer.sh <folder> [lista ujęć po przecinku]
# potem: python3 tools/soundtrack.py <folder>/beat.wav audio.wav 45
#        swift tools/encode.swift <folder> audio.wav zwiastun.mp4 30
OUT=${1:?podaj folder na klatki}
ONLY=$2
DIR="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$OUT"
: > "$OUT/log.txt"
if [ -n "$ONLY" ]; then EXTRA="--only=$ONLY"; fi
open -g -n -W -a /Applications/Godot.app --args --path "$DIR" --audio-driver Dummy --fixed-fps 30 --resolution 1920x1080 --log-file "$OUT/log.txt" -- --autostart --mute --quality=high --trailer="$OUT" $EXTRA
grep -E "TRAILER|ERROR|at: " "$OUT/log.txt" | grep -v "_free_rids\|cleanup\|clear (" | head -60
