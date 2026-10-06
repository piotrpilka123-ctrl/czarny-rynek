#!/usr/bin/env python3
"""Kafelkowe tekstury tkanin na ubrania: dla każdej mapa jasności (mnożona przez kolor materiału) i mapa normalnych.
dzianina (bluzy, czapki, dresy), dżins (jeansy, kurtki), płótno (koszule, bojówki, trampki), skóra (rękawiczki, buty), ściągacz (mankiety)."""
# uruchamiane w Blenderze (ma numpy): Blender -b --python tools/make_fabric.py
import os, math
import numpy as np
import bpy

N = 256
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets', 'wear')
yy, xx = np.mgrid[0:N, 0:N].astype(np.float32) / N
rng = np.random.default_rng(5)


def noise(scale, seed):
    """kafelkowy szum: suma kilku sinusów o losowych fazach"""
    r = np.random.default_rng(seed)
    out = np.zeros((N, N), np.float32)
    for _ in range(10):
        fx, fy = r.integers(1, scale + 1), r.integers(1, scale + 1)
        out += np.sin(math.tau * (fx * xx + fy * yy) + r.uniform(0, math.tau)) * r.uniform(0.3, 1.0)
    return out / 5.0


def _png(path, rgb):
    h, w = rgb.shape[:2]
    img = bpy.data.images.new('tmp', w, h, alpha=False)
    px = np.ones((h, w, 4), np.float32)
    px[..., :3] = rgb[::-1]
    img.colorspace_settings.name = 'Non-Color'
    img.pixels = px.ravel().tolist()
    img.update()
    img.filepath_raw = path
    img.file_format = 'PNG'
    img.save()
    bpy.data.images.remove(img)


def save(name, h, lo=0.78, hi=1.0, strength=2.2):
    h = (h - h.min()) / max(1e-6, h.max() - h.min())
    a = lo + (hi - lo) * h
    _png(os.path.join(OUT, name + '_a.png'), np.stack([a, a, a], -1))
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    nz = np.ones_like(h)
    ln = np.sqrt(dx * dx + dy * dy + nz * nz)
    n = np.stack([(-dx / ln) * 0.5 + 0.5, (dy / ln) * 0.5 + 0.5, (nz / ln) * 0.5 + 0.5], -1)
    _png(os.path.join(OUT, name + '_n.png'), n)


# dzianina: kolumny oczek w kształcie litery V
k = 16
u = (xx * k) % 1.0
v = (yy * k * 1.5 + np.abs(u - 0.5) * 1.4) % 1.0
knit = (1.0 - np.abs(u - 0.5) * 2.0) ** 0.6 * (0.55 + 0.45 * np.sin(v * math.pi) ** 0.8) + noise(6, 1) * 0.08
save('dzianina', knit, 0.74, 1.0, 2.6)

# dżins: skośny splot z jaśniejszą nitką wątku
d = np.sin((xx * 64 + yy * 32) * math.tau) * 0.5 + 0.5
d2 = np.sin((xx * 64 - yy * 128) * math.tau) * 0.5 + 0.5
denim = d * 0.7 + d2 * 0.25 + noise(8, 2) * 0.25
save('dzins', denim, 0.7, 1.0, 2.0)

# płótno: prosty splot krzyżowy
cx = np.sin(xx * 56 * math.tau) * 0.5 + 0.5
cy = np.sin(yy * 56 * math.tau) * 0.5 + 0.5
chk = ((np.floor(xx * 56) + np.floor(yy * 56)) % 2)
canvas = np.where(chk > 0.5, cx ** 0.6, cy ** 0.6) + noise(7, 3) * 0.12
save('plotno', canvas, 0.8, 1.0, 1.8)

# skóra: drobne ziarno z porami i zmarszczkami
g = noise(24, 4) + noise(40, 5) * 0.7
leather = np.abs(g) ** 0.7 + noise(5, 6) * 0.3
save('skora', leather, 0.72, 1.0, 1.6)

# ściągacz: pionowe prążki
rib = (np.sin(xx * 28 * math.tau) * 0.5 + 0.5) ** 0.7 + noise(6, 7) * 0.05
save('sciagacz', rib, 0.62, 1.0, 3.2)

# guma podeszwy: drobna kratka
rb = np.maximum(np.sin(xx * 24 * math.tau), np.sin(yy * 24 * math.tau)) * 0.5 + 0.5
save('guma', rb + noise(5, 8) * 0.1, 0.8, 1.0, 1.6)
print('tkaniny ok')
