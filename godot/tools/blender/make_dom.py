"""Wyposażenie mieszkań: waga z woreczkami, kubek, popielniczka, butelka, puszka, pudełko po pizzy, półka z książkami,
aneks kuchenny, lodówka, lampy sufitowe, buty, wieszak z kurtką, pościel, okno z firankami.
Części nazwane „Tint…” są jasne — gra barwi je na wybrany kolor."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *

R90 = math.radians(90)


def waga():
    """waga jubilerska: korpus, szalka ze stali z rantem, wyświetlacz z cyframi, przyciski, nóżki; obok woreczki, pojemnik, łyżeczka"""
    reset()
    dark = mat('korpus', '26282c', 0.5)
    st = mat('stal', 'b4b9be', 0.28, 0.85)
    p = [rbox('korpus', (0.2, 0.26, 0.028), dark, 0.008, (0, 0, 0.016))]
    p.append(rbox('panel', (0.19, 0.072, 0.003), mat('panel', '0e0f11', 0.25), 0.002, (0, -0.088, 0.0305), segs=1))
    p.append(rbox('ramka', (0.092, 0.04, 0.003), mat('ramka', '3a3d42', 0.4, 0.5), 0.002, (-0.035, -0.088, 0.032), segs=1))
    for k in range(3):
        b = lathe('przycisk%d' % k, [(0.0, 0.0), (0.0085, 0.0), (0.0085, 0.002), (0.006, 0.003), (0.0, 0.003)], mat('guma', '5a5e66', 0.8), 14)
        b.location = (0.035 + k * 0.024, -0.088, 0.0315)
        p.append(b)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(lathe('nozka', [(0.0, 0.0), (0.01, 0.0), (0.01, 0.003)], mat('guma', '5a5e66', 0.8), 10, loc=(sx * 0.08, sy * 0.11, -0.001)))
    # szalka: krążek na trzpieniu, z podniesionym rantem i koncentrycznym szlifem
    p.append(lathe('szalka', [(0.0, 0.03), (0.014, 0.03), (0.014, 0.039), (0.086, 0.039), (0.092, 0.041), (0.094, 0.047), (0.091, 0.047), (0.088, 0.043), (0.06, 0.0425), (0.03, 0.0425), (0.0, 0.0425)], st, 40, loc=(0, 0.03, 0)))
    # woreczki strunowe: nierówny stosik
    rnd = random.Random(4)
    bags = []
    for k in range(7):
        bags.append(rbox('woreczek%d' % k, (0.07, 0.1, 0.0012), mat('folia', 'e6eef2', 0.15, 0.0, 0.0, 0.45), 0.0004, (0.22 + rnd.uniform(-0.01, 0.01), -0.02 + rnd.uniform(-0.012, 0.012), 0.001 + k * 0.0016), (0, 0, rnd.uniform(-0.25, 0.25)), segs=1))
        bags.append(rbox('struna%d' % k, (0.068, 0.004, 0.0016), mat('struna', 'c8322a', 0.5), 0.0, (0.22, 0.024, 0.001 + k * 0.0016), (0, 0, 0), segs=1))
    # pojemnik z wieczkiem i łyżeczka
    p.append(rbox('pojemnik', (0.12, 0.12, 0.05), mat('pojemnik', '14161a', 0.55), 0.012, (-0.27, 0.0, 0.025), (0, 0, 0.3)))
    p.append(rbox('wieczko', (0.126, 0.126, 0.012), mat('wieczko', '2c3038', 0.5), 0.006, (-0.27, 0.0, 0.054), (0, 0, 0.3)))
    p.append(tube('lyzeczka', [(-0.14, -0.1, 0.004), (-0.19, -0.07, 0.006), (-0.24, -0.06, 0.004)], 0.003, st, 6))
    p.append(lathe('czerpak', [(0.0, 0.0), (0.012, 0.002), (0.014, 0.006)], st, 12, loc=(-0.132, -0.105, 0.002)))
    ob = join('Waga', p)
    weather([ob], 1024, 0.35, 0.6)
    join('Woreczki', bags)
    rbox('Wyswietlacz', (0.08, 0.03, 0.002), mat('lcd', '9fe6b0', 0.3, 0.0, 1.4), 0.001, (-0.035, -0.088, 0.0335), segs=1)
    text('Cyfry', '0.0 g', 0.02, mat('cyfry', '0c2a16', 0.5), (-0.035, -0.088, 0.0348), (0, 0, 0), 0.0002)
    export('dom_waga')


def kubek():
    reset()
    m = mat('fajans', 'f1eee6', 0.35)
    p = [lathe('kubek', [(0.0, 0.004), (0.03, 0.004), (0.036, 0.0), (0.04, 0.003), (0.041, 0.088), (0.039, 0.093), (0.0365, 0.09), (0.0355, 0.012), (0.0, 0.01)], m, 28)]
    p.append(tube('ucho', [(0.04, 0, 0.075), (0.066, 0, 0.07), (0.07, 0, 0.045), (0.06, 0, 0.022), (0.04, 0, 0.02)], 0.0055, m, 10))
    ob = join('TintKubek', p)
    weather([ob], 512, 0.3, 0.2, (0.3, 0.24, 0.18))
    lathe('Kawa', [(0.0, 0.07), (0.0355, 0.07)], mat('kawa', '2a1a10', 0.2), 20)
    export('dom_kubek')


def popielniczka():
    reset()
    gl = mat('szklo_dym', '6a7880', 0.08, 0.0, 0.0, 0.55)
    lathe('Popielniczka', [(0.0, 0.0), (0.056, 0.0), (0.062, 0.004), (0.066, 0.024), (0.062, 0.028), (0.054, 0.026), (0.05, 0.01), (0.0, 0.008)], gl, 32)
    p = []
    rnd = random.Random(2)
    for k in range(4):
        a = rnd.uniform(0, 6.28)
        x, y = math.cos(a) * 0.02, math.sin(a) * 0.02
        dx, dy = math.cos(a + 0.6) * 0.04, math.sin(a + 0.6) * 0.04
        p.append(tube('pet%d' % k, [(x, y, 0.012), (x + dx * 0.6, y + dy * 0.6, 0.02)], 0.0038, mat('bibulka', 'e9e4d6', 0.9), 8))
        p.append(tube('filtr%d' % k, [(x + dx * 0.6, y + dy * 0.6, 0.02), (x + dx, y + dy, 0.027)], 0.004, mat('filtr', 'c88a3a', 0.85), 8))
    p.append(lathe('popiol', [(0.0, 0.009), (0.04, 0.009), (0.03, 0.014), (0.0, 0.016)], mat('popiol', '5a5854', 1.0), 14))
    join('Pety', p)
    export('dom_popielniczka')


def butelka():
    reset()
    gl = mat('szklo', 'ffffff', 0.08, 0.0, 0.0, 0.6)
    lathe('TintButelka', [(0.0, 0.004), (0.026, 0.002), (0.031, 0.008), (0.032, 0.14), (0.028, 0.165), (0.014, 0.21), (0.0125, 0.245), (0.0145, 0.249), (0.0145, 0.256), (0.0125, 0.258)], gl, 28)
    p = [lathe('etykieta', [(0.0326, 0.05), (0.0326, 0.12)], mat('papier', 'e6dcc0', 0.85), 28)]
    p.append(lathe('krawatka', [(0.0152, 0.2), (0.0135, 0.235)], mat('papier', 'e6dcc0', 0.85), 20))
    ob = join('Etykieta', p)
    weather([ob], 256, 0.5, 0.2, (0.3, 0.25, 0.18))
    export('dom_butelka')


def puszka():
    reset()
    al = mat('alu', 'f2f2f2', 0.3, 0.6)
    body = lathe('TintPuszka', [(0.0, 0.003), (0.024, 0.0), (0.03, 0.006), (0.033, 0.014), (0.033, 0.108), (0.029, 0.118), (0.027, 0.119)], al, 28)
    top = [lathe('wieczko', [(0.027, 0.119), (0.028, 0.122), (0.026, 0.122), (0.025, 0.117), (0.0, 0.117)], mat('alu_top', 'c9cdd2', 0.25, 0.85), 28)]
    top.append(rbox('zawleczka', (0.012, 0.02, 0.0015), mat('alu_top', 'c9cdd2', 0.25, 0.85), 0.0005, (0, -0.004, 0.1185), segs=1))
    join('Wieczko', top)
    export('dom_puszka')


def pizza():
    reset()
    card = mat('tektura', 'c2a273', 0.92)
    p = [rbox('dno', (0.33, 0.33, 0.04), card, 0.004, (0, 0, 0.02), segs=2)]
    p.append(rbox('klapa', (0.332, 0.332, 0.004), card, 0.002, (0, 0.004, 0.043), (math.radians(-3), 0, 0), segs=1))
    for sx in (-1, 1):
        p.append(rbox('zakladka', (0.004, 0.3, 0.03), card, 0.001, (sx * 0.167, 0, 0.026), segs=1))
    ob = join('Pizza', p)
    weather([ob], 512, 0.6, 0.3, (0.35, 0.22, 0.1))
    t = [text('logo', 'PIZZA', 0.07, mat('druk', 'a8322a', 0.9), (0, 0.02, 0.0462), (0, 0, 0), 0.0003),
         text('logo2', 'NA TELEFON  24H', 0.022, mat('druk', 'a8322a', 0.9), (0, -0.06, 0.0458), (0, 0, 0), 0.0003)]
    join('Druk', t)
    export('dom_pizza')


def polka():
    """półka 1,0 m: deska na stalowych wspornikach, książki o różnych grzbietach (część pochylona), kasety, mała doniczka"""
    reset()
    wood = mat('deska', '6b5238', 0.7)
    p = [rbox('deska', (1.0, 0.2, 0.025), wood, 0.004, (0, -0.1, 0.0))]
    for sx in (-1, 1):
        p.append(profile('wspornik', [(0.0, 0.0), (0.16, 0.0), (0.16, -0.012), (0.02, -0.13), (0.0, -0.13)], 0.02, mat('stal_cz', '2a2c30', 0.5, 0.6), 0.002))
        p[-1].rotation_euler = (R90, 0, -R90)
        p[-1].location = (sx * 0.4, 0.0, -0.0125)
    ob = join('Polka', p)
    weather([ob], 512, 0.5, 0.5)
    rnd = random.Random(11)
    cols = ['7a2a2a', '2a4a6a', '3a5a3a', '8a6a2a', '4a3a5a', 'c9c4b6', '1c1c20', 'a85a2a', '2a5a5a']
    books = []
    x = -0.46
    k = 0
    while x < 0.2:
        bw = rnd.uniform(0.02, 0.05)
        bh = rnd.uniform(0.16, 0.24)
        bd = rnd.uniform(0.11, 0.15)
        lean = 0.0 if k % 7 != 5 else 0.22
        c = cols[rnd.randrange(len(cols))]
        b = rbox('ksiazka%d' % k, (bw, bd, bh), mat('okl_' + c, c, 0.75), 0.004, (x + bw / 2 + lean * bh * 0.5, -0.1, 0.0125 + bh / 2), (0, lean, 0), segs=2)
        books.append(b)
        # blok kartek i pasek tytułu na grzbiecie
        books.append(rbox('kartki%d' % k, (bw * 0.8, bd * 0.96, bh * 0.94), mat('kartki', 'e8e0cc', 0.9), 0.0, (x + bw / 2 + lean * bh * 0.5, -0.094, 0.0125 + bh / 2), (0, lean, 0), segs=1))
        books.append(rbox('tytul%d' % k, (bw * 0.7, 0.002, bh * 0.22), mat('tytul', 'd8c890', 0.6), 0.0, (x + bw / 2 + lean * bh * 0.5 + lean * 0.02, -0.1 - bd / 2, 0.0125 + bh * 0.66), (0, lean, 0), segs=1))
        x += bw + 0.004 + lean * bh
        k += 1
    for j in range(4):
        books.append(rbox('kaseta%d' % j, (0.11, 0.07, 0.017), mat('kaseta', '202226', 0.5), 0.003, (0.3, -0.1, 0.021 + j * 0.0175), (0, 0, rnd.uniform(-0.15, 0.15)), segs=1))
    bo = join('Ksiazki', books)
    weather([bo], 1024, 0.4, 0.5)
    export('dom_polka')


def aneks():
    """aneks 1,3 m: szafki dolne z frontami i uchwytami, blat, zlew z baterią, płyta z dwoma palnikami, płytki, szafki wiszące, czajnik, suszarka z talerzem"""
    reset()
    W = 1.3
    cab = mat('korpus', 'cfc9b8', 0.6)
    door = mat('front', 'ded8c8', 0.5)
    top = mat('blat', '4a4640', 0.4)
    st = mat('stal', 'b4b9be', 0.25, 0.85)
    hd = mat('uchwyt', '9a9488', 0.35, 0.7)
    p = [rbox('korpus', (W, 0.56, 0.78), cab, 0.004, (0, 0, 0.47))]
    p.append(rbox('cokol', (W, 0.5, 0.08), mat('cokol', '2a2826', 0.8), 0.002, (0, 0.03, 0.04)))
    p.append(rbox('blat', (W + 0.03, 0.6, 0.04), top, 0.01, (0, -0.01, 0.88)))
    for k in range(3):
        x = -W / 2 + (k + 0.5) * W / 3
        p.append(rbox('front%d' % k, (W / 3 - 0.012, 0.018, 0.72), door, 0.006, (x, -0.289, 0.47)))
        p.append(tube('uchwyt%d' % k, [(x + 0.12, -0.3, 0.7), (x + 0.12, -0.32, 0.68), (x + 0.12, -0.32, 0.6), (x + 0.12, -0.3, 0.58)], 0.006, hd, 8))
    # zlew wpuszczony w blat, bateria z wylewką i dwoma kurkami
    p.append(rbox('zlew_rama', (0.44, 0.38, 0.008), st, 0.004, (-0.38, -0.02, 0.902)))
    p.append(rbox('komora', (0.34, 0.28, 0.012), mat('komora', '7c8288', 0.3, 0.8), 0.006, (-0.38, -0.02, 0.899)))
    p.append(tube('wylewka', [(-0.38, 0.14, 0.9), (-0.38, 0.14, 1.08), (-0.38, 0.08, 1.14), (-0.38, 0.0, 1.1)], 0.011, st, 10))
    for sx in (-0.07, 0.07):
        p.append(lathe('kurek', [(0.0, 0.0), (0.014, 0.0), (0.016, 0.02), (0.01, 0.035), (0.0, 0.036)], st, 12, loc=(-0.38 + sx, 0.14, 0.9)))
    # płyta grzejna: dwa żeliwne palniki i pokrętła na froncie
    p.append(rbox('plyta', (0.5, 0.3, 0.02), mat('emalia', 'e6e3da', 0.35), 0.006, (0.3, -0.02, 0.91)))
    for sx in (-0.11, 0.11):
        p.append(lathe('palnik', [(0.0, 0.0), (0.075, 0.0), (0.08, 0.004), (0.078, 0.01), (0.05, 0.012), (0.02, 0.009), (0.0, 0.009)], mat('zeliwo', '1c1d20', 0.7, 0.4), 24, loc=(0.3 + sx, -0.02, 0.92)))
        kn = lathe('pokr', [(0.0, 0.0), (0.016, 0.0), (0.018, 0.012), (0.0, 0.014)], mat('pokr', '2a2c30', 0.5), 12)
        kn.rotation_euler = (R90, 0, 0)
        kn.location = (0.3 + sx, -0.175, 0.91)
        p.append(kn)
    # szafki wiszące
    p.append(rbox('gora', (W, 0.32, 0.56), cab, 0.004, (0, 0.13, 1.84)))
    for k in range(3):
        x = -W / 2 + (k + 0.5) * W / 3
        p.append(rbox('gfront%d' % k, (W / 3 - 0.012, 0.018, 0.52), door, 0.006, (x, -0.039, 1.84)))
        p.append(tube('guchwyt%d' % k, [(x + 0.12, -0.05, 1.68), (x + 0.12, -0.07, 1.66), (x + 0.12, -0.07, 1.6), (x + 0.12, -0.05, 1.58)], 0.006, hd, 8))
    # płytki nad blatem: rzędy kafli z fugą
    for r in range(4):
        for c in range(9):
            p.append(rbox('kafel', (W / 9 - 0.006, 0.008, 0.148), mat('kafel%d' % ((r * 3 + c) % 3), ('e9e6da', 'e2ded0', 'ece9e0')[(r * 3 + c) % 3], 0.2), 0.003, (-W / 2 + (c + 0.5) * W / 9, 0.284, 0.98 + r * 0.153), segs=1))
    p.append(rbox('fuga', (W, 0.004, 0.62), mat('fuga', '8a857a', 0.9), 0.0, (0, 0.288, 1.21), segs=1))
    # czajnik, suszarka z talerzami, gąbka
    p.append(lathe('czajnik', [(0.0, 0.0), (0.07, 0.0), (0.085, 0.02), (0.08, 0.1), (0.05, 0.14), (0.02, 0.15), (0.0, 0.15)], st, 24, loc=(0.52, 0.08, 0.9)))
    p.append(tube('raczka', [(0.47, 0.08, 1.02), (0.47, 0.08, 1.1), (0.57, 0.08, 1.1), (0.57, 0.08, 1.02)], 0.007, mat('bakelit', '14151a', 0.6), 8))
    p.append(tube('dziobek', [(0.6, 0.08, 0.96), (0.64, 0.08, 1.0)], 0.012, st, 8, taper=0.007))
    for k in range(3):
        t = lathe('talerz%d' % k, [(0.0, 0.0), (0.06, 0.0), (0.1, 0.012), (0.1, 0.016), (0.058, 0.006), (0.0, 0.006)], mat('talerz', 'f1eee6', 0.25), 24)
        t.rotation_euler = (0, math.radians(78), 0)
        t.location = (-0.02 + k * 0.035, 0.12, 1.01)
        p.append(t)
    p.append(rbox('suszarka', (0.2, 0.22, 0.02), mat('drut', 'c8ccd0', 0.3, 0.8), 0.006, (0.02, 0.12, 0.91)))
    p.append(rbox('gabka', (0.09, 0.06, 0.025), mat('gabka', 'd8c032', 0.95), 0.008, (-0.14, -0.2, 0.915)))
    ob = join('Aneks', p)
    weather([ob], 2048, 0.45, 0.35, (0.25, 0.2, 0.15))
    export('dom_aneks')


def lodowka():
    """stara lodówka 1,62 m: zaokrąglona skrzynia, zamrażalnik u góry, chromowane uchwyty, uszczelki, kratka, magnesy, kartka, znaczek"""
    reset()
    H = 1.62
    wh = mat('emalia', 'e6e3da', 0.32)
    p = [rbox('skrzynia', (0.58, 0.54, H), wh, 0.03, (0, 0.02, H / 2), segs=4)]
    p.append(rbox('drzwi_g', (0.57, 0.05, 0.42), wh, 0.022, (0, -0.265, H - 0.23), segs=4))
    p.append(rbox('drzwi_d', (0.57, 0.05, 1.04), wh, 0.022, (0, -0.265, 0.62), segs=4))
    for z, ln in ((H - 0.33, 0.2), (0.86, 0.36)):
        p.append(tube('uchwyt', [(-0.23, -0.29, z - ln / 2), (-0.23, -0.32, z - ln / 2 + 0.02), (-0.23, -0.32, z + ln / 2 - 0.02), (-0.23, -0.29, z + ln / 2)], 0.009, mat('chrom', 'c8ccd0', 0.15, 0.9), 10))
    p.append(rbox('uszczelka', (0.56, 0.02, 0.012), mat('uszczelka', '8a8a86', 0.8), 0.003, (0, -0.245, 1.155), segs=1))
    for k in range(9):
        p.append(rbox('kratka%d' % k, (0.5, 0.008, 0.006), mat('kratka', '3a3c40', 0.6), 0.0, (0, -0.268, 0.03 + k * 0.009), segs=1))
    p.append(rbox('stopa', (0.56, 0.5, 0.02), mat('kratka', '3a3c40', 0.6), 0.004, (0, 0.02, 0.01)))
    ob = join('Lodowka', p)
    weather([ob], 1024, 0.4, 0.4, (0.3, 0.26, 0.18))
    d = []
    for k, c in enumerate(('c8322a', '2a6ac8', 'e8c22a')):
        m = lathe('magnes%d' % k, [(0.0, 0.0), (0.022, 0.0), (0.022, 0.006), (0.0, 0.008)], mat('magnes%d' % k, c, 0.5), 14)
        m.rotation_euler = (R90, 0, 0)
        m.location = (0.05 + k * 0.08, -0.291, H - 0.12 - k * 0.07)
        d.append(m)
    d.append(rbox('kartka', (0.16, 0.003, 0.2), mat('kartka', 'e8e2cf', 0.95), 0.0, (0.14, -0.2915, 0.82), (0, -0.06, 0), segs=1))
    d.append(text('znaczek', 'POLAR', 0.035, mat('chrom', 'c8ccd0', 0.15, 0.9), (0.16, -0.292, H - 0.4), (R90, 0, 0), 0.002))
    join('Drobiazgi', d)
    export('dom_lodowka')


def lampy():
    """trzy lampy sufitowe (punkt zaczepienia w 0,0,0, wiszą w dół): klosz, goła żarówka, świetlówka"""
    for kind in ('klosz', 'zarowka', 'swietlowka'):
        reset()
        p = []
        if kind == 'swietlowka':
            p.append(rbox('oprawa', (1.24, 0.14, 0.05), mat('oprawa', 'c8c8c4', 0.5, 0.3), 0.012, (0, 0, -0.025)))
            for sx in (-1, 1):
                p.append(rbox('koncowka', (0.03, 0.06, 0.05), mat('koncowka', '8a8a86', 0.6), 0.004, (sx * 0.6, 0, -0.07)))
            ob = join('Oprawa', p)
            weather([ob], 512, 0.5, 0.4)
            t = lathe('Swiatlo', [(0.017, -0.58), (0.017, 0.58)], mat('rura', 'ffffff', 0.4, 0.0, 4.0), 12)
            t.rotation_euler = (0, R90, 0)
            t.location = (0, 0, -0.07)
        else:
            p.append(lathe('rozeta', [(0.0, 0.0), (0.05, 0.0), (0.05, -0.012), (0.02, -0.03), (0.0, -0.03)], mat('rozeta', 'd8d4c8', 0.7), 16))
            p.append(tube('kabel', [(0, 0, -0.03), (0.004, 0, -0.2), (0, 0, -0.34)], 0.004, mat('kabel', '1a1a1a', 0.8), 6))
            p.append(lathe('oprawka', [(0.0, -0.33), (0.018, -0.33), (0.02, -0.34), (0.02, -0.375), (0.016, -0.38)], mat('oprawka', '2a2622', 0.6), 14))
            if kind == 'klosz':
                # klosz z materiału: stożek z rantami i trzema drutami do oprawki
                p.append(lathe('klosz', [(0.085, -0.29), (0.09, -0.292), (0.235, -0.47), (0.24, -0.475), (0.232, -0.476), (0.088, -0.298)], mat('abazur', 'c9b98f', 0.9, 0.0, 0.3), 32))
                for k in range(3):
                    a = k * 2.094
                    p.append(tube('drut%d' % k, [(0.018, 0, -0.35), (math.cos(a) * 0.088, math.sin(a) * 0.088, -0.3)], 0.0025, mat('drut', '6a6a66', 0.5, 0.6), 4))
            ob = join('Lampa', p)
            weather([ob], 512, 0.4, 0.3)
            lathe('Swiatlo', [(0.0, -0.375), (0.012, -0.38), (0.03, -0.41), (0.035, -0.435), (0.028, -0.46), (0.0, -0.468)], mat('zarowka', 'ffffff', 0.3, 0.0, 5.0), 16)
        export('dom_lampa_' + kind)


def buty():
    """para adidasów: podeszwa, cholewka, nosek, język, sznurówki, trzy paski"""
    reset()
    for sx in (-1, 1):
        g = empty('but%d' % sx, (sx * 0.07, 0, 0))
        g.rotation_euler = (0, 0, sx * 0.14)
        sole = [rbox('podeszwa', (0.1, 0.28, 0.025), mat('podeszwa', 'e2ded0', 0.8), 0.01, (0, 0, 0.0125), segs=3)]
        join('Podeszwa%d' % sx, sole, g)
        up = [rbox('przod', (0.094, 0.16, 0.05), mat('skora', 'f2f2f2', 0.75), 0.022, (0, -0.055, 0.045), segs=4)]
        up.append(rbox('pieta', (0.09, 0.13, 0.085), mat('skora', 'f2f2f2', 0.75), 0.03, (0, 0.07, 0.062), segs=4))
        up.append(rbox('jezyk', (0.05, 0.08, 0.03), mat('skora', 'f2f2f2', 0.75), 0.012, (0, 0.0, 0.085), (math.radians(-25), 0, 0), segs=3))
        t = join('TintBut%d' % sx, up, g)
        lace = []
        for k in range(4):
            lace.append(tube('sznur%d' % k, [(-0.03, -0.05 + k * 0.022, 0.07 + k * 0.008), (0.03, -0.04 + k * 0.022, 0.072 + k * 0.008)], 0.003, mat('sznurek', 'f1eee6', 0.9), 6))
        for k in range(3):
            lace.append(rbox('pasek%d' % k, (0.002, 0.012, 0.05), mat('pasek', 'f1eee6', 0.8), 0.0, (sx * 0.0475, 0.0 + k * 0.022, 0.05), (math.radians(-28), 0, 0), segs=1))
        join('Dodatki%d' % sx, lace, g)
    export('dom_buty')


def wieszak():
    """deska z czterema hakami, na jednym kurtka z kapturem (barwiona w grze)"""
    reset()
    p = [rbox('deska', (0.6, 0.022, 0.08), mat('deska', '6b5238', 0.7), 0.006, (0, -0.011, 0))]
    for k in range(4):
        x = -0.22 + k * 0.15
        p.append(tube('hak%d' % k, [(x, -0.02, 0.0), (x, -0.07, -0.01), (x, -0.08, 0.02)], 0.005, mat('hak', 'b8b0a0', 0.35, 0.7), 8))
    ob = join('Wieszak', p)
    weather([ob], 512, 0.5, 0.5)

    def fold(u, v):
        return (0.0, -0.035 * math.sin(u * math.pi) - 0.012 * math.sin(u * 14.0 + v * 3.0) * (1.0 - v * 0.5), 0.0)
    j = [sheet('korpus', 0.4, 0.66, 14, 8, fold, mat('ortalion', 'f0f0f0', 0.7))]
    j[0].location = (-0.07, -0.085, -0.74)
    for sx in (-1, 1):
        j.append(tube('rekaw', [(-0.07 + sx * 0.2, -0.08, -0.1), (-0.07 + sx * 0.25, -0.085, -0.4), (-0.07 + sx * 0.24, -0.08, -0.68)], 0.05, mat('ortalion', 'f0f0f0', 0.7), 10, taper=0.04))
    j.append(lathe('kaptur', [(0.0, 0.0), (0.09, -0.02), (0.11, -0.09), (0.08, -0.16), (0.0, -0.18)], mat('ortalion', 'f0f0f0', 0.7), 16, loc=(-0.07, -0.1, 0.04)))
    jo = join('TintKurtka', j)
    weather([jo], 512, 0.35, 0.1, (0.4, 0.4, 0.4))
    rbox('Zamek', (0.012, 0.004, 0.6), mat('zamek', '8a8f96', 0.4, 0.7), 0.0, (-0.07, -0.123, -0.42), segs=1)
    export('dom_wieszak')


def posciel():
    """materac z lamówką, skotłowana kołdra i zgnieciona poduszka (środek łóżka w 0,0; góra materaca na 0,5 m)"""
    reset()
    p = [rbox('materac', (0.84, 1.86, 0.16), mat('materac', 'b9b4a6', 0.95), 0.04, (0, 0, 0.42), segs=4)]
    for z in (0.36, 0.48):
        p.append(rbox('lamowka', (0.845, 1.865, 0.008), mat('lamowka', '8a8474', 0.9), 0.003, (0, 0, z), segs=1))
    ob = join('Materac', p)
    weather([ob], 1024, 0.6, 0.2, (0.3, 0.26, 0.2))

    def duvet(u, v):
        bump = 0.035 * math.sin(u * 9.0 + v * 4.0) * math.sin(v * 7.0 + 1.0) + 0.02 * math.sin(u * 17.0 - v * 11.0)
        edge = -0.1 * (abs(u - 0.5) * 2.0) ** 4
        return (0.0, 0.0, 0.0), bump + edge
    # kołdra leży: budujemy arkusz w poziomie (X × Y) z wybrzuszeniami w Z
    import bmesh as _bm
    bm = _bm.new()
    nx, ny = 26, 30
    rows = []
    for j in range(ny + 1):
        row = []
        for i in range(nx + 1):
            u, v = i / nx, j / ny
            _, dz = duvet(u, v)
            row.append(bm.verts.new((-0.44 + u * 0.88, -0.3 + v * 1.2 + 0.03 * math.sin(u * 6.0), 0.54 + dz)))
        rows.append(row)
    for j in range(ny):
        for i in range(nx):
            bm.faces.new((rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]))
    me = bpy.data.meshes.new('Koldra')
    bm.to_mesh(me)
    bm.free()
    ko = bpy.data.objects.new('Koldra', me)
    bpy.context.scene.collection.objects.link(ko)
    me.materials.append(mat('poszwa', '3d4f66', 0.95))
    for f in me.polygons:
        f.use_smooth = True
    sol = ko.modifiers.new('grubosc', 'SOLIDIFY')
    sol.thickness = 0.04
    weather([ko], 1024, 0.3, 0.1, (0.15, 0.18, 0.25))
    po = rbox('Poduszka', (0.56, 0.38, 0.13), mat('poszewka', 'dcd8cc', 0.95), 0.06, (0.02, -0.7, 0.55), (0.06, 0.03, 0.12), segs=5)
    weather([po], 512, 0.4, 0.1, (0.3, 0.28, 0.22))
    export('dom_posciel')


def okno():
    """okno 1,5 × 1,2 m (środek szyby w 0,0,0; pokój po stronie −Y): rama, dwa skrzydła z okuciami, klamki, parapet,
    karnisz z kółkami i dwie firanki z fałdami. Szybę i światło dokłada gra."""
    reset()
    W, H = 1.5, 1.2
    fr = mat('rama', 'e6e3da', 0.5)
    p = []
    for sx in (-1, 1):
        p.append(rbox('stojak', (0.07, 0.09, H + 0.1), fr, 0.012, (sx * (W / 2 + 0.01), -0.05, 0)))
    for sz in (-1, 1):
        p.append(rbox('rygiel', (W + 0.1, 0.09, 0.07), fr, 0.012, (0, -0.05, sz * (H / 2 + 0.01))))
    p.append(rbox('slupek', (0.06, 0.08, H), fr, 0.01, (0, -0.05, 0)))
    # skrzydła: węższa rama wewnątrz każdej połówki, szpros u góry
    for sx in (-1, 1):
        cx = sx * (W / 4 + 0.005)
        ww = W / 2 - 0.05
        for s2 in (-1, 1):
            p.append(rbox('skrz_pion', (0.04, 0.05, H - 0.04), fr, 0.008, (cx + s2 * ww / 2, -0.075, 0)))
            p.append(rbox('skrz_poz', (ww, 0.05, 0.04), fr, 0.008, (cx, -0.075, s2 * (H / 2 - 0.02))))
        p.append(rbox('szpros', (ww, 0.035, 0.03), fr, 0.006, (cx, -0.075, H * 0.2)))
        # klamka przy słupku
        p.append(lathe('rozetka', [(0.0, 0.0), (0.018, 0.0), (0.018, 0.006), (0.0, 0.008)], mat('klamka', 'b8b0a0', 0.3, 0.7), 12, loc=(sx * 0.06, -0.1, -H * 0.1)))
        p[-1].rotation_euler = (R90, 0, 0)
        p.append(tube('klamka', [(sx * 0.06, -0.108, -H * 0.1), (sx * 0.06, -0.125, -H * 0.1), (sx * 0.06, -0.125, -H * 0.1 - 0.09)], 0.007, mat('klamka', 'b8b0a0', 0.3, 0.7), 8))
    p.append(rbox('parapet', (W + 0.26, 0.22, 0.04), fr, 0.012, (0, -0.12, -H / 2 - 0.05)))
    ob = join('Rama', p)
    weather([ob], 1024, 0.5, 0.45, (0.28, 0.24, 0.18))
    # karnisz i firanki
    k = [tube('karnisz', [(-W / 2 - 0.25, -0.14, H / 2 + 0.16), (W / 2 + 0.25, -0.14, H / 2 + 0.16)], 0.012, mat('karnisz', '5a4a3a', 0.5, 0.3), 10)]
    for sx in (-1, 1):
        k.append(lathe('galka', [(0.0, 0.0), (0.02, 0.01), (0.024, 0.025), (0.018, 0.04), (0.0, 0.045)], mat('karnisz', '5a4a3a', 0.5, 0.3), 12))
        k[-1].rotation_euler = (0, sx * R90, 0)
        k[-1].location = (sx * (W / 2 + 0.25), -0.14, H / 2 + 0.16)
    join('Karnisz', k)

    def folds(u, v):
        amp = 0.03 * (0.4 + 0.6 * (1.0 - v))
        return (0.0, amp * math.sin(u * math.pi * 9.0) + 0.01 * math.sin(u * 23.0 + v * 5.0), 0.0)
    for sx in (-1, 1):
        f = sheet('Firanka%d' % sx, 0.46, H + 0.36, 40, 6, folds, mat('firanka', 'efe9dc', 0.95, 0.0, 0.0, 0.62))
        f.location = (sx * (W / 2 - 0.08), -0.14, -H / 2 - 0.22)
    export('dom_okno')


only = [a for a in sys.argv[sys.argv.index('--') + 1:]] if '--' in sys.argv else []
for f in (waga, kubek, popielniczka, butelka, puszka, pizza, polka, aneks, lodowka, lampy, buty, wieszak, posciel, okno):
    if not only or f.__name__ in only:
        f()
