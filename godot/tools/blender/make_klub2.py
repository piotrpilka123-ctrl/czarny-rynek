"""Klub Neon — druga partia: loża VIP na podeście, girlanda kolorowych żarówek, neony ścienne (drink, piorun, serce, fale, palma), kinkiet LED.
Przód = −Y. Części „Swiatlo…” świecą własnym kolorem."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *

R90 = math.radians(90)
rnd = random.Random(31)
PINK, CYAN, VIOLET, GOLD, GREEN = 'ff3bd0', '3be8ff', '9a5cff', 'ffc23b', '5cff7a'


def glow(name, color, power=6.0):
    return mat('neon_' + name, color, 0.3, 0.0, power)


def neon(name, pts, color, r=0.012, closed=False):
    p = [(x, -0.045, z) for x, z in pts]
    if closed:
        p.append(p[0])
    return tube(name, p, r, glow(color, color), 6)


def backplate(w, h, parts):
    """przezroczysta płyta z dystansami — na niej wiszą rurki neonu"""
    parts.append(rbox('plyta', (w, 0.006, h), mat('pleksi', '1a1a22', 0.2, 0.2, 0.0, 0.35), 0.0, (0, -0.02, 0), segs=1))
    for sx in (-1, 1):
        for sz in (-1, 1):
            parts.append(lathe('dystans', [(0.0, 0.0), (0.012, 0.0), (0.012, 0.03), (0.0, 0.03)], mat('chrom', 'b9bcc2', 0.25, 0.9), 8, loc=(sx * (w / 2 - 0.05), 0.0, sz * (h / 2 - 0.05))))
            parts[-1].rotation_euler = (R90, 0, 0)
    parts.append(tube('kabel', [(w / 2 - 0.06, -0.01, -h / 2 + 0.06), (w / 2 + 0.02, -0.01, -h / 2 - 0.2), (w / 2 + 0.04, -0.005, -h / 2 - 0.6)], 0.005, mat('kabel', '0c0c0e', 0.8), 5))


def klub_neon_drink():
    reset()
    p = []
    backplate(0.9, 1.2, p)
    join('Plyta', p)
    g = [neon('kieliszek', [(-0.32, 0.42), (0.32, 0.42), (0.0, 0.02), (-0.32, 0.42)], PINK)]
    g.append(neon('nozka', [(0.0, 0.02), (0.0, -0.4)], PINK))
    g.append(neon('stopka', [(-0.2, -0.42), (0.2, -0.42)], PINK))
    join('SwiatloRoz', g)
    c = [neon('slomka', [(0.1, 0.2), (0.34, 0.56)], CYAN, 0.009)]
    c.append(neon('oliwka', [(-0.08 + 0.06 * math.cos(a), 0.28 + 0.06 * math.sin(a)) for a in [k * math.tau / 10 for k in range(11)]], GREEN, 0.009))
    c.append(neon('babelki', [(0.26 + 0.035 * math.cos(a), 0.0 + 0.035 * math.sin(a)) for a in [k * math.tau / 8 for k in range(9)]], CYAN, 0.007))
    join('SwiatloCyan', c)
    export('klub_neon_drink')


def klub_neon_piorun():
    reset()
    p = []
    backplate(0.8, 1.3, p)
    join('Plyta', p)
    neon('SwiatloZolty', [(0.12, 0.58), (-0.22, 0.02), (0.02, 0.02), (-0.14, -0.58), (0.26, 0.12), (0.0, 0.12), (0.12, 0.58)], GOLD, 0.013)
    j = [neon('okrag', [(0.36 * math.cos(a), 0.0 + 0.6 * math.sin(a)) for a in [k * math.tau / 28 for k in range(29)]], VIOLET, 0.009)]
    join('SwiatloFiolet', j)
    export('klub_neon_piorun')


def klub_neon_serce():
    reset()
    p = []
    backplate(1.0, 0.95, p)
    join('Plyta', p)
    pts = []
    for k in range(41):
        t = k / 40 * math.tau
        pts.append((0.026 * 16 * math.sin(t) ** 3, 0.026 * (13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)) + 0.04))
    neon('SwiatloRoz', pts, PINK, 0.013)
    neon('SwiatloCyan', [(x * 0.62, z * 0.62 + 0.02) for x, z in pts], CYAN, 0.008)
    export('klub_neon_serce')


def klub_neon_fale():
    """trzy faliste linie na 2,4 m — pas nad lożami"""
    reset()
    p = [rbox('listwa', (2.4, 0.02, 0.04), mat('listwa', '15151a', 0.6), 0.004, (0, -0.01, -0.3))]
    join('Listwa', p)
    for k, col in enumerate((PINK, VIOLET, CYAN)):
        neon('Swiatlo%d' % k, [(-1.15 + i * 0.05, 0.16 - k * 0.16 + 0.07 * math.sin(i * 0.42 + k * 1.1)) for i in range(47)], col, 0.011)
    export('klub_neon_fale')


def klub_neon_palma():
    reset()
    p = []
    backplate(1.1, 1.5, p)
    join('Plyta', p)
    g = []
    for k in range(6):
        a = math.radians(25 + k * 26)
        pts = [(math.cos(a) * r * 0.5, 0.22 + math.sin(a) * r * 0.42 - 0.5 * (r * 0.5) ** 2) for r in [j * 0.14 for j in range(8)]]
        g.append(neon('lisc%d' % k, pts, GREEN, 0.011))
    join('SwiatloZielen', g)
    neon('SwiatloZolty', [(0.0, 0.22), (0.03, -0.1), (-0.02, -0.4), (0.04, -0.68)], GOLD, 0.014)
    neon('SwiatloRoz', [(-0.4, -0.7), (-0.2, -0.66), (0.0, -0.7), (0.2, -0.66), (0.4, -0.7)], PINK, 0.01)
    export('klub_neon_palma')


def klub_kinkiet():
    """kinkiet ścienny: czarna obudowa z listwą LED świecącą w górę i w dół po ścianie"""
    reset()
    p = [rbox('obudowa', (0.14, 0.09, 0.42), mat('czarny', '121216', 0.5), 0.02, (0, -0.045, 0), segs=3)]
    p.append(rbox('zebra', (0.15, 0.02, 0.3), mat('czarny', '121216', 0.5), 0.004, (0, -0.092, 0)))
    ob = join('Kinkiet', p)
    weather([ob], 256, 0.3, 0.4)
    j = [rbox('gora', (0.1, 0.06, 0.012), mat('led', 'ffffff', 0.3, 0.0, 6.0), 0.0, (0, -0.045, 0.212), segs=1), rbox('dol', (0.1, 0.06, 0.012), mat('led', 'ffffff', 0.3, 0.0, 6.0), 0.0, (0, -0.045, -0.212), segs=1)]
    join('SwiatloLed', j)
    export('klub_kinkiet')


def klub_girlanda():
    """girlanda 6 m między kratownicami (zaczepy na końcach, zwis pośrodku): przewód, oprawki i kolorowe żarówki co 40 cm"""
    reset()
    L, sag = 6.0, 0.55
    n = 15
    def at(u):
        return ((u - 0.5) * L, 0.0, -sag * (1.0 - (2.0 * u - 1.0) ** 2))
    p = [tube('przewod', [at(k / 30) for k in range(31)], 0.008, mat('przewod', '0c0c0e', 0.8), 5)]
    for sx in (-1, 1):
        p.append(lathe('zaczep', [(0.0, 0.0), (0.02, 0.0), (0.02, 0.04), (0.0, 0.04)], mat('chrom', 'b9bcc2', 0.25, 0.9), 8, loc=(sx * L / 2, 0, 0.0)))
    cols = (PINK, CYAN, GOLD, VIOLET, GREEN)
    bulbs = {c: [] for c in cols}
    for k in range(n):
        x, y, z = at((k + 0.5) / n)
        p.append(lathe('oprawka', [(0.0, 0.0), (0.016, 0.0), (0.018, -0.05), (0.0, -0.05)], mat('oprawka', '15151a', 0.6), 8, loc=(x, y, z)))
        c = cols[k % len(cols)]
        bulbs[c].append(lathe('zarowka', [(0.0, -0.05), (0.016, -0.055), (0.036, -0.1), (0.04, -0.13), (0.03, -0.16), (0.0, -0.172)], glow(c, c, 5.0), 10, loc=(x, y, z)))
    join('Przewod', p)
    for i, c in enumerate(cols):
        join('Swiatlo%d' % i, bulbs[c])
    export('klub_girlanda')


def klub_vip():
    """loża VIP 2,9 × 3,4 m na podeście: stopień, podświetlona krawędź, narożna pikowana kanapa w złotym welurze, niski stół z kubełkiem szampana,
    butelkami i kieliszkami, słupki z liną przy wejściu, neon VIP na ścianie"""
    reset()
    W, D, H = 2.9, 3.4, 0.25
    dark = mat('podest', '101014', 0.5)
    p = [rbox('podest', (W, D, H), dark, 0.01, (0, 0, H / 2))]
    p.append(rbox('wykladzina', (W - 0.1, D - 0.1, 0.012), mat('wykladzina', '3a0f1c', 0.95), 0.004, (0, 0, H + 0.006)))
    p.append(rbox('stopien', (0.42, 1.3, 0.125), dark, 0.008, (W / 2 + 0.2, -0.9, 0.0625)))
    br = mat('mosiadz', 'c9a44a', 0.22, 0.95)
    for sy in (-1.62, -0.2):
        p.append(lathe('slupek', [(0.0, 0.0), (0.14, 0.0), (0.14, 0.02), (0.05, 0.05), (0.022, 0.08), (0.022, 0.9), (0.04, 0.92), (0.045, 0.96), (0.03, 0.98), (0.0, 0.99)], br, 16, loc=(W / 2 - 0.12, sy, H)))
    p.append(tube('lina', [(W / 2 - 0.12, -1.62 + k * 0.142, H + 0.9 - 0.2 * math.sin(k / 10 * math.pi)) for k in range(11)], 0.02, mat('welur', '8a1424', 0.9), 8))
    fr = join('Podest', p)
    weather([fr], 1024, 0.4, 0.4)
    # narożna kanapa: bok zachodni i północny
    vel = mat('welur_z', '8a6a2a', 0.6)
    s = []
    def seg(cx, cy, length, along_y):
        sz = (0.78, length, 0.22) if along_y else (length, 0.78, 0.22)
        s.append(rbox('skrzynia', sz, vel, 0.03, (cx, cy, H + 0.22), segs=3))
        n = int(round(length / 0.62))
        for k in range(n):
            o = -length / 2 + (k + 0.5) * length / n
            if along_y:
                s.append(rbox('poducha', (0.6, length / n - 0.02, 0.14), vel, 0.05, (cx + 0.07, cy + o, H + 0.4), segs=4))
                s.append(rbox('plecy', (0.16, length / n - 0.02, 0.5), vel, 0.05, (cx - 0.27, cy + o, H + 0.66), (0, math.radians(-8), 0), segs=4))
                s.extend(bolts('guzik', [(cx - 0.185, cy + o + dy, H + 0.66 + dz) for dy in (-0.14, 0.14) for dz in (-0.1, 0.1)], br, 0.014, 0.008, 'X'))
            else:
                s.append(rbox('poducha', (length / n - 0.02, 0.6, 0.14), vel, 0.05, (cx + o, cy - 0.07, H + 0.4), segs=4))
                s.append(rbox('plecy', (length / n - 0.02, 0.16, 0.5), vel, 0.05, (cx + o, cy + 0.27, H + 0.66), (math.radians(-8), 0, 0), segs=4))
                s.extend(bolts('guzik', [(cx + o + dx, cy + 0.185, H + 0.66 + dz) for dx in (-0.14, 0.14) for dz in (-0.1, 0.1)], br, 0.014, 0.008, 'Y'))
    seg(-W / 2 + 0.44, -0.2, 2.5, True)
    seg(0.3, D / 2 - 0.44, 2.1, False)
    so = join('Kanapa', s)
    weather([so], 1024, 0.35, 0.3, (0.12, 0.08, 0.04))
    # stół z marmurowym blatem, kubełek z szampanem, butelki, kieliszki
    t = [rbox('blat', (1.1, 0.7, 0.04), mat('marmur', '1c1c22', 0.12, 0.2), 0.012, (0.2, -0.15, H + 0.44))]
    t.append(rbox('noga', (0.5, 0.3, 0.42), mat('zloto_n', 'c9a44a', 0.25, 0.9), 0.02, (0.2, -0.15, H + 0.21)))
    t.append(tube('rant', [(0.2 + sx * 0.55, -0.15 + sy * 0.35, H + 0.44) for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1), (-1, -1))], 0.008, br, 6))
    ch = mat('chrom', 'd4d8dc', 0.12, 0.9)
    t.append(lathe('kubelek', [(0.0, 0.0), (0.08, 0.0), (0.11, 0.2), (0.115, 0.21), (0.1, 0.21), (0.075, 0.012), (0.0, 0.012)], ch, 16, loc=(0.5, -0.05, H + 0.46)))
    gl = mat('szklo', 'e8f4f8', 0.05, 0.0, 0.0, 0.35)
    bt = lathe('szampan', [(0.0, 0.0), (0.042, 0.0), (0.042, 0.17), (0.015, 0.26), (0.014, 0.33), (0.018, 0.34), (0.0, 0.345)], mat('but_z', '14301c', 0.12, 0.0, 0.0, 0.85), 12, loc=(0.5, -0.05, H + 0.5))
    bt.rotation_euler = (0.25, 0.1, 0)
    t.append(bt)
    t.append(lathe('folia', [(0.0145, 0.27), (0.019, 0.275), (0.019, 0.345), (0.0, 0.35)], mat('zloto_n', 'c9a44a', 0.25, 0.9), 10, loc=(0.5 + 0.0, -0.05 - 0.07, H + 0.5 + 0.0)))
    for k, (x, y) in enumerate(((-0.1, -0.3), (0.05, 0.02), (0.3, -0.38), (-0.2, 0.0), (0.62, -0.36))):
        t.append(lathe('kieliszek%d' % k, [(0.0, 0.0), (0.03, 0.0), (0.004, 0.008), (0.004, 0.09), (0.024, 0.13), (0.028, 0.2), (0.026, 0.2), (0.022, 0.132), (0.0, 0.095)], gl, 12, loc=(0.2 + x * 0.9 - 0.18, -0.15 + y * 0.6 + 0.1, H + 0.46)))
    t.append(lathe('wodka', [(0.0, 0.0), (0.035, 0.0), (0.035, 0.2), (0.014, 0.26), (0.014, 0.31), (0.0, 0.31)], mat('but_b', 'dfe8ee', 0.08, 0.0, 0.0, 0.5), 12, loc=(-0.12, -0.2, H + 0.46)))
    t.append(rbox('popielniczka', (0.12, 0.12, 0.025), mat('marmur', '1c1c22', 0.12, 0.2), 0.008, (0.0, 0.05, H + 0.473)))
    t.append(rbox('banknoty', (0.15, 0.07, 0.02), mat('banknot', '8a9a7a', 0.9), 0.003, (0.36, -0.3, H + 0.47), (0, 0, 0.5)))
    to = join('Stol', t)
    weather([to], 512, 0.25, 0.2)
    # podświetlona krawędź podestu i neon na ścianie
    j = [rbox('led_p', (W, 0.012, 0.03), glow(GOLD, GOLD, 4.0), 0.0, (0, -D / 2 - 0.004, H - 0.03), segs=1), rbox('led_b', (0.012, D, 0.03), glow(GOLD, GOLD, 4.0), 0.0, (W / 2 + 0.004, 0, H - 0.03), segs=1)]
    join('SwiatloLed', j)
    text('SwiatloVip', 'VIP', 0.5, glow(GOLD, GOLD, 5.0), (0.3, D / 2 - 0.05, 2.45), (R90, 0, 0), 0.012)
    tube('SwiatloRamka', [(-0.42, D / 2 - 0.05, 2.36), (1.02, D / 2 - 0.05, 2.36), (1.02, D / 2 - 0.05, 2.92), (-0.42, D / 2 - 0.05, 2.92), (-0.42, D / 2 - 0.05, 2.36)], 0.012, glow(PINK, PINK), 6)
    export('klub_vip')


ALL = (klub_neon_drink, klub_neon_piorun, klub_neon_serce, klub_neon_fale, klub_neon_palma, klub_kinkiet, klub_girlanda, klub_vip)
only = [a for a in sys.argv[sys.argv.index('--') + 1:]] if '--' in sys.argv else []
for f in ALL:
    if not only or f.__name__ in only:
        f()
