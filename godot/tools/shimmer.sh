#!/bin/sh
# Miara migotania obrazu w ruchu: dwie klatki z kamerą przesuniętą o ~3 cm, średnia różnica pikseli.
# Użycie: ./tools/shimmer.sh etykieta [argumenty gry]
DIR="$(cd "$(dirname "$0")/.." && pwd)"
SP="${CR_OUT:-${TMPDIR:-/tmp}/czarny-rynek}"; mkdir -p "$SP"
L=$1; shift
one() { n=$1; pos=$2; shift; shift; for try in 1 2; do : > "$SP/$n.log"; (open -g -n -W -a /Applications/Godot.app --args --path "$DIR" --audio-driver Dummy --resolution 2448x1440 --log-file "$SP/$n.log" -- --shot="$SP/$n.png" --mute --autostart --loc=out --nohud --raw --frames=100 --hour=14 --yaw=265 --pitch=-30 --quality=med --pos=$pos "$@" &); ok=0; for i in $(seq 1 45); do sleep 2; grep -q SHOT "$SP/$n.log" 2>/dev/null && { ok=1; break; }; done; sleep 1; [ $ok = 1 ] && return; pkill -f "shot=$SP/$n.png"; sleep 2; done; }
one "${L}_a" 30,22 "$@"
one "${L}_b" 30.05,22 "$@"
python3 - "$SP" "$L" <<'PY'
import sys, os
from PIL import Image, ImageChops, ImageStat
sp, l = sys.argv[1], sys.argv[2]
a = Image.open(os.path.join(sp, l + '_a.png')).convert('L')
b = Image.open(os.path.join(sp, l + '_b.png')).convert('L')
w, h = a.size
box = (w // 4, h // 2, 3 * w // 4, h - 40)          # dolna połowa kadru: grunt
d = ImageChops.difference(a.crop(box), b.crop(box))
# wysokie częstotliwości pojedynczej klatki (ziarno) i różnica między klatkami (migotanie)
from PIL import ImageFilter
ca = a.crop(box)
grain = ImageStat.Stat(ImageChops.difference(ca, ca.filter(ImageFilter.GaussianBlur(1.5)))).mean[0]
print("MIGOTANIE %-10s różnica klatek %.2f   ziarno %.2f" % (l, ImageStat.Stat(d).mean[0], grain))
PY
