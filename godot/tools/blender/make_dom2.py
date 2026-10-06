"""Mieszkanie — druga partia, w jednym stylu z biurkiem (okleina dębowa, czarna stal, szara tkanina):
drzwi wewnętrzne, wieszak z kurtką, stolik kawowy, kanapa z poduszkami, szafka RTV, telewizor, łóżko; do tego torba sportowa z prologu.
Przód = −Y. „Tint…” barwi gra, „Ekran…” świeci."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
import bmesh

R90 = math.radians(90)
rnd = random.Random(15)
OAK = 'd4bd98'


def grid_mesh(name, nu, nv, fn, material, close_u=False, smooth=True):
    """siatka z funkcji fn(u, v) -> (x, y, z); close_u zamyka ją w rurę"""
    bm = bmesh.new()
    rows = []
    for j in range(nv + 1):
        row = [bm.verts.new(fn(i / nu, j / nv)) for i in range(nu if close_u else nu + 1)]
        rows.append(row)
    n = len(rows[0])
    for j in range(nv):
        for i in range(n if close_u else n - 1):
            bm.faces.new((rows[j][i], rows[j][(i + 1) % n], rows[j + 1][(i + 1) % n], rows[j + 1][i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    me.materials.append(material)
    for p in me.polygons:
        p.use_smooth = smooth
    return ob


def strap(name, pts, width, material, axis_z=0.14, thick=0.004):
    """płaska taśma w przestrzeni: szerokość w poprzek kierunku biegu, grubość od osi torby na zewnątrz"""
    bm = bmesh.new()
    rows = []
    P = [Vector(p) for p in pts]
    for i, p in enumerate(P):
        t = (P[min(i + 1, len(P) - 1)] - P[max(i - 1, 0)]).normalized()
        nr = Vector((0, p.y, p.z - axis_z))
        nr = nr - t * nr.dot(t)
        if nr.length < 1e-4:
            nr = Vector((0, 0, 1))
        nr.normalize()
        b = t.cross(nr).normalized()
        rows.append((bm.verts.new(p - b * width / 2), bm.verts.new(p + b * width / 2), bm.verts.new(p + b * width / 2 + nr * thick), bm.verts.new(p - b * width / 2 + nr * thick)))
    for i in range(len(rows) - 1):
        a, c = rows[i], rows[i + 1]
        for k in range(4):
            bm.faces.new((a[k], a[(k + 1) % 4], c[(k + 1) % 4], c[k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    me.materials.append(material)
    return ob


def torba():
    """torba sportowa 66 cm: miękki, zapadnięty korpus, zamek z suwakiem pod listwami, dwa ucha z taśmy z owijką, taśmy dookoła,
    pasek na ramię z poduszką i karabińczykami, kieszeń boczna, lamówki na szczytach"""
    reset()
    L, RY, RZ = 0.66, 0.155, 0.15
    cloth = mat('plotno', '20242e', 0.92)
    web = mat('tasma', '0e1014', 0.85)
    met = mat('metal', '8a8f96', 0.35, 0.85)

    def body(u, v):
        x = (u - 0.5) * L
        e = abs(u - 0.5) * 2.0
        k = (1.0 - e ** 5) ** 0.3 if e < 1.0 else 0.0
        a = v * math.tau
        ca, sa = math.cos(a), math.sin(a)
        sq = 3.2
        cy = (abs(ca) ** (2.0 / sq)) * (1 if ca >= 0 else -1)
        cz = (abs(sa) ** (2.0 / sq)) * (1 if sa >= 0 else -1)
        sag = 1.0 - 0.16 * (1.0 - e * e) * max(0.0, cz)
        y = cy * RY * k * (1.0 + 0.05 * math.sin(x * 23.0))
        z = RZ + cz * RZ * k * sag
        z += 0.012 * math.sin(x * 31.0 + a * 2.0) * max(0.0, cz) * k
        return (x, y, max(0.0, z))
    b = grid_mesh('korpus', 26, 28, lambda u, v: body(u, v), cloth, False)
    # (siatka zamknięta po obwodzie przez pokrycie v=0 i v=1 tym samym punktem)
    p = [b]
    top = lambda x: body(x / L + 0.5, 0.25)[2]
    for sy in (-1, 1):
        p.append(strap('listwa', [(x, sy * 0.012, top(x) + 0.004) for x in [(-0.27 + k * 0.03) for k in range(19)]], 0.016, cloth, 0.14, 0.006))
    p.append(strap('zamek', [(x, 0.0, top(x) + 0.003) for x in [(-0.27 + k * 0.03) for k in range(19)]], 0.008, met, 0.14, 0.003))
    p.append(rbox('suwak', (0.02, 0.012, 0.008), met, 0.002, (0.2, 0.0, top(0.2) + 0.012)))
    p.append(tube('uchwyt_s', [(0.21, 0.0, top(0.2) + 0.014), (0.235, 0.004, top(0.2) + 0.02), (0.255, 0.0, top(0.2) + 0.008)], 0.003, met, 5))
    # taśmy dookoła korpusu i ucha, które się z nich wyprowadzają
    for sx in (-0.14, 0.14):
        ring = [body(sx / L + 0.5, v / 24.0) for v in range(25)]
        ring = [(q[0], q[1] * 1.012, q[2] + (0.002 if q[2] > 0.01 else 0.0)) for q in ring]
        p.append(strap('obwod', ring, 0.036, web, 0.14, 0.003))
    for sy, lean in ((-1, 0.07), (1, -0.02)):
        pts = []
        for k in range(15):
            t = k / 14.0
            x = -0.14 + 0.28 * t
            arch = math.sin(t * math.pi)
            y = sy * 0.1 * (1.0 - 0.75 * arch) + lean * arch
            z = top(x) + 0.01 + 0.15 * arch - (0.08 * arch if sy > 0 else 0.0)
            pts.append((x, y, z))
        p.append(strap('ucho', pts, 0.034, web, -1.0, 0.004))
    p.append(rbox('owijka', (0.11, 0.045, 0.028), mat('owijka', '15171c', 0.75), 0.012, (0.0, -0.03 + 0.07, top(0) + 0.155), (0.5, 0, 0), segs=3))
    # lamówki i uchwyty na szczytach
    for sx in (-1, 1):
        x = sx * (L / 2 - 0.045)
        ring = [body(x / L + 0.5, v / 24.0) for v in range(25)]
        p.append(tube('lamowka', [(q[0], q[1], q[2]) for q in ring], 0.006, web, 6))
        p.append(strap('raczka', [(sx * (L / 2 - 0.01), -0.05, 0.19), (sx * (L / 2 + 0.03), -0.03, 0.17), (sx * (L / 2 + 0.03), 0.03, 0.17), (sx * (L / 2 - 0.01), 0.05, 0.19)], 0.028, web, -1.0, 0.004))
        p.append(tube('polkole', [(sx * (L / 2 - 0.03), 0.0, 0.25 + 0.016 * math.sin(a)) if False else (sx * (L / 2 - 0.035), 0.016 * math.cos(a), 0.262 + 0.016 * math.sin(a)) for a in [k * math.tau / 10 for k in range(11)]], 0.003, met, 5))
    # kieszeń boczna z zamkiem
    def pocket(u, v):
        x = (u - 0.5) * 0.3
        z = 0.06 + v * 0.14
        bul = 0.022 * math.sin(u * math.pi) ** 0.6 * math.sin(v * math.pi) ** 0.6
        base = body(x / L + 0.5, 0.5 + 0.0)[1]
        return (x, -(RY * 0.985 + bul) * (1.0 - 0.0), z)
    p.append(grid_mesh('kieszen', 10, 6, pocket, cloth))
    p.append(strap('zamek_k', [(-0.13 + k * 0.026, -(RY + 0.02), 0.19) for k in range(11)], 0.007, met, 0.14, 0.003))
    p.append(rbox('metka', (0.05, 0.004, 0.03), mat('metka', 'c8322a', 0.8), 0.002, (0.2, -(RY + 0.004), 0.1)))
    # pasek na ramię: z półkola na szczycie przez wierzch torby na podłogę
    sp = [(-(L / 2 - 0.035), 0.0, 0.27), (-0.22, 0.05, top(-0.22) + 0.02), (-0.05, 0.1, top(0) - 0.0), (0.08, 0.17, 0.12), (0.2, 0.24, 0.008), (0.36, 0.2, 0.006), (0.42, 0.06, 0.006), (L / 2 + 0.02, 0.01, 0.1), (L / 2 - 0.035, 0.0, 0.27)]
    sm = []
    for i in range(len(sp) - 1):
        for k in range(4):
            a, c = Vector(sp[i]), Vector(sp[i + 1])
            sm.append(tuple(a.lerp(c, k / 4.0)))
    sm.append(sp[-1])
    for _ in range(2):
        sm = [sm[0]] + [tuple((Vector(sm[i - 1]) + Vector(sm[i]) * 2 + Vector(sm[i + 1])) / 4) for i in range(1, len(sm) - 1)] + [sm[-1]]
    p.append(strap('pasek', sm, 0.036, web, -1.0, 0.004))
    p.append(rbox('poduszka', (0.16, 0.06, 0.014), mat('owijka', '15171c', 0.75), 0.006, (0.3, 0.215, 0.012), (0, 0, -0.6), segs=3))
    ob = join('Torba', p)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.mesh.remove_doubles(threshold=0.0004)
    bpy.ops.mesh.normals_make_consistent(inside=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    weather([ob], 1024, 0.5, 0.3, (0.1, 0.09, 0.08))
    export('torba')


def dom_drzwi():
    """drzwi wewnętrzne (ściana w y=0, patrzą do pokoju): ościeżnica z opaską, gładkie skrzydło z frezami, klamka na szyldzie, zamek, wizjer, łańcuch, zawiasy, próg"""
    reset()
    wh = mat('oscieznica', 'e6e3dc', 0.5)
    p = []
    for sx in (-1, 1):
        p.append(rbox('opaska', (0.09, 0.03, 2.12), wh, 0.006, (sx * 0.5, -0.015, 1.06)))
        p.append(rbox('oscieznica', (0.04, 0.1, 2.06), wh, 0.004, (sx * 0.465, -0.04, 1.03)))
    p.append(rbox('opaska_g', (1.09, 0.03, 0.09), wh, 0.006, (0, -0.015, 2.11)))
    p.append(rbox('prog', (0.9, 0.1, 0.018), mat('prog', '8a7a62', 0.6), 0.004, (0, -0.04, 0.009)))
    fr = join('Oscieznica', p)
    weather([fr], 512, 0.35, 0.3)
    leaf = mat('skrzydlo', 'e2ddd2', 0.5)
    d = [rbox('skrzydlo', (0.88, 0.042, 2.03), leaf, 0.004, (0, -0.045, 1.03))]
    for z in (0.5, 1.03, 1.56):
        d.append(rbox('frez', (0.7, 0.004, 0.012), mat('frez', 'bdb6a8', 0.6), 0.0, (0, -0.0665, z), segs=1))
    dj = join('TintSkrzydlo', d)
    weather([dj], 1024, 0.3, 0.25)
    st = mat('chrom', 'b9bcc2', 0.25, 0.9)
    o = [rbox('szyld', (0.045, 0.01, 0.22), st, 0.008, (0.36, -0.071, 1.02))]
    o.append(tube('klamka', [(0.36, -0.076, 1.06), (0.36, -0.115, 1.06), (0.25, -0.118, 1.06)], 0.01, st, 8))
    o.append(lathe('wkladka', [(0.0, 0.0), (0.011, 0.0), (0.011, 0.006), (0.0, 0.006)], mat('mosiadz', 'b89a4a', 0.3, 0.9), 10, loc=(0.36, -0.076, 0.96)))
    o[-1].rotation_euler = (R90, 0, 0)
    o.append(lathe('wizjer', [(0.0, 0.0), (0.012, 0.0), (0.014, 0.006), (0.008, 0.01), (0.0, 0.008)], st, 10, loc=(0, -0.066, 1.52)))
    o[-1].rotation_euler = (R90, 0, 0)
    o.append(rbox('zasuwka', (0.07, 0.014, 0.03), st, 0.004, (0.38, -0.073, 1.36)))
    o.append(tube('lancuch', [(0.38, -0.08, 1.36), (0.42, -0.085, 1.3), (0.455, -0.08, 1.26), (0.47, -0.07, 1.34)], 0.003, st, 5))
    for z in (0.25, 1.03, 1.8):
        o.append(lathe('zawias', [(0.0, -0.045), (0.009, -0.045), (0.009, 0.045), (0.0, 0.045)], st, 8, loc=(-0.445, -0.07, z)))
    join('Okucia', o)
    export('dom_drzwi')


def dom_wieszak():
    """wieszak ścienny (ściana w y=0): dębowa listwa z czarnymi haczykami i półką, na półce czapka i miseczka na klucze;
    wisi kurtka z kapturem (TintKurtka) z fałdami i rękawami, obok parasol i torba płócienna"""
    reset()
    oak = mat('okleina', OAK, 0.55)
    blk = mat('czarny', '17181b', 0.45, 0.4)
    p = [rbox('listwa', (0.95, 0.022, 0.13), oak, 0.006, (0, -0.011, 0.0))]
    p.append(rbox('polka', (0.95, 0.2, 0.022), oak, 0.006, (0, -0.1, 0.18)))
    for sx in (-0.4, 0.4):
        p.append(rbox('wspornik', (0.02, 0.16, 0.02), blk, 0.004, (sx, -0.09, 0.158), (0.5, 0, 0)))
    hooks = (-0.36, -0.12, 0.12, 0.36)
    for hx in hooks:
        p.append(tube('hak', [(hx, -0.022, 0.03), (hx, -0.07, 0.02), (hx, -0.085, -0.02), (hx, -0.07, -0.045), (hx, -0.055, -0.03)], 0.007, blk, 8))
        p.append(lathe('rozeta', [(0.0, 0.0), (0.016, 0.0), (0.016, 0.005), (0.0, 0.005)], blk, 10, loc=(hx, -0.022, 0.03)))
        p[-1].rotation_euler = (R90, 0, 0)
    p.append(lathe('miseczka', [(0.0, 0.0), (0.045, 0.0), (0.06, 0.03), (0.055, 0.03), (0.042, 0.006), (0.0, 0.006)], mat('ceramika', '3a5a6a', 0.3), 14, loc=(0.32, -0.1, 0.191)))
    p.append(tube('klucze', [(0.31, -0.1, 0.2), (0.33, -0.09, 0.2), (0.335, -0.11, 0.2), (0.31, -0.1, 0.2)], 0.003, mat('chrom', 'b9bcc2', 0.25, 0.9), 5))
    fr = join('Wieszak', p)
    weather([fr], 512, 0.3, 0.3)
    # czapka z daszkiem na półce
    c = [lathe('czapka', [(0.0, 0.085), (0.04, 0.08), (0.08, 0.05), (0.09, 0.0), (0.085, 0.0), (0.075, 0.045), (0.0, 0.078)], mat('czapka', '2c4a7a', 0.9), 14, loc=(-0.25, -0.1, 0.191))]
    c.append(rbox('daszek', (0.15, 0.09, 0.008), mat('czapka', '2c4a7a', 0.9), 0.004, (-0.25, -0.2, 0.2), (math.radians(-8), 0, 0)))
    weather([join('Czapka', c)], 256, 0.3, 0.2)
    # kurtka: korpus zebrany pod hakiem, fałdy, rękawy opadające po bokach, kaptur
    hx = -0.12

    def jacket(u, v):
        a = u * math.tau
        w = 0.07 + 0.19 * min(1.0, v * 3.2) ** 0.7
        dth = 0.035 + 0.06 * min(1.0, v * 2.0)
        fold = 1.0 + 0.09 * math.sin(a * 5.0 + v * 2.0) * min(1.0, v * 2.5) + 0.04 * math.sin(a * 11.0)
        x = hx + math.cos(a) * w * fold
        y = -0.09 + math.sin(a) * dth * fold - 0.01 * v
        z = -0.03 - v * 0.74 - 0.03 * (1.0 - abs(math.cos(a))) * (1.0 - v)
        return (x, min(y, -0.004), z)
    j = [grid_mesh('korpus', 36, 16, jacket, mat('kurtka', 'c4c8cc', 0.9), True)]
    for sx in (-1, 1):
        def sleeve(u, v, sx=sx):
            a = u * math.tau
            r = 0.06 - 0.012 * v
            fold = 1.0 + 0.1 * math.sin(a * 3.0 + v * 9.0)
            x = hx + sx * (0.2 + 0.03 * v) + math.cos(a) * r * fold
            y = -0.085 - 0.02 * v + math.sin(a) * r * 0.55 * fold
            z = -0.12 - v * 0.6
            return (x, min(y, -0.004), z)
        j.append(grid_mesh('rekaw', 14, 12, sleeve, mat('kurtka', 'c4c8cc', 0.9), True))
        j.append(lathe('mankiet', [(0.045, -0.02), (0.052, -0.02), (0.052, 0.02), (0.045, 0.02)], mat('sciagacz', '9a9ea4', 0.95), 12, loc=(hx + sx * 0.23, -0.105, -0.72)))
        j[-1].scale = (1.0, 0.55, 1.0)

    def hood(u, v):
        a = (u - 0.5) * math.pi
        r = 0.13 * math.sin(v * math.pi * 0.9 + 0.15)
        return (hx + math.sin(a) * r, -0.05 - math.cos(a) * r * 0.5 - 0.03 * v, 0.0 - v * 0.26)
    j.append(grid_mesh('kaptur', 12, 8, hood, mat('kurtka', 'c4c8cc', 0.9)))
    j.append(rbox('zamek', (0.006, 0.004, 0.66), mat('zamek', '4a4d52', 0.4, 0.8), 0.0, (hx, -0.185, -0.42), (0.03, 0, 0), segs=1))
    j.append(tube('wieszak_p', [(hx - 0.02, -0.06, -0.02), (hx, -0.075, -0.035), (hx + 0.02, -0.06, -0.02)], 0.004, mat('kurtka', 'c4c8cc', 0.9), 5))
    jo = join('TintKurtka', j)
    weather([jo], 1024, 0.4, 0.1, (0.12, 0.12, 0.13))
    # torba płócienna i parasol
    b = [grid_mesh('torba', 16, 8, lambda u, v: (0.36 + math.cos(u * math.tau) * (0.13 + 0.03 * v), -0.07 + math.sin(u * math.tau) * (0.025 + 0.02 * v), -0.3 - v * 0.36), mat('len', 'd8cfb8', 0.95), True)]
    for s in (-1, 1):
        b.append(tube('ucho', [(0.36 + s * 0.07, -0.07, -0.3), (0.36 + s * 0.03, -0.075, -0.1), (0.36, -0.08, -0.04)], 0.006, mat('len', 'd8cfb8', 0.95), 5))
    b.append(lathe('parasol', [(0.0, -0.78), (0.012, -0.76), (0.03, -0.3), (0.012, -0.12), (0.008, -0.12), (0.008, -0.05), (0.0, -0.05)], mat('parasol', '1c1d22', 0.8), 10, loc=(0.12, -0.07, 0.0)))
    b.append(tube('raczka', [(0.12, -0.07, -0.05), (0.12, -0.07, -0.02), (0.12, -0.085, 0.0), (0.12, -0.1, -0.02)], 0.008, mat('drewno', '6a4a2a', 0.6), 6))
    weather([join('Drobiazgi', b)], 512, 0.4, 0.2)
    export('dom_wieszak')


def dom_stolik():
    """stolik kawowy 1,0 × 0,55 × 0,4 m: dębowy blat z ciemnym obrzeżem na czarnej ramie z profili, niżej półka z listew"""
    reset()
    oak = mat('okleina', OAK, 0.55)
    st = mat('profil', '1d1f23', 0.45, 0.6)
    W, D, H = 1.0, 0.55, 0.4
    p = [rbox('blat', (W, D, 0.028), oak, 0.004, (0, 0, H - 0.014))]
    p.append(rbox('obrzeze', (W + 0.002, D + 0.002, 0.006), mat('obrzeze', '3a3027', 0.6), 0.0, (0, 0, H - 0.031), segs=1))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(rbox('noga', (0.03, 0.03, H - 0.03), st, 0.004, (sx * (W / 2 - 0.05), sy * (D / 2 - 0.05), (H - 0.03) / 2)))
        p.append(rbox('rama_b', (0.03, D - 0.1, 0.03), st, 0.004, (sx * (W / 2 - 0.05), 0, 0.12)))
        p.append(rbox('rama_g', (0.03, D - 0.1, 0.03), st, 0.004, (sx * (W / 2 - 0.05), 0, H - 0.045)))
    for sy in (-1, 1):
        p.append(rbox('rama_d', (W - 0.1, 0.03, 0.03), st, 0.004, (0, sy * (D / 2 - 0.05), 0.12)))
    for k in range(5):
        p.append(rbox('listwa', (W - 0.14, 0.07, 0.014), oak, 0.003, (0, -0.16 + k * 0.08, 0.142)))
    ob = join('Stolik', p)
    weather([ob], 1024, 0.25, 0.25)
    export('dom_stolik')


def dom_kanapa():
    """kanapa trzyosobowa 1,9 m: szara tkanina, trzy poduchy siedziska i oparcia z lamówką, zaokrąglone boki, dębowe nóżki, dwie poduszki (TintPoduszki) i koc"""
    reset()
    fab = mat('tkanina', '6d7178', 0.95)
    dark = mat('lamowka', '54585e', 0.95)
    W = 1.9
    p = [rbox('skrzynia', (W, 0.82, 0.2), fab, 0.03, (0, 0, 0.24), segs=3)]
    p.append(rbox('plecy', (W, 0.2, 0.52), fab, 0.06, (0, 0.31, 0.52), (math.radians(-6), 0, 0), segs=4))
    for sx in (-1, 1):
        p.append(rbox('bok', (0.2, 0.82, 0.44), fab, 0.07, (sx * (W / 2 - 0.1), 0, 0.42), segs=4))
    cw = (W - 0.44) / 3
    for k in range(3):
        x = -cw + k * cw
        p.append(rbox('siedzisko', (cw - 0.01, 0.6, 0.15), fab, 0.05, (x, -0.08, 0.41), (math.radians(2), 0, 0), segs=4))
        p.append(rbox('oparcie', (cw - 0.01, 0.16, 0.4), fab, 0.06, (x, 0.2, 0.66), (math.radians(-12), 0, 0), segs=4))
        p.append(rbox('szew', (cw - 0.04, 0.6, 0.004), dark, 0.0, (x, -0.08, 0.335), (math.radians(2), 0, 0), segs=1))
    for sx in (-1, 1):
        for sy in (-1, 1):
            leg = lathe('nozka', [(0.0, 0.0), (0.016, 0.0), (0.026, 0.14), (0.0, 0.14)], mat('okleina', OAK, 0.55), 10, loc=(sx * (W / 2 - 0.12), sy * 0.33, 0.0))
            leg.rotation_euler = (0.1 * -sy, 0.1 * sx, 0)
            p.append(leg)
    ob = join('Kanapa', p)
    weather([ob], 1024, 0.35, 0.12, (0.1, 0.1, 0.11))
    c = [rbox('poduszka1', (0.42, 0.14, 0.4), mat('poduszka', 'd8c9a6', 0.95), 0.06, (-0.62, 0.12, 0.68), (math.radians(-22), 0.15, 0.1), segs=5)]
    c.append(rbox('poduszka2', (0.4, 0.14, 0.38), mat('poduszka', 'd8c9a6', 0.95), 0.06, (-0.28, 0.1, 0.66), (math.radians(-26), -0.2, -0.25), segs=5))
    weather([join('TintPoduszki', c)], 512, 0.3, 0.1, (0.15, 0.13, 0.1))

    def blanket(u, v):
        x = W / 2 - 0.1 + (u - 0.5) * 0.3
        t = v * 1.5
        if t < 0.55:
            y, z = -0.3 + t * 0.9, 0.655 + 0.012 * math.sin(u * 9.0)
        else:
            y, z = 0.19 + (t - 0.55) * 0.03, 0.655 - (t - 0.55) * 0.42
        return (x + 0.115 * (1 if u > 0.5 else -1) * min(1.0, abs(u - 0.5) * 2.0) ** 3, y, z + 0.008 * math.sin(v * 14.0 + u * 5.0))
    bl = grid_mesh('Koc', 10, 14, blanket, mat('koc', '8a4a3a', 0.95))
    md = bl.modifiers.new('g', 'SOLIDIFY')
    md.thickness = 0.012
    weather([bl], 512, 0.3, 0.1, (0.15, 0.1, 0.08))
    export('dom_kanapa')


def dom_szafka_tv():
    """szafka RTV 1,2 × 0,4 × 0,5 m: dębowy korpus na czarnych nogach, drzwiczki z frezem, wnęka z konsolą i routerem, przelotka na kable"""
    reset()
    oak = mat('okleina', OAK, 0.55)
    st = mat('profil', '1d1f23', 0.45, 0.6)
    W, D, H = 1.2, 0.4, 0.5
    p = [rbox('blat', (W, D, 0.022), oak, 0.004, (0, 0, H - 0.011))]
    p.append(rbox('dno', (W, D, 0.022), oak, 0.004, (0, 0, 0.151)))
    for sx in (-1, 0.02, 1):
        p.append(rbox('bok', (0.02, D, H - 0.16), oak, 0.003, (sx * (W / 2 - 0.01), 0, 0.32)))
    p.append(rbox('plecy', (W - 0.02, 0.008, H - 0.16), mat('plecy', '2a2c30', 0.7), 0.0, (0, D / 2 - 0.006, 0.32), segs=1))
    p.append(rbox('drzwiczki', (W / 2 - 0.016, 0.018, H - 0.19), mat('front', '2f3237', 0.5), 0.004, (-W / 4, -D / 2 + 0.009, 0.32)))
    p.append(rbox('uchwyt', (0.012, 0.016, 0.12), st, 0.004, (-0.04, -D / 2 - 0.006, 0.36)))
    for sx in (-1, 1):
        for sy in (-1, 1):
            leg = lathe('nozka', [(0.0, 0.0), (0.012, 0.0), (0.018, 0.14), (0.0, 0.14)], st, 8, loc=(sx * (W / 2 - 0.07), sy * (D / 2 - 0.06), 0.0))
            p.append(leg)
    p.append(rbox('konsola', (0.3, 0.26, 0.06), mat('konsola', '15161a', 0.4), 0.01, (0.3, 0.0, 0.192)))
    p.append(rbox('router', (0.16, 0.1, 0.03), mat('router', 'e4e4e0', 0.5), 0.008, (0.12, 0.06, 0.34), (0, 0, 0.2)))
    for k in range(2):
        p.append(tube('antena%d' % k, [(0.08 + k * 0.08, 0.1, 0.345), (0.075 + k * 0.09, 0.11, 0.44)], 0.004, mat('konsola', '15161a', 0.4), 5))
    p.append(rbox('polka', (W / 2 - 0.03, D - 0.03, 0.014), oak, 0.002, (W / 4, 0, 0.315)))
    ob = join('Szafka', p)
    weather([ob], 1024, 0.25, 0.25)
    export('dom_szafka_tv')


def dom_tv():
    """telewizor płaski 43 cale na dwóch stopkach: cienka ramka, wzmocniony tył z otworami, dioda; „Ekran” lekko świeci"""
    reset()
    blk = mat('obudowa', '111215', 0.4)
    W, H = 0.96, 0.56
    p = [rbox('obudowa', (W, 0.03, H), blk, 0.008, (0, 0, 0.07 + H / 2))]
    p.append(rbox('tyl', (0.5, 0.05, 0.3), blk, 0.02, (0, 0.03, 0.07 + H * 0.42)))
    for k in range(6):
        p.append(rbox('otwor', (0.3, 0.004, 0.006), mat('cien', '050506', 0.9), 0.0, (0, 0.056, 0.2 + k * 0.02), segs=1))
    for sx in (-1, 1):
        p.append(tube('stopka', [(sx * 0.34, -0.11, 0.004), (sx * 0.34, 0.0, 0.07), (sx * 0.34, 0.11, 0.004)], 0.008, blk, 6))
    p.append(rbox('listwa', (0.1, 0.006, 0.012), mat('logo', '8a8f96', 0.3, 0.8), 0.002, (0, -0.016, 0.082)))
    ob = join('Telewizor', p)
    weather([ob], 512, 0.2, 0.2)
    rbox('Ekran', (W - 0.02, 0.002, H - 0.022), mat('ekran', '0a0e16', 0.08, 0.3, 0.25), 0.0, (0, -0.016, 0.076 + H / 2), segs=1)
    lathe('SwiatloDioda', [(0.0, 0.0), (0.003, 0.0), (0.003, 0.001), (0.0, 0.001)], mat('dioda', 'ff3020', 0.3, 0.0, 4.0), 6, loc=(0.44, -0.016, 0.078)).rotation_euler = (R90, 0, 0)
    export('dom_tv')


def dom_lozko():
    """łóżko 90 × 200: czarna stalowa rama na nóżkach, dębowe burty, tapicerowany zagłówek z przeszyciami (materac i pościel dokłada gra)"""
    reset()
    oak = mat('okleina', OAK, 0.55)
    st = mat('profil', '1d1f23', 0.45, 0.6)
    fab = mat('tkanina', '6d7178', 0.95)
    W, L = 0.9, 1.96
    p = []
    for sx in (-1, 1):
        p.append(rbox('burta', (0.03, L, 0.16), oak, 0.006, (sx * (W / 2 + 0.005), 0, 0.27)))
        for sy in (-1, 1):
            p.append(rbox('noga', (0.04, 0.04, 0.2), st, 0.005, (sx * (W / 2 - 0.02), sy * (L / 2 - 0.05), 0.1)))
    p.append(rbox('szczyt_d', (W + 0.04, 0.03, 0.2), oak, 0.006, (0, -L / 2 - 0.005, 0.29)))
    for k in range(11):
        p.append(rbox('listwa', (W - 0.02, 0.07, 0.016), mat('listwa', 'c9b28c', 0.6), 0.003, (0, -L / 2 + 0.12 + k * 0.172, 0.33)))
    p.append(rbox('rama_s', (0.03, L - 0.04, 0.04), st, 0.004, (0, 0, 0.31)))
    p.append(rbox('zaglowek_r', (W + 0.06, 0.04, 0.98), oak, 0.008, (0, L / 2 + 0.01, 0.51)))
    fr = join('Rama', p)
    weather([fr], 1024, 0.25, 0.25)
    h = [rbox('zaglowek', (W, 0.07, 0.56), fab, 0.035, (0, L / 2 - 0.035, 0.7), segs=4)]
    for k in range(1, 4):
        h.append(rbox('przeszycie', (0.006, 0.074, 0.54), mat('szew', '54585e', 0.95), 0.002, (-W / 2 + k * W / 4, L / 2 - 0.036, 0.7), segs=1))
    weather([join('Zaglowek', h)], 512, 0.3, 0.1, (0.1, 0.1, 0.11))
    export('dom_lozko')


ALL = (torba, dom_drzwi, dom_wieszak, dom_stolik, dom_kanapa, dom_szafka_tv, dom_tv, dom_lozko)
only = [a for a in sys.argv[sys.argv.index('--') + 1:]] if '--' in sys.argv else []
for f in ALL:
    if not only or f.__name__ in only:
        f()
