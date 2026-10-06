"""Życie miasta poza osiedlem: obozowisko bezdomnych (ognisko z topiącym się plastikowym krzesłem, legowisko z kartonów,
szałas z palet i plandeki, wózek sklepowy), policyjne bariery i zapory drogowe z lampą, pachołek oraz portal dużego tunelu.
Przód = −Y, spód na z = 0."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
from lib import _finish
from mathutils import noise

R90 = math.radians(90)
rnd = random.Random(12)


def _grudka(name, r, material, loc, sq=0.6, seed=0.0):
    """nieregularna bryłka (worek, tobołek, kamień)"""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
    for v in bm.verts:
        k = 1.0 + 0.3 * noise.noise(v.co * 2.2 + Vector((seed, seed * 0.6, 1.0)))
        v.co = Vector((v.co.x * r * k, v.co.y * r * k, (v.co.z * 0.5 + 0.5) * r * 2.0 * sq * k))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = _finish(me, name, material, True, None)
    ob.location = loc
    return ob


def bezd_ognisko():
    """ognisko w kręgu z cegieł: popiół, nadpalone deski, a w ogniu biały ogrodowy fotel z plastiku — przewrócony,
    z nadtopionymi, sczerniałymi nogami. Żar („Zar”) świeci."""
    reset()
    brick = mat('cegla', '8a4a36', 0.9)
    ash = mat('popiol', '2a2826', 0.98)
    char = mat('wegiel', '141312', 0.95)
    plast = mat('plastik', 'e2e0d8', 0.45)
    burnt = mat('stopiony', '2b2622', 0.6)
    p = [lathe('popiol', [(0.0, 0.0), (0.5, 0.0), (0.46, 0.035), (0.2, 0.06), (0.0, 0.07)], ash, 16)]
    for k in range(10):
        a = k * math.tau / 10 + rnd.uniform(-0.08, 0.08)
        p.append(rbox('cegla', (0.24, 0.115, 0.07), brick, 0.008, (math.cos(a) * 0.52, math.sin(a) * 0.52, 0.035 + (0.07 if k % 4 == 0 else 0.0)), (rnd.uniform(-0.1, 0.1), 0, a + R90 + rnd.uniform(-0.2, 0.2)), segs=1))
    for k in range(4):
        a = k * 1.7 + 0.3
        p.append(rbox('deska', (0.62, 0.09, 0.03), char, 0.006, (math.cos(a) * 0.1, math.sin(a) * 0.1, 0.1 + k * 0.03), (0.25, 0.18 * (k % 2), a), segs=1))
    # fotel ogrodowy: siedzisko, oparcie ze szczeblami, podłokietniki, cztery nogi — leży bokiem w ogniu
    ch = [rbox('siedzisko', (0.44, 0.42, 0.025), plast, 0.01, (0, 0, 0.42), segs=2)]
    ch.append(rbox('rant', (0.44, 0.03, 0.05), plast, 0.008, (0, -0.2, 0.4), segs=1))
    for sx in (-0.16, -0.05, 0.06, 0.17):
        ch.append(rbox('szczebel', (0.05, 0.02, 0.36), plast, 0.006, (sx, 0.21, 0.62), (0.12, 0, 0), segs=1))
    ch.append(rbox('zaglowek', (0.46, 0.025, 0.08), plast, 0.01, (0, 0.235, 0.82), (0.12, 0, 0), segs=2))
    for sx in (-1, 1):
        ch.append(rbox('podlokietnik', (0.05, 0.4, 0.025), plast, 0.008, (sx * 0.235, 0.02, 0.6), segs=1))
        ch.append(tube('slupek', [(sx * 0.235, -0.17, 0.42), (sx * 0.235, -0.18, 0.6)], 0.016, plast, 6))
    legs = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            # nogi po stronie ognia są krótsze, powyginane i czarne
            hot = sx > 0
            legs.append(tube('noga', [(sx * 0.2, sy * 0.18, 0.42), (sx * (0.21 + (0.05 if hot else 0)), sy * 0.19, 0.22 if hot else 0.2), (sx * (0.22 + (0.12 if hot else 0)), sy * (0.2 + (0.04 if hot else 0)), 0.12 if hot else 0.0)], 0.018, burnt if hot else plast, 6))
    chair = join('Fotel', ch + legs)
    chair.rotation_euler = (0.25, math.radians(72), 0.5)
    chair.location = (-0.12, 0.05, 0.16)
    # nadtopiona krawędź siedziska i kałuża stopionego plastiku
    p.append(_grudka('stopiony', 0.14, burnt, (0.12, 0.1, 0.05), 0.2, 3.0))
    base = join('Ognisko', p)
    em = mat('zar', 'ff6a1a', 0.6, 0.0, 3.5)
    z = [rbox('zar', (0.3, 0.05, 0.02), em, 0.004, (0.02, 0.02, 0.105), (0.2, 0.1, 0.4), segs=1),
         rbox('zar', (0.22, 0.045, 0.02), em, 0.004, (-0.05, 0.08, 0.13), (0.2, 0.0, 2.0), segs=1),
         _grudka('zar', 0.07, em, (0.1, -0.08, 0.06), 0.3, 5.0)]
    join('Zar', z)
    weather([base, chair], 1024, 0.8, 0.85, (0.06, 0.05, 0.045))
    export('bezd_ognisko')


def bezd_legowisko():
    """legowisko: płaty kartonu, stary materac, koc, poduszka z reklamówki, torby, butelki i puszki"""
    reset()
    card = mat('karton', 'a98458', 0.95, wzor='karton')
    matr = mat('materac', 'b9b0a0', 0.95, wzor='tkanina')
    koc = mat('koc', '5a4a6a', 0.98, wzor='tkanina')
    p = []
    for (x, y, w, d, rz) in ((0, 0, 2.1, 1.1, 0.05), (0.3, 0.2, 1.4, 0.9, -0.12), (-0.9, -0.5, 0.8, 0.6, 0.5)):
        p.append(rbox('karton', (w, d, 0.012), card, 0.0, (x, y, 0.008 + 0.012 * len(p)), (0, 0, rz), segs=1))
    p.append(rbox('materac', (1.85, 0.8, 0.12), matr, 0.04, (0.05, 0.05, 0.1), (0, 0, 0.03), segs=3))
    for k in range(5):
        p.append(rbox('pasek', (0.03, 0.8, 0.002), mat('pasek', '6a7a8a', 0.95), 0.0, (-0.7 + k * 0.36, 0.05, 0.161), (0, 0, 0.03), segs=1))
    # koc: pofałdowana płachta narzucona na połowę materaca
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=14, y_segments=9, size=0.5)
    for v in bm.verts:
        x, y = v.co.x * 2, v.co.y * 2
        v.co = Vector((x * 0.6 + 0.4, y * 0.46 + 0.05, 0.18 + 0.035 * noise.noise(Vector((x * 2.2, y * 2.6, 0.7))) + 0.03 * math.sin(x * 5.0)))
    me = bpy.data.meshes.new('koc')
    bm.to_mesh(me)
    bm.free()
    p.append(_finish(me, 'koc', koc, True, None))
    p.append(_grudka('poduszka', 0.17, mat('reklamowka', 'd8d4c0', 0.6), (-0.68, 0.05, 0.16), 0.4, 2.0))
    for i, (x, y, r) in enumerate(((1.25, -0.4, 0.2), (1.3, 0.3, 0.16), (-1.15, 0.5, 0.18))):
        p.append(_grudka('torba', r, mat('torba%d' % i, ['2a3a5a', '1c1c1e', '8a2a22'][i], 0.7), (x, y, 0.0), 0.7, i * 4.0))
    gl = mat('szklo_z', '2f5a34', 0.15, 0.2)
    gb = mat('szklo_b', '5a3a1c', 0.15, 0.2)
    for i, (x, y, lying) in enumerate(((-0.4, -0.62, False), (-0.25, -0.7, True), (0.9, 0.62, False), (1.5, -0.05, True), (0.1, -0.66, False))):
        b = lathe('butelka', [(0.0, 0.0), (0.032, 0.0), (0.034, 0.15), (0.014, 0.21), (0.013, 0.26), (0.0, 0.262)], gl if i % 2 else gb, 10, loc=(x, y, 0))
        if lying:
            b.rotation_euler = (R90, 0, rnd.uniform(0, 3))
            b.location.z = 0.034
        p.append(b)
    for (x, y) in ((0.55, -0.68), (-1.4, -0.1)):
        c = lathe('puszka', [(0.0, 0.0), (0.03, 0.0), (0.033, 0.01), (0.033, 0.11), (0.027, 0.122), (0.0, 0.122)], mat('alu', 'b9bcc0', 0.3, 0.8), 10, loc=(x, y, 0.033))
        c.rotation_euler = (R90, 0, rnd.uniform(0, 3))
        p.append(c)
    ob = join('Legowisko', p)
    weather([ob], 1024, 0.85, 0.8, (0.1, 0.08, 0.06))
    export('bezd_legowisko')


def bezd_szalas():
    """szałas: dwie palety oparte o siebie, na nich niebieska plandeka z fałdami, z tyłu ściana z kartonów, w środku skrzynka"""
    reset()
    wood = mat('paleta', '8d7350', 0.9, wzor='drewno')
    tarp = mat('plandeka', '2b5f9e', 0.55)
    card = mat('karton', 'a98458', 0.95, wzor='karton')
    p = []
    def paleta(loc, rot):
        parts = []
        for k in range(5):
            parts.append(rbox('deska', (1.2, 0.1, 0.02), wood, 0.004, (0, -0.35 + k * 0.175, 0.13), segs=1))
        for sx in (-0.55, 0.0, 0.55):
            parts.append(rbox('legar', (0.1, 0.8, 0.09), wood, 0.004, (sx, 0, 0.075), segs=1))
        for k in range(3):
            parts.append(rbox('spod', (1.2, 0.1, 0.02), wood, 0.004, (0, -0.35 + k * 0.35, 0.02), segs=1))
        o = join('paleta', parts)
        o.rotation_euler = rot
        o.location = loc
        return o
    p.append(paleta((0, -0.5, 0.55), (math.radians(62), 0, 0)))
    p.append(paleta((0, 0.5, 0.55), (math.radians(-62), 0, 0)))
    # plandeka przerzucona przez kalenicę, zwisa nierówno i jest przyciśnięta cegłami
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=12, y_segments=18, size=0.5)
    for v in bm.verts:
        x, y = v.co.x * 2, v.co.y * 2
        yy = y * 1.05
        z = 1.02 - abs(yy) * 0.92 + 0.03 * noise.noise(Vector((x * 2.5, y * 3.0, 0.3))) - 0.04 * (x * x) * (1 - abs(y))
        v.co = Vector((x * 0.78, yy * 0.78, max(0.02, z)))
    me = bpy.data.meshes.new('plandeka')
    bm.to_mesh(me)
    bm.free()
    tp = _finish(me, 'Plandeka', tarp, True, None)
    solid = tp.modifiers.new('g', 'SOLIDIFY')
    solid.thickness = 0.004
    p.append(rbox('tyl', (0.9, 0.012, 0.75), card, 0.0, (0.72, 0, 0.36), (0, 0.08, R90), segs=1))
    p.append(rbox('tyl2', (0.7, 0.012, 0.5), card, 0.0, (0.735, 0.1, 0.26), (0, -0.05, R90 + 0.1), segs=1))
    p.append(rbox('skrzynka', (0.4, 0.3, 0.26), mat('skrzynka', '7a2a22', 0.6), 0.02, (-0.1, 0.05, 0.13), (0, 0, 0.3)))
    for sy in (-1, 1):
        p.append(rbox('cegla', (0.24, 0.115, 0.07), mat('cegla', '8a4a36', 0.9), 0.008, (rnd.uniform(-0.4, 0.4), sy * 0.86, 0.04), (0, 0, rnd.uniform(0, 3)), segs=1))
    ob = join('Szalas', p)
    weather([ob, tp], 1024, 0.8, 0.8, (0.1, 0.08, 0.06))
    export('bezd_szalas')


def bezd_wozek():
    """wózek sklepowy z dobytkiem: rama z rur, kosz z rzadkiej kraty, w środku torby i złom, jedno kółko krzywe"""
    reset()
    st = mat('ocynk', '9aa0a4', 0.4, 0.8)
    red = mat('raczka', 'b8261c', 0.5)
    p = []
    # kosz: dno i cztery ściany z prętów (rzadko, ale czytelnie)
    x0, x1, y0, y1, z0, z1 = -0.25, 0.25, -0.42, 0.45, 0.5, 0.95
    for z in (z0, z1):
        p.append(tube('rama', [(x0, y0, z), (x1, y0, z), (x1 * 1.1 if z == z1 else x1, y1, z), (x0 * 1.1 if z == z1 else x0, y1, z), (x0, y0, z)], 0.008, st, 5))
    for k in range(7):
        t = k / 6
        y = y0 + (y1 - y0) * t
        for sx in (x0, x1):
            p.append(tube('pret', [(sx, y, z0), (sx * (1 + 0.1 * t), y, z1)], 0.004, st, 4))
        p.append(tube('dno', [(x0, y, z0), (x1, y, z0)], 0.004, st, 4))
    for k in range(4):
        x = x0 + (x1 - x0) * k / 3
        p.append(tube('pret', [(x, y0, z0), (x, y0, z1)], 0.004, st, 4))
        p.append(tube('pret', [(x, y1, z0), (x * 1.1, y1, z1)], 0.004, st, 4))
    p.append(tube('raczka', [(x0 * 1.1, y1 + 0.06, z1 + 0.06), (x1 * 1.1, y1 + 0.06, z1 + 0.06)], 0.014, red, 8))
    for sx in (x0 * 1.1, x1 * 1.1):
        p.append(tube('ramie', [(sx, y1, z1), (sx, y1 + 0.06, z1 + 0.06)], 0.008, st, 5))
        p.append(tube('noga', [(sx / 1.1, y1 - 0.05, z0), (sx / 1.1, y1 - 0.1, 0.1), (sx / 1.1 * 0.7, y0 + 0.05, 0.1), (sx / 1.1 * 0.8, y0, z0)], 0.01, st, 6))
    for (sx, sy, rz) in ((-0.2, y1 - 0.12, 0.0), (0.2, y1 - 0.12, 0.2), (-0.15, y0 + 0.06, 0.0), (0.15, y0 + 0.06, 1.1)):
        w = lathe('kolko', [(0.0, -0.012), (0.045, -0.012), (0.05, -0.006), (0.05, 0.006), (0.045, 0.012), (0.0, 0.012)], mat('guma', '1a1a1c', 0.9), 10)
        w.rotation_euler = (0, R90, rz)
        w.location = (sx, sy, 0.05)
        p.append(w)
    cart = join('Wozek', p)
    stuff = [_grudka('torba', 0.2, mat('torba_n', '2a3a5a', 0.7), (0.0, -0.15, 0.52), 0.8, 1.0),
             _grudka('torba', 0.17, mat('torba_c', '1c1c1e', 0.7), (0.02, 0.22, 0.52), 0.9, 6.0),
             _grudka('tobolek', 0.15, mat('koc', '5a4a6a', 0.98), (-0.03, 0.02, 0.78), 0.6, 9.0)]
    stuff.append(tube('rura', [(0.1, -0.3, 0.6), (0.16, 0.5, 1.25)], 0.02, mat('zlom', '6a5a4a', 0.6, 0.6), 6))
    stuff.append(rbox('karton', (0.4, 0.012, 0.5), mat('karton', 'a98458', 0.95), 0.0, (-0.2, 0.1, 0.8), (0.1, 0.15, R90), segs=1))
    dob = join('Dobytek', stuff)
    weather([cart, dob], 512, 0.7, 0.8, (0.12, 0.09, 0.06))
    export('bezd_wozek')


def bariera_policyjna():
    """przęsło bariery policyjnej 2,3 m: rama z rur, pionowe pręty, płaskie stopy, biało-niebieska tablica POLICE, haki do spinania"""
    reset()
    st = mat('ocynk', '9da3a8', 0.4, 0.8)
    p = [tube('rama', [a, b], 0.019, st, 8) for (a, b) in (((-1.15, 0, 0.14), (-1.15, 0, 1.08)), ((-1.15, 0, 1.08), (1.15, 0, 1.08)), ((1.15, 0, 1.08), (1.15, 0, 0.14)), ((1.15, 0, 0.14), (-1.15, 0, 0.14)))]
    for i in range(15):
        x = -1.0 + i * 0.143
        p.append(tube('pret', [(x, 0, 0.14), (x, 0, 1.08)], 0.008, st, 5))
    for sx in (-0.8, 0.8):
        p.append(rbox('stopa', (0.06, 0.62, 0.012), st, 0.004, (sx, 0, 0.006)))
        p.append(tube('lacznik', [(sx, 0, 0.012), (sx, 0, 0.14)], 0.015, st, 6))
    p.append(tube('hak', [(1.15, 0, 0.75), (1.21, 0, 0.75), (1.21, 0, 0.66)], 0.008, st, 5))
    p.append(tube('ucho', [(-1.15, 0, 0.78), (-1.2, 0, 0.78), (-1.2, 0, 0.7), (-1.15, 0, 0.7)], 0.006, st, 5))
    ob = join('Bariera', p)
    t = [rbox('tablica', (0.9, 0.014, 0.26), mat('tablica', 'e8ecf0', 0.5), 0.004, (0, -0.022, 0.8))]
    t.append(rbox('pas', (0.9, 0.016, 0.05), mat('niebieski', '1d3a8a', 0.5), 0.0, (0, -0.023, 0.695), segs=1))
    t.append(text('napis', 'POLICE', 0.15, mat('niebieski', '1d3a8a', 0.5), (0, -0.031, 0.76)))
    join('Tablica', t)
    weather([ob], 512, 0.45, 0.6)
    export('bariera_policyjna')


def zapora_drogowa():
    """zapora: dwie biało-czerwone deski na kozłach, tablica ROAD CLOSED i żółta lampa ostrzegawcza („Swiatlo”)"""
    reset()
    st = mat('stal', '5a5f64', 0.5, 0.6)
    white = mat('biale', 'e9e9e4', 0.5)
    red = mat('czerwone', 'c0281e', 0.5)
    p = []
    for sx in (-0.95, 0.95):
        for sy in (-1, 1):
            p.append(tube('noga', [(sx, sy * 0.32, 0.0), (sx, 0, 1.05)], 0.018, st, 6))
        p.append(tube('rozporka', [(sx, -0.2, 0.35), (sx, 0.2, 0.35)], 0.012, st, 5))
    for z in (0.62, 0.95):
        for k in range(10):
            p.append(rbox('pas', (0.22, 0.022, 0.16), white if k % 2 else red, 0.0, (-0.99 + k * 0.22, -0.03, z), segs=1))
    p.append(rbox('znak', (0.9, 0.012, 0.3), white, 0.004, (0, -0.045, 1.25)))
    p.append(rbox('ramka', (0.9, 0.014, 0.03), red, 0.0, (0, -0.046, 1.385), segs=1))
    p.append(rbox('ramka', (0.9, 0.014, 0.03), red, 0.0, (0, -0.046, 1.115), segs=1))
    p.append(text('napis', 'ROAD CLOSED', 0.1, mat('tusz', '15161a', 0.6), (0, -0.053, 1.215)))
    p.append(tube('slupek', [(0.0, 0, 0.95), (0.0, 0, 1.12)], 0.014, st, 5))
    p.append(rbox('lampa_k', (0.1, 0.07, 0.05), mat('zolty_p', 'd8a81e', 0.5), 0.01, (0.8, 0, 1.1)))
    ob = join('Zapora', p)
    lathe('Swiatlo', [(0.0, 0.0), (0.075, 0.0), (0.08, 0.03), (0.06, 0.07), (0.0, 0.08)], mat('lampa', 'ffb020', 0.3, 0.0, 2.5), 14, loc=(0.8, 0, 1.125))
    weather([ob], 512, 0.5, 0.6)
    export('zapora_drogowa')


def pacholek():
    """pachołek drogowy 70 cm: pomarańczowy stożek z dwoma białymi pasami na kwadratowej stopie"""
    reset()
    org = mat('pomarancz', 'e2571c', 0.6)
    white = mat('bialy', 'e8e8e2', 0.5)
    p = [rbox('stopa', (0.36, 0.36, 0.03), mat('guma', '1a1a1c', 0.9), 0.02, (0, 0, 0.015))]
    p.append(lathe('stozek', [(0.15, 0.03), (0.11, 0.25), (0.112, 0.25), (0.09, 0.36), (0.07, 0.47), (0.035, 0.66), (0.03, 0.7), (0.0, 0.7)], org, 16))
    for (z0, z1) in ((0.25, 0.36), (0.44, 0.52)):
        r0 = 0.15 - (z0 - 0.03) * 0.178 + 0.003
        r1 = 0.15 - (z1 - 0.03) * 0.178 + 0.003
        p.append(lathe('pas', [(r0, z0), (r1, z1)], white, 16))
    ob = join('Pacholek', p)
    weather([ob], 256, 0.5, 0.6)
    export('pacholek')


def tunel_portal():
    """portal dużego tunelu drogowego: betonowa ściana 17 × 8,6 m z łukowym otworem 9,4 × 5,6 m, w głąb 16 m ciemnej rury,
    gzyms, tablica z nazwą i rokiem, znak wysokości, lampy pod stropem i odwodnienie"""
    reset()
    con = mat('beton', '9a968c', 0.92, wzor='beton')
    dark = mat('wnetrze', '1c1b1a', 0.98)
    W_, H_ = 17.0, 8.6
    ow, oh, rr = 9.4, 5.6, 2.2
    hole = [(-ow / 2, -0.2), (ow / 2, -0.2), (ow / 2, oh - rr)]
    for i in range(1, 9):
        a = i * (math.pi / 2) / 9
        hole.append((ow / 2 - rr + math.cos(a) * rr, oh - rr + math.sin(a) * rr))
    for i in range(0, 9):
        a = math.pi / 2 + i * (math.pi / 2) / 9
        hole.append((-ow / 2 + rr + math.cos(a) * rr, oh - rr + math.sin(a) * rr))
    hole.append((-ow / 2, oh - rr))
    wall = profile('sciana', [(-W_ / 2, 0.0), (W_ / 2, 0.0), (W_ / 2, H_), (-W_ / 2, H_)], 1.4, con, 0.04, holes=(hole,))
    p = [wall]
    p.append(rbox('gzyms', (W_ + 0.5, 1.7, 0.35), con, 0.05, (0, 0, H_ + 0.15)))
    for sx in (-1, 1):
        p.append(rbox('pilaster', (1.1, 1.75, H_), con, 0.05, (sx * (W_ / 2 - 0.55), -0.02, H_ / 2)))
        p.append(rbox('skrzydlo', (4.0, 0.6, 3.2), con, 0.05, (sx * (W_ / 2 + 1.8), 0.2, 1.6), (0, 0, sx * -0.35)))
    # obramienie łuku
    arc = [(x, -0.72, z) for (x, z) in hole[1:]]
    p.append(tube('obramienie', arc, 0.16, con, 6))
    # wnętrze: rura tunelu ciemniejąca w głąb
    L = 16.0
    p.append(rbox('strop', (ow + 0.4, L, 0.3), dark, 0.0, (0, 0.7 + L / 2, oh + 0.15), segs=1))
    for sx in (-1, 1):
        p.append(rbox('bok', (0.3, L, oh + 0.3), dark, 0.0, (sx * (ow / 2 + 0.15), 0.7 + L / 2, oh / 2), segs=1))
        p.append(rbox('chodnik', (0.9, L, 0.18), con, 0.02, (sx * (ow / 2 - 0.45), 0.7 + L / 2, 0.09)))
        for k in range(5):
            p.append(rbox('lampa_t', (0.5, 0.16, 0.06), mat('oprawa', '3a3c40', 0.5, 0.5), 0.01, (sx * 2.3, 1.6 + k * 3.2, oh - 0.05)))
    p.append(rbox('koniec', (ow + 0.4, 0.3, oh + 0.3), mat('czern', '050505', 1.0), 0.0, (0, 0.7 + L, oh / 2), segs=1))
    p.append(rbox('jezdnia', (ow - 1.6, L, 0.12), mat('asfalt', '2a2a2c', 0.95), 0.0, (0, 0.7 + L / 2, -0.03), segs=1))
    # tablica z nazwą, rok budowy, znak ograniczenia wysokości
    p.append(rbox('tablica', (4.4, 0.06, 0.8), mat('tablica', '2a4a3a', 0.6), 0.02, (0, -0.74, 7.05)))
    p.append(text('nazwa', 'HUTNIK TUNNEL', 0.46, mat('bialy', 'e8e8e2', 0.6), (0, -0.78, 6.9)))
    p.append(text('rok', '1978', 0.5, con, (5.4, -0.73, 6.6)))
    disc = lathe('znak', [(0.0, 0.0), (0.42, 0.0), (0.42, 0.03), (0.0, 0.03)], mat('znak_b', 'ecece6', 0.5), 20, loc=(-3.3, -0.76, 6.95))
    disc.rotation_euler = (R90, 0, 0)
    p.append(disc)
    ring = lathe('obwodka', [(0.34, 0.03), (0.42, 0.03), (0.42, 0.04), (0.34, 0.04)], mat('znak_c', 'c0281e', 0.5), 20, loc=(-3.3, -0.76, 6.95))
    ring.rotation_euler = (R90, 0, 0)
    p.append(ring)
    p.append(text('wys', '3.8m', 0.24, mat('tusz', '15161a', 0.6), (-3.3, -0.81, 6.87)))
    # rynna odwodnienia i zacieki po bokach
    for sx in (-1, 1):
        p.append(tube('rynna', [(sx * (W_ / 2 - 1.3), -0.74, H_), (sx * (W_ / 2 - 1.3), -0.74, 0.3), (sx * (W_ / 2 - 1.3), -0.95, 0.1)], 0.07, mat('rura', '4a4f55', 0.5, 0.5), 8))
    ob = join('Portal', p)
    weather([ob], 2048, 0.8, 0.6, (0.07, 0.06, 0.05))
    export('tunel_portal')


only = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
for fn in (bezd_ognisko, bezd_legowisko, bezd_szalas, bezd_wozek, bariera_policyjna, zapora_drogowa, pacholek, tunel_portal):
    if not only or fn.__name__ in only:
        fn()
