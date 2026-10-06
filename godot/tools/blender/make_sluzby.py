"""Szpital, komenda i klub Neon: wyposażenie wnętrz i elementy elewacji.
Części „Swiatlo…” i „Ekran…” świecą, „Tint…” gra barwi sama, „Drzwi” mają oś w zawiasie."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *

R90 = math.radians(90)
rnd = random.Random(7)


def castor(name, loc, r=0.035):
    w = lathe(name, [(0.0, -0.012), (r * 0.55, -0.012), (r, -0.007), (r, 0.007), (r * 0.55, 0.012), (0.0, 0.012)], mat('kolko', '26262a', 0.7), 12)
    w.rotation_euler = (0, R90, 0)
    w.location = loc
    return w


def flat(ob):
    for p in ob.data.polygons:
        p.use_smooth = False
    return ob


def ring(name, r, z, radius, material, n=20, y=0.0, x=0.0, plane='XY'):
    pts = []
    for k in range(n + 1):
        a = k / n * math.tau
        pts.append((x + math.cos(a) * r, y + math.sin(a) * r, z) if plane == 'XY' else (x + math.cos(a) * r, y, z + math.sin(a) * r))
    return tube(name, pts, radius, material, 6)


# ================================================================ SZPITAL
def szp_lozko():
    """łóżko szpitalne: rama z rur na kółkach, podnoszony zagłówek, barierki, materac w dwóch segmentach, koc z przeszyciami, karta na szczycie"""
    reset()
    st = mat('rura', 'c9ced2', 0.3, 0.8)
    wh = mat('lakier', 'e4e2da', 0.45)
    p = []
    for sx in (-1, 1):
        p.append(rbox('podluznica', (0.04, 1.96, 0.05), wh, 0.006, (sx * 0.42, 0, 0.42)))
        for sy in (-0.9, 0.9):
            p.append(tube('noga', [(sx * 0.42, sy, 0.42), (sx * 0.42, sy, 0.085)], 0.018, st, 8))
            p.append(castor('kolko', (sx * 0.42, sy, 0.04)))
            p.append(rbox('widelec', (0.05, 0.05, 0.05), mat('widelec', '6a6e72', 0.5, 0.6), 0.008, (sx * 0.42, sy, 0.085)))
        # barierka boczna: pętla z rury z trzema szczebelkami
        x = sx * 0.47
        p.append(tube('barierka', [(x, 0.05, 0.5), (x, 0.05, 0.86), (x, 0.1, 0.9), (x, 0.8, 0.9), (x, 0.85, 0.86), (x, 0.85, 0.5)], 0.012, st, 8))
        for y in (0.25, 0.45, 0.65):
            p.append(tube('szczebel', [(x, y, 0.5), (x, y, 0.9)], 0.007, st, 6))
    for y in (-0.6, 0.0, 0.6):
        p.append(tube('poprzeczka', [(-0.42, y, 0.4), (0.42, y, 0.4)], 0.014, st, 8))
    p.append(rbox('leze', (0.84, 1.24, 0.025), wh, 0.004, (0, -0.34, 0.455)))
    p.append(rbox('leze_g', (0.84, 0.7, 0.025), wh, 0.004, (0, 0.6, 0.545), (math.radians(16), 0, 0)))
    for y, h in ((1.0, 1.08), (-1.0, 0.86)):
        p.append(tube('szczyt', [(-0.44, y, 0.36), (-0.44, y, h - 0.08), (-0.36, y, h), (0.36, y, h), (0.44, y, h - 0.08), (0.44, y, 0.36)], 0.017, st, 10))
        p.append(rbox('plyta', (0.78, 0.018, h - 0.56), mat('laminat', 'cfd8d2', 0.5), 0.006, (0, y, 0.48 + (h - 0.56) / 2)))
        p += bolts('sr', [(sx * 0.33, y - 0.01 * (1 if y > 0 else -1), 0.56) for sx in (-1, 1)], st, 0.008, 0.005, 'Y' if y < 0 else '-Y')
    p.append(tube('korba', [(0.18, -1.0, 0.36), (0.18, -1.08, 0.36), (0.18, -1.08, 0.28), (0.24, -1.08, 0.28)], 0.009, st, 8))
    fr = join('Rama', p)
    weather([fr], 1024, 0.35, 0.5)
    f = [rbox('materac', (0.82, 1.22, 0.11), mat('materac', 'd8dccf', 0.9), 0.03, (0, -0.34, 0.525), segs=4)]
    f.append(rbox('materac_g', (0.82, 0.7, 0.11), mat('materac', 'd8dccf', 0.9), 0.03, (0, 0.6, 0.615), (math.radians(16), 0, 0), segs=4))
    f.append(rbox('poduszka', (0.58, 0.4, 0.12), mat('poszewka', 'eeeae0', 0.95), 0.055, (0.02, 0.68, 0.72), (math.radians(16), 0.03, 0.08), segs=5))
    f.append(rbox('koc', (0.9, 1.0, 0.045), mat('koc', '6f9aa0', 0.95), 0.02, (0, -0.42, 0.6), segs=3))
    f.append(rbox('zaklad', (0.9, 0.22, 0.055), mat('przescieradlo', 'e8e6dc', 0.95), 0.02, (0, 0.15, 0.6), segs=3))
    for k in range(6):
        f.append(rbox('przeszycie', (0.9, 0.008, 0.05), mat('przeszycie', '557c82', 0.95), 0.002, (0, -0.86 + k * 0.17, 0.602), segs=1))
    for k in range(4):
        f.append(rbox('przeszycie2', (0.008, 1.0, 0.05), mat('przeszycie', '557c82', 0.95), 0.002, (-0.33 + k * 0.22, -0.42, 0.602), segs=1))
    po = join('Posciel', f)
    weather([po], 1024, 0.3, 0.1, (0.2, 0.2, 0.17))
    k = [rbox('podkladka', (0.24, 0.012, 0.32), mat('podkladka', '3a4a5a', 0.6), 0.004, (0, -1.03, 0.66), (math.radians(-8), 0, 0))]
    k.append(rbox('kartka', (0.2, 0.004, 0.27), mat('kartka', 'f0ecdf', 0.95), 0.0, (0, -1.04, 0.655), (math.radians(-8), 0, 0), segs=1))
    k.append(rbox('klips', (0.1, 0.012, 0.025), mat('klips', 'b4b9be', 0.3, 0.8), 0.003, (0, -1.045, 0.8), (math.radians(-8), 0, 0)))
    for i in range(7):
        k.append(rbox('linia', (0.15, 0.002, 0.004), mat('tusz', '39445a', 0.9), 0.0, (-0.01, -1.043 - i * 0.0042, 0.74 - i * 0.03), (math.radians(-8), 0, 0), segs=1))
    join('Karta', k)
    export('szp_lozko')


def szp_stojak():
    """stojak na kroplówkę: pięcioramienna podstawa na kółkach, teleskop, haki, worek z płynem, komora kroplowa, wężyk"""
    reset()
    st = mat('rura', 'c9ced2', 0.3, 0.8)
    p = [lathe('piasta', [(0.0, 0.07), (0.05, 0.07), (0.05, 0.11), (0.02, 0.13), (0.0, 0.13)], st, 14)]
    for k in range(5):
        a = k * math.tau / 5
        cx, cy = math.cos(a) * 0.27, math.sin(a) * 0.27
        p.append(tube('ramie', [(0, 0, 0.1), (cx * 0.5, cy * 0.5, 0.085), (cx, cy, 0.075)], 0.012, st, 8))
        c = castor('kolko', (cx, cy, 0.035))
        c.rotation_euler = (0, R90, a)
        p.append(c)
    p.append(lathe('slupek', [(0.016, 0.1), (0.016, 1.08), (0.022, 1.08), (0.022, 1.14), (0.011, 1.14), (0.011, 1.92), (0.0, 1.92)], st, 12))
    p.append(lathe('pokretlo', [(0.0, 0.0), (0.014, 0.0), (0.018, 0.012), (0.014, 0.03), (0.0, 0.03)], mat('pokretlo', '2a2a2c', 0.6), 10, loc=(0.03, 0, 1.1)))
    for s in (-1, 1):
        p.append(tube('hak', [(0, 0, 1.9), (s * 0.1, 0, 1.92), (s * 0.13, 0, 1.9), (s * 0.13, 0, 1.86), (s * 0.11, 0, 1.845)], 0.005, st, 6))
    ob = join('Stojak', p)
    weather([ob], 512, 0.3, 0.4)
    b = [rbox('worek', (0.11, 0.03, 0.19), mat('plyn', 'dfe9ee', 0.2, 0.0, 0.0, 0.55), 0.012, (0.13, 0, 1.73), segs=3)]
    b.append(rbox('etykieta', (0.07, 0.002, 0.07), mat('etykieta', 'f4f1e6', 0.9), 0.0, (0.13, -0.016, 1.75), segs=1))
    b.append(lathe('komora', [(0.004, 1.52), (0.012, 1.53), (0.012, 1.59), (0.005, 1.6), (0.005, 1.635)], mat('plyn', 'dfe9ee', 0.2, 0.0, 0.0, 0.55), 10, loc=(0.13, 0, 0)))
    b.append(tube('wezyk', [(0.13, 0, 1.52), (0.14, -0.02, 1.3), (0.2, -0.08, 1.1), (0.3, -0.16, 0.98), (0.42, -0.2, 0.92)], 0.003, mat('wezyk', 'e8eef0', 0.3, 0.0, 0.0, 0.7), 6))
    b.append(rbox('zacisk', (0.014, 0.01, 0.03), mat('zacisk', '3a78c8', 0.5), 0.003, (0.145, -0.03, 1.24)))
    join('Kroplowka', b)
    export('szp_stojak')


def szp_parawan():
    """parawan: rama z rur na kółkach i plisowana zasłona na kółeczkach (TintZaslona)"""
    reset()
    st = mat('rura', 'c9ced2', 0.3, 0.8)
    W, H = 1.7, 1.78
    p = []
    for sx in (-1, 1):
        x = sx * W / 2
        p.append(tube('slupek', [(x, 0, 0.07), (x, 0, H)], 0.014, st, 8))
        p.append(tube('stopa', [(x, -0.24, 0.07), (x, 0.24, 0.07)], 0.014, st, 8))
        for sy in (-0.24, 0.24):
            p.append(castor('kolko', (x, sy, 0.035)))
    p.append(tube('gora', [(-W / 2, 0, H), (W / 2, 0, H)], 0.012, st, 8))
    p.append(tube('dol', [(-W / 2, 0, 0.34), (W / 2, 0, 0.34)], 0.012, st, 8))
    for k in range(12):
        x = -W / 2 + 0.08 + k * (W - 0.16) / 11
        p.append(ring('oczko', 0.018, H - 0.03, 0.003, st, 8, 0.0, x, 'XZ'))
    fr = join('Rama', p)
    weather([fr], 512, 0.3, 0.4)

    def folds(u, v):
        amp = 0.035 * (0.55 + 0.45 * (1.0 - v))
        return (0.0, amp * math.sin(u * math.pi * 23.0) + 0.008 * math.sin(u * 51.0 + v * 4.0), 0.0)
    sheet('TintZaslona', W - 0.06, H - 0.42, 92, 5, folds, mat('zaslona', 'e9eeea', 0.95), loc=(0, 0, 0.36))
    export('szp_parawan')


def szp_szafka():
    """szafka przyłóżkowa: szuflada, drzwiczki, rant blatu, kółka; na blacie kubek, leki i chusteczki"""
    reset()
    wh = mat('lakier', 'e4e2da', 0.45)
    p = [rbox('korpus', (0.45, 0.42, 0.68), wh, 0.012, (0, 0, 0.45))]
    p.append(rbox('blat', (0.48, 0.45, 0.022), mat('blat', 'b9c4bc', 0.4), 0.008, (0, 0, 0.802)))
    for sx in (-1, 1):
        p.append(rbox('rant', (0.012, 0.45, 0.03), wh, 0.004, (sx * 0.236, 0, 0.825)))
        for sy in (-0.16, 0.16):
            p.append(castor('kolko', (sx * 0.18, sy, 0.035)))
            p.append(tube('trzpien', [(sx * 0.18, sy, 0.07), (sx * 0.18, sy, 0.115)], 0.008, mat('rura', 'c9ced2', 0.3, 0.8), 6))
    p.append(rbox('rant_t', (0.48, 0.012, 0.03), wh, 0.004, (0, 0.219, 0.825)))
    p.append(rbox('szuflada', (0.41, 0.016, 0.15), wh, 0.006, (0, -0.214, 0.69)))
    p.append(rbox('drzwiczki', (0.41, 0.016, 0.47), wh, 0.006, (0, -0.214, 0.365)))
    hd = mat('uchwyt', '8a9096', 0.3, 0.8)
    p.append(tube('uchwyt', [(-0.07, -0.222, 0.69), (-0.07, -0.245, 0.69), (0.07, -0.245, 0.69), (0.07, -0.222, 0.69)], 0.006, hd, 8))
    p.append(tube('uchwyt2', [(0.15, -0.222, 0.5), (0.15, -0.245, 0.5), (0.15, -0.245, 0.4), (0.15, -0.222, 0.4)], 0.006, hd, 8))
    p.append(rbox('szczelina', (0.42, 0.004, 0.006), mat('cien', '2a2a2a', 0.9), 0.0, (0, -0.213, 0.607), segs=1))
    ob = join('Szafka', p)
    weather([ob], 512, 0.35, 0.5)
    d = [lathe('kubek', [(0.0, 0.0), (0.03, 0.0), (0.034, 0.08), (0.03, 0.08), (0.027, 0.006), (0.0, 0.006)], mat('kubek', 'f0f0ec', 0.4), 14, loc=(-0.12, 0.05, 0.813))]
    d.append(lathe('leki', [(0.0, 0.0), (0.02, 0.0), (0.02, 0.05), (0.014, 0.055), (0.016, 0.07), (0.0, 0.07)], mat('leki', 'c8762a', 0.4, 0.0, 0.0, 0.8), 12, loc=(0.02, 0.1, 0.813)))
    d.append(rbox('chusteczki', (0.2, 0.1, 0.06), mat('pudelko', '9fc0d8', 0.8), 0.006, (0.1, -0.08, 0.843), (0, 0, 0.3)))
    d.append(rbox('chustka', (0.06, 0.03, 0.04), mat('chustka', 'ffffff', 0.95), 0.012, (0.1, -0.08, 0.885), (0.3, 0.2, 0.3)))
    d.append(rbox('blister', (0.09, 0.04, 0.006), mat('blister', 'c9ced2', 0.3, 0.7), 0.002, (-0.05, -0.12, 0.816), (0, 0, -0.5)))
    join('Drobiazgi', d)
    export('szp_szafka')


def szp_monitor():
    """kardiomonitor na statywie: ekran z zapisem EKG (świeci), pokrętła, uchwyt, przewody"""
    reset()
    st = mat('rura', 'c9ced2', 0.3, 0.8)
    p = [lathe('slupek', [(0.02, 0.09), (0.02, 1.02), (0.0, 1.02)], st, 12)]
    for k in range(4):
        a = k * math.tau / 4 + 0.78
        cx, cy = math.cos(a) * 0.25, math.sin(a) * 0.25
        p.append(tube('ramie', [(0, 0, 0.1), (cx, cy, 0.075)], 0.013, st, 8))
        c = castor('kolko', (cx, cy, 0.035))
        c.rotation_euler = (0, R90, a)
        p.append(c)
    p.append(rbox('polka', (0.36, 0.3, 0.02), mat('polka', 'd4d6d0', 0.5), 0.006, (0, 0, 1.03)))
    body = mat('obudowa', 'd9d6c8', 0.5)
    p.append(rbox('obudowa', (0.34, 0.2, 0.27), body, 0.02, (0, 0, 1.18)))
    p.append(rbox('ramka', (0.3, 0.012, 0.21), mat('ramka', '34383c', 0.5), 0.008, (-0.01, -0.102, 1.19)))
    p.append(tube('uchwyt', [(-0.1, 0, 1.315), (-0.1, 0, 1.35), (0.1, 0, 1.35), (0.1, 0, 1.315)], 0.009, mat('ramka', '34383c', 0.5), 8))
    for k in range(4):
        p.append(lathe('pokretlo%d' % k, [(0.0, 0.0), (0.009, 0.0), (0.008, 0.01), (0.0, 0.01)], mat('ramka', '34383c', 0.5), 8, loc=(0.148, -0.1, 1.27 - k * 0.045)))
        p[-1].rotation_euler = (R90, 0, 0)
    for k, y in enumerate((-0.04, 0.0, 0.04)):
        p.append(tube('kabel%d' % k, [(0.17, y, 1.1), (0.24, y - 0.03, 0.95), (0.3, y - 0.1, 0.88), (0.42, y - 0.2, 0.9)], 0.0035, mat('kabel%d' % k, ('c8322a', 'e8c22a', '2a2a2a')[k], 0.6), 6))
    ob = join('Monitor', p)
    weather([ob], 512, 0.3, 0.3)
    rbox('Ekran', (0.25, 0.004, 0.17), mat('ekran', '062a14', 0.2, 0.0, 0.6), 0.0, (-0.02, -0.109, 1.19), segs=1)
    pts = []
    for i in range(41):
        u = i / 40
        ph = (u * 3.0) % 1.0
        y = 0.0
        if 0.42 < ph < 0.46:
            y = -0.012
        elif 0.46 <= ph < 0.5:
            y = 0.055
        elif 0.5 <= ph < 0.54:
            y = -0.022
        elif 0.7 < ph < 0.8:
            y = 0.012
        pts.append((-0.14 + u * 0.24, -0.112, 1.21 + y))
    tube('SwiatloWykres', pts, 0.0022, mat('wykres', '4dff7a', 0.3, 0.0, 6.0), 4)
    text('SwiatloLiczba', '72', 0.05, mat('wykres', '4dff7a', 0.3, 0.0, 6.0), (0.06, -0.112, 1.125), (R90, 0, 0), 0.0006)
    export('szp_monitor')


def szp_umywalka():
    """umywalka przy ścianie (ściana w y=0): misa, bateria, syfon, płytki, lustro, dozownik, ręczniki papierowe"""
    reset()
    wh = mat('ceramika', 'f2f1ec', 0.2)
    p = []
    for i in range(5):
        for j in range(4):
            p.append(rbox('kafel', (0.148, 0.01, 0.148), mat('kafel', 'e6ebe8', 0.25), 0.004, (-0.3 + i * 0.15, -0.005, 0.86 + j * 0.15), segs=1))
    p.append(rbox('fuga', (0.76, 0.006, 0.61), mat('fuga', '9aa29e', 0.9), 0.0, (0, -0.003, 1.085), segs=1))
    b = lathe('misa', [(0.0, 0.7), (0.04, 0.7), (0.19, 0.74), (0.245, 0.84), (0.26, 0.86), (0.245, 0.86), (0.2, 0.78), (0.04, 0.735), (0.0, 0.735)], wh, 24)
    b.scale = (1.0, 0.78, 1.0)
    b.location = (0, -0.22, 0)
    p.append(b)
    p.append(rbox('polka', (0.52, 0.1, 0.03), wh, 0.01, (0, -0.05, 0.85)))
    st = mat('chrom', 'd4d8dc', 0.12, 0.9)
    p.append(tube('bateria', [(0, -0.06, 0.865), (0, -0.06, 1.0), (0, -0.1, 1.04), (0, -0.2, 1.03), (0, -0.21, 0.99)], 0.011, st, 10))
    for sx in (-1, 1):
        p.append(lathe('kurek', [(0.0, 0.0), (0.014, 0.0), (0.018, 0.02), (0.012, 0.035), (0.0, 0.035)], st, 10, loc=(sx * 0.08, -0.06, 0.865)))
    p.append(tube('syfon', [(0, -0.22, 0.7), (0, -0.22, 0.58), (0, -0.16, 0.54), (0, -0.1, 0.58), (0, -0.1, 0.62), (0, 0, 0.62)], 0.016, st, 10))
    p.append(rbox('lustro_rama', (0.5, 0.02, 0.6), mat('rama', 'c9ced2', 0.3, 0.8), 0.006, (0, -0.012, 1.72)))
    p.append(rbox('dozownik', (0.08, 0.07, 0.16), mat('dozownik', 'e8e8e4', 0.4), 0.014, (0.33, -0.04, 1.2)))
    p.append(rbox('dozownik_p', (0.04, 0.02, 0.03), mat('pompka', '3a78c8', 0.5), 0.006, (0.33, -0.08, 1.11)))
    p.append(rbox('reczniki', (0.26, 0.1, 0.34), mat('podajnik', 'd4d6d0', 0.4), 0.012, (-0.52, -0.05, 1.3)))
    p.append(rbox('recznik', (0.2, 0.03, 0.05), mat('papier', 'f4f1e6', 0.95), 0.008, (-0.52, -0.06, 1.115)))
    ob = join('Umywalka', p)
    weather([ob], 1024, 0.4, 0.2, (0.2, 0.2, 0.18))
    rbox('Lustro', (0.46, 0.004, 0.56), mat('lustro', 'b8c4cc', 0.12, 0.35), 0.0, (0, -0.024, 1.72), segs=1)
    export('szp_umywalka')


def _kaseton(name, word, body, glow, sign, W=2.8):
    """podświetlany kaseton na elewację (ściana w y=0): skrzynka z ramą, wsporniki, świecące lico, znak i napis"""
    reset()
    fr = mat('rama', '2a2e34', 0.5, 0.5)
    p = [rbox('skrzynka', (W, 0.16, 0.74), fr, 0.012, (0, -0.1, 0))]
    for sx in (-1, 1):
        p.append(rbox('wspornik', (0.05, 0.1, 0.5), fr, 0.006, (sx * (W / 2 - 0.3), -0.02, 0)))
        p += bolts('sr%d' % sx, [(sx * (W / 2 - 0.05), -0.182, sz * 0.31) for sz in (-1, 1)], mat('sruba', '8a9096', 0.3, 0.8), 0.012, 0.006, 'Y')
    p.append(tube('kabel', [(W / 2 - 0.2, -0.05, -0.37), (W / 2 - 0.2, -0.03, -0.6), (W / 2 - 0.1, -0.01, -0.9)], 0.008, mat('kabel', '1a1a1a', 0.8), 6))
    ob = join('Kaseton', p)
    weather([ob], 512, 0.5, 0.4)
    rbox('SwiatloLico', (W - 0.1, 0.01, 0.64), mat('lico', body, 0.4, 0.0, 1.6), 0.0, (0, -0.182, 0), segs=1)
    gm = mat('znak', glow, 0.4, 0.0, 3.5)
    if sign == 'krzyz':
        j = [rbox('k1', (0.42, 0.012, 0.14), gm, 0.0, (-W / 2 + 0.42, -0.19, 0), segs=1), rbox('k2', (0.14, 0.012, 0.42), gm, 0.0, (-W / 2 + 0.42, -0.19, 0), segs=1)]
        join('SwiatloZnak', j)
    else:
        s = flat(lathe('SwiatloZnak', [(0.0, 0.0), (0.2, 0.0), (0.2, 0.012), (0.0, 0.012)], gm, 8))
        s.rotation_euler = (R90, 0, 0)
        s.location = (-W / 2 + 0.42, -0.186, 0)
    text('SwiatloNapis', word, 0.36, gm, (0.3, -0.19, -0.13), (R90, 0, 0), 0.004)
    export(name)


def szp_szyld():
    _kaseton('szp_szyld', 'HOSPITAL', 'f4f6f4', 'e0262a', 'krzyz', 3.1)


def kom_szyld():
    _kaseton('kom_szyld', 'POLICE', '1c3f9a', 'f2f6ff', 'gwiazda', 2.6)


def szp_wiata():
    """daszek izby przyjęć (ściana w y=0, wysięg 3,2 m): słupy, płyta, czerwony pas z napisem EMERGENCY, rynna, świetlówki od spodu"""
    reset()
    W, D, H = 6.0, 3.2, 3.05
    con = mat('beton', 'c4c6c2', 0.85)
    p = [rbox('plyta', (W, D, 0.2), con, 0.015, (0, -D / 2, H))]
    for sx in (-1, 1):
        p.append(rbox('slup', (0.18, 0.18, H - 0.1), mat('slup', 'd8dad6', 0.6), 0.02, (sx * (W / 2 - 0.25), -D + 0.3, (H - 0.1) / 2)))
        p.append(rbox('stopa', (0.34, 0.34, 0.12), con, 0.01, (sx * (W / 2 - 0.25), -D + 0.3, 0.06)))
        p.append(rbox('glowica', (0.3, 0.3, 0.08), con, 0.01, (sx * (W / 2 - 0.25), -D + 0.3, H - 0.14)))
        p.append(tube('rynna_pion', [(sx * (W / 2 - 0.08), -D + 0.12, H - 0.1), (sx * (W / 2 - 0.08), -D + 0.12, 0.1)], 0.035, mat('rynna', '6a7074', 0.4, 0.6), 8))
    red = mat('pas', 'c4262a', 0.5)
    p.append(rbox('pas', (W + 0.04, 0.06, 0.46), red, 0.006, (0, -D - 0.01, H + 0.06)))
    for sx in (-1, 1):
        p.append(rbox('pas_bok', (0.06, D, 0.46), red, 0.006, (sx * (W / 2 + 0.01), -D / 2, H + 0.06)))
    p.append(rbox('obrobka', (W + 0.1, D + 0.06, 0.03), mat('rynna', '6a7074', 0.4, 0.6), 0.004, (0, -D / 2, H + 0.3)))
    for k in range(5):
        p.append(rbox('zebro', (0.06, D - 0.3, 0.08), con, 0.004, (-W / 2 + 0.6 + k * (W - 1.2) / 4, -D / 2, H - 0.13)))
    ob = join('Wiata', p)
    weather([ob], 1024, 0.6, 0.4)
    text('SwiatloNapis', 'EMERGENCY', 0.3, mat('napis', 'ffffff', 0.4, 0.0, 3.0), (0, -D - 0.045, H - 0.05), (R90, 0, 0), 0.004)
    j = [rbox('sw%d' % k, (1.2, 0.08, 0.03), mat('swietlowka', 'f4f8ff', 0.4, 0.0, 4.0), 0.0, (-1.6 + k * 1.6, -D / 2, H - 0.11), segs=1) for k in range(3)]
    join('SwiatloLampy', j)
    export('szp_wiata')


# ================================================================ KOMENDA
def kom_krata():
    """krata celi 3,2 × 2,6 m: pręty, trzy płaskowniki, słupki; skrzydło „Drzwi” z osią w zawiasie, zamek skrzynkowy, podajnik"""
    reset()
    W, H = 3.2, 2.6
    stl = mat('stal', '4a5058', 0.45, 0.7)
    x0, x1 = 0.35, 1.3          # otwór drzwi
    p = []
    for x in (-W / 2 + 0.03, x0 - 0.03, x1 + 0.03, W / 2 - 0.03):
        p.append(rbox('slupek', (0.06, 0.06, H), stl, 0.006, (x, 0, H / 2)))
    for z in (0.12, 1.25, 2.48):
        p.append(rbox('plask_l', (x0 + W / 2, 0.05, 0.012 if z == 1.25 else 0.05), stl, 0.003, ((x0 - W / 2) / 2, 0, z)))
        p.append(rbox('plask_p', (W / 2 - x1, 0.05, 0.012 if z == 1.25 else 0.05), stl, 0.003, ((W / 2 + x1) / 2, 0, z)))
    p.append(rbox('nadproze', (x1 - x0, 0.06, 0.36), stl, 0.004, ((x0 + x1) / 2, 0, H - 0.18)))
    x = -W / 2 + 0.14
    while x < W / 2 - 0.08:
        if not (x0 - 0.05 < x < x1 + 0.05):
            p.append(tube('pret', [(x, 0, 0.12), (x, 0, 2.48)], 0.011, stl, 8))
        x += 0.115
    p += bolts('nit', [(xx, -0.031, zz) for xx in (-W / 2 + 0.03, W / 2 - 0.03) for zz in (0.3, 1.0, 1.7, 2.3)], stl, 0.012, 0.007, 'Y')
    ob = join('Krata', p)
    weather([ob], 1024, 0.6, 0.7)
    d = [rbox('zawias_os', (0.03, 0.03, 2.2), stl, 0.004, (x0 + 0.015, 0, 1.13))]
    for z in (0.14, 1.13, 2.2):
        d.append(rbox('rama_h', (x1 - x0 - 0.02, 0.045, 0.05), stl, 0.004, ((x0 + x1) / 2, 0, z)))
    d.append(rbox('rama_v', (0.05, 0.045, 2.1), stl, 0.004, (x1 - 0.035, 0, 1.17)))
    x = x0 + 0.12
    while x < x1 - 0.08:
        d.append(tube('pret', [(x, 0, 0.14), (x, 0, 2.2)], 0.011, stl, 8))
        x += 0.115
    d.append(rbox('zamek', (0.16, 0.09, 0.24), mat('zamek', '2e3238', 0.5, 0.6), 0.008, (x1 - 0.1, 0, 1.13)))
    d.append(lathe('dziurka', [(0.0, 0.0), (0.02, 0.0), (0.02, 0.006), (0.0, 0.006)], mat('mosiadz', 'b89a4a', 0.3, 0.9), 10, loc=(x1 - 0.1, -0.046, 1.13)))
    d[-1].rotation_euler = (R90, 0, 0)
    d.append(rbox('podajnik', (0.4, 0.07, 0.016), stl, 0.003, ((x0 + x1) / 2, -0.04, 0.95)))
    d.append(tube('raczka', [(x1 - 0.18, -0.03, 1.4), (x1 - 0.18, -0.07, 1.4), (x1 - 0.18, -0.07, 1.6), (x1 - 0.18, -0.03, 1.6)], 0.01, stl, 8))
    dr = join('Drzwi', d)
    weather([dr], 1024, 0.6, 0.7)
    export('kom_krata')


def kom_prycza():
    """prycza przykręcona do ściany (ściana w y=0): blacha z rantem, wsporniki, cienki pasiasty materac, złożony koc"""
    reset()
    stl = mat('stal', '4a5058', 0.45, 0.7)
    p = [rbox('blacha', (1.9, 0.66, 0.03), stl, 0.006, (0, -0.33, 0.44))]
    p.append(rbox('rant', (1.9, 0.03, 0.08), stl, 0.006, (0, -0.655, 0.46)))
    for sx in (-0.7, 0.7):
        p.append(rbox('wspornik', (0.04, 0.6, 0.04), stl, 0.004, (sx, -0.3, 0.41)))
        p.append(tube('zastrzal', [(sx, -0.6, 0.41), (sx, -0.02, 0.1)], 0.014, stl, 8))
        p.append(rbox('stopka', (0.1, 0.012, 0.14), stl, 0.003, (sx, -0.006, 0.12)))
    p += bolts('nit', [(-0.85 + k * 0.34, -0.672, 0.47) for k in range(6)], stl, 0.01, 0.006, 'Y')
    ob = join('Prycza', p)
    weather([ob], 1024, 0.7, 0.8)
    f = [rbox('materac', (1.82, 0.6, 0.07), mat('drelich', '7d8a78', 0.95), 0.025, (0, -0.33, 0.49), segs=3)]
    for k in range(9):
        f.append(rbox('pas', (0.03, 0.602, 0.072), mat('pasek', '5a6658', 0.95), 0.02, (-0.8 + k * 0.2, -0.33, 0.49), segs=2))
    f.append(rbox('koc', (0.5, 0.42, 0.07), mat('koc', '6a5a4a', 0.95), 0.03, (0.6, -0.33, 0.56), (0, 0, 0.1), segs=3))
    f.append(rbox('koc2', (0.5, 0.42, 0.012), mat('koc_l', '8a7a66', 0.95), 0.004, (0.6, -0.33, 0.58), (0, 0, 0.1), segs=1))
    fo = join('Materac', f)
    weather([fo], 512, 0.6, 0.2, (0.2, 0.18, 0.14))
    export('kom_prycza')


def kom_biurko():
    """biurko dyżurnego: dwie szafki z szufladami, monitor (Ekran), klawiatura, telefon, lampka, kuwety z aktami, kubek, pieczątka"""
    reset()
    wood = mat('okleina', '7a5a3a', 0.55)
    dark = mat('ciemny', '2a2c30', 0.6)
    p = [rbox('blat', (1.6, 0.75, 0.035), wood, 0.008, (0, 0, 0.752))]
    p.append(rbox('obrzeze', (1.61, 0.012, 0.04), dark, 0.003, (0, -0.378, 0.752)))
    hd = mat('uchwyt', '9a9ea4', 0.3, 0.8)
    for sx in (-1, 1):
        p.append(rbox('szafka', (0.42, 0.68, 0.72), wood, 0.006, (sx * 0.57, 0, 0.37)))
        for k in range(3):
            z = 0.61 - k * 0.225
            p.append(rbox('front', (0.39, 0.016, 0.205), mat('front', '86663f', 0.5), 0.005, (sx * 0.57, -0.345, z)))
            p.append(tube('uchwyt', [(sx * 0.57 - 0.06, -0.353, z), (sx * 0.57 - 0.06, -0.375, z), (sx * 0.57 + 0.06, -0.375, z), (sx * 0.57 + 0.06, -0.353, z)], 0.005, hd, 6))
        p.append(lathe('zamek', [(0.0, 0.0), (0.009, 0.0), (0.009, 0.004), (0.0, 0.004)], hd, 8, loc=(sx * 0.57 + 0.15, -0.353, 0.69)))
        p[-1].rotation_euler = (R90, 0, 0)
    p.append(rbox('oslona', (0.72, 0.016, 0.45), wood, 0.004, (0, 0.3, 0.5)))
    ob = join('Biurko', p)
    weather([ob], 1024, 0.5, 0.6)
    d = [rbox('monitor', (0.42, 0.32, 0.34), mat('plastik', 'cfc9b8', 0.6), 0.03, (0.1, 0.12, 1.0), (0, 0, -0.25))]
    d.append(rbox('podstawa', (0.26, 0.24, 0.05), mat('plastik', 'cfc9b8', 0.6), 0.015, (0.1, 0.12, 0.795), (0, 0, -0.25)))
    d.append(rbox('klawiatura', (0.44, 0.16, 0.025), mat('plastik', 'cfc9b8', 0.6), 0.006, (0.02, -0.18, 0.785), (0, 0, -0.1)))
    for k in range(5):
        d.append(rbox('klawisze', (0.4, 0.022, 0.008), mat('klawisz', 'e6e2d4', 0.6), 0.003, (0.02 - 0.003 * k, -0.24 + k * 0.03, 0.8), (0, 0, -0.1), segs=1))
    d.append(rbox('telefon', (0.2, 0.22, 0.05), dark, 0.012, (-0.5, 0.1, 0.795), (0.12, 0, 0.2)))
    d.append(tube('sluchawka', [(-0.58, 0.02, 0.84), (-0.58, 0.05, 0.855), (-0.58, 0.17, 0.855), (-0.58, 0.2, 0.84)], 0.022, dark, 8))
    d.append(tube('sznur', [(-0.58, 0.02, 0.83), (-0.62, -0.05, 0.78), (-0.6, -0.12, 0.775), (-0.52, -0.02, 0.775)], 0.004, dark, 6))
    for k in range(3):
        for j in range(4):
            d.append(rbox('przycisk', (0.022, 0.022, 0.008), mat('klawisz', 'e6e2d4', 0.6), 0.003, (-0.49 + k * 0.035, 0.05 + j * 0.035, 0.83 + j * 0.004), (0.12, 0, 0.2), segs=1))
    for k in range(2):
        d.append(rbox('kuweta%d' % k, (0.26, 0.34, 0.012), dark, 0.004, (0.58, 0.12, 0.775 + k * 0.07)))
        d.append(rbox('akta%d' % k, (0.22, 0.3, 0.03 + k * 0.012), mat('papier', 'ece6d4', 0.95), 0.004, (0.58, 0.12, 0.797 + k * 0.07), (0, 0, 0.05 * k)))
        for sx in (-1, 1):
            d.append(tube('pret%d' % k, [(0.58 + sx * 0.12, 0.28, 0.775), (0.58 + sx * 0.12, 0.28, 0.85)], 0.004, hd, 6))
    d.append(rbox('teczka', (0.24, 0.32, 0.014), mat('teczka', '5a6a8a', 0.8), 0.004, (0.45, -0.2, 0.777), (0, 0, 0.4)))
    d.append(rbox('teczka2', (0.24, 0.32, 0.014), mat('teczka2', '9a6a3a', 0.8), 0.004, (0.47, -0.19, 0.791), (0, 0, 0.25)))
    d.append(lathe('kubek', [(0.0, 0.0), (0.035, 0.0), (0.038, 0.09), (0.033, 0.09), (0.031, 0.008), (0.0, 0.008)], mat('kubek', '2a4a8a', 0.4), 14, loc=(-0.25, -0.2, 0.77)))
    d.append(lathe('pieczatka', [(0.0, 0.0), (0.02, 0.0), (0.02, 0.015), (0.008, 0.03), (0.014, 0.06), (0.0, 0.065)], mat('drewno', '6a4a2a', 0.6), 10, loc=(-0.28, 0.2, 0.77)))
    d.append(lathe('lampka_st', [(0.0, 0.0), (0.07, 0.0), (0.07, 0.015), (0.012, 0.03), (0.012, 0.3), (0.0, 0.3)], dark, 14, loc=(-0.68, 0.25, 0.77)))
    d.append(tube('lampka_r', [(-0.68, 0.25, 1.07), (-0.66, 0.2, 1.18), (-0.58, 0.1, 1.2)], 0.008, dark, 8))
    sh = lathe('lampka_k', [(0.025, 0.0), (0.075, -0.07), (0.07, -0.07), (0.02, -0.004)], mat('zielony', '2a5a3a', 0.4), 14, loc=(-0.56, 0.08, 1.2))
    sh.rotation_euler = (0.3, -0.2, 0)
    d.append(sh)
    dj = join('Sprzet', d)
    weather([dj], 1024, 0.4, 0.4)
    s = rbox('Ekran', (0.32, 0.004, 0.24), mat('ekran', '0a1e3a', 0.2, 0.0, 0.9), 0.0, (0.06, -0.035, 1.0), (0, 0, -0.25), segs=1)
    s.location = (0.1 - 0.165 * math.sin(0.25) * 1.0 - 0.0, 0.12 - 0.165 * math.cos(0.25), 1.0)
    export('kom_biurko')


def kom_tablica():
    """tablica korkowa (ściana w y=0): aluminiowa rama, listy gończe, ogłoszenia, pinezki"""
    reset()
    p = [rbox('korek', (1.5, 0.02, 0.95), mat('korek', '9a7448', 0.95), 0.0, (0, -0.012, 0), segs=1)]
    al = mat('alu', 'b4b9be', 0.35, 0.8)
    for sz in (-1, 1):
        p.append(rbox('rama_h', (1.56, 0.035, 0.035), al, 0.006, (0, -0.018, sz * 0.49)))
    for sx in (-1, 1):
        p.append(rbox('rama_v', (0.035, 0.035, 1.0), al, 0.006, (sx * 0.765, -0.018, 0)))
    ob = join('Tablica', p)
    weather([ob], 512, 0.5, 0.4)
    d = []
    ink = mat('tusz', '1a1a1a', 0.9)
    lay = [(-0.55, 0.2, 0.26, 0.36, 'WANTED', 'f0e8d0'), (-0.22, 0.22, 0.26, 0.36, 'WANTED', 'ece2c4'), (0.12, 0.18, 0.3, 0.42, 'NOTICE', 'f6f4ec'),
           (0.52, 0.22, 0.26, 0.2, 'DUTY', 'f2e06a'), (-0.5, -0.24, 0.34, 0.24, 'MISSING', 'f6f4ec'), (-0.08, -0.26, 0.24, 0.3, 'WANTED', 'f0e8d0'),
           (0.3, -0.25, 0.2, 0.26, 'MAP', 'd8e6d0'), (0.56, -0.12, 0.2, 0.28, 'RULES', 'f6f4ec')]
    for i, (x, z, w, h, word, col) in enumerate(lay):
        rz = rnd.uniform(-0.07, 0.07)
        d.append(rbox('kartka%d' % i, (w, 0.003, h), mat('k' + col, col, 0.95), 0.0, (x, -0.024 - i * 0.0004, z), (0, rz, 0), segs=1))
        d.append(text('napis%d' % i, word, 0.05 if len(word) > 5 else 0.06, ink, (x, -0.027 - i * 0.0004, z + h / 2 - 0.08), (R90, rz, 0), 0.0004))
        if word in ('WANTED', 'MISSING'):
            d.append(rbox('foto%d' % i, (w * 0.55, 0.002, h * 0.42), mat('foto', '4a4a4a', 0.8), 0.0, (x, -0.0265 - i * 0.0004, z - 0.03), (0, rz, 0), segs=1))
        for k in range(3):
            d.append(rbox('linia%d_%d' % (i, k), (w * 0.7, 0.002, 0.006), ink, 0.0, (x, -0.0265 - i * 0.0004, z - h / 2 + 0.03 + k * 0.022), (0, rz, 0), segs=1))
        d.append(lathe('pin%d' % i, [(0.0, 0.0), (0.008, 0.0), (0.008, 0.006), (0.004, 0.012), (0.0, 0.012)], mat('pin%d' % (i % 3), ('c8322a', '2a6ac8', 'e8c22a')[i % 3], 0.4), 8, loc=(x, -0.027, z + h / 2 - 0.015)))
        d[-1].rotation_euler = (R90, 0, 0)
    join('Kartki', d)
    export('kom_tablica')


def kom_szafa():
    """trzy metalowe szafki depozytowe: drzwi z żaluzjami, klamki, numery, kłódka, cokół"""
    reset()
    gr = mat('lakier', '5a6a72', 0.5, 0.3)
    p = [rbox('cokol', (1.08, 0.46, 0.08), mat('cokol', '2a2c30', 0.7), 0.004, (0, 0, 0.04))]
    hd = mat('klamka', 'b4b9be', 0.3, 0.8)
    for k in range(3):
        x = -0.36 + k * 0.36
        p.append(rbox('korpus', (0.355, 0.5, 1.8), gr, 0.006, (x, 0, 0.98)))
        p.append(rbox('drzwi', (0.33, 0.014, 1.74), mat('drzwi', '66767e', 0.45, 0.3), 0.006, (x, -0.253, 0.98)))
        for j in range(5):
            p.append(rbox('zaluzja', (0.2, 0.006, 0.012), mat('cien', '1c1e22', 0.9), 0.002, (x, -0.261, 1.68 - j * 0.03), (0.4, 0, 0), segs=1))
            p.append(rbox('zaluzja_d', (0.2, 0.006, 0.012), mat('cien', '1c1e22', 0.9), 0.002, (x, -0.261, 0.34 - j * 0.03), (0.4, 0, 0), segs=1))
        p.append(rbox('klamka', (0.03, 0.02, 0.11), hd, 0.006, (x + 0.12, -0.268, 1.05)))
        p.append(rbox('ramka_nr', (0.09, 0.006, 0.05), hd, 0.003, (x, -0.262, 1.5)))
        for z in (0.35, 1.0, 1.65):
            p.append(rbox('zawias', (0.012, 0.012, 0.07), hd, 0.003, (x - 0.163, -0.258, z)))
    p.append(tube('klodka', [(0.11, -0.28, 1.0), (0.11, -0.29, 0.975), (0.13, -0.29, 0.975), (0.13, -0.28, 1.0)], 0.004, hd, 6))
    p.append(rbox('klodka_k', (0.04, 0.016, 0.035), mat('mosiadz', 'b89a4a', 0.3, 0.9), 0.004, (0.12, -0.29, 0.955)))
    ob = join('Szafa', p)
    weather([ob], 1024, 0.6, 0.7)
    d = [text('nr%d' % k, '%02d' % (k + 11), 0.032, mat('tusz', '1a1a1a', 0.9), (-0.36 + k * 0.36, -0.266, 1.488), (R90, 0, 0), 0.0005) for k in range(3)]
    join('Numery', d)
    export('kom_szafa')


def kom_lawka():
    """ławka w poczekalni: belka, dwie nogi ze stopami, trzy kubełki z wytłoczonymi żebrami, podłokietniki"""
    reset()
    stl = mat('stal', '3a3e44', 0.45, 0.7)
    p = [rbox('belka', (1.7, 0.06, 0.04), stl, 0.006, (0, 0, 0.36))]
    for sx in (-0.65, 0.65):
        p.append(rbox('noga', (0.05, 0.05, 0.34), stl, 0.006, (sx, 0, 0.18)))
        p.append(rbox('stopa', (0.07, 0.5, 0.03), stl, 0.008, (sx, 0, 0.015)))
    for sx in (-0.86, 0.86):
        p.append(tube('podlokietnik', [(sx, 0.12, 0.4), (sx, 0.12, 0.62), (sx, -0.2, 0.62), (sx, -0.22, 0.4)], 0.013, stl, 8))
    seat = mat('kubelek', '2f5f8a', 0.5)
    for k in range(3):
        x = -0.56 + k * 0.56
        p.append(rbox('siedzisko', (0.5, 0.44, 0.03), seat, 0.014, (x, -0.04, 0.41), (0.06, 0, 0)))
        p.append(rbox('oparcie', (0.5, 0.03, 0.4), seat, 0.014, (x, 0.2, 0.63), (-0.16, 0, 0)))
        for j in range(5):
            p.append(rbox('zebro', (0.38, 0.016, 0.006), mat('kubelek_c', '264e72', 0.5), 0.002, (x, -0.2 + j * 0.08, 0.418 + (-0.2 + j * 0.08) * -0.06 - 0.012), (0.06, 0, 0), segs=1))
            p.append(rbox('zebro_o', (0.38, 0.006, 0.016), mat('kubelek_c', '264e72', 0.5), 0.002, (x, 0.182 + (j - 2) * 0.013, 0.5 + j * 0.065), (-0.16, 0, 0), segs=1))
    ob = join('Lawka', p)
    weather([ob], 1024, 0.5, 0.7)
    export('kom_lawka')


# ================================================================ KLUB NEON
def klub_bar():
    """lada barowa 4,2 m: pikowany front z guzikami, blat z mosiężnym rantem, poręcz pod nogi, nalewak, szkło; listwa LED (SwiatloLed)"""
    reset()
    W = 4.2
    p = [rbox('korpus', (W, 0.6, 1.02), mat('korpus', '17171b', 0.6), 0.008, (0, 0, 0.51))]
    p.append(rbox('cokol', (W, 0.5, 0.1), mat('cokol', '0c0c0e', 0.8), 0.004, (0, 0.06, 0.05)))
    pad = mat('skaj', '5a1626', 0.55)
    br = mat('mosiadz', 'b89a4a', 0.25, 0.9)
    n = 7
    for k in range(n):
        x = -W / 2 + (k + 0.5) * W / n
        p.append(rbox('pik', (W / n - 0.03, 0.06, 0.74), pad, 0.028, (x, -0.31, 0.55), segs=4))
        p += bolts('guzik%d' % k, [(x + dx, -0.342, 0.55 + dz) for dx in (-0.14, 0.14) for dz in (-0.2, 0.2)] + [(x, -0.342, 0.55)], br, 0.014, 0.008, 'Y')
    p.append(rbox('blat', (W + 0.1, 0.78, 0.05), mat('blat', '0a0a0c', 0.15, 0.2), 0.012, (0, -0.06, 1.045)))
    p.append(tube('rant', [(-W / 2 - 0.04, -0.45, 1.045), (W / 2 + 0.04, -0.45, 1.045)], 0.016, br, 10))
    p.append(tube('porecz', [(-W / 2 + 0.1, -0.44, 0.2), (W / 2 - 0.1, -0.44, 0.2)], 0.02, br, 10))
    for k in range(5):
        x = -W / 2 + 0.2 + k * (W - 0.4) / 4
        p.append(tube('wspornik', [(x, -0.3, 0.2), (x, -0.44, 0.2)], 0.012, br, 8))
    ob = join('Bar', p)
    weather([ob], 1024, 0.45, 0.5)
    d = [lathe('nalewak', [(0.0, 0.0), (0.06, 0.0), (0.06, 0.02), (0.035, 0.04), (0.035, 0.34), (0.05, 0.36), (0.05, 0.4), (0.0, 0.42)], mat('chrom', 'd4d8dc', 0.12, 0.9), 16, loc=(0.9, 0.05, 1.07))]
    for k in (-1, 0, 1):
        d.append(tube('kran%d' % k, [(0.9 + k * 0.03, 0.02, 1.42), (0.9 + k * 0.05, -0.06, 1.42), (0.9 + k * 0.05, -0.08, 1.38)], 0.008, mat('chrom', 'd4d8dc', 0.12, 0.9), 8))
        d.append(lathe('raczka%d' % k, [(0.008, 0.0), (0.014, 0.03), (0.012, 0.11), (0.0, 0.12)], mat('raczka%d' % k, ('c8322a', '1a1a1a', 'e8c22a')[k + 1], 0.4), 8, loc=(0.9 + k * 0.05, -0.06, 1.43)))
    d.append(rbox('ociekacz', (0.3, 0.16, 0.015), mat('chrom', 'd4d8dc', 0.12, 0.9), 0.004, (0.9, -0.1, 1.078)))
    gl = mat('szklo', 'e8f4f8', 0.05, 0.0, 0.0, 0.35)
    for i, (x, y) in enumerate(((-1.5, -0.1), (-1.38, -0.2), (-0.4, -0.15), (0.2, -0.22), (1.6, -0.1), (1.72, -0.18))):
        d.append(lathe('szklanka%d' % i, [(0.0, 0.0), (0.028, 0.0), (0.035, 0.12), (0.032, 0.12), (0.026, 0.008), (0.0, 0.008)], gl, 12, loc=(x, y, 1.07)))
    d.append(lathe('popielniczka', [(0.0, 0.0), (0.06, 0.0), (0.065, 0.025), (0.055, 0.025), (0.05, 0.008), (0.0, 0.008)], gl, 14, loc=(-0.9, -0.2, 1.07)))
    d.append(rbox('serwetki', (0.12, 0.06, 0.1), mat('chrom', 'd4d8dc', 0.12, 0.9), 0.006, (-1.9, -0.05, 1.12)))
    d.append(rbox('kasa', (0.34, 0.3, 0.12), mat('kasa', '1c1c20', 0.5), 0.012, (-0.2, 0.1, 1.13)))
    d.append(rbox('kasa_e', (0.26, 0.02, 0.2), mat('kasa', '1c1c20', 0.5), 0.008, (-0.2, 0.12, 1.3), (-0.3, 0, 0)))
    join('Sprzet', d)
    rbox('SwiatloLed', (W, 0.012, 0.03), mat('led', 'ff3bd0', 0.4, 0.0, 5.0), 0.0, (0, -0.44, 1.0), segs=1)
    export('klub_bar')


def klub_regal():
    """regał za barem 4,2 m: lustro, trzy półki z podświetlaną krawędzią (SwiatloLed), czterdzieści butelek"""
    reset()
    W = 4.2
    p = [rbox('plecy', (W, 0.04, 2.0), mat('korpus', '17171b', 0.6), 0.004, (0, -0.02, 1.2))]
    for sx in (-1, 1):
        p.append(rbox('bok', (0.05, 0.32, 2.0), mat('korpus', '17171b', 0.6), 0.006, (sx * (W / 2 - 0.025), -0.16, 1.2)))
    p.append(rbox('szafka', (W, 0.4, 0.9), mat('korpus', '17171b', 0.6), 0.006, (0, -0.2, 0.45)))
    for k in range(6):
        p.append(rbox('front', (W / 6 - 0.02, 0.016, 0.8), mat('front', '202026', 0.5), 0.006, (-W / 2 + (k + 0.5) * W / 6, -0.405, 0.46)))
        p.append(rbox('uchwyt', (0.02, 0.02, 0.2), mat('mosiadz', 'b89a4a', 0.25, 0.9), 0.006, (-W / 2 + (k + 0.5) * W / 6 + 0.25 * (1 if k % 2 == 0 else -1), -0.42, 0.6)))
    shelf = mat('polka', '26262c', 0.3, 0.3)
    for z in (0.92, 1.35, 1.78):
        p.append(rbox('polka', (W - 0.1, 0.28, 0.03), shelf, 0.004, (0, -0.16, z)))
    p.append(rbox('gzyms', (W + 0.06, 0.36, 0.08), mat('korpus', '17171b', 0.6), 0.01, (0, -0.16, 2.24)))
    ob = join('Regal', p)
    weather([ob], 1024, 0.4, 0.4)
    rbox('Lustro', (W - 0.14, 0.004, 1.2), mat('lustro', '8a94a0', 0.06, 1.0), 0.0, (0, -0.042, 1.56), segs=1)
    b = []
    cols = ('2a5a2a', '6a3a14', 'd8d4c8', '1a1a1a', 'b0382c', '2a4a8a', 'c8a23a', '4a2a5a')
    i = 0
    for z in (0.935, 1.365, 1.795):
        x = -W / 2 + 0.16
        while x < W / 2 - 0.12:
            h = rnd.uniform(0.22, 0.32)
            r = rnd.uniform(0.03, 0.042)
            c = cols[rnd.randrange(len(cols))]
            m = mat('but' + c, c, 0.12, 0.0, 0.0, 0.8)
            b.append(lathe('butelka%d' % i, [(0.0, 0.0), (r, 0.0), (r, h * 0.6), (r * 0.4, h * 0.78), (r * 0.36, h), (0.0, h)], m, 10, loc=(x, -0.14 + rnd.uniform(-0.05, 0.05), z)))
            b.append(lathe('etyk%d' % i, [(r + 0.001, h * 0.2), (r + 0.001, h * 0.48)], mat('etyk%d' % (i % 3), ('f0e8d0', 'd8c890', 'e8e8e8')[i % 3], 0.8), 10, loc=(x, b[-1].location[1], z)))
            x += r * 2 + rnd.uniform(0.03, 0.09)
            i += 1
    join('Butelki', b)
    j = [rbox('led%d' % k, (W - 0.1, 0.008, 0.012), mat('led', 'ff3bd0', 0.4, 0.0, 5.0), 0.0, (0, -0.302, z), segs=1) for k, z in enumerate((0.92, 1.35, 1.78))]
    join('SwiatloLed', j)
    export('klub_regal')


def klub_dj():
    """stanowisko DJ-a: front z pionowymi listwami LED (SwiatloLed), blat, dwa gramofony, mikser z gałkami, laptop (Ekran), słuchawki"""
    reset()
    blk = mat('czarny', '121216', 0.55)
    p = [rbox('front', (2.3, 0.08, 1.05), blk, 0.01, (0, -0.4, 0.525))]
    for sx in (-1, 1):
        p.append(rbox('bok', (0.08, 0.8, 1.05), blk, 0.01, (sx * 1.11, 0, 0.525)))
    p.append(rbox('blat', (2.3, 0.8, 0.045), mat('blat', '1c1c22', 0.4), 0.008, (0, 0, 1.03)))
    for k in range(9):
        p.append(rbox('rowek', (0.012, 0.01, 0.95), mat('cien', '050506', 0.9), 0.0, (-1.0 + k * 0.25, -0.442, 0.525), segs=1))
    alu = mat('alu', '9a9ea4', 0.3, 0.8)
    for sx in (-1, 1):
        x = sx * 0.62
        p.append(rbox('gramofon', (0.44, 0.36, 0.07), mat('gramofon', '2a2a30', 0.4), 0.012, (x, -0.02, 1.09)))
        p.append(lathe('talerz', [(0.0, 0.0), (0.15, 0.0), (0.15, 0.014), (0.145, 0.018), (0.0, 0.018)], alu, 28, loc=(x - 0.04, -0.02, 1.125)))
        p.append(lathe('plyta', [(0.0, 0.0), (0.14, 0.0), (0.14, 0.004), (0.0, 0.004)], mat('winyl', '08080a', 0.25), 28, loc=(x - 0.04, -0.02, 1.143)))
        p.append(lathe('etykieta', [(0.0, 0.0), (0.045, 0.0), (0.045, 0.001), (0.0, 0.001)], mat('etyk%d' % sx, 'e8c22a' if sx < 0 else 'c8322a', 0.6), 16, loc=(x - 0.04, -0.02, 1.147)))
        p.append(tube('ramie', [(x + 0.17, 0.12, 1.15), (x + 0.17, 0.12, 1.17), (x + 0.12, -0.02, 1.165), (x + 0.07, -0.08, 1.152)], 0.006, alu, 8))
        p.append(lathe('przeciwwaga', [(0.0, 0.0), (0.016, 0.0), (0.016, 0.03), (0.0, 0.03)], alu, 10, loc=(x + 0.17, 0.15, 1.155)))
        p.append(rbox('suwak', (0.02, 0.14, 0.012), alu, 0.003, (x + 0.19, -0.08, 1.13)))
    p.append(rbox('mikser', (0.32, 0.38, 0.09), mat('mikser', '202026', 0.4), 0.01, (0, -0.02, 1.1)))
    for i in range(4):
        for j in range(4):
            p.append(lathe('galka', [(0.0, 0.0), (0.011, 0.0), (0.009, 0.018), (0.0, 0.018)], mat('galka%d' % (j % 3), ('d4d8dc', 'c8322a', '2a6ac8')[j % 3], 0.4), 8, loc=(-0.11 + i * 0.073, 0.14 - j * 0.045, 1.145)))
        p.append(rbox('tor', (0.008, 0.11, 0.004), mat('cien', '050506', 0.9), 0.0, (-0.11 + i * 0.073, -0.12, 1.146), segs=1))
        p.append(rbox('fader', (0.022, 0.014, 0.016), alu, 0.003, (-0.11 + i * 0.073, -0.12 + rnd.uniform(-0.04, 0.04), 1.153)))
    p.append(rbox('laptop', (0.34, 0.24, 0.016), alu, 0.005, (0.0, 0.26, 1.062)))
    p.append(rbox('laptop_e', (0.34, 0.012, 0.23), alu, 0.005, (0.0, 0.385, 1.175), (-0.2, 0, 0)))
    p.append(tube('paloak', [(-0.98, 0.2, 1.06), (-0.98, 0.2, 1.2), (-0.9, 0.2, 1.24), (-0.82, 0.2, 1.2), (-0.82, 0.2, 1.06)], 0.008, blk, 8))
    for x in (-0.98, -0.82):
        p.append(lathe('muszla', [(0.0, 0.0), (0.04, 0.0), (0.045, 0.02), (0.04, 0.035), (0.0, 0.035)], blk, 12, loc=(x, 0.2, 1.055)))
    ob = join('Stanowisko', p)
    weather([ob], 1024, 0.4, 0.5)
    rbox('Ekran', (0.31, 0.004, 0.2), mat('ekran', '1a3a6a', 0.2, 0.0, 1.2), 0.0, (0.0, 0.376, 1.177), (-0.2, 0, 0), segs=1)
    j = [rbox('led%d' % k, (0.05, 0.012, 0.9), mat('led', 'ff3bd0', 0.4, 0.0, 5.0), 0.0, (-0.875 + k * 0.25, -0.444, 0.525), segs=1) for k in range(8)]
    join('SwiatloLed', j)
    export('klub_dj')


def klub_glosnik():
    """kolumna estradowa: subwoofer i góra z dwoma głośnikami i tubą; membrany, ramki maskownic, narożniki, uchwyty, nóżki"""
    reset()
    blk = mat('sklejka', '15151a', 0.75)
    met = mat('okucie', '6a6e74', 0.35, 0.8)
    cone = mat('membrana', '0a0a0c', 0.6)
    p = [rbox('sub', (0.72, 0.62, 0.78), blk, 0.012, (0, 0, 0.42)), rbox('gora', (0.6, 0.5, 0.95), blk, 0.012, (0, 0, 1.3))]

    def speaker(r, x, z, y):
        s = lathe('membrana', [(0.0, 0.035), (r * 0.25, 0.04), (r * 0.3, 0.06), (r * 0.86, 0.008), (r * 0.95, 0.0), (r, 0.004), (r * 1.08, 0.004), (r * 1.08, -0.01)], cone, 24)
        s.rotation_euler = (R90, 0, 0)
        s.location = (x, y, z)
        p.append(s)
        k = ring('pierscien', r * 1.08, z, 0.008, met, 24, y - 0.004, x, 'XZ')
        p.append(k)
        for a in range(6):
            aa = a * math.tau / 6
            b = bolts('sr', [(x + math.cos(aa) * r * 1.08, y - 0.006, z + math.sin(aa) * r * 1.08)], met, 0.007, 0.005, 'Y')
            p.extend(b)
    speaker(0.23, 0, 0.44, -0.315)
    speaker(0.15, 0, 1.08, -0.255)
    speaker(0.15, 0, 1.44, -0.255)
    p.append(rbox('tuba', (0.36, 0.03, 0.12), cone, 0.01, (0, -0.25, 1.69)))
    p.append(rbox('tuba_w', (0.3, 0.02, 0.07), mat('cien', '050506', 0.9), 0.008, (0, -0.262, 1.69)))
    for (w, d, zc, h) in ((0.72, 0.62, 0.42, 0.78), (0.6, 0.5, 1.3, 0.95)):
        for sx in (-1, 1):
            for sz in (-1, 1):
                p.append(rbox('naroznik', (0.07, 0.07, 0.07), met, 0.012, (sx * (w / 2 - 0.028), -d / 2 + 0.028, zc + sz * (h / 2 - 0.028))))
            p.append(rbox('uchwyt', (0.02, 0.2, 0.1), mat('cien', '050506', 0.9), 0.008, (sx * (w / 2 - 0.004), 0, zc + 0.1)))
            p.append(tube('uchwyt_p', [(sx * (w / 2 + 0.004), -0.07, zc + 0.1), (sx * (w / 2 + 0.02), -0.05, zc + 0.1), (sx * (w / 2 + 0.02), 0.05, zc + 0.1), (sx * (w / 2 + 0.004), 0.07, zc + 0.1)], 0.007, met, 6))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(lathe('nozka', [(0.0, 0.0), (0.03, 0.0), (0.025, 0.03), (0.0, 0.03)], cone, 8, loc=(sx * 0.28, sy * 0.24, 0.0)))
    p.append(rbox('tabliczka', (0.12, 0.004, 0.04), met, 0.002, (0.2, -0.312, 0.74)))
    ob = join('Glosnik', p)
    weather([ob], 1024, 0.5, 0.7)
    export('klub_glosnik')


def klub_stolik():
    """wysoki stolik barowy: ciężka stopa, kolumna, blat z rantem; szkło, butelka, popielniczka"""
    reset()
    met = mat('chrom', 'c4c8cc', 0.2, 0.9)
    p = [lathe('stopa', [(0.0, 0.0), (0.25, 0.0), (0.25, 0.015), (0.08, 0.05), (0.035, 0.08), (0.035, 1.0), (0.07, 1.04), (0.0, 1.04)], met, 24)]
    p.append(lathe('blat', [(0.0, 1.04), (0.34, 1.04), (0.35, 1.05), (0.35, 1.075), (0.34, 1.085), (0.0, 1.085)], mat('blat', '0e0e12', 0.2, 0.2), 32))
    p.append(ring('rant', 0.35, 1.062, 0.008, met, 32))
    p.append(ring('podnozek', 0.2, 0.3, 0.012, met, 24))
    for k in range(3):
        a = k * math.tau / 3
        p.append(tube('szprycha', [(0.03 * math.cos(a), 0.03 * math.sin(a), 0.3), (0.2 * math.cos(a), 0.2 * math.sin(a), 0.3)], 0.008, met, 6))
    ob = join('Stolik', p)
    weather([ob], 512, 0.4, 0.5)
    gl = mat('szklo', 'e8f4f8', 0.05, 0.0, 0.0, 0.35)
    d = [lathe('szklanka', [(0.0, 0.0), (0.028, 0.0), (0.035, 0.12), (0.032, 0.12), (0.026, 0.008), (0.0, 0.008)], gl, 12, loc=(0.12, -0.08, 1.085))]
    d.append(lathe('drink', [(0.0, 0.01), (0.026, 0.01), (0.03, 0.075), (0.0, 0.075)], mat('drink', 'd87a2a', 0.2, 0.0, 0.0, 0.8), 12, loc=(0.12, -0.08, 1.085)))
    d.append(lathe('kieliszek', [(0.0, 0.0), (0.03, 0.0), (0.004, 0.01), (0.004, 0.08), (0.035, 0.11), (0.03, 0.16), (0.028, 0.16), (0.032, 0.112), (0.0, 0.085)], gl, 12, loc=(-0.15, 0.05, 1.085)))
    d.append(lathe('butelka', [(0.0, 0.0), (0.03, 0.0), (0.03, 0.14), (0.012, 0.19), (0.011, 0.24), (0.0, 0.24)], mat('but_z', '2a5a2a', 0.12, 0.0, 0.0, 0.8), 10, loc=(-0.02, 0.16, 1.085)))
    d.append(lathe('popielniczka', [(0.0, 0.0), (0.055, 0.0), (0.06, 0.022), (0.05, 0.022), (0.046, 0.007), (0.0, 0.007)], gl, 14, loc=(-0.05, -0.16, 1.085)))
    join('Szklo', d)
    export('klub_stolik')


def klub_stolek():
    """hoker: stopa, kolumna z podnóżkiem, pikowane siedzisko z lamówką"""
    reset()
    met = mat('chrom', 'c4c8cc', 0.2, 0.9)
    p = [lathe('stopa', [(0.0, 0.0), (0.2, 0.0), (0.2, 0.012), (0.06, 0.04), (0.028, 0.06), (0.028, 0.7), (0.06, 0.72), (0.0, 0.72)], met, 20)]
    p.append(ring('podnozek', 0.16, 0.28, 0.011, met, 20))
    for k in range(3):
        a = k * math.tau / 3
        p.append(tube('szprycha', [(0.025 * math.cos(a), 0.025 * math.sin(a), 0.28), (0.16 * math.cos(a), 0.16 * math.sin(a), 0.28)], 0.007, met, 6))
    p.append(lathe('siedzisko', [(0.0, 0.72), (0.17, 0.72), (0.185, 0.74), (0.185, 0.79), (0.16, 0.815), (0.05, 0.825), (0.0, 0.815)], mat('skaj', '5a1626', 0.55), 20))
    p.append(ring('lamowka', 0.186, 0.765, 0.006, mat('lamowka', '3a0e18', 0.6), 20))
    p += bolts('guzik', [(0, 0, 0.816)], mat('mosiadz', 'b89a4a', 0.25, 0.9), 0.014, 0.008)
    ob = join('Stolek', p)
    weather([ob], 512, 0.4, 0.5)
    export('klub_stolek')


def klub_kula():
    """kula lustrzana na łańcuchu z silniczkiem (zaczep w 0,0,0; „Kula” obraca gra)"""
    reset()
    met = mat('okucie', '6a6e74', 0.35, 0.8)
    p = [rbox('silnik', (0.12, 0.12, 0.08), mat('czarny', '121216', 0.55), 0.012, (0, 0, -0.04))]
    p.append(tube('lancuch', [(0, 0, -0.08), (0.004, 0, -0.16), (-0.004, 0, -0.24), (0, 0, -0.3)], 0.006, met, 6))
    join('Zaczep', p)
    pr = []
    R = 0.24
    n = 11
    for k in range(n + 1):
        a = -math.pi / 2 + k * math.pi / n
        pr.append((max(0.0, math.cos(a) * R), math.sin(a) * R))
    b = flat(lathe('Kula', pr, mat('lusterka', 'd8dee6', 0.08, 1.0), 22))
    b.location = (0, 0, -0.3 - R)
    export('klub_kula')


def klub_reflektor():
    """reflektor PAR na jarzmie z zaciskiem (zaczep w 0,0,0): puszka z żebrami, klapki, soczewka świeci (SwiatloSoczewka)"""
    reset()
    blk = mat('czarny', '121216', 0.55)
    met = mat('okucie', '6a6e74', 0.35, 0.8)
    p = [rbox('zacisk', (0.06, 0.08, 0.08), met, 0.01, (0, 0, -0.04))]
    p.append(tube('jarzmo', [(-0.13, 0, -0.26), (-0.13, 0, -0.1), (-0.1, 0, -0.08), (0.1, 0, -0.08), (0.13, 0, -0.1), (0.13, 0, -0.26)], 0.01, blk, 8))
    ob = join('Jarzmo', p)
    c = []
    can = lathe('puszka', [(0.0, 0.0), (0.07, 0.0), (0.105, 0.04), (0.11, 0.26), (0.118, 0.26), (0.118, 0.275), (0.1, 0.275), (0.1, 0.05), (0.0, 0.05)], blk, 20)
    c.append(can)
    for k in range(5):
        c.append(ring('zebro', 0.112, 0.07 + k * 0.035, 0.004, blk, 20))
    for k in range(4):
        a = k * math.tau / 4
        c.append(rbox('klapka', (0.16, 0.004, 0.09), blk, 0.0, (math.sin(a) * 0.125, -math.cos(a) * 0.125, 0.31), (0.5 * math.cos(a) * -1, 0.5 * math.sin(a) * -1, a), segs=1))
    cj = join('Puszka', c)
    cj.rotation_euler = (math.radians(135), 0, 0)
    cj.location = (0, 0, -0.26)
    lens = lathe('SwiatloSoczewka', [(0.0, 0.262), (0.098, 0.262), (0.098, 0.266), (0.0, 0.27)], mat('soczewka', 'ffffff', 0.3, 0.0, 6.0), 20)
    lens.rotation_euler = (math.radians(135), 0, 0)
    lens.location = (0, 0, -0.26)
    export('klub_reflektor')


def klub_krata():
    """kratownica sceniczna 3 m: cztery pasy z rur, krzyżulce, płyty czołowe"""
    reset()
    alu = mat('alu', 'aeb2b8', 0.3, 0.85)
    L, s = 3.0, 0.14
    p = []
    for sy in (-1, 1):
        for sz in (-1, 1):
            p.append(tube('pas', [(-L / 2, sy * s, sz * s), (L / 2, sy * s, sz * s)], 0.022, alu, 10))
    n = 8
    for k in range(n):
        xa = -L / 2 + k * L / n
        xb = xa + L / n
        up = k % 2 == 0
        for sy in (-1, 1):
            p.append(tube('krz', [(xa, sy * s, -s if up else s), (xb, sy * s, s if up else -s)], 0.01, alu, 6))
        for sz in (-1, 1):
            p.append(tube('krz2', [(xa, -s if up else s, sz * s), (xb, s if up else -s, sz * s)], 0.01, alu, 6))
    for sx in (-1, 1):
        p.append(rbox('czolo', (0.012, s * 2 + 0.06, s * 2 + 0.06), alu, 0.004, (sx * L / 2, 0, 0)))
    ob = join('Krata', p)
    weather([ob], 512, 0.3, 0.4)
    export('klub_krata')


def klub_kanapa():
    """loża: pikowana kanapa 2 m z guzikami i lamówką, na niskim cokole"""
    reset()
    pad = mat('skaj', '5a1626', 0.55)
    br = mat('mosiadz', 'b89a4a', 0.25, 0.9)
    p = [rbox('cokol', (2.0, 0.66, 0.12), mat('cokol', '0c0c0e', 0.8), 0.006, (0, 0, 0.06))]
    p.append(rbox('skrzynia', (2.02, 0.72, 0.24), pad, 0.03, (0, 0, 0.24), segs=3))
    p.append(rbox('oparcie', (2.02, 0.2, 0.62), pad, 0.05, (0, 0.27, 0.62), segs=4))
    for sx in (-1, 1):
        p.append(rbox('bok', (0.16, 0.72, 0.42), pad, 0.05, (sx * 0.95, 0, 0.5), segs=4))
    for k in range(4):
        x = -0.63 + k * 0.42
        p.append(rbox('poducha', (0.41, 0.52, 0.14), pad, 0.05, (x, -0.08, 0.41), segs=4))
        p.append(rbox('plecy', (0.41, 0.1, 0.42), pad, 0.045, (x, 0.17, 0.7), (-0.12, 0, 0), segs=4))
        p += bolts('guzik%d' % k, [(x + dx, 0.115 - (0.7 + dz - 0.7) * 0.12, 0.7 + dz) for dx in (-0.1, 0.1) for dz in (-0.1, 0.1)], br, 0.013, 0.008, 'Y')
    p.append(tube('lamowka', [(-1.01, -0.36, 0.36), (1.01, -0.36, 0.36)], 0.008, mat('lamowka', '3a0e18', 0.6), 8))
    p.append(tube('lamowka2', [(-1.01, 0.2, 0.93), (1.01, 0.2, 0.93)], 0.008, mat('lamowka', '3a0e18', 0.6), 8))
    ob = join('Kanapa', p)
    weather([ob], 1024, 0.4, 0.4, (0.1, 0.05, 0.05))
    export('klub_kanapa')


def klub_drzwi():
    """wejście do klubu (ściana w y=0, wychodzi na −Y): stalowy portal, dwa pikowane skrzydła z bulajami, neonowy łuk (SwiatloNeon),
    kamera, chodnik, słupki z welurową liną"""
    reset()
    stl = mat('stal', '1a1c20', 0.45, 0.6)
    br = mat('mosiadz', 'b89a4a', 0.25, 0.9)
    p = []
    for sx in (-1, 1):
        p.append(rbox('oscieznica', (0.22, 0.3, 2.6), stl, 0.012, (sx * 1.11, -0.1, 1.3)))
    p.append(rbox('nadproze', (2.44, 0.3, 0.3), stl, 0.012, (0, -0.1, 2.6)))
    p.append(rbox('prog', (2.0, 0.34, 0.04), mat('prog', '6a6e74', 0.4, 0.7), 0.006, (0, -0.1, 0.02)))
    pad = mat('obicie', '241016', 0.55)
    for sx in (-1, 1):
        x = sx * 0.5
        p.append(rbox('skrzydlo', (0.98, 0.07, 2.4), stl, 0.008, (x, -0.06, 1.24)))
        p.append(rbox('obicie', (0.82, 0.03, 1.0), pad, 0.02, (x, -0.105, 0.66), segs=3))
        p.append(rbox('obicie_g', (0.82, 0.03, 0.5), pad, 0.02, (x, -0.105, 2.12), segs=3))
        p += bolts('cwiek%d' % sx, [(x + dx, -0.122, z) for dx in (-0.3, 0, 0.3) for z in (0.3, 0.66, 1.02, 2.0, 2.24)], br, 0.014, 0.008, 'Y')
        bul = ring('bulaj', 0.17, 1.55, 0.022, br, 24, -0.1, x, 'XZ')
        p.append(bul)
        g = lathe('szyba', [(0.0, 0.0), (0.165, 0.0), (0.165, 0.006), (0.0, 0.006)], mat('szyba', '2a0a1e', 0.08, 0.3, 0.6), 24)
        g.rotation_euler = (R90, 0, 0)
        g.location = (x, -0.098, 1.55)
        p.append(g)
        p.append(tube('pochwyt', [(x - sx * 0.36, -0.1, 0.95), (x - sx * 0.36, -0.16, 0.98), (x - sx * 0.36, -0.16, 1.32), (x - sx * 0.36, -0.1, 1.35)], 0.016, br, 10))
        p.append(rbox('kopniak', (0.9, 0.012, 0.16), mat('prog', '6a6e74', 0.4, 0.7), 0.004, (x, -0.1, 0.1)))
    p.append(rbox('kamera', (0.1, 0.22, 0.1), mat('kamera', 'd8d8d4', 0.5), 0.02, (1.0, -0.36, 2.82), (0.35, 0, -0.3)))
    p.append(tube('kamera_r', [(1.0, -0.02, 2.9), (1.0, -0.2, 2.9), (1.0, -0.28, 2.86)], 0.012, mat('kamera', 'd8d8d4', 0.5), 6))
    p.append(rbox('popielnica', (0.16, 0.1, 0.3), mat('prog', '6a6e74', 0.4, 0.7), 0.01, (-1.5, -0.05, 1.1)))
    ob = join('Portal', p)
    weather([ob], 1024, 0.5, 0.6)
    c = [rbox('chodnik', (2.0, 2.6, 0.02), mat('chodnik', '6a1420', 0.9), 0.004, (0, -1.6, 0.01))]
    for sx in (-1, 1):
        c.append(rbox('lam', (0.06, 2.6, 0.022), mat('chodnik_l', 'b89a4a', 0.7), 0.004, (sx * 0.97, -1.6, 0.011)))
    cj = join('Chodnik', c)
    weather([cj], 512, 0.7, 0.3, (0.12, 0.1, 0.09))
    s = []
    for sx in (-1, 1):
        for y in (-0.6, -2.7):
            s.append(lathe('slupek', [(0.0, 0.0), (0.15, 0.0), (0.15, 0.02), (0.05, 0.05), (0.022, 0.08), (0.022, 0.92), (0.04, 0.94), (0.045, 0.98), (0.03, 1.0), (0.0, 1.01)], br, 16, loc=(sx * 1.2, y, 0)))
        pts = []
        for k in range(13):
            u = k / 12
            pts.append((sx * 1.2, -0.6 - u * 2.1, 0.93 - 0.26 * math.sin(u * math.pi)))
        s.append(tube('lina', pts, 0.02, mat('welur', '8a1424', 0.9), 8))
    sj = join('Slupki', s)
    weather([sj], 512, 0.3, 0.4)
    pts = []
    for k in range(25):
        a = math.pi - k / 24 * math.pi
        pts.append((math.cos(a) * 1.3, -0.27, 2.85 + math.sin(a) * 0.55))
    pts = [(-1.3, -0.27, 0.2)] + pts + [(1.3, -0.27, 0.2)]
    tube('SwiatloNeon', pts, 0.022, mat('neon', 'ff3bd0', 0.3, 0.0, 6.0), 8)
    export('klub_drzwi')


def klub_bramka():
    """bramka z wykrywaczem metalu: dwie kolumny z listwami (SwiatloLed), nadproże z wyświetlaczem (Ekran), stopy przykręcone do podłogi"""
    reset()
    gr = mat('obudowa', 'c8cac6', 0.5)
    dk = mat('ciemny', '2a2c30', 0.6)
    p = []
    for sx in (-1, 1):
        p.append(rbox('kolumna', (0.11, 0.56, 2.02), gr, 0.02, (sx * 0.44, 0, 1.05)))
        p.append(rbox('stopa', (0.2, 0.7, 0.04), dk, 0.008, (sx * 0.44, 0, 0.02)))
        p.append(rbox('pas', (0.115, 0.5, 0.06), dk, 0.004, (sx * 0.44, 0, 0.5)))
        p.append(rbox('pas2', (0.115, 0.5, 0.06), dk, 0.004, (sx * 0.44, 0, 1.6)))
        p += bolts('sr%d' % sx, [(sx * 0.44 + dx, dy, 0.04) for dx in (-0.07, 0.07) for dy in (-0.3, 0.3)], mat('sruba', '8a9096', 0.3, 0.8), 0.01, 0.006)
    p.append(rbox('nadproze', (0.99, 0.56, 0.14), gr, 0.02, (0, 0, 2.13)))
    p.append(rbox('panel', (0.4, 0.02, 0.1), dk, 0.006, (0, -0.285, 2.13)))
    ob = join('Bramka', p)
    weather([ob], 1024, 0.4, 0.5)
    rbox('Ekran', (0.2, 0.004, 0.05), mat('ekran', '0a2a12', 0.2, 0.0, 1.5), 0.0, (-0.06, -0.297, 2.13), segs=1)
    j = [rbox('led%d' % sx, (0.012, 0.012, 1.0), mat('led', '4dff7a', 0.4, 0.0, 5.0), 0.0, (sx * 0.382, -0.2, 1.1), segs=1) for sx in (-1, 1)]
    j.append(lathe('lampka', [(0.0, 0.0), (0.012, 0.0), (0.012, 0.004), (0.0, 0.004)], mat('led', '4dff7a', 0.4, 0.0, 5.0), 8, loc=(0.12, -0.297, 2.13)))
    j[-1].rotation_euler = (R90, 0, 0)
    join('SwiatloLed', j)
    export('klub_bramka')


ALL = (szp_lozko, szp_stojak, szp_parawan, szp_szafka, szp_monitor, szp_umywalka, szp_szyld, szp_wiata,
       kom_krata, kom_prycza, kom_biurko, kom_tablica, kom_szafa, kom_lawka, kom_szyld,
       klub_bar, klub_regal, klub_dj, klub_glosnik, klub_stolik, klub_stolek, klub_kula, klub_reflektor, klub_krata, klub_kanapa, klub_drzwi, klub_bramka)
only = [a for a in sys.argv[sys.argv.index('--') + 1:]] if '--' in sys.argv else []
for f in ALL:
    if not only or f.__name__ in only:
        f()
