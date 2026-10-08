#!/usr/bin/env python3
"""Żadnej idealnej czerni na modelach: tekstury koloru (assets/models/*_kolor.png, assets/props/**/*_diff_*.jpg),
w których jest wyraźnie dużo prawie czarnych pikseli, dostają podniesiony „dół” — najciemniejsze miejsca stają się
ciemnym grafitem zamiast smoły, reszta obrazu zostaje bez zmian. Krzywa: v' = v + F·(1 − v/2F)² dla v < 2F.
Użycie: python3 tools/bez_czerni.py [--sucho]   (potem Godot --import)"""
import glob, os, sys
from PIL import Image

F = 24.0            # do jakiej jasności (0–255) podnosimy czerń
DRY = '--sucho' in sys.argv
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'assets')
LUT = [int(round(v + F * (1.0 - v / (2 * F)) ** 2)) if v < 2 * F else v for v in range(256)]
files = glob.glob(os.path.join(ROOT, 'models', '*_kolor.png')) + glob.glob(os.path.join(ROOT, 'props', '**', '*_diff_*.jpg'), recursive=True) \
    + glob.glob(os.path.join(ROOT, 'props', '**', '*_diff_*.png'), recursive=True) \
    + glob.glob(os.path.join(ROOT, 'people', '*', '*_body.jpg')) + glob.glob(os.path.join(ROOT, 'people', '*', '*_head.jpg'))
done = 0
for f in sorted(files):
    im = Image.open(f)
    h = im.convert('L').histogram()
    dark = sum(h[:13]) / float(sum(h))
    if dark < 0.02:
        continue
    done += 1
    if DRY:
        print('%5.1f%%  %s' % (dark * 100.0, os.path.relpath(f, ROOT)))
        continue
    if im.mode == 'RGBA':
        r, g, b, a = im.split()
        out = Image.merge('RGBA', (r.point(LUT), g.point(LUT), b.point(LUT), a))
    else:
        out = Image.merge('RGB', tuple(c.point(LUT) for c in im.convert('RGB').split()))
    if f.lower().endswith('.jpg'):
        out.save(f, quality=92)
    else:
        out.save(f, optimize=True)
print('tekstur z czernią:', done, 'z', len(files), '(na sucho)' if DRY else '— rozjaśnione')
