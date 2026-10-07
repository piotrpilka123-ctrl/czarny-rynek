"""Znaki drogowe na słupkach (ocynkowana rura 60 mm, tarcza z odgiętym rantem, obejmy z tyłu):
przejście dla pieszych, STOP, ustąp pierwszeństwa, ograniczenie 40, ślepa ulica, zakaz zatrzymywania
oraz tabliczki z nazwami ulic. Tarcza patrzy na −Y, słupek stoi w (0, 0), spód na z = 0."""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
from lib import _finish

R90 = math.radians(90)


def _ngon(n, r, rot=0.0):
    return [(math.cos(rot + i * 2 * math.pi / n) * r, math.sin(rot + i * 2 * math.pi / n) * r) for i in range(n)]


def _plate(name, pts, material, z, y=-0.045, depth=0.012):
    """płaska tarcza z punktów (x, z względem środka) — stoi pionowo, przodem do −Y"""
    ob = profile(name, [(x, zz + z) for (x, zz) in pts], depth, material, 0.002)
    ob.location = (0, y, 0)
    return ob


def _slupek(h, st, con):
    p = [tube('slupek', [(0, 0, 0.0), (0, 0, h)], 0.03, st, 10),
         lathe('kapturek', [(0.0, 0.0), (0.033, 0.0), (0.033, 0.015), (0.0, 0.025)], st, 10, loc=(0, 0, h)),
         rbox('stopa', (0.26, 0.26, 0.05), con, 0.01, (0, 0, 0.02))]
    return p


def _obejmy(z, st):
    return [rbox('obejma', (0.1, 0.05, 0.035), st, 0.006, (0, -0.012, z + dz)) for dz in (-0.14, 0.14)]


def znak(nazwa, rodzaj, napis=''):
    reset()
    st = mat('ocynk', '9da3a8', 0.4, 0.8)
    con = mat('beton', '8e8a80', 0.92, wzor='beton')
    back = mat('tyl', '8d9296', 0.5, 0.6)
    white = mat('bialy', 'ecece6', 0.45)
    red = mat('czerwony', 'c0281e', 0.45)
    blue = mat('niebieski', '1c4f9c', 0.45)
    yel = mat('zolty', 'e8b818', 0.45)
    ink = mat('czarny', '15161a', 0.5)
    H = 2.75 if rodzaj != 'ulica' else 3.0
    zc = H - 0.42
    p = _slupek(H, st, con)
    f = []          # grafika tarczy — osobny obiekt, żeby była ostra
    if rodzaj == 'przejscie':
        sq = [(-0.3, -0.3), (0.3, -0.3), (0.3, 0.3), (-0.3, 0.3)]
        p.append(_plate('tyl', sq, back, zc, -0.036))
        f.append(_plate('tlo', sq, blue, zc, -0.046, 0.008))
        f.append(_plate('trojkat', [(-0.24, -0.2), (0.24, -0.2), (0.0, 0.24)], white, zc, -0.051, 0.006))
        # ludzik: głowa, tułów, nogi w kroku, pasy pod stopami
        head = lathe('glowa', [(0.0, 0.0), (0.032, 0.0), (0.032, 0.006), (0.0, 0.006)], ink, 12, loc=(0.01, -0.058, zc + 0.115))
        head.rotation_euler = (R90, 0, 0)
        f.append(head)
        f.append(_plate('tulow', [(-0.03, 0.07), (0.035, 0.08), (0.02, -0.03), (-0.035, -0.02)], ink, zc, -0.056, 0.005))
        f.append(_plate('noga1', [(-0.035, -0.02), (0.0, -0.025), (-0.06, -0.15), (-0.09, -0.14)], ink, zc, -0.056, 0.005))
        f.append(_plate('noga2', [(-0.01, -0.025), (0.02, -0.03), (0.075, -0.14), (0.045, -0.15)], ink, zc, -0.056, 0.005))
        f.append(_plate('reka', [(0.03, 0.07), (0.085, 0.0), (0.07, -0.01), (0.015, 0.045)], ink, zc, -0.056, 0.005))
        for i in range(4):
            f.append(_plate('pas%d' % i, [(-0.17 + i * 0.09, -0.19), (-0.13 + i * 0.09, -0.19), (-0.12 + i * 0.09, -0.16), (-0.16 + i * 0.09, -0.16)], ink, zc, -0.056, 0.005))
    elif rodzaj == 'stop':
        oc = _ngon(8, 0.33, math.pi / 8)
        p.append(_plate('tyl', oc, back, zc, -0.036))
        f.append(_plate('rant', oc, white, zc, -0.046, 0.008))
        f.append(_plate('tlo', _ngon(8, 0.3, math.pi / 8), red, zc, -0.051, 0.006))
        f.append(text('napis', 'STOP', 0.2, white, (0, -0.058, zc)))
    elif rodzaj == 'ustap':
        tr = [(-0.4, 0.23), (0.4, 0.23), (0.0, -0.46)]
        p.append(_plate('tyl', tr, back, zc, -0.036))
        f.append(_plate('rant', tr, red, zc, -0.046, 0.008))
        f.append(_plate('tlo', [(-0.29, 0.17), (0.29, 0.17), (0.0, -0.33)], yel, zc, -0.051, 0.006))
    elif rodzaj in ('40', 'zakaz'):
        ci = _ngon(28, 0.3)
        p.append(_plate('tyl', ci, back, zc, -0.036))
        f.append(_plate('rant', ci, red, zc, -0.046, 0.008))
        if rodzaj == '40':
            f.append(_plate('tlo', _ngon(28, 0.235), white, zc, -0.051, 0.006))
            f.append(text('napis', '40', 0.26, ink, (0, -0.058, zc)))
        else:
            f.append(_plate('tlo', _ngon(28, 0.235), blue, zc, -0.051, 0.006))
            for a in (math.radians(45), math.radians(-45)):
                x = rbox('krzyz', (0.52, 0.006, 0.055), red, 0.0, (0, -0.056, zc), (0, a, 0), segs=1)
                f.append(x)
    elif rodzaj == 'slepa':
        sq = [(-0.3, -0.3), (0.3, -0.3), (0.3, 0.3), (-0.3, 0.3)]
        p.append(_plate('tyl', sq, back, zc, -0.036))
        f.append(_plate('tlo', sq, blue, zc, -0.046, 0.008))
        f.append(rbox('trzon', (0.085, 0.006, 0.36), white, 0.0, (0, -0.053, zc - 0.08), segs=1))
        f.append(rbox('belka', (0.26, 0.006, 0.085), red, 0.0, (0, -0.054, zc + 0.14), segs=1))
    elif rodzaj == 'ulica':
        # dwie tabliczki pod kątem prostym na jednym słupku
        zc = H - 0.2
        for i, txt in enumerate(napis.split('|')):
            w = max(0.9, 0.105 * len(txt) + 0.2)
            pl = rbox('tabliczka%d' % i, (w, 0.014, 0.2), blue, 0.004, (w / 2 + 0.04, 0.0, zc - i * 0.24))
            t = text('nazwa%d' % i, txt, 0.11, white, (w / 2 + 0.04, -0.009, zc - i * 0.24))
            t2 = text('nazwa_t%d' % i, txt, 0.11, white, (w / 2 + 0.04, 0.009, zc - i * 0.24), rot=(R90, 0, math.radians(180)))
            grp = join('Tab%d' % i, [pl, t, t2])
            grp.rotation_euler = (0, 0, i * R90)
            f.append(grp)
            p.append(rbox('uchwyt%d' % i, (0.07, 0.07, 0.16), st, 0.006, (0, 0, zc - i * 0.24)))
    if rodzaj != 'ulica':
        p += _obejmy(zc, st)
    slup = join('Slupek', p)
    graf = join('Tarcza', f)
    weather([slup], 512, 0.5, 0.6, (0.1, 0.09, 0.08))
    weather([graf], 512, 0.3, 0.45, (0.12, 0.1, 0.08))
    export(nazwa)


LISTA = {'znak_przejscie': ('przejscie', ''), 'znak_stop': ('stop', ''), 'znak_ustap': ('ustap', ''), 'znak_40': ('40', ''), 'znak_zakaz': ('zakaz', ''), 'znak_slepa': ('slepa', ''),
         'znak_ulica_a': ('ulica', 'HUTNICZA ST|ROBOTNICZA ST'), 'znak_ulica_b': ('ulica', 'HUTNICZA ST|ESTATE RD'), 'znak_ulica_c': ('ulica', 'HUTNICZA ST|STEELWORKS RD'), 'znak_ulica_d': ('ulica', 'ESTATE RD|BLOCKS 5-13')}
only = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
for n, (r, t) in LISTA.items():
    if not only or n in only:
        znak(n, r, t)
