"""Witryna hurtowni budowlanej 4,4 × 2,65 m (przód = −Y, spód na z = 0, tył przy ścianie budynku na y = +0,3):
stalowy portal z podniesioną roletą, wystawa z regałem (wiadra i puszki farb, kartony z lampami LED, szkło
laboratoryjne, kanistry, zwój kabla, rolka siatki), okienko z ladą, dzwonkiem i cennikiem, drabina oparta o słupek.
Napisy i świecące elementy są osobnymi obiektami bez wypalanego brudu."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
from lib import _finish

R90 = math.radians(90)
rnd = random.Random(31)
FARBY = ['c0392b', '2471a3', 'd4ac0d', '1e8449', 'e8e4d8', 'ca6f1e', '566573', '7d3c98']


def witryna():
    reset()
    W, H, D = 4.4, 2.65, 0.6
    yb, yf = D / 2, -D / 2
    st = mat('stal', '7d8286', 0.45, 0.8)
    stc = mat('stal_c', '3b4045', 0.5, 0.7)
    tlo = mat('wnetrze', '14181b', 0.95)
    mur = mat('cokol', '6b665e', 0.9, wzor='beton')
    drew = mat('drewno', '8a6a42', 0.85, wzor='drewno')
    karton = mat('karton', 'b08a56', 0.9, wzor='karton')
    bialy = mat('bialy', 'ecebe4', 0.6)
    tusz = mat('tusz', '15161a', 0.6)
    zolty = mat('zolty', 'd9a514', 0.55, 0.2)
    alu = mat('alu', 'b9bdc0', 0.35, 0.9)
    zo = 0.5                      # wierzch cokołu
    zt = H - 0.34                 # spód skrzynki rolety
    hw = zt - zo                  # wysokość otworu
    # podział: wystawa po lewej, okienko z ladą po prawej
    xm = 0.72                     # słupek między nimi
    xl0, xl1 = -W / 2 + 0.16, xm - 0.06
    xr0, xr1 = xm + 0.06, W / 2 - 0.16
    p = []
    # --- portal: cokół, słupy, skrzynka rolety z listwami, prowadnice
    p.append(rbox('cokol', (W, D, zo), mur, 0.012, (0, 0, zo / 2)))
    p.append(rbox('cokol_listwa', (W + 0.03, D + 0.03, 0.05), stc, 0.008, (0, 0, zo - 0.02)))
    for sx in (-1, 1):
        p.append(rbox('slup', (0.16, D + 0.04, H), stc, 0.012, (sx * (W / 2 - 0.08), 0, H / 2)))
        p.append(rbox('prowadnica', (0.05, 0.06, hw), st, 0.006, (sx * (W / 2 - 0.185), yf + 0.05, zo + hw / 2)))
    p.append(rbox('slup_s', (0.12, D, hw), stc, 0.01, (xm, 0, zo + hw / 2)))
    p.append(rbox('skrzynka', (W, D + 0.06, 0.34), st, 0.02, (0, -0.01, H - 0.17)))
    for i in range(3):
        p.append(rbox('listwa', (W - 0.34, 0.03, 0.07), st, 0.01, (0, yf + 0.06, zt - 0.04 - i * 0.075)))
    p.append(rbox('tlo', (W - 0.3, 0.03, hw), tlo, 0.0, (0, yb - 0.02, zo + hw / 2), segs=1))
    p.append(rbox('sufit', (W - 0.3, D - 0.06, 0.02), tlo, 0.0, (0, 0.02, zt - 0.32), segs=1))
    # --- wystawa: deska parapetu, regał z trzema półkami
    xc = (xl0 + xl1) / 2
    p.append(rbox('parapet', (xl1 - xl0, D + 0.08, 0.05), drew, 0.008, (xc, -0.03, zo + 0.025)))
    polki = [0.93, 1.31, 1.69]
    for x in (xl0 + 0.06, xc, xl1 - 0.06):
        p.append(rbox('reg_slup', (0.04, 0.04, 1.5), st, 0.004, (x, 0.14, zo + 0.05 + 0.75)))
        p.append(rbox('reg_slup_f', (0.03, 0.03, 1.5), st, 0.004, (x, -0.2, zo + 0.05 + 0.75)))
    for z in polki:
        p.append(rbox('polka', (xl1 - xl0 - 0.06, 0.4, 0.025), st, 0.004, (xc, -0.03, z)))
        p.append(rbox('polka_rant', (xl1 - xl0 - 0.06, 0.012, 0.045), zolty, 0.003, (xc, -0.235, z + 0.005)))
    # --- okienko: lada na wspornikach, blacha pod ladą, rama okienka
    xo = (xr0 + xr1) / 2
    wo = xr1 - xr0
    p.append(rbox('lada', (wo + 0.1, D + 0.28, 0.06), drew, 0.01, (xo, -0.14, 1.0)))
    p.append(rbox('lada_blacha', (wo, 0.04, 0.5), stc, 0.008, (xo, yf + 0.03, 0.74)))
    for i in range(6):
        p.append(rbox('przetloczenie', (0.03, 0.012, 0.42), stc, 0.004, (xr0 + 0.12 + i * (wo - 0.24) / 5, yf + 0.006, 0.74)))
    for sx in (xr0 + 0.12, xr1 - 0.12):
        p.append(tube('wspornik', [(sx, yf, 0.72), (sx, yf - 0.26, 0.96)], 0.014, st, 6))
    p.append(rbox('rama_g', (wo, 0.05, 0.06), st, 0.006, (xo, yf + 0.03, zt - 0.36)))
    p.append(rbox('krata_zwinieta', (wo - 0.06, 0.06, 0.1), stc, 0.02, (xo, yf + 0.06, zt - 0.44)))
    # --- drabina aluminiowa oparta o lewy słup, wiadra przy cokole
    for sx in (-0.19, 0.19):
        p.append(tube('drabina', [(-W / 2 - 0.34 + sx, yf - 0.62, 0.0), (-W / 2 - 0.34 + sx, yf + 0.02, 2.5)], 0.018, alu, 6))
    for i in range(9):
        k = (0.26 + i * 0.26) / 2.5
        p.append(tube('szczebel', [(-W / 2 - 0.53, yf - 0.62 + 0.64 * k, 2.5 * k), (-W / 2 - 0.15, yf - 0.62 + 0.64 * k, 2.5 * k)], 0.012, alu, 5))
    wit = join('Witryna', p)

    # --- towar
    t = []
    napisy = []
    yg = -0.05                    # środek głębokości półek

    def wiadro(x, y, z, k, r=0.13, h=0.25):
        c = mat('farba%d' % k, FARBY[k % len(FARBY)], 0.5)
        t.append(lathe('wiadro', [(0.0, 0.0), (r * 0.88, 0.0), (r, h), (r * 1.04, h), (r * 1.04, h + 0.012), (0.0, h + 0.012)], bialy, 12, loc=(x, y, z)))
        t.append(lathe('etykieta', [(r * 0.905, h * 0.25), (r * 0.975, h * 0.8)], c, 12, loc=(x, y, z)))
        t.append(tube('palak', [(x - r, y, z + h * 0.9), (x - r * 0.7, y - r * 0.9, z + h * 0.55), (x + r * 0.7, y - r * 0.9, z + h * 0.55), (x + r, y, z + h * 0.9)], 0.004, st, 4))

    def puszka(x, y, z, k, r=0.052, h=0.12):
        c = mat('farba%d' % k, FARBY[k % len(FARBY)], 0.5)
        t.append(lathe('puszka', [(0.0, 0.0), (r, 0.0), (r, h), (r * 0.9, h + 0.006), (0.0, h + 0.006)], alu, 8, loc=(x, y, z)))
        t.append(lathe('puszka_e', [(r * 1.02, h * 0.12), (r * 1.02, h * 0.88)], c, 8, loc=(x, y, z)))

    def kolba(x, y, z, s=1.0):
        g = mat('szklo', 'a9d3d6', 0.08, 0.1)
        t.append(lathe('kolba', [(0.0, 0.0), (0.055 * s, 0.0), (0.06 * s, 0.01 * s), (0.02 * s, 0.11 * s), (0.02 * s, 0.16 * s), (0.026 * s, 0.165 * s)], g, 10, loc=(x, y, z)))
        t.append(lathe('plyn', [(0.0, 0.002), (0.05 * s, 0.002), (0.04 * s, 0.045 * s), (0.0, 0.045 * s)], mat('plyn%d' % int(x * 100 % 3), ['2d7fb8', '3d9a57', 'c9a227'][int(abs(x) * 100) % 3], 0.2), 10, loc=(x, y, z)))

    def zlewka(x, y, z, r=0.04, h=0.1):
        g = mat('szklo', 'a9d3d6', 0.08, 0.1)
        t.append(lathe('zlewka', [(0.0, 0.0), (r, 0.0), (r, h), (r * 1.08, h + 0.004), (r * 0.94, h), (r * 0.94, 0.004), (0.0, 0.004)], g, 10, loc=(x, y, z)))

    # parapet: wiadra farby, kanistry, zwój kabla, rolka siatki, worek
    zp = zo + 0.05
    for i in range(4):
        wiadro(xl0 + 0.24 + i * 0.3, yg - 0.04 + 0.05 * (i % 2), zp, i)
    wiadro(xl0 + 0.39, yg, zp + 0.262, 5)
    for i in range(2):
        x = xl0 + 1.62 + i * 0.27
        kan = mat('kanister%d' % i, ['2f5d3a', '8e2a22'][i], 0.5)
        t.append(rbox('kanister', (0.22, 0.14, 0.32), kan, 0.03, (x, yg, zp + 0.16)))
        t.append(rbox('kanister_uchwyt', (0.12, 0.035, 0.04), kan, 0.012, (x, yg, zp + 0.345)))
        t.append(lathe('korek', [(0.0, 0.0), (0.022, 0.0), (0.022, 0.03), (0.0, 0.03)], tusz, 8, loc=(x + 0.08, yg, zp + 0.32)))
    xk = xl1 - 0.5
    kab = mat('kabel', 'd9621c', 0.6)
    for i in range(5):
        pts = [(xk + math.cos(a) * 0.15, yg - 0.14 + i * 0.022, zp + 0.17 + math.sin(a) * 0.15) for a in [j * math.tau / 14 for j in range(15)]]
        t.append(tube('zwoj', pts, 0.012, kab, 5))
    t.append(lathe('siatka', [(0.0, 0.0), (0.1, 0.0), (0.1, 0.34), (0.085, 0.34), (0.085, 0.01), (0.0, 0.01)], mat('siatka', '8a9296', 0.5, 0.7), 14, loc=(xl1 - 0.14, yg + 0.06, zp)))
    # półka 1: puszki farb w dwóch rzędach, pędzle w słoiku
    z1 = polki[0] + 0.0125
    for i in range(11):
        puszka(xl0 + 0.16 + i * 0.125, yg - 0.1, z1, i)
    for i in range(10):
        puszka(xl0 + 0.22 + i * 0.125, yg + 0.04, z1, i + 3)
    for i in range(4):
        puszka(xl0 + 0.2 + i * 0.25, yg - 0.1, z1 + 0.127, i + 5)
    xp = xl1 - 0.3
    t.append(lathe('sloik', [(0.0, 0.0), (0.045, 0.0), (0.045, 0.11), (0.0, 0.11)], alu, 10, loc=(xp, yg - 0.08, z1)))
    for i in range(4):
        a = i * 1.7
        t.append(tube('pedzel', [(xp + math.cos(a) * 0.02, yg - 0.08 + math.sin(a) * 0.02, z1 + 0.05), (xp + math.cos(a) * 0.05, yg - 0.08 + math.sin(a) * 0.05, z1 + 0.27)], 0.007, drew, 5))
        t.append(rbox('wlosie', (0.035, 0.012, 0.05), tusz, 0.003, (xp + math.cos(a) * 0.055, yg - 0.08 + math.sin(a) * 0.055, z1 + 0.295)))
    # półka 2: kartony z lampami LED (fioletowa naklejka), pudełka z wkrętami
    z2 = polki[1] + 0.0125
    fiol = mat('naklejka', '7d3fb0', 0.5)
    for i in range(3):
        x = xl0 + 0.3 + i * 0.5
        t.append(rbox('karton_led', (0.44, 0.26, 0.2), karton, 0.006, (x, yg, z2 + 0.1)))
        t.append(rbox('naklejka', (0.3, 0.006, 0.12), fiol, 0.002, (x, yg - 0.132, z2 + 0.1)))
        napisy.append(text('led%d' % i, 'LED 600W', 0.05, bialy, (x, yg - 0.137, z2 + 0.115)))
        napisy.append(text('led_b%d' % i, 'GROW PANEL', 0.026, bialy, (x, yg - 0.137, z2 + 0.065)))
    t.append(rbox('karton_led_g', (0.44, 0.26, 0.2), karton, 0.006, (xl0 + 0.52, yg + 0.01, z2 + 0.305), (0, 0, 0.12)))
    for i in range(5):
        c = mat('pud%d' % (i % 3), ['2f4f7a', 'a8322a', '3d6b46'][i % 3], 0.6)
        t.append(rbox('pudelko', (0.14, 0.2, 0.09), c, 0.004, (xl1 - 0.78 + i * 0.155, yg - 0.03, z2 + 0.045)))
        t.append(rbox('pudelko_e', (0.1, 0.004, 0.05), bialy, 0.001, (xl1 - 0.78 + i * 0.155, yg - 0.132, z2 + 0.045)))
    for i in range(3):
        t.append(rbox('pudelko2', (0.14, 0.2, 0.09), mat('pud%d' % ((i + 1) % 3), '2f4f7a', 0.6), 0.004, (xl1 - 0.7 + i * 0.155, yg - 0.03, z2 + 0.137)))
    # półka 3: szkło laboratoryjne i skrzynka „FRAGILE”
    z3 = polki[2] + 0.0125
    for i in range(5):
        kolba(xl0 + 0.2 + i * 0.17, yg - 0.07 + 0.05 * (i % 2), z3, 1.0 + 0.25 * (i % 3 == 0))
    for i in range(6):
        zlewka(xl0 + 1.12 + i * 0.105, yg - 0.1, z3, 0.036 + 0.006 * (i % 2), 0.085 + 0.02 * (i % 3))
    for i in range(4):
        t.append(lathe('cylinder_m', [(0.0, 0.0), (0.035, 0.0), (0.035, 0.008), (0.016, 0.012), (0.016, 0.24), (0.02, 0.245)], mat('szklo', 'a9d3d6', 0.08, 0.1), 10, loc=(xl0 + 1.2 + i * 0.13, yg + 0.06, z3)))
    t.append(rbox('skrzynka_szklo', (0.5, 0.3, 0.24), drew, 0.006, (xl1 - 0.36, yg, z3 + 0.12)))
    for dz in (0.05, 0.19):
        t.append(rbox('skrzynka_listwa', (0.52, 0.012, 0.035), mat('drewno_c', '6a5236', 0.9, wzor='drewno'), 0.003, (xl1 - 0.36, yg - 0.153, z3 + dz)))
    napisy.append(text('fragile', 'LAB GLASS', 0.055, mat('czerwony', 'a8261c', 0.6), (xl1 - 0.36, yg - 0.153, z3 + 0.135)))
    napisy.append(text('fragile2', 'FRAGILE', 0.03, mat('czerwony', 'a8261c', 0.6), (xl1 - 0.36, yg - 0.153, z3 + 0.09)))
    # okienko: dzwonek, miarka, kwitariusz na szpikulcu, cennik na ścianie w głębi, kalendarz
    zl = 1.03
    t.append(lathe('dzwonek', [(0.0, 0.0), (0.05, 0.0), (0.05, 0.008), (0.042, 0.012), (0.036, 0.035), (0.02, 0.05), (0.006, 0.054), (0.006, 0.064), (0.0, 0.064)], mat('mosiadz', 'b8963e', 0.3, 0.9), 14, loc=(xo - 0.3, -0.3, zl)))
    t.append(rbox('miarka', (0.07, 0.03, 0.07), zolty, 0.012, (xo + 0.1, -0.34, zl + 0.035)))
    t.append(rbox('miarka_tasma', (0.16, 0.018, 0.003), bialy, 0.0, (xo + 0.21, -0.34, zl + 0.008), segs=1))
    t.append(lathe('szpikulec', [(0.0, 0.0), (0.035, 0.0), (0.035, 0.008), (0.003, 0.012), (0.002, 0.14), (0.0, 0.142)], st, 8, loc=(xo + 0.42, -0.2, zl)))
    for i in range(4):
        t.append(rbox('kwit', (0.09, 0.07, 0.002), bialy, 0.0, (xo + 0.42, -0.2, zl + 0.02 + i * 0.012), (0, 0, i * 0.5), segs=1))
    t.append(rbox('cennik', (0.62, 0.012, 0.8), bialy, 0.004, (xo - 0.12, yb - 0.045, 1.54)))
    t.append(rbox('cennik_listwa', (0.66, 0.02, 0.05), stc, 0.004, (xo - 0.12, yb - 0.05, 1.95)))
    napisy.append(text('c0', 'PRICE LIST', 0.06, mat('czerwony', 'a8261c', 0.6), (xo - 0.12, yb - 0.053, 1.85)))
    for i, (a, b) in enumerate([('SHELVING', '340'), ('WORKBENCH', '480'), ('CRATE', '120'), ('LED PANEL', '650'), ('DRY RACK', '260'), ('CARBON FILTER', '700'), ('LAB TABLE', '3600')]):
        napisy.append(text('c%da' % i, a, 0.034, tusz, (xo - 0.4, yb - 0.053, 1.75 - i * 0.075), align='LEFT'))
        napisy.append(text('c%db' % i, b, 0.034, tusz, (xo + 0.16, yb - 0.053, 1.75 - i * 0.075), align='RIGHT'))
    napisy.append(text('c9', 'CASH ONLY', 0.036, mat('czerwony', 'a8261c', 0.6), (xo - 0.12, yb - 0.053, 1.19)))
    t.append(rbox('kalendarz', (0.24, 0.01, 0.34), bialy, 0.003, (xo + 0.42, yb - 0.045, 1.72)))
    t.append(rbox('kalendarz_g', (0.24, 0.012, 0.13), mat('kal', '2e6da4', 0.6), 0.003, (xo + 0.42, yb - 0.047, 1.825)))
    for r in range(3):
        for c in range(5):
            t.append(rbox('dzien', (0.022, 0.004, 0.022), mat('szary_j', 'c9c9c4', 0.7), 0.0, (xo + 0.33 + c * 0.036, yb - 0.052, 1.72 - r * 0.036), segs=1))
    # tabliczka nad ladą i naklejka na cokole
    t.append(rbox('tabl', (0.62, 0.012, 0.16), zolty, 0.004, (xo, yf - 0.045, H - 0.17)))
    napisy.append(text('tabl_t', 'ORDERS & PICKUP', 0.055, tusz, (xo, yf - 0.053, H - 0.17)))
    t.append(rbox('nakl', (0.7, 0.008, 0.2), bialy, 0.004, (xc, yf - 0.004, 0.26)))
    napisy.append(text('nakl_t', 'WE DELIVER', 0.085, mat('czerwony', 'a8261c', 0.6), (xc, yf - 0.01, 0.285)))
    napisy.append(text('nakl_t2', 'SAME DAY  •  NO QUESTIONS', 0.03, tusz, (xc, yf - 0.01, 0.2)))
    tow = join('Towar', t)
    nap = join('Napisy', napisy)
    # --- światło: świetlówka pod skrzynką rolety i lampka OPEN w okienku (osobno, bez brudu)
    sw = [rbox('swietlowka', (xl1 - xl0 - 0.3, 0.035, 0.03), mat('swiatlo', 'fff1d0', 0.4, 0.0, 3.2), 0.008, (xc, -0.08, zt - 0.35)),
          rbox('swietlowka2', (wo - 0.3, 0.035, 0.03), mat('swiatlo', 'fff1d0', 0.4, 0.0, 3.2), 0.008, (xo, 0.0, zt - 0.35))]
    join('SwiatloWitryna', sw)
    op = [rbox('open_tlo', (0.36, 0.02, 0.15), tusz, 0.006, (xo + 0.4, yb - 0.06, 1.36))]
    join('OpenRamka', op)
    join('SwiatloOpen', [text('open_t', 'OPEN', 0.085, mat('neon', '5dff8a', 0.4, 0.0, 4.0), (xo + 0.4, yb - 0.075, 1.36), depth=0.003)])
    weather([wit], 2048, 0.6, 0.55, (0.11, 0.095, 0.08))
    weather([tow], 2048, 0.3, 0.25, (0.11, 0.095, 0.08))
    export('hurtownia_witryna')


witryna()
