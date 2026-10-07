"""Boisko przed blokiem: kosz do koszykówki (boisko_kosz — tablica patrzy na −Y, słup stoi za nią, spód na z = 0,
obręcz 3,05 m nad ziemią) i piłka do kosza (boisko_pilka — pomarańczowa, z czarnymi szwami, promień 12 cm)."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
from lib import _finish

R90 = math.radians(90)


def kosz():
    reset()
    st = mat('stal', '6f767c', 0.5, 0.8)
    stc = mat('stal_c', '3a4046', 0.55, 0.7)
    bialy = mat('tablica', 'e4e2da', 0.6)
    czerw = mat('czerwony', 'b3261c', 0.55)
    pom = mat('obrecz', 'd2571a', 0.45, 0.4)
    pianka = mat('pianka', '1f4f8f', 0.8, wzor='tkanina')
    p = []
    yp = 1.25                     # słup stoi 1,25 m za licem tablicy
    # stopa na betonowym fundamencie, śruby
    p.append(rbox('fundament', (0.6, 0.6, 0.08), mat('beton', '8b8a84', 0.9, wzor='beton'), 0.01, (0, yp, 0.04)))
    p.append(rbox('stopa', (0.36, 0.36, 0.02), stc, 0.004, (0, yp, 0.09)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(lathe('sruba', [(0.0, 0.0), (0.018, 0.0), (0.018, 0.02), (0.0, 0.02)], st, 6, loc=(sx * 0.13, yp + sy * 0.13, 0.1)))
    # słup z wysięgnikiem: rura gięta do przodu, dwa zastrzały do tablicy
    p.append(tube('slup', [(0, yp, 0.09), (0, yp, 2.75), (0, yp - 0.12, 3.25), (0, yp - 0.5, 3.55), (0, 0.1, 3.55)], 0.06, st, 12))
    for sx in (-1, 1):
        p.append(tube('zastrzal', [(0, yp - 0.35, 3.5), (sx * 0.6, 0.04, 3.8)], 0.018, st, 6))
        p.append(tube('zastrzal_d', [(0, yp - 0.2, 3.3), (sx * 0.6, 0.04, 3.05)], 0.018, st, 6))
    # osłona z pianki na dole słupa (żeby nikt się nie rozbił), opaski
    p.append(lathe('oslona', [(0.0, 0.0), (0.12, 0.0), (0.125, 0.02), (0.125, 1.68), (0.12, 1.7), (0.0, 1.7)], pianka, 14, loc=(0, yp, 0.12)))
    for z in (0.35, 1.0, 1.65):
        p.append(lathe('opaska', [(0.126, 0.0), (0.129, 0.0), (0.129, 0.04), (0.126, 0.04)], mat('opaska', '15161a', 0.6), 14, loc=(0, yp, z)))
    # tablica 1,8 × 1,05 m w stalowej ramie; obrys i prostokąt nad obręczą
    zb = 2.9
    p.append(rbox('tablica', (1.8, 0.03, 1.05), bialy, 0.004, (0, 0.015, zb + 0.525)))
    for sx in (-1, 1):
        p.append(rbox('rama_b', (0.035, 0.05, 1.09), stc, 0.004, (sx * 0.9, 0.02, zb + 0.525)))
        p.append(rbox('linia_b', (0.045, 0.004, 0.97), czerw, 0.0, (sx * 0.845, -0.002, zb + 0.525), segs=1))
        p.append(rbox('kwadrat_b', (0.045, 0.004, 0.45), czerw, 0.0, (sx * 0.2725, -0.002, zb + 0.375), segs=1))
    for dz in (0.0, 1.05):
        p.append(rbox('rama_p', (1.83, 0.05, 0.035), stc, 0.004, (0, 0.02, zb + dz)))
    for dz in (0.04, 1.01):
        p.append(rbox('linia_p', (1.735, 0.004, 0.045), czerw, 0.0, (0, -0.002, zb + dz), segs=1))
    for dz in (0.15, 0.6):
        p.append(rbox('kwadrat_p', (0.59, 0.004, 0.045), czerw, 0.0, (0, -0.002, zb + dz), segs=1))
    # obręcz na wsporniku, 3,05 m nad ziemią
    zr, rr = 3.05, 0.225
    yr = -0.15 - rr
    p.append(rbox('wspornik', (0.16, 0.16, 0.012), pom, 0.003, (0, -0.075, zr - 0.006)))
    p.append(rbox('plyta', (0.2, 0.012, 0.14), pom, 0.003, (0, -0.008, zr - 0.05)))
    pts = [(math.cos(a) * rr, yr + math.sin(a) * rr, zr) for a in [i * math.tau / 28 for i in range(29)]]
    p.append(tube('obrecz', pts, 0.011, pom, 8))
    for sx in (-1, 1):
        p.append(tube('zastrzal_o', [(sx * 0.07, -0.02, zr - 0.1), (sx * 0.16, yr + 0.02, zr - 0.012)], 0.007, pom, 5))
    kosz_ob = join('Kosz', p)
    # siatka z łańcuszków: dwanaście pasm zwężających się w dół i dwa pierścienie
    s = []
    lan = mat('lancuch', 'b9bdc0', 0.4, 0.9)
    n = 12
    for i in range(n):
        a0 = i * math.tau / n
        a1 = a0 + math.tau / n * 0.5
        s.append(tube('pasmo', [(math.cos(a0) * rr, yr + math.sin(a0) * rr, zr - 0.012), (math.cos(a1) * rr * 0.82, yr + math.sin(a1) * rr * 0.82, zr - 0.16),
                                (math.cos(a0) * rr * 0.66, yr + math.sin(a0) * rr * 0.66, zr - 0.3), (math.cos(a1) * rr * 0.6, yr + math.sin(a1) * rr * 0.6, zr - 0.42)], 0.004, lan, 4))
    for k, dz in ((0.82, 0.16), (0.66, 0.3)):
        s.append(tube('pierscien', [(math.cos(a) * rr * k, yr + math.sin(a) * rr * k, zr - dz) for a in [i * math.tau / 20 for i in range(21)]], 0.003, lan, 4))
    siatka = join('Siatka', s)
    weather([kosz_ob], 1024, 0.5, 0.5, (0.12, 0.1, 0.08))
    export('boisko_kosz')


def pilka():
    reset()
    r = 0.12
    skora = mat('skora', 'c8591c', 0.75)
    szew = mat('szew', '17140f', 0.6)
    prof = [(math.sin(a) * r, -math.cos(a) * r + r) for a in [i * math.pi / 16 for i in range(17)]]
    prof[0] = (0.0, 0.0)
    prof[-1] = (0.0, 2 * r)
    kula = lathe('kula', prof, skora, 20)
    sz = []
    c = (0, 0, r)
    rs = r + 0.0006
    # trzy szwy po wielkich kołach i dwa boczne łuki — układ jak na prawdziwej piłce do kosza
    def kolo(fn, n=24):
        return [fn(i * math.tau / n) for i in range(n + 1)]
    sz.append(tube('szew_r', kolo(lambda a: (math.cos(a) * rs, math.sin(a) * rs, r)), 0.0028, szew, 4))
    sz.append(tube('szew_p', kolo(lambda a: (math.cos(a) * rs, 0.0, r + math.sin(a) * rs)), 0.0028, szew, 4))
    for sx in (-1, 1):
        k = 0.62
        rk = rs * math.sqrt(1 - k * k)
        sz.append(tube('szew_b', kolo(lambda a: (sx * (k * rs + 0.0), math.cos(a) * rk, r + math.sin(a) * rk)), 0.0028, szew, 4))
    ob = join('Pilka', [kula] + sz)
    weather([ob], 512, 0.45, 0.35, (0.1, 0.08, 0.06))
    export('boisko_pilka')


FUNCS = {'boisko_kosz': kosz, 'boisko_pilka': pilka}
names = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else list(FUNCS)
for nm in names:
    FUNCS[nm]()
