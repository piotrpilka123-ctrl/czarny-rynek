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
    """Towar wsuwany pod drzwi, tak jak chodzi po mieście: płaska paczka próżniowa z marihuaną („Ziolo”) — folia
    przyssana do sprasowanych szyszek, żebrowane zgrzewy, pasek srebrnej taśmy z dopiskiem markerem — leżąca na
    kawałku szarego papieru, w który była zawinięta; do tego mały woreczek strunowy z wilgotną, kremową pastą
    amfetaminy („Feta”) ściśnięty dwiema gumkami recepturkami. Obie rzeczy mieszczą się w szparze pod drzwiami."""
    import numpy as np
    reset()
    rs = np.random.default_rng(11)
    ink = mat('marker', '15161a', 0.6)
    # --- paczka próżniowa 20 × 13 cm, gruba na 1,5 cm
    W, Dd = 0.2, 0.13
    EU, EV = 0.86, 0.9                       # gdzie kończy się towar, a zaczyna zgrzew / kołnierz folii

    def hz(u, v):
        if abs(u) >= EU or abs(v) >= EV:
            return 0.0012
        body = (1.0 - (abs(u) / EU) ** 6) * (1.0 - (abs(v) / EV) ** 6)
        x, y = u * W / 2, v * Dd / 2
        buds = 0.5 + 0.5 * noise.noise(Vector((x * 55, y * 55, 1.7)))          # grudki szyszek co ok. 2 cm
        fine = noise.noise(Vector((x * 210, y * 210, 4.2)))                    # zmarszczki przyssanej folii
        return 0.0012 + body * (0.0072 + 0.0058 * buds + 0.0013 * fine)

    # tekstura: sprasowane szyszki (komórki w kilku zieleniach, ciemne szczeliny), rude włoski, szron żywicy, połysk folii
    wp, hp = 640, 416
    NB = 230
    cell, d1, d2 = _komorki(np, rs, wp, hp, NB, 7.0)
    pal = np.array([[0.19, 0.27, 0.11], [0.25, 0.33, 0.14], [0.31, 0.38, 0.17], [0.22, 0.29, 0.15], [0.35, 0.39, 0.2], [0.27, 0.31, 0.12]])
    tone = pal[rs.integers(0, len(pal), NB)] * rs.uniform(0.82, 1.12, (NB, 1))
    img = tone[cell]
    img *= (0.6 + 0.4 * np.clip((d2 - d1) / 13.0, 0.0, 1.0) ** 0.7)[..., None]    # miękkie szczeliny między szyszkami
    img *= (0.88 + 0.22 * np.clip(1.0 - d1 / 20.0, 0.0, 1.0))[..., None]          # środek szyszki jaśniejszy
    # drobniejsza struktura w środku szyszek: listki i kielichy (druga, gęsta siatka komórek)
    c2, f1, f2 = _komorki(np, rs, wp, hp, 1400, 3.0)
    img *= (0.84 + 0.16 * np.clip((f2 - f1) / 3.5, 0.0, 1.0))[..., None]
    img *= rs.uniform(0.86, 1.1, (1400, 1))[c2]
    img *= rs.uniform(0.9, 1.08, (hp, wp, 1))                                      # ziarno
    for _i in range(520):                                                          # rude włoski
        x0, y0, a, ln = rs.random() * wp, rs.random() * hp, rs.random() * math.tau, rs.uniform(5, 13)
        for t in range(int(ln)):
            xi, yi = int(x0 + math.cos(a) * t), int(y0 + math.sin(a) * t)
            if 0 <= xi < wp and 0 <= yi < hp:
                img[yi, xi] = img[yi, xi] * 0.35 + np.array([0.55, 0.33, 0.12]) * 0.65
    fr = rs.integers(0, [hp, wp], (2600, 2))
    img[fr[:, 0], fr[:, 1]] += 0.16                                                # szron żywicy
    img = img * 0.9 + np.array([0.78, 0.83, 0.8]) * 0.1                            # mleczna folia na wierzchu
    _smugi(np, rs, img, 26, 0.16)
    ys, xs = np.mgrid[0:hp, 0:wp].astype(np.float32)
    uu, vv = xs / wp * 2 - 1, ys / hp * 2 - 1
    zebra = 0.7 + 0.09 * np.sin(xs * 0.9)
    seal = (np.abs(uu) >= EU - 0.01)
    img[seal] = (np.stack([zebra * 0.97, zebra * 1.02, zebra], axis=2))[seal]
    kol = (np.abs(vv) >= EV - 0.01) & ~seal
    img[kol] = np.array([0.7, 0.74, 0.72])
    img[:4, :4] = np.array([0.66, 0.7, 0.68])
    paczka = _poduszka('ZioloSrodek', W, Dd, 64, 42, hz, _mat_obraz('susz_folia', _obraz('paczka_ziolo_kolor', img), 0.24))
    paczka.location = (0, 0, 0.0016)
    # --- reszta: żebra zgrzewu, srebrna taśma przez jeden koniec, szary papier pod spodem (z wypalonym brudem)
    cz = []
    zg = mat('zgrzew', 'c9d1cc', 0.22)
    for sx in (-1, 1):
        for k in range(5):
            cz.append(rbox('zebro', (0.0013, Dd - 0.004, 0.0006), zg, 0.0, (sx * (W / 2 - 0.003 - k * 0.0026), 0, 0.0031), segs=1))
    cz.append(rbox('tasma', (0.03, Dd * 0.5, 0.0009), mat('tasma', '8a9094', 0.42, 0.35), 0.0002, (W / 2 - 0.016, -0.012, 0.0036), (0, 0, 0.05), segs=1))
    pap = mat('papier', 'b3a68c', 0.92)

    def hpap(u, v):
        x, y = u * 0.135, v * 0.095
        z = 0.0007 + 0.0006 * (0.5 + 0.5 * noise.noise(Vector((x * 38, y * 38, 6.0)))) + 0.0005 * abs(noise.noise(Vector((x * 120, y * 14, 1.0))))
        k = max(0.0, u - 0.72) + max(0.0, v - 0.66)                            # jeden lekko odstający róg
        return z + 0.011 * max(0.0, k - 0.2)

    papier = _poduszka('papier', 0.27, 0.19, 30, 22, hpap, pap)
    papier.rotation_euler = (0, 0, -0.16)
    papier.location = (0.012, -0.006, 0.0)
    cz.append(papier)
    zr = join('ZioloReszta', cz)
    weather([zr], 512, 0.5, 0.3, (0.12, 0.1, 0.07))
    zn = join('ZioloNapis', [rbox('karteczka', (0.022, 0.036, 0.0005), mat('karteczka', 'f0ece0', 0.8), 0.0, (W / 2 - 0.016, -0.014, 0.0042), (0, 0, 0.05), segs=1),
                             text('dopisek', '8g', 0.014, ink, (W / 2 - 0.0165, -0.014, 0.0048), (0, 0, 0.05 + R90), 0.0002)])
    z = empty('Ziolo')
    for o in (paczka, zr, zn):
        o.parent = z
    # --- woreczek strunowy 8,5 × 6 cm: dół wypchany pastą, góra pusta z zamkiem, dwie recepturki
    w2, d2 = 0.085, 0.06
    FV = 0.42                                # powyżej tej wysokości woreczek jest pusty (zamek)

    def hf(u, v):
        if abs(u) >= 0.9 or v >= FV or v <= -0.93:
            return 0.0011
        body = (1.0 - (abs(u) / 0.9) ** 4) * (1.0 - (abs(v + 0.255) / 0.675) ** 4)
        x, y = u * w2 / 2, v * d2 / 2
        lumps = 0.5 + 0.5 * noise.noise(Vector((x * 95, y * 95, 3.3)))
        return 0.0011 + body * (0.0042 + 0.0042 * lumps + 0.0008 * noise.noise(Vector((x * 300, y * 300, 0.6))))

    wq, hq = 320, 224
    cell, e1, e2 = _komorki(np, rs, wq, hq, 70, 5.0)
    tone = np.array([[0.9, 0.86, 0.73]]) * rs.uniform(0.9, 1.05, (70, 1)) * np.array([1.0, 1.0, 1.0]) + rs.uniform(-0.02, 0.02, (70, 3))
    fi = tone[cell]
    fi *= (0.86 + 0.14 * np.clip((e2 - e1) / 9.0, 0.0, 1.0) ** 0.7)[..., None]     # grudki pasty
    fi *= rs.uniform(0.95, 1.04, (hq, wq, 1))
    wet = np.clip(1.0 - e1 / 9.0, 0.0, 1.0)[..., None] * (rs.random((hq, wq, 1)) < 0.5)
    fi = fi * (1.0 - 0.12 * wet) + np.array([0.82, 0.74, 0.5]) * 0.12 * wet         # wilgotne, żółtawe plamy
    _smugi(np, rs, fi, 12, 0.1, (0.2, 0.6), (1.0, 2.2))
    ys, xs = np.mgrid[0:hq, 0:wq].astype(np.float32)
    uu, vv = xs / wq * 2 - 1, ys / hq * 2 - 1
    pusty = (np.abs(uu) >= 0.88) | (vv >= FV - 0.02) | (vv <= -0.91)
    folia = np.zeros((hq, wq, 3)) + np.array([0.72, 0.76, 0.74])
    _smugi(np, rs, folia, 8, 0.12, (0.2, 0.7), (1.0, 2.0))
    fi[pusty] = folia[pusty]
    fi[:4, :4] = np.array([0.7, 0.74, 0.72])
    fs = _poduszka('FetaSrodek', w2, d2, 34, 26, hf, _mat_obraz('pasta_folia', _obraz('paczka_feta_kolor', fi), 0.24))
    fc = []
    for dv in (0.56, 0.68):
        fc.append(rbox('zamek', (w2 - 0.004, 0.0016, 0.001), mat('zamek', '2a6ac8', 0.45), 0.0, (0, dv * d2 / 2, 0.0015), segs=1))
    gum = mat('gumka', 'a8261c', 0.6)
    for gx in (-0.014, 0.012):
        u0 = gx / (w2 / 2)
        pts = [(gx + 0.001 * math.sin(j * 1.3), (-1 + 2 * j / 14) * d2 / 2, hf(u0, -1 + 2 * j / 14) + 0.0007) for j in range(15)]
        fc.append(tube('gumka', pts, 0.0009, gum, 5))
    fr2 = join('FetaReszta', fc)
    f = empty('Feta')
    fs.parent = f
    fr2.parent = f
    export('paczka_start')


only = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
if not only or 'wiktor_skrzynka' in only:
    wiktor_skrzynka()
if not only or 'paczka_start' in only:
    paczka_start()
