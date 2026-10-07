"""Brama garażu w rzędzie blaszaków: dwuskrzydłowa, z blachy z przetłoczeniami, w ramie z kątownika; zawiasy, rygiel
z kłódką, uchwyt, kratki wentylacyjne u dołu, nadproże i betonowy próg z najazdem. Skrzydła („TintBrama”) są jasne —
gra barwi je na kolor farby. Przód = −Y, spód na z = 0, szerokość 2,35 m."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
from lib import _finish

rnd = random.Random(3)


def brama():
    reset()
    W, H = 2.35, 2.1
    paint = mat('farba', 'dedbd2', 0.6, 0.3)
    st = mat('stal', '4a4e54', 0.55, 0.7)
    rust = mat('rdza', '6a4630', 0.85, 0.3)
    con = mat('beton', '8e8a80', 0.92, wzor='beton')
    t = []
    for sx in (-1, 1):
        cx = sx * (W / 4 - 0.005)
        t.append(rbox('skrzydlo', (W / 2 - 0.03, 0.035, H - 0.05), paint, 0.006, (cx, -0.03, H / 2 + 0.01)))
        # przetłoczenia: rama skrzydła i dwa pola z poziomymi żebrami
        for z in (0.07, H * 0.5, H - 0.07):
            t.append(rbox('rama_p', (W / 2 - 0.05, 0.02, 0.06), paint, 0.006, (cx, -0.053, z)))
        for dx in (-1, 1):
            t.append(rbox('rama_k', (0.06, 0.02, H - 0.1), paint, 0.006, (cx + dx * (W / 4 - 0.055), -0.053, H / 2)))
        for k in range(5):
            for half in (0, 1):
                z = 0.2 + half * (H * 0.5 - 0.06) + k * 0.165
                t.append(rbox('zebro', (W / 2 - 0.2, 0.012, 0.03), paint, 0.006, (cx, -0.05, z)))
    tint = join('TintBrama', t)
    p = [rbox('nadproze', (W + 0.24, 0.1, 0.14), st, 0.01, (0, -0.01, H + 0.08)),
         rbox('prog', (W + 0.3, 0.7, 0.06), con, 0.012, (0, -0.33, 0.012), (math.radians(4), 0, 0))]
    for sx in (-1, 1):
        p.append(rbox('oscieznica', (0.07, 0.09, H + 0.02), st, 0.008, (sx * (W / 2 + 0.03), -0.01, H / 2)))
        for z in (0.3, H / 2, H - 0.3):
            p.append(rbox('zawias', (0.12, 0.03, 0.09), st, 0.008, (sx * (W / 2 - 0.045), -0.062, z)))
            p.append(tube('sworzen', [(sx * (W / 2 + 0.005), -0.07, z - 0.06), (sx * (W / 2 + 0.005), -0.07, z + 0.06)], 0.012, st, 6))
        # kratki wentylacyjne
        for k in range(4):
            p.append(rbox('kratka', (0.3, 0.012, 0.012), mat('czern', '15161a', 0.8), 0.0, (sx * (W / 4), -0.062, 0.115 + k * 0.022), segs=1))
    # rygiel przez oba skrzydła, skobel z kłódką, uchwyt
    p.append(rbox('rygiel', (0.7, 0.02, 0.05), st, 0.006, (0, -0.07, 1.05)))
    for dx in (-0.25, 0.25):
        p.append(rbox('prowadnik', (0.06, 0.035, 0.09), st, 0.006, (dx, -0.07, 1.05)))
    p.append(tube('skobel', [(0.06, -0.075, 1.0), (0.06, -0.1, 0.96), (0.06, -0.075, 0.92)], 0.008, st, 5))
    p.append(rbox('klodka', (0.07, 0.03, 0.08), mat('mosiadz', 'a8873a', 0.4, 0.8), 0.008, (0.06, -0.1, 0.9)))
    p.append(tube('uchwyt', [(-0.12, -0.062, 1.2), (-0.12, -0.11, 1.26), (-0.12, -0.11, 1.4), (-0.12, -0.062, 1.46)], 0.011, st, 6))
    p.append(rbox('listwa', (0.05, 0.02, H - 0.08), st, 0.006, (0.0, -0.058, H / 2)))
    # zaciek rdzy spod zawiasów i plama przy progu
    for sx in (-1, 1):
        p.append(rbox('zaciek', (0.05, 0.004, 0.5), rust, 0.0, (sx * (W / 2 - 0.06), -0.052, 0.3 + 0.25 - 0.3), segs=1))
    ob = join('Brama', p)
    weather([tint], 1024, 0.6, 0.7, (0.24, 0.13, 0.06))
    weather([ob], 512, 0.6, 0.6, (0.2, 0.11, 0.06))
    export('garaz_brama')


brama()
