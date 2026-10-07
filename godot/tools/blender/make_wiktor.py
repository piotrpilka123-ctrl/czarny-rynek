"""Rzeczy Wiktora: skrzynka na pieniądze (stara skrzynka gazowa na murze, drzwiczki „Drzwi” uchylają się na zawiasie)
i paczka na start wsuwana pod drzwi — płaski worek z marihuaną („Ziolo”) i woreczek strunowy z amfetaminą („Feta”).
Przód = −Y, tył skrzynki leży na płaszczyźnie y = 0 (mur)."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
from lib import _finish
from mathutils import noise, Vector
import bmesh

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


def _poduszka(name, w, d, nx, ny, height, material, side=None):
    """zamknięta bryła o płaskim spodzie i wierzchu z funkcji height(u, v) (u, v od −1 do 1);
    wierzch dostaje UV „z góry” (cała tekstura = cały wierzch), boki i spód biorą kolor z rogu tekstury"""
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new('UVMap')
    top = [[bm.verts.new(((-1 + 2 * i / nx) * w / 2, (-1 + 2 * j / ny) * d / 2, max(0.0006, height(-1 + 2 * i / nx, -1 + 2 * j / ny)))) for i in range(nx + 1)] for j in range(ny + 1)]
    for j in range(ny):
        for i in range(nx):
            f = bm.faces.new((top[j][i], top[j][i + 1], top[j + 1][i + 1], top[j + 1][i]))
            f.smooth = True
            for lp in f.loops:
                lp[uvl].uv = (lp.vert.co.x / w + 0.5, lp.vert.co.y / d + 0.5)
    ring = [top[0][i] for i in range(nx + 1)] + [top[j][nx] for j in range(1, ny + 1)] + [top[ny][i] for i in range(nx - 1, -1, -1)] + [top[j][0] for j in range(ny - 1, 0, -1)]
    low = [bm.verts.new((v.co.x, v.co.y, 0.0)) for v in ring]
    n = len(ring)
    extra = [bm.faces.new((ring[k], low[k], low[(k + 1) % n], ring[(k + 1) % n])) for k in range(n)] + [bm.faces.new(low)]
    for f in extra:
        for lp in f.loops:
            lp[uvl].uv = (0.004, 0.004)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return _finish(me, name, material, True, None)


def _obraz(name, arr):
    """tablica numpy (wys × szer × 3, wartości jak na ekranie 0…1, wiersz 0 = dół) → obraz spakowany do pliku GLB"""
    import numpy as np
    h, w, _ = arr.shape
    img = bpy.data.images.new(name, w, h)
    img.pixels.foreach_set(np.concatenate([np.clip(arr, 0.0, 1.0), np.ones((h, w, 1))], axis=2).astype(np.float32).ravel())
    img.pack()
    return img


def _mat_obraz(name, img, rough):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bs = m.node_tree.nodes['Principled BSDF']
    t = m.node_tree.nodes.new('ShaderNodeTexImage')
    t.image = img
    m.node_tree.links.new(t.outputs['Color'], bs.inputs['Base Color'])
    bs.inputs['Roughness'].default_value = rough
    return m


def _komorki(np, rs, wp, hp, n, warp=0.0):
    """szum komórkowy: dla każdego piksela numer najbliższego ziarna, odległość do niego i do drugiego;
    warp > 0 wygina siatkę falami, żeby granice komórek nie były proste jak w witrażu"""
    ys, xs = np.mgrid[0:hp, 0:wp].astype(np.float32)
    if warp > 0.0:
        ph = rs.random(6) * math.tau
        xs, ys = (xs + warp * (np.sin(ys * 0.051 + ph[0]) + 0.6 * np.sin((xs + ys) * 0.083 + ph[1]) + 0.35 * np.sin(ys * 0.19 + ph[2])),
                  ys + warp * (np.sin(xs * 0.047 + ph[3]) + 0.6 * np.sin((xs - ys) * 0.079 + ph[4]) + 0.35 * np.sin(xs * 0.21 + ph[5])))
    pts = rs.random((n, 2)) * [wp, hp]
    dd = np.sqrt((xs[..., None] - pts[:, 0]) ** 2 + (ys[..., None] - pts[:, 1]) ** 2)
    two = np.partition(dd, 1, axis=2)
    return np.argmin(dd, axis=2), two[..., 0], two[..., 1]


def _smugi(np, rs, arr, n, sila, dlug=(0.25, 0.8), gr=(1.2, 3.0)):
    """jasne smugi — zmarszczki folii łapiące światło"""
    hp, wp, _ = arr.shape
    ys, xs = np.mgrid[0:hp, 0:wp].astype(np.float32)
    for _i in range(n):
        x0, y0 = rs.random() * wp, rs.random() * hp
        a = rs.random() * math.pi
        ln = rs.uniform(*dlug) * wp
        w = rs.uniform(*gr)
        dx, dy = math.cos(a), math.sin(a)
        t = (xs - x0) * dx + (ys - y0) * dy
        dist = np.abs((xs - x0) * -dy + (ys - y0) * dx)
        k = np.exp(-(dist / w) ** 2) * np.clip(1.0 - np.abs(t) / (ln / 2), 0.0, 1.0)
        arr += (k * sila * rs.uniform(0.5, 1.0))[..., None]


def paczka_start():
    """Paczka od Wiktora, tak jak chodzi po mieście: zwarty pakunek 19 × 12 × 2 cm zawinięty w szary papier
    pakowy — pognieciony, z zakładkami na końcach — i okręcony brązową taśmą na krzyż; na wierzchu dopisek markerem.
    Co jest w środku, widać dopiero po otwarciu (okno paczki). Węzeł „Ziolo” to cały pakunek (wsuwa się pod drzwi)."""
    import numpy as np
    reset()
    rs = np.random.default_rng(23)
    W, Dd, Hh = 0.19, 0.12, 0.021
    # --- tekstura papieru: szarobrązowy, z włóknami, zagnieceniami (jasne grzbiety, ciemne doliny) i przetarciami
    wp, hp = 760, 480
    ys, xs = np.mgrid[0:hp, 0:wp].astype(np.float32)
    base = np.zeros((hp, wp, 3), dtype=np.float32) + np.array([0.60, 0.50, 0.37], dtype=np.float32)
    base *= (1.0 + 0.018 * np.sin(xs * 0.9 + np.sin(ys * 0.05) * 3.0))[..., None]            # prążki papieru pakowego
    base *= rs.uniform(0.93, 1.05, (hp, wp, 1)).astype(np.float32)                          # włókna
    for _i in range(34):                                                                   # zagniecenia: jasna i ciemna kreska obok siebie
        x0, y0 = rs.random() * wp, rs.random() * hp
        a = rs.random() * math.pi
        ln = rs.uniform(0.12, 0.6) * wp
        dx, dy = math.cos(a), math.sin(a)
        t = (xs - x0) * dx + (ys - y0) * dy
        dist = (xs - x0) * -dy + (ys - y0) * dx
        k = np.clip(1.0 - np.abs(t) / (ln / 2), 0.0, 1.0)
        base += (np.exp(-((dist - 1.2) / 1.3) ** 2) * k * 0.10)[..., None]
        base -= (np.exp(-((dist + 1.4) / 1.8) ** 2) * k * 0.09)[..., None]
    for _i in range(9):                                                                    # tłustsze plamy i przetarcia
        cx, cy, rr = rs.random() * wp, rs.random() * hp, rs.uniform(18, 60)
        base *= (1.0 - 0.10 * np.exp(-(((xs - cx) ** 2 + (ys - cy) ** 2) / (rr * rr))))[..., None]
    base[:4, :4] = np.array([0.5, 0.42, 0.31])
    uu, vv = xs / wp * 2 - 1, ys / hp * 2 - 1
    # zakładki na końcach: papier złożony „w kopertę” — dwie skośne krawędzie schodzące się do środka krótszego boku
    for sx in (-1, 1):
        for sy in (-1, 1):
            # prosta od rogu (sx, sy) do punktu (sx·0.62, 0)
            d = np.abs((vv - sy) * (0.62 - 1.0) * sx - (uu - sx) * (0.0 - sy)) / math.hypot(0.38, 1.0)
            on = (np.abs(uu) > 0.6) & (vv * sy > 0)
            base -= (np.exp(-(d / 0.012) ** 2) * 0.16 * on)[..., None]
            base += (np.exp(-((d - 0.02) / 0.012) ** 2) * 0.07 * on)[..., None]
    # brązowa taśma pakowa: dwa pasy wzdłuż i jeden w poprzek; lekko prześwituje papier, brzegi łapią światło
    tape = np.array([0.42, 0.27, 0.12], dtype=np.float32)
    def pas(mask, edge):
        k = 0.9 + 0.05 * np.sin(xs * 0.07 + ys * 0.045)
        base[mask] = (base[mask] * 0.25 + tape * 0.75) * k[mask][..., None]
        base[edge] = base[edge] * 0.55 + np.array([0.75, 0.62, 0.42]) * 0.45
    for v0 in (-0.42, 0.46):
        m = (np.abs(vv - v0) < 0.15) & (np.abs(uu) < 0.985)
        e = (np.abs(np.abs(vv - v0) - 0.15) < 0.012) & (np.abs(uu) < 0.985)
        pas(m, e)
    m2 = (np.abs(uu - 0.3) < 0.1) & (np.abs(vv) < 0.985)
    e2 = (np.abs(np.abs(uu - 0.3) - 0.1) < 0.008) & (np.abs(vv) < 0.985)
    pas(m2, e2)
    _smugi(np, rs, base, 10, 0.05, (0.1, 0.4), (1.0, 2.0))
    base[:4, :4] = np.array([0.5, 0.42, 0.31])
    papier = _mat_obraz('papier_pakowy', _obraz('paczka_papier_kolor', base), 0.6)

    def hz(u, v):
        # poduszka o stromych bokach, lekko wybrzuszona; nierówna, bo w środku leżą woreczki
        edge = (1.0 - abs(u) ** 34) * (1.0 - abs(v) ** 26)
        x, y = u * W / 2, v * Dd / 2
        bump = 0.5 + 0.5 * noise.noise(Vector((x * 34, y * 34, 2.1)))
        fine = noise.noise(Vector((x * 150, y * 150, 5.5)))
        return 0.0008 + edge * (Hh * 0.78 + Hh * 0.22 * bump + 0.0006 * fine)

    paczka = _poduszka('PaczkaPapier', W, Dd, 60, 38, hz, papier)
    nap = join('PaczkaNapis', [text('dopisek', 'K.', 0.024, mat('marker', '15161a', 0.6), (-0.035, 0.001, hz(-0.37, 0.02) + 0.0009), (0, 0, 0.12), 0.0002)])
    z = empty('Ziolo')
    for o in (paczka, nap):
        o.parent = z
    export('paczka_start')


only = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
if not only or 'wiktor_skrzynka' in only:
    wiktor_skrzynka()
if not only or 'paczka_start' in only:
    paczka_start()
