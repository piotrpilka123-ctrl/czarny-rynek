#!/bin/sh
# poprawia „Cannot infer the type” w skrypcie ładowanym leniwie (selftest)
F=${1:-scripts/selftest.gd}
for i in 1 2 3 4 5 6 7 8 9 10; do
  out=$(/Applications/Godot.app/Contents/MacOS/Godot --headless --audio-driver Dummy --path . --check-only --script $F 2>&1 | grep -A1 "Cannot infer" | head -4)
  [ -z "$out" ] && break
  name=$(echo "$out" | sed -n 's/.*type of "\([a-z_0-9A-Z]*\)" variable.*/\1/p' | head -1)
  line=$(echo "$out" | sed -n 's/.*gd:\([0-9]*\).*/\1/p' | head -1)
  echo "fix $name $line"
  sed -i '' "${line}s/var $name :=/var $name =/" $F
done
/Applications/Godot.app/Contents/MacOS/Godot --headless --audio-driver Dummy --path . --check-only --script $F 2>&1 | grep -A2 "Parse Error" | head
