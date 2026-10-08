"""Sprzęt do kryjówki. Układ: przód = −Y, spód na z = 0, środek mebla w (0, 0).
kryj_lab — stół laboratoryjny 2,0 × 0,9 m: blat ze stali, półka, osłona z tyłu i półka na odczynniki, czasza grzejna
z kolbą okrągłodenną, nasadka z termometrem, chłodnica na statywie z wężami, odbieralnik, mieszadło ze zlewką, cylinder,
lejek z sączkiem, butelki z odczynnikami, tacka, waga, kartony z „udrażniaczem”. Szkło jest osobnym, przezroczystym obiektem —
zawartość naczyń i żar dorysowuje gra (węzeł Glow), dlatego kolba stoi dokładnie w (−0,55; 0; 1,16), a odbieralnik w (0,2; −0,05).
Użycie: Blender -b --python make_kryjowka.py [-- nazwa…]"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *

R90 = math.radians(90)
rnd = random.Random(9)


def along(a, b, t):
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def kryj_lab():
    reset()
    W, D = 2.0, 0.9
    zt = 0.92                                   # wierzch blatu
    stal = mat('stal', 'b9bdc2', 0.38, 0.35)
    rama = mat('rama', '5a5f66', 0.5, 0.3)
    ciemny = mat('ciemny', '3a3d43', 0.55, 0.2)
    bialy = mat('bialy', 'e6e4dc', 0.5)
    karton = mat('karton', wz('a8875a', 'karton'), 0.9, wzor='karton')
    guma_c = mat('waz_c', 'b0342c', 0.6)
    guma_n = mat('waz_n', '2a5a9a', 0.6)
    plastik = mat('plastik', '3f6a8a', 0.5)
    etyk = mat('etykieta', 'ecebe4', 0.6)
    p = []
    # --- stół: blat z rantem, rama, półka, osłona tylna i wąska półka na odczynniki
    p.append(rbox('blat', (W, D, 0.04), stal, 0.006, (0, 0, zt - 0.02)))
    p.append(rbox('rant', (W, 0.02, 0.07), stal, 0.004, (0, D / 2 - 0.01, zt + 0.015)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(rbox('noga', (0.045, 0.045, zt - 0.04), rama, 0.004, (sx * (W / 2 - 0.05), sy * (D / 2 - 0.05), (zt - 0.04) / 2)))
            p.append(lathe('stopka', [(0.0, 0.0), (0.03, 0.0), (0.03, 0.012), (0.012, 0.02), (0.0, 0.02)], ciemny, 8, loc=(sx * (W / 2 - 0.05), sy * (D / 2 - 0.05), 0.0)))
        p.append(rbox('poprzeczka', (0.035, D - 0.1, 0.035), rama, 0.004, (sx * (W / 2 - 0.05), 0, 0.3)))
    for sy in (-1, 1):
        p.append(rbox('podluznica', (W - 0.1, 0.035, 0.035), rama, 0.004, (0, sy * (D / 2 - 0.05), zt - 0.07)))
    p.append(rbox('polka', (W - 0.1, D - 0.1, 0.02), rama, 0.004, (0, 0, 0.31)))
    p.append(rbox('oslona', (W, 0.015, 0.34), stal, 0.004, (0, D / 2 - 0.008, zt + 0.17)))
    for sx in (-1, 1):
        p.append(rbox('slupek', (0.03, 0.03, 0.62), rama, 0.004, (sx * (W / 2 - 0.03), D / 2 - 0.03, zt + 0.31)))
    zp = zt + 0.6
    p.append(rbox('polka_g', (W, 0.2, 0.02), stal, 0.004, (0, D / 2 - 0.1, zp)))
    p.append(rbox('polka_g_rant', (W, 0.012, 0.035), rama, 0.003, (0, D / 2 - 0.2, zp + 0.012)))
    # --- czasza grzejna: korpus z pokrętłem i lampką, gniazdo pod kolbę
    fx, fy = -0.55, 0.0
    p.append(lathe('czasza', [(0.0, 0.0), (0.17, 0.0), (0.18, 0.02), (0.18, 0.1), (0.165, 0.125), (0.13, 0.125), (0.11, 0.06), (0.0, 0.05)], bialy, 20, loc=(fx, fy, zt)))
    p.append(lathe('gniazdo', [(0.0, 0.052), (0.108, 0.062), (0.128, 0.122), (0.118, 0.122), (0.1, 0.07), (0.0, 0.06)], mat('tkanina_gn', wz('8a857c', 'tkanina'), 0.95, wzor='tkanina'), 20, loc=(fx, fy, zt)))
    kn = lathe('pokretlo', [(0.0, 0.0), (0.022, 0.0), (0.02, 0.018), (0.0, 0.018)], ciemny, 10)
    kn.rotation_euler = (R90, 0, 0)
    kn.location = (fx - 0.06, fy - 0.178, zt + 0.055)
    p.append(kn)
    # --- statywy: podstawa, pręt, łapy z mufami
    def statyw(x, y, h, lapy):
        p.append(rbox('st_podstawa', (0.16, 0.26, 0.016), ciemny, 0.004, (x, y - 0.06, zt + 0.008)))
        p.append(tube('st_pret', [(x, y, zt + 0.01), (x, y, zt + h)], 0.006, stal, 6))
        for z, tx, ty in lapy:
            p.append(rbox('mufa', (0.03, 0.03, 0.035), rama, 0.004, (x, y, z)))
            p.append(tube('lapa', [(x, y, z), (tx, ty, z)], 0.005, stal, 5))
            for a in (-1, 1):
                p.append(tube('szczeka', [(tx, ty, z), (tx + (tx - x) * 0.0 + a * 0.03, ty - 0.035 if ty < y else ty + 0.0, z), (tx + a * 0.034, ty - 0.07, z)], 0.004, stal, 4))
    statyw(fx, 0.3, 0.95, [(1.36, fx, 0.07)])
    # --- chłodnica: od nasadki w dół do odbieralnika; druga łapa trzyma ją w połowie
    a = (fx + 0.05, 0.0, 1.47)
    b = (0.1, -0.03, 1.2)
    mid = along(a, b, 0.55)
    statyw(mid[0] + 0.02, 0.3, 0.9, [(mid[2] + 0.0, mid[0], mid[1] + 0.07)])
    for t, col in ((0.16, guma_c), (0.84, guma_n)):
        q = along(a, b, t)
        p.append(tube('kroc', [q, (q[0], q[1] + 0.05, q[2] + 0.015)], 0.007, stal, 5))
        p.append(tube('waz', [(q[0], q[1] + 0.05, q[2] + 0.015), (q[0] + 0.02, q[1] + 0.16, q[2] - 0.05), (q[0] + 0.05, 0.34, zt + 0.25), (q[0] + 0.12, 0.4, zt + 0.02), (q[0] + 0.3 * (1 if t < 0.5 else -1), 0.41, zt + 0.012)], 0.0075, col, 6))
    # --- mieszadło magnetyczne ze zlewką, waga, tacka emaliowana, pudełko rękawiczek
    mx, my = 0.5, 0.2
    p.append(rbox('mieszadlo', (0.2, 0.22, 0.07), bialy, 0.012, (mx, my, zt + 0.035)))
    p.append(lathe('plyta', [(0.0, 0.0), (0.075, 0.0), (0.075, 0.008), (0.0, 0.008)], mat('plyta', 'd9d9d4', 0.3), 16, loc=(mx, my + 0.02, zt + 0.07)))
    for i in range(2):
        k = lathe('galka', [(0.0, 0.0), (0.014, 0.0), (0.012, 0.014), (0.0, 0.014)], ciemny, 8)
        k.rotation_euler = (R90, 0, 0)
        k.location = (mx - 0.045 + i * 0.09, my - 0.112, zt + 0.03)
        p.append(k)
    p.append(rbox('tacka', (0.26, 0.36, 0.012), bialy, 0.006, (0.72, -0.22, zt + 0.006)))
    p.append(rbox('tacka_rant', (0.27, 0.37, 0.006), mat('emalia_rant', '2f4a7a', 0.5), 0.004, (0.72, -0.22, zt + 0.017)))
    p.append(rbox('waga', (0.16, 0.2, 0.03), ciemny, 0.008, (0.3, -0.3, zt + 0.015)))
    p.append(rbox('waga_szalka', (0.13, 0.13, 0.006), stal, 0.003, (0.3, -0.27, zt + 0.034)))
    p.append(rbox('rekawiczki', (0.22, 0.12, 0.07), mat('pudelko', '6aa0c8', 0.6), 0.006, (-0.86, -0.3, zt + 0.035), (0, 0, 0.3)))
    # --- półka górna: butelki z odczynnikami, kanister, lejek zapasowy; pod blatem kartony
    for i in range(6):
        x = -0.85 + i * 0.17
        r = 0.04 + 0.006 * (i % 2)
        h = 0.17 + 0.03 * (i % 3)
        kol = ['5a3414', '5a3414', 'e6e4dc', '2c4a32', '5a3414', 'c9c4b6'][i]
        p.append(lathe('butelka', [(0.0, 0.0), (r, 0.0), (r, h * 0.72), (r * 0.4, h * 0.86), (r * 0.4, h), (0.0, h)], mat('odcz%d' % i, kol, 0.25), 10, loc=(x, D / 2 - 0.1, zp + 0.01)))
        p.append(lathe('nakretka', [(0.0, h), (r * 0.46, h), (r * 0.46, h + 0.022), (0.0, h + 0.022)], ciemny, 8, loc=(x, D / 2 - 0.1, zp + 0.01)))
        p.append(lathe('etykieta', [(r * 1.03, h * 0.2), (r * 1.03, h * 0.55)], etyk, 10, loc=(x, D / 2 - 0.1, zp + 0.01)))
    p.append(rbox('kanister', (0.2, 0.14, 0.26), plastik, 0.025, (0.5, D / 2 - 0.1, zp + 0.14)))
    p.append(lathe('kanister_korek', [(0.0, 0.0), (0.02, 0.0), (0.02, 0.025), (0.0, 0.025)], ciemny, 8, loc=(0.56, D / 2 - 0.1, zp + 0.27)))
    p.append(rbox('pudlo_filtrow', (0.16, 0.14, 0.1), bialy, 0.005, (0.82, D / 2 - 0.1, zp + 0.06)))
    for i, (x, rot) in enumerate(((0.5, 0.15), (0.82, -0.2))):
        p.append(rbox('karton', (0.26, 0.2, 0.3), karton, 0.006, (x, 0.2, 0.32 + 0.15), (0, 0, rot)))
        p.append(rbox('karton_nalepka', (0.18, 0.004, 0.12), mat('nalepka', 'c0392b', 0.6), 0.003, (x - math.sin(rot) * 0.101, 0.2 - math.cos(rot) * 0.101, 0.5), (0, 0, rot)))
    stol = join('Stol', p)

    # --- napisy na kartonach (osobno, bez brudu)
    napisy = []
    for x, rot in ((0.5, 0.15), (0.82, -0.2)):
        napisy.append(text('nal', 'DRAIN', 0.035, mat('nal_t', 'f4f1e6', 0.6), (x - math.sin(rot) * 0.105, 0.2 - math.cos(rot) * 0.105, 0.515), rot=(R90, 0, rot)))
        napisy.append(text('nal2', 'CLEANER', 0.026, mat('nal_t', 'f4f1e6', 0.6), (x - math.sin(rot) * 0.105, 0.2 - math.cos(rot) * 0.105, 0.47), rot=(R90, 0, rot)))
    join('Napisy', napisy)

    # --- szkło (przezroczyste, gładkie)
    g = mat('szklo', 'd4e8ee', 0.05, 0.0, 0.0, 0.26)
    s = []
    fz = 1.16
    s.append(lathe('kolba', [(0.0, -0.14), (0.06, -0.127), (0.105, -0.093), (0.134, -0.04), (0.14, 0.0), (0.134, 0.04), (0.105, 0.093), (0.06, 0.127), (0.037, 0.145), (0.035, 0.27), (0.04, 0.275), (0.04, 0.285), (0.03, 0.285)], g, 20, loc=(fx, fy, fz)))
    # nasadka destylacyjna: pion z termometrem i ramię do chłodnicy
    s.append(tube('nasadka', [(fx, fy, fz + 0.27), (fx, fy, fz + 0.4)], 0.022, g, 10))
    s.append(tube('ramie', [(fx, fy, fz + 0.33), a], 0.016, g, 8))
    s.append(tube('plaszcz', [along(a, b, 0.08), along(a, b, 0.92)], 0.034, g, 12))
    s.append(tube('rurka', [a, b], 0.011, g, 8))
    s.append(tube('przedluzacz', [b, (0.2, -0.05, 1.14)], 0.013, g, 8))
    s.append(lathe('odbieralnik', [(0.0, 0.0), (0.085, 0.0), (0.09, 0.012), (0.03, 0.15), (0.028, 0.2), (0.034, 0.205), (0.026, 0.205)], g, 16, loc=(0.2, -0.05, zt)))
    s.append(lathe('zlewka', [(0.0, 0.0), (0.06, 0.0), (0.062, 0.006), (0.062, 0.13), (0.066, 0.134), (0.058, 0.134), (0.058, 0.008), (0.0, 0.008)], g, 16, loc=(mx, my + 0.02, zt + 0.078)))
    s.append(lathe('cylinder', [(0.0, 0.0), (0.045, 0.0), (0.045, 0.012), (0.022, 0.016), (0.022, 0.24), (0.026, 0.244), (0.018, 0.244), (0.018, 0.02), (0.0, 0.02)], g, 12, loc=(0.6, -0.18 + 0.36, zt)))
    s.append(lathe('lejek', [(0.006, 0.0), (0.008, 0.09), (0.07, 0.17), (0.072, 0.17), (0.01, 0.092), (0.008, 0.0)], g, 14, loc=(-0.16, -0.26, zt + 0.02)))
    s.append(lathe('kolba_stozkowa', [(0.0, 0.0), (0.07, 0.0), (0.074, 0.01), (0.026, 0.13), (0.024, 0.17), (0.03, 0.174), (0.022, 0.174)], g, 14, loc=(-0.16, -0.26, zt - 0.0)))
    s.append(tube('bagietka', [(mx + 0.03, my + 0.0, zt + 0.09), (mx - 0.05, my + 0.07, zt + 0.26)], 0.004, g, 5))
    join('Szklo', s)
    # --- drobiazgi bez brudu: termometr, sączek, podziałki
    d = []
    d.append(tube('termometr', [(fx, fy, fz + 0.3), (fx, fy, fz + 0.52)], 0.004, mat('termometr', 'f2f0ea', 0.3), 5))
    d.append(tube('rtec', [(fx, fy, fz + 0.3), (fx, fy, fz + 0.42)], 0.0045, mat('rtec', 'c0392b', 0.4), 5))
    d.append(lathe('korek', [(0.0, 0.0), (0.024, 0.0), (0.02, 0.03), (0.0, 0.03)], mat('korek', 'b0764a', 0.8), 8, loc=(fx, fy, fz + 0.39)))
    d.append(lathe('saczek', [(0.004, 0.095), (0.064, 0.166), (0.066, 0.166), (0.006, 0.097)], mat('saczek', 'f4f1e6', 0.9), 12, loc=(-0.16, -0.26, zt + 0.02)))
    d.append(rbox('dioda', (0.012, 0.004, 0.012), mat('dioda', 'ff5a2a', 0.4, 0.0, 2.5), 0.002, (fx + 0.07, fy - 0.181, zt + 0.055)))
    d.append(rbox('wyswietlacz', (0.07, 0.004, 0.025), mat('lcd', '9fe0a8', 0.4, 0.0, 1.2), 0.002, (0.3, -0.401, zt + 0.016)))
    join('Drobiazgi', d)
    weather([stol], 2048, 0.28, 0.4, (0.13, 0.12, 0.1))
    export('kryj_lab')


def kryj_filtr():
    """filtr węglowy 0,6 × 0,6 m: bęben z siatki w białym rękawie na stojaku, wentylator kanałowy z puszką,
    karbowana rura aluminiowa do sufitu, opaski, kabel"""
    reset()
    stal = mat('stal', 'b4b8bd', 0.4, 0.3)
    rama = mat('rama', '4a4e55', 0.5, 0.3)
    ciemny = mat('ciemny', '34373d', 0.55, 0.2)
    siatka = mat('siatka', '7d8288', 0.6, 0.3)
    rekaw = mat('rekaw', wz('d9d6cc', 'tkanina'), 0.95, wzor='tkanina')
    alu = mat('alu', 'c4c7ca', 0.35, 0.4)
    p = []
    # stojak: cztery nogi, dwie obręcze
    for k in range(4):
        an = math.radians(45 + k * 90)
        x, y = math.cos(an) * 0.21, math.sin(an) * 0.21
        p.append(tube('noga', [(x * 1.25, y * 1.25, 0.0), (x, y, 0.5), (x, y, 0.62)], 0.012, rama, 6))
        p.append(lathe('stopka', [(0.0, 0.0), (0.025, 0.0), (0.02, 0.012), (0.0, 0.012)], ciemny, 8, loc=(x * 1.25, y * 1.25, 0.0)))
    for z in (0.3, 0.6):
        r = 0.21 * (1.25 - 0.25 * z / 0.5) if z < 0.5 else 0.21
        p.append(tube('obrecz', [(math.cos(i / 20 * math.tau) * r, math.sin(i / 20 * math.tau) * r, z) for i in range(21)], 0.009, rama, 5))
    # bęben filtra: siatka, rękaw wstępny z gumkami, dno
    p.append(lathe('beben', [(0.0, 0.58), (0.17, 0.58), (0.18, 0.6), (0.18, 1.16), (0.17, 1.18), (0.1, 1.18), (0.1, 1.24), (0.0, 1.24)], siatka, 20))
    p.append(lathe('rekaw', [(0.186, 0.66), (0.19, 0.7), (0.19, 1.08), (0.186, 1.12)], rekaw, 20))
    for z in (0.67, 1.11):
        p.append(tube('gumka', [(math.cos(i / 20 * math.tau) * 0.192, math.sin(i / 20 * math.tau) * 0.192, z) for i in range(21)], 0.006, ciemny, 5))
    # wentylator kanałowy z puszką i kablem
    p.append(lathe('wentylator', [(0.0, 1.24), (0.1, 1.24), (0.1, 1.28), (0.15, 1.31), (0.15, 1.46), (0.1, 1.49), (0.1, 1.53), (0.0, 1.53)], ciemny, 20))
    p.append(rbox('puszka', (0.1, 0.07, 0.09), ciemny, 0.008, (0.0, -0.17, 1.385)))
    p.append(tube('kabel', [(0.03, -0.2, 1.36), (0.08, -0.26, 1.1), (0.2, -0.27, 0.4), (0.26, -0.26, 0.02), (0.32, -0.2, 0.012)], 0.006, ciemny, 5))
    for z in (1.255, 1.515):
        p.append(tube('opaska', [(math.cos(i / 20 * math.tau) * 0.104, math.sin(i / 20 * math.tau) * 0.104, z) for i in range(21)], 0.006, stal, 5))
    # karbowana rura do sufitu z kolanem przy ścianie
    pts = [(0.0, 0.0, 1.53), (0.0, 0.0, 1.9), (0.0, 0.06, 2.12), (0.0, 0.2, 2.26), (0.0, 0.3, 2.3)]
    prof = []
    n = 46
    for i in range(n + 1):
        t = i / n * (len(pts) - 1)
        k = min(int(t), len(pts) - 2)
        u = t - k
        prof.append(tuple(pts[k][j] + (pts[k + 1][j] - pts[k][j]) * u for j in range(3)))
    p.append(tube('rura', prof, 0.1, alu, 12, taper=[1.0 + 0.045 * (i % 2) for i in range(n + 1)]))
    f = join('Filtr', p)
    weather([f], 1024, 0.3, 0.4, (0.13, 0.12, 0.1))
    export('kryj_filtr')


def kryj_zbiornik():
    """zbiornik z pompą 0,75 × 0,75 m: niebieska beczka z obręczami na palecie, pokrywa z korkami, pompa z manometrem,
    rurka poziomu, zwój węża i rozdzielacz kroplujący"""
    reset()
    blekit = mat('beczka', '2a5a98', 0.45)
    blekit_c = mat('beczka_c', '214a80', 0.5)
    ciemny = mat('ciemny', '34373d', 0.55, 0.2)
    drew = mat('paleta', wz('a8875a', 'drewno'), 0.9, wzor='drewno')
    pompa = mat('pompa', 'd98a1e', 0.5)
    stal = mat('stal', 'b4b8bd', 0.4, 0.3)
    waz = mat('waz', '2f6b3a', 0.6)
    p = []
    # paleta
    for y in (-0.3, 0.0, 0.3):
        p.append(rbox('legar', (0.74, 0.09, 0.08), drew, 0.006, (0, y, 0.04)))
    for i in range(5):
        p.append(rbox('deska', (0.12, 0.74, 0.02), drew, 0.004, (-0.31 + i * 0.155, 0, 0.09)))
    z0 = 0.1
    # beczka z dwiema obręczami i pokrywą
    p.append(lathe('beczka', [(0.0, 0.0), (0.27, 0.0), (0.285, 0.02), (0.285, 0.27), (0.297, 0.285), (0.297, 0.315), (0.285, 0.33), (0.285, 0.57), (0.297, 0.585), (0.297, 0.615),
                              (0.285, 0.63), (0.285, 0.86), (0.27, 0.88), (0.0, 0.88)], blekit, 24, loc=(0, 0, z0)))
    p.append(lathe('pokrywa', [(0.0, 0.88), (0.292, 0.88), (0.296, 0.9), (0.28, 0.915), (0.0, 0.905)], blekit_c, 24, loc=(0, 0, z0)))
    for x, y in ((-0.14, 0.12), (0.16, -0.1)):
        p.append(lathe('korek', [(0.0, 0.0), (0.04, 0.0), (0.04, 0.02), (0.03, 0.03), (0.0, 0.03)], ciemny, 10, loc=(x, y, z0 + 0.905)))
    # pompa na pokrywie: silnik, głowica, manometr, przewód
    pz = z0 + 0.915
    pm = lathe('silnik', [(0.0, 0.0), (0.055, 0.0), (0.06, 0.01), (0.06, 0.17), (0.05, 0.19), (0.0, 0.19)], pompa, 14)
    pm.rotation_euler = (0, R90, 0)
    pm.location = (-0.12, -0.02, pz + 0.075)
    p.append(pm)
    p.append(rbox('podstawa_pompy', (0.24, 0.13, 0.02), ciemny, 0.004, (-0.02, -0.02, pz + 0.01)))
    p.append(rbox('glowica', (0.08, 0.1, 0.1), stal, 0.012, (0.11, -0.02, pz + 0.07)))
    mn = lathe('manometr', [(0.0, 0.0), (0.03, 0.0), (0.03, 0.02), (0.0, 0.02)], mat('manometr', 'ecebe4', 0.4), 12)
    mn.rotation_euler = (R90, 0, 0)
    mn.location = (0.11, -0.075, pz + 0.15)
    p.append(mn)
    p.append(tube('ssanie', [(0.11, -0.02, pz + 0.03), (0.11, -0.02, pz - 0.0)], 0.014, ciemny, 6))
    # rurka poziomu po boku i wąż: zwój na beczce, końcówka z rozdzielaczem na podłodze
    p.append(tube('poziom', [(0.29, -0.07, z0 + 0.06), (0.305, -0.075, z0 + 0.08), (0.305, -0.075, z0 + 0.8), (0.29, -0.07, z0 + 0.84)], 0.008, mat('rurka', 'dfe9ee', 0.2), 6))
    coil = []
    for i in range(60):
        an = i / 60 * math.tau * 3.2
        coil.append((-0.02 + math.cos(an) * (0.14 + i * 0.0006), 0.3 + 0.012 * (i // 19), z0 + 0.5 + math.sin(an) * (0.14 + i * 0.0006)))
    p.append(tube('zwoj', coil, 0.012, waz, 6))
    p.append(tube('waz', [(0.15, -0.02, pz + 0.08), (0.26, 0.0, pz + 0.05), (0.33, 0.06, z0 + 0.6), (0.34, 0.14, 0.2), (0.36, 0.26, 0.02), (0.3, 0.36, 0.014)], 0.012, waz, 6))
    p.append(rbox('rozdzielacz', (0.14, 0.035, 0.03), ciemny, 0.006, (0.26, 0.36, 0.016)))
    z = join('Zbiornik', p)
    weather([z], 1024, 0.3, 0.4, (0.13, 0.12, 0.1))
    export('kryj_zbiornik')


ALL = {'kryj_lab': kryj_lab, 'kryj_filtr': kryj_filtr, 'kryj_zbiornik': kryj_zbiornik}
only = [a for a in sys.argv[sys.argv.index('--') + 1:]] if '--' in sys.argv else []
for name, fn in ALL.items():
    if not only or name in only:
        fn()
