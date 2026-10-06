"""Laboratorium w Starej Hucie: stoły ze stali, aparatura szklana, reaktor, beczki, paletopojemnik, butle,
lampy robocze, prasa do cegieł, suszarnia, ładunek („zabezpieczenie”), wentylator, tablica, kanistry."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *

R90 = math.radians(90)


def steel():
    return mat('stal_nierdzewna', '9aa0a6', 0.34, 0.85)


def stol():
    """stół laboratoryjny 2,0 × 0,8 m: blat z rantem, półka, szuflady, stopki, śruby"""
    reset()
    st = steel()
    dark = mat('stal_ciemna', '4a4e54', 0.45, 0.8)
    W, D, H = 2.0, 0.8, 0.9
    p = [rbox('blat', (W, D, 0.04), st, 0.006, (0, 0, H - 0.02))]
    # podniesiony rant z tyłu i po bokach — rozlane odczynniki nie ściekają
    p.append(rbox('rant_t', (W, 0.02, 0.07), st, 0.004, (0, D / 2 - 0.01, H + 0.03)))
    for sx in (-1, 1):
        p.append(rbox('rant_b', (0.02, D * 0.6, 0.04), st, 0.004, (sx * (W / 2 - 0.01), D * 0.2, H + 0.015)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            x, y = sx * (W / 2 - 0.05), sy * (D / 2 - 0.05)
            p.append(rbox('noga', (0.05, 0.05, H - 0.06), dark, 0.006, (x, y, (H - 0.06) / 2 + 0.02)))
            p.append(lathe('stopka', [(0.0, 0.0), (0.035, 0.0), (0.035, 0.012), (0.012, 0.016), (0.012, 0.03)], dark, 12, loc=(x, y, 0.0)))
    p.append(rbox('polka', (W - 0.12, D - 0.12, 0.025), st, 0.004, (0, 0, 0.22)))
    for sy in (-1, 1):
        p.append(rbox('belka', (W - 0.1, 0.03, 0.05), dark, 0.004, (0, sy * (D / 2 - 0.05), H - 0.08)))
    # szafka z trzema szufladami po prawej
    p.append(rbox('szafka', (0.5, D - 0.14, 0.56), st, 0.006, (0.68, 0, 0.56)))
    for k in range(3):
        z = 0.38 + k * 0.18
        p.append(rbox('front%d' % k, (0.46, 0.012, 0.16), mat('front', 'b4b9be', 0.3, 0.85), 0.004, (0.68, -D / 2 + 0.065, z)))
        p.append(tube('uchwyt%d' % k, [(0.58, -D / 2 + 0.04, z), (0.68, -D / 2 + 0.03, z), (0.78, -D / 2 + 0.04, z)], 0.006, dark, 8))
    p += bolts('sr', [(sx * (W / 2 - 0.05), -D / 2 + 0.022, H - 0.08) for sx in (-1, 1)] + [(x, -D / 2 + 0.034, H - 0.08) for x in (-0.6, -0.2, 0.2)], dark, 0.007, 0.005, '-Y')
    ob = join('Stol', p)
    weather([ob], 1024, 0.5, 0.5, (0.12, 0.1, 0.08))
    export('lab_stol')


def _flask(name, r, neck, glass, liquid, fill, loc):
    """kolba okrągłodenna: szkło + ciecz (osobny, lekko świecący obiekt)"""
    prof = [(0.0, 0.0)] + [(math.sin(a) * r, r - math.cos(a) * r) for a in [i * math.pi / 14 for i in range(1, 13)]] + [(0.016, r * 2 - 0.004), (0.016, r * 2 + neck), (0.02, r * 2 + neck + 0.004)]
    g = lathe(name, prof, glass, 24, loc=loc)
    top = r - math.cos(math.pi * fill) * r
    lp = [(0.0, 0.004)] + [(math.sin(a) * (r - 0.004), r - math.cos(a) * (r - 0.004)) for a in [i * math.pi * fill / 8 for i in range(1, 9)]] + [(0.0, top)]
    l = lathe(name + '_c', lp, liquid, 20, loc=loc)
    return g, l


def aparatura():
    """zestaw do destylacji i krystalizacji na blat: statywy, płaszcz grzejny, kolba, chłodnica, odbieralnik, zlewki, węże"""
    reset()
    st = steel()
    dark = mat('zeliwo', '2a2c30', 0.6, 0.6)
    glass = mat('szklo', 'cfe6ee', 0.06, 0.0, 0.0, 0.22)
    amber = mat('ciecz_bursztyn', 'c8862a', 0.2, 0.0, 0.9, 0.85)
    clear = mat('ciecz_mleczna', 'e8ecef', 0.25, 0.0, 0.5, 0.9)
    green = mat('ciecz_zielona', '7fbf4a', 0.2, 0.0, 0.8, 0.85)
    hose = mat('waz', 'b8482e', 0.6)
    solid = []
    glassy = []
    liquids = []
    # dwa statywy
    for x in (-0.32, 0.42):
        solid.append(rbox('podstawa', (0.2, 0.14, 0.014), dark, 0.004, (x, 0.1, 0.007)))
        solid.append(lathe('pret', [(0.006, 0.0), (0.006, 0.72)], st, 8, loc=(x, 0.14, 0.014)))
    # płaszcz grzejny z pokrętłem i lampką
    solid.append(lathe('plaszcz', [(0.0, 0.0), (0.12, 0.0), (0.125, 0.01), (0.125, 0.1), (0.11, 0.12), (0.085, 0.12), (0.078, 0.07), (0.0, 0.05)], mat('plaszcz', 'd8d2c0', 0.7), 28, loc=(-0.32, -0.02, 0.0)))
    kn = lathe('pokretlo', [(0.0, 0.0), (0.018, 0.0), (0.02, 0.012), (0.0, 0.014)], dark, 12)
    kn.rotation_euler = (R90, 0, 0)
    kn.location = (-0.32, -0.145, 0.05)
    solid.append(kn)
    # kolba w płaszczu, nasadka i chłodnica skośnie w dół do odbieralnika
    g, l = _flask('kolba', 0.085, 0.06, glass, amber, 0.55, (-0.32, -0.02, 0.07))
    glassy.append(g)
    liquids.append(l)
    glassy.append(tube('nasadka', [(-0.32, -0.02, 0.3), (-0.32, -0.02, 0.4), (-0.26, -0.02, 0.44)], 0.014, glass, 12))
    glassy.append(tube('chlodnica_w', [(-0.26, -0.02, 0.44), (0.3, -0.02, 0.27)], 0.009, glass, 10))
    glassy.append(tube('chlodnica_z', [(-0.2, -0.02, 0.422), (0.24, -0.02, 0.288)], 0.028, glass, 14))
    glassy.append(tube('kolanko', [(0.3, -0.02, 0.27), (0.4, -0.02, 0.24), (0.42, -0.02, 0.2)], 0.009, glass, 10))
    g2, l2 = _flask('odbieralnik', 0.07, 0.04, glass, clear, 0.4, (0.42, -0.02, 0.02))
    glassy.append(g2)
    liquids.append(l2)
    solid.append(lathe('korek', [(0.0, 0.0), (0.07, 0.0), (0.075, 0.02), (0.05, 0.022), (0.0, 0.022)], mat('korek', '9a7648', 0.9), 20, loc=(0.42, -0.02, 0.0)))
    # łapy statywów i węże z wodą chłodzącą
    for x, z, tx in ((-0.32, 0.36, -0.32), (0.42, 0.33, 0.1)):
        solid.append(tube('lapa', [(x, 0.14, z), (x, 0.06, z), (tx, -0.02, z if tx == x else 0.33)], 0.005, dark, 6))
        solid.append(rbox('mufa', (0.03, 0.03, 0.03), dark, 0.004, (x, 0.14, z)))
    solid.append(tube('waz1', [(-0.16, -0.02, 0.44), (-0.14, 0.12, 0.5), (0.0, 0.3, 0.2), (0.1, 0.36, 0.0)], 0.007, hose, 8))
    solid.append(tube('waz2', [(0.2, -0.02, 0.27), (0.24, 0.1, 0.2), (0.3, 0.3, 0.06), (0.36, 0.36, 0.0)], 0.007, hose, 8))
    # zlewki, kolba stożkowa, lejek z sączkiem, termometr
    for k, (x, y, r, h, liq, f) in enumerate(((0.0, -0.2, 0.045, 0.11, green, 0.6), (0.14, -0.24, 0.035, 0.09, clear, 0.35), (-0.05, 0.22, 0.05, 0.13, amber, 0.75))):
        glassy.append(lathe('zlewka%d' % k, [(0.0, 0.0), (r, 0.0), (r, h), (r + 0.004, h + 0.003)], glass, 20, loc=(x, y, 0.0)))
        liquids.append(lathe('zlewka%d_c' % k, [(0.0, 0.003), (r - 0.003, 0.003), (r - 0.003, h * f), (0.0, h * f)], liq, 18, loc=(x, y, 0.0)))
    glassy.append(lathe('erlen', [(0.0, 0.0), (0.06, 0.0), (0.062, 0.006), (0.018, 0.13), (0.018, 0.17), (0.022, 0.173)], glass, 22, loc=(0.2, 0.2, 0.0)))
    liquids.append(lathe('erlen_c', [(0.0, 0.003), (0.057, 0.003), (0.04, 0.06), (0.0, 0.06)], green, 18, loc=(0.2, 0.2, 0.0)))
    glassy.append(lathe('lejek', [(0.006, 0.0), (0.006, 0.07), (0.055, 0.13), (0.057, 0.132)], glass, 20, loc=(0.2, 0.2, 0.15)))
    solid.append(lathe('saczek', [(0.004, 0.072), (0.05, 0.128), (0.0, 0.1)], mat('bibula', 'eee8d8', 0.95), 12, loc=(0.2, 0.2, 0.15)))
    solid.append(tube('termometr', [(-0.3, -0.02, 0.2), (-0.3, -0.02, 0.46)], 0.003, mat('termometr', 'e8e8e8', 0.2), 6))
    # taca z białym proszkiem i szpatułka
    solid.append(rbox('taca', (0.3, 0.2, 0.012), st, 0.004, (-0.62, -0.18, 0.006)))
    solid.append(rbox('proszek', (0.26, 0.16, 0.014), mat('proszek', 'f4f4f0', 0.95), 0.006, (-0.62, -0.18, 0.016)))
    solid.append(rbox('szpatulka', (0.16, 0.014, 0.003), st, 0.001, (-0.6, -0.02, 0.004), (0, 0, 0.5)))
    so = join('Sprzet', solid)
    weather([so], 1024, 0.45, 0.4)
    join('Szklo', glassy)
    join('Ciecze', liquids)
    export('lab_aparatura')


def reaktor():
    """reaktor 200 l z płaszczem: zbiornik na nogach, pokrywa na śruby, mieszadło z silnikiem, manometr, wziernik, zawory, szafka sterująca"""
    reset()
    st = steel()
    dark = mat('stal_ciemna', '3c4046', 0.5, 0.8)
    blue = mat('silnik', '2c4f7a', 0.5, 0.4)
    p = []
    # zbiornik: dennica, płaszcz z dwoma pasami, kołnierz
    p.append(lathe('zbiornik', [(0.0, 0.62), (0.2, 0.64), (0.36, 0.72), (0.42, 0.82), (0.44, 0.9), (0.44, 1.0), (0.455, 1.0), (0.455, 1.06), (0.44, 1.06), (0.44, 1.5), (0.455, 1.5), (0.455, 1.56), (0.44, 1.56),
                            (0.44, 1.72), (0.5, 1.72), (0.5, 1.76), (0.44, 1.76)], st, 40))
    p.append(lathe('pokrywa', [(0.5, 1.76), (0.5, 1.8), (0.44, 1.8), (0.4, 1.86), (0.3, 1.92), (0.12, 1.95), (0.0, 1.95)], st, 40))
    p += bolts('sr', [(math.cos(a) * 0.47, math.sin(a) * 0.47, 1.8) for a in [i * math.pi / 8 for i in range(16)]], dark, 0.014, 0.012)
    # trzy nogi z rozporami
    for k in range(3):
        a = k * 2.094 + 0.5
        x, y = math.cos(a) * 0.4, math.sin(a) * 0.4
        p.append(tube('noga%d' % k, [(x * 0.9, y * 0.9, 0.86), (x * 1.08, y * 1.08, 0.0)], 0.03, dark, 10))
        p.append(lathe('stopa%d' % k, [(0.0, 0.0), (0.07, 0.0), (0.07, 0.015), (0.0, 0.02)], dark, 12, loc=(x * 1.08, y * 1.08, 0.0)))
    for k in range(3):
        a0 = k * 2.094 + 0.5
        a1 = a0 + 2.094
        p.append(tube('rozpora%d' % k, [(math.cos(a0) * 0.41, math.sin(a0) * 0.41, 0.3), (math.cos(a1) * 0.41, math.sin(a1) * 0.41, 0.3)], 0.014, dark, 6))
    # mieszadło: silnik z żebrami, przekładnia, wał
    p.append(lathe('przekladnia', [(0.0, 1.95), (0.09, 1.95), (0.09, 2.06), (0.07, 2.08), (0.0, 2.08)], dark, 16))
    p.append(lathe('silnik', [(0.0, 2.08), (0.11, 2.08), (0.115, 2.1), (0.115, 2.36), (0.1, 2.38), (0.0, 2.38)], blue, 24))
    for k in range(12):
        a = k * math.pi / 6
        p.append(rbox('zebro%d' % k, (0.012, 0.02, 0.24), blue, 0.002, (math.cos(a) * 0.118, math.sin(a) * 0.118, 2.23), (0, 0, a + R90), segs=1))
    p.append(rbox('puszka', (0.1, 0.07, 0.08), dark, 0.008, (0.14, 0.0, 2.25)))
    # króćce na pokrywie: manometr, zawór bezpieczeństwa, wlew
    p.append(tube('kr1', [(0.26, 0.1, 1.9), (0.26, 0.1, 2.04)], 0.016, st, 10))
    gau = lathe('manometr', [(0.0, 0.0), (0.06, 0.0), (0.065, 0.006), (0.065, 0.03), (0.058, 0.036), (0.0, 0.036)], dark, 24)
    gau.rotation_euler = (R90, 0, 0)
    gau.location = (0.26, 0.085, 2.1)
    p.append(gau)
    tar = lathe('tarcza', [(0.0, 0.0), (0.055, 0.0), (0.055, 0.002)], mat('tarcza', 'f2f0e6', 0.4, 0.0, 0.3), 24)
    tar.rotation_euler = (R90, 0, 0)
    tar.location = (0.26, 0.047, 2.1)
    p.append(tar)
    p.append(rbox('wskazowka', (0.004, 0.003, 0.045), mat('czerwony', 'c8281e', 0.5, 0.0, 0.6), 0.0, (0.27, 0.044, 2.115), (0, 0.6, 0), segs=1))
    p.append(tube('kr2', [(-0.2, -0.2, 1.9), (-0.2, -0.2, 2.02), (-0.3, -0.3, 2.06)], 0.02, st, 10))
    p.append(lathe('wlew', [(0.06, 1.9), (0.06, 1.98), (0.075, 1.98), (0.075, 2.0), (0.0, 2.0)], st, 20, loc=(-0.18, 0.24, 0.0)))
    # wziernik z przodu, zawór spustowy na dole z pokrętłem, rura do kolektora
    wz = lathe('wziernik', [(0.0, 0.0), (0.09, 0.0), (0.095, 0.006), (0.095, 0.03), (0.07, 0.03), (0.07, 0.012), (0.0, 0.012)], dark, 24)
    wz.rotation_euler = (R90, 0, 0)
    wz.location = (0.0, -0.435, 1.3)
    p.append(wz)
    p += bolts('wzs', [(math.cos(a) * 0.082, -0.468, 1.3 + math.sin(a) * 0.082) for a in [i * math.pi / 4 for i in range(8)]], st, 0.007, 0.005, '-Y')
    p.append(tube('spust', [(0.0, 0.0, 0.62), (0.0, 0.0, 0.46), (0.0, -0.2, 0.4), (0.0, -0.5, 0.4)], 0.028, st, 12))
    kolo = lathe('pokretlo', [(0.05, -0.006), (0.058, -0.006), (0.058, 0.006), (0.05, 0.006)], mat('czerwony', 'c8281e', 0.5), 20)
    kolo.rotation_euler = (0, R90, 0)
    kolo.location = (0.09, -0.3, 0.4)
    p.append(kolo)
    p.append(tube('trzpien', [(0.0, -0.3, 0.4), (0.09, -0.3, 0.4)], 0.008, dark, 6))
    # szafka sterująca na wysięgniku: lampki i przyciski
    p.append(tube('wysiegnik', [(0.44, 0.0, 1.3), (0.62, 0.0, 1.3)], 0.016, dark, 8))
    p.append(rbox('szafka', (0.1, 0.26, 0.36), mat('szafka', 'c9cdd2', 0.5, 0.3), 0.01, (0.68, 0.0, 1.3)))
    ob = join('Reaktor', p)
    weather([ob], 2048, 0.5, 0.5, (0.1, 0.085, 0.07))
    lights = []
    for k, (c, z) in enumerate((('4ade80', 1.42), ('f0b429', 1.36), ('e5412d', 1.3))):
        l = lathe('lampka%d' % k, [(0.0, 0.0), (0.012, 0.0), (0.012, 0.006), (0.0, 0.01)], mat('lampka%d' % k, c, 0.3, 0.0, 3.0), 10)
        l.rotation_euler = (0, R90, 0)
        l.location = (0.73, -0.07, z)
        lights.append(l)
    for k in range(3):
        b = lathe('przycisk%d' % k, [(0.0, 0.0), (0.014, 0.0), (0.014, 0.008), (0.0, 0.01)], mat('przycisk', '1c1d20', 0.5), 10)
        b.rotation_euler = (0, R90, 0)
        b.location = (0.73, 0.05, 1.42 - k * 0.07)
        lights.append(b)
    join('Lampki', lights)
    okno = lathe('Szyba', [(0.0, 0.0), (0.07, 0.0)], mat('szyba', 'ffd9a0', 0.1, 0.0, 1.6, 0.6), 20)
    okno.rotation_euler = (R90, 0, 0)
    okno.location = (0.0, -0.462, 1.3)
    export('lab_reaktor')


def beczka():
    """niebieska beczka 200 l z żebrami, dwoma korkami i nalepką ostrzegawczą"""
    reset()
    blue = mat('hdpe', '1f4f8e', 0.55)
    prof = [(0.0, 0.0), (0.27, 0.0), (0.285, 0.012), (0.29, 0.04)]
    for z in (0.3, 0.6):
        prof += [(0.29, z - 0.03), (0.3, z - 0.015), (0.3, z + 0.015), (0.29, z + 0.03)]
    prof += [(0.29, 0.86), (0.285, 0.89), (0.27, 0.9), (0.265, 0.88), (0.0, 0.88)]
    p = [lathe('beczka', prof, blue, 32)]
    for x, r in ((0.16, 0.035), (-0.14, 0.022)):
        p.append(lathe('korek', [(0.0, 0.0), (r, 0.0), (r, 0.012), (r * 0.5, 0.014), (r * 0.5, 0.02), (0.0, 0.02)], mat('korek_b', '14181f', 0.6), 12, loc=(x, 0.0, 0.88)))
    lab = lathe('nalepka', [(0.2925, 0.36), (0.2925, 0.54)], mat('nalepka', 'f2e9c8', 0.8), 32)
    p.append(lab)
    ob = join('Beczka', p)
    # nalepka zajmuje tylko wycinek obwodu: resztę „zamalowuje” kolor beczki przy wypalaniu przez osobną taśmę
    p2 = [text('napis', 'ACETONE', 0.045, mat('druk', '14181f', 0.8), (0.0, -0.2945, 0.47)), text('napis2', 'FLAMMABLE', 0.028, mat('druk_cz', 'c8281e', 0.8), (0.0, -0.2945, 0.41))]
    weather([ob], 1024, 0.6, 0.45, (0.1, 0.09, 0.08))
    join('Napisy', p2)
    export('lab_beczka')


def ibc():
    """paletopojemnik 1000 l: biały zbiornik w stalowej kracie na palecie, korek i zawór"""
    reset()
    cage = mat('ocynk', '9da3a8', 0.5, 0.7)
    p = [rbox('zbiornik', (0.96, 1.16, 0.96), mat('hdpe_bialy', 'e6e4d8', 0.5, 0.0, 0.0, 1.0), 0.06, (0, 0, 0.66), segs=4)]
    p.append(rbox('ciecz', (0.9, 1.1, 0.5), mat('ciecz', 'b9c2a0', 0.4), 0.05, (0, 0, 0.44), segs=3))
    krata = []
    for z in (0.2, 0.42, 0.66, 0.9, 1.14):
        for sy in (-1, 1):
            krata.append(tube('h', [(-0.5, sy * 0.6, z), (0.5, sy * 0.6, z)], 0.011, cage, 6))
        for sx in (-1, 1):
            krata.append(tube('h', [(sx * 0.5, -0.6, z), (sx * 0.5, 0.6, z)], 0.011, cage, 6))
    for k in range(6):
        x = -0.5 + k * 0.2
        for sy in (-1, 1):
            krata.append(tube('v', [(x, sy * 0.6, 0.16), (x, sy * 0.6, 1.16)], 0.011, cage, 6))
    for k in range(7):
        y = -0.6 + k * 0.2
        for sx in (-1, 1):
            krata.append(tube('v', [(sx * 0.5, y, 0.16), (sx * 0.5, y, 1.16)], 0.011, cage, 6))
    # paleta stalowa i zawór
    for y in (-0.5, 0.0, 0.5):
        krata.append(rbox('plozy', (1.0, 0.1, 0.12), cage, 0.008, (0, y, 0.06)))
    krata.append(rbox('plyta', (1.02, 1.22, 0.03), cage, 0.006, (0, 0, 0.15)))
    ob2 = join('Krata', krata)
    weather([ob2], 1024, 0.6, 0.5)
    p.append(lathe('korek', [(0.0, 1.14), (0.11, 1.14), (0.115, 1.15), (0.115, 1.18), (0.0, 1.19)], mat('korek_cz', 'b02a20', 0.5), 20))
    zaw = lathe('zawor', [(0.0, 0.0), (0.04, 0.0), (0.04, 0.09), (0.05, 0.09), (0.05, 0.11), (0.0, 0.11)], mat('korek_cz', 'b02a20', 0.5), 14)
    zaw.rotation_euler = (R90, 0, 0)
    zaw.location = (0.0, -0.58, 0.24)
    p.append(zaw)
    ob = join('Zbiornik', p)
    weather([ob], 1024, 0.7, 0.2, (0.2, 0.18, 0.14))
    export('lab_ibc')


def butla():
    """butla z gazem technicznym z kołpakiem, zaworem i opaską; dwie sztuki przypięte łańcuchem do szyny"""
    reset()
    parts = []
    for k, (x, col) in enumerate(((-0.14, '7a1f1f'), (0.14, '2a3a5a'))):
        m = mat('butla%d' % k, col, 0.45, 0.5)
        parts.append(lathe('b%d' % k, [(0.0, 0.0), (0.1, 0.0), (0.115, 0.02), (0.115, 1.25), (0.1, 1.36), (0.06, 1.44), (0.035, 1.47), (0.035, 1.5)], m, 24, loc=(x, 0, 0)))
        parts.append(lathe('ramie%d' % k, [(0.116, 1.1), (0.116, 1.2)], mat('pas_bialy', 'e4e2d6', 0.6), 24, loc=(x, 0, 0)))
        parts.append(lathe('kolpak%d' % k, [(0.035, 1.5), (0.06, 1.5), (0.065, 1.52), (0.065, 1.62), (0.05, 1.66), (0.0, 1.67)], mat('kolpak', '2a2c30', 0.5, 0.7), 16, loc=(x, 0, 0)))
        parts.append(lathe('stopa%d' % k, [(0.118, 0.0), (0.122, 0.0), (0.122, 0.06), (0.118, 0.06)], mat('kolpak', '2a2c30', 0.5, 0.7), 24, loc=(x, 0, 0)))
    parts.append(rbox('szyna', (0.66, 0.02, 0.06), mat('szyna', '50545a', 0.5, 0.8), 0.004, (0, 0.13, 0.95)))
    parts.append(tube('lancuch', [(-0.3, 0.12, 0.95), (-0.26, -0.1, 0.93), (0.0, -0.13, 0.9), (0.26, -0.1, 0.93), (0.3, 0.12, 0.95)], 0.006, mat('szyna', '50545a', 0.5, 0.8), 6))
    ob = join('Butle', parts)
    weather([ob], 1024, 0.5, 0.8)
    export('lab_butle')


def lampa_robocza():
    """halogen budowlany na statywie: żółta głowica z kratką, trójnóg, kabel. „Glow” = świecąca szyba."""
    reset()
    yel = mat('zolty', 'd6a312', 0.5, 0.3)
    dark = mat('czarny', '1a1b1e', 0.6, 0.4)
    p = []
    for k in range(3):
        a = k * 2.094
        p.append(tube('noga%d' % k, [(0, 0, 0.75), (math.cos(a) * 0.42, math.sin(a) * 0.42, 0.0)], 0.012, dark, 8))
        p.append(tube('zastrzal%d' % k, [(0, 0, 0.4), (math.cos(a) * 0.22, math.sin(a) * 0.22, 0.36)], 0.007, dark, 6))
    p.append(tube('maszt', [(0, 0, 0.3), (0, 0, 1.55)], 0.016, dark, 10))
    p.append(lathe('zacisk', [(0.016, 0.74), (0.03, 0.74), (0.03, 0.8), (0.016, 0.8)], yel, 12))
    p.append(tube('palak', [(-0.17, 0, 1.78), (-0.17, 0, 1.56), (0.17, 0, 1.56), (0.17, 0, 1.78)], 0.009, dark, 8))
    head = [rbox('glowica', (0.3, 0.12, 0.22), yel, 0.02, (0, 0.02, 1.78), (math.radians(-12), 0, 0))]
    for k in range(7):
        head.append(rbox('zebro%d' % k, (0.012, 0.03, 0.2), yel, 0.002, (-0.12 + k * 0.04, 0.09, 1.795), (math.radians(-12), 0, 0), segs=1))
    for k in range(5):
        head.append(tube('kratka%d' % k, [(-0.14, -0.05, 1.7 + k * 0.035), (0.14, -0.05, 1.7 + k * 0.035)], 0.003, dark, 4))
    p += head
    p.append(tube('kabel', [(0.1, 0.08, 1.7), (0.16, 0.14, 1.2), (0.05, 0.06, 0.5), (0.3, 0.3, 0.02), (0.6, 0.5, 0.015)], 0.006, mat('kabel', 'c2501c', 0.7), 8))
    ob = join('Lampa', p)
    weather([ob], 1024, 0.5, 0.7)
    gl = rbox('Glow', (0.26, 0.006, 0.17), mat('halogen', 'fff0c8', 0.2, 0.0, 9.0), 0.004, (0, -0.036, 1.768), (math.radians(-12), 0, 0), segs=1)
    export('lab_lampa')


def prasa():
    """ręczna prasa hydrauliczna do cegieł: rama z ceowników, podnośnik butelkowy, forma, dźwignia, manometr"""
    reset()
    red = mat('rama', '8e2a22', 0.55, 0.4)
    st = steel()
    dark = mat('stal_ciemna', '33363b', 0.5, 0.8)
    p = []
    for sx in (-1, 1):
        p.append(rbox('slup', (0.07, 0.1, 1.5), red, 0.008, (sx * 0.3, 0, 0.75)))
        p.append(rbox('stopa', (0.09, 0.5, 0.05), red, 0.008, (sx * 0.3, 0, 0.025)))
        for z in (0.5, 0.7, 0.9, 1.1):
            p += bolts('otw', [(sx * 0.3, -0.052, z)], dark, 0.012, 0.004, '-Y')
    p.append(rbox('belka_g', (0.68, 0.12, 0.1), red, 0.008, (0, 0, 1.46)))
    p.append(rbox('stol', (0.68, 0.14, 0.08), red, 0.008, (0, 0, 0.62)))
    p.append(lathe('podnosnik', [(0.0, 1.0), (0.06, 1.0), (0.065, 1.02), (0.065, 1.38), (0.05, 1.41), (0.0, 1.41)], mat('podnosnik', '2c4f7a', 0.5, 0.4), 20))
    p.append(lathe('tlok', [(0.0, 0.82), (0.03, 0.82), (0.03, 1.0), (0.0, 1.0)], st, 14))
    p.append(rbox('stempel', (0.26, 0.13, 0.03), dark, 0.004, (0, 0, 0.805)))
    p.append(rbox('forma', (0.3, 0.17, 0.12), st, 0.006, (0, 0, 0.72)))
    p.append(tube('dzwignia', [(0.065, 0, 1.06), (0.2, -0.1, 1.1), (0.5, -0.3, 1.3)], 0.012, dark, 8))
    p.append(lathe('raczka', [(0.018, 0.0), (0.02, 0.01), (0.02, 0.11), (0.018, 0.12), (0.0, 0.12)], mat('guma', '111214', 0.9), 10, loc=(0.5, -0.3, 1.26)))
    ob = join('Prasa', p)
    weather([ob], 1024, 0.5, 0.8)
    export('lab_prasa')


def suszarnia():
    """regał suszarni: pięć tac z proszkiem na stelażu, lampa grzewcza u góry"""
    reset()
    st = steel()
    dark = mat('stal_ciemna', '4a4e54', 0.45, 0.8)
    p = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(rbox('slup', (0.035, 0.035, 1.8), dark, 0.004, (sx * 0.42, sy * 0.3, 0.9)))
    powder = []
    for k in range(5):
        z = 0.3 + k * 0.3
        for sx in (-1, 1):
            p.append(rbox('prowadnica', (0.02, 0.6, 0.02), dark, 0.002, (sx * 0.4, 0, z - 0.02)))
        p.append(rbox('taca', (0.76, 0.56, 0.02), st, 0.004, (0, 0, z)))
        for sy in (-1, 1):
            p.append(rbox('rant', (0.76, 0.012, 0.04), st, 0.003, (0, sy * 0.275, z + 0.02)))
        if k != 1:
            powder.append(rbox('proszek%d' % k, (0.7, 0.5, 0.02), mat('proszek', 'f4f4f0', 0.95), 0.008, (0, 0, z + 0.018)))
    p.append(rbox('daszek', (0.9, 0.66, 0.03), dark, 0.006, (0, 0, 1.8)))
    ob = join('Regal', p)
    weather([ob], 1024, 0.5, 0.5)
    join('Proszek', powder)
    rbox('Grzalka', (0.7, 0.06, 0.02), mat('grzalka', 'ff7a2a', 0.4, 0.0, 3.5), 0.004, (0, 0, 1.77), segs=1)
    export('lab_suszarnia')


def ladunek():
    """„zabezpieczenie”: paczki owinięte taśmą na słupie, przewody, zapalnik z czerwoną diodą i wyłącznikiem"""
    reset()
    p = []
    wrap = mat('papier', 'b8a274', 0.85)
    tape = mat('tasma', '2a2a2c', 0.6)
    for k in range(4):
        p.append(rbox('kostka%d' % k, (0.09, 0.05, 0.2), wrap, 0.008, (-0.15 + k * 0.1, 0, 0.0)))
    for z in (-0.06, 0.06):
        p.append(rbox('tasma', (0.42, 0.058, 0.025), tape, 0.004, (0, 0, z)))
    p.append(rbox('zapalnik', (0.14, 0.05, 0.09), mat('zapalnik', '202226', 0.5, 0.3), 0.006, (0, -0.045, 0.02)))
    for k, c in enumerate(('c8281e', 'e8d020', '2a52c8', '1c1c1e')):
        x = -0.15 + k * 0.1
        p.append(tube('przewod%d' % k, [(x, 0, 0.1), (x * 0.6, -0.03, 0.16), (-0.05 + k * 0.03, -0.05, 0.065)], 0.004, mat('przewod%d' % k, c, 0.6), 6))
    p.append(tube('do_sufitu', [(0.06, -0.05, 0.06), (0.2, -0.02, 0.3), (0.22, 0.0, 0.8)], 0.005, mat('przewod0', 'c8281e', 0.6), 6))
    ob = join('Ladunek', p)
    weather([ob], 512, 0.5, 0.4)
    led = lathe('Dioda', [(0.0, 0.0), (0.008, 0.0), (0.008, 0.004), (0.0, 0.008)], mat('dioda_cz', 'ff2a1a', 0.3, 0.0, 6.0), 10)
    led.rotation_euler = (R90, 0, 0)
    led.location = (0.04, -0.07, 0.04)
    export('lab_ladunek')


def wentylator():
    """wentylator kanałowy w ramie z osłoną i łopatami („Fan” obraca gra) oraz kawałek karbowanego przewodu"""
    reset()
    dark = mat('stal_ciemna', '3a3d42', 0.5, 0.8)
    st = steel()
    p = [lathe('obudowa', [(0.36, -0.14), (0.38, -0.14), (0.38, 0.14), (0.36, 0.14)], dark, 36)]
    for k in range(9):
        r = 0.04 + k * 0.04
        p.append(lathe('krata%d' % k, [(r, 0.142), (r + 0.006, 0.142), (r + 0.006, 0.148), (r, 0.148)], st, 28))
    for k in range(4):
        a = k * math.pi / 4
        p.append(tube('pret%d' % k, [(math.cos(a) * 0.37, math.sin(a) * 0.37, 0.15), (-math.cos(a) * 0.37, -math.sin(a) * 0.37, 0.15)], 0.004, st, 4))
    for sx in (-1, 1):
        p.append(rbox('lapa', (0.06, 0.06, 0.3), dark, 0.006, (sx * 0.42, 0, 0.0)))
    # karbowany przewód za wentylatorem
    prof = []
    for k in range(14):
        z = -0.14 - k * 0.06
        prof += [(0.34, z), (0.36, z - 0.02), (0.34, z - 0.04)]
    p.append(lathe('przewod', prof, mat('alu_folia', 'b5b9be', 0.3, 0.9), 28))
    ob = join('Wentylator', p)
    weather([ob], 1024, 0.6, 0.5)
    fan = empty('Fan')
    blades = [lathe('piasta', [(0.0, -0.05), (0.07, -0.05), (0.08, 0.0), (0.07, 0.05), (0.0, 0.06)], dark, 16)]
    for k in range(5):
        a = k * 2 * math.pi / 5
        b = rbox('lopata%d' % k, (0.26, 0.12, 0.008), mat('lopata', '5a5e64', 0.4, 0.8), 0.004, (math.cos(a) * 0.19, math.sin(a) * 0.19, 0.0), (0.5, 0, a), segs=2)
        blades.append(b)
    join('FanMesh', blades, fan)
    # całość stoi pionowo: oś wentylatora wzdłuż Y
    for o in bpy.context.scene.objects:
        if o.parent is None:
            o.rotation_euler = (R90, 0, 0)
            o.location.z += 0.42
    export('lab_wentylator')


def tablica():
    """biała tablica na stojaku z wzorami i rachunkiem partii (kreski markerem), magnesy, półka z markerami"""
    reset()
    alu = mat('alu', 'b9bdc2', 0.4, 0.8)
    p = [rbox('plyta', (1.4, 0.02, 0.95), mat('tablica', 'f1f1ec', 0.25), 0.004, (0, 0, 1.35))]
    for sx in (-1, 1):
        p.append(rbox('rama_b', (0.03, 0.03, 0.99), alu, 0.004, (sx * 0.7, 0, 1.35)))
        p.append(tube('noga', [(sx * 0.6, 0.0, 0.86), (sx * 0.6, 0.0, 0.04)], 0.014, alu, 8))
        p.append(rbox('stopa', (0.04, 0.5, 0.03), alu, 0.006, (sx * 0.6, 0, 0.02)))
    for z in (0.86, 1.84):
        p.append(rbox('rama_p', (1.43, 0.03, 0.03), alu, 0.004, (0, 0, z)))
    p.append(rbox('polka', (0.9, 0.06, 0.012), alu, 0.003, (0, -0.035, 0.88)))
    for k, c in enumerate(('1c1c1e', 'c8281e', '1f4f8e')):
        m = lathe('marker%d' % k, [(0.0, 0.0), (0.008, 0.0), (0.008, 0.11), (0.0, 0.12)], mat('marker%d' % k, c, 0.5), 8)
        m.rotation_euler = (0, R90, 0)
        m.location = (-0.3 + k * 0.16, -0.045, 0.895)
        p.append(m)
    ob = join('Tablica', p)
    weather([ob], 1024, 0.3, 0.2, (0.3, 0.3, 0.3))
    ink = mat('tusz', '1b2440', 0.6)
    red = mat('tusz_cz', 'b0241c', 0.6)
    t = [text('t1', 'BATCH 41', 0.085, ink, (-0.36, -0.0125, 1.72)),
         text('t2', 'C17H21NO4', 0.06, ink, (-0.36, -0.0125, 1.6)),
         text('t3', 'HCl  ->  pH 4.5', 0.05, ink, (-0.33, -0.0125, 1.5)),
         text('t4', 'DRY 6h / 40C', 0.05, ink, (-0.36, -0.0125, 1.4)),
         text('t5', '500 g  @  94%', 0.07, red, (0.34, -0.0125, 1.66)),
         text('t6', 'WIKTOR  06:00', 0.06, red, (0.34, -0.0125, 1.54)),
         text('t7', 'NO PHONES', 0.05, ink, (0.36, -0.0125, 1.1)),
         text('t8', 'x x x x  x x x x  x x', 0.05, ink, (-0.3, -0.0125, 1.12))]
    # sześciokąt wzoru i podkreślenia
    hexp = [(0.3 + math.cos(a) * 0.1, -0.0125, 1.33 + math.sin(a) * 0.1) for a in [i * math.pi / 3 for i in range(7)]]
    for i in range(6):
        t.append(tube('hex%d' % i, [hexp[i], hexp[i + 1]], 0.004, ink, 4))
    t.append(tube('podkr', [(0.08, -0.0125, 1.6), (0.6, -0.0125, 1.595)], 0.004, red, 4))
    join('Pismo', t)
    export('lab_tablica')


def kanistry():
    """trzy kanistry 20 l (dwa stojące, jeden przewrócony) z żebrowaniem X i korkami"""
    reset()
    p = []
    for k, (x, y, rot, col) in enumerate(((0.0, 0.0, (0, 0, 0.1), '5a6a3a'), (0.4, 0.05, (0, 0, -0.3), 'b02a20'), (0.2, -0.45, (R90, 0, 0.7), '2c4f7a'))):
        m = mat('kanister%d' % k, col, 0.5, 0.3)
        g = empty('k%d' % k, (x, y, 0.0))
        b = [rbox('korpus', (0.34, 0.16, 0.44), m, 0.03, (0, 0, 0.23), segs=4, parent=None)]
        # wytłoczenie w kształcie X po obu stronach
        for sy in (-1, 1):
            for a in (0.75, -0.75):
                b.append(rbox('x', (0.3, 0.012, 0.03), m, 0.004, (0, sy * 0.082, 0.23), (0, a, 0), segs=1))
        b.append(tube('uchwyt', [(-0.1, 0, 0.44), (-0.08, 0, 0.5), (0.04, 0, 0.5), (0.06, 0, 0.44)], 0.012, m, 8))
        b.append(lathe('wlew', [(0.022, 0.0), (0.022, 0.05), (0.03, 0.05), (0.03, 0.075), (0.0, 0.08)], mat('korek_b', '14181f', 0.6), 12, loc=(0.12, 0, 0.44)))
        ob = join('Kanister%d' % k, b, g)
        g.rotation_euler = rot
        if k == 2:
            g.location.z = 0.08
    weather([o for o in bpy.context.scene.objects if o.type == 'MESH'], 512, 0.55, 0.8)
    export('lab_kanistry')


only = [a for a in sys.argv[sys.argv.index('--') + 1:]] if '--' in sys.argv else []
for f in (stol, aparatura, reaktor, beczka, ibc, butla, lampa_robocza, prasa, suszarnia, ladunek, wentylator, tablica, kanistry):
    if not only or f.__name__ in only:
        f()
