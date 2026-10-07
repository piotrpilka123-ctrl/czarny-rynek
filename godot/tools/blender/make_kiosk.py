"""Kiosk uliczny 2,6 × 2,0 m: blaszana budka w zielonej emalii, pas przeszkleń z gazetami i papierosami na wystawie,
okienko z ladą, pasiasta markiza, szyld KIOSK, stojak z gazetami, plakaty, drzwi z kłódką z boku.
Przód (okienko) = −Y, spód na z = 0."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
from lib import _finish

R90 = math.radians(90)
rnd = random.Random(19)
KOLORY = ['c0392b', '2471a3', 'd4ac0d', '1e8449', '7d3c98', 'ca6f1e', '566573', 'b03a6b', 'e8e4d8', '17a589']


def kiosk():
    reset()
    W, D, H = 2.6, 2.0, 2.3
    green = mat('emalia', '2f6e5a', 0.5, 0.25)
    dk = mat('emalia_c', '1d473a', 0.55, 0.25)
    st = mat('stal', '8a8f94', 0.4, 0.8)
    back = mat('wnetrze', '12171a', 0.9)
    white = mat('bialy', 'ecebe4', 0.6)
    ink = mat('tusz', '15161a', 0.6)
    yf = -D / 2
    p = [rbox('cokol', (W + 0.04, D + 0.04, 0.12), mat('cokol', '3a3d40', 0.9), 0.01, (0, 0, 0.06)),
         rbox('dol', (W, D, 0.86), green, 0.02, (0, 0, 0.12 + 0.43)),
         rbox('wieniec', (W, D, 0.17), green, 0.02, (0, 0, 2.155)),
         rbox('tyl', (W - 0.08, 0.05, 1.12), green, 0.005, (0, D / 2 - 0.025, 1.53)),
         rbox('pas', (W + 0.02, D + 0.02, 0.04), dk, 0.005, (0, 0, 0.985))]
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(rbox('slupek', (0.08, 0.08, 1.12), green, 0.01, (sx * (W / 2 - 0.04), sy * (D / 2 - 0.04), 1.53)))
    # przetłoczenia blachy na dolnym pasie
    for i in range(12):
        x = -W / 2 + 0.2 + i * 0.2
        p.append(rbox('zebro_f', (0.035, 0.012, 0.74), green, 0.005, (x, yf - 0.004, 0.55)))
    for sx in (-1, 1):
        for i in range(9):
            y = -D / 2 + 0.2 + i * 0.2
            p.append(rbox('zebro_b', (0.012, 0.035, 0.74), green, 0.005, (sx * (W / 2 + 0.004), y, 0.55)))
    # ciemne wnętrze za wystawą i szprosy
    p.append(rbox('tlo_f', (W - 0.16, 0.02, 1.1), back, 0.0, (0, yf + 0.07, 1.53), segs=1))
    for sx in (-1, 1):
        p.append(rbox('tlo_b', (0.02, D - 0.16, 1.1), back, 0.0, (sx * (W / 2 - 0.07), 0, 1.53), segs=1))
        p.append(rbox('szpros', (0.04, 0.04, 1.1), green, 0.005, (sx * 0.46, yf + 0.03, 1.53)))
        p.append(rbox('szpros_b', (0.04, 0.04, 1.1), green, 0.005, (sx * (W / 2 - 0.03), 0.0, 1.53)))
    # okienko z ramką, lada na wspornikach, miseczka na drobne
    p.append(rbox('okienko_r', (0.86, 0.035, 0.52), st, 0.006, (0, yf + 0.02, 1.27)))
    p.append(rbox('okienko', (0.76, 0.04, 0.42), back, 0.0, (0, yf + 0.018, 1.27), segs=1))
    p.append(rbox('lada', (1.0, 0.32, 0.03), st, 0.008, (0, yf - 0.15, 0.995)))
    for sx in (-0.4, 0.4):
        p.append(tube('wspornik', [(sx, yf - 0.02, 0.78), (sx, yf - 0.28, 0.98)], 0.012, st, 6))
    p.append(lathe('miseczka', [(0.0, 0.0), (0.06, 0.0), (0.08, 0.02), (0.07, 0.02), (0.055, 0.008), (0.0, 0.008)], mat('plastik', '2f3b6a', 0.5), 12, loc=(0.25, yf - 0.2, 1.01)))
    # dach z okapem, wywietrznik, szyld
    p.append(rbox('dach', (W + 0.5, D + 0.6, 0.07), dk, 0.015, (0, -0.05, H + 0.0), (math.radians(-1.5), 0, 0)))
    p.append(lathe('wywietrznik', [(0.0, 0.0), (0.09, 0.0), (0.09, 0.12), (0.14, 0.14), (0.0, 0.2)], st, 12, loc=(0.7, 0.4, H + 0.03)))
    p.append(rbox('szyld', (1.9, 0.05, 0.34), mat('szyld', 'e3b21c', 0.5), 0.01, (0, yf - 0.33, H + 0.2)))
    for sx in (-0.8, 0.8):
        p.append(tube('szyld_w', [(sx, yf - 0.3, H + 0.04), (sx, yf - 0.3, H + 0.1)], 0.015, st, 6))
    # markiza w pasy nad okienkiem: stelaż z rurek i pięć brytów płótna
    ya, za, yb, zb = yf - 0.02, 2.06, yf - 0.62, 1.84
    ang = math.atan2(za - zb, ya - yb)
    for i in range(6):
        col = mat('markiza_c', 'b23226', 0.85, wzor='tkanina') if i % 2 == 0 else mat('markiza_b', 'e6e0d0', 0.85, wzor='tkanina')
        x = -0.75 + i * 0.3
        p.append(rbox('bryt%d' % i, (0.3, math.hypot(ya - yb, za - zb), 0.012), col, 0.002, (x, (ya + yb) / 2, (za + zb) / 2), (ang, 0, 0), segs=1))
        p.append(rbox('falbana%d' % i, (0.3, 0.012, 0.1), col, 0.002, (x, yb - 0.004, zb - 0.05), segs=1))
    for sx in (-0.9, 0.9):
        p.append(tube('stelaz', [(sx, ya, za - 0.03), (sx, yb, zb - 0.02)], 0.012, st, 6))
        p.append(tube('stelaz2', [(sx, ya, 1.62), (sx, yb, zb - 0.02)], 0.012, st, 6))
    # drzwi z prawego boku: skrzydło, klamka, kłódka, próg z palety
    p.append(rbox('drzwi', (0.03, 0.78, 1.92), dk, 0.006, (W / 2 + 0.005, 0.35, 1.1)))
    p.append(tube('klamka', [(W / 2 + 0.03, 0.06, 1.05), (W / 2 + 0.07, 0.06, 1.05), (W / 2 + 0.07, 0.17, 1.05)], 0.01, st, 6))
    p.append(rbox('klodka', (0.03, 0.05, 0.06), mat('mosiadz', 'a8873a', 0.4, 0.8), 0.006, (W / 2 + 0.035, 0.03, 1.2)))
    p.append(rbox('stopien', (0.5, 0.8, 0.1), mat('drewno', '6a5236', 0.9, wzor='drewno'), 0.006, (W / 2 + 0.28, 0.35, 0.05)))
    # skrzynka elektryczna z tyłu i kabel na dach
    p.append(rbox('licznik', (0.3, 0.1, 0.4), mat('szary', '8d9296', 0.6, 0.3), 0.01, (-0.9, D / 2 + 0.05, 1.5)))
    p.append(tube('kabel', [(-0.9, D / 2 + 0.05, 1.7), (-0.9, D / 2 + 0.05, H + 0.02)], 0.012, ink, 5))
    bud = join('Kiosk', p)
    # --- towar na wystawie, stojak z gazetami, plakaty, napisy
    t = []
    def pismo(x, y, z, w, h, ry=0.0, rx=0.0, front=True, k=None):
        c = mat('pismo%d' % (k if k is not None else rnd.randrange(10)), KOLORY[k if k is not None else rnd.randrange(10)], 0.6)
        if front:
            t.append(rbox('pismo', (w, 0.012, h), c, 0.002, (x, y, z), (rx, 0, ry), segs=1))
            t.append(rbox('tytul', (w * 0.86, 0.014, h * 0.2), white, 0.0, (x, y - 0.002, z + h * 0.32), (rx, 0, ry), segs=1))
        else:
            t.append(rbox('pismo', (0.012, w, h), c, 0.002, (x, y, z), segs=1))
            t.append(rbox('tytul', (0.014, w * 0.86, h * 0.2), white, 0.0, (x + (0.002 if x > 0 else -0.002), y, z + h * 0.32), segs=1))
    yw = yf + 0.05
    # lewa szyba: gazety i kolorowe pisma w trzech rzędach
    for r in range(3):
        for c in range(3):
            pismo(-1.12 + c * 0.22, yw, 1.16 + r * 0.33, 0.2, 0.28, k=(r * 3 + c) % 10)
    # prawa szyba: papierosy w rzędach, pod nimi zapalniczki i gumy
    pk = [mat('paczka_b', 'e9e6dc', 0.5), mat('paczka_c', 'b0281e', 0.5), mat('paczka_n', '1f3a7a', 0.5), mat('paczka_z', 'c9a437', 0.5, 0.4)]
    for r in range(4):
        for c in range(7):
            t.append(rbox('paczka', (0.075, 0.02, 0.105), pk[(r + c * 3) % 4], 0.004, (0.57 + c * 0.09, yw, 1.42 + r * 0.14)))
    for c in range(10):
        t.append(rbox('zapalniczka', (0.022, 0.014, 0.075), mat('zap%d' % (c % 5), KOLORY[c % 5], 0.3), 0.004, (0.56 + c * 0.065, yw, 1.12)))
    for c in range(5):
        t.append(rbox('guma', (0.1, 0.03, 0.05), mat('guma%d' % c, KOLORY[(c + 5) % 10], 0.5), 0.004, (0.6 + c * 0.13, yw, 1.24)))
    # boczne szyby: stosy gazet i kilka pism
    for sx in (-1, 1):
        for c in range(4):
            pismo(sx * (W / 2 - 0.05), -0.62 + c * 0.42, 1.7, 0.36, 0.3, front=False, k=(c + (3 if sx > 0 else 0)) % 10)
        for c in range(3):
            t.append(rbox('stos', (0.03, 0.34, 0.16 + 0.05 * (c % 2)), mat('gazeta', 'cfcabd', 0.9), 0.004, (sx * (W / 2 - 0.05), -0.5 + c * 0.5, 1.08 + 0.025 * (c % 2))))
    # stojak druciany przed kioskiem: trzy półki z gazetami pochylonymi do tyłu
    xs, ys = -0.95, yf - 0.5
    for sx in (-0.26, 0.26):
        t.append(tube('stojak', [(xs + sx, ys - 0.12, 0.0), (xs + sx, ys + 0.14, 1.25)], 0.01, st, 6))
        t.append(tube('stojak_n', [(xs + sx, ys + 0.14, 1.25), (xs + sx, ys + 0.3, 0.0)], 0.01, st, 6))
    for r in range(3):
        z = 0.28 + r * 0.36
        yy = ys - 0.12 + (0.26 * z / 1.25)
        t.append(tube('polka', [(xs - 0.27, yy - 0.08, z), (xs + 0.27, yy - 0.08, z)], 0.008, st, 5))
        for c in range(2):
            pismo(xs - 0.13 + c * 0.26, yy - 0.03, z + 0.15, 0.22, 0.3, rx=math.radians(-12), k=(r * 2 + c + 4) % 10)
    # plakaty na dolnym pasie
    t.append(rbox('plakat1', (0.5, 0.008, 0.6), mat('plakat_z', 'e6c21c', 0.6), 0.004, (0.85, yf - 0.012, 0.56)))
    t.append(text('p1a', 'LOTTERY', 0.1, mat('czerwony', 'b0281e', 0.5), (0.85, yf - 0.02, 0.72)))
    t.append(text('p1b', 'JACKPOT', 0.07, ink, (0.85, yf - 0.02, 0.56)))
    t.append(text('p1c', '2 000 000', 0.075, mat('czerwony', 'b0281e', 0.5), (0.85, yf - 0.02, 0.42)))
    t.append(rbox('plakat2', (0.42, 0.008, 0.3), mat('plakat_n', '1f4e8c', 0.6), 0.004, (-0.2, yf - 0.012, 0.7)))
    t.append(text('p2a', 'TOP-UPS', 0.08, white, (-0.2, yf - 0.02, 0.74)))
    t.append(text('p2b', 'TICKETS', 0.06, white, (-0.2, yf - 0.02, 0.63)))
    t.append(text('szyld_t', 'KIOSK', 0.25, ink, (0, yf - 0.36, H + 0.2)))
    t.append(rbox('kartka', (0.2, 0.006, 0.14), white, 0.002, (0.25, yf + 0.0, 1.62)))
    t.append(text('kartka_t', 'BACK IN 5 MIN', 0.022, ink, (0.25, yf - 0.006, 1.62)))
    tow = join('Towar', t)
    weather([bud], 2048, 0.6, 0.6, (0.12, 0.1, 0.08))
    weather([tow], 1024, 0.3, 0.3, (0.12, 0.1, 0.08))
    export('kiosk')


kiosk()
