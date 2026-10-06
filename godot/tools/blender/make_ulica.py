"""Mała architektura osiedla w jednym stylu z resztą modeli: latarnia, ławka, kontener na śmieci, wiata śmietnikowa,
przystanek, trzepak, huśtawka, zjeżdżalnia, kosz uliczny, słupek. Przód = −Y. Części „Tint…” gra barwi, „Swiatlo…” świecą."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
import bmesh

R90 = math.radians(90)
rnd = random.Random(3)


def wavy(name, w, d, waves, amp, material, loc=(0, 0, 0), rot=(0, 0, 0), nx=None):
    """blacha falista: prostokąt w×d z falą wzdłuż X"""
    nx = nx or waves * 6
    bm = bmesh.new()
    rows = []
    for j in range(2):
        row = []
        for i in range(nx + 1):
            u = i / nx
            row.append(bm.verts.new((-w / 2 + u * w, -d / 2 + j * d, amp * math.sin(u * waves * math.tau))))
        rows.append(row)
    for i in range(nx):
        bm.faces.new((rows[0][i], rows[0][i + 1], rows[1][i + 1], rows[1][i]))
    bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.006)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    me.materials.append(material)
    for p in me.polygons:
        p.use_smooth = True
    ob.location = loc
    ob.rotation_euler = rot
    return ob


def ul_latarnia():
    """latarnia osiedlowa 7,2 m: zbieżny słup betonowy z cokołem i klapą rewizyjną, stalowe opaski, wysięgnik, oprawa z radiatorem; klosz „Swiatlo” świeci"""
    reset()
    con = mat('beton', 'b4b2aa', 0.88)
    st = mat('stal', '4a4f55', 0.5, 0.6)
    p = [lathe('slup', [(0.0, 0.0), (0.2, 0.0), (0.2, 0.42), (0.165, 0.56), (0.15, 0.7), (0.085, 7.2), (0.0, 7.2)], con, 10)]
    p.append(rbox('klapa', (0.12, 0.016, 0.34), st, 0.004, (0, -0.146, 1.0)))
    p += bolts('sr', [(sx * 0.045, -0.155, 1.0 + sz * 0.14) for sx in (-1, 1) for sz in (-1, 1)], st, 0.008, 0.004, 'Y')
    for z in (2.4, 4.6, 6.9):
        r = 0.15 - 0.065 * (z - 0.7) / 6.5
        p.append(lathe('opaska', [(r - 0.002, z - 0.035), (r + 0.008, z - 0.035), (r + 0.008, z + 0.035), (r - 0.002, z + 0.035)], st, 10))
        p.append(rbox('sciag', (0.03, 0.03, 0.05), st, 0.004, (0, r + 0.02, z)))
    p.append(tube('wysiegnik', [(0, 0, 6.95), (0, -0.12, 7.3), (0, -0.5, 7.5), (0, -1.3, 7.44)], 0.036, st, 10))
    p.append(tube('zastrzal', [(0, -0.02, 6.6), (0, -0.55, 7.42)], 0.016, st, 8))
    p.append(rbox('oprawa', (0.27, 0.66, 0.1), mat('oprawa', '2a2c30', 0.5, 0.5), 0.035, (0, -1.62, 7.42), (math.radians(-6), 0, 0), segs=4))
    for k in range(6):
        p.append(rbox('zebro', (0.2, 0.012, 0.035), mat('oprawa', '2a2c30', 0.5, 0.5), 0.003, (0, -1.4 - k * 0.07, 7.485 + k * 0.007), (math.radians(-6), 0, 0)))
    p.append(rbox('numer', (0.1, 0.004, 0.07), mat('tabliczka', 'd8d4c8', 0.6), 0.0, (0, -0.118, 1.75), segs=1))
    p.append(rbox('ogloszenie', (0.14, 0.004, 0.19), mat('papier', 'e8e2cf', 0.95), 0.0, (0.02, -0.112, 1.45), (0, 0.06, 0), segs=1))
    ob = join('Latarnia', p)
    weather([ob], 1024, 0.65, 0.45)
    rbox('Swiatlo', (0.2, 0.48, 0.02), mat('klosz', 'fff2d0', 0.3, 0.0, 3.0), 0.006, (0, -1.63, 7.365), (math.radians(-6), 0, 0))
    export('ul_latarnia')


def ul_lawka():
    """ławka parkowa: żeliwne boki z podłokietnikami, pięć desek siedziska i trzy oparcia przykręcone śrubami (TintDeski)"""
    reset()
    iron = mat('zeliwo', '2a2d30', 0.6, 0.5)
    p = []
    for sx in (-0.8, 0.8):
        p.append(tube('noga_t', [(sx, 0.24, 0.0), (sx, 0.22, 0.42), (sx, 0.3, 0.9)], 0.022, iron, 8))
        p.append(tube('noga_p', [(sx, -0.22, 0.0), (sx, -0.22, 0.42)], 0.022, iron, 8))
        p.append(tube('wspornik', [(sx, -0.24, 0.42), (sx, 0.24, 0.42)], 0.02, iron, 8))
        p.append(tube('podlokietnik', [(sx, -0.24, 0.42), (sx, -0.27, 0.6), (sx, -0.1, 0.66), (sx, 0.24, 0.62)], 0.018, iron, 8))
        p.append(tube('ozdoba', [(sx, -0.1, 0.42), (sx, 0.0, 0.54), (sx, 0.1, 0.42)], 0.012, iron, 8))
        for y in (-0.22, 0.24):
            p.append(rbox('stopa', (0.09, 0.12, 0.02), iron, 0.006, (sx, y, 0.01)))
    p.append(tube('lacznik', [(-0.8, 0.0, 0.2), (0.8, 0.0, 0.2)], 0.014, iron, 8))
    fr = join('Boki', p)
    weather([fr], 512, 0.5, 0.7)
    wood = mat('deski', 'c9b48f', 0.8)
    s = []
    for i in range(5):
        s.append(rbox('deska', (1.74, 0.078, 0.03), wood, 0.008, (0, -0.18 + i * 0.092, 0.455 + (0.006 if i in (0, 4) else 0.0)), (0, rnd.uniform(-0.004, 0.004), 0)))
    for i in range(3):
        s.append(rbox('oparcie', (1.74, 0.03, 0.085), wood, 0.008, (0, 0.245 + i * 0.024, 0.6 + i * 0.105), (math.radians(-13), 0, 0)))
    so = join('TintDeski', s)
    weather([so], 1024, 0.55, 0.5, (0.12, 0.1, 0.08))
    b = []
    for sx in (-0.8, 0.8):
        b += bolts('sr', [(sx, -0.18 + i * 0.092, 0.471) for i in range(5)], mat('sruba', '8a8f95', 0.4, 0.8), 0.009, 0.005)
        b += bolts('sr', [(sx, 0.228 + i * 0.024, 0.6 + i * 0.105) for i in range(3)], mat('sruba', '8a8f95', 0.4, 0.8), 0.009, 0.005, 'Y')
    join('Sruby', b)
    export('ul_lawka')


def ul_kontener():
    """kontener 1100 l: tłoczone żebra, kołnierz, klapa z uchwytami, czopy do śmieciarki, cztery kółka z widelcami, korek spustowy (TintKorpus)"""
    reset()
    pl = mat('plastik', 'c9cbc8', 0.6)
    p = [rbox('korpus', (1.26, 0.9, 0.86), pl, 0.05, (0, 0, 0.71), segs=3)]
    for k in range(6):
        x = -0.5 + k * 0.2
        for sy in (-1, 1):
            p.append(rbox('zebro', (0.05, 0.03, 0.7), pl, 0.012, (x, sy * 0.455, 0.72)))
    for sx in (-1, 1):
        for k in range(3):
            p.append(rbox('zebro_b', (0.03, 0.05, 0.7), pl, 0.012, (sx * 0.635, -0.25 + k * 0.25, 0.72)))
    p.append(rbox('kolnierz', (1.36, 1.0, 0.06), pl, 0.018, (0, 0, 1.15)))
    p.append(rbox('klapa', (1.38, 1.02, 0.12), pl, 0.05, (0, 0.0, 1.235), (math.radians(2), 0, 0), segs=4))
    for k in range(4):
        p.append(rbox('przetloczenie', (1.1, 0.05, 0.02), pl, 0.008, (0, -0.3 + k * 0.2, 1.3 + k * 0.007)))
    body = join('TintKorpus', p)
    weather([body], 1024, 0.75, 0.6, (0.1, 0.09, 0.07))
    st = mat('stal', '6a6f75', 0.45, 0.7)
    rub = mat('guma', '18181a', 0.85)
    o = []
    for sx in (-1, 1):
        t = lathe('czop', [(0.0, 0.0), (0.035, 0.0), (0.035, 0.07), (0.05, 0.075), (0.05, 0.09), (0.0, 0.09)], st, 12)
        t.rotation_euler = (0, R90 * sx, 0)
        t.location = (sx * 0.65, 0.0, 1.05)
        o.append(t)
        o.append(tube('uchwyt_b', [(sx * 0.66, -0.2, 0.95), (sx * 0.71, -0.2, 0.93), (sx * 0.71, 0.2, 0.93), (sx * 0.66, 0.2, 0.95)], 0.012, st, 8))
        for sy in (-1, 1):
            x, y = sx * 0.5, sy * 0.34
            w = lathe('kolko', [(0.0, -0.025), (0.06, -0.025), (0.1, -0.02), (0.1, 0.02), (0.06, 0.025), (0.0, 0.025)], rub, 14)
            w.rotation_euler = (0, R90, 0.3 * sx * sy)
            w.location = (x, y, 0.1)
            o.append(w)
            o.append(rbox('widelec', (0.075, 0.06, 0.16), st, 0.008, (x, y + 0.01, 0.2)))
            o.append(rbox('plytka', (0.12, 0.12, 0.012), st, 0.004, (x, y, 0.285)))
    o.append(tube('uchwyt_k', [(-0.3, -0.52, 1.24), (-0.3, -0.57, 1.22), (0.3, -0.57, 1.22), (0.3, -0.52, 1.24)], 0.012, st, 8))
    o.append(lathe('korek', [(0.0, 0.0), (0.03, 0.0), (0.03, 0.02), (0.0, 0.02)], rub, 10, loc=(0.4, -0.46, 0.34)))
    o[-1].rotation_euler = (R90, 0, 0)
    ok = join('Okucia', o)
    weather([ok], 512, 0.6, 0.6)
    d = [rbox('naklejka', (0.3, 0.004, 0.2), mat('naklejka', 'e8e4d4', 0.7), 0.0, (-0.2, -0.472, 0.85), segs=1)]
    d.append(text('napis', 'MIXED WASTE', 0.04, mat('druk', '1a1a1a', 0.9), (-0.2, -0.475, 0.87), (R90, 0, 0), 0.0005))
    d.append(text('napis2', '1100 L', 0.03, mat('druk', '1a1a1a', 0.9), (-0.2, -0.475, 0.81), (R90, 0, 0), 0.0005))
    join('Naklejka', d)
    export('ul_kontener')


def ul_wiata():
    """wiata śmietnikowa 5 × 3,2 m: ściany z płyt betonowych z pilastrami i spoinami, dach z blachy falistej na kątownikach, uchylona furtka z siatki"""
    reset()
    con = mat('beton', 'b9b8b2', 0.9)
    st = mat('stal', '4a5158', 0.5, 0.6)
    p = [rbox('tyl', (5.0, 0.12, 1.9), con, 0.01, (0, 1.6, 0.95))]
    for sx in (-1, 1):
        p.append(rbox('bok', (0.12, 3.2, 1.9), con, 0.01, (sx * 2.5, 0, 0.95)))
        for y in (-1.6, 0.0, 1.6):
            p.append(rbox('pilaster', (0.2, 0.2, 2.0), con, 0.012, (sx * 2.5, y, 1.0)))
        p.append(rbox('czapa', (0.26, 3.4, 0.07), con, 0.01, (sx * 2.5, 0, 1.94)))
    for x in (-1.25, 0.0, 1.25):
        p.append(rbox('pilaster_t', (0.2, 0.2, 2.0), con, 0.012, (x, 1.6, 1.0)))
    for z in (0.63, 1.27):
        p.append(rbox('spoina', (4.9, 0.006, 0.014), mat('spoina', '6a6a66', 0.95), 0.0, (0, 1.537, z), segs=1))
        for sx in (-1, 1):
            p.append(rbox('spoina_b', (0.006, 3.1, 0.014), mat('spoina', '6a6a66', 0.95), 0.0, (sx * 2.437, 0, z), segs=1))
    p.append(rbox('posadzka', (5.0, 3.3, 0.06), mat('posadzka', '9a9892', 0.95), 0.008, (0, 0, 0.03)))
    walls = join('Mury', p)
    weather([walls], 1024, 0.85, 0.5, (0.1, 0.09, 0.07))
    r = [wavy('blacha', 5.5, 3.7, 22, 0.018, mat('blacha', '8f9499', 0.5, 0.6), (0, 0, 2.13), (math.radians(4), 0, 0))]
    for y in (-1.5, 0.0, 1.5):
        r.append(rbox('katownik', (5.3, 0.05, 0.05), st, 0.004, (0, y, 2.06 + y * -0.07)))
    for sx in (-1, 1):
        r.append(tube('slupek', [(sx * 2.42, -1.62, 0.0), (sx * 2.42, -1.62, 2.16)], 0.03, st, 8))
    # furtka: rama z rur z krzyżulcem, uchylona na zawiasach
    gx = -2.42
    a = math.radians(-62)
    def gp(u, z):
        return (gx + u * math.cos(a), -1.66 + u * math.sin(a), z)
    r.append(tube('furtka', [gp(0, 0.12), gp(0, 1.8), gp(1.15, 1.8), gp(1.15, 0.12), gp(0, 0.12), gp(0, 0.2)], 0.018, st, 8))
    r.append(tube('krzyzulec', [gp(0, 0.12), gp(1.15, 1.8)], 0.012, st, 6))
    for k in range(1, 8):
        r.append(tube('pret', [gp(k * 0.144, 0.12), gp(k * 0.144, 1.8)], 0.006, st, 5))
    roof = join('Dach', r)
    weather([roof], 1024, 0.75, 0.7)
    export('ul_wiata')


def ul_przystanek():
    """wiata przystankowa: stalowa rama, dach z rynną, szyby w ramkach (Szyba), ławka z desek, rozkład jazdy, słupek ze znakiem, kosz"""
    reset()
    st = mat('stal', '3a4048', 0.5, 0.6)
    p = []
    for sx in (-1.95, 1.95):
        p.append(rbox('slup_t', (0.08, 0.08, 2.4), st, 0.01, (sx, 0.72, 1.2)))
        p.append(rbox('slup_p', (0.08, 0.08, 2.3), st, 0.01, (sx, -0.5, 1.15)))
        p.append(rbox('belka', (0.06, 1.5, 0.08), st, 0.008, (sx, 0.1, 2.38), (math.radians(4), 0, 0)))
    p.append(rbox('slup_s', (0.06, 0.06, 2.4), st, 0.01, (0, 0.72, 1.2)))
    p.append(rbox('dach', (4.3, 1.8, 0.05), mat('dach', '2a2f36', 0.6, 0.4), 0.012, (0, 0.05, 2.45), (math.radians(4), 0, 0)))
    p.append(tube('rynna', [(-2.15, 0.96, 2.5), (2.15, 0.96, 2.5)], 0.035, st, 8))
    p.append(tube('rura', [(2.1, 0.96, 2.48), (2.1, 0.8, 2.2), (2.03, 0.76, 0.1)], 0.022, st, 8))
    for z in (0.35, 2.2):
        p.append(rbox('rama_h', (3.9, 0.04, 0.04), st, 0.006, (0, 0.72, z)))
        p.append(rbox('rama_b', (0.04, 1.2, 0.04), st, 0.006, (-1.95, 0.12, z)))
    wood = mat('deska', '6b4a2e', 0.8)
    for k in range(3):
        p.append(rbox('siedzisko', (3.0, 0.11, 0.035), wood, 0.008, (0, 0.33 + k * 0.125, 0.5)))
    for x in (-1.3, 0.0, 1.3):
        p.append(tube('wspornik', [(x, 0.7, 0.3), (x, 0.3, 0.47), (x, 0.26, 0.47)], 0.018, st, 8))
    p.append(tube('slupek', [(2.6, -0.4, 0.0), (2.6, -0.4, 2.9)], 0.03, st, 8))
    sign = lathe('znak', [(0.0, 0.0), (0.26, 0.0), (0.26, 0.012), (0.0, 0.012)], mat('znak', 'e0b422', 0.5), 20)
    sign.rotation_euler = (R90, 0, 0)
    sign.location = (2.6, -0.44, 2.62)
    p.append(sign)
    p.append(rbox('rozklad', (0.36, 0.03, 0.5), mat('gablota', 'd8d6cf', 0.5), 0.008, (2.6, -0.44, 1.55)))
    p.append(lathe('kosz', [(0.0, 0.0), (0.13, 0.0), (0.16, 0.42), (0.17, 0.44), (0.15, 0.44), (0.12, 0.02), (0.0, 0.02)], mat('kosz', '2f5a40', 0.6, 0.3), 14, loc=(-2.2, -0.45, 0.55)))
    p.append(tube('kosz_s', [(-2.2, -0.45, 0.0), (-2.2, -0.45, 0.58)], 0.022, st, 8))
    p.append(rbox('posadzka', (4.6, 2.0, 0.05), mat('posadzka', '9a9892', 0.95), 0.008, (0, 0.1, 0.025)))
    ob = join('Wiata', p)
    weather([ob], 1024, 0.7, 0.6)
    g = [rbox('szyba_t%d' % k, (1.86, 0.012, 1.78), mat('szklo', '9fb4c0', 0.08, 0.2, 0.0, 0.32), 0.0, (-0.97 + k * 1.94, 0.72, 1.28), segs=1) for k in range(2)]
    g.append(rbox('szyba_b', (0.012, 1.14, 1.78), mat('szklo', '9fb4c0', 0.08, 0.2, 0.0, 0.32), 0.0, (-1.95, 0.12, 1.28), segs=1))
    join('Szyba', g)
    t = [text('bus', 'BUS', 0.16, mat('druk', '1a1a1a', 0.9), (2.6, -0.455, 2.56), (R90, 0, 0), 0.001)]
    t.append(text('linie', '12   27   N4', 0.045, mat('druk', '1a1a1a', 0.9), (2.6, -0.458, 1.72), (R90, 0, 0), 0.0006))
    for k in range(6):
        t.append(rbox('wiersz%d' % k, (0.28, 0.002, 0.012), mat('druk', '1a1a1a', 0.9), 0.0, (2.6, -0.4565, 1.64 - k * 0.045), segs=1))
    join('Napisy', t)
    export('ul_przystanek')


def ul_trzepak():
    """trzepak: dwie rury w tulejach z betonu, dwie poprzeczki ze spawanymi obejmami, wytarta farba"""
    reset()
    pt = mat('farba', '3d5a48', 0.6, 0.4)
    p = []
    for sx in (-1.2, 1.2):
        p.append(tube('slup', [(sx, 0, 0.0), (sx, 0, 2.03)], 0.034, pt, 10))
        p.append(lathe('stopa', [(0.0, 0.0), (0.14, 0.0), (0.12, 0.05), (0.05, 0.07), (0.0, 0.07)], mat('beton', 'a9a7a0', 0.9), 10, loc=(sx, 0, 0)))
        p.append(lathe('zaslepka', [(0.0, 0.0), (0.036, 0.0), (0.03, 0.02), (0.0, 0.024)], pt, 10, loc=(sx, 0, 2.03)))
        for z in (1.35, 1.98):
            p.append(lathe('obejma', [(0.036, z - 0.03), (0.046, z - 0.03), (0.046, z + 0.03), (0.036, z + 0.03)], pt, 10, loc=(sx, 0, 0)))
    for z in (1.35, 1.98):
        p.append(tube('poprzeczka', [(-1.2, 0, z), (1.2, 0, z)], 0.03, pt, 10))
    ob = join('Trzepak', p)
    weather([ob], 512, 0.5, 0.95)
    export('ul_trzepak')


def ul_hustawka():
    """huśtawka podwójna: stelaż w kształcie A, belka z zawiesiami, łańcuchy, siedziska z desek"""
    reset()
    pt = mat('farba', '7a2f24', 0.6, 0.4)
    ch = mat('lancuch', '6a6e72', 0.4, 0.8)
    p = []
    for sx in (-1.5, 1.5):
        for sy in (-1, 1):
            p.append(tube('noga', [(sx, sy * 0.85, 0.0), (sx, 0, 2.36)], 0.036, pt, 10))
            p.append(lathe('stopa', [(0.0, 0.0), (0.12, 0.0), (0.1, 0.04), (0.0, 0.05)], mat('beton', 'a9a7a0', 0.9), 10, loc=(sx, sy * 0.85, 0)))
        p.append(tube('rozporka', [(sx, -0.4, 1.25), (sx, 0.4, 1.25)], 0.022, pt, 8))
    p.append(tube('belka', [(-1.56, 0, 2.36), (1.56, 0, 2.36)], 0.04, pt, 10))
    wood = mat('deska', '6b5236', 0.85)
    for cx in (-0.7, 0.7):
        for d in (-0.2, 0.2):
            p.append(lathe('zawiesie', [(0.0, 0.0), (0.02, 0.0), (0.02, 0.05), (0.0, 0.05)], ch, 8, loc=(cx + d, 0, 2.29)))
            p.append(tube('lancuch', [(cx + d, 0, 2.3), (cx + d, 0.004, 1.5), (cx + d, 0, 0.62)], 0.007, ch, 5))
        p.append(rbox('siedzisko', (0.5, 0.2, 0.035), wood, 0.008, (cx, 0, 0.6)))
        p += bolts('sr', [(cx + d, sy * 0.06, 0.618) for d in (-0.2, 0.2) for sy in (-1, 1)], ch, 0.008, 0.005)
    ob = join('Hustawka', p)
    weather([ob], 1024, 0.5, 0.9)
    export('ul_hustawka')


def ul_zjezdzalnia():
    """zjeżdżalnia: podest z poręczami, drabinka ze szczeblami, ślizg z blachy z burtami i wypłaszczeniem na dole"""
    reset()
    pt = mat('farba', '5a6a7a', 0.55, 0.4)
    sl = mat('blacha', 'b4b9be', 0.3, 0.85)
    p = [rbox('podest', (0.9, 0.9, 0.05), pt, 0.008, (0, 0, 1.6))]
    for sx in (-0.42, 0.42):
        for sy in (-0.42, 0.42):
            p.append(tube('noga', [(sx, sy, 0.0), (sx, sy, 1.6)], 0.032, pt, 8))
        p.append(tube('porecz', [(sx, 0.42, 1.6), (sx, 0.42, 2.35), (sx, -0.42, 2.35), (sx, -0.42, 1.6)], 0.022, pt, 8))
        p.append(tube('porecz_s', [(sx, 0.42, 2.0), (sx, -0.42, 2.0)], 0.014, pt, 6))
        # podłużnice drabinki
        p.append(tube('podluznica', [(sx * 0.7, 0.45, 1.62), (sx * 0.7, 1.05, 0.0)], 0.024, pt, 8))
    for k in range(6):
        t = (k + 0.6) / 6.4
        p.append(tube('szczebel', [(-0.3, 0.45 + 0.6 * (1 - t), 1.62 * t), (0.3, 0.45 + 0.6 * (1 - t), 1.62 * t)], 0.016, pt, 8))
    fr = join('Stelaz', p)
    weather([fr], 1024, 0.5, 0.9)
    # ślizg: profil boczny wyciągnięty na szerokość
    prof = [(-0.45, 1.6), (-0.9, 1.42), (-2.6, 0.42), (-3.0, 0.3), (-3.45, 0.3)]
    s = []
    for i in range(len(prof) - 1):
        (y0, z0), (y1, z1) = prof[i], prof[i + 1]
        ln = math.hypot(y1 - y0, z1 - z0)
        an = math.atan2(z1 - z0, y1 - y0)
        s.append(rbox('dno%d' % i, (0.56, ln + 0.02, 0.012), sl, 0.003, (0, (y0 + y1) / 2, (z0 + z1) / 2), (an, 0, 0)))
    for sx in (-0.29, 0.29):
        s.append(tube('burta', [(sx, y, z + 0.07) for y, z in prof], 0.022, sl, 8))
    s.append(tube('podpora', [(0, -2.2, 0.0), (0, -2.2, 0.62)], 0.026, sl, 8))
    s.append(tube('podpora2', [(-0.25, -3.3, 0.0), (-0.25, -3.3, 0.3)], 0.022, sl, 8))
    s.append(tube('podpora3', [(0.25, -3.3, 0.0), (0.25, -3.3, 0.3)], 0.022, sl, 8))
    so = join('Slizg', s)
    weather([so], 1024, 0.45, 0.5)
    export('ul_zjezdzalnia')


def ul_kosz():
    """kosz uliczny na słupku: perforowany kubeł z obręczami, daszek-popielniczka, obejma (TintKubel)"""
    reset()
    st = mat('stal', '4a5158', 0.5, 0.6)
    p = [tube('slupek', [(0, 0.2, 0.0), (0, 0.2, 1.05)], 0.028, st, 8)]
    p.append(lathe('stopa', [(0.0, 0.0), (0.11, 0.0), (0.09, 0.04), (0.0, 0.05)], mat('beton', 'a9a7a0', 0.9), 10, loc=(0, 0.2, 0)))
    p.append(tube('obejma', [(0, 0.2, 0.86), (0, 0.1, 0.86)], 0.014, st, 6))
    p.append(tube('obejma2', [(0, 0.2, 0.56), (0, 0.1, 0.56)], 0.014, st, 6))
    fr = join('Slupek', p)
    weather([fr], 512, 0.6, 0.7)
    pt = mat('farba', 'c9cbc8', 0.6, 0.3)
    b = [lathe('kubel', [(0.0, 0.45), (0.13, 0.45), (0.165, 0.92), (0.175, 0.94), (0.155, 0.94), (0.122, 0.47), (0.0, 0.47)], pt, 16)]
    for z in (0.52, 0.68, 0.84):
        r = 0.13 + 0.035 * (z - 0.45) / 0.47
        b.append(lathe('obrecz', [(r, z - 0.012), (r + 0.008, z - 0.012), (r + 0.008, z + 0.012), (r, z + 0.012)], pt, 16))
    b.append(lathe('daszek', [(0.0, 1.04), (0.19, 0.99), (0.19, 0.975), (0.0, 1.02)], pt, 16))
    for k in range(3):
        a = k * math.tau / 3
        b.append(tube('wspornik', [(0.15 * math.cos(a), 0.15 * math.sin(a), 0.93), (0.16 * math.cos(a), 0.16 * math.sin(a), 0.99)], 0.008, pt, 5))
    bo = join('TintKubel', b)
    weather([bo], 512, 0.7, 0.7, (0.1, 0.09, 0.07))
    export('ul_kosz')


def ul_slupek():
    """słupek drogowy biało-czerwony z odblaskiem"""
    reset()
    p = [lathe('slupek', [(0.0, 0.0), (0.07, 0.0), (0.07, 0.03), (0.045, 0.05), (0.045, 0.82), (0.03, 0.86), (0.0, 0.87)], mat('bialy', 'e4e2dc', 0.6), 12)]
    for z in (0.3, 0.6):
        p.append(lathe('pas', [(0.046, z), (0.047, z), (0.047, z + 0.13), (0.046, z + 0.13)], mat('czerwony', 'b0281e', 0.6), 12))
    ob = join('Slupek', p)
    weather([ob], 512, 0.6, 0.6)
    export('ul_slupek')


ALL = (ul_latarnia, ul_lawka, ul_kontener, ul_wiata, ul_przystanek, ul_trzepak, ul_hustawka, ul_zjezdzalnia, ul_kosz, ul_slupek)
only = [a for a in sys.argv[sys.argv.index('--') + 1:]] if '--' in sys.argv else []
for f in ALL:
    if not only or f.__name__ in only:
        f()


def ul_wejscie():
    """wejście do klatki (ściana w y=0): stalowe drzwi z szybą zbrojoną, samozamykacz, pochwyt, domofon, betonowy daszek na wspornikach z lampą, stopień z wycieraczką"""
    reset()
    con = mat('beton', 'b4b2aa', 0.9)
    st = mat('stal', '3a3f45', 0.5, 0.6)
    p = []
    for sx in (-1, 1):
        p.append(rbox('oscieznica', (0.12, 0.22, 2.3), st, 0.008, (sx * 0.62, -0.06, 1.15)))
        p.append(rbox('wspornik', (0.1, 1.1, 0.14), con, 0.01, (sx * 1.05, -0.55, 2.62), (math.radians(-6), 0, 0)))
    p.append(rbox('nadproze', (1.36, 0.22, 0.14), st, 0.008, (0, -0.06, 2.3)))
    p.append(rbox('daszek', (2.7, 1.35, 0.13), con, 0.02, (0, -0.66, 2.78), (math.radians(-3), 0, 0)))
    p.append(rbox('okapnik', (2.74, 0.05, 0.05), mat('blacha', '6a6f75', 0.45, 0.6), 0.006, (0, -1.34, 2.72)))
    p.append(rbox('stopien', (2.4, 1.0, 0.16), con, 0.012, (0, -0.5, 0.08)))
    p.append(rbox('wycieraczka', (0.9, 0.5, 0.02), mat('krata', '2a2c30', 0.6, 0.5), 0.004, (0, -0.42, 0.168)))
    for k in range(9):
        p.append(rbox('pret', (0.86, 0.012, 0.012), mat('krata', '2a2c30', 0.6, 0.5), 0.002, (0, -0.63 + k * 0.052, 0.182)))
    # domofon i skrzynka na ogłoszenia
    p.append(rbox('domofon', (0.16, 0.035, 0.3), mat('domofon', '8a8f95', 0.4, 0.7), 0.008, (0.86, -0.02, 1.4)))
    for r in range(4):
        for c in range(3):
            p.append(rbox('przycisk', (0.028, 0.008, 0.028), mat('przycisk', '2a2c30', 0.6), 0.004, (0.82 + c * 0.04, -0.04, 1.27 + r * 0.04)))
    for k in range(4):
        p.append(rbox('glosnik', (0.1, 0.004, 0.006), mat('przycisk', '2a2c30', 0.6), 0.0, (0.86, -0.039, 1.47 + k * 0.016), segs=1))
    p.append(rbox('gablota', (0.5, 0.03, 0.62), mat('gablota', '5a4a3a', 0.6), 0.008, (-1.0, -0.015, 1.5)))
    for k in range(3):
        p.append(rbox('kartka%d' % k, (0.16 + 0.03 * k, 0.003, 0.2), mat('papier', 'e8e2cf', 0.95), 0.0, (-1.12 + k * 0.13, -0.033, 1.52 - 0.05 * (k % 2)), (0, 0.05 * (k - 1), 0), segs=1))
    p.append(lathe('oprawa', [(0.0, 0.0), (0.09, 0.0), (0.09, 0.03), (0.07, 0.05), (0.0, 0.05)], st, 14, loc=(0, -0.6, 2.67)))
    ob = join('Wejscie', p)
    weather([ob], 1024, 0.7, 0.55)
    d = [rbox('skrzydlo', (1.1, 0.05, 2.14), mat('lakier', 'c9cbc8', 0.5, 0.3), 0.006, (0, -0.06, 1.09))]
    d.append(rbox('przetloczenie', (0.86, 0.012, 0.72), mat('lakier', 'c9cbc8', 0.5, 0.3), 0.02, (0, -0.088, 0.52)))
    d.append(rbox('kopniak', (1.06, 0.008, 0.2), mat('kopniak', '9a9ea4', 0.35, 0.8), 0.004, (0, -0.09, 0.13)))
    d.append(rbox('ramka', (0.42, 0.014, 1.02), mat('lakier', 'c9cbc8', 0.5, 0.3), 0.006, (0.18, -0.088, 1.5)))
    dj = join('TintSkrzydlo', d)
    weather([dj], 1024, 0.6, 0.6)
    o = [rbox('szyba', (0.34, 0.008, 0.94), mat('szyba', '1c2a30', 0.1, 0.3), 0.0, (0.18, -0.092, 1.5), segs=1)]
    for k in range(7):
        o.append(rbox('drut', (0.34, 0.002, 0.004), mat('drut', '6a6f75', 0.5), 0.0, (0.18, -0.097, 1.1 + k * 0.135), segs=1))
    for k in range(3):
        o.append(rbox('drut_p', (0.004, 0.002, 0.94), mat('drut', '6a6f75', 0.5), 0.0, (0.07 + k * 0.11, -0.097, 1.5), segs=1))
    hd = mat('chrom', 'b9bcc2', 0.25, 0.9)
    o.append(tube('pochwyt', [(-0.38, -0.09, 0.9), (-0.38, -0.15, 0.93), (-0.38, -0.15, 1.3), (-0.38, -0.09, 1.33)], 0.016, hd, 10))
    o.append(lathe('zamek', [(0.0, 0.0), (0.022, 0.0), (0.022, 0.006), (0.0, 0.006)], hd, 12, loc=(-0.38, -0.089, 0.78)))
    o[-1].rotation_euler = (R90, 0, 0)
    o.append(rbox('samozamykacz', (0.24, 0.05, 0.06), hd, 0.008, (-0.25, -0.11, 2.12)))
    o.append(tube('ramie', [(-0.16, -0.12, 2.12), (0.1, -0.16, 2.2), (0.3, -0.06, 2.24)], 0.008, hd, 6))
    join('Okucia', o)
    lathe('Swiatlo', [(0.0, -0.06), (0.05, -0.05), (0.07, -0.02), (0.07, 0.0), (0.0, 0.0)], mat('klosz', 'fff0cc', 0.3, 0.0, 2.5), 14, loc=(0, -0.6, 2.67))
    export('ul_wejscie')


def ul_brama():
    """brama garażowa uchylna 2,5 × 2,25 m (ściana w y=0): tłoczone panele, rama z kątownika, klamka z zamkiem, wywietrzniki, uszczelka, numer"""
    reset()
    st = mat('rama', '3a3f45', 0.5, 0.6)
    p = []
    for sx in (-1, 1):
        p.append(rbox('slupek', (0.09, 0.14, 2.34), st, 0.006, (sx * 1.3, -0.04, 1.17)))
    p.append(rbox('nadproze', (2.7, 0.14, 0.12), st, 0.006, (0, -0.04, 2.31)))
    p.append(rbox('uszczelka', (2.5, 0.03, 0.03), mat('guma', '141416', 0.9), 0.008, (0, -0.07, 0.015)))
    fr = join('Rama', p)
    weather([fr], 512, 0.7, 0.7)
    pl = mat('blacha', 'c9cbc8', 0.5, 0.4)
    d = [rbox('plat', (2.5, 0.03, 2.24), pl, 0.004, (0, -0.07, 1.13))]
    for k in range(11):
        d.append(rbox('tloczenie', (2.42, 0.014, 0.1), pl, 0.02, (0, -0.088, 0.16 + k * 0.196)))
    for sx in (-0.83, 0.0, 0.83):
        d.append(rbox('wzmocnienie', (0.035, 0.02, 2.2), pl, 0.004, (sx, -0.095, 1.13)))
    dj = join('TintPlat', d)
    weather([dj], 1024, 0.75, 0.7, (0.12, 0.09, 0.06))
    o = [rbox('szyld', (0.09, 0.012, 0.16), mat('chrom', 'b9bcc2', 0.3, 0.9), 0.006, (0, -0.108, 0.95))]
    o.append(tube('klamka', [(0, -0.115, 0.98), (0, -0.15, 0.98), (0.1, -0.15, 0.98)], 0.01, mat('chrom', 'b9bcc2', 0.3, 0.9), 8))
    o.append(lathe('wkladka', [(0.0, 0.0), (0.012, 0.0), (0.012, 0.006), (0.0, 0.006)], mat('mosiadz', 'b89a4a', 0.3, 0.9), 10, loc=(0, -0.114, 0.9)))
    o[-1].rotation_euler = (R90, 0, 0)
    for sx in (-0.7, 0.7):
        for k in range(5):
            o.append(rbox('wywietrznik', (0.3, 0.004, 0.012), mat('cien', '0c0c0e', 0.9), 0.0, (sx, -0.097, 0.3 + k * 0.03), segs=1))
    join('Okucia', o)
    export('ul_brama')


if not only or 'ul_wejscie' in only:
    ul_wejscie()
if not only or 'ul_brama' in only:
    ul_brama()
