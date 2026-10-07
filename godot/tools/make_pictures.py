#!/usr/bin/env python3
"""Obrazki na ściany wnętrz, rysowane od zera (własne grafiki): plakat koncertu, gala boksu,
kalendarz, „jeleń na rykowisku”, plakat z autem. Wynik: assets/pictures/pic_*.png (512×725)."""
import os, random, math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'assets', 'pictures')
FONTS = os.path.join(ROOT, 'assets', 'fonts')
os.makedirs(OUT, exist_ok=True)
W, H = 512, 725
IMPORT = open(os.path.join(ROOT, 'assets', 'graffiti', 'poster_00.png.import')).read() if os.path.exists(os.path.join(ROOT, 'assets', 'graffiti', 'poster_00.png.import')) else ''


def font(size, name='barlowc.ttf'):
    p = os.path.join(FONTS, name)
    try:
        return ImageFont.truetype(p, size)
    except Exception:
        return ImageFont.load_default()


def center(d, y, text, f, fill):
    w = d.textlength(text, font=f)
    d.text(((W - w) / 2, y), text, font=f, fill=fill)


def grain(im, amount=10, seed=1):
    rnd = random.Random(seed)
    px = im.load()
    for y in range(0, H, 1):
        for x in range(0, W, 1):
            if (x * 7 + y * 13) % 3 == 0:
                r, g, b = px[x, y][:3]
                n = rnd.randint(-amount, amount)
                px[x, y] = (max(0, min(255, r + n)), max(0, min(255, g + n)), max(0, min(255, b + n)))
    return im


def koncert():
    im = Image.new('RGB', (W, H), (18, 16, 22))
    d = ImageDraw.Draw(im)
    rnd = random.Random(5)
    for i in range(26):
        x = rnd.randint(-60, W)
        c = rnd.choice([(214, 46, 80), (240, 170, 40), (60, 200, 190)])
        d.polygon([(x, H), (x + rnd.randint(30, 90), H), (W / 2 + rnd.randint(-40, 40), 230)], fill=tuple(int(v * 0.35) for v in c))
    d.ellipse([W / 2 - 150, 150, W / 2 + 150, 450], fill=(240, 170, 40))
    d.ellipse([W / 2 - 120, 180, W / 2 + 120, 420], fill=(18, 16, 22))
    d.rectangle([0, 470, W, 478], fill=(214, 46, 80))
    center(d, 28, 'BLOKERSI', font(112), (245, 240, 230))
    center(d, 492, 'NIGHT ON THE ESTATE', font(58), (240, 170, 40))
    center(d, 566, 'NEON CLUB  •  SATURDAY 10 PM', font(34), (230, 226, 216))
    center(d, 616, 'ENTRY 20 ZŁ', font(42), (214, 46, 80))
    center(d, 676, 'support: DJ ŻELBET', font(26), (150, 146, 140))
    return grain(im, 8, 2)


def boks():
    im = Image.new('RGB', (W, H), (150, 30, 28))
    d = ImageDraw.Draw(im)
    for i in range(18):
        a = i * math.tau / 18
        d.polygon([(W / 2, 330), (W / 2 + math.cos(a) * 700, 330 + math.sin(a) * 700), (W / 2 + math.cos(a + 0.17) * 700, 330 + math.sin(a + 0.17) * 700)], fill=(178, 44, 36))
    # dwie rękawice naprzeciw siebie
    for sx in (-1, 1):
        cx = W / 2 + sx * 96
        d.ellipse([cx - 78, 250, cx + 78, 410], fill=(24, 22, 26))
        d.ellipse([cx - sx * 20 - 44, 232, cx - sx * 20 + 44, 320], fill=(24, 22, 26))
        d.rectangle([cx - 46, 396, cx + 46, 470], fill=(236, 230, 214))
    center(d, 30, 'BOXING GALA', font(104), (248, 236, 200))
    center(d, 150, '“HUTNIK” SPORTS HALL', font(36), (24, 22, 26))
    center(d, 500, 'MAIN EVENT', font(60), (248, 236, 200))
    center(d, 572, 'KOWALSKI  vs  NOWAK', font(46), (24, 22, 26))
    center(d, 644, 'tickets at the door and at Staś\'s', font(28), (248, 236, 200))
    return grain(im, 8, 3)


def kalendarz():
    im = Image.new('RGB', (W, H), (238, 234, 222))
    d = ImageDraw.Draw(im)
    # zdjęcie: góry o zachodzie
    for y in range(300):
        t = y / 300
        d.line([(0, y), (W, y)], fill=(int(250 - 60 * t), int(170 + 30 * t), int(90 + 110 * t)))
    d.ellipse([330, 70, 420, 160], fill=(255, 236, 170))
    rnd = random.Random(8)
    for k, col in enumerate([(92, 104, 140), (62, 74, 104), (38, 48, 70)]):
        pts = [(0, 300)]
        x = 0
        while x <= W:
            pts.append((x, 150 + k * 46 + rnd.randint(-36, 36)))
            x += 48
        pts.append((W, 300))
        d.polygon(pts, fill=col)
    d.rectangle([0, 300, W, 372], fill=(170, 40, 36))
    center(d, 306, 'OCTOBER', font(60), (250, 244, 230))
    days = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU']
    f = font(30)
    for i, dn in enumerate(days):
        d.text((34 + i * 66, 386), dn, font=f, fill=(170, 40, 36) if i >= 5 else (60, 60, 66))
    n = 1
    for r in range(5):
        for c in range(7):
            if r == 0 and c < 2:
                continue
            if n > 31:
                break
            col = (170, 40, 36) if c >= 5 else (30, 30, 36)
            d.text((38 + c * 66, 432 + r * 54), str(n), font=font(36), fill=col)
            if n in (5, 9, 13):
                d.ellipse([28 + c * 66, 428 + r * 54, 84 + c * 66, 476 + r * 54], outline=(30, 60, 170), width=4)
            n += 1
    center(d, 694, '“Żelbet” Wholesale wishes you a good year', font(22), (120, 116, 108))
    d.ellipse([W / 2 - 9, 6, W / 2 + 9, 24], fill=(60, 60, 60))
    return im


def jelen():
    im = Image.new('RGB', (W, H), (0, 0, 0))
    d = ImageDraw.Draw(im)
    for y in range(H):
        t = y / H
        d.line([(0, y), (W, y)], fill=(int(226 - 110 * t), int(170 - 60 * t), int(96 - 30 * t)))
    rnd = random.Random(12)
    # las w tle, polana, jezioro
    for k, col in enumerate([(94, 92, 60), (62, 70, 44), (38, 50, 34)]):
        x = -20
        base = 300 + k * 60
        while x < W:
            hgt = rnd.randint(110, 210) - k * 20
            wd = rnd.randint(46, 80)
            d.polygon([(x, base), (x + wd / 2, base - hgt), (x + wd, base)], fill=col)
            x += wd * 0.6
        d.rectangle([0, base, W, H], fill=col)
    d.ellipse([-80, 500, 360, 640], fill=(120, 150, 150))
    d.ellipse([-40, 520, 300, 610], fill=(170, 190, 180))
    # jeleń: sylwetka z porożem
    bx, by = 330, 470
    body = (58, 36, 22)
    d.ellipse([bx - 80, by - 40, bx + 70, by + 46], fill=body)
    for lx in (-58, -34, 36, 56):
        d.rectangle([bx + lx - 7, by + 20, bx + lx + 7, by + 130], fill=body)
    d.polygon([(bx + 40, by - 20), (bx + 84, by - 120), (bx + 112, by - 110), (bx + 76, by + 10)], fill=body)
    d.ellipse([bx + 70, by - 150, bx + 136, by - 100], fill=body)
    d.polygon([(bx + 126, by - 130), (bx + 160, by - 118), (bx + 128, by - 106)], fill=body)
    for sx, lean in ((0, -1), (22, 1)):
        ax, ay = bx + 86 + sx, by - 146
        d.line([(ax, ay), (ax + lean * 26, ay - 84)], fill=(210, 190, 150), width=6)
        for t in (0.3, 0.55, 0.8):
            px, py = ax + lean * 26 * t, ay - 84 * t
            d.line([(px, py), (px + lean * 30, py - 26)], fill=(210, 190, 150), width=5)
    im = im.filter(ImageFilter.GaussianBlur(0.8))
    return grain(im, 12, 4)


def auto():
    im = Image.new('RGB', (W, H), (16, 20, 30))
    d = ImageDraw.Draw(im)
    for y in range(H):
        t = y / H
        d.line([(0, y), (W, y)], fill=(int(20 + 60 * t), int(24 + 40 * t), int(40 + 20 * t)))
    for i in range(14):
        y = 430 + i * 22
        d.line([(0, y), (W, y)], fill=(230, 90, 40) if i % 2 == 0 else (20, 24, 34), width=3)
    # sylwetka auta z boku
    body = (214, 40, 36)
    d.rounded_rectangle([40, 300, 472, 400], radius=26, fill=body)
    d.polygon([(130, 304), (190, 222), (350, 222), (410, 304)], fill=body)
    d.polygon([(150, 300), (198, 236), (262, 236), (262, 300)], fill=(150, 200, 230))
    d.polygon([(276, 300), (276, 236), (342, 236), (388, 300)], fill=(150, 200, 230))
    for cx in (130, 384):
        d.ellipse([cx - 52, 348, cx + 52, 452], fill=(14, 14, 16))
        d.ellipse([cx - 26, 374, cx + 26, 426], fill=(190, 194, 200))
    d.rectangle([452, 330, 476, 352], fill=(255, 236, 170))
    center(d, 40, 'TURBO', font(150), (248, 240, 220))
    center(d, 520, 'HUTNIK RALLY', font(72), (248, 240, 220))
    center(d, 606, 'special stages: slag heap • ramp • tracks', font(26), (230, 90, 40))
    center(d, 660, '17th edition', font(34), (150, 200, 230))
    return grain(im, 8, 6)


if __name__ == '__main__':
    for name, fn in [('pic_koncert', koncert), ('pic_boks', boks), ('pic_kalendarz', kalendarz), ('pic_jelen', jelen), ('pic_auto', auto)]:
        im = fn()
        im.save(os.path.join(OUT, name + '.png'))
        print(name, im.size)
