#!/usr/bin/env python3
"""Rośliny do upraw rysowane od zera (własne grafiki): konopie w trzech fazach wzrostu
jako karty RGBA. Wynik: assets/nature/gen_konopie_{1,2,3}.png + pliki .import (z mipmapami)."""
import os, random, math
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'nature')
IMPORT = '''[remap]

importer="texture"
type="CompressedTexture2D"

[params]

compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
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


W, H = 512, 768


def leaflet(d, ox, oy, ln, wd, ang, col):
    """jeden wąski listek z ząbkowaną krawędzią"""
    n = 12
    up, dn = [], []
    for i in range(n + 1):
        t = i / n
        x = t * ln
        w = wd * math.sin(math.pi * t ** 0.85) ** 0.9
        if i % 2 == 1:
            w *= 0.82          # ząbki
        up.append((x, w))
        dn.append((x, -w))
    ca, sa = math.cos(ang), math.sin(ang)
    poly = [(ox + x * ca - y * sa, oy + x * sa + y * ca) for x, y in up + dn[::-1]]
    d.polygon(poly, fill=col + (255,))
    dark = tuple(int(c * 0.6) for c in col)
    d.line([(ox, oy), (ox + ln * 0.94 * ca, oy + ln * 0.94 * sa)], fill=dark + (255,), width=max(1, int(wd * 0.14)))


def fan(d, ox, oy, size, ang, col, rnd, fingers=7):
    """liść dłoniasty: kilka listków rozchodzących się z jednego punktu"""
    spread = math.radians(rnd.uniform(62, 80))
    for k in range(fingers):
        t = k / (fingers - 1) - 0.5
        a = ang + t * 2.0 * spread
        ln = size * (1.0 - abs(t) * 1.15) * rnd.uniform(0.92, 1.05)
        c = tuple(max(0, min(255, int(v * rnd.uniform(0.86, 1.1)))) for v in col)
        leaflet(d, ox, oy, max(8.0, ln), max(2.5, ln * 0.115), a, c)


def bud(d, cx, cy, ln, wd, rnd):
    """kwiatostan: szyszka z jasnych grudek i rudych włosków"""
    for i in range(int(ln * 0.9)):
        t = rnd.random()
        y = cy - t * ln
        w = wd * (1.0 - t * 0.8)
        x = cx + rnd.uniform(-w, w)
        r = rnd.uniform(3.0, 6.5) * (1.0 - t * 0.4)
        g = rnd.randint(118, 172)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(int(g * 0.72), g, int(g * 0.46), 255))
    for i in range(int(ln * 0.5)):
        t = rnd.random()
        y = cy - t * ln
        w = wd * (1.0 - t * 0.8)
        x = cx + rnd.uniform(-w, w)
        a = rnd.uniform(0, math.tau)
        d.line([(x, y), (x + math.cos(a) * 5, y + math.sin(a) * 5)], fill=(206, 132, 58, 255), width=1)
    for i in range(int(ln * 0.25)):
        t = rnd.random()
        y = cy - t * ln
        x = cx + rnd.uniform(-wd, wd) * (1.0 - t * 0.8)
        d.point((x, y), fill=(236, 240, 226, 255))


def plant(stage, seed):
    rnd = random.Random(seed)
    im = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    base = (W / 2, H - 6)
    hgt = [0.3, 0.72, 0.95][stage] * (H - 30)
    top = (W / 2 + rnd.uniform(-10, 10), base[1] - hgt)
    stem = (86, 122, 62)
    greens = [(58, 122, 54), (72, 146, 60), (44, 100, 48), (84, 158, 70)]
    sw = [5, 9, 11][stage]
    d.line([base, top], fill=stem + (255,), width=sw)
    nodes = [4, 11, 14][stage]
    items = []
    for i in range(nodes):
        t = (i + 0.6) / (nodes + 0.4)
        y = base[1] - hgt * t
        x = base[0] + (top[0] - base[0]) * t
        reach = [80, 190, 200][stage] * (1.0 - t * 0.72) * rnd.uniform(0.85, 1.1)
        for side in (-1, 1):
            a = -math.pi / 2 + side * math.radians(rnd.uniform(46, 72))
            ex = x + math.cos(a) * reach
            ey = y + math.sin(a) * reach
            d.line([(x, y), (ex, ey)], fill=stem + (255,), width=max(2, sw // 2))
            size = [70, 118, 104][stage] * (1.0 - t * 0.3) * rnd.uniform(0.85, 1.15)
            # liście wzdłuż całej gałązki: od pnia po czubek
            steps = [1, 3, 3][stage]
            for k in range(steps + 1):
                q = (k + 0.35) / (steps + 0.35)
                mx, my = x + (ex - x) * q, y + (ey - y) * q
                items.append(('fan', mx, my, size * (0.7 + 0.3 * q), a + rnd.uniform(-0.9, 0.9)))
            if stage == 2:
                items.append(('bud', ex, ey + 10, rnd.uniform(46, 74) * (1.0 - t * 0.25), rnd.uniform(11, 17)))
                if reach > 90:
                    items.append(('bud', x + (ex - x) * 0.55, y + (ey - y) * 0.55 + 8, rnd.uniform(30, 46), rnd.uniform(8, 12)))
        # liście przy samym pniu zasłaniają „drabinkę”
        items.append(('fan', x, y, [50, 92, 82][stage] * rnd.uniform(0.8, 1.1), -math.pi / 2 + rnd.uniform(-1.3, 1.3)))
    # wierzchołek
    for a in (-0.9, -0.45, 0.0, 0.45, 0.9):
        items.append(('fan', top[0], top[1] + 16, [56, 96, 84][stage] * rnd.uniform(0.9, 1.1), -math.pi / 2 + a))
    if stage == 2:
        items.append(('bud', top[0], top[1] + 96, 176, 26))
    # najpierw liście z tyłu (ciemniejsze), potem z przodu, na końcu kwiatostany
    rnd.shuffle(items)
    for it in items:
        if it[0] == 'fan':
            fan(d, it[1], it[2], it[3], it[4], rnd.choice(greens), rnd)
    for it in items:
        if it[0] == 'bud':
            bud(d, it[1], it[2], it[3], it[4], rnd)
    # lekkie zmiękczenie krawędzi i ciemniejszy dół (cień własny)
    a = im.split()[3].filter(ImageFilter.GaussianBlur(0.6))
    shade = Image.new('L', (W, H), 255)
    sd = ImageDraw.Draw(shade)
    for y in range(H):
        sd.line([(0, y), (W, y)], fill=int(255 * (0.72 + 0.28 * (1.0 - y / H))))
    rgb = im.convert('RGB')
    px = rgb.load()
    sh = shade.load()
    for y in range(H):
        k = sh[0, y] / 255.0
        for x in range(W):
            r, g, b = px[x, y]
            px[x, y] = (int(r * k), int(g * k), int(b * k))
    out = Image.merge('RGBA', (*rgb.split(), a))
    return out


if __name__ == '__main__':
    for st in range(3):
        name = 'gen_konopie_%d.png' % (st + 1)
        im = plant(st, 40 + st * 7)
        im.save(os.path.join(OUT, name))
        with open(os.path.join(OUT, name + '.import'), 'w') as f:
            f.write(IMPORT)
        print(name, im.size)
