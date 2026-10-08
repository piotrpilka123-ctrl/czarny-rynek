"""Witryna sklepu monopolowego 2,9 × 2,5 m (przód = −Y, spód na z = 0, tył przy ścianie budynku na y = +0,25):
okno z półkami pełnymi butelek (wódka, piwo, wino), skrzynki piwa na parapecie, plakaty z cenami na szybie,
drzwi z nocnym okienkiem, półeczką i dzwonkiem, neon 24H. Butelki, napisy i światła są osobnymi obiektami bez brudu."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *

R90 = math.radians(90)
rnd = random.Random(24)


def witryna():
    reset()
    W, H, D = 2.9, 2.5, 0.5
    yb, yf = D / 2, -D / 2
    rama = mat('rama', '3d6a4a', 0.6)
    rama_c = mat('rama_c', '2f5239', 0.6)
    plytki = mat('plytki', wz('b9b4a8', 'beton'), 0.6, wzor='beton')
    tlo = mat('wnetrze', '4a4038', 0.95)
    polka_m = mat('polka', 'd8d2c2', 0.6)
    bialy = mat('bialy', 'ecebe4', 0.6)
    zolty = mat('zolty', 'e2b21c', 0.55)
    tusz = mat('tusz', '1b1c20', 0.6)
    czerw = mat('czerwony', 'b02a22', 0.6)
    stal = mat('stal', '8a9096', 0.45)
    zo = 0.5
    zt = H - 0.3
    xd0, xd1 = 0.52, W / 2 - 0.12
    xw0, xw1 = -W / 2 + 0.12, xd0 - 0.14
    xc, ww = (xw0 + xw1) / 2, xw1 - xw0
    xo, wd = (xd0 + xd1) / 2, xd1 - xd0
    p = []
    # --- portal: cokół z płytek, słupy, nadproże z deską
    p.append(rbox('cokol', (ww + 0.24, D, zo), plytki, 0.012, (xc, 0, zo / 2)))
    p.append(rbox('cokol_listwa', (ww + 0.26, D + 0.03, 0.05), rama_c, 0.008, (xc, 0, zo - 0.02)))
    for x in (-W / 2 + 0.06, xd0 - 0.07, W / 2 - 0.06):
        p.append(rbox('slup', (0.12, D + 0.03, H), rama, 0.012, (x, 0, H / 2)))
    p.append(rbox('nadproze', (W, D + 0.06, 0.3), rama, 0.02, (0, -0.01, H - 0.15)))
    p.append(rbox('gzyms', (W + 0.08, D + 0.12, 0.04), rama_c, 0.01, (0, -0.02, H - 0.02)))
    p.append(rbox('tlo', (ww, 0.03, zt - zo), tlo, 0.0, (xc, yb - 0.02, (zt + zo) / 2), segs=1))
    p.append(rbox('sufit', (ww, D - 0.06, 0.02), tlo, 0.0, (xc, 0.02, zt - 0.01), segs=1))
    p.append(rbox('parapet', (ww, D - 0.02, 0.04), polka_m, 0.006, (xc, 0.0, zo + 0.02)))
    polki = [0.98, 1.36, 1.74]
    for z in polki:
        p.append(rbox('polka', (ww - 0.04, 0.26, 0.022), polka_m, 0.004, (xc, 0.09, z)))
        p.append(rbox('polka_rant', (ww - 0.04, 0.01, 0.04), zolty, 0.003, (xc, -0.045, z - 0.004)))
    for x in (xw0 + 0.03, xw1 - 0.03):
        p.append(rbox('polka_bok', (0.025, 0.26, zt - zo - 0.1), polka_m, 0.004, (x, 0.09, (zt + zo) / 2)))
    p.append(rbox('rama_d', (ww, 0.05, 0.05), rama_c, 0.006, (xc, yf + 0.06, zo + 0.045)))
    p.append(rbox('rama_g', (ww, 0.05, 0.05), rama_c, 0.006, (xc, yf + 0.06, zt - 0.03)))
    p.append(rbox('szpros', (0.04, 0.05, zt - zo), rama_c, 0.006, (xc, yf + 0.06, (zt + zo) / 2)))
    # --- drzwi z nocnym okienkiem
    p.append(rbox('stopien', (wd + 0.3, 0.42, 0.14), plytki, 0.012, (xo, yf - 0.1, 0.07)))
    zd0, zd1 = 0.14, zt
    yd = 0.08
    drzwi = mat('drzwi', '4f5e58', 0.55)
    p.append(rbox('skrzydlo', (wd - 0.04, 0.05, zd1 - zd0 - 0.02), drzwi, 0.008, (xo, yd, (zd0 + zd1) / 2)))
    for i in range(2):
        p.append(rbox('przetloczenie', (wd - 0.22, 0.012, 0.36), mat('drzwi_c', '44524c', 0.55), 0.01, (xo, yd - 0.03, zd0 + 0.3 + i * 0.44)))
    zh = zd0 + 1.06                 # nocne okienko: rama, klapka uchylona do środka, półeczka na wspornikach
    p.append(rbox('okienko_rama', (0.46, 0.04, 0.4), stal, 0.008, (xo, yd - 0.03, zh + 0.18)))
    p.append(rbox('okienko_wnetrze', (0.38, 0.02, 0.32), tlo, 0.0, (xo, yd - 0.04, zh + 0.18), segs=1))
    p.append(rbox('poleczka', (0.5, 0.16, 0.025), stal, 0.006, (xo, yd - 0.12, zh - 0.02)))
    for sx in (-0.18, 0.18):
        p.append(tube('wspornik', [(xo + sx, yd - 0.035, zh - 0.16), (xo + sx, yd - 0.18, zh - 0.03)], 0.008, stal, 5))
    p.append(rbox('klamka_szyld', (0.05, 0.012, 0.2), stal, 0.004, (xd0 + 0.12, yd - 0.032, zd0 + 0.86)))
    p.append(tube('klamka', [(xd0 + 0.12, yd - 0.04, zd0 + 0.9), (xd0 + 0.12, yd - 0.09, zd0 + 0.9), (xd0 + 0.24, yd - 0.09, zd0 + 0.9)], 0.011, stal, 6))
    p.append(rbox('dzwonek_p', (0.07, 0.02, 0.1), bialy, 0.006, (xd1 - 0.1, yd - 0.035, zh + 0.2)))
    p.append(rbox('prog', (wd, 0.2, 0.03), stal, 0.004, (xo, yd - 0.08, zd0 + 0.015)))
    # skrzynki piwa na chodniku przy słupie (puste, do zwrotu)
    for i, kol in enumerate(('b0382c', '2f6b3a')):
        p.append(rbox('skrzynka_ch', (0.4, 0.3, 0.26), mat('skrz%d' % i, kol, 0.55), 0.015, (-W / 2 - 0.26, yf + 0.02, 0.13 + i * 0.27), (0, 0, 0.1 * i)))
    wit = join('Witryna', p)

    # --- butelki i towar (bez wypalanego brudu: gładkie szkło)
    b = []
    etyk = ['b02a22', '1f4f8a', 'e2b21c', 'ecebe4', '2f6b3a', '7a2a6a', 'd06a1c']

    def butelka(x, y, z, kind, k):
        if kind == 'piwo':
            r, h, szklo = 0.03, 0.23, mat('szklo_piwo', '6a4420', 0.2)
            prof = [(0.0, 0.0), (r, 0.0), (r, h * 0.55), (r * 0.45, h * 0.78), (r * 0.42, h * 0.97), (r * 0.5, h), (0.0, h)]
        elif kind == 'wino':
            r, h, szklo = 0.037, 0.3, mat('szklo_wino', '2c4a32', 0.2)
            prof = [(0.0, 0.0), (r, 0.0), (r, h * 0.58), (r * 0.36, h * 0.74), (r * 0.34, h * 0.98), (r * 0.42, h), (0.0, h)]
        else:
            r, h, szklo = 0.035, 0.28, mat('szklo_wodka', 'c4d6da', 0.12)
            prof = [(0.0, 0.0), (r, 0.0), (r, h * 0.66), (r * 0.4, h * 0.8), (r * 0.38, h * 0.93), (0.0, h * 0.93)]
        b.append(lathe('butelka', prof, szklo, 8, loc=(x, y, z)))
        b.append(lathe('etykieta', [(r * 1.03, h * 0.16), (r * 1.03, h * 0.44)], mat('etyk%d' % (k % len(etyk)), etyk[k % len(etyk)], 0.6), 8, loc=(x, y, z)))
        if kind != 'piwo':
            b.append(lathe('nakretka', [(0.0, h * 0.93), (r * 0.42, h * 0.93), (r * 0.42, h), (0.0, h)], mat('nakretka%d' % (k % 3), ['b02a22', 'c9a03a', '1b1c20'][k % 3], 0.4), 8, loc=(x, y, z)))

    rodzaje = [('wodka', 0.085), ('wino', 0.09), ('piwo', 0.074)]
    for li, z in enumerate(polki):
        kind, krok = rodzaje[li % 3]
        for rz in (0.14, 0.04):                      # dwa rzędy w głąb
            x = xw0 + 0.1 + (0.03 if rz < 0.1 else 0.0)
            k = li * 7
            while x < xw1 - 0.09:
                if abs(x - xc) > 0.04:
                    butelka(x, rz, z + 0.011, kind, k // 3)
                x += krok
                k += 1
    # parapet: trzy skrzynki piwa z szyjkami, zgrzewki, kosz z puszkami
    zp = zo + 0.04
    for i, kol in enumerate(('b0382c', '2f6b3a', 'e2b21c')):
        x = xw0 + 0.3 + i * 0.46
        if abs(x - xc) < 0.22:
            x += 0.2
        b.append(rbox('skrzynka', (0.4, 0.3, 0.24), mat('skrz%d' % i, kol, 0.55), 0.015, (x, 0.05, zp + 0.12)))
        b.append(rbox('skrzynka_napis', (0.3, 0.006, 0.08), bialy, 0.004, (x, -0.102, zp + 0.13)))
        for a in range(4):
            for c in range(3):
                b.append(lathe('szyjka', [(0.0, 0.0), (0.013, 0.0), (0.012, 0.05), (0.015, 0.055), (0.0, 0.055)], mat('szklo_piwo', '6a4420', 0.2), 6, loc=(x - 0.14 + a * 0.093, -0.04 + c * 0.09, zp + 0.24)))
    # plakaty z cenami na szybie i tabliczki
    n = []
    b.append(rbox('plakat1', (0.5, 0.004, 0.34), zolty, 0.004, (xw0 + 0.36, yf + 0.092, zo + 0.36)))
    n.append(text('p1a', 'BEER', 0.1, czerw, (xw0 + 0.36, yf + 0.088, zo + 0.42)))
    n.append(text('p1b', '2.99', 0.13, tusz, (xw0 + 0.36, yf + 0.088, zo + 0.25)))
    b.append(rbox('plakat2', (0.46, 0.004, 0.3), bialy, 0.004, (xw1 - 0.34, yf + 0.092, zo + 1.5)))
    n.append(text('p2a', 'VODKA 0.5 L', 0.05, tusz, (xw1 - 0.34, yf + 0.088, zo + 1.57)))
    n.append(text('p2b', '19.99', 0.11, czerw, (xw1 - 0.34, yf + 0.088, zo + 1.42)))
    b.append(rbox('deska', (W - 0.3, 0.014, 0.2), mat('deska', 'e8e2cf', 0.6), 0.004, (0, yf - 0.045, H - 0.15)))
    n.append(text('deska_t', 'BEER • VODKA • WINE • CIGARETTES', 0.07, mat('zielony_n', '1f5a34', 0.6), (0, yf - 0.054, H - 0.172)))
    b.append(rbox('tabl', (0.42, 0.008, 0.14), bialy, 0.004, (xo, yd - 0.062, zh + 0.5)))
    n.append(text('tabl_1', 'NIGHT WINDOW', 0.04, tusz, (xo, yd - 0.068, zh + 0.52)))
    n.append(text('tabl_2', 'RING THE BELL', 0.03, czerw, (xo, yd - 0.068, zh + 0.465)))
    b.append(rbox('nakl', (0.8, 0.008, 0.14), bialy, 0.004, (xc, yf - 0.004, 0.26)))
    n.append(text('nakl_t', 'ID REQUIRED  •  18+', 0.05, czerw, (xc, yf - 0.01, 0.243)))
    join('Butelki', b)
    join('Napisy', n)
    # --- szyba okna (przezroczysta), światło nad półkami i neon 24H nad okienkiem
    szklo = mat('szklo', 'a9c6d6', 0.06, 0.1, 0.0, 0.14)
    join('Szyby', [rbox('szyba', (ww, 0.008, zt - zo - 0.06), szklo, 0.0, (xc, yf + 0.1, (zt + zo) / 2), segs=1)])
    join('SwiatloWitryna', [rbox('swietlowka', (ww - 0.3, 0.035, 0.03), mat('swiatlo', 'eaf6ff', 0.4, 0.0, 3.0), 0.008, (xc, -0.05, zt - 0.045))])
    join('NeonRamka', [rbox('neon_tlo', (0.4, 0.014, 0.2), tusz, 0.006, (xo, yd - 0.062, zh + 0.8))])
    join('SwiatloNeon', [text('neon_t', '24H', 0.13, mat('neon', '5dff8a', 0.4, 0.0, 4.5), (xo, yd - 0.074, zh + 0.755), depth=0.004)])
    weather([wit], 2048, 0.32, 0.45, (0.14, 0.12, 0.1))
    export('monopolowy_witryna')


witryna()
