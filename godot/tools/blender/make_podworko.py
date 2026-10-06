"""Podwórko pod blokiem: stara kanapa-„spocik”, stolik z palety z popielniczką i lufkami, grill, płotek ogródka, grządka z warzywami,
rabata z kwiatami, krasnal, suszarka z praniem, skrzynka do siedzenia, zawiniątko (rzecz leżąca na ziemi). Przód = −Y."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *

R90 = math.radians(90)
rnd = random.Random(44)
MUD = (0.16, 0.12, 0.08)


def pod_kanapa():
    """stara kanapa wystawiona pod blok: zapadnięte siedzisko, wytarty welur, rozdarcie z gąbką, jedna noga na cegłach, koc"""
    reset()
    fab = mat('welur', '6a4a3a', 0.95, wzor='sztruks')
    W = 1.8
    p = [rbox('skrzynia', (W, 0.8, 0.22), fab, 0.03, (0, 0, 0.25), (0, math.radians(-2.5), 0), segs=3)]
    p.append(rbox('plecy', (W, 0.2, 0.5), fab, 0.06, (0, 0.3, 0.55), (math.radians(-10), 0, 0), segs=4))
    for sx in (-1, 1):
        p.append(rbox('bok', (0.18, 0.8, 0.4), fab, 0.07, (sx * (W / 2 - 0.09), 0, 0.42), segs=4))
    for k in range(3):
        x = -0.48 + k * 0.48
        sag = (0.0, -0.04, -0.015)[k]
        p.append(rbox('siedzisko', (0.47, 0.58, 0.13), fab, 0.05, (x, -0.08, 0.4 + sag), (math.radians(3), rnd.uniform(-0.04, 0.04), 0), segs=4))
        p.append(rbox('oparcie', (0.47, 0.15, 0.36), fab, 0.06, (x, 0.19, 0.62 + sag * 0.5), (math.radians(-14 + k * 3), 0, rnd.uniform(-0.05, 0.05)), segs=4))
    for sx, sy in ((-1, -1), (1, -1), (1, 1)):
        p.append(lathe('nozka', [(0.0, 0.0), (0.02, 0.0), (0.028, 0.13), (0.0, 0.13)], mat('drewno', '3a2a1c', 0.8), 8, loc=(sx * (W / 2 - 0.12), sy * 0.32, 0.0)))
    ob = join('Kanapa', p)
    weather([ob], 1024, 0.9, 0.5, MUD)
    d = [rbox('cegla1', (0.24, 0.12, 0.065), mat('cegla', '8a4a34', 0.9), 0.006, (-W / 2 + 0.12, 0.32, 0.033))]
    d.append(rbox('cegla2', (0.24, 0.12, 0.065), mat('cegla', '8a4a34', 0.9), 0.006, (-W / 2 + 0.13, 0.31, 0.098), (0, 0, 0.3)))
    d.append(rbox('gabka', (0.16, 0.1, 0.03), mat('gabka', 'd8c88a', 0.95), 0.012, (0.5, -0.33, 0.44), (0.2, 0.1, 0.4), segs=3))
    d.append(rbox('koc', (0.5, 0.75, 0.03), mat('koc', '4a5a4a', 0.95), 0.012, (-0.55, -0.02, 0.485), (math.radians(3), 0, 0.1), segs=3))
    do = join('Drobiazgi', d)
    weather([do], 512, 0.8, 0.3, MUD)
    export('pod_kanapa')


def pod_stolik():
    """stolik z palety na dwóch skrzynkach: popielniczka pełna petów, trzy szklane lufki, zapalniczka, puszki, talia kart"""
    reset()
    wood = mat('paleta', 'b8946a', 0.9, wzor='drewno')
    p = []
    for k in range(5):
        p.append(rbox('deska', (1.0, 0.11, 0.02), wood, 0.004, (0, -0.3 + k * 0.15, 0.4), (0, 0, rnd.uniform(-0.01, 0.01))))
    for sx in (-0.42, 0.0, 0.42):
        p.append(rbox('legar', (0.09, 0.72, 0.07), wood, 0.004, (sx, 0, 0.355)))
    for sx in (-0.3, 0.3):
        p.append(rbox('skrzynka', (0.36, 0.5, 0.32), mat('skrzynka', '2a4a7a', 0.7), 0.01, (sx, 0, 0.16)))
        for k in range(3):
            p.append(rbox('otwor', (0.2, 0.004, 0.03), mat('cien', '101014', 0.9), 0.0, (sx, -0.252, 0.08 + k * 0.08), segs=1))
    ob = join('Stolik', p)
    weather([ob], 1024, 0.55, 0.6, MUD)
    gl = mat('szklo', 'd8e8e0', 0.08, 0.0, 0.0, 0.5)
    d = [lathe('popielniczka', [(0.0, 0.0), (0.07, 0.0), (0.078, 0.03), (0.066, 0.03), (0.06, 0.008), (0.0, 0.008)], gl, 14, loc=(0.1, 0.05, 0.41))]
    d.append(lathe('popiol', [(0.0, 0.008), (0.058, 0.009), (0.04, 0.02), (0.0, 0.024)], mat('popiol', '5a5650', 0.95), 10, loc=(0.1, 0.05, 0.41)))
    for k in range(6):
        a = k * 1.1
        b = rbox('pet%d' % k, (0.035, 0.008, 0.008), mat('pet', 'd8a060' if k % 2 else 'e8e4d8', 0.9), 0.003, (0.1 + math.cos(a) * 0.035, 0.05 + math.sin(a) * 0.035, 0.433), (0, 0.3, a))
        d.append(b)
    # lufki: szklane rurki z okopconym końcem
    for k, (x, y, r) in enumerate(((-0.22, -0.12, 0.3), (-0.15, 0.02, -0.5), (-0.3, 0.1, 1.2))):
        t = lathe('lufka%d' % k, [(0.0035, 0.0), (0.0055, 0.0), (0.0055, 0.085), (0.0035, 0.085)], gl, 8)
        t.rotation_euler = (R90, 0, r)
        t.location = (x, y, 0.417)
        d.append(t)
        s = lathe('okop%d' % k, [(0.0056, 0.0), (0.0058, 0.0), (0.0058, 0.02), (0.0056, 0.02)], mat('okop', '2a1c10', 0.6), 8)
        s.rotation_euler = (R90, 0, r)
        s.location = (x, y, 0.417)
        d.append(s)
    d.append(rbox('zapalniczka', (0.022, 0.012, 0.06), mat('zapal', 'c8322a', 0.4), 0.004, (-0.05, -0.18, 0.418), (R90, 0, 0.7)))
    alu = mat('alu', 'c2c5c9', 0.3, 0.85)
    for k, (x, y) in enumerate(((0.32, -0.2), (0.38, 0.12), (0.26, 0.24))):
        # puszka po piwie: aluminiowe denko i wieczko z zawleczką, kolorowy płaszcz z jaśniejszym pasem etykiety
        body = mat('puszka%d' % k, ('c8a23a', '1f5a34', 'a3261c')[k], 0.35, 0.6)
        band = mat('etykieta%d' % k, ('f1ecd8', 'e8e0c0', 'f1ecd8')[k], 0.45, 0.3)
        cp = [lathe('dno', [(0.0, 0.004), (0.024, 0.0), (0.033, 0.012)], alu, 14),
              lathe('plaszcz', [(0.033, 0.012), (0.033, 0.106)], body, 14),
              lathe('pas', [(0.0334, 0.04), (0.0334, 0.078)], band, 14),
              lathe('wieczko', [(0.033, 0.106), (0.028, 0.12), (0.026, 0.122), (0.024, 0.118), (0.0, 0.118)], alu, 14),
              rbox('zawleczka', (0.012, 0.02, 0.002), mat('ciemne', '4a4c50', 0.4, 0.8), 0.001, (0.0, 0.006, 0.119), segs=1),
              rbox('znak', (0.002, 0.026, 0.026), body, 0.0, (0.0336, 0.0, 0.059), (math.radians(45), 0, 0), segs=1)]
        c = join('puszka%d' % k, cp)
        c.location = (x, y, 0.41)
        c.rotation_euler = (0, 0, k * 1.9)
        if k == 2:
            c.rotation_euler = (R90, 0, 0.6)
            c.location = (x, y, 0.443)
        d.append(c)
    d.append(rbox('karty', (0.06, 0.09, 0.016), mat('karty', 'e8e2d0', 0.6), 0.003, (-0.36, -0.2, 0.418), (0, 0, 0.3)))
    do = join('Drobiazgi', d)
    weather([do], 512, 0.5, 0.2, MUD)
    export('pod_stolik')


def pod_grill():
    """grill kulisty na trzech nogach z kółkami: misa z żarem (Swiatlo), ruszt z kiełbaskami, pokrywa oparta o nogę; obok stołek z talerzem i szczypcami"""
    reset()
    en = mat('emalia', '15171a', 0.35, 0.3)
    st = mat('stal', 'a9aeb3', 0.3, 0.85)
    p = [lathe('misa', [(0.0, 0.52), (0.1, 0.53), (0.24, 0.62), (0.28, 0.72), (0.285, 0.73), (0.27, 0.73), (0.235, 0.64), (0.1, 0.55), (0.0, 0.54)], en, 20)]
    for k in range(3):
        a = k * math.tau / 3 + 0.5
        p.append(tube('noga', [(math.cos(a) * 0.16, math.sin(a) * 0.16, 0.58), (math.cos(a) * 0.3, math.sin(a) * 0.3, 0.04 if k else 0.07)], 0.011, st, 6))
        if k == 0:
            w = lathe('kolko', [(0.0, -0.012), (0.05, -0.012), (0.07, 0.0), (0.05, 0.012), (0.0, 0.012)], mat('guma', '111113', 0.9), 12)
            w.rotation_euler = (R90, 0, a)
            w.location = (math.cos(a) * 0.3, math.sin(a) * 0.3, 0.07)
            p.append(w)
    p.append(lathe('polka', [(0.0, 0.3), (0.22, 0.3), (0.22, 0.305), (0.0, 0.305)], st, 3))
    for k in range(9):
        p.append(tube('ruszt%d' % k, [(-0.24 + k * 0.06, -math.sqrt(max(0.0, 0.26 ** 2 - (-0.24 + k * 0.06) ** 2)), 0.722), (-0.24 + k * 0.06, math.sqrt(max(0.0, 0.26 ** 2 - (-0.24 + k * 0.06) ** 2)), 0.722)], 0.003, st, 4))
    p.append(tube('uchwyt', [(0.28, -0.06, 0.7), (0.34, -0.06, 0.7), (0.34, 0.06, 0.7), (0.28, 0.06, 0.7)], 0.007, mat('drewno', '6a4a2a', 0.7), 6))
    lid = lathe('pokrywa', [(0.29, 0.0), (0.285, 0.02), (0.24, 0.1), (0.1, 0.17), (0.02, 0.18), (0.02, 0.21), (0.0, 0.21), (0.0, 0.165), (0.1, 0.155), (0.23, 0.09), (0.27, 0.0)], en, 20)
    lid.rotation_euler = (math.radians(74), 0, 0.4)
    lid.location = (-0.42, 0.18, 0.28)
    p.append(lid)
    # stołek z talerzem
    p.append(rbox('stolek', (0.32, 0.32, 0.03), mat('plastik', 'e4e2dc', 0.5), 0.01, (0.62, -0.1, 0.44)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(tube('n', [(0.62 + sx * 0.13, -0.1 + sy * 0.13, 0.43), (0.62 + sx * 0.15, -0.1 + sy * 0.15, 0.0)], 0.012, mat('plastik', 'e4e2dc', 0.5), 5))
    p.append(lathe('talerz', [(0.0, 0.0), (0.09, 0.0), (0.11, 0.012), (0.105, 0.014), (0.085, 0.006), (0.0, 0.006)], mat('talerz', 'f0f0ec', 0.3), 14, loc=(0.6, -0.1, 0.456)))
    p.append(tube('szczypce', [(0.5, -0.02, 0.462), (0.72, -0.2, 0.462)], 0.006, st, 5))
    p.append(lathe('butelka', [(0.0, 0.0), (0.03, 0.0), (0.03, 0.13), (0.012, 0.18), (0.012, 0.22), (0.0, 0.22)], mat('but', '6a3a14', 0.12, 0.0, 0.0, 0.8), 10, loc=(0.72, 0.0, 0.456)))
    ob = join('Grill', p)
    weather([ob], 1024, 0.7, 0.5, MUD)
    k = []
    for i in range(5):
        s = tube('kielbasa%d' % i, [(-0.16 + i * 0.075, -0.1, 0.74), (-0.15 + i * 0.075, 0.0, 0.745), (-0.16 + i * 0.075, 0.1, 0.74)], 0.014, mat('kielbasa', '8a3a1c', 0.5), 6)
        k.append(s)
    join('Kielbaski', k)
    lathe('Swiatlo', [(0.0, 0.6), (0.1, 0.6), (0.22, 0.66), (0.0, 0.67)], mat('zar', 'ff5a1a', 0.6, 0.0, 3.0), 12)
    export('pod_grill')


def pod_plotek():
    """płotek ogródka 2 m: słupki i sztachety o nierównych czubkach, dwie żerdzie, obłażąca zielona farba (TintFarba)"""
    reset()
    wd = mat('farba', 'c9cbc8', 0.8)
    p = []
    for sx in (-1.0, 1.0):
        p.append(rbox('slupek', (0.07, 0.07, 0.85), wd, 0.008, (sx, 0, 0.42)))
    for z in (0.22, 0.6):
        p.append(rbox('zerdz', (2.0, 0.03, 0.06), wd, 0.004, (0, 0.03, z)))
    for k in range(12):
        x = -0.92 + k * 0.167
        h = 0.72 + rnd.uniform(-0.03, 0.03)
        p.append(rbox('sztacheta', (0.085, 0.018, h), wd, 0.004, (x, 0.0, h / 2 + 0.04), (0, rnd.uniform(-0.03, 0.03), 0)))
        tip = rbox('czubek', (0.06, 0.018, 0.06), wd, 0.002, (x, 0.0, h + 0.04), (0, math.radians(45), 0))
        p.append(tip)
    ob = join('TintFarba', p)
    weather([ob], 512, 0.8, 0.9, MUD)
    export('pod_plotek')


def pod_grzadka():
    """grządka 1,6 × 0,9 m w obrzeżu z desek: rzędy kapusty i sałaty, pomidory przy palikach, szczypior, konewka"""
    reset()
    p = []
    wd = mat('deska', '7a5a3a', 0.9)
    for sx in (-1, 1):
        p.append(rbox('burta', (0.03, 0.9, 0.16), wd, 0.004, (sx * 0.8, 0, 0.08)))
    for sy in (-1, 1):
        p.append(rbox('burta_k', (1.6, 0.03, 0.16), wd, 0.004, (0, sy * 0.45, 0.08)))
    p.append(rbox('ziemia', (1.56, 0.86, 0.1), mat('ziemia', '2a1c12', 0.98), 0.01, (0, 0, 0.09)))
    fr = join('Skrzynia', p)
    weather([fr], 512, 0.8, 0.5, MUD)
    g = []
    leaf = mat('lisc', '4a8a3a', 0.8)
    for k in range(4):
        x = -0.6 + k * 0.26
        for i in range(6):
            a = i * math.tau / 6 + k
            l = lathe('k', [(0.0, 0.0), (0.05, 0.01), (0.075, 0.05), (0.05, 0.085), (0.0, 0.07)], mat('kapusta', '7aa85a', 0.75), 6, loc=(x + math.cos(a) * 0.03, -0.25 + math.sin(a) * 0.03, 0.14))
            l.rotation_euler = (math.cos(a) * 0.5, math.sin(a) * 0.5, a)
            g.append(l)
        g.append(lathe('glowka', [(0.0, 0.0), (0.05, 0.02), (0.06, 0.06), (0.04, 0.1), (0.0, 0.11)], mat('kapusta', '7aa85a', 0.75), 8, loc=(x, -0.25, 0.14)))
    for k in range(7):
        x = -0.68 + k * 0.2
        for i in range(5):
            a = i * math.tau / 5 + k * 0.7
            l = rbox('salata', (0.07, 0.004, 0.09), leaf, 0.0, (x + math.cos(a) * 0.025, 0.02 + math.sin(a) * 0.025, 0.18), (0.6 * math.sin(a), -0.6 * math.cos(a), a), segs=1)
            g.append(l)
    for k in range(3):
        x = 0.2 + k * 0.24
        g.append(tube('palik', [(x, 0.28, 0.12), (x + 0.01, 0.28, 0.85)], 0.008, wd, 5))
        g.append(tube('pomidor_l', [(x + 0.02, 0.26, 0.14), (x - 0.02, 0.27, 0.4), (x + 0.03, 0.26, 0.66)], 0.006, leaf, 5))
        for i in range(5):
            a = i * 1.3 + k
            g.append(rbox('lisc', (0.11, 0.004, 0.06), leaf, 0.0, (x + math.cos(a) * 0.07, 0.27 + math.sin(a) * 0.05, 0.3 + i * 0.09), (0.3, 0.4 * math.cos(a), a), segs=1))
        for i in range(3):
            g.append(lathe('pomidor', [(0.0, 0.0), (0.02, 0.006), (0.026, 0.024), (0.016, 0.042), (0.0, 0.044)], mat('pomidor', 'c8281c' if i else '7aa83a', 0.4), 8, loc=(x + 0.05 * math.cos(i * 2.1), 0.24 + 0.03 * math.sin(i * 2.1), 0.36 + i * 0.1)))
    for k in range(14):
        g.append(tube('szczypior', [(-0.66 + k * 0.03, 0.3, 0.13), (-0.66 + k * 0.03 + rnd.uniform(-0.02, 0.02), 0.3 + rnd.uniform(-0.02, 0.02), 0.3 + rnd.uniform(0.0, 0.08))], 0.003, leaf, 3))
    join('Rosliny', g)
    k = [lathe('konewka', [(0.0, 0.0), (0.09, 0.0), (0.1, 0.02), (0.1, 0.22), (0.085, 0.24), (0.0, 0.24)], mat('konewka', '3a6a8a', 0.5), 12, loc=(0.98, -0.3, 0.0))]
    k.append(tube('dziobek', [(1.07, -0.3, 0.06), (1.22, -0.3, 0.22), (1.27, -0.3, 0.25)], 0.012, mat('konewka', '3a6a8a', 0.5), 6))
    k.append(tube('ucho', [(0.9, -0.3, 0.06), (0.83, -0.3, 0.14), (0.9, -0.3, 0.22)], 0.01, mat('konewka', '3a6a8a', 0.5), 6))
    ko = join('Konewka', k)
    weather([ko], 256, 0.6, 0.5, MUD)
    export('pod_grzadka')


def pod_kwiaty():
    """rabata 1,2 × 0,5 m obłożona kamieniami: tulipany, żonkile i bratki — wiosna"""
    reset()
    p = [rbox('ziemia', (1.2, 0.5, 0.08), mat('ziemia', '2a1c12', 0.98), 0.03, (0, 0, 0.03), segs=3)]
    for k in range(18):
        a = k / 18 * math.tau
        p.append(rbox('kamien', (0.11, 0.08, 0.06), mat('kamien', '9a9892', 0.9), 0.025, (math.cos(a) * 0.62, math.sin(a) * 0.27, 0.03), (0, 0, a + rnd.uniform(-0.3, 0.3)), segs=2))
    fr = join('Rabata', p)
    weather([fr], 512, 0.8, 0.4, MUD)
    g = []
    leaf = mat('lisc', '4a8a3a', 0.8)
    cols = ('e8323a', 'f2c21a', 'f08ac0', 'ffffff', '8a4ac8')
    for k in range(26):
        x, y = rnd.uniform(-0.5, 0.5), rnd.uniform(-0.18, 0.18)
        h = rnd.uniform(0.16, 0.3)
        g.append(tube('lodyga', [(x, y, 0.06), (x + rnd.uniform(-0.02, 0.02), y, h)], 0.004, leaf, 3))
        g.append(rbox('lisc', (0.02, 0.004, h * 0.7), leaf, 0.0, (x + 0.015, y + 0.01, 0.06 + h * 0.35), (0.15, 0.2, rnd.uniform(0, 3)), segs=1))
        c = cols[k % len(cols)]
        g.append(lathe('kwiat', [(0.0, 0.0), (0.012, 0.004), (0.02, 0.025), (0.016, 0.045), (0.006, 0.04), (0.0, 0.02)], mat('k' + c, c, 0.6), 6, loc=(x, y, h)))
    join('Kwiaty', g)
    export('pod_kwiaty')


def pod_krasnal():
    """krasnal ogrodowy 45 cm: czapka, broda, kubrak, taczka — obtłuczony gips"""
    reset()
    p = [lathe('buty', [(0.0, 0.0), (0.09, 0.0), (0.09, 0.03), (0.07, 0.05), (0.0, 0.05)], mat('but', '3a2a1c', 0.7), 10)]
    p.append(lathe('spodnie', [(0.07, 0.04), (0.08, 0.1), (0.085, 0.16), (0.0, 0.16)], mat('spodnie', '2a4a8a', 0.7), 10))
    p.append(lathe('kubrak', [(0.085, 0.15), (0.1, 0.2), (0.095, 0.28), (0.06, 0.31), (0.0, 0.31)], mat('kubrak', '2a7a3a', 0.7), 12))
    p.append(lathe('glowa', [(0.0, 0.29), (0.055, 0.3), (0.065, 0.34), (0.05, 0.38), (0.0, 0.39)], mat('skora', 'e8b89a', 0.7), 12))
    p.append(lathe('czapka', [(0.066, 0.36), (0.05, 0.4), (0.02, 0.46), (0.0, 0.5)], mat('czapka', 'c8281c', 0.7), 12))
    b = lathe('broda', [(0.0, 0.0), (0.045, 0.02), (0.05, 0.07), (0.03, 0.1), (0.0, 0.1)], mat('broda', 'f0f0ec', 0.8), 8)
    b.location = (0, -0.045, 0.24)
    b.scale = (1.0, 0.6, 1.0)
    p.append(b)
    p.append(lathe('nos', [(0.0, 0.0), (0.012, 0.004), (0.012, 0.016), (0.0, 0.02)], mat('skora', 'e8b89a', 0.7), 6, loc=(0, -0.066, 0.335)))
    for sx in (-1, 1):
        p.append(tube('reka', [(sx * 0.09, 0.0, 0.27), (sx * 0.12, -0.04, 0.2)], 0.022, mat('kubrak', '2a7a3a', 0.7), 6))
    p.append(lathe('pas', [(0.092, 0.17), (0.1, 0.17), (0.1, 0.19), (0.092, 0.19)], mat('pas', '1c1410', 0.6), 12))
    ob = join('Krasnal', p)
    weather([ob], 512, 0.7, 0.8, MUD)
    export('pod_krasnal')


def pod_suszarka():
    """suszarka ogrodowa „parasol”: słup, cztery ramiona z linkami, wiszące pranie (koszulki, ręcznik, skarpety)"""
    reset()
    st = mat('alu', 'aeb2b8', 0.35, 0.8)
    p = [tube('slup', [(0, 0, 0.0), (0, 0, 1.75)], 0.022, st, 8)]
    p.append(lathe('tuleja', [(0.0, 0.0), (0.05, 0.0), (0.04, 0.05), (0.0, 0.06)], mat('beton', 'a9a7a0', 0.9), 8))
    ends = []
    for k in range(4):
        a = k * math.tau / 4 + 0.4
        e = (math.cos(a) * 1.0, math.sin(a) * 1.0, 1.9)
        ends.append(e)
        p.append(tube('ramie', [(0, 0, 1.55), e], 0.012, st, 6))
    for r in (0.45, 0.7, 0.95):
        pts = [(e[0] * r, e[1] * r, 1.55 + 0.35 * r) for e in ends]
        p.append(tube('linka', pts + [pts[0]], 0.003, mat('linka', 'e8e8e4', 0.6), 3))
    fr = join('Suszarka', p)
    weather([fr], 512, 0.5, 0.5)
    c = []
    cols = ('e8e4d8', '3a6a9a', 'c8322a', 'e8c22a', '5a5a5e', 'f0f0ec')
    for k in range(7):
        s = k % 4
        a0, a1 = ends[s], ends[(s + 1) % 4]
        r = (0.95, 0.7)[k % 2]
        t = 0.2 + 0.6 * ((k * 37) % 10) / 10.0
        x = (a0[0] + (a1[0] - a0[0]) * t) * r
        y = (a0[1] + (a1[1] - a0[1]) * t) * r
        z = 1.55 + 0.35 * r
        ang = math.atan2(a1[1] - a0[1], a1[0] - a0[0])
        w, h = ((0.42, 0.5), (0.3, 0.6), (0.12, 0.3))[k % 3]
        cl = sheet('pranie%d' % k, w, h, 6, 5, lambda u, v, k=k: (0.0, 0.03 * math.sin(u * 6.0 + k) * (1.0 - v), 0.0), mat('pr' + cols[k % len(cols)], cols[k % len(cols)], 0.9))
        cl.rotation_euler = (0, 0, ang)
        cl.location = (x, y, z - h)
        c.append(cl)
    co = join('Pranie', c)
    md = co.modifiers.new('g', 'SOLIDIFY')
    md.thickness = 0.004
    export('pod_suszarka')


def pod_znalezisko():
    """coś leży na ziemi: mała reklamówka związana na supeł, obok zmięta gazeta"""
    reset()
    p = [lathe('worek', [(0.0, 0.0), (0.07, 0.0), (0.11, 0.03), (0.12, 0.08), (0.09, 0.13), (0.035, 0.16), (0.03, 0.18), (0.05, 0.21), (0.0, 0.2)], mat('folia', 'e8e4dc', 0.5), 12)]
    p[0].scale = (1.0, 0.8, 1.0)
    p.append(rbox('nadruk', (0.08, 0.004, 0.05), mat('nadruk', 'c8322a', 0.6), 0.0, (0, -0.092, 0.08), segs=1))
    p.append(rbox('gazeta', (0.16, 0.12, 0.012), mat('gazeta', 'cfc9b8', 0.95), 0.004, (0.16, 0.05, 0.006), (0.05, 0.03, 0.5)))
    ob = join('Znalezisko', p)
    weather([ob], 256, 0.7, 0.2, MUD)
    export('pod_znalezisko')


def pod_pck():
    """czerwony kontener na używaną odzież: blaszana skrzynia z uchylną klapą wrzutową, zamkiem, tabliczką i sprejowym tagiem"""
    reset()
    red = mat('lakier', 'b8261e', 0.5, 0.3)
    p = [rbox('skrzynia', (1.1, 1.0, 1.75), red, 0.03, (0, 0, 0.95), segs=3)]
    p.append(rbox('cokol', (1.0, 0.9, 0.1), mat('cokol', '2a2c30', 0.7), 0.006, (0, 0, 0.05)))
    p.append(rbox('daszek', (1.16, 1.06, 0.06), red, 0.02, (0, 0, 1.85)))
    p.append(rbox('wrzutnia', (0.8, 0.12, 0.42), mat('ciemny', '5a1410', 0.6), 0.02, (0, -0.5, 1.42), (math.radians(18), 0, 0)))
    p.append(tube('uchwyt', [(-0.3, -0.58, 1.3), (-0.3, -0.64, 1.28), (0.3, -0.64, 1.28), (0.3, -0.58, 1.3)], 0.014, mat('stal', '8a8f95', 0.4, 0.8), 6))
    p.append(rbox('drzwi', (0.9, 0.012, 0.9), red, 0.006, (0, -0.506, 0.62)))
    p.append(rbox('zamek', (0.08, 0.03, 0.12), mat('stal', '8a8f95', 0.4, 0.8), 0.006, (0.36, -0.52, 0.7)))
    for z in (0.3, 0.95):
        p.append(rbox('zawias', (0.02, 0.02, 0.1), mat('stal', '8a8f95', 0.4, 0.8), 0.004, (-0.46, -0.51, z)))
    ob = join('Kontener', p)
    weather([ob], 1024, 0.8, 0.7, MUD)
    d = [rbox('tabliczka', (0.62, 0.004, 0.22), mat('biel', 'f0eee8', 0.6), 0.0, (0, -0.512, 1.06), segs=1)]
    d.append(text('napis', 'USED CLOTHES', 0.075, mat('druk', 'b8261e', 0.8), (0, -0.516, 1.07), (R90, 0, 0), 0.0006))
    d.append(text('napis2', 'thank you', 0.04, mat('druk', 'b8261e', 0.8), (0, -0.516, 0.99), (R90, 0, 0), 0.0006))
    d.append(tube('tag', [(0.57, -0.3 + k * 0.05, 0.9 + 0.12 * math.sin(k * 1.9) + 0.02 * k) for k in range(13)], 0.008, mat('sprej', 'e8e4dc', 0.7), 4))
    d.append(tube('tag2', [(0.57, -0.1 + 0.14 * math.cos(a), 1.3 + 0.12 * math.sin(a)) for a in [k * 0.6 for k in range(12)]], 0.007, mat('sprej', 'e8e4dc', 0.7), 4))
    join('Napisy', d)
    export('pod_pck')


def pod_barierka():
    """niska barierka trawnikowa 2 m: dwa słupki i poręcz z rury, zielona farba z odpryskami"""
    reset()
    gr = mat('farba', '2f6a3c', 0.55, 0.4)
    p = [tube('porecz', [(-1.0, 0, 0.0), (-1.0, 0, 0.42), (-0.96, 0, 0.46), (0.96, 0, 0.46), (1.0, 0, 0.42), (1.0, 0, 0.0)], 0.02, gr, 8)]
    p.append(tube('slupek', [(0, 0, 0.0), (0, 0, 0.46)], 0.018, gr, 8))
    ob = join('Barierka', p)
    weather([ob], 256, 0.6, 0.9, MUD)
    export('pod_barierka')


ALL = (pod_pck, pod_barierka, pod_kanapa, pod_stolik, pod_grill, pod_plotek, pod_grzadka, pod_kwiaty, pod_krasnal, pod_suszarka, pod_znalezisko)
only = [a for a in sys.argv[sys.argv.index('--') + 1:]] if '--' in sys.argv else []
for f in ALL:
    if not only or f.__name__ in only:
        f()
