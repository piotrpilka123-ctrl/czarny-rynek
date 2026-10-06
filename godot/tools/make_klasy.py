#!/usr/bin/env python3
"""„Gra w klasy” narysowana kredą na chodniku (PNG z przezroczystością) -> assets/tex/gen_klasy.png."""
import os, random
from PIL import Image, ImageDraw, ImageFilter, ImageChops, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
W, H = 256, 640
rnd = random.Random(5)
im = Image.new('L', (W, H), 0)
d = ImageDraw.Draw(im)
font = ImageFont.truetype(os.path.join(ROOT, 'assets', 'fonts', 'sedgwick.ttf'), 54)


def kreska(a, b):
    # kreda prowadzona ręką: lekko krzywa, nierównej grubości
    n = 14
    pts = []
    for i in range(n + 1):
        t = i / n
        pts.append((a[0] + (b[0] - a[0]) * t + rnd.uniform(-2.5, 2.5), a[1] + (b[1] - a[1]) * t + rnd.uniform(-2.5, 2.5)))
    for i in range(n):
        d.line([pts[i], pts[i + 1]], fill=rnd.randint(170, 255), width=rnd.choice([5, 6, 7]))


def pole(x0, y0, x1, y1, txt):
    kreska((x0, y0), (x1, y0)); kreska((x1, y0), (x1, y1)); kreska((x1, y1), (x0, y1)); kreska((x0, y1), (x0, y0))
    d.text(((x0 + x1) / 2 - 14, (y0 + y1) / 2 - 34), txt, fill=220, font=font)


s = 84
cx = W // 2
y = H - 30
pole(cx - s // 2, y - s, cx + s // 2, y, '1'); y -= s
pole(cx - s // 2, y - s, cx + s // 2, y, '2'); y -= s
pole(cx - s, y - s, cx, y, '3'); pole(cx, y - s, cx + s, y, '4'); y -= s
pole(cx - s // 2, y - s, cx + s // 2, y, '5'); y -= s
pole(cx - s, y - s, cx, y, '6'); pole(cx, y - s, cx + s, y, '7'); y -= s
# „niebo” na końcu
d.arc([cx - s, y - s, cx + s, y + s], 180, 360, fill=230, width=6)
grain = Image.new('L', (W // 2, H // 2))
grain.putdata([rnd.randint(60, 255) for _ in range((W // 2) * (H // 2))])
grain = grain.resize((W, H), Image.BICUBIC)
alpha = ImageChops.multiply(im.filter(ImageFilter.GaussianBlur(0.8)), grain)
Image.merge('RGBA', (Image.new('L', (W, H), 255),) * 3 + (alpha,)).save(os.path.join(ROOT, 'assets', 'tex', 'gen_klasy.png'))
print('gen_klasy.png')
