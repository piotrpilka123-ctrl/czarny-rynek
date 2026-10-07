"""Kolejka miejska na estakadę: trzy wagony elektrycznego zespołu trakcyjnego — dwa czołowe z kabiną (żółty przód,
trzy szyby, reflektory, zderzaki) i środkowy z pantografem. Granatowy dół, kremowa góra, żółty pas, rozsuwane drzwi.
Okna boczne to osobny obiekt „Okna” — gra zapala je po zmroku. Przód = −Y, szyny na z = 0."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
from lib import _finish

R90 = math.radians(90)
L, W = 13.0, 2.7
Z0, ZB, ZR = 0.78, 1.78, 3.56


def _wozek(y, out, dark, st):
    """wózek dwuosiowy: rama, cztery koła z obręczami, resory"""
    out.append(rbox('rama_w', (2.0, 2.5, 0.22), dark, 0.03, (0, y, 0.52)))
    for sy in (-0.85, 0.85):
        for sx in (-1, 1):
            k = lathe('kolo', [(0.0, -0.06), (0.4, -0.06), (0.46, -0.04), (0.46, 0.0), (0.42, 0.06), (0.0, 0.06)], st, 18)
            k.rotation_euler = (0, R90, 0)
            k.location = (sx * 0.76, y + sy, 0.46)
            out.append(k)
        out.append(tube('os', [(-0.76, y + sy, 0.46), (0.76, y + sy, 0.46)], 0.07, dark, 8))
    for sx in (-1, 1):
        out.append(rbox('resor', (0.12, 0.9, 0.16), dark, 0.02, (sx * 1.02, y, 0.62)))


def wagon(nazwa, kabina):
    reset()
    blue = mat('granat', '27457a', 0.45, 0.25)
    cream = mat('krem', 'e4dcc4', 0.45, 0.2)
    yellow = mat('zolty', 'e0b020', 0.5, 0.2)
    dark = mat('ciemny', '1c1d20', 0.8, 0.3)
    st = mat('stal', '6a6e72', 0.45, 0.8)
    glass = mat('szyba', '10161c', 0.08, 0.6)
    roofm = mat('dach', '7b7d80', 0.7, 0.3)
    ink = mat('tusz', '15161a', 0.6)
    b = [rbox('dol', (W, L, ZB - Z0), blue, 0.06, (0, 0, (Z0 + ZB) / 2)),
         rbox('gora', (W - 0.03, L - 0.02, ZR - ZB + 0.06), cream, 0.3, (0, 0, (ZB + ZR) / 2 - 0.03), segs=5),
         rbox('pas', (W + 0.012, L + 0.004, 0.09), yellow, 0.01, (0, 0, ZB)),
         rbox('dach', (W - 1.0, L - 0.5, 0.1), roofm, 0.04, (0, 0, ZR + 0.01))]
    for y in (-4.2, -1.4, 1.4, 4.2):
        b.append(rbox('wywietrznik', (0.5, 0.9, 0.12), roofm, 0.03, (0, y, ZR + 0.1)))
    if kabina:
        # żółte czoło: panel ostrzegawczy na całą szerokość
        b.append(rbox('czolo', (W - 0.08, 0.08, 1.35), yellow, 0.04, (0, -L / 2 - 0.01, Z0 + 0.7)))
    nad = join('Nadwozie', b)
    d = [rbox('spod', (W - 0.3, L - 0.4, 0.2), dark, 0.0, (0, 0, Z0 - 0.06), segs=1)]
    okna = []
    nap = []          # napisy zostają osobno, bez wypalania — inaczej litery giną w brudzie
    xs = W / 2 - 0.012
    zw, hw = 2.5, 0.95
    drzwi = (-3.3, 3.3) if not kabina else (-2.6, 3.3)
    for sx in (-1, 1):
        # okna między drzwiami i na końcach
        edges = [-L / 2 + (1.9 if kabina else 0.5)] + [v for y in drzwi for v in (y - 0.75, y + 0.75)] + [L / 2 - 0.5]
        for i in range(0, len(edges), 2):
            ya, yb = edges[i], edges[i + 1]
            n = max(1, int(round((yb - ya) / 1.3)))
            ln = (yb - ya) / n
            for j in range(n):
                yc = ya + ln * (j + 0.5)
                okna.append(rbox('okno', (0.014, ln - 0.22, hw), glass, 0.06, (sx * (xs + 0.004), yc, zw)))
                d.append(rbox('lufcik', (0.02, ln - 0.22, 0.025), dark, 0.0, (sx * (xs + 0.008), yc, zw + 0.22), segs=1))
        for yc in drzwi:
            d.append(rbox('drzwi_rama', (0.03, 1.5, 2.2), dark, 0.01, (sx * (xs + 0.002), yc, Z0 + 0.06 + 1.1)))
            for s in (-1, 1):
                d.append(rbox('skrzydlo', (0.03, 0.7, 2.1), blue, 0.01, (sx * (xs + 0.014), yc + s * 0.36, Z0 + 0.08 + 1.05)))
                okna.append(rbox('szyba_d', (0.012, 0.46, 0.85), glass, 0.05, (sx * (xs + 0.032), yc + s * 0.36, 2.45)))
                d.append(tube('porecz', [(sx * (xs + 0.05), yc + s * 0.08, 1.3), (sx * (xs + 0.05), yc + s * 0.08, 2.1)], 0.014, yellow, 6))
            d.append(rbox('stopien', (0.18, 1.5, 0.05), st, 0.01, (sx * (xs + 0.07), yc, Z0 - 0.02)))
        for (txt, size, y, z, m) in (('CITY RAIL', 0.16, 0.3 * sx, 1.32, mat('bialy', 'f0ece0', 0.5)), ('EN57-071' if kabina else 'EN57-071s', 0.1, -5.0 * sx if not kabina else 5.2, 0.98, mat('bialy', 'f0ece0', 0.5))):
            tt = text('napis', txt, size, m, (sx * (W / 2 + 0.008), y, z))
            tt.rotation_euler = (R90, 0, R90 if sx > 0 else -R90)
            nap.append(tt)
    # wózki, skrzynie aparatury pod podłogą, sprzęgi i harmonijki
    _wozek(-4.3, d, dark, st)
    _wozek(4.3, d, dark, st)
    for (y, ln) in ((-1.3, 2.2), (1.4, 1.8)):
        d.append(rbox('skrzynia', (W - 0.5, ln, 0.5), dark, 0.03, (0, y, Z0 - 0.3)))
    for sy in ((1,) if kabina else (-1, 1)):
        d.append(rbox('harmonia', (1.5, 0.22, 2.2), dark, 0.05, (0, sy * (L / 2 + 0.1), Z0 + 1.2)))
        for k in range(5):
            d.append(rbox('falda', (1.56, 0.02, 2.26), mat('guma', '111112', 0.95), 0.0, (0, sy * (L / 2 + 0.02 + k * 0.045), Z0 + 1.2), segs=1))
    yf = -L / 2 - 0.02
    swiatla = []
    if kabina:
        # trzy szyby czołowe, tablica kierunkowa, wycieraczki, zderzaki, sprzęg, zgarniacz
        for (x, w) in ((-0.86, 0.74), (0.0, 0.84), (0.86, 0.74)):
            d.append(rbox('szyba_p', (w, 0.03, 0.95), glass, 0.06, (x, yf - 0.012, 2.6)))
        d.append(rbox('tablica_k', (1.3, 0.05, 0.26), dark, 0.02, (0, yf - 0.01, 3.3)))
        nap.append(text('kierunek', 'S1  HUTNIK', 0.17, mat('bursztyn', 'e8a020', 0.4), (0, yf - 0.04, 3.3)))
        for sx in (-1, 1):
            d.append(rbox('wycieraczka', (0.02, 0.014, 0.6), dark, 0.004, (sx * 0.7, yf - 0.035, 2.5), (0, sx * 0.25, 0)))
            d.append(lathe('zderzak', [(0.0, 0.0), (0.08, 0.0), (0.08, 0.3), (0.2, 0.32), (0.2, 0.38), (0.0, 0.38)], st, 14, loc=(sx * 0.88, yf - 0.02, 1.05)))
            d[-1].rotation_euler = (R90, 0, 0)
            r = lathe('Reflektor', [(0.0, 0.0), (0.11, 0.0), (0.125, 0.02), (0.1, 0.05), (0.0, 0.055)], mat('reflektor', 'fff4d0', 0.15, 0.0, 2.0), 16, loc=(sx * 0.9, yf - 0.05, 1.55))
            r.rotation_euler = (R90, 0, 0)
            swiatla.append(r)
            d.append(rbox('czerwone', (0.12, 0.03, 0.1), mat('lampa_tyl', '8a1414', 0.3), 0.02, (sx * 0.62, yf - 0.05, 1.55)))
        r = lathe('Reflektor', [(0.0, 0.0), (0.09, 0.0), (0.1, 0.02), (0.08, 0.045), (0.0, 0.05)], mat('reflektor', 'fff4d0', 0.15, 0.0, 2.0), 14, loc=(0, yf - 0.03, 3.55))
        r.rotation_euler = (R90, 0, 0)
        swiatla.append(r)
        d.append(rbox('sprzeg', (0.3, 0.5, 0.26), dark, 0.04, (0, yf - 0.2, 0.9)))
        d.append(rbox('zgarniacz', (W - 0.3, 0.06, 0.45), dark, 0.02, (0, yf - 0.05, 0.42), (math.radians(-18), 0, 0)))
        nap.append(text('numer_p', '071', 0.16, ink, (0.0, yf - 0.06, 1.2)))
        # boczne okno maszynisty
        for sx in (-1, 1):
            okna.append(rbox('okno_m', (0.014, 0.8, 0.8), glass, 0.06, (sx * (xs + 0.004), -L / 2 + 1.0, 2.55)))
    else:
        # pantograf: podstawa na izolatorach, ramiona w romb, ślizgacz
        for sx in (-0.5, 0.5):
            for sy in (-0.6, 0.6):
                d.append(lathe('izolator', [(0.0, 0.0), (0.06, 0.0), (0.04, 0.05), (0.06, 0.1), (0.04, 0.15), (0.0, 0.18)], mat('porcelana', '7a3a2a', 0.4), 8, loc=(sx, sy, ZR + 0.06)))
        for (a, c) in (((-0.5, -0.6), (0.5, -0.6)), ((-0.5, 0.6), (0.5, 0.6)), ((-0.5, -0.6), (-0.5, 0.6)), ((0.5, -0.6), (0.5, 0.6))):
            d.append(tube('rama_p', [(a[0], a[1], ZR + 0.26), (c[0], c[1], ZR + 0.26)], 0.03, st, 6))
        zt = 4.62
        for sx in (-0.45, 0.45):
            d.append(tube('ramie_d', [(sx, -0.6, ZR + 0.26), (sx * 0.8, 0.35, ZR + 0.72)], 0.025, st, 6))
            d.append(tube('ramie_g', [(sx * 0.8, 0.35, ZR + 0.72), (sx * 0.7, -0.1, zt)], 0.02, st, 6))
        d.append(tube('poprzeczka', [(-0.36, 0.35, ZR + 0.72), (0.36, 0.35, ZR + 0.72)], 0.02, st, 6))
        for sy in (-0.18, -0.02):
            d.append(rbox('slizgacz', (1.5, 0.05, 0.03), dark, 0.01, (0, sy, zt + 0.02)))
        for sx in (-0.8, 0.8):
            d.append(tube('rog', [(sx * 0.93, -0.1, zt + 0.02), (sx * 1.12, -0.1, zt - 0.12)], 0.012, dark, 5))
    det = join('Detale', d)
    ok = join('Okna', okna)
    join('Napisy', nap)
    weather([nad], 2048, 0.42, 0.45, (0.13, 0.1, 0.08))
    weather([det], 1024, 0.5, 0.5, (0.1, 0.08, 0.06))
    export(nazwa)


only = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
for (n, k) in (('kolejka_czolo', True), ('kolejka_srodek', False)):
    if not only or n in only:
        wagon(n, k)
