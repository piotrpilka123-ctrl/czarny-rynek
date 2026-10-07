"""Altanka działkowa: budka z desek 2,6 × 2,0 m na bloczkach, dwuspadowy dach z papy z listwami, drzwi z zastrzałem
i kłódką, okienko z firanką i skrzynką na kwiaty, rynna do niebieskiej beczki, szpadel i grabie oparte o ścianę, ławeczka.
Ściany („TintSciany”) są jasne — gra barwi je na kolor farby. Przód (drzwi) = −Y, spód na z = 0."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
from lib import _finish

R90 = math.radians(90)
rnd = random.Random(7)


def altanka():
    reset()
    W, D, H, Z0 = 2.6, 2.0, 2.0, 0.14
    plank = mat('deska', 'd9d5c9', 0.9, wzor='drewno')
    dark = mat('belka', '4a3a2c', 0.9, wzor='drewno')
    con = mat('beton', '9a968c', 0.92, wzor='beton')
    tar = mat('papa', '2c2a29', 0.95)
    st = mat('stal', '5a5e62', 0.5, 0.7)
    white = mat('biale', 'e6e2d6', 0.6)
    glass = mat('szyba', '1a2226', 0.15, 0.3)
    # --- ściany z pionowych desek (każda ciut inna: szpary, nierówny dół)
    w = []
    def sciana(n, x0, y0, dx, dy, length):
        k = int(round(length / 0.2))
        for i in range(k):
            t = (i + 0.5) / k
            hh = H + rnd.uniform(-0.015, 0.01)
            sz = (length / k - 0.006, 0.024, hh) if dx else (0.024, length / k - 0.006, hh)
            w.append(rbox('%s%d' % (n, i), sz, plank, 0.003, (x0 + dx * length * t, y0 + dy * length * t, Z0 + hh / 2 + rnd.uniform(0.0, 0.012)), segs=1))
    sciana('f', -W / 2, -D / 2, 1, 0, W)
    sciana('t', -W / 2, D / 2, 1, 0, W)
    sciana('l', -W / 2, -D / 2, 0, 1, D)
    sciana('p', W / 2, -D / 2, 0, 1, D)
    # szczyty: deski przycięte w trójkąt (jedna płyta z rowkami wystarczy)
    for sy in (-1, 1):
        g = profile('szczyt', [(-W / 2, 0.0), (W / 2, 0.0), (0.0, 0.62)], 0.024, plank, 0.002)
        g.location = (0, sy * D / 2, Z0 + H)
        w.append(g)
    sc = join('TintSciany', w)
    # --- konstrukcja, dach, drzwi, okno, drobiazgi
    p = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(rbox('bloczek', (0.3, 0.3, 0.16), con, 0.01, (sx * (W / 2 - 0.12), sy * (D / 2 - 0.12), 0.07)))
            p.append(rbox('naroznik', (0.07, 0.07, H + 0.02), dark, 0.004, (sx * (W / 2 + 0.005), sy * (D / 2 + 0.005), Z0 + H / 2)))
    for sy in (-1, 1):
        p.append(rbox('podwalina', (W + 0.08, 0.08, 0.1), dark, 0.006, (0, sy * (D / 2), Z0 + 0.02)))
    for sx in (-1, 1):
        p.append(rbox('podwalina_b', (0.08, D + 0.08, 0.1), dark, 0.006, (sx * (W / 2), 0, Z0 + 0.02)))
    # dach: dwie połacie z papy, listwy dociskowe co 60 cm, deska czołowa, kalenica
    ang = math.atan2(0.62, W / 2)
    sl = math.hypot(W / 2, 0.62) + 0.28
    for sx in (-1, 1):
        cx = sx * (W / 4 + 0.09 * math.cos(ang))
        cz = Z0 + H + 0.31 - 0.09 * math.sin(ang) + 0.03
        p.append(rbox('polac', (sl, D + 0.5, 0.035), tar, 0.004, (cx, 0, cz), (0, sx * ang, 0)))
        for k in range(5):
            y = -D / 2 - 0.15 + k * (D + 0.3) / 4
            p.append(rbox('listwa', (sl - 0.04, 0.035, 0.018), dark, 0.002, (cx, y, cz + 0.026), (0, sx * ang, 0)))
        for sy in (-1, 1):
            p.append(rbox('wiatrownica', (sl, 0.022, 0.11), dark, 0.003, (cx, sy * (D / 2 + 0.25), cz - 0.045), (0, sx * ang, 0)))
    p.append(rbox('kalenica', (0.16, D + 0.52, 0.03), tar, 0.004, (0, 0, Z0 + H + 0.665)))
    p.append(tube('komin', [(0.7, 0.45, Z0 + H + 0.2), (0.7, 0.45, Z0 + H + 0.95)], 0.05, st, 8))
    p.append(lathe('daszek_k', [(0.0, 0.06), (0.1, 0.0), (0.0, 0.0)], st, 10, loc=(0.7, 0.45, Z0 + H + 0.97)))
    # drzwi: deski, zastrzał „Z”, zawiasy pasowe, skobel z kłódką, próg i stopień z płyty chodnikowej
    yd = -D / 2 - 0.02
    green = mat('drzwi', '3f5a46', 0.8, wzor='drewno')
    for i in range(4):
        p.append(rbox('drzwi%d' % i, (0.19, 0.022, 1.78), green, 0.003, (-0.55 + i * 0.195 - 0.29, yd, Z0 + 0.94), segs=1))
    for z in (Z0 + 0.3, Z0 + 1.55):
        p.append(rbox('poprzeczka', (0.78, 0.02, 0.09), green, 0.003, (-0.55, yd - 0.02, z)))
        p.append(rbox('zawias', (0.3, 0.008, 0.035), st, 0.002, (-0.8, yd - 0.034, z)))
    p.append(rbox('zastrzal', (0.09, 0.02, 1.42), green, 0.003, (-0.55, yd - 0.02, Z0 + 0.93), (0, math.radians(29), 0)))
    p.append(rbox('skobel', (0.14, 0.008, 0.04), st, 0.002, (-0.2, yd - 0.016, Z0 + 1.0)))
    p.append(rbox('klodka', (0.05, 0.022, 0.06), mat('mosiadz', 'a8873a', 0.4, 0.8), 0.006, (-0.16, yd - 0.03, Z0 + 0.95)))
    p.append(rbox('futryna_g', (0.92, 0.035, 0.07), dark, 0.004, (-0.55, yd, Z0 + 1.87)))
    p.append(rbox('stopien', (0.9, 0.5, 0.07), con, 0.01, (-0.55, yd - 0.3, 0.035)))
    # okno od frontu: rama, szyba, szprosy, firanka do połowy, skrzynka z pelargoniami
    xo = 0.72
    p.append(rbox('rama', (0.74, 0.05, 0.64), white, 0.006, (xo, yd - 0.004, Z0 + 1.25)))
    p.append(rbox('szyba', (0.62, 0.02, 0.52), glass, 0.004, (xo, yd - 0.022, Z0 + 1.25)))
    p.append(rbox('szpros_p', (0.03, 0.03, 0.52), white, 0.003, (xo, yd - 0.03, Z0 + 1.25)))
    p.append(rbox('szpros_h', (0.62, 0.03, 0.03), white, 0.003, (xo, yd - 0.03, Z0 + 1.28)))
    p.append(sheet('firanka', 0.6, 0.24, 14, 2, lambda u, v: (0.0, 0.006 * math.sin(u * 40.0), 0.0), mat('firanka', 'ded8c8', 0.9), loc=(xo, yd - 0.016, Z0 + 1.26)))
    p.append(rbox('skrzynka', (0.7, 0.14, 0.12), mat('skrzynka', '6a4a30', 0.9, wzor='drewno'), 0.006, (xo, yd - 0.1, Z0 + 0.86)))
    for i in range(6):
        fx = xo - 0.27 + i * 0.108
        p.append(lathe('lisc%d' % i, [(0.0, 0.0), (0.055, 0.02), (0.06, 0.06), (0.03, 0.1), (0.0, 0.11)], mat('lisc', '3d6a34', 0.8), 7, loc=(fx, yd - 0.1 + rnd.uniform(-0.02, 0.02), Z0 + 0.9)))
        if i % 2 == 0:
            p.append(lathe('kwiat%d' % i, [(0.0, 0.0), (0.028, 0.01), (0.03, 0.03), (0.0, 0.045)], mat('kwiat', 'c8342c', 0.6), 7, loc=(fx + 0.01, yd - 0.11, Z0 + 1.0)))
    # rynna wzdłuż okapu, rura spustowa do niebieskiej beczki na deszczówkę
    ye = D / 2 + 0.2
    zr = Z0 + H + 0.0
    p.append(tube('rynna', [(W / 2 + 0.22, -ye, zr), (W / 2 + 0.22, ye, zr - 0.03)], 0.04, st, 8))
    p.append(tube('rura', [(W / 2 + 0.22, ye - 0.05, zr - 0.03), (W / 2 + 0.22, ye - 0.05, 1.0)], 0.03, st, 8))
    blue = mat('beczka', '2f5f9a', 0.5)
    p.append(lathe('beczka', [(0.0, 0.0), (0.26, 0.0), (0.29, 0.06), (0.3, 0.45), (0.29, 0.84), (0.26, 0.9), (0.24, 0.9), (0.24, 0.86), (0.0, 0.86)], blue, 18, loc=(W / 2 + 0.26, ye - 0.05, 0.0)))
    for z in (0.28, 0.62):
        p.append(lathe('obrecz', [(0.3, 0.0), (0.31, 0.0), (0.31, 0.03), (0.3, 0.03)], blue, 18, loc=(W / 2 + 0.26, ye - 0.05, z)))
    # narzędzia oparte o boczną ścianę: szpadel i grabie; wiadro; ławeczka z deski na pieńkach
    xs = -W / 2 - 0.05
    p.append(tube('trzonek_s', [(xs - 0.22, 0.25, 0.02), (xs - 0.03, 0.25, 1.25)], 0.016, dark, 6))
    p.append(rbox('szpadel', (0.02, 0.19, 0.27), st, 0.004, (xs - 0.245, 0.25, 0.12), (0, math.radians(-9), 0)))
    p.append(tube('raczka_s', [(xs - 0.03, 0.2, 1.25), (xs - 0.03, 0.3, 1.25)], 0.014, dark, 6))
    p.append(tube('trzonek_g', [(xs - 0.3, 0.55, 0.03), (xs - 0.03, 0.55, 1.5)], 0.014, dark, 6))
    p.append(rbox('grabie', (0.03, 0.38, 0.025), st, 0.004, (xs - 0.3, 0.55, 0.04)))
    for i in range(9):
        p.append(tube('zab%d' % i, [(xs - 0.3, 0.55 - 0.17 + i * 0.0425, 0.04), (xs - 0.34, 0.55 - 0.17 + i * 0.0425, 0.0)], 0.004, st, 4))
    p.append(lathe('wiadro', [(0.0, 0.0), (0.11, 0.0), (0.14, 0.26), (0.13, 0.26), (0.105, 0.012), (0.0, 0.012)], mat('ocynk', '9da3a8', 0.4, 0.8), 14, loc=(xs - 0.25, -0.5, 0.0)))
    p.append(rbox('lawka', (0.24, 1.1, 0.04), dark, 0.006, (xs - 0.3, -0.3 + 1.6, 0.42)))
    for sy in (-0.4, 0.4):
        p.append(lathe('pieniek', [(0.0, 0.0), (0.11, 0.0), (0.1, 0.4), (0.0, 0.4)], dark, 10, loc=(xs - 0.3, 1.3 + sy, 0.0)))
    ob = join('Altanka', p)
    weather([sc], 1024, 0.5, 0.55, (0.16, 0.13, 0.1))
    weather([ob], 1024, 0.6, 0.55, (0.1, 0.08, 0.06))
    export('altanka')


altanka()
