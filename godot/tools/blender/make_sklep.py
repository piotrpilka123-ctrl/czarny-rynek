"""Sklep u Stasia: towar na półki (puszki, pudełka, słoiki, chemia — każdy model wypełnia jedną przegródkę regału 0,42 m),
gablota ze słodyczami na ladę, regał z papierosami nad ladą, chłodziarka z napojami i stojak z gazetami.
Przód = −Y, spód na z = 0."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
from lib import _finish

R90 = math.radians(90)
rnd = random.Random(41)
KOL = ['b02a1e', '1d4ed8', '15803d', 'c9a23a', 'c2410c', '7c3aed', '0f766e', 'be123c', 'e6dfc8', '374151']
white = lambda: mat('bialy', 'efeee8', 0.6)
ink = lambda: mat('tusz', '15161a', 0.6)


def _puszka(name, x, y, col, h=0.11, r=0.037):
    out = [lathe(name, [(0.0, 0.0), (r, 0.0), (r, 0.004), (r - 0.002, 0.008), (r - 0.002, h - 0.008), (r, h - 0.004), (r, h), (0.0, h)], mat('blacha', 'b8bcc0', 0.3, 0.8), 14, loc=(x, y, 0.0)),
           lathe(name + '_e', [(r + 0.0006, 0.014), (r + 0.0006, h - 0.014)], mat('et_' + col, col, 0.6), 14, loc=(x, y, 0.0)),
           lathe(name + '_p', [(r + 0.0012, h * 0.42), (r + 0.0012, h * 0.62)], white(), 14, loc=(x, y, 0.0))]
    return out


def polka_puszki():
    reset()
    p = []
    for row in range(2):
        for i in range(4):
            c = KOL[(i * 3 + row) % 5]
            p += _puszka('puszka%d%d' % (row, i), -0.15 + i * 0.1, 0.045 - row * 0.09, c)
            if row == 1 and i % 2 == 0:
                for o in _puszka('puszka_g%d' % i, -0.15 + i * 0.1 + 0.05, 0.045, c):
                    o.location.z = 0.11
                    p.append(o)
    ob = join('Puszki', p)
    weather([ob], 512, 0.3, 0.3)
    export('sklep_polka_puszki')


def _pudelko(name, x, w, h, d, col, napis, y=0.0):
    out = [rbox(name, (w, d, h), mat('p_' + col, col, 0.7, wzor='karton'), 0.004, (x, y, h / 2)),
           rbox(name + '_pole', (w * 0.8, 0.004, h * 0.34), white(), 0.002, (x, y - d / 2 - 0.001, h * 0.6)),
           rbox(name + '_pas', (w * 0.98, 0.004, h * 0.08), mat('zloty', 'd9b33a', 0.5, 0.3), 0.0, (x, y - d / 2 - 0.001, h * 0.2), segs=1)]
    t = text(name + '_t', napis, min(0.034, w * 0.72 / max(1, len(napis)) * 1.7), ink(), (x, y - d / 2 - 0.004, h * 0.6))
    return out, t


def polka_pudelka():
    reset()
    p, tx = [], []
    for i, (w, h, c, n) in enumerate(((0.11, 0.24, 'b02a1e', 'TEA'), (0.09, 0.2, '1d4ed8', 'SALT'), (0.12, 0.27, 'c9a23a', 'FLAKES'), (0.08, 0.18, '15803d', 'RICE'))):
        x = -0.165 + sum((0.11, 0.09, 0.12, 0.08)[:i]) + i * 0.012 + w / 2 - 0.03
        o, t = _pudelko('pudelko%d' % i, x, w, h, 0.07, c, n)
        p += o
        tx.append(t)
        o2, t2 = _pudelko('pudelko_t%d' % i, x, w, h, 0.07, c, n, 0.085)
        p += o2[:1]
    ob = join('Pudelka', p)
    nap = join('Napisy', tx)
    weather([ob], 512, 0.3, 0.3)
    export('sklep_polka_pudelka')


def polka_sloiki():
    reset()
    glass = mat('szklo', '6a7f6a', 0.15, 0.2)
    p = []
    zaw = ['5a7a2a', '8a2a22', 'c9a23a', '6a3a1a']
    for row in range(2):
        for i in range(4):
            x, y = -0.15 + i * 0.1, 0.04 - row * 0.09
            c = zaw[(i + row) % 4]
            p.append(lathe('sloik', [(0.0, 0.0), (0.036, 0.0), (0.038, 0.01), (0.038, 0.1), (0.03, 0.115), (0.03, 0.125), (0.0, 0.125)], mat('zaw_' + c, c, 0.25, 0.1), 14, loc=(x, y, 0.0)))
            p.append(lathe('nakretka', [(0.0, 0.125), (0.033, 0.125), (0.033, 0.14), (0.0, 0.141)], mat('nakretka', ['c0281e', 'd9b33a', 'ecece6'][(i + row) % 3], 0.4, 0.5), 14, loc=(x, y, 0.0)))
            p.append(lathe('etykieta', [(0.0388, 0.035), (0.0388, 0.085)], white(), 14, loc=(x, y, 0.0)))
    ob = join('Sloiki', p)
    weather([ob], 512, 0.25, 0.25)
    export('sklep_polka_sloiki')


def polka_chemia():
    reset()
    p = []
    for i, (c, h) in enumerate((('1d4ed8', 0.25), ('e6dfc8', 0.22), ('15803d', 0.26), ('c2410c', 0.2))):
        x = -0.15 + i * 0.1
        b = lathe('butla%d' % i, [(0.0, 0.0), (0.04, 0.0), (0.043, 0.02), (0.043, h * 0.62), (0.03, h * 0.8), (0.014, h * 0.86), (0.014, h * 0.95), (0.0, h * 0.95)], mat('pl_' + c, c, 0.4), 14, loc=(x, 0, 0.0))
        b.scale = (1.0, 0.62, 1.0)
        p.append(b)
        p.append(lathe('korek%d' % i, [(0.0, h * 0.95), (0.018, h * 0.95), (0.018, h), (0.0, h)], mat('korek', 'c0281e' if i % 2 else 'ecece6', 0.5), 10, loc=(x, 0, 0.0)))
        p.append(rbox('etyk%d' % i, (0.06, 0.004, h * 0.3), white(), 0.002, (x, -0.0275, h * 0.36)))
    for i in range(3):
        p.append(rbox('kostka%d' % i, (0.1, 0.06, 0.035), mat('mydlo', ['e8c8d0', 'c8e0d0', 'e8e0c0'][i], 0.6), 0.008, (-0.1 + i * 0.11, 0.09, 0.018)))
    ob = join('Chemia', p)
    weather([ob], 512, 0.3, 0.3)
    export('sklep_polka_chemia')


def gablota():
    """gablota na ladę 1,3 × 0,5 × 0,34 m: szklany klosz na ramce, w środku tacki z batonami, lizaki w słoju, gumy, cenówki"""
    reset()
    st = mat('ramka', '9da3a8', 0.4, 0.8)
    glass = mat('szyba', 'cfe6ee', 0.06, 0.0, 0.0, 0.22)
    W, D, H = 1.3, 0.5, 0.34
    p = [rbox('dno', (W, D, 0.02), mat('dno', 'e6e2d6', 0.6), 0.004, (0, 0, 0.01))]
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(tube('slupek', [(sx * (W / 2 - 0.01), sy * (D / 2 - 0.01), 0.02), (sx * (W / 2 - 0.01), sy * (D / 2 - 0.01), H)], 0.008, st, 6))
    for sy in (-1, 1):
        p.append(tube('rama_g', [(-W / 2 + 0.01, sy * (D / 2 - 0.01), H), (W / 2 - 0.01, sy * (D / 2 - 0.01), H)], 0.008, st, 6))
    for sx in (-1, 1):
        p.append(tube('rama_b', [(sx * (W / 2 - 0.01), -D / 2 + 0.01, H), (sx * (W / 2 - 0.01), D / 2 - 0.01, H)], 0.008, st, 6))
    # tacki: batony w trzech rzędach, obok gumy i cukierki
    for r in range(3):
        y = -0.14 + r * 0.14
        p.append(rbox('tacka%d' % r, (0.72, 0.12, 0.012), mat('tacka', '3a3d42', 0.6), 0.003, (-0.25, y, 0.03), (0.12, 0, 0)))
        for i in range(8):
            c = KOL[(i + r * 3) % 8]
            p.append(rbox('baton', (0.07, 0.1, 0.018), mat('b_' + c, c, 0.45, 0.2), 0.005, (-0.57 + i * 0.09, y, 0.048), (0.12, 0, rnd.uniform(-0.08, 0.08))))
            p.append(rbox('baton_p', (0.072, 0.03, 0.019), white(), 0.004, (-0.57 + i * 0.09, y - 0.005, 0.0484), (0.12, 0, 0)))
    jar = mat('sloj', 'd8e6e8', 0.08, 0.0, 0.0, 0.3)
    p.append(lathe('sloj', [(0.0, 0.0), (0.07, 0.0), (0.075, 0.02), (0.075, 0.17), (0.055, 0.2), (0.055, 0.215), (0.0, 0.215)], jar, 16, loc=(0.32, 0.05, 0.02)))
    for i in range(9):
        a = i * 0.7
        p.append(tube('patyk%d' % i, [(0.32 + math.cos(a) * 0.03, 0.05 + math.sin(a) * 0.03, 0.04), (0.32 + math.cos(a) * 0.05, 0.05 + math.sin(a) * 0.05, 0.25)], 0.003, white(), 4))
        l = lathe('lizak%d' % i, [(0.0, -0.02), (0.016, -0.012), (0.02, 0.0), (0.016, 0.012), (0.0, 0.02)], mat('l_' + KOL[i % 8], KOL[i % 8], 0.3), 8, loc=(0.32 + math.cos(a) * 0.05, 0.05 + math.sin(a) * 0.05, 0.265))
        p.append(l)
    for i in range(5):
        for k in range(2):
            p.append(rbox('guma', (0.07, 0.03, 0.02), mat('g_' + KOL[(i + 4) % 8], KOL[(i + 4) % 8], 0.5), 0.004, (0.47 + (i % 3) * 0.045 - 0.04, -0.15 + i * 0.045, 0.03 + k * 0.021), (0, 0, 0.3)))
    for i in range(3):
        p.append(rbox('cenowka', (0.07, 0.004, 0.035), mat('cenowka', 'f2e24a', 0.6), 0.002, (-0.5 + i * 0.3, -D / 2 + 0.03, 0.045)))
    ob = join('Gablota', p)
    szk = [rbox('szyba_g', (W - 0.02, D - 0.02, 0.006), glass, 0.0, (0, 0, H), segs=1), rbox('szyba_f', (W - 0.02, 0.006, H - 0.02), glass, 0.0, (0, -D / 2 + 0.01, H / 2 + 0.01), segs=1)]
    for sx in (-1, 1):
        szk.append(rbox('szyba_b', (0.006, D - 0.02, H - 0.02), glass, 0.0, (sx * (W / 2 - 0.01), 0, H / 2 + 0.01), segs=1))
    join('Szklo', szk)
    weather([ob], 1024, 0.25, 0.3)
    export('sklep_gablota')


def papierosy():
    """regał z papierosami nad ladą 1,6 × 0,7 m: ciemna szafka, trzy półki paczek, podświetlany pas z napisem, cennik"""
    reset()
    dark = mat('szafka', '25272b', 0.6)
    W, H, D = 1.6, 0.7, 0.14
    p = [rbox('plecy', (W, 0.02, H), dark, 0.004, (0, D / 2 - 0.01, H / 2)), rbox('gora', (W, D, 0.02), dark, 0.004, (0, 0, H - 0.01)), rbox('dol', (W, D, 0.02), dark, 0.004, (0, 0, 0.01))]
    for sx in (-1, 1):
        p.append(rbox('bok', (0.02, D, H), dark, 0.004, (sx * (W / 2 - 0.01), 0, H / 2)))
    pk = ['e9e6dc', 'b0281e', '1f3a7a', 'c9a437', '2a2c30', '2f6e5a']
    for r in range(3):
        z = 0.03 + r * 0.19
        p.append(rbox('polka%d' % r, (W - 0.04, D - 0.02, 0.012), dark, 0.002, (0, 0, z)))
        for i in range(19):
            c = pk[(i // 2 + r * 2) % 6]
            p.append(rbox('paczka', (0.062, 0.024, 0.092), mat('pk_' + c, c, 0.5), 0.004, (-W / 2 + 0.07 + i * 0.081, -0.035, z + 0.053)))
            p.append(rbox('paczka_g', (0.063, 0.025, 0.028), white() if c != 'e9e6dc' else mat('pk_g', 'b0281e', 0.5), 0.003, (-W / 2 + 0.07 + i * 0.081, -0.0355, z + 0.086)))
        p.append(rbox('listwa%d' % r, (W - 0.04, 0.006, 0.022), mat('listwa', 'ecece6', 0.6), 0.002, (0, -D / 2 + 0.004, z + 0.012)))
    ob = join('Regal', p)
    nap = [rbox('pas', (W, 0.03, 0.11), mat('pas_n', '1c2f4a', 0.5), 0.004, (0, -D / 2 + 0.0, H + 0.055)),
           text('napis', 'TOBACCO', 0.07, mat('napis_b', 'f0ece0', 0.5), (-0.45, -D / 2 - 0.018, H + 0.055)),
           text('napis2', '18+', 0.06, mat('napis_c', 'd9382c', 0.5), (0.62, -D / 2 - 0.018, H + 0.055))]
    join('Napisy', nap)
    weather([ob], 1024, 0.25, 0.3)
    export('sklep_papierosy')


def lodowka():
    """chłodziarka do napojów 0,7 × 1,2 × 1,95 m (drzwi w stronę +X w grze — tu przód = −Y): biała obudowa, przeszklone
    drzwi z uchwytem, czerwony pas z napisem, cztery półki butelek i puszek, kratka sprężarki"""
    reset()
    wh = mat('obudowa', 'dcdcd6', 0.45, 0.2)
    st = mat('stal', '9aa0a6', 0.4, 0.7)
    W, D, H = 1.2, 0.7, 1.95
    p = [rbox('tyl', (W, 0.03, H), wh, 0.006, (0, D / 2 - 0.015, H / 2)), rbox('dno', (W, D, 0.2), wh, 0.01, (0, 0, 0.1)), rbox('gora', (W, D, 0.26), wh, 0.01, (0, 0, H - 0.13)),
         rbox('wnetrze', (W - 0.08, 0.01, H - 0.5), mat('wnetrze', 'eef2f2', 0.5), 0.0, (0, D / 2 - 0.035, 0.97), segs=1)]
    for sx in (-1, 1):
        p.append(rbox('bok', (0.03, D, H), wh, 0.006, (sx * (W / 2 - 0.015), 0, H / 2)))
        p.append(rbox('rama_d', (0.05, 0.03, H - 0.5), st, 0.006, (sx * (W / 2 - 0.045), -D / 2 + 0.015, 0.97)))
    for z in (0.22, H - 0.28):
        p.append(rbox('rama_p', (W - 0.04, 0.03, 0.04), st, 0.006, (0, -D / 2 + 0.015, z)))
    p.append(tube('uchwyt', [(W / 2 - 0.1, -D / 2 - 0.03, 0.75), (W / 2 - 0.1, -D / 2 - 0.03, 1.3)], 0.014, st, 8))
    for z in (0.75, 1.3):
        p.append(tube('uchwyt_m', [(W / 2 - 0.1, -D / 2, z), (W / 2 - 0.1, -D / 2 - 0.03, z)], 0.01, st, 6))
    for i in range(7):
        p.append(rbox('kratka', (W - 0.2, 0.01, 0.012), mat('kratka', '3a3d42', 0.6), 0.0, (0, -D / 2 + 0.002, 0.05 + i * 0.022), segs=1))
    napoje = ['3a6a3a', 'c8322a', 'e8a22a', '2a6ac8', '5a3414', 'e6dfc8']
    for s in range(4):
        z = 0.24 + s * 0.37
        p.append(rbox('polka%d' % s, (W - 0.08, D - 0.1, 0.012), st, 0.002, (0, 0.0, z)))
        for row in range(2):
            for i in range(10):
                x = -W / 2 + 0.11 + i * 0.108
                y = -0.14 + row * 0.16
                c = napoje[(i + s * 2 + row) % 6]
                if s % 2 == 0:
                    b = lathe('butelka', [(0.0, 0.0), (0.034, 0.0), (0.036, 0.01), (0.036, 0.15), (0.014, 0.23), (0.014, 0.27), (0.0, 0.27)], mat('n_' + c, c, 0.25, 0.1), 10, loc=(x, y, z + 0.006))
                    p.append(b)
                    p.append(lathe('etyk', [(0.0368, 0.05), (0.0368, 0.12)], white(), 10, loc=(x, y, z + 0.006)))
                    p.append(lathe('kapsel', [(0.0, 0.27), (0.016, 0.27), (0.016, 0.283), (0.0, 0.283)], mat('kapsel', 'd9b33a', 0.4, 0.6), 8, loc=(x, y, z + 0.006)))
                else:
                    p += _puszka('puszka', x, y, c, 0.125, 0.033)
                    for o in p[-3:]:
                        o.location.z = z + 0.006
    ob = join('Chlodziarka', p)
    glass = mat('szyba', 'bfe0ee', 0.06, 0.0, 0.0, 0.2)
    rbox('Szyba', (W - 0.12, 0.01, H - 0.54), glass, 0.0, (0, -D / 2 + 0.012, 0.97), segs=1)
    nap = [rbox('pas', (W - 0.06, 0.012, 0.2), mat('pas_c', 'c0281e', 0.5), 0.004, (0, -D / 2 - 0.004, H - 0.13)),
           text('napis', 'COLD DRINKS', 0.105, mat('napis_b', 'f4f0e4', 0.5), (0, -D / 2 - 0.014, H - 0.13))]
    join('Napisy', nap)
    weather([ob], 2048, 0.25, 0.3)
    export('sklep_lodowka')


def stojak_gazety():
    reset()
    st = mat('drut', '9da3a8', 0.4, 0.8)
    p = []
    for sx in (-0.3, 0.3):
        p.append(tube('noga', [(sx, -0.14, 0.0), (sx, 0.12, 1.2)], 0.01, st, 6))
        p.append(tube('noga_t', [(sx, 0.12, 1.2), (sx, 0.26, 0.0)], 0.01, st, 6))
    gaz = ['d8d4c8', 'c9c4b6', 'e2ded2']
    for r in range(4):
        z = 0.18 + r * 0.27
        y = -0.14 + 0.26 * z / 1.2
        p.append(tube('polka', [(-0.31, y - 0.07, z), (0.31, y - 0.07, z)], 0.007, st, 5))
        p.append(tube('polka_t', [(-0.31, y - 0.01, z - 0.02), (0.31, y - 0.01, z - 0.02)], 0.007, st, 5))
        for c in range(2):
            x = -0.15 + c * 0.3
            for k in range(3):
                p.append(rbox('gazeta', (0.27, 0.006, 0.22), mat('g%d' % ((r + c + k) % 3), gaz[(r + c + k) % 3], 0.95), 0.002, (x, y - 0.04 + k * 0.007, z + 0.115), (math.radians(-12), 0, 0)))
            p.append(rbox('winieta', (0.25, 0.007, 0.045), mat('winieta', ['15161a', 'b0281e', '1d4ed8'][(r + c) % 3], 0.6), 0.0, (x, y - 0.046 + 0.021 * 0.0, z + 0.2), (math.radians(-12), 0, 0), segs=1))
            for k in range(3):
                p.append(rbox('szpalta', (0.07, 0.0065, 0.12), mat('szpalta', 'a8a59a', 0.9), 0.0, (x - 0.085 + k * 0.085, y - 0.043, z + 0.095), (math.radians(-12), 0, 0), segs=1))
    ob = join('Stojak', p)
    weather([ob], 512, 0.35, 0.4)
    export('sklep_stojak_gazety')


only = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
for fn in (polka_puszki, polka_pudelka, polka_sloiki, polka_chemia, gablota, papierosy, lodowka, stojak_gazety):
    if not only or fn.__name__ in only:
        fn()
