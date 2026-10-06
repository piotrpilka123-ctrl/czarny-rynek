"""Linie pod napięciem przy torach: słup linii napowietrznej (ul_slup_en) i słup trakcyjny z wysięgnikiem (ul_slup_trak).
Przewody rozpina gra (world.gd). Linia biegnie wzdłuż osi Y modelu, poprzeczniki wzdłuż X."""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *

R90 = math.radians(90)


def izolator(name, loc, porc, st, h=0.2, r=0.05):
    """izolator stojący: stalowy trzon i porcelanowe klosze"""
    x, y, z = loc
    prof = [(0.012, z), (0.012, z + 0.05)]
    n = 4
    for k in range(n):
        z0 = z + 0.05 + k * (h - 0.05) / n
        dz = (h - 0.05) / n
        rr = r * (1.0 - 0.12 * k)
        prof += [(rr * 0.45, z0), (rr, z0 + dz * 0.25), (rr * 0.92, z0 + dz * 0.55), (rr * 0.42, z0 + dz * 0.8)]
    prof += [(r * 0.35, z + h), (r * 0.4, z + h + 0.02), (0.0, z + h + 0.025)]
    return lathe(name, prof, porc, 10, loc=(x, y, 0))


def ul_slup_en():
    """słup linii napowietrznej 9,3 m: wirowany beton z opaskami, poprzecznik z kątownika na zastrzałach, trzy izolatory,
    uziom po słupie, tabliczka ostrzegawcza i numer"""
    reset()
    con = mat('beton', 'b0aea6', 0.9)
    st = mat('stal', '50565a', 0.5, 0.6)
    porc = mat('porcelana', '6a3a2a', 0.25)
    H = 9.3
    p = [lathe('slup', [(0.0, 0.0), (0.24, 0.0), (0.24, 0.1), (0.185, 0.16), (0.1, H), (0.0, H)], con, 12)]
    for z in (0.9, 3.2, 5.6, 7.9):
        r = 0.185 - 0.085 * z / H
        p.append(lathe('opaska', [(r - 0.002, z - 0.03), (r + 0.007, z - 0.03), (r + 0.007, z + 0.03), (r - 0.002, z + 0.03)], st, 12))
    # poprzecznik: kątownik, obejma na słupie i dwa zastrzały
    zc = 8.5
    p.append(rbox('poprzecznik', (2.0, 0.07, 0.07), st, 0.006, (0, -0.13, zc)))
    p.append(rbox('polka', (2.0, 0.07, 0.012), st, 0.003, (0, -0.1, zc + 0.04)))
    p.append(lathe('obejma', [(0.11, zc - 0.06), (0.125, zc - 0.06), (0.125, zc + 0.06), (0.11, zc + 0.06)], st, 12))
    for sx in (-1, 1):
        p.append(tube('zastrzal', [(sx * 0.82, -0.13, zc - 0.03), (sx * 0.1, -0.13, zc - 0.75)], 0.016, st, 6))
        p.append(izolator('izolator', (sx * 0.9, -0.12, zc + 0.045), porc, st))
        p += bolts('sr', [(sx * 0.9, -0.17, zc), (sx * 0.5, -0.17, zc)], st, 0.012, 0.006, 'Y')
    p.append(lathe('obejma2', [(0.105, zc - 0.82), (0.12, zc - 0.82), (0.12, zc - 0.72), (0.105, zc - 0.72)], st, 12))
    # izolator szczytowy na trzonie
    p.append(lathe('trzon', [(0.02, H - 0.05), (0.02, H + 0.12)], st, 6))
    p.append(izolator('izolator', (0, 0, H + 0.1), porc, st))
    # uziom: płaskownik po słupie do ziemi
    p.append(tube('uziom', [(0.19, 0.02, 0.0), (0.175, 0.02, 1.2), (0.14, 0.02, 4.5), (0.11, 0.02, 8.3)], 0.006, mat('ocynk', '8a9094', 0.45, 0.7), 4))
    # tabliczka ostrzegawcza i numer słupa
    yel = mat('zolty', 'd8b020', 0.6)
    blk = mat('czarny', '141416', 0.7)
    p.append(rbox('tablica', (0.26, 0.006, 0.2), yel, 0.0, (0, -0.172, 2.05), segs=1))
    p.append(text('napis', 'DANGER', 0.055, blk, (0, -0.176, 2.07)))
    p.append(text('napis2', 'HIGH VOLTAGE', 0.026, blk, (0, -0.176, 2.0)))
    p.append(rbox('ramka', (0.26, 0.008, 0.012), blk, 0.0, (0, -0.174, 2.145), segs=1))
    p.append(rbox('ramka', (0.26, 0.008, 0.012), blk, 0.0, (0, -0.174, 1.955), segs=1))
    p.append(text('numer', '17/4', 0.09, blk, (0, -0.178, 1.5)))
    # klamry do wchodzenia od 3 m w górę
    for k in range(8):
        z = 3.6 + k * 0.6
        r = 0.185 - 0.085 * z / H
        sx = 1 if k % 2 == 0 else -1
        p.append(tube('klamra', [(sx * (r - 0.01), 0, z), (sx * (r + 0.13), 0, z), (sx * (r + 0.13), 0, z + 0.03)], 0.008, st, 5))
    ob = join('Slup', p)
    weather([ob], 1024, 0.7, 0.5)
    export('ul_slup_en')


def ul_slup_trak():
    """słup trakcyjny 7,8 m: dwuteownik na betonowym fundamencie, wysięgnik rurowy z odciągiem i izolatorami,
    ramię odciągowe przewodu jezdnego; tor leży 2,58 m w stronę −X"""
    reset()
    st = mat('stal', '4c5450', 0.55, 0.6)
    con = mat('beton', 'a8a69e', 0.9)
    porc = mat('porcelana', '6a3a2a', 0.25)
    H = 7.8
    p = [rbox('fundament', (0.62, 0.62, 0.5), con, 0.03, (0, 0, 0.2))]
    p.append(rbox('stopa', (0.42, 0.42, 0.03), st, 0.004, (0, 0, 0.465)))
    p += bolts('kotwa', [(sx * 0.16, sy * 0.16, 0.48) for sx in (-1, 1) for sy in (-1, 1)], st, 0.02, 0.03, 'Z')
    # dwuteownik: dwie półki i środnik, z nakładkami
    for sy in (-1, 1):
        p.append(rbox('polka', (0.2, 0.016, H - 0.48), st, 0.003, (0, sy * 0.1, 0.48 + (H - 0.48) / 2)))
    p.append(rbox('srodnik', (0.012, 0.2, H - 0.48), st, 0.0, (0, 0, 0.48 + (H - 0.48) / 2), segs=1))
    for z in (1.2, 3.4, 5.6):
        p.append(rbox('przewiazka', (0.2, 0.2, 0.012), st, 0.0, (0, 0, z), segs=1))
    # wysięgnik: rura pozioma, odciąg ukośny od szczytu, izolatory przy słupie
    za = 6.6
    p.append(tube('wysiegnik', [(-0.1, 0, za - 0.9), (-0.6, 0, za - 0.72), (-2.7, 0, za)], 0.03, st, 8))
    p.append(tube('odciag', [(-0.1, 0, H - 0.15), (-0.55, 0, H - 0.33), (-2.58, 0, za + 0.06)], 0.012, st, 6))
    for (x, z, ang) in ((-0.35, za - 0.82, 70), (-0.34, H - 0.24, 68)):
        iz = izolator('izolator', (0, 0, 0), porc, st, 0.26, 0.055)
        iz.rotation_euler = (0, math.radians(-ang), 0)
        iz.location = (x - 0.12, 0, z + 0.04)
        p.append(iz)
    # wieszak liny nośnej i ramię odciągowe przewodu jezdnego
    p.append(rbox('uchwyt', (0.1, 0.06, 0.1), st, 0.01, (-2.58, 0, za + 0.02)))
    p.append(tube('ramie', [(-1.5, 0, za - 0.3), (-1.55, 0, 5.55), (-2.58, 0, 5.4)], 0.016, st, 6))
    p.append(rbox('zacisk', (0.06, 0.05, 0.07), st, 0.006, (-2.58, 0, 5.38)))
    # tabliczka z numerem lokaty i żółte pasy ostrzegawcze u dołu
    p.append(rbox('tabliczka', (0.16, 0.004, 0.2), mat('biala', 'dcd8cc', 0.6), 0.0, (0, -0.112, 2.3), segs=1))
    p.append(text('numer', '48\n12', 0.07, mat('czarny', '141416', 0.7), (0, -0.116, 2.3)))
    for k in range(3):
        p.append(rbox('pas', (0.204, 0.02, 0.1), mat('zolty', 'd8b020', 0.6), 0.0, (0, -0.1, 0.7 + k * 0.22), segs=1))
    ob = join('Slup', p)
    weather([ob], 1024, 0.7, 0.6)
    export('ul_slup_trak')


only = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
if not only or 'ul_slup_en' in only:
    ul_slup_en()
if not only or 'ul_slup_trak' in only:
    ul_slup_trak()
