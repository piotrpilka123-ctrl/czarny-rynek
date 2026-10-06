"""Rzeczy Wiktora: skrzynka na pieniądze (stara skrzynka gazowa na murze, drzwiczki „Drzwi” uchylają się na zawiasie)
i paczka na start wsuwana pod drzwi — płaski worek z marihuaną („Ziolo”) i woreczek strunowy z amfetaminą („Feta”).
Przód = −Y, tył skrzynki leży na płaszczyźnie y = 0 (mur)."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
from lib import _finish
from mathutils import noise

R90 = math.radians(90)
rnd = random.Random(7)


def wiktor_skrzynka():
    """skrzynka gazowa 46×62×20 cm na wysokości 0,95 m: korpus z daszkiem, drzwiczki z żaluzją i skoblem,
    kłódka wisi otwarta, rura w dół do ziemi, naklejka z numerem, zacieki rdzy"""
    reset()
    st = mat('blacha', '7d8a86', 0.6, 0.5)
    dark = mat('ciemne', '2c3130', 0.7, 0.4)
    yel = mat('zolty', 'c9a326', 0.6)
    z0, W, H, Dp = 0.95, 0.46, 0.62, 0.2
    p = [rbox('korpus', (W, Dp, H), st, 0.012, (0, -Dp / 2, z0 + H / 2))]
    p.append(rbox('daszek', (W + 0.06, Dp + 0.05, 0.02), st, 0.006, (0, -Dp / 2 - 0.012, z0 + H + 0.012), (math.radians(-7), 0, 0)))
    p.append(rbox('wnetrze', (W - 0.05, 0.01, H - 0.06), dark, 0.0, (0, -Dp + 0.012, z0 + H / 2), segs=1))
    # rura gazowa w dół i uchwyty do muru
    p.append(tube('rura', [(0.12, -0.06, z0), (0.12, -0.06, 0.25), (0.12, -0.03, 0.08), (0.12, -0.03, 0.0)], 0.022, yel, 10))
    for z in (0.3, 0.7):
        p.append(rbox('obejma', (0.07, 0.02, 0.03), dark, 0.004, (0.12, -0.015, z)))
    for sx in (-1, 1):
        for sz in (0.08, H - 0.08):
            p.append(rbox('ucho', (0.05, 0.012, 0.04), st, 0.003, (sx * (W / 2 + 0.02), -0.006, z0 + sz)))
    p += bolts('sr', [(sx * (W / 2 + 0.02), -0.014, z0 + sz) for sx in (-1, 1) for sz in (0.08, H - 0.08)], dark, 0.008, 0.004, 'Y')
    ob = join('Skrzynka', p)
    # drzwiczki: osobny obiekt z osią na lewej krawędzi (zawias), żeby gra mogła je uchylić
    d = [rbox('skrzydlo', (W - 0.03, 0.012, H - 0.03), st, 0.004, (W / 2 - 0.015, -0.006, H / 2 - 0.015))]
    for k in range(6):
        d.append(rbox('zaluzja', (W - 0.14, 0.01, 0.014), dark, 0.002, (W / 2 - 0.015, -0.014, 0.1 + k * 0.03), (math.radians(28), 0, 0)))
    d.append(rbox('ramka', (W - 0.1, 0.006, 0.22), st, 0.003, (W / 2 - 0.015, -0.011, 0.175)))
    d.append(rbox('tabliczka', (0.15, 0.004, 0.09), yel, 0.0, (W / 2 - 0.015, -0.014, H - 0.14), segs=1))
    d.append(text('gaz', 'GAS', 0.05, dark, (W / 2 - 0.015, -0.017, H - 0.155)))
    d.append(text('nr', '7/B', 0.028, dark, (W / 2 - 0.015, -0.014, H - 0.26)))
    d.append(rbox('skobel', (0.05, 0.012, 0.03), dark, 0.003, (W - 0.05, -0.016, H / 2)))
    d.append(tube('klodka_palak', [(W - 0.05, -0.024, H / 2 - 0.005), (W - 0.05, -0.03, H / 2 - 0.03), (W - 0.035, -0.03, H / 2 - 0.045), (W - 0.02, -0.03, H / 2 - 0.03)], 0.004, dark, 6))
    d.append(rbox('klodka', (0.036, 0.016, 0.03), mat('mosiadz', '9a7a30', 0.4, 0.7), 0.004, (W - 0.022, -0.03, H / 2 - 0.058), (0, math.radians(12), 0)))
    for z in (0.08, H - 0.1):
        d.append(tube('zawias', [(0.0, -0.012, z - 0.03), (0.0, -0.012, z + 0.03)], 0.008, dark, 6))
    dr = join('Drzwi', d)
    weather([ob, dr], 1024, 0.75, 0.7, (0.2, 0.11, 0.05))
    # join zostawia środek obiektu w pierwszej części — przenosimy go na zawias (lewa krawędź, dół),
    # a potem stawiamy drzwiczki na froncie korpusu
    bpy.context.view_layer.update()
    for o in bpy.context.selected_objects:
        o.select_set(False)
    dr.select_set(True)
    bpy.context.view_layer.objects.active = dr
    bpy.context.scene.cursor.location = (0.0, 0.0, 0.0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    dr.location = (-W / 2 + 0.015, -Dp, z0 + 0.015)
    export('wiktor_skrzynka')


def _worek(name, w, d, h, film):
    """płaski foliowy woreczek: miękka poduszka z zagnieceniami"""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=6, use_grid_fill=True)
    for v in bm.verts:
        x, y, z = v.co.x * 2, v.co.y * 2, v.co.z * 2
        # poduszka: grubość spada do zera na zgrzewach
        k = max(0.0, 1.0 - abs(x) ** 3.0) * max(0.0, 1.0 - abs(y) ** 3.0)
        zz = (0.5 * z) * h * (0.12 + 0.88 * k)
        n = noise.noise(Vector((x * 2.3, y * 2.3, 1.7 if z > 0 else -3.1))) * h * 0.16 * k
        v.co = Vector((x * w / 2, y * d / 2, zz + (n if z > 0 else 0.0) + h * 0.5))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return _finish(me, name, film, True, None)


def paczka_start():
    """dwa płaskie woreczki, które mieszczą się w szparze pod drzwiami: marihuana (zielone szyszki pod folią,
    biała naklejka) i woreczek strunowy z bladożółtym proszkiem (czerwony pasek zamka)"""
    reset()
    film = mat('folia', 'e8f0ec', 0.1, 0.0, 0.0, 0.14)
    green = mat('susz', '3f5a22', 0.95)
    green2 = mat('susz2', '5d7a30', 0.95)
    hair = mat('wloski', 'b0702a', 0.9)
    # --- worek z marihuaną 20 × 13 cm, gruby na 1,6 cm
    W, Dd, Hh = 0.2, 0.13, 0.016
    parts = []
    for i in range(16):
        x = rnd.uniform(-W / 2 + 0.032, W / 2 - 0.032)
        y = rnd.uniform(-Dd / 2 + 0.03, Dd / 2 - 0.038)
        r = rnd.uniform(0.013, 0.021)
        # szyszka: nieregularna grudka (kula z szumem), przypłaszczona folią
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=2, radius=1.0)
        sd = rnd.uniform(0, 50)
        for v in bm.verts:
            k = 1.0 + 0.38 * noise.noise(v.co * 2.6 + Vector((sd, sd * 0.7, 3.0))) + 0.16 * noise.noise(v.co * 7.0 + Vector((sd, 1.0, sd)))
            v.co = Vector((v.co.x * r * k * rnd.uniform(0.9, 1.25), v.co.y * r * k, (v.co.z * 0.5 + 0.5) * r * 0.6 * k))
        me = bpy.data.meshes.new('szyszka')
        bm.to_mesh(me)
        bm.free()
        b = _finish(me, 'szyszka', green if i % 3 else green2, True, None)
        b.location = (x, y, 0.0015)
        b.rotation_euler = (0, 0, rnd.uniform(0, 6.28))
        parts.append(b)
        for h in range(3):
            a = rnd.uniform(0, 6.28)
            parts.append(rbox('wlosek', (r * 0.55, 0.0012, 0.0012), hair, 0.0, (x + math.cos(a) * r * 0.45, y + math.sin(a) * r * 0.45, r * 0.62), (0, rnd.uniform(-0.5, 0.5), a), segs=1))
    parts.append(rbox('zgrzew', (W, 0.012, 0.0012), mat('zgrzew', 'c8d2ce', 0.3), 0.0, (0, Dd / 2 - 0.008, 0.002), segs=1))
    parts.append(rbox('naklejka', (0.05, 0.03, 0.0008), mat('naklejka', 'f0ece0', 0.8), 0.0, (-W / 2 + 0.045, -Dd / 2 + 0.03, Hh * 0.93), segs=1))
    parts.append(tube('kreska', [(-W / 2 + 0.028, -Dd / 2 + 0.032, Hh * 0.93 + 0.0012), (-W / 2 + 0.04, -Dd / 2 + 0.027, Hh * 0.93 + 0.0012), (-W / 2 + 0.05, -Dd / 2 + 0.034, Hh * 0.93 + 0.0012), (-W / 2 + 0.062, -Dd / 2 + 0.028, Hh * 0.93 + 0.0012)], 0.0008, mat('tusz', '1a1a4c', 0.8), 4))
    join('ZioloSrodek', parts)
    wz = _worek('ZioloFolia', W, Dd, Hh, film)
    z = empty('Ziolo')
    for o in list(bpy.context.scene.objects):
        if o.name in ('ZioloSrodek', 'ZioloFolia'):
            o.parent = z
    # --- woreczek strunowy z amfetaminą 10 × 7 cm
    w2, d2, h2 = 0.1, 0.07, 0.011
    pw = mat('proszek', 'e9e0b6', 0.9)
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=12, y_segments=9, size=0.5)
    for v in bm.verts:
        x, y = v.co.x * 2, v.co.y * 2
        k = max(0.0, 1.0 - abs(x) ** 2.4) * max(0.0, 1.0 - abs(y + 0.15) ** 2.2)
        v.co = Vector((x * (w2 / 2 - 0.008), y * (d2 / 2 - 0.012) - 0.004, 0.001 + h2 * 0.72 * k * (0.75 + 0.25 * noise.noise(Vector((x * 4, y * 4, 0.3))))))
    me = bpy.data.meshes.new('FetaSrodek')
    bm.to_mesh(me)
    bm.free()
    fs = _finish(me, 'FetaSrodek', pw, True, None)
    ff = _worek('FetaFolia', w2, d2, h2, film)
    zam = join('FetaZamek', [rbox('zamek', (w2, 0.004, 0.0016), mat('zamek', 'c0392b', 0.5), 0.0, (0, d2 / 2 - 0.012, h2 * 0.2), segs=1),
                              rbox('zamek2', (w2, 0.002, 0.0016), mat('zamek', 'c0392b', 0.5), 0.0, (0, d2 / 2 - 0.018, h2 * 0.2), segs=1)])
    f = empty('Feta')
    for o in (fs, ff, zam):
        o.parent = f
    export('paczka_start')


only = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
if not only or 'wiktor_skrzynka' in only:
    wiktor_skrzynka()
if not only or 'paczka_start' in only:
    paczka_start()
