"""Sklep z tanią odzieżą: ubrania na wieszakach (koszula, kurtka, bluza z kapturem, spodnie, płaszcz), złożony sweter
na półkę, kosz z wyprzedażą, zasłona przymierzalni i manekin. Tkanina („TintTkanina”) jest jasna — gra barwi ją na kolor
ubrania. Ubranie wisi w płaszczyźnie XZ (bark do barku wzdłuż X), haczyk wieszaka na z = 0, reszta poniżej."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
from lib import _finish
from mathutils import noise

R90 = math.radians(90)
rnd = random.Random(23)


def _wieszak(out, w=0.2):
    wood = mat('wieszak', '8a6a44', 0.7, wzor='drewno')
    st = mat('haczyk', '9da3a8', 0.4, 0.8)
    out.append(tube('ramie_l', [(-w, 0, -0.105), (0, 0, -0.055)], 0.011, wood, 6))
    out.append(tube('ramie_p', [(w, 0, -0.105), (0, 0, -0.055)], 0.011, wood, 6))
    out.append(tube('hak', [(0, 0, -0.055), (0, 0, -0.01), (0.022, 0, 0.012), (0.03, 0, -0.012)], 0.004, st, 5))


def _cloth():
    return mat('tkanina', 'e4e1da', 0.95, wzor='tkanina')


def _faldy(ob, amp=0.008, freq=18.0):
    """lekkie pofalowanie materiału, żeby ubranie nie było deską"""
    for v in ob.data.vertices:
        co = ob.matrix_world @ v.co if False else v.co
        v.co.y += amp * math.sin(co.x * freq + co.z * 3.0) * min(1.0, abs(co.z) * 3.0)
    return ob


def _korpus(name, sh, ln, thick, flare=0.0, neck=0.07):
    pts = [(-sh, -0.105), (-neck, -0.06), (neck, -0.06), (sh, -0.105), (sh - 0.01 + flare, -ln), (-sh + 0.01 - flare, -ln)]
    ob = profile(name, pts, thick, _cloth(), 0.014)
    return ob


def _rekaw(name, sx, sh, ln, thick, ang=0.07):
    r = rbox(name, (0.085, thick * 0.8, ln), _cloth(), 0.025, (sx * (sh + 0.03 + math.sin(ang) * ln * 0.5), 0, -0.125 - ln * 0.5), (0, -sx * ang, 0), segs=3)
    return r


def ubranie(nazwa, rodzaj):
    reset()
    h = []
    _wieszak(h, 0.2 if rodzaj != 'spodnie' else 0.17)
    t = []
    dark = mat('dodatki', '2a2a2e', 0.7)
    if rodzaj == 'koszula':
        t.append(_korpus('korpus', 0.2, 0.74, 0.045))
        for sx in (-1, 1):
            t.append(_rekaw('rekaw', sx, 0.2, 0.52, 0.045))
            t.append(rbox('kolnierz', (0.085, 0.05, 0.035), _cloth(), 0.012, (sx * 0.045, -0.005, -0.068), (0, sx * 0.5, 0)))
        h.append(rbox('listwa', (0.012, 0.05, 0.62), mat('listwa', 'd6d2c8', 0.9), 0.002, (0, -0.002, -0.4)))
        for i in range(6):
            h.append(lathe('guzik%d' % i, [(0.0, 0.0), (0.006, 0.0), (0.006, 0.003), (0.0, 0.003)], mat('guzik', 'f0eee6', 0.5), 8, loc=(0.0, -0.028, -0.13 - i * 0.1)))
            h[-1].rotation_euler = (R90, 0, 0)
    elif rodzaj == 'kurtka':
        t.append(_korpus('korpus', 0.235, 0.68, 0.09))
        for sx in (-1, 1):
            t.append(_rekaw('rekaw', sx, 0.235, 0.56, 0.085))
            t.append(rbox('kolnierz', (0.1, 0.09, 0.05), _cloth(), 0.016, (sx * 0.055, 0, -0.07), (0, sx * 0.45, 0)))
            h.append(rbox('kieszen', (0.11, 0.094, 0.012), dark, 0.003, (sx * 0.11, 0, -0.5)))
        h.append(rbox('zamek', (0.01, 0.094, 0.6), mat('zamek', '8a8d92', 0.4, 0.8), 0.002, (0, 0, -0.39)))
        h.append(rbox('sciagacz', (0.45, 0.096, 0.045), dark, 0.012, (0, 0, -0.665)))
    elif rodzaj == 'bluza':
        t.append(_korpus('korpus', 0.225, 0.66, 0.08))
        for sx in (-1, 1):
            t.append(_rekaw('rekaw', sx, 0.225, 0.55, 0.08))
        # kaptur zwisa z tyłu, z przodu kieszeń „kangurka” i sznurki
        hood = lathe('kaptur', [(0.0, -0.22), (0.1, -0.2), (0.14, -0.1), (0.12, 0.0), (0.0, 0.02)], _cloth(), 12, loc=(0, 0.06, -0.1))
        hood.scale = (1.0, 0.45, 1.0)
        t.append(hood)
        t.append(rbox('kangurka', (0.26, 0.086, 0.14), _cloth(), 0.02, (0, -0.006, -0.5)))
        for sx in (-1, 1):
            h.append(tube('sznurek', [(sx * 0.04, -0.045, -0.09), (sx * 0.045, -0.047, -0.3)], 0.004, mat('sznurek', 'eeeae0', 0.9), 4))
        h.append(rbox('sciagacz', (0.43, 0.086, 0.04), _cloth(), 0.012, (0, 0, -0.65)))
    elif rodzaj == 'plaszcz':
        t.append(_korpus('korpus', 0.225, 1.08, 0.085, flare=0.03))
        for sx in (-1, 1):
            t.append(_rekaw('rekaw', sx, 0.225, 0.6, 0.08))
            t.append(rbox('klapa', (0.09, 0.09, 0.22), _cloth(), 0.014, (sx * 0.05, -0.004, -0.17), (0, sx * 0.3, 0)))
        for i in range(3):
            h.append(lathe('guzik%d' % i, [(0.0, 0.0), (0.012, 0.0), (0.012, 0.005), (0.0, 0.005)], dark, 10, loc=(0.03, -0.047, -0.36 - i * 0.16)))
            h[-1].rotation_euler = (R90, 0, 0)
        h.append(rbox('pasek', (0.44, 0.09, 0.03), dark, 0.006, (0, 0, -0.52)))
    else:           # spodnie przewieszone przez poprzeczkę wieszaka
        h.append(tube('poprzeczka', [(-0.17, 0, -0.105), (0.17, 0, -0.105)], 0.008, mat('wieszak', '8a6a44', 0.7, wzor='drewno'), 6))
        for (sy, ln) in ((-0.022, 0.56), (0.022, 0.5)):
            for sx in (-1, 1):
                t.append(rbox('nogawka', (0.15, 0.03, ln), _cloth(), 0.012, (sx * 0.078, sy, -0.1 - ln * 0.5)))
        t.append(rbox('grzbiet', (0.31, 0.075, 0.03), _cloth(), 0.012, (0, 0, -0.098)))
        h.append(rbox('pas', (0.31, 0.034, 0.04), dark, 0.006, (0, -0.022, -0.64)))
    tk = join('TintTkanina', t)
    _faldy(tk)
    hz = join('Wieszak', h)
    weather([tk], 256, 0.3, 0.3, (0.16, 0.14, 0.12))
    export(nazwa)


def zlozony():
    """złożony sweter / dżinsy na półkę: trzy warstwy z zaokrąglonym grzbietem"""
    reset()
    t = [rbox('warstwa%d' % i, (0.3 - i * 0.004, 0.34, 0.022), _cloth(), 0.01, (0, 0, 0.011 + i * 0.022), (0, 0, rnd.uniform(-0.03, 0.03))) for i in range(3)]
    t.append(rbox('grzbiet', (0.3, 0.03, 0.066), _cloth(), 0.014, (0, -0.165, 0.033)))
    tk = join('TintTkanina', t)
    weather([tk], 256, 0.3, 0.3, (0.16, 0.14, 0.12))
    export('ciuch_zlozony')


def kosz():
    """kosz z wyprzedażą: druciany stojak na kółkach z tekturowym wkładem i stertą zmiętych ubrań (kolory wypalone)"""
    reset()
    st = mat('drut', '9da3a8', 0.4, 0.8)
    card = mat('karton', 'a88a5e', 0.95, wzor='karton')
    p = []
    W, D, H, Z0 = 0.8, 0.6, 0.42, 0.16
    for z in (Z0, Z0 + H * 0.5, Z0 + H):
        for (a, b) in (((-W / 2, -D / 2), (W / 2, -D / 2)), ((W / 2, -D / 2), (W / 2, D / 2)), ((W / 2, D / 2), (-W / 2, D / 2)), ((-W / 2, D / 2), (-W / 2, -D / 2))):
            p.append(tube('obrecz', [(a[0], a[1], z), (b[0], b[1], z)], 0.008, st, 6))
    for i in range(9):
        x = -W / 2 + i * W / 8
        for sy in (-1, 1):
            p.append(tube('pret', [(x, sy * D / 2, Z0), (x, sy * D / 2, Z0 + H)], 0.005, st, 5))
    for i in range(7):
        y = -D / 2 + i * D / 6
        for sx in (-1, 1):
            p.append(tube('pret_b', [(sx * W / 2, y, Z0), (sx * W / 2, y, Z0 + H)], 0.005, st, 5))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(tube('noga', [(sx * (W / 2 - 0.03), sy * (D / 2 - 0.03), Z0), (sx * (W / 2 - 0.03), sy * (D / 2 - 0.03), 0.05)], 0.012, st, 6))
            k = lathe('kolko', [(0.0, -0.012), (0.035, -0.012), (0.04, 0.0), (0.035, 0.012), (0.0, 0.012)], mat('guma', '18181a', 0.9), 10)
            k.rotation_euler = (R90, 0, 0)
            k.location = (sx * (W / 2 - 0.03), sy * (D / 2 - 0.03), 0.04)
            p.append(k)
    p.append(rbox('wklad', (W - 0.03, D - 0.03, H - 0.02), card, 0.004, (0, 0, Z0 + H / 2 - 0.01)))
    kolory = ['8a2a2a', '2a4a6a', '3a5a3a', 'c9a23a', '1c1c20', 'd9d4c8', '6a3a5a', 'b0582c', '2f6a6a', 'e8e2d0']
    for i in range(16):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
        s = rnd.uniform(0.0, 9.0)
        rx, ry, rz = rnd.uniform(0.13, 0.2), rnd.uniform(0.1, 0.16), rnd.uniform(0.035, 0.06)
        for v in bm.verts:
            kk = 1.0 + 0.35 * noise.noise(v.co * 2.6 + Vector((s, s * 0.4, 1.0)))
            v.co = Vector((v.co.x * rx * kk, v.co.y * ry * kk, v.co.z * rz * kk))
        me = bpy.data.meshes.new('ciuch%d' % i)
        bm.to_mesh(me)
        bm.free()
        ob = _finish(me, 'ciuch%d' % i, mat('c%d' % (i % 10), kolory[i % 10], 0.95, wzor='tkanina'), True, None)
        ob.location = (rnd.uniform(-0.26, 0.26), rnd.uniform(-0.18, 0.18), Z0 + H - 0.01 + rnd.uniform(0.0, 0.07))
        ob.rotation_euler = (rnd.uniform(-0.25, 0.25), rnd.uniform(-0.25, 0.25), rnd.uniform(0, 3.1))
        p.append(ob)
    ob = join('Kosz', p)
    weather([ob], 1024, 0.45, 0.4, (0.14, 0.12, 0.1))
    export('ciuch_kosz')


def zaslona():
    """zasłona przymierzalni 1,3 × 1,95 m na kółkach: gęste, nierówne fałdy; drążek ma gra"""
    reset()
    velvet = mat('TintZaslona', 'e4e1da', 0.95, wzor='tkanina')
    def fn(u, v):
        f = math.sin(u * 22.0 + math.sin(v * 2.0) * 0.6) * 0.035 * (0.6 + 0.4 * v) + math.sin(u * 51.0) * 0.008
        return (0.0, f, 0.0)
    sh = sheet('TintZaslona', 1.3, 1.95, 90, 10, fn, velvet)
    sh2 = sheet('tyl', 1.3, 1.95, 90, 10, lambda u, v: (0.0, fn(u, v)[1] + 0.004, 0.0), velvet)
    for p in sh2.data.polygons:
        p.flip()
    z = join('TintZaslona', [sh, sh2])
    st = mat('kolko', '9da3a8', 0.4, 0.8)
    k = [lathe('kolko%d' % i, [(0.012, -0.004), (0.02, -0.004), (0.02, 0.004), (0.012, 0.004)], st, 10, loc=(-0.62 + i * 0.113, fn(i / 11.0, 1.0)[1], 1.97)) for i in range(12)]
    for o in k:
        o.rotation_euler = (0, R90, 0)
    join('Kolka', k)
    weather([z], 512, 0.35, 0.3, (0.16, 0.13, 0.12))
    export('ciuch_zaslona')


def manekin():
    """manekin krawiecki: tors z kremowego płótna na drewnianym stojaku, na nim marynarka do zabarwienia, na szyi gałka"""
    reset()
    linen = mat('plotno', 'd9d0b8', 0.95, wzor='tkanina')
    wood = mat('drewno', '5a4326', 0.7, wzor='drewno')
    tors = lathe('tors', [(0.0, 0.0), (0.13, 0.0), (0.15, 0.1), (0.135, 0.25), (0.16, 0.4), (0.185, 0.5), (0.17, 0.58), (0.07, 0.63), (0.055, 0.69), (0.0, 0.7)], linen, 20, loc=(0, 0, 0.95))
    tors.scale = (1.0, 0.68, 1.0)
    p = [tors,
         tube('trzpien', [(0, 0, 0.06), (0, 0, 0.96)], 0.018, wood, 8),
         lathe('galka', [(0.0, 0.0), (0.03, 0.0), (0.04, 0.03), (0.02, 0.06), (0.0, 0.065)], wood, 12, loc=(0, 0, 1.64)),
         lathe('podstawa', [(0.0, 0.0), (0.2, 0.0), (0.19, 0.03), (0.05, 0.05), (0.0, 0.06)], wood, 16)]
    st = join('Manekin', p)
    t = []
    body = profile('marynarka', [(-0.215, 0.5), (-0.07, 0.6), (0.07, 0.6), (0.215, 0.5), (0.2, -0.05), (-0.2, -0.05)], 0.26, _cloth(), 0.03)
    body.location = (0, 0, 1.0)
    t.append(body)
    for sx in (-1, 1):
        t.append(rbox('rekaw', (0.1, 0.11, 0.58), _cloth(), 0.035, (sx * 0.255, 0, 1.22), (0, -sx * 0.06, 0), segs=3))
        t.append(rbox('klapa', (0.08, 0.02, 0.26), _cloth(), 0.01, (sx * 0.05, -0.135, 1.42), (0, sx * 0.25, 0)))
    tk = join('TintTkanina', t)
    weather([st], 512, 0.4, 0.4, (0.14, 0.12, 0.1))
    weather([tk], 512, 0.3, 0.3, (0.16, 0.14, 0.12))
    export('manekin')


only = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
for n, r in (('ciuch_koszula', 'koszula'), ('ciuch_kurtka', 'kurtka'), ('ciuch_bluza', 'bluza'), ('ciuch_spodnie', 'spodnie'), ('ciuch_plaszcz', 'plaszcz')):
    if not only or n in only:
        ubranie(n, r)
for fn in (zlozony, kosz, zaslona, manekin):
    if not only or fn.__name__ in only:
        fn()
