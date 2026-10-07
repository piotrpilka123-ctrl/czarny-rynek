#!/usr/bin/env python3
"""Tekstury wyciągnięte z modeli (assets/models/*.png) domyślnie importują się bezstratnie i bez kompresji w pamięci
karty — 186 plików zajmowało tam ok. 930 MB. Ten skrypt przełącza je na kompresję VRAM wysokiej jakości (BC7),
czyli ok. cztery razy mniej pamięci i szybsze wczytywanie. Tabliczki i napisy zostają bezstratne, żeby litery były ostre.
Po dodaniu nowych modeli: najpierw zwykły import (Godot --headless --import), potem ten skrypt i import jeszcze raz."""
import glob, re, sys

OSTRE = ('Tablic', 'Napis', 'Szyld', 'Etykiet', 'Kaseton', 'Towar', 'Plakat')
zmienione = pominiete = 0
for path in sorted(glob.glob('assets/models/*.png.import')):
    name = path.split('/')[-1]
    s = open(path).read()
    keep = any(k in name for k in OSTRE)
    want = '0' if keep else '2'
    new = re.sub(r'compress/mode=\d', 'compress/mode=' + want, s)
    new = re.sub(r'compress/high_quality=\w+', 'compress/high_quality=' + ('false' if keep else 'true'), new)
    if new != s:
        open(path, 'w').write(new)
        zmienione += 1
    if keep:
        pominiete += 1
print('tekstury modeli: przełączone %d, bezstratne (napisy) %d' % (zmienione, pominiete))
