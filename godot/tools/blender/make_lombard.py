"""Witryna lombardu 2,9 × 2,5 m (przód = −Y, spód na z = 0, tył przy ścianie budynku na y = +0,25):
okno wystawowe za kratą z zastawionymi rzeczami (radiomagnetofon, telewizor, gitara, aparaty, zegarki, puchar),
drzwi z okratowaną szybą i tabliczką OPEN, deska z napisem nad drzwiami, stopień.
Napisy i świecące elementy są osobnymi obiektami bez wypalanego brudu."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *

R90 = math.radians(90)
rnd = random.Random(77)


def witryna():
    reset()
    W, H, D = 2.9, 2.5, 0.5
    yb, yf = D / 2, -D / 2
    st = mat('stal', '80868b', 0.45, 0.5)
    stc = mat('stal_c', '4b5056', 0.5, 0.4)
    mur = mat('cokol', wz('77726a', 'beton'), 0.9, wzor='beton')
    drew = mat('drewno', wz('8a6a42', 'drewno'), 0.8, wzor='drewno')
    drew_c = mat('drewno_c', wz('6e5038', 'drewno'), 0.8, wzor='drewno')
    tlo = mat('wnetrze', '3a2e26', 0.95)
    bialy = mat('bialy', 'ecebe4', 0.6)
    tusz = mat('tusz', '1b1c20', 0.6)
    zolty = mat('zolty', 'd9a514', 0.55, 0.2)
    zloto = mat('zloto', 'd9b24a', 0.32, 0.6)
    srebro = mat('srebro', 'c6cacd', 0.3, 0.6)
    zielony = mat('zielony', '2f4a3a', 0.7)
    zo = 0.48                      # wierzch cokołu pod oknem
    zt = H - 0.3                   # spód deski z napisem
    xd0, xd1 = 0.5, W / 2 - 0.12   # drzwi po prawej
    xw0, xw1 = -W / 2 + 0.12, xd0 - 0.14   # okno po lewej
    xc, ww = (xw0 + xw1) / 2, xw1 - xw0
    xo, wd = (xd0 + xd1) / 2, xd1 - xd0
    p = []
    # --- portal: cokół pod oknem, słupy, nadproże z deską
    p.append(rbox('cokol', (xw1 - xw0 + 0.24, D, zo), mur, 0.012, (xc, 0, zo / 2)))
    p.append(rbox('cokol_listwa', (xw1 - xw0 + 0.26, D + 0.03, 0.05), drew_c, 0.008, (xc, 0, zo - 0.02)))
    for x in (-W / 2 + 0.06, xd0 - 0.07, W / 2 - 0.06):
        p.append(rbox('slup', (0.12, D + 0.03, H), drew_c, 0.012, (x, 0, H / 2)))
    p.append(rbox('nadproze', (W, D + 0.06, 0.3), drew_c, 0.02, (0, -0.01, H - 0.15)))
    p.append(rbox('gzyms', (W + 0.08, D + 0.12, 0.04), drew, 0.01, (0, -0.02, H - 0.02)))
    p.append(rbox('tlo', (ww, 0.03, zt - zo), tlo, 0.0, (xc, yb - 0.02, (zt + zo) / 2), segs=1))
    p.append(rbox('sufit', (ww, D - 0.06, 0.02), tlo, 0.0, (xc, 0.02, zt - 0.01), segs=1))
    # --- wystawa: parapet i dwie półki na wspornikach
    polki = [1.02, 1.5]
    p.append(rbox('parapet', (ww, D - 0.02, 0.04), drew, 0.006, (xc, 0.0, zo + 0.02)))
    for z in polki:
        p.append(rbox('polka', (ww - 0.04, 0.3, 0.025), drew, 0.004, (xc, 0.07, z)))
        for x in (xw0 + 0.2, xc, xw1 - 0.2):
            p.append(tube('wspornik', [(x, yb - 0.03, z - 0.16), (x, 0.0, z - 0.012)], 0.008, stc, 5))
    # --- krata przed szybą: pionowe pręty i dwa płaskowniki
    yk = yf + 0.05
    n = 11
    for i in range(n + 1):
        x = xw0 + 0.03 + i * (ww - 0.06) / n
        p.append(tube('pret', [(x, yk, zo + 0.03), (x, yk, zt - 0.02)], 0.0075, stc, 6))
    for z in (zo + 0.42, zo + 1.2):
        p.append(rbox('plaskownik', (ww, 0.012, 0.04), stc, 0.003, (xc, yk - 0.008, z)))
    p.append(rbox('rama_d', (ww, 0.05, 0.05), stc, 0.006, (xc, yk, zo + 0.045)))
    p.append(rbox('rama_g', (ww, 0.05, 0.05), stc, 0.006, (xc, yk, zt - 0.03)))
    # --- drzwi: ościeżnica, skrzydło z okratowaną szybą, klamka, skrzynka na listy, stopień
    p.append(rbox('stopien', (wd + 0.3, 0.42, 0.14), mur, 0.012, (xo, yf - 0.1, 0.07)))
    zd0, zd1 = 0.14, zt
    yd = 0.08
    p.append(rbox('skrzydlo', (wd - 0.04, 0.05, zd1 - zd0 - 0.02), zielony, 0.008, (xo, yd, (zd0 + zd1) / 2)))
    p.append(rbox('plycina', (wd - 0.24, 0.02, 0.62), mat('zielony_c', '263c2f', 0.7), 0.01, (xo, yd - 0.03, zd0 + 0.42)))
    zg0, zg1 = zd0 + 0.92, zd1 - 0.16
    p.append(rbox('szyba_rama', (wd - 0.2, 0.03, zg1 - zg0 + 0.08), drew_c, 0.008, (xo, yd - 0.03, (zg0 + zg1) / 2)))
    for i in range(5):
        x = xo - (wd - 0.32) / 2 + i * (wd - 0.32) / 4
        p.append(tube('pret_d', [(x, yd - 0.055, zg0), (x, yd - 0.055, zg1)], 0.006, stc, 5))
    p.append(rbox('klamka_szyld', (0.05, 0.012, 0.2), srebro, 0.004, (xd0 + 0.14, yd - 0.032, zd0 + 0.9)))
    p.append(tube('klamka', [(xd0 + 0.14, yd - 0.04, zd0 + 0.94), (xd0 + 0.14, yd - 0.09, zd0 + 0.94), (xd0 + 0.27, yd - 0.09, zd0 + 0.94)], 0.011, srebro, 6))
    p.append(rbox('listy', (0.26, 0.012, 0.05), srebro, 0.004, (xo, yd - 0.032, zd0 + 0.78)))
    p.append(rbox('prog', (wd, 0.2, 0.03), stc, 0.004, (xo, yd - 0.08, zd0 + 0.015)))
    # metalowe części osobno: wypalana tekstura uśrednia metaliczność całego obiektu i drewniana rama wychodziła czarna
    def metal_part(o):
        return any(sl.material is not None and sl.material.node_tree.nodes['Principled BSDF'].inputs['Metallic'].default_value > 0.05 for sl in o.material_slots)
    metale = [o for o in p if metal_part(o)]
    wit = join('Witryna', [o for o in p if not metal_part(o)])

    # --- zastawione rzeczy
    t = []
    napisy = []
    yg = 0.06

    def cena(x, y, z, txt):
        t.append(rbox('cena', (0.085, 0.004, 0.05), bialy, 0.002, (x, y, z + 0.025), (math.radians(-12), 0, 0), segs=1))
        napisy.append(text('cena_t', txt, 0.026, mat('czerwony', 'a8261c', 0.6), (x, y - 0.004, z + 0.016), rot=(math.radians(78), 0, 0)))

    zp = zo + 0.04
    # parapet: radiomagnetofon, telewizor kineskopowy, gitara oparta o ścianę, wzmacniacz, skrzynka narzędziowa
    xr = xw0 + 0.34
    t.append(rbox('radio', (0.46, 0.13, 0.24), srebro, 0.02, (xr, yg, zp + 0.12)))
    for sx in (-1, 1):
        g = lathe('glosnik', [(0.0, 0.0), (0.085, 0.0), (0.085, 0.012), (0.06, 0.016), (0.0, 0.004)], tusz, 14)
        g.rotation_euler = (R90, 0, 0)
        g.location = (xr + sx * 0.14, yg - 0.066, zp + 0.11)
        t.append(g)
    t.append(rbox('kaseta', (0.12, 0.01, 0.07), tusz, 0.004, (xr, yg - 0.066, zp + 0.14)))
    t.append(tube('raczka', [(xr - 0.17, yg, zp + 0.24), (xr - 0.15, yg, zp + 0.3), (xr + 0.15, yg, zp + 0.3), (xr + 0.17, yg, zp + 0.24)], 0.009, stc, 5))
    cena(xr, yg - 0.16, zp, '120')
    xt = xw0 + 0.95
    t.append(rbox('tv', (0.42, 0.34, 0.36), mat('tv_obud', '4a4038', 0.6), 0.03, (xt, yg + 0.02, zp + 0.18)))
    t.append(rbox('tv_ramka', (0.34, 0.012, 0.27), tusz, 0.02, (xt - 0.02, yg - 0.153, zp + 0.19)))
    for i in range(2):
        k = lathe('pokretlo', [(0.0, 0.0), (0.014, 0.0), (0.012, 0.012), (0.0, 0.012)], srebro, 8)
        k.rotation_euler = (R90, 0, 0)
        k.location = (xt + 0.175, yg - 0.155, zp + 0.26 - i * 0.06)
        t.append(k)
    cena(xt - 0.1, yg - 0.2, zp, '90')
    # gitara: pudło z dwóch krążków, gryf, główka, struny
    xg = xw1 - 0.62
    wood = mat('gitara', 'b0752e', 0.4)
    for r, dz in ((0.17, 0.2), (0.13, 0.43)):
        b = lathe('pudlo', [(0.0, 0.0), (r, 0.0), (r * 1.03, 0.02), (r * 1.03, 0.07), (r, 0.09), (0.0, 0.09)], wood, 18)
        b.rotation_euler = (R90 - math.radians(8), 0, 0)
        b.location = (xg, yb - 0.1 + dz * 0.14, zp + dz)
        t.append(b)
    o = lathe('otwor', [(0.0, 0.0), (0.045, 0.0), (0.045, 0.004), (0.0, 0.004)], tusz, 12)
    o.rotation_euler = (R90 - math.radians(8), 0, 0)
    o.location = (xg, yb - 0.176 + 0.36 * 0.14, zp + 0.36)
    t.append(o)
    t.append(rbox('gryf', (0.05, 0.025, 0.62), drew_c, 0.006, (xg, yb - 0.072, zp + 0.86), (math.radians(-8), 0, 0)))
    t.append(rbox('glowka', (0.075, 0.022, 0.16), drew_c, 0.008, (xg, yb - 0.022, zp + 1.22), (math.radians(-8), 0, 0)))
    for i in range(6):
        sx = (i - 2.5) * 0.007
        t.append(tube('struna', [(xg + sx, yb - 0.2, zp + 0.3), (xg + sx, yb - 0.045, zp + 1.16)], 0.0009, srebro, 3))
    cena(xg - 0.25, yg - 0.16, zp, '250')
    xa = xw1 - 0.24
    t.append(rbox('wzmacniacz', (0.34, 0.2, 0.34), tusz, 0.015, (xa, yg, zp + 0.17)))
    t.append(rbox('maskownica', (0.29, 0.01, 0.22), mat('maskownica', wz('5a5148', 'tkanina'), 0.9, wzor='tkanina'), 0.006, (xa, yg - 0.102, zp + 0.14)))
    t.append(rbox('panel', (0.29, 0.012, 0.05), srebro, 0.004, (xa, yg - 0.102, zp + 0.3)))
    xn = xw0 + 1.42
    t.append(rbox('skrzynka', (0.3, 0.16, 0.14), mat('czerwony_l', '9c2f2a', 0.5), 0.012, (xn, yg - 0.03, zp + 0.07)))
    t.append(tube('uchwyt', [(xn - 0.07, yg - 0.03, zp + 0.14), (xn - 0.06, yg - 0.03, zp + 0.18), (xn + 0.06, yg - 0.03, zp + 0.18), (xn + 0.07, yg - 0.03, zp + 0.14)], 0.007, stc, 5))
    # półka 1: aparaty, lornetka, telefon, stos kaset wideo, lampka
    z1 = polki[0] + 0.0125
    for i in range(3):
        x = xw0 + 0.2 + i * 0.24
        t.append(rbox('aparat', (0.15, 0.07, 0.1), tusz if i != 1 else srebro, 0.01, (x, yg, z1 + 0.05)))
        ob = lathe('obiektyw', [(0.0, 0.0), (0.036, 0.0), (0.036, 0.05), (0.03, 0.055), (0.026, 0.045), (0.0, 0.045)], tusz, 12)
        ob.rotation_euler = (R90, 0, 0)
        ob.location = (x - 0.01, yg - 0.035, z1 + 0.045)
        t.append(ob)
        t.append(rbox('pryzmat', (0.05, 0.05, 0.025), tusz if i != 1 else srebro, 0.006, (x - 0.01, yg, z1 + 0.11)))
    cena(xw0 + 0.44, yg - 0.11, z1, '180')
    xs = xw0 + 1.05
    kol = ['27324a', '8a2a2a', '2f4a3a', '1b1c20', '6a3a5a', 'c9a23a']
    for i in range(7):
        t.append(rbox('kaseta_vhs', (0.19, 0.105, 0.027), mat('vhs%d' % (i % 6), kol[i % 6], 0.6), 0.003, (xs + rnd.uniform(-0.01, 0.01), yg, z1 + 0.014 + i * 0.027), (0, 0, rnd.uniform(-0.12, 0.12))))
    xl = xw0 + 1.42
    t.append(lathe('lampka_p', [(0.0, 0.0), (0.06, 0.0), (0.06, 0.012), (0.012, 0.02), (0.01, 0.2), (0.0, 0.2)], zloto, 12, loc=(xl, yg, z1)))
    t.append(lathe('klosz', [(0.035, 0.18), (0.085, 0.06 + 0.18 - 0.14), (0.088, 0.06 + 0.18 - 0.14), (0.04, 0.185)], mat('klosz', 'c9b890', 0.7), 14, loc=(xl, yg, z1 + 0.08)))
    xf = xw1 - 0.2
    t.append(rbox('telefon', (0.2, 0.16, 0.06), mat('bordo', '6a2228', 0.4), 0.02, (xf, yg, z1 + 0.03)))
    t.append(tube('sluchawka', [(xf - 0.08, yg, z1 + 0.075), (xf - 0.07, yg, z1 + 0.1), (xf + 0.07, yg, z1 + 0.1), (xf + 0.08, yg, z1 + 0.075)], 0.017, mat('bordo', '6a2228', 0.4), 6))
    # półka 2: zegarki na podstawkach, puchar, taca z biżuterią, budzik
    z2 = polki[1] + 0.0125
    for i in range(4):
        x = xw0 + 0.18 + i * 0.15
        t.append(rbox('podstawka', (0.07, 0.06, 0.07), mat('aksamit', '3a1f2a', 0.9), 0.008, (x, yg, z2 + 0.035), (math.radians(-18), 0, 0)))
        zg = lathe('zegarek', [(0.0, 0.0), (0.022, 0.0), (0.022, 0.008), (0.0, 0.008)], zloto if i % 2 == 0 else srebro, 12)
        zg.rotation_euler = (R90 - math.radians(18), 0, 0)
        zg.location = (x, yg - 0.034, z2 + 0.045)
        t.append(zg)
    cena(xw0 + 0.4, yg - 0.11, z2, '300')
    xp = xw0 + 0.98
    t.append(lathe('puchar', [(0.0, 0.0), (0.05, 0.0), (0.05, 0.012), (0.012, 0.03), (0.01, 0.1), (0.03, 0.12), (0.06, 0.2), (0.064, 0.26), (0.056, 0.26), (0.05, 0.2), (0.0, 0.13)], zloto, 14, loc=(xp, yg, z2)))
    for sx in (-1, 1):
        t.append(tube('ucho', [(xp + sx * 0.058, yg, z2 + 0.24), (xp + sx * 0.1, yg, z2 + 0.22), (xp + sx * 0.09, yg, z2 + 0.16), (xp + sx * 0.04, yg, z2 + 0.15)], 0.005, zloto, 5))
    xj = xw0 + 1.36
    t.append(rbox('taca', (0.26, 0.18, 0.02), mat('aksamit', '3a1f2a', 0.9), 0.006, (xj, yg - 0.01, z2 + 0.03), (math.radians(-20), 0, 0)))
    for i in range(3):
        for j in range(2):
            r = lathe('pierscien', [(0.008, 0.0), (0.011, 0.0), (0.011, 0.005), (0.008, 0.005)], zloto if (i + j) % 2 == 0 else srebro, 10)
            r.rotation_euler = (math.radians(-20), 0, 0)
            r.location = (xj - 0.08 + i * 0.08, yg - 0.045 + j * 0.07, z2 + 0.03 + j * 0.025)
            t.append(r)
    xb = xw1 - 0.2
    bz = lathe('budzik', [(0.0, 0.0), (0.06, 0.0), (0.064, 0.01), (0.064, 0.05), (0.06, 0.06), (0.0, 0.06)], srebro, 16)
    bz.rotation_euler = (R90, 0, 0)
    bz.location = (xb, yg + 0.03, z2 + 0.075)
    t.append(bz)
    tar = lathe('tarcza', [(0.0, 0.0), (0.052, 0.0), (0.052, 0.002), (0.0, 0.002)], bialy, 16)
    tar.rotation_euler = (R90, 0, 0)
    tar.location = (xb, yg - 0.002, z2 + 0.075)
    t.append(tar)
    for sx in (-1, 1):
        t.append(lathe('dzwonek', [(0.0, 0.0), (0.024, 0.0), (0.018, 0.016), (0.0, 0.02)], srebro, 10, loc=(xb + sx * 0.04, yg + 0.03, z2 + 0.13)))
    # deska nad drzwiami i oknem, naklejki na szybie drzwi, tabliczka z godzinami
    t.append(rbox('deska', (W - 0.3, 0.014, 0.2), zolty, 0.004, (0, yf - 0.045, H - 0.15)))
    napisy.append(text('deska_t', 'WE BUY ANYTHING', 0.105, tusz, (0, yf - 0.054, H - 0.185)))
    t.append(rbox('godziny', (0.3, 0.008, 0.2), bialy, 0.004, (xo + 0.08, yd - 0.065, zd0 + 1.22)))
    napisy.append(text('godz_1', 'OPEN 9–19', 0.05, tusz, (xo + 0.08, yd - 0.071, zd0 + 1.25)))
    napisy.append(text('godz_2', 'CASH FOR GOLD', 0.03, mat('czerwony', 'a8261c', 0.6), (xo + 0.08, yd - 0.071, zd0 + 1.17)))
    t.append(rbox('nakl', (0.9, 0.008, 0.16), bialy, 0.004, (xc, yf - 0.004, 0.25)))
    napisy.append(text('nakl_t', 'GOLD • WATCHES • ELECTRONICS', 0.044, tusz, (xc, yf - 0.01, 0.235)))
    metale += [o for o in t if metal_part(o)]
    tow = join('Towar', [o for o in t if not metal_part(o)])
    join('Metale', metale)
    join('Napisy', napisy)
    # --- szyby: okno wystawy i okienko w drzwiach (osobno, przezroczyste)
    szklo = mat('szklo', 'a9c6d6', 0.06, 0.1, 0.0, 0.16)
    join('Szyby', [rbox('szyba', (ww, 0.008, zt - zo - 0.06), szklo, 0.0, (xc, yf + 0.085, (zt + zo) / 2), segs=1),
                   rbox('szyba_d', (wd - 0.26, 0.006, zg1 - zg0), szklo, 0.0, (xo, yd - 0.035, (zg0 + zg1) / 2), segs=1)])
    # --- światło: ciepła świetlówka pod sufitem wystawy i neon OPEN w drzwiach (osobno, bez brudu)
    join('SwiatloWitryna', [rbox('swietlowka', (ww - 0.3, 0.035, 0.03), mat('swiatlo', 'ffd9a0', 0.4, 0.0, 3.0), 0.008, (xc, -0.05, zt - 0.045))])
    join('OpenRamka', [rbox('open_tlo', (0.3, 0.014, 0.12), tusz, 0.006, (xo - 0.02, yd - 0.062, zd0 + 1.5))])
    join('SwiatloOpen', [text('open_t', 'OPEN', 0.07, mat('neon', 'ff6a3a', 0.4, 0.0, 4.0), (xo - 0.02, yd - 0.072, zd0 + 1.475), depth=0.003)])
    weather([wit], 2048, 0.3, 0.45, (0.14, 0.12, 0.1))
    weather([tow], 2048, 0.3, 0.25, (0.11, 0.095, 0.08))
    export('lombard_witryna')


witryna()
