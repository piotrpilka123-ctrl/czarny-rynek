"""Autobus miejski na pętlę: pudełkowaty, 11-metrowy, kremowo-czerwony, troje dwuskrzydłowych drzwi po prawej stronie,
tablica kierunkowa nad szybą, klapy dachowe, żaluzje silnika z tyłu. Stoi wyłączony na końcowym przystanku.
Przód = −Y, koła na z = 0."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
from lib import _finish

R90 = math.radians(90)
L, W = 11.0, 2.5
Z0, ZB, ZR = 0.36, 1.36, 3.04       # podłoga, linia pasa, dach


def _kolo(name, y, sx, rub, rim, dark, double=False):
    w = 0.3 if not double else 0.52
    t = lathe(name, [(0.27, -w / 2), (0.47, -w / 2), (0.505, -w / 2 + 0.05), (0.505, w / 2 - 0.05), (0.47, w / 2), (0.27, w / 2)], rub, 22)
    f = lathe(name + '_f', [(0.0, w / 2 - 0.1), (0.1, w / 2 - 0.1), (0.13, w / 2 - 0.04), (0.24, w / 2 - 0.05), (0.28, w / 2 - 0.01), (0.28, -w / 2 + 0.02), (0.0, -w / 2 + 0.02)], rim, 18)
    nuts = bolts(name + '_s', [(math.cos(i * math.pi / 4) * 0.17, math.sin(i * math.pi / 4) * 0.17, w / 2 - 0.045) for i in range(8)], dark, 0.018, 0.02)
    ob = join(name, [t, f] + nuts)
    ob.rotation_euler = (0, R90 if sx > 0 else -R90, 0)
    ob.location = (sx * (W / 2 - w / 2 + 0.035), y, 0.505)
    return ob


def autobus():
    reset()
    red = mat('czerwony', 'b02a1e', 0.45, 0.25)
    cream = mat('kremowy', 'e4dcc4', 0.45, 0.2)
    glass = mat('szyba', '10161c', 0.08, 0.6)
    black = mat('czarny', '1b1c1e', 0.75)
    rub = mat('guma', '141414', 0.9)
    chrome = mat('chrom', 'b8bcc2', 0.3, 0.9)
    rim = mat('felga', 'a39a86', 0.5, 0.5)
    ink = mat('tusz', '15161a', 0.6)
    amber = mat('bursztyn', 'e8a020', 0.4)
    # --- nadwozie: czerwony dół, kremowa góra, dach
    b = [rbox('dol', (W, L, ZB - Z0), red, 0.07, (0, 0, (Z0 + ZB) / 2)),
         rbox('gora', (W - 0.03, L - 0.03, ZR - ZB + 0.05), cream, 0.16, (0, 0, (ZB + ZR) / 2 - 0.025), segs=4),
         rbox('dach', (W - 0.5, L - 1.0, 0.07), mat('dach', 'cfc8b4', 0.6), 0.03, (0, 0, ZR + 0.02))]
    for y in (-2.6, 2.4):
        b.append(rbox('klapa', (0.85, 0.85, 0.06), mat('dach', 'cfc8b4', 0.6), 0.02, (0, y, ZR + 0.07)))
    b.append(rbox('przod_dol', (W - 0.1, 0.06, 0.5), red, 0.02, (0, -L / 2 - 0.01, 0.8)))
    body = join('Nadwozie', b)
    d = [rbox('pas', (W + 0.012, L + 0.012, 0.06), black, 0.01, (0, 0, ZB)),
         rbox('spod', (W - 0.3, L - 0.6, 0.2), black, 0.0, (0, 0, Z0 - 0.05), segs=1)]
    xs = W / 2 - 0.015
    zw, hw = 2.02, 0.98
    # lewa strona (+X): rząd okien, z przodu mniejsze okno kierowcy
    def okna(sx, spans):
        for (ya, yb) in spans:
            n = max(1, int(round((yb - ya) / 1.25)))
            ln = (yb - ya) / n
            for i in range(n):
                yc = ya + ln * (i + 0.5)
                d.append(rbox('okno', (0.014, ln - 0.1, hw), glass, 0.04, (sx * (xs + 0.004), yc, zw)))
                d.append(rbox('lufcik', (0.018, ln - 0.1, 0.02), black, 0.0, (sx * (xs + 0.006), yc, zw + 0.2), segs=1))
    okna(1, [(-4.55, 5.05)])
    d.append(rbox('okno_k', (0.014, 0.75, 0.8), glass, 0.04, (xs + 0.004, -5.0, zw - 0.05)))
    # prawa strona (−X): troje drzwi i okna między nimi
    doors = (-4.45, -0.55, 3.55)
    okna(-1, [(-3.7, -1.3), (0.2, 2.8), (4.3, 5.05)])
    for yc in doors:
        d.append(rbox('drzwi_rama', (0.03, 1.36, 2.16), black, 0.01, (-(xs + 0.002), yc, Z0 + 0.12 + 1.08)))
        for s in (-1, 1):
            d.append(rbox('skrzydlo', (0.03, 0.62, 2.06), cream, 0.01, (-(xs + 0.012), yc + s * 0.325, Z0 + 0.14 + 1.03)))
            d.append(rbox('szyba_d', (0.012, 0.48, 1.15), glass, 0.03, (-(xs + 0.03), yc + s * 0.325, 1.92)))
            d.append(rbox('szyba_d2', (0.012, 0.48, 0.42), glass, 0.03, (-(xs + 0.03), yc + s * 0.325, 0.95)))
            d.append(tube('porecz', [(-(xs + 0.045), yc + s * 0.06, 1.0), (-(xs + 0.045), yc + s * 0.06, 1.9)], 0.012, chrome, 6))
        d.append(rbox('stopien', (0.1, 1.3, 0.04), black, 0.01, (-(xs + 0.03), yc, Z0 + 0.1)))
    # nadkola i koła (tylna oś na bliźniakach)
    kola = []
    k = 1
    for (y, dbl) in ((-3.15, False), (2.55, True)):
        for sx in (-1, 1):
            arch = [(-0.63, Z0 - 0.03)] + [(math.cos(math.pi - i * math.pi / 14) * 0.63, 0.5 + math.sin(math.pi - i * math.pi / 14) * 0.56) for i in range(15)] + [(0.63, Z0 - 0.03)]
            na = profile('nadkole', arch, 0.03, black, 0.004)
            na.rotation_euler = (R90, 0, R90)
            na.location = (sx * (xs + 0.003), y, 0.0)
            d.append(na)
            kola.append(_kolo('Kolo%d' % k, y, sx, rub, rim, black, dbl))
            k += 1
    # --- przód: szyba dzielona, tablica kierunkowa, reflektory, zderzak, wycieraczki, lusterka
    yf = -L / 2 - 0.012
    d.append(rbox('szyba_p', (W - 0.34, 0.02, 1.34), glass, 0.08, (0, yf + 0.004, 2.02)))
    d.append(rbox('slupek_p', (0.05, 0.03, 1.34), black, 0.0, (0, yf - 0.005, 2.02), segs=1))
    d.append(rbox('tablica_k', (1.9, 0.04, 0.3), black, 0.02, (0, yf - 0.005, 2.86)))
    d.append(text('kierunek', '12  HUTNIK', 0.2, amber, (0, yf - 0.03, 2.86)))
    for sx in (-1, 1):
        r = lathe('Reflektor', [(0.0, 0.0), (0.11, 0.0), (0.125, 0.02), (0.1, 0.05), (0.0, 0.055)], mat('reflektor', 'f4f1dc', 0.15, 0.0, 0.3), 16, loc=(sx * 0.86, yf - 0.03, 0.88))
        r.rotation_euler = (R90, 0, 0)
        d.append(r)
        d.append(rbox('kierunkowskaz', (0.16, 0.03, 0.08), mat('pomarancz', 'd98a1e', 0.3), 0.015, (sx * 1.08, yf - 0.035, 0.88)))
        d.append(rbox('wycieraczka', (0.75, 0.014, 0.02), black, 0.004, (sx * 0.55, yf - 0.02, 1.42), (0, sx * 0.1, 0)))
        d.append(tube('ramie_l', [(sx * (W / 2 - 0.05), yf + 0.2, 2.72), (sx * (W / 2 + 0.26), yf - 0.12, 2.55)], 0.014, black, 6))
        d.append(rbox('lusterko', (0.05, 0.2, 0.36), black, 0.02, (sx * (W / 2 + 0.27), yf - 0.13, 2.36)))
    d.append(rbox('zderzak_p', (W + 0.04, 0.16, 0.22), black, 0.05, (0, yf - 0.04, 0.5)))
    for g in range(5):
        d.append(rbox('wlot', (0.9, 0.014, 0.022), black, 0.0, (0, yf - 0.035, 0.76 + g * 0.05), segs=1))
    d.append(rbox('tabl_p', (0.5, 0.012, 0.11), mat('biale', 'e9e9e4', 0.5), 0.004, (0, yf - 0.125, 0.5)))
    d.append(text('nr_p', 'SH 4127K', 0.075, ink, (0, yf - 0.133, 0.5)))
    d.append(text('numer_p', '2147', 0.13, ink, (0.78, yf - 0.045, 1.2)))
    # --- tył: okno, żaluzje silnika, lampy, zderzak
    yr = L / 2 + 0.012
    d.append(rbox('szyba_t', (W - 0.7, 0.02, 0.8), glass, 0.08, (0, yr - 0.004, 2.2)))
    d.append(rbox('pokrywa', (1.7, 0.03, 0.75), red, 0.02, (0, yr + 0.0, 0.95)))
    for g in range(9):
        d.append(rbox('zaluzja', (1.5, 0.02, 0.03), black, 0.0, (0, yr + 0.02, 0.66 + g * 0.07), segs=1))
    for sx in (-1, 1):
        d.append(rbox('LampaTyl', (0.14, 0.04, 0.36), mat('lampa_tyl', 'a01414', 0.25, 0.0, 0.2), 0.02, (sx * (W / 2 - 0.16), yr + 0.01, 1.05)))
        d.append(rbox('kier_t', (0.14, 0.04, 0.12), mat('pomarancz', 'd98a1e', 0.3), 0.02, (sx * (W / 2 - 0.16), yr + 0.01, 1.32)))
    d.append(rbox('zderzak_t', (W + 0.04, 0.16, 0.22), black, 0.05, (0, yr + 0.04, 0.5)))
    d.append(rbox('tabl_t', (0.5, 0.012, 0.11), mat('biale', 'e9e9e4', 0.5), 0.004, (0.5, yr + 0.125, 0.5)))
    t = text('nr_t', 'SH 4127K', 0.075, ink, (0.5, yr + 0.133, 0.5))
    t.rotation_euler = (R90, 0, math.radians(180))
    d.append(t)
    t = text('linia_t', '12', 0.3, amber, (-0.7, yr + 0.0, 2.2))
    t.rotation_euler = (R90, 0, math.radians(180))
    d.append(rbox('linia_tlo', (0.5, 0.03, 0.42), black, 0.02, (-0.7, yr - 0.01, 2.2)))
    t.location = (-0.7, yr + 0.012, 2.2)
    d.append(t)
    d.append(tube('wydech', [(-0.8, yr - 0.3, Z0 - 0.08), (-0.8, yr + 0.1, Z0 - 0.1)], 0.04, chrome, 8))
    # --- napisy na bokach
    for sx in (-1, 1):
        for (txt, size, y, z) in (('CITY TRANSIT', 0.13, 1.3 if sx > 0 else -2.5, 1.05), ('2147', 0.13, -4.2 if sx > 0 else 1.5, 0.75)):
            tt = text('napis', txt, size, ink if txt != 'CITY TRANSIT' else mat('bialy', 'f0ece0', 0.5), (sx * (W / 2 + 0.006), y, z))
            tt.rotation_euler = (R90, 0, R90 if sx > 0 else -R90)
            d.append(tt)
    det = join('Detale', d)
    weather([body], 2048, 0.38, 0.45, (0.13, 0.1, 0.08))
    export('autobus')


autobus()
