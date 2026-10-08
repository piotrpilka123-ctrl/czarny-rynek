"""Witryny przy Hutniczej, 2,9 × 2,5 m (przód = −Y, spód na z = 0, tył przy ścianie budynku na y = +0,25):
piekarnia_witryna — okno z półkami pieczywa (bochenki, bułki, bagietki w koszu, blacha drożdżówek), markiza w pasy,
                    drzwi z szybą i dzwonkiem;
kebab_witryna     — okienko z ladą, pionowy rożen z grzałką, blacha z dodatkami, tablica z menu, lodówka z napojami.
Towar, napisy i światła są osobnymi obiektami bez wypalanego brudu.
Użycie: Blender -b --python make_witryny2.py [-- nazwa…]"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *

R90 = math.radians(90)
W, H, D = 2.9, 2.5, 0.5
yb, yf = D / 2, -D / 2


def portal(p, rama, rama_c, cokol_m, tlo, xw0, xw1, zo, zt, slupy):
    """cokół pod oknem, słupy, nadproże, tło i sufit wnęki okna"""
    xc, ww = (xw0 + xw1) / 2, xw1 - xw0
    p.append(rbox('cokol', (ww + 0.24, D, zo), cokol_m, 0.012, (xc, 0, zo / 2)))
    p.append(rbox('cokol_listwa', (ww + 0.26, D + 0.03, 0.05), rama_c, 0.008, (xc, 0, zo - 0.02)))
    for x in slupy:
        p.append(rbox('slup', (0.12, D + 0.03, H), rama, 0.012, (x, 0, H / 2)))
    p.append(rbox('nadproze', (W, D + 0.06, 0.3), rama, 0.02, (0, -0.01, H - 0.15)))
    p.append(rbox('gzyms', (W + 0.08, D + 0.12, 0.04), rama_c, 0.01, (0, -0.02, H - 0.02)))
    p.append(rbox('tlo', (ww, 0.03, zt - zo), tlo, 0.0, (xc, yb - 0.02, (zt + zo) / 2), segs=1))
    p.append(rbox('sufit', (ww, D - 0.06, 0.02), tlo, 0.0, (xc, 0.02, zt - 0.01), segs=1))


def piekarnia_witryna():
    reset()
    rnd = random.Random(5)
    rama = mat('rama', wz('8a6238', 'drewno'), 0.75, wzor='drewno')
    rama_c = mat('rama_c', wz('6e4c2a', 'drewno'), 0.75, wzor='drewno')
    plytki = mat('plytki', wz('cfc6b2', 'beton'), 0.6, wzor='beton')
    tlo = mat('wnetrze', '5a4a3a', 0.95)
    polka_m = mat('polka', wz('b08a56', 'drewno'), 0.7, wzor='drewno')
    bialy = mat('bialy', 'ecebe4', 0.6)
    tusz = mat('tusz', '2a2420', 0.6)
    czerw = mat('czerwony', 'b02a22', 0.6)
    stal = mat('stal', '9a9fa5', 0.45)
    zo, zt = 0.62, H - 0.3
    xd0, xd1 = 0.52, W / 2 - 0.12
    xw0, xw1 = -W / 2 + 0.12, xd0 - 0.14
    xc, ww = (xw0 + xw1) / 2, xw1 - xw0
    xo, wd = (xd0 + xd1) / 2, xd1 - xd0
    p = []
    portal(p, rama, rama_c, plytki, tlo, xw0, xw1, zo, zt, (-W / 2 + 0.06, xd0 - 0.07, W / 2 - 0.06))
    p.append(rbox('parapet', (ww, D - 0.02, 0.04), polka_m, 0.006, (xc, 0.0, zo + 0.02)))
    polki = [1.1, 1.52]
    for z in polki:
        p.append(rbox('polka', (ww - 0.04, 0.3, 0.025), polka_m, 0.004, (xc, 0.07, z)))
    p.append(rbox('rama_d', (ww, 0.05, 0.05), rama_c, 0.006, (xc, yf + 0.06, zo + 0.045)))
    p.append(rbox('rama_g', (ww, 0.05, 0.05), rama_c, 0.006, (xc, yf + 0.06, zt - 0.03)))
    # drzwi: skrzydło z dużą szybą, pochwyt, próg, stopień
    p.append(rbox('stopien', (wd + 0.3, 0.42, 0.14), plytki, 0.012, (xo, yf - 0.1, 0.07)))
    zd0, zd1, yd = 0.14, zt, 0.08
    p.append(rbox('skrzydlo_d', (wd - 0.04, 0.05, 0.75), rama, 0.008, (xo, yd, zd0 + 0.375)))
    for x in (xd0 + 0.07, xd1 - 0.07):
        p.append(rbox('ramiak', (0.1, 0.05, zd1 - zd0 - 0.02), rama, 0.008, (x, yd, (zd0 + zd1) / 2)))
    p.append(rbox('ramiak_g', (wd - 0.04, 0.05, 0.12), rama, 0.008, (xo, yd, zd1 - 0.07)))
    p.append(rbox('wnetrze_d', (wd - 0.2, 0.02, zd1 - zd0 - 0.9), tlo, 0.0, (xo, yd + 0.05, zd0 + 0.75 + (zd1 - zd0 - 0.9) / 2), segs=1))
    p.append(tube('pochwyt', [(xd0 + 0.16, yd - 0.03, zd0 + 0.8), (xd0 + 0.16, yd - 0.075, zd0 + 0.86), (xd0 + 0.16, yd - 0.075, zd0 + 1.2), (xd0 + 0.16, yd - 0.03, zd0 + 1.26)], 0.011, stal, 6))
    p.append(rbox('prog', (wd, 0.2, 0.03), stal, 0.004, (xo, yd - 0.08, zd0 + 0.015)))
    # markiza w pasy nad oknem: rama z rurek
    za, ya = zt + 0.06, yf - 0.02
    for sx in (xw0 + 0.02, xw1 - 0.02):
        p.append(tube('markiza_rama', [(sx, ya, za), (sx, ya - 0.62, za - 0.3), (sx, ya, za - 0.42)], 0.01, stal, 5))
    p.append(tube('markiza_pret', [(xw0 + 0.02, ya - 0.62, za - 0.3), (xw1 - 0.02, ya - 0.62, za - 0.3)], 0.01, stal, 5))
    wit = join('Witryna', p)

    # --- markiza (pasy), pieczywo, tabliczki: bez wypalanego brudu
    t = []
    n_pas = 9
    for i in range(n_pas):
        x0 = xw0 + i * ww / n_pas
        m = czerw if i % 2 == 0 else bialy
        cx = x0 + ww / n_pas / 2
        t.append(rbox('pas', (ww / n_pas + 0.002, 0.69, 0.006), m, 0.0, (cx, ya - 0.31, za - 0.15), (math.atan2(0.3, 0.62), 0, 0), segs=1))
        t.append(rbox('falbana', (ww / n_pas + 0.002, 0.006, 0.1), m, 0.0, (cx, ya - 0.622, za - 0.35), segs=1))
    skorka = [mat('chleb%d' % i, c, 0.85) for i, c in enumerate(('b9772f', 'a8662a', 'c98a3a', '8f5622'))]
    jasny = mat('bulka', 'd9a45a', 0.85)

    def bochenek(x, y, z, k, dl=0.26, sz=0.13, wys=0.1, rot=0.0):
        b = lathe('bochenek', [(0.0, 0.0), (0.5, 0.0), (0.92, 0.16), (1.0, 0.45), (0.86, 0.8), (0.5, 1.0), (0.0, 1.0)], skorka[k % 4], 12)
        b.scale = (dl / 2, sz / 2, wys)
        b.rotation_euler = (0, 0, rot)
        b.location = (x, y, z)
        t.append(b)
        for j in (-1, 0, 1):                      # nacięcia na skórce
            a = rot + 0.6
            cx, cy = x + math.cos(rot) * j * dl * 0.22, y + math.sin(rot) * j * dl * 0.22
            t.append(tube('naciecie', [(cx - math.cos(a) * sz * 0.3, cy - math.sin(a) * sz * 0.3, z + wys * 0.96), (cx, cy, z + wys * 1.0), (cx + math.cos(a) * sz * 0.3, cy + math.sin(a) * sz * 0.3, z + wys * 0.96)], 0.004, jasny, 4))

    def bulka(x, y, z, r=0.045):
        b = lathe('bulka', [(0.0, 0.0), (0.6, 0.0), (1.0, 0.3), (0.85, 0.7), (0.4, 0.95), (0.0, 1.0)], jasny, 10)
        b.scale = (r, r, r * 1.3)
        b.location = (x, y, z)
        t.append(b)

    yg = 0.05
    # półka górna: okrągłe bochny oparte o tył i bułki
    z2 = polki[1] + 0.0125
    for i in range(4):
        x = xw0 + 0.22 + i * 0.4
        b = lathe('bochen', [(0.0, 0.0), (0.6, 0.0), (0.96, 0.25), (1.0, 0.5), (0.8, 0.85), (0.4, 1.0), (0.0, 1.0)], skorka[i % 4], 14)
        b.scale = (0.13, 0.13, 0.07)
        b.rotation_euler = (math.radians(70), 0, 0)
        b.location = (x, yg + 0.14, z2 + 0.13)
        t.append(b)
    for i in range(9):
        bulka(xw0 + 0.14 + i * 0.185, yg - 0.03 + 0.02 * (i % 2), z2)
    # półka dolna: podłużne bochenki w rzędzie
    z1 = polki[0] + 0.0125
    for i in range(5):
        bochenek(xw0 + 0.22 + i * 0.36, yg + 0.02, z1, i, 0.3, 0.14, 0.11, R90 + rnd.uniform(-0.12, 0.12))
    # parapet: kosz z bagietkami, blacha drożdżówek, pudełko ciastek
    zp = zo + 0.04
    kx = xw0 + 0.26
    t.append(lathe('kosz', [(0.0, 0.0), (0.11, 0.0), (0.14, 0.34), (0.15, 0.36), (0.13, 0.36), (0.1, 0.02), (0.0, 0.02)], mat('wiklina', wz('a07a42', 'tkanina'), 0.9, wzor='tkanina'), 14, loc=(kx, yg, zp)))
    for i in range(6):
        a = i / 6 * math.tau
        t.append(tube('bagietka', [(kx + math.cos(a) * 0.05, yg + math.sin(a) * 0.05, zp + 0.04), (kx + math.cos(a) * 0.09, yg + math.sin(a) * 0.09, zp + 0.62 + 0.04 * (i % 3))], 0.028, skorka[i % 4], 6, taper=0.02))
    bx = xw0 + 0.95
    t.append(rbox('blacha', (0.62, 0.36, 0.02), stal, 0.006, (bx, yg - 0.02, zp + 0.01), (math.radians(-10), 0, 0)))
    for i in range(4):
        for j in range(2):
            d = lathe('drozdzowka', [(0.0, 0.0), (0.7, 0.0), (1.0, 0.4), (0.75, 0.85), (0.35, 1.0), (0.0, 0.8)], jasny, 10)
            d.scale = (0.06, 0.06, 0.035)
            d.location = (bx - 0.22 + i * 0.147, yg - 0.1 + j * 0.15, zp + 0.03 + j * 0.026)
            t.append(d)
            k = lathe('nadzienie', [(0.0, 0.0), (0.5, 0.0), (0.4, 0.3), (0.0, 0.35)], mat('nadzienie%d' % ((i + j) % 2), ('7a2a3a', 'e8d9a0')[(i + j) % 2], 0.4), 8)
            k.scale = (0.03, 0.03, 0.02)
            k.location = (bx - 0.22 + i * 0.147, yg - 0.1 + j * 0.15, zp + 0.062 + j * 0.026)
            t.append(k)
    cx = xw1 - 0.34
    t.append(rbox('paleta_ciastek', (0.4, 0.3, 0.05), bialy, 0.008, (cx, yg, zp + 0.025)))
    for i in range(5):
        for j in range(3):
            c = lathe('ciastko', [(0.0, 0.0), (1.0, 0.0), (1.0, 0.6), (0.6, 1.0), (0.0, 1.0)], skorka[(i + j) % 4], 8)
            c.scale = (0.03, 0.03, 0.014)
            c.location = (cx - 0.15 + i * 0.075, yg - 0.09 + j * 0.09, zp + 0.05)
            t.append(c)
    # tabliczki
    napisy = []
    t.append(rbox('deska', (W - 0.3, 0.014, 0.2), mat('deska', 'f0e6cc', 0.6), 0.004, (0, yf - 0.045, H - 0.15)))
    napisy.append(text('deska_t', 'FRESH BREAD DAILY', 0.1, mat('braz_n', '5a3414', 0.6), (0, yf - 0.054, H - 0.183)))
    t.append(rbox('godziny', (0.3, 0.008, 0.16), bialy, 0.004, (xo, yd - 0.04, zd0 + 0.48)))
    napisy.append(text('godz_1', 'OPEN 6–15', 0.05, tusz, (xo, yd - 0.046, zd0 + 0.5)))
    napisy.append(text('godz_2', 'ROLLS  0.60', 0.03, czerw, (xo, yd - 0.046, zd0 + 0.43)))
    t.append(rbox('cena', (0.2, 0.004, 0.1), bialy, 0.003, (xw0 + 0.62, yg - 0.12, z1 + 0.05), (math.radians(-12), 0, 0)))
    napisy.append(text('cena_t', 'BREAD 3.50', 0.03, tusz, (xw0 + 0.62, yg - 0.125, z1 + 0.04), rot=(math.radians(78), 0, 0)))
    join('Towar', t)
    join('Napisy', napisy)
    szklo = mat('szklo', 'a9c6d6', 0.06, 0.1, 0.0, 0.14)
    join('Szyby', [rbox('szyba', (ww, 0.008, zt - zo - 0.06), szklo, 0.0, (xc, yf + 0.1, (zt + zo) / 2), segs=1),
                   rbox('szyba_d', (wd - 0.22, 0.006, zd1 - zd0 - 0.92), szklo, 0.0, (xo, yd - 0.01, zd0 + 0.76 + (zd1 - zd0 - 0.92) / 2), segs=1)])
    join('SwiatloWitryna', [rbox('swietlowka', (ww - 0.3, 0.035, 0.03), mat('swiatlo', 'ffe2b0', 0.4, 0.0, 3.0), 0.008, (xc, -0.05, zt - 0.045))])
    join('OpenRamka', [rbox('open_tlo', (0.3, 0.014, 0.12), tusz, 0.006, (xo, yd - 0.02, zd0 + 1.55))])
    join('SwiatloOpen', [text('open_t', 'OPEN', 0.07, mat('neon', 'ffb347', 0.4, 0.0, 4.0), (xo, yd - 0.03, zd0 + 1.525), depth=0.003)])
    weather([wit], 2048, 0.3, 0.45, (0.14, 0.12, 0.1))
    export('piekarnia_witryna')


def kebab_witryna():
    reset()
    rnd = random.Random(8)
    rama = mat('rama', 'b33a2c', 0.6)
    rama_c = mat('rama_c', '8f2c22', 0.6)
    plytki = mat('plytki', wz('d8d4c8', 'beton'), 0.5, wzor='beton')
    tlo = mat('wnetrze', '6a625a', 0.9)
    stal = mat('stal', 'aeb3b8', 0.4)
    bialy = mat('bialy', 'ecebe4', 0.6)
    tusz = mat('tusz', '26221f', 0.6)
    zolty = mat('zolty', 'f0c030', 0.55)
    zo, zt = 1.0, H - 0.3
    xd0, xd1 = 0.52, W / 2 - 0.12
    xw0, xw1 = -W / 2 + 0.12, xd0 - 0.14
    xc, ww = (xw0 + xw1) / 2, xw1 - xw0
    xo, wd = (xd0 + xd1) / 2, xd1 - xd0
    p = []
    portal(p, rama, rama_c, plytki, tlo, xw0, xw1, zo, zt, (-W / 2 + 0.06, xd0 - 0.07, W / 2 - 0.06))
    # lada wysunięta na chodnik, blat roboczy w środku, okap nad rożnem
    p.append(rbox('lada', (ww + 0.06, D + 0.22, 0.05), stal, 0.008, (xc, -0.11, zo + 0.025)))
    for sx in (xw0 + 0.2, xw1 - 0.2):
        p.append(tube('wspornik', [(sx, yf, zo - 0.26), (sx, yf - 0.2, zo - 0.01)], 0.012, stal, 5))
    p.append(rbox('okap', (0.62, 0.34, 0.16), stal, 0.012, (xw0 + 0.42, 0.06, zt - 0.1)))
    p.append(rbox('rama_g', (ww, 0.05, 0.05), rama_c, 0.006, (xc, yf + 0.06, zt - 0.03)))
    # drzwi pełne z bulajem
    p.append(rbox('stopien', (wd + 0.3, 0.42, 0.14), plytki, 0.012, (xo, yf - 0.1, 0.07)))
    zd0, zd1, yd = 0.14, zt, 0.08
    p.append(rbox('skrzydlo', (wd - 0.04, 0.05, zd1 - zd0 - 0.02), bialy, 0.008, (xo, yd, (zd0 + zd1) / 2)))
    p.append(rbox('kopniak', (wd - 0.04, 0.012, 0.28), stal, 0.004, (xo, yd - 0.03, zd0 + 0.16)))
    b = lathe('bulaj', [(0.0, 0.0), (0.16, 0.0), (0.16, 0.014), (0.13, 0.014), (0.13, 0.004), (0.0, 0.004)], stal, 20)
    b.rotation_euler = (R90, 0, 0)
    b.location = (xo, yd - 0.028, zd0 + 1.45)
    p.append(b)
    p.append(rbox('klamka_szyld', (0.05, 0.012, 0.2), stal, 0.004, (xd0 + 0.12, yd - 0.032, zd0 + 0.9)))
    p.append(tube('klamka', [(xd0 + 0.12, yd - 0.04, zd0 + 0.94), (xd0 + 0.12, yd - 0.09, zd0 + 0.94), (xd0 + 0.24, yd - 0.09, zd0 + 0.94)], 0.011, stal, 6))
    p.append(rbox('prog', (wd, 0.2, 0.03), stal, 0.004, (xo, yd - 0.08, zd0 + 0.015)))
    # kosz na śmieci przy słupie
    p.append(lathe('kosz', [(0.0, 0.0), (0.15, 0.0), (0.17, 0.5), (0.18, 0.52), (0.16, 0.52), (0.14, 0.02), (0.0, 0.02)], mat('kosz', '4a4f55', 0.6), 14, loc=(-W / 2 - 0.26, yf + 0.02, 0.0)))
    wit = join('Witryna', p)

    t = []
    napisy = []
    zl = zo + 0.05
    # rożen: podstawa, pręt, stożek mięsa (dwa odcienie), grzałka z tyłu
    rx, ry = xw0 + 0.42, 0.04
    t.append(lathe('rozen_podstawa', [(0.0, 0.0), (0.16, 0.0), (0.16, 0.03), (0.03, 0.04), (0.0, 0.04)], stal, 16, loc=(rx, ry, zl)))
    t.append(tube('rozen_pret', [(rx, ry, zl), (rx, ry, zl + 0.86)], 0.008, stal, 6))
    t.append(lathe('mieso', [(0.0, 0.06), (0.1, 0.06), (0.125, 0.12), (0.13, 0.3), (0.115, 0.52), (0.09, 0.68), (0.06, 0.76), (0.0, 0.78)], mat('mieso', '8a4a26', 0.8), 18, loc=(rx, ry, zl)))
    for k in range(7):
        z = zl + 0.1 + k * 0.095
        r = 0.132 - 0.0009 * (k * 9) ** 1.2
        t.append(tube('warstwa', [(rx + math.cos(i / 16 * math.tau) * r, ry + math.sin(i / 16 * math.tau) * r, z + 0.008 * math.sin(i * 1.7)) for i in range(17)], 0.006, mat('mieso_c', '6a3418', 0.8), 4))
    t.append(lathe('rozen_czubek', [(0.0, 0.78), (0.03, 0.78), (0.035, 0.8), (0.0, 0.84)], mat('cebula', 'e8dcc0', 0.6), 10, loc=(rx, ry, zl)))
    t.append(rbox('grzalka_obudowa', (0.3, 0.05, 0.7), stal, 0.008, (rx, ry + 0.17, zl + 0.42)))
    # blacha z dodatkami: pojemniki GN z sałatą, pomidorem, cebulą, sosem
    gx = xw0 + 1.06
    t.append(rbox('gn_rama', (0.7, 0.3, 0.06), stal, 0.006, (gx, 0.02, zl + 0.03)))
    for i, c in enumerate(('5f9a3a', 'c8382a', 'e6dcc6', 'd9c060')):
        x = gx - 0.255 + i * 0.17
        t.append(rbox('gn', (0.15, 0.24, 0.02), mat('dodatek%d' % i, c, 0.8), 0.006, (x, 0.02, zl + 0.062)))
        for k in range(6):
            t.append(rbox('kawalek', (0.03, 0.035, 0.014), mat('dodatek%d' % i, c, 0.8), 0.004, (x + rnd.uniform(-0.05, 0.05), 0.02 + rnd.uniform(-0.09, 0.09), zl + 0.075), (0, 0, rnd.uniform(0, 3))))
    # serwetnik, butelki sosów, stos tacek
    t.append(rbox('serwetnik', (0.12, 0.08, 0.1), stal, 0.006, (xw1 - 0.3, -0.22, zl + 0.05)))
    for i, c in enumerate(('c8382a', 'ecebe4')):
        t.append(lathe('sos', [(0.0, 0.0), (0.028, 0.0), (0.028, 0.12), (0.008, 0.15), (0.005, 0.19), (0.0, 0.19)], mat('sos%d' % i, c, 0.5), 10, loc=(xw1 - 0.14, -0.2 - i * 0.07, zl)))
    for i in range(5):
        t.append(rbox('tacka', (0.16, 0.11, 0.008), bialy, 0.004, (xw0 + 0.16, -0.26, zl + 0.004 + i * 0.008), (0, 0, 0.05 * i)))
    # lodówka z napojami w głębi po prawej
    lx = xw1 - 0.24
    t.append(rbox('lodowka', (0.4, 0.2, 0.86), mat('lodowka', 'd8dade', 0.5), 0.012, (lx, 0.12, zl + 0.43)))
    t.append(rbox('lodowka_wn', (0.34, 0.01, 0.72), mat('lodowka_wn', 'f4f8fb', 0.4, 0.0, 0.6), 0.004, (lx, 0.016, zl + 0.44)))
    for r in range(4):
        for c in range(4):
            t.append(lathe('puszka', [(0.0, 0.0), (0.03, 0.0), (0.03, 0.11), (0.024, 0.12), (0.0, 0.12)], mat('puszka%d' % ((r + c) % 4), ('c8382a', '2f6b3a', 'f0c030', '2a5a9a')[(r + c) % 4], 0.4), 8, loc=(lx - 0.12 + c * 0.08, 0.0, zl + 0.1 + r * 0.17)))
        t.append(rbox('lodowka_polka', (0.34, 0.1, 0.008), stal, 0.0, (lx, 0.02, zl + 0.095 + r * 0.17), segs=1))
    # menu nad okienkiem, deska, naklejki
    t.append(rbox('menu', (1.16, 0.012, 0.36), tusz, 0.006, (xw0 + 1.2, yb - 0.04, zt - 0.3)))
    napisy.append(text('m0', 'MENU', 0.055, zolty, (xw0 + 1.2, yb - 0.048, zt - 0.2)))
    for i, (a, b2) in enumerate((('KEBAB ROLL', '12'), ('KEBAB BOX', '14'), ('FALAFEL', '11'), ('FRIES', '6'))):
        napisy.append(text('m%da' % i, a, 0.036, bialy, (xw0 + 0.7, yb - 0.048, zt - 0.265 - i * 0.052), align='LEFT'))
        napisy.append(text('m%db' % i, b2, 0.036, zolty, (xw0 + 1.7, yb - 0.048, zt - 0.265 - i * 0.052), align='RIGHT'))
    t.append(rbox('deska', (W - 0.3, 0.014, 0.2), zolty, 0.004, (0, yf - 0.045, H - 0.15)))
    napisy.append(text('deska_t', 'KEBAB • FALAFEL • FRIES', 0.09, mat('czerwony_n', '8f2c22', 0.6), (0, yf - 0.054, H - 0.18)))
    t.append(rbox('nakl', (0.9, 0.008, 0.2), bialy, 0.004, (xc, yf - 0.004, 0.5)))
    napisy.append(text('nakl_t', 'OPEN TILL 23', 0.075, mat('czerwony_n', '8f2c22', 0.6), (xc, yf - 0.01, 0.5)))
    napisy.append(text('nakl_t2', 'EXTRA SAUCE FREE', 0.03, tusz, (xc, yf - 0.01, 0.435)))
    join('Towar', t)
    join('Napisy', napisy)
    szklo = mat('szklo', 'a9c6d6', 0.06, 0.1, 0.0, 0.12)
    join('Szyby', [rbox('szyba_bulaj', (0.25, 0.006, 0.25), szklo, 0.0, (xo, yd - 0.03, zd0 + 1.45), segs=1),
                   rbox('oslona', (ww - 0.5, 0.008, 0.34), szklo, 0.0, (xc + 0.2, yf - 0.02, zl + 0.2), (math.radians(-18), 0, 0), segs=1)])
    join('SwiatloWitryna', [rbox('swietlowka', (ww - 0.3, 0.035, 0.03), mat('swiatlo', 'fff1d8', 0.4, 0.0, 3.2), 0.008, (xc, -0.05, zt - 0.045)),
                            rbox('grzalka', (0.24, 0.012, 0.6), mat('zar', 'ff5a1e', 0.5, 0.0, 3.0), 0.004, (rx, ry + 0.14, zl + 0.42))])
    join('OpenRamka', [rbox('open_tlo', (0.34, 0.014, 0.14), tusz, 0.006, (xo, yd - 0.035, zd0 + 1.82))])
    join('SwiatloOpen', [text('open_t', 'OPEN', 0.085, mat('neon', 'ff4a3a', 0.4, 0.0, 4.5), (xo, yd - 0.045, zd0 + 1.79), depth=0.003)])
    weather([wit], 2048, 0.3, 0.45, (0.14, 0.12, 0.1))
    export('kebab_witryna')


def fryzjer_witryna():
    """salon fryzjerski: okno z fotelem na chromowanej nodze, suszarką hełmową, lustrem i półką z kosmetykami,
    plakaty fryzur, cennik, drzwi z szybą"""
    reset()
    rama = mat('rama', 'b08ab8', 0.6)
    rama_c = mat('rama_c', '8f6a98', 0.6)
    plytki = mat('plytki', wz('d8d0d8', 'beton'), 0.5, wzor='beton')
    tlo = mat('wnetrze', 'cfc3c9', 0.9)
    bialy = mat('bialy', 'ecebe4', 0.6)
    tusz = mat('tusz', '2a2630', 0.6)
    stal = mat('stal', 'b4b8bd', 0.4)
    skaj = mat('skaj', '6a2f4a', 0.5)
    roz = mat('roz', 'd0508a', 0.6)
    zo, zt = 0.5, H - 0.3
    xd0, xd1 = 0.52, W / 2 - 0.12
    xw0, xw1 = -W / 2 + 0.12, xd0 - 0.14
    xc, ww = (xw0 + xw1) / 2, xw1 - xw0
    xo, wd = (xd0 + xd1) / 2, xd1 - xd0
    p = []
    portal(p, rama, rama_c, plytki, tlo, xw0, xw1, zo, zt, (-W / 2 + 0.06, xd0 - 0.07, W / 2 - 0.06))
    p.append(rbox('parapet', (ww, D - 0.02, 0.04), bialy, 0.006, (xc, 0.0, zo + 0.02)))
    p.append(rbox('rama_d', (ww, 0.05, 0.05), rama_c, 0.006, (xc, yf + 0.06, zo + 0.045)))
    p.append(rbox('rama_g', (ww, 0.05, 0.05), rama_c, 0.006, (xc, yf + 0.06, zt - 0.03)))
    # drzwi z szybą
    p.append(rbox('stopien', (wd + 0.3, 0.42, 0.14), plytki, 0.012, (xo, yf - 0.1, 0.07)))
    zd0, zd1, yd = 0.14, zt, 0.08
    p.append(rbox('skrzydlo_d', (wd - 0.04, 0.05, 0.6), rama, 0.008, (xo, yd, zd0 + 0.3)))
    for x in (xd0 + 0.07, xd1 - 0.07):
        p.append(rbox('ramiak', (0.1, 0.05, zd1 - zd0 - 0.02), rama, 0.008, (x, yd, (zd0 + zd1) / 2)))
    p.append(rbox('ramiak_g', (wd - 0.04, 0.05, 0.12), rama, 0.008, (xo, yd, zd1 - 0.07)))
    p.append(rbox('wnetrze_d', (wd - 0.2, 0.02, zd1 - zd0 - 0.75), tlo, 0.0, (xo, yd + 0.05, zd0 + 0.6 + (zd1 - zd0 - 0.75) / 2), segs=1))
    p.append(tube('pochwyt', [(xd0 + 0.16, yd - 0.03, zd0 + 0.8), (xd0 + 0.16, yd - 0.075, zd0 + 0.86), (xd0 + 0.16, yd - 0.075, zd0 + 1.2), (xd0 + 0.16, yd - 0.03, zd0 + 1.26)], 0.011, stal, 6))
    p.append(rbox('prog', (wd, 0.2, 0.03), stal, 0.004, (xo, yd - 0.08, zd0 + 0.015)))
    wit = join('Witryna', p)

    t = []
    napisy = []
    zp = zo + 0.04
    # fotel fryzjerski: chromowana noga z talerzem, siedzisko, oparcie, podłokietniki, podnóżek
    fx = xw0 + 0.62
    t.append(lathe('fotel_noga', [(0.0, 0.0), (0.2, 0.0), (0.2, 0.012), (0.04, 0.03), (0.03, 0.34), (0.0, 0.34)], stal, 16, loc=(fx, 0.0, zp)))
    t.append(rbox('fotel_siedzisko', (0.42, 0.34, 0.09), skaj, 0.03, (fx, -0.02, zp + 0.39)))
    t.append(rbox('fotel_oparcie', (0.4, 0.08, 0.46), skaj, 0.03, (fx, 0.15, zp + 0.66), (math.radians(-8), 0, 0)))
    for sx in (-1, 1):
        t.append(tube('podlokietnik', [(fx + sx * 0.22, 0.14, zp + 0.5), (fx + sx * 0.23, 0.02, zp + 0.58), (fx + sx * 0.23, -0.14, zp + 0.58)], 0.018, stal, 6))
    t.append(tube('podnozek', [(fx - 0.14, -0.2, zp + 0.14), (fx + 0.14, -0.2, zp + 0.14)], 0.014, stal, 6))
    t.append(tube('podnozek_r', [(fx, -0.2, zp + 0.14), (fx, -0.02, zp + 0.3)], 0.012, stal, 5))
    # suszarka hełmowa na stojaku
    sx0 = xw0 + 1.35
    t.append(lathe('susz_podstawa', [(0.0, 0.0), (0.18, 0.0), (0.18, 0.015), (0.02, 0.03), (0.018, 1.02), (0.0, 1.02)], stal, 14, loc=(sx0, 0.06, zp)))
    hl = lathe('helm', [(0.0, 0.2), (0.1, 0.19), (0.17, 0.14), (0.2, 0.05), (0.2, -0.06), (0.185, -0.06), (0.18, 0.04), (0.15, 0.12), (0.09, 0.17), (0.0, 0.18)], mat('helm', 'e6dfe6', 0.4), 18)
    hl.rotation_euler = (math.radians(-20), 0, 0)
    hl.location = (sx0, -0.02, zp + 1.1)
    t.append(hl)
    t.append(tube('susz_ramie', [(sx0, 0.06, zp + 1.0), (sx0, 0.03, zp + 1.16)], 0.02, stal, 6))
    # lustro na tylnej ścianie i półka z kosmetykami
    t.append(rbox('lustro_rama', (0.62, 0.02, 0.9), bialy, 0.01, (fx, yb - 0.04, zp + 1.05)))
    t.append(rbox('lustro', (0.54, 0.012, 0.82), mat('lustro', 'b9cdd6', 0.1), 0.004, (fx, yb - 0.052, zp + 1.05)))
    t.append(rbox('polka', (0.7, 0.14, 0.02), bialy, 0.004, (sx0 + 0.02, yb - 0.1, zp + 1.5)))
    for i in range(6):
        c = ('d0508a', '5aa0c8', 'e2b21c', 'ecebe4', '8f6a98', '5fae7a')[i]
        h2 = 0.1 + 0.03 * (i % 3)
        t.append(lathe('kosmetyk', [(0.0, 0.0), (0.024, 0.0), (0.024, h2 * 0.75), (0.01, h2 * 0.85), (0.01, h2), (0.0, h2)], mat('kosm%d' % i, c, 0.4), 8, loc=(sx0 - 0.25 + i * 0.105, yb - 0.1, zp + 1.51)))
    # kwiat w donicy i stolik z gazetami
    kx = xw1 - 0.22
    t.append(lathe('donica', [(0.0, 0.0), (0.09, 0.0), (0.12, 0.24), (0.105, 0.24), (0.08, 0.02), (0.0, 0.02)], mat('donica', 'c9b8a0', 0.8), 12, loc=(kx, 0.0, zp)))
    for i in range(9):
        a = i / 9 * math.tau
        t.append(tube('lisc', [(kx, 0.0, zp + 0.22), (kx + math.cos(a) * 0.1, math.sin(a) * 0.1, zp + 0.5 + 0.08 * (i % 3)), (kx + math.cos(a) * 0.2, math.sin(a) * 0.17, zp + 0.5 + 0.05 * (i % 2))], 0.016, mat('lisc', '3f7a3a', 0.8), 4, taper=0.003))
    # plakaty fryzur na szybie, cennik, deska
    for i, c in enumerate(('d0508a', '5aa0c8')):
        x = xw0 + 0.22 + i * 1.72
        t.append(rbox('plakat', (0.3, 0.004, 0.42), mat('plakat%d' % i, c, 0.6), 0.004, (x, yf + 0.092, zo + 1.25)))
        g = lathe('glowa', [(0.0, 0.0), (1.0, 0.0), (1.0, 0.1), (0.0, 0.1)], bialy, 16)
        g.scale = (0.075, 0.09, 0.02)
        g.rotation_euler = (R90, 0, 0)
        g.location = (x, yf + 0.089, zo + 1.2)
        t.append(g)
        w = lathe('wlosy', [(0.0, 0.0), (1.0, 0.0), (1.0, 0.1), (0.0, 0.1)], tusz, 16)
        w.scale = (0.1, 0.075, 0.02)
        w.rotation_euler = (R90, 0, 0)
        w.location = (x, yf + 0.086, zo + 1.29)
        t.append(w)
    t.append(rbox('cennik', (0.34, 0.008, 0.3), bialy, 0.004, (xo, yd - 0.04, zd0 + 0.36)))
    napisy.append(text('c0', 'CUT  25', 0.04, tusz, (xo, yd - 0.046, zd0 + 0.44)))
    napisy.append(text('c1', 'PERM  60', 0.04, tusz, (xo, yd - 0.046, zd0 + 0.37)))
    napisy.append(text('c2', 'COLOUR  80', 0.04, tusz, (xo, yd - 0.046, zd0 + 0.3)))
    t.append(rbox('deska', (W - 0.3, 0.014, 0.2), mat('deska', 'f3e6ee', 0.6), 0.004, (0, yf - 0.045, H - 0.15)))
    napisy.append(text('deska_t', 'CUTS • PERMS • COLOUR', 0.095, mat('roz_n', 'a03870', 0.6), (0, yf - 0.054, H - 0.182)))
    t.append(rbox('nakl', (0.9, 0.008, 0.16), bialy, 0.004, (xc, yf - 0.004, 0.25)))
    napisy.append(text('nakl_t', 'WALK-INS WELCOME', 0.05, mat('roz_n', 'a03870', 0.6), (xc, yf - 0.01, 0.235)))
    join('Towar', t)
    join('Napisy', napisy)
    szklo = mat('szklo', 'a9c6d6', 0.06, 0.1, 0.0, 0.14)
    join('Szyby', [rbox('szyba', (ww, 0.008, zt - zo - 0.06), szklo, 0.0, (xc, yf + 0.1, (zt + zo) / 2), segs=1),
                   rbox('szyba_d', (wd - 0.22, 0.006, zd1 - zd0 - 0.77), szklo, 0.0, (xo, yd - 0.01, zd0 + 0.61 + (zd1 - zd0 - 0.77) / 2), segs=1)])
    join('SwiatloWitryna', [rbox('swietlowka', (ww - 0.3, 0.035, 0.03), mat('swiatlo', 'fff0f6', 0.4, 0.0, 3.0), 0.008, (xc, -0.05, zt - 0.045))])
    join('OpenRamka', [rbox('open_tlo', (0.3, 0.014, 0.12), tusz, 0.006, (xo, yd - 0.02, zd0 + 1.6))])
    join('SwiatloOpen', [text('open_t', 'OPEN', 0.07, mat('neon', 'ff5aa8', 0.4, 0.0, 4.0), (xo, yd - 0.03, zd0 + 1.575), depth=0.003)])
    weather([wit], 2048, 0.28, 0.45, (0.14, 0.12, 0.11))
    export('fryzjer_witryna')


def pogrzebowy_witryna():
    """zakład pogrzebowy: stonowany portal z kamienia, okno z fioletową kotarą, wieniec na stojaku, urna na postumencie,
    znicze, tabliczka z telefonem całodobowym, drzwi z matową szybą"""
    reset()
    rama = mat('rama', wz('6a6e76', 'beton'), 0.6, wzor='beton')
    rama_c = mat('rama_c', wz('54585f', 'beton'), 0.6, wzor='beton')
    cokol = mat('cokol', wz('4e5258', 'beton'), 0.5, wzor='beton')
    tlo = mat('kotara', wz('5a4668', 'tkanina'), 0.95, wzor='tkanina')
    zloto = mat('zloto', 'c9a85a', 0.4, 0.3)
    bialy = mat('bialy', 'ecebe4', 0.6)
    kamien = mat('kamien', 'b9b6ae', 0.5)
    tusz = mat('tusz', '2c2e34', 0.6)
    zo, zt = 0.6, H - 0.3
    xd0, xd1 = 0.52, W / 2 - 0.12
    xw0, xw1 = -W / 2 + 0.12, xd0 - 0.14
    xc, ww = (xw0 + xw1) / 2, xw1 - xw0
    xo, wd = (xd0 + xd1) / 2, xd1 - xd0
    p = []
    portal(p, rama, rama_c, cokol, tlo, xw0, xw1, zo, zt, (-W / 2 + 0.06, xd0 - 0.07, W / 2 - 0.06))
    # fałdy kotary w tle
    for i in range(14):
        x = xw0 + 0.07 + i * (ww - 0.14) / 13
        p.append(tube('falda', [(x, yb - 0.06, zo + 0.05), (x, yb - 0.06, zt - 0.03)], 0.035, tlo, 6))
    p.append(rbox('parapet', (ww, D - 0.02, 0.04), kamien, 0.006, (xc, 0.0, zo + 0.02)))
    p.append(rbox('rama_d', (ww, 0.05, 0.05), rama_c, 0.006, (xc, yf + 0.06, zo + 0.045)))
    p.append(rbox('rama_g', (ww, 0.05, 0.05), rama_c, 0.006, (xc, yf + 0.06, zt - 0.03)))
    p.append(rbox('stopien', (wd + 0.3, 0.42, 0.14), cokol, 0.012, (xo, yf - 0.1, 0.07)))
    zd0, zd1, yd = 0.14, zt, 0.08
    drzwi = mat('drzwi', '4a4e56', 0.5)
    p.append(rbox('skrzydlo', (wd - 0.04, 0.05, zd1 - zd0 - 0.02), drzwi, 0.008, (xo, yd, (zd0 + zd1) / 2)))
    p.append(rbox('szyba_mat', (wd - 0.3, 0.012, 1.0), mat('szyba_mat', 'c4c8cc', 0.6), 0.01, (xo, yd - 0.03, zd0 + 1.25)))
    p.append(tube('pochwyt', [(xd0 + 0.14, yd - 0.03, zd0 + 0.75), (xd0 + 0.14, yd - 0.08, zd0 + 0.8), (xd0 + 0.14, yd - 0.08, zd0 + 1.3), (xd0 + 0.14, yd - 0.03, zd0 + 1.35)], 0.012, zloto, 6))
    p.append(rbox('prog', (wd, 0.2, 0.03), kamien, 0.004, (xo, yd - 0.08, zd0 + 0.015)))
    wit = join('Witryna', p)

    t = []
    napisy = []
    zp = zo + 0.04
    # wieniec na trójnogu: obręcz z liści, białe i czerwone kwiaty, szarfa
    wx, wz0 = xw0 + 0.55, zp + 0.78
    for sxx, sy in ((-0.2, 0.0), (0.2, 0.0), (0.0, 0.16)):
        t.append(tube('trojnog', [(wx + sxx, 0.02 + sy, zp), (wx, 0.06, zp + 1.1)], 0.01, tusz, 5))
    wr = lathe('wieniec', [(0.25, -0.05), (0.31, -0.035), (0.33, 0.0), (0.31, 0.035), (0.25, 0.05), (0.21, 0.035), (0.19, 0.0), (0.21, -0.035), (0.25, -0.05)], mat('zielen', '2f5a34', 0.9), 22)
    wr.rotation_euler = (math.radians(78), 0, 0)
    wr.location = (wx, 0.0, wz0)
    t.append(wr)
    for i in range(14):
        a = i / 14 * math.tau
        kw = lathe('kwiat', [(0.0, 0.0), (0.7, 0.05), (1.0, 0.4), (0.6, 0.85), (0.0, 1.0)], mat('kwiat%d' % (i % 2), ('ecebe4', 'a8262a')[i % 2], 0.8), 8)
        kw.scale = (0.045, 0.045, 0.03)
        kw.rotation_euler = (math.radians(78), 0, 0)
        kw.location = (wx + math.cos(a) * 0.26, -0.055 - 0.02 * math.sin(a), wz0 + math.sin(a) * 0.255)
        t.append(kw)
    t.append(rbox('szarfa', (0.07, 0.006, 0.5), bialy, 0.004, (wx - 0.1, -0.085, wz0 - 0.12), (0, math.radians(18), 0)))
    t.append(rbox('szarfa2', (0.07, 0.006, 0.5), bialy, 0.004, (wx + 0.1, -0.085, wz0 - 0.12), (0, math.radians(-18), 0)))
    # urna na postumencie, znicze, krzyż z tabliczką
    ux = xw0 + 1.4
    t.append(rbox('postument', (0.3, 0.26, 0.6), kamien, 0.012, (ux, 0.02, zp + 0.3)))
    t.append(lathe('urna', [(0.0, 0.0), (0.06, 0.0), (0.07, 0.015), (0.11, 0.1), (0.115, 0.2), (0.09, 0.27), (0.06, 0.29), (0.065, 0.3), (0.05, 0.32), (0.02, 0.34), (0.0, 0.36)], mat('urna', '5a5f6a', 0.35, 0.3), 16, loc=(ux, 0.02, zp + 0.6)))
    t.append(tube('urna_pas', [(ux + math.cos(i / 16 * math.tau) * 0.116, 0.02 + math.sin(i / 16 * math.tau) * 0.116, zp + 0.78) for i in range(17)], 0.005, zloto, 4))
    for i, x in enumerate((xw1 - 0.42, xw1 - 0.22)):
        t.append(lathe('znicz', [(0.0, 0.0), (0.05, 0.0), (0.06, 0.02), (0.06, 0.16), (0.045, 0.19), (0.05, 0.2), (0.03, 0.22), (0.0, 0.22)], mat('znicz%d' % i, ('a8262a', 'ecebe4')[i], 0.3, 0.0, 0.0, 0.8), 12, loc=(x, -0.02 - i * 0.06, zp)))
        t.append(lathe('znicz_wieko', [(0.0, 0.22), (0.035, 0.22), (0.04, 0.235), (0.0, 0.26)], zloto, 10, loc=(x, -0.02 - i * 0.06, zp)))
    t.append(rbox('tablica', (0.5, 0.012, 0.3), tusz, 0.006, (xw1 - 0.34, yb - 0.1, zp + 0.9)))
    napisy.append(text('tb1', 'ETERNITAS', 0.06, zloto, (xw1 - 0.34, yb - 0.108, zp + 0.95)))
    napisy.append(text('tb2', 'FUNERAL SERVICES', 0.03, bialy, (xw1 - 0.34, yb - 0.108, zp + 0.88)))
    napisy.append(text('tb3', 'DAY AND NIGHT', 0.026, bialy, (xw1 - 0.34, yb - 0.108, zp + 0.82)))
    t.append(rbox('deska', (W - 0.3, 0.014, 0.2), tusz, 0.004, (0, yf - 0.045, H - 0.15)))
    napisy.append(text('deska_t', 'ETERNITAS  •  SINCE 1974', 0.09, zloto, (0, yf - 0.054, H - 0.18)))
    t.append(rbox('tel', (0.34, 0.008, 0.12), bialy, 0.004, (xo, yd - 0.04, zd0 + 0.5)))
    napisy.append(text('tel_t', 'RING AT NIGHT', 0.034, tusz, (xo, yd - 0.046, zd0 + 0.49)))
    join('Towar', t)
    join('Napisy', napisy)
    szklo = mat('szklo', 'a9c6d6', 0.06, 0.1, 0.0, 0.14)
    join('Szyby', [rbox('szyba', (ww, 0.008, zt - zo - 0.06), szklo, 0.0, (xc, yf + 0.1, (zt + zo) / 2), segs=1)])
    join('SwiatloWitryna', [rbox('swietlowka', (ww - 0.3, 0.035, 0.03), mat('swiatlo', 'f4e8ff', 0.4, 0.0, 2.2), 0.008, (xc, -0.05, zt - 0.045)),
                            rbox('plomyk1', (0.012, 0.012, 0.03), mat('plomyk', 'ffb040', 0.4, 0.0, 4.0), 0.004, (xw1 - 0.42, -0.02, zp + 0.12)),
                            rbox('plomyk2', (0.012, 0.012, 0.03), mat('plomyk', 'ffb040', 0.4, 0.0, 4.0), 0.004, (xw1 - 0.22, -0.08, zp + 0.12))])
    weather([wit], 2048, 0.28, 0.45, (0.14, 0.12, 0.11))
    export('pogrzebowy_witryna')


ALL = {'piekarnia_witryna': piekarnia_witryna, 'kebab_witryna': kebab_witryna, 'fryzjer_witryna': fryzjer_witryna, 'pogrzebowy_witryna': pogrzebowy_witryna}
only = [a for a in sys.argv[sys.argv.index('--') + 1:]] if '--' in sys.argv else []
for name, fn in ALL.items():
    if not only or name in only:
        fn()
