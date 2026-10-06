#!/usr/bin/env python3
"""Tekstura siatki ogrodzeniowej (plecionka z drutu, kafel 4×4 oczka, przezroczyste tło) do assets/tex/gen_siatka.png."""
import os, math
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
N = 512
S = 4
W = N * S
im = Image.new('RGBA', (W, W), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
cells = 4
step = W / cells
wire = int(W * 0.018)
# dwa kierunki drutu; na skrzyżowaniach jeden przechodzi „nad” drugim (ciemniejsza przerwa w dolnym)
for layer, col in ((0, (118, 124, 122)), (1, (150, 156, 154))):
    for k in range(-cells, cells * 2 + 1):
        if layer == 0:
            a = (k * step, 0)
            b = (k * step + W, W)
        else:
            a = (k * step, W)
            b = (k * step + W, 0)
        d.line([a, b], fill=col + (255,), width=wire)
        # jaśniejsza krawędź: drut jest okrągły
        off = wire * 0.28
        d.line([(a[0] - off, a[1]), (b[0] - off, b[1])], fill=tuple(min(255, c + 46) for c in col) + (255,), width=max(1, wire // 4))
# rdzawe przebarwienia w kilku miejscach
rust = Image.new('RGBA', (W, W), (0, 0, 0, 0))
rd = ImageDraw.Draw(rust)
import random
rnd = random.Random(7)
for _ in range(26):
    x, y, r = rnd.uniform(0, W), rnd.uniform(0, W), rnd.uniform(W * 0.03, W * 0.09)
    rd.ellipse([x - r, y - r, x + r, y + r], fill=(120, 70, 36, 150))
rust = rust.filter(ImageFilter.GaussianBlur(W * 0.02))
alpha = im.split()[3]
im = Image.alpha_composite(im, Image.composite(rust, Image.new('RGBA', (W, W), (0, 0, 0, 0)), alpha))
im.putalpha(alpha)
im = im.resize((N, N), Image.LANCZOS)
out = os.path.join(ROOT, 'assets', 'tex', 'gen_siatka.png')
im.save(out, optimize=True)
print('zapisano', out)
