"""Zamknięcia granic mapy: portal kolejowy pod wiaduktem drogowym (tor wchodzi w ciemny przepust, przed nim zamknięta
brama z prętów i semafor na „stój”) oraz główna brama huty: ceglane słupy, przesuwna brama z blachy, portiernia i szlaban.
Przód = −Y. Portal: z = 0 to wierzch podsypki (główka szyny 19 cm wyżej). Brama huty: z = 0 to jezdnia."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
from lib import _finish

R90 = math.radians(90)
rnd = random.Random(31)


def _disc(name, r, material, loc, h=0.02):
    d = lathe(name, [(0.0, 0.0), (r, 0.0), (r, h), (0.0, h)], material, 22, loc=loc)
    d.rotation_euler = (R90, 0, 0)
    return d


def _stripes(name, a, b, n, r, m1, m2):
    """biało-czerwona rura z odcinków (ramię szlabanu)"""
    out = []
    for i in range(n):
        p0 = tuple(a[k] + (b[k] - a[k]) * i / n for k in range(3))
        p1 = tuple(a[k] + (b[k] - a[k]) * (i + 1) / n for k in range(3))
        out.append(tube('%s%d' % (name, i), [p0, p1], r, m1 if i % 2 == 0 else m2, 8))
    return out


def portal_kolejowy():
    """przepust pod wiaduktem drogowym: betonowa ściana 14,6 m z łukowym otworem 5,2 × 5,9 m, schodząca 6,4 m pod tor
    (zasłania skarpę nasypu), gzyms i balustrada drogi na górze, w głąb 14 m ciemnej rury z torem, zamknięta brama z prętów"""
    reset()
    con = mat('beton', 'a5a197', 0.92, wzor='beton')
    dark = mat('wnetrze', '171615', 0.98)
    st = mat('stal', '4a4e54', 0.5, 0.7)
    rust = mat('rdza', '5a3f30', 0.8, 0.4)
    W_, H_, D_ = 14.6, 7.2, 6.4
    ow, oh, rr = 5.2, 5.9, 2.0
    hole = [(-ow / 2, -0.25), (ow / 2, -0.25), (ow / 2, oh - rr)]
    for i in range(1, 9):
        a = i * (math.pi / 2) / 9
        hole.append((ow / 2 - rr + math.cos(a) * rr, oh - rr + math.sin(a) * rr))
    for i in range(0, 9):
        a = math.pi / 2 + i * (math.pi / 2) / 9
        hole.append((-ow / 2 + rr + math.cos(a) * rr, oh - rr + math.sin(a) * rr))
    hole.append((-ow / 2, oh - rr))
    p = [profile('sciana', [(-W_ / 2, -D_), (W_ / 2, -D_), (W_ / 2, H_), (-W_ / 2, H_)], 1.2, con, 0.04, holes=(hole,))]
    p.append(rbox('gzyms', (W_ + 0.5, 1.5, 0.3), con, 0.05, (0, 0, H_ + 0.15)))
    for sx in (-1, 1):
        p.append(rbox('pilaster', (1.0, 1.5, H_ + D_), con, 0.05, (sx * (W_ / 2 - 0.5), -0.02, (H_ - D_) / 2)))
        # przypory po bokach otworu
        p.append(rbox('przypora', (0.7, 0.5, oh + 0.6), con, 0.05, (sx * (ow / 2 + 0.75), -0.72, (oh + 0.6) / 2 - 0.3)))
    p.append(tube('obramienie', [(x, -0.64, z) for (x, z) in hole[1:]], 0.15, con, 6))
    p.append(rbox('zwornik', (0.7, 0.3, 0.9), con, 0.04, (0, -0.66, oh + 0.3)))
    # wnętrze: rura ciemniejąca w głąb, podsypka, tor i podkłady
    L = 14.0
    p.append(rbox('strop', (ow + 0.4, L, 0.3), dark, 0.0, (0, 0.6 + L / 2, oh + 0.15), segs=1))
    for sx in (-1, 1):
        p.append(rbox('bok', (0.3, L, oh + 0.6), dark, 0.0, (sx * (ow / 2 + 0.15), 0.6 + L / 2, oh / 2 - 0.3), segs=1))
    p.append(rbox('koniec', (ow + 0.4, 0.3, oh + 0.6), mat('czern', '040404', 1.0), 0.0, (0, 0.6 + L, oh / 2 - 0.3), segs=1))
    p.append(rbox('podsypka', (ow, L + 1.6, 0.3), mat('tluczen', '4d473f', 0.97), 0.0, (0, L / 2 - 0.2, -0.15), segs=1))
    wood = mat('podklad', '2f2620', 0.95, wzor='drewno')
    for k in range(14):
        p.append(rbox('podklad%d' % k, (2.5, 0.24, 0.14), wood, 0.01, (0, -0.7 + k * 0.62, 0.02)))
    for sx in (-1, 1):
        p.append(rbox('szyna', (0.07, L + 1.5, 0.14), st, 0.01, (sx * 0.784, L / 2 - 0.15, 0.12)))
    ob = join('Portal', p)
    # balustrada drogi na wiadukcie
    b = []
    zb = H_ + 0.3
    for i in range(9):
        x = -W_ / 2 + 0.5 + i * (W_ - 1.0) / 8
        b.append(tube('slupek%d' % i, [(x, -0.45, zb), (x, -0.45, zb + 1.1)], 0.035, st, 6))
    for z in (zb + 0.55, zb + 1.1):
        b.append(tube('porecz', [(-W_ / 2 + 0.5, -0.45, z), (W_ / 2 - 0.5, -0.45, z)], 0.03, st, 6))
    # brama z prętów: dwa skrzydła spięte łańcuchem, słupki przy ościeżach
    yg = -1.0
    for sx in (-1, 1):
        b.append(rbox('slup_b', (0.14, 0.14, 2.95), st, 0.01, (sx * (ow / 2 + 0.05), yg, 1.47)))
        b.append(rbox('kotwa', (0.3, 0.3, 0.08), st, 0.01, (sx * (ow / 2 + 0.05), yg + 0.18, 2.4)))
        x0, x1 = sx * 0.03, sx * (ow / 2 - 0.05)
        for (a, c) in (((x0, yg, 0.26), (x1, yg, 0.26)), ((x0, yg, 2.62), (x1, yg, 2.62)), ((x0, yg, 1.45), (x1, yg, 1.45)), ((x0, yg, 0.26), (x0, yg, 2.62)), ((x1, yg, 0.26), (x1, yg, 2.62)),
                       ((x0, yg, 0.26), (x1, yg, 2.62))):
            b.append(tube('rama', [a, c], 0.028, st, 6))
        for i in range(1, 20):
            x = x0 + (x1 - x0) * i / 20
            b.append(tube('pret', [(x, yg, 0.26), (x, yg, 2.8)], 0.011, st, 5, taper=0.004))
    b.append(rbox('klodka', (0.09, 0.04, 0.11), rust, 0.01, (0.0, yg - 0.05, 1.33)))
    b.append(tube('lancuch', [(-0.1, yg - 0.03, 1.5), (0.0, yg - 0.06, 1.38), (0.1, yg - 0.03, 1.5), (0.0, yg + 0.04, 1.56), (-0.1, yg - 0.03, 1.5)], 0.012, rust, 5))
    # semafor świetlny na wsporniku przy ościeżu: komora z trzema soczewkami, pali się czerwona
    blk = mat('czarny', '15161a', 0.6)
    b.append(tube('wspornik', [(-3.75, -0.6, 4.3), (-3.75, -1.25, 4.3)], 0.045, st, 6))
    b.append(tube('zastrzal', [(-3.75, -0.6, 3.7), (-3.75, -1.2, 4.25)], 0.03, st, 6))
    b.append(rbox('komora', (0.38, 0.2, 1.05), blk, 0.03, (-3.75, -1.3, 4.3)))
    b.append(rbox('tarcza', (0.62, 0.02, 1.3), blk, 0.01, (-3.75, -1.2, 4.3)))
    for k, z in enumerate((4.62, 4.3)):
        b.append(_disc('soczewka%d' % k, 0.1, mat('szklo_c', '1c2420', 0.3), (-3.75, -1.41, z), 0.02))
        b.append(rbox('daszek%d' % k, (0.26, 0.16, 0.02), blk, 0.005, (-3.75, -1.46, z + 0.13)))
    b.append(rbox('daszek_r', (0.26, 0.16, 0.02), blk, 0.005, (-3.75, -1.46, 3.98 + 0.13)))
    # skrzynka przekaźnikowa i rura z kablem
    b.append(rbox('skrzynka', (0.55, 0.3, 0.8), mat('szary', '7d8286', 0.6, 0.4), 0.02, (3.7, -0.8, 1.7)))
    b.append(tube('rura', [(3.7, -0.68, 2.1), (3.7, -0.68, 5.2)], 0.03, st, 6))
    ob2 = join('Brama', b)
    # tablice na bramie
    t = [_disc('zakaz', 0.3, mat('czerwony', 'c0281e', 0.5), (-1.3, yg - 0.03, 1.85)),
         rbox('belka', (0.42, 0.012, 0.1), mat('bialy', 'ecece6', 0.5), 0.0, (-1.3, yg - 0.058, 1.85), segs=1),
         rbox('tablica', (1.5, 0.02, 0.62), mat('bialy', 'ecece6', 0.5), 0.01, (1.3, yg - 0.03, 1.85)),
         text('t1', 'LINE CLOSED', 0.17, mat('tusz', '15161a', 0.6), (1.3, yg - 0.045, 1.98)),
         text('t2', 'RAILWAY PROPERTY', 0.085, mat('czerwony', 'c0281e', 0.5), (1.3, yg - 0.045, 1.78)),
         text('t3', 'NO TRESPASSING', 0.085, mat('czerwony', 'c0281e', 0.5), (1.3, yg - 0.045, 1.65)),
         rbox('rok_t', (1.3, 0.03, 0.5), con, 0.01, (0, -0.8, oh + 0.95)),
         text('rok', '1974', 0.36, mat('tusz', '15161a', 0.6), (0, -0.82, oh + 0.95))]
    ob3 = join('Tablice', t)
    weather([ob], 2048, 0.6, 0.6, (0.09, 0.08, 0.07))
    weather([ob2], 1024, 0.6, 0.7, (0.2, 0.1, 0.05))
    weather([ob3], 512, 0.45, 0.5)
    # czerwone światło semafora — osobno, żeby świeciło tylko ono
    lamp = _disc('Swiatlo', 0.1, mat('swiatlo_r', 'ff2a18', 0.3, 0.0, 4.0), (-3.75, -1.41, 3.98), 0.025)
    export('portal_kolejowy')


def brama_huty():
    """brama główna huty w murze granicznym (14,6 m): ceglane słupy z kratownicą i napisem, przesuwna brama z blachy
    trapezowej z kolcami, mur z drutem kolczastym, portiernia z okienkiem i szlaban. Środek jezdni: x = −2,24 m."""
    reset()
    brick = mat('cegla', '8f4c3a', 0.92, wzor='cegla')
    con = mat('beton', '9a968c', 0.92, wzor='beton')
    st = mat('stal', '4a4e54', 0.5, 0.7)
    paint = mat('farba', '4a6670', 0.6, 0.3)
    rust = mat('rdza', '5a3f30', 0.8, 0.4)
    white = mat('bialy', 'ecece6', 0.5)
    red = mat('czerwony', 'c0281e', 0.5)
    ink = mat('tusz', '15161a', 0.6)
    RC, GW, HW = -2.24, 6.2, 4.4
    xl, xr = RC - GW / 2 - 0.45, RC + GW / 2 + 0.45        # środki słupów
    # --- mur i słupy
    m = []
    for (x0, x1) in ((-7.28, xl - 0.45), (xr + 0.45, 7.28)):
        w = x1 - x0
        cx = (x0 + x1) / 2
        m.append(rbox('mur', (w, 0.5, HW), brick, 0.005, (cx, 0, HW / 2)))
        m.append(rbox('cokol', (w, 0.6, 0.5), con, 0.02, (cx, 0, 0.25)))
        m.append(rbox('czapa', (w + 0.06, 0.62, 0.1), con, 0.02, (cx, 0, HW + 0.05)))
    for cx in (xl, xr):
        m.append(rbox('slup', (0.9, 0.9, 5.9), brick, 0.005, (cx, 0, 2.95)))
        m.append(rbox('slup_cokol', (1.02, 1.02, 0.55), con, 0.02, (cx, 0, 0.275)))
        m.append(rbox('slup_czapa', (1.1, 1.1, 0.18), con, 0.03, (cx, 0, 5.99)))
        m.append(rbox('slup_czapa2', (0.7, 0.7, 0.14), con, 0.03, (cx, 0, 6.14)))
    for sx in (-1, 1):
        m.append(rbox('pilaster', (0.5, 0.64, HW + 0.4), con, 0.03, (sx * 7.28, 0, (HW + 0.4) / 2)))
        # odboje przy słupach, żeby ciężarówki nie obijały cegieł
        cxo = (xl + 0.62) if sx < 0 else (xr - 0.62)
        m.append(lathe('odboj', [(0.0, 0.0), (0.2, 0.0), (0.17, 0.3), (0.08, 0.5), (0.0, 0.52)], con, 14, loc=(cxo, -0.5, 0.0)))
    m.append(rbox('prog', (GW + 0.2, 1.3, 0.05), con, 0.01, (RC, -0.25, 0.0)))
    mur = join('Mur', m)
    # --- brama przesuwna, kratownica z napisem, drut kolczasty
    g = []
    yg = -0.56
    g.append(sheet('blacha', GW + 0.3, 2.7, 132, 1, lambda u, v: (0.0, -0.018 * max(-1.0, min(1.0, 2.2 * math.sin(u * 33.0 * 2.0 * math.pi))), 0.0), paint, loc=(RC, yg, 0.22)))
    for z in (0.2, 1.55, 2.92):
        g.append(rbox('belka', (GW + 0.4, 0.07, 0.09), paint, 0.008, (RC, yg - 0.04, z)))
    for i in range(5):
        x = RC - (GW + 0.4) / 2 + 0.04 + i * (GW + 0.32) / 4
        g.append(rbox('stojak', (0.08, 0.07, 2.8), paint, 0.008, (x, yg - 0.04, 1.56)))
    for i in range(34):
        x = RC - GW / 2 - 0.1 + i * (GW + 0.2) / 33
        g.append(tube('kolec%d' % i, [(x, yg - 0.04, 2.95), (x, yg - 0.04, 3.2)], 0.013, st, 5, taper=0.002))
    for sx in (-1, 1):
        w = lathe('rolka', [(0.0, -0.03), (0.09, -0.03), (0.09, 0.03), (0.0, 0.03)], st, 14, loc=(RC + sx * 2.4, yg - 0.04, 0.1))
        w.rotation_euler = (R90, 0, 0)
        g.append(w)
    g.append(rbox('szyna', (GW + 2.2, 0.05, 0.03), st, 0.004, (RC + 0.9, yg - 0.04, 0.02)))
    g.append(rbox('zamek', (0.16, 0.06, 0.24), st, 0.01, (RC + GW / 2 - 0.05, yg - 0.08, 1.25)))
    g.append(tube('uchwyt', [(RC + GW / 2 - 0.5, yg - 0.07, 1.1), (RC + GW / 2 - 0.5, yg - 0.14, 1.2), (RC + GW / 2 - 0.5, yg - 0.14, 1.4), (RC + GW / 2 - 0.5, yg - 0.07, 1.5)], 0.014, st, 6))
    g.append(tube('lancuch', [(RC + GW / 2 + 0.1, yg - 0.1, 1.45), (RC + GW / 2 + 0.3, yg - 0.02, 1.3), (RC + GW / 2 + 0.52, -0.47, 1.42)], 0.013, rust, 5))
    g.append(rbox('klodka', (0.08, 0.04, 0.1), rust, 0.01, (RC + GW / 2 + 0.3, yg - 0.05, 1.2)))
    # kratownica nad wjazdem
    ya = -0.2
    xa, xb = xl + 0.45, xr - 0.45
    for z in (4.95, 5.75):
        g.append(tube('pas', [(xa, ya, z), (xb, ya, z)], 0.05, st, 8))
    nb = 8
    for i in range(nb + 1):
        x = xa + (xb - xa) * i / nb
        g.append(tube('slupek_k', [(x, ya, 4.95), (x, ya, 5.75)], 0.028, st, 6))
        if i < nb:
            x2 = xa + (xb - xa) * (i + 1) / nb
            g.append(tube('krzyzulec', [(x, ya, 4.95 if i % 2 == 0 else 5.75), (x2, ya, 5.75 if i % 2 == 0 else 4.95)], 0.02, st, 6))
    g.append(rbox('tlo', (GW - 0.3, 0.03, 0.72), mat('tlo', '26323a', 0.7, 0.2), 0.01, (RC, ya - 0.07, 5.35)))
    # drut kolczasty na wysięgnikach
    for (x0, x1, n) in ((-7.1, xl - 0.5, 2), (xr + 0.5, 7.1, 6)):
        for i in range(n):
            x = x0 + (x1 - x0) * i / max(1, n - 1)
            g.append(tube('wysieg', [(x, 0.0, HW + 0.1), (x, -0.3, HW + 0.55)], 0.018, st, 5))
        for k in range(3):
            f = 0.3 + k * 0.33
            g.append(tube('drut', [(x0, -0.3 * f, HW + 0.1 + 0.45 * f), (x1, -0.3 * f, HW + 0.1 + 0.45 * f)], 0.006, st, 4))
    brama = join('Brama', g)
    # --- portiernia przy murze: tynk z lamperią, okienko od strony wjazdu, drzwi i zakratowane okno od frontu
    plaster = mat('tynk', 'b5ae9c', 0.95, wzor='beton')
    dado = mat('lamperia', '5f6656', 0.9, wzor='beton')
    glass = mat('szyba', '1a2226', 0.15, 0.3)
    green = mat('drzwi', '3c5446', 0.6, 0.2)
    x0, x1, y0, y1, hh = 2.2, 6.6, -3.0, -0.25, 2.9
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    h = [rbox('bryla', (x1 - x0, y1 - y0, hh), plaster, 0.01, (cx, cy, hh / 2)),
         rbox('lamperia', (x1 - x0 + 0.03, y1 - y0 + 0.03, 0.95), dado, 0.01, (cx, cy, 0.475)),
         rbox('dach', (x1 - x0 + 0.7, y1 - y0 + 0.5, 0.16), con, 0.02, (cx, cy - 0.2, hh + 0.08)),
         rbox('papa', (x1 - x0 + 0.56, y1 - y0 + 0.36, 0.04), mat('papa', '25262a', 0.95), 0.01, (cx, cy - 0.2, hh + 0.18))]
    # front: drzwi po prawej, okno z kratą po lewej
    h.append(rbox('oscieznica', (1.04, 0.08, 2.12), st, 0.01, (5.7, y0 - 0.01, 1.06)))
    h.append(rbox('drzwi', (0.92, 0.06, 2.04), green, 0.01, (5.7, y0 - 0.04, 1.04)))
    h.append(rbox('szybka', (0.36, 0.02, 0.5), glass, 0.005, (5.7, y0 - 0.075, 1.55)))
    h.append(tube('klamka', [(5.36, y0 - 0.08, 1.02), (5.36, y0 - 0.14, 1.02), (5.5, y0 - 0.14, 1.02)], 0.012, st, 6))
    h.append(rbox('stopien', (1.3, 0.55, 0.12), con, 0.02, (5.7, y0 - 0.27, 0.06)))
    h.append(rbox('rama_o', (1.66, 0.08, 1.16), white, 0.01, (3.55, y0 - 0.01, 1.75)))
    h.append(rbox('szyba_o', (1.5, 0.04, 1.0), glass, 0.005, (3.55, y0 - 0.04, 1.75)))
    h.append(rbox('szczeblina', (0.05, 0.05, 1.0), white, 0.005, (3.55, y0 - 0.05, 1.75)))
    h.append(rbox('parapet', (1.8, 0.16, 0.05), con, 0.01, (3.55, y0 - 0.07, 1.15)))
    for i in range(7):
        xk = 2.86 + i * 0.23
        h.append(tube('krata', [(xk, y0 - 0.1, 1.2), (xk, y0 - 0.1, 2.3)], 0.009, st, 5))
    for z in (1.4, 2.1):
        h.append(tube('krata_p', [(2.8, y0 - 0.1, z), (4.3, y0 - 0.1, z)], 0.009, st, 5))
    # bok od strony jezdni: okienko wartownika z półką
    h.append(rbox('rama_b', (0.08, 1.46, 1.06), white, 0.01, (x0 + 0.01, -1.7, 1.75)))
    h.append(rbox('szyba_b', (0.04, 1.3, 0.9), glass, 0.005, (x0 - 0.02, -1.7, 1.75)))
    h.append(rbox('szczeblina_b', (0.05, 0.05, 0.9), white, 0.005, (x0 - 0.03, -1.7, 1.75)))
    h.append(rbox('polka', (0.26, 0.9, 0.04), st, 0.01, (x0 - 0.1, -1.7, 1.26)))
    # rynna, kominek wentylacyjny, antena, oprawa lampy nad drzwiami
    h.append(tube('rynna', [(x1 - 0.1, y0 - 0.08, hh), (x1 - 0.1, y0 - 0.08, 0.25)], 0.045, st, 8))
    h.append(tube('kominek', [(3.2, -1.0, hh + 0.1), (3.2, -1.0, hh + 0.75)], 0.07, st, 8))
    h.append(rbox('daszek_k', (0.24, 0.24, 0.03), st, 0.005, (3.2, -1.0, hh + 0.8)))
    h.append(tube('antena', [(6.2, -0.6, hh + 0.1), (6.2, -0.6, hh + 1.9)], 0.012, st, 5))
    for k in range(3):
        h.append(tube('antena_p', [(5.95 + k * 0.03, -0.6, hh + 1.3 + k * 0.2), (6.45 - k * 0.03, -0.6, hh + 1.3 + k * 0.2)], 0.006, st, 4))
    h.append(rbox('oprawa', (0.3, 0.14, 0.16), st, 0.02, (5.7, y0 - 0.07, 2.42)))
    h.append(rbox('skrzynka_el', (0.4, 0.14, 0.55), mat('szary', '7d8286', 0.6, 0.4), 0.01, (6.35, y0 - 0.07, 1.5)))
    dom = join('Portiernia', h)
    # --- szlaban: słupek z napędem, biało-czerwone ramię z przeciwwagą, widełki po drugiej stronie jezdni
    yb = -4.3
    yel = mat('zolty', 'd9a514', 0.5, 0.2)
    s = [rbox('naped', (0.34, 0.34, 1.12), yel, 0.02, (1.45, yb, 0.56)),
         rbox('naped_cokol', (0.5, 0.5, 0.1), con, 0.02, (1.45, yb, 0.05)),
         rbox('pas_o', (0.345, 0.345, 0.14), ink, 0.02, (1.45, yb, 0.42)),
         rbox('przeciwwaga', (0.5, 0.16, 0.22), st, 0.02, (1.95, yb - 0.24, 0.98)),
         tube('widelki_s', [(RC - GW / 2 + 0.25, yb - 0.24, 0.0), (RC - GW / 2 + 0.25, yb - 0.24, 0.9)], 0.035, st, 6),
         tube('widelki', [(RC - GW / 2 + 0.25, yb - 0.33, 1.08), (RC - GW / 2 + 0.25, yb - 0.33, 0.9), (RC - GW / 2 + 0.25, yb - 0.15, 0.9), (RC - GW / 2 + 0.25, yb - 0.15, 1.08)], 0.016, st, 5)]
    s += _stripes('ramie', (1.7, yb - 0.24, 0.98), (RC - GW / 2 + 0.05, yb - 0.24, 0.98), 13, 0.045, white, red)
    s.append(_disc('stop', 0.26, red, (RC, yb - 0.3, 0.98)))
    s.append(rbox('stop_b', (0.36, 0.012, 0.085), white, 0.0, (RC, yb - 0.326, 0.98), segs=1))
    szl = join('Szlaban', s)
    # --- napisy i tablice
    t = [text('nazwa', 'HUTNIK STEELWORKS', 0.44, mat('litery', 'ddd6c2', 0.6, 0.3), (RC, ya - 0.1, 5.35), depth=0.02),
         _disc('zakaz', 0.36, red, (RC - 1.7, yg - 0.1, 2.05)),
         rbox('zakaz_b', (0.5, 0.012, 0.12), white, 0.0, (RC - 1.7, yg - 0.128, 2.05), segs=1),
         rbox('tablica', (1.7, 0.02, 0.86), white, 0.01, (RC + 1.2, yg - 0.1, 1.95)),
         text('t1', 'GATE 1', 0.24, ink, (RC + 1.2, yg - 0.115, 2.16)),
         text('t2', 'CLOSED', 0.2, red, (RC + 1.2, yg - 0.115, 1.9)),
         text('t3', 'DELIVERIES: GATE 3', 0.085, ink, (RC + 1.2, yg - 0.115, 1.66)),
         rbox('szyld', (0.7, 0.02, 0.24), mat('granat', '1d2c4a', 0.5), 0.01, (4.85, y0 - 0.02, 2.0)),
         text('szyld_t', 'SECURITY', 0.1, white, (4.85, y0 - 0.035, 2.0)),
         rbox('tabl_b', (0.02, 0.8, 0.3), white, 0.01, (x0 - 0.02, -1.7, 2.45)),
         text('tabl_bt', 'SHOW YOUR PASS', 0.075, ink, (x0 - 0.035, -1.7, 2.45), rot=(R90, 0, -R90))]
    tab = join('Tablice', t)
    weather([mur], 2048, 0.75, 0.6, (0.08, 0.07, 0.06))
    weather([brama], 2048, 0.7, 0.75, (0.22, 0.11, 0.05))
    weather([dom], 1024, 0.75, 0.6, (0.08, 0.07, 0.06))
    weather([szl], 512, 0.5, 0.6)
    weather([tab], 1024, 0.4, 0.5, (0.12, 0.09, 0.06))
    # lampa nad drzwiami portierni — osobno, żeby świeciła tylko ona
    rbox('Swiatlo', (0.22, 0.05, 0.1), mat('swiatlo', 'ffd9a0', 0.3, 0.0, 3.0), 0.02, (5.7, y0 - 0.15, 2.4))
    export('brama_huty')


only = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
for fn in (portal_kolejowy, brama_huty):
    if not only or fn.__name__ in only:
        fn()
