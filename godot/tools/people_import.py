#!/usr/bin/env python3
"""Pobiera wybrane postacie z biblioteki Microsoft Rocketbox (licencja MIT, github.com/microsoft/Microsoft-Rocketbox)
i przygotowuje je dla gry: model FBX bez zmian, tekstury zmniejszone i zapisane jako JPG/PNG.

  python3 tools/people_import.py KATALOG_ROBOCZY id=Ścieżka/Do/Awatara [id=...]
  np. m10=Adults/Male_Adult_10

Wynik: assets/people/<id>/<id>.fbx, <id>_<część>.jpg (kolor), <id>_<część>_n.jpg (normalna), <id>_opacity.png (włosy z przezroczystością)."""
import sys, os, re, json, urllib.request, urllib.parse, concurrent.futures as cf
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'people')
RAW = 'https://raw.githubusercontent.com/microsoft/Microsoft-Rocketbox/master/'
work = sys.argv[1]
os.makedirs(work, exist_ok=True)

TEX_IMPORT = '''[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=%d
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
'''


def fetch(path, dst):
    if os.path.exists(dst) and os.path.getsize(dst) > 0:
        return
    url = RAW + urllib.parse.quote(path)
    for _ in range(3):
        try:
            data = urllib.request.urlopen(url, timeout=180).read()
            open(dst, 'wb').write(data)
            return
        except Exception as e:
            err = e
    raise SystemExit('nie pobrano %s: %s' % (path, err))


def tga_names(fbx):
    data = open(fbx, 'rb').read()
    return sorted(set(m.decode('ascii', 'ignore').lower() for m in re.findall(rb'[A-Za-z0-9_]+\.tga', data)))


def one(spec):
    pid, src = spec.split('=')
    name = src.split('/')[-1]
    base = 'Assets/Avatars/%s/' % src
    raw = os.path.join(work, name)
    os.makedirs(raw, exist_ok=True)
    fbx = os.path.join(raw, name + '.fbx')
    fetch(base + 'Export/%s.fbx' % name, fbx)
    names = tga_names(fbx)
    dst = os.path.join(OUT, pid)
    os.makedirs(dst, exist_ok=True)
    open(os.path.join(dst, pid + '.fbx'), 'wb').write(open(fbx, 'rb').read())
    parts = {}
    for t in names:
        m = re.match(r'([a-z]\d+)_(\w+?)_(color|normal|specular)\.tga', t)
        if not m or m.group(3) == 'specular':
            continue
        prefix, part, kind = m.groups()
        tga = os.path.join(raw, t)
        fetch(base + 'Textures/' + t, tga)
        im = Image.open(tga)
        if kind == 'color' and im.mode == 'RGBA' and part.endswith('opacity'):
            im = im.resize((512, 512), Image.LANCZOS)
            f = '%s_%s.png' % (pid, part)
            im.save(os.path.join(dst, f), optimize=True)
            nm = 0
        elif kind == 'color':
            size = 1024 if im.size[0] >= 2048 else im.size[0]
            im = im.convert('RGB').resize((size, size), Image.LANCZOS)
            f = '%s_%s.jpg' % (pid, part)
            im.save(os.path.join(dst, f), quality=90)
            nm = 0
        else:
            size = 512 if im.size[0] >= 1024 else im.size[0]
            im = im.convert('RGB').resize((size, size), Image.LANCZOS)
            f = '%s_%s_n.jpg' % (pid, part)
            im.save(os.path.join(dst, f), quality=92)
            nm = 1
        imp = os.path.join(dst, f + '.import')
        if not os.path.exists(imp):
            open(imp, 'w').write(TEX_IMPORT % nm)
        parts.setdefault(part, {})[kind] = f
        parts[part]['prefix'] = prefix
    json.dump({'source': src, 'parts': parts}, open(os.path.join(dst, pid + '.json'), 'w'), indent=1)
    return pid, sorted(parts)


with cf.ThreadPoolExecutor(4) as ex:
    for pid, parts in ex.map(one, sys.argv[2:]):
        print(pid, parts)
