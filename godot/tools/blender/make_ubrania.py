"""Ubrania na postać: prawdziwe siatki szyte na miarę szkieletu (Rocketbox „Bip01”).
Powłoka każdego ubrania powstaje z powierzchni ciała w danym obszarze (tułów z rękawami, nogi, dłonie, stopy, szyja):
wygładzona, odsunięta od ciała, zagęszczona, z grubością materiału na brzegach — i zachowuje wagi kości, więc rusza się z postacią.
Do tego detale: ściągacze, kaptur, kołnierz, kieszenie i patki rzutowane na powierzchnię, zamek, guziki, sznurówki, podeszwy.
Czapki, okulary i łańcuch są sztywne (wiszą na kości) i zapisują się względem jej początku.
Nazwa materiału zaczyna się od tkaniny (dzianina_, dzins_, plotno_, skora_, sciagacz_, guma_, metal_, krata_) — gra dobiera do niej fakturę.

  Blender -b --python tools/blender/make_ubrania.py [-- nazwa ...]"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bpy, bmesh
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree
import lib
from lib import mat, lathe, rbox, tube

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
SRC = os.path.join(ROOT, 'assets', 'people', 'm10', 'm10.fbx')
OUT = os.path.join(ROOT, 'assets', 'wear')
R90 = math.radians(90)
rnd = random.Random(11)

FACE = ('Head', 'Eye', 'Jaw', 'Lip', 'Tongue', 'Mouth', 'Masseter', 'Caninus', 'Cheek', 'Eyebrow', 'Nose')


class Body:
    """ciało w pozie spoczynkowej, we współrzędnych świata (X w lewo postaci, −Y przód, Z góra)"""

    def __init__(self):
        lib.reset()
        bpy.ops.import_scene.fbx(filepath=SRC)
        sc = bpy.context.scene
        self.arm = next(o for o in sc.objects if o.type == 'ARMATURE')
        self.ob = next(o for o in sc.objects if o.type == 'MESH')
        self.names = [g.name for g in self.ob.vertex_groups]
        self.H = {b.name: self.arm.matrix_world @ b.head_local for b in self.arm.data.bones}
        self.bm = bmesh.new()
        self.bm.from_mesh(self.ob.data)
        self.bm.transform(self.ob.matrix_world)
        self.bm.normal_update()
        self.dl = self.bm.verts.layers.deform.verify()
        self.mats = [m.name.split('_')[-1].lower() for m in self.ob.data.materials]
        # tylko skóra i ubranie (bez kart włosów i rzęs)
        solid = bmesh.new()
        solid.from_mesh(self.ob.data)
        solid.transform(self.ob.matrix_world)
        bmesh.ops.delete(solid, geom=[f for f in solid.faces if self.mats[f.material_index] == 'opacity'], context='FACES')
        self.tree = BVHTree.FromBMesh(solid)
        self.kd = KDTree(len(self.bm.verts))
        self.bm.verts.ensure_lookup_table()
        for v in self.bm.verts:
            self.kd.insert(v.co, v.index)
        self.kd.balance()
        self.ob.hide_set(True)

    def w(self, v, dl=None):
        return {self.names[g]: x for g, x in v[dl or self.dl].items()}

    def near_w(self, co):
        _, i, _ = self.kd.find(co)
        return self.bm.verts[i][self.dl].items()


def part(w, keys):
    return sum(x for n, x in w.items() if any(k in n for k in keys))


def top_w(w):
    return part(w, ('Spine', 'Clavicle', 'UpperArm', 'Forearm'))


def legs_w(w):
    return part(w, ('Pelvis', 'Thigh', 'Calf')) + w.get('Bip01', 0.0)


def hand_w(w):
    return part(w, ('Hand', 'Finger'))


def foot_w(w):
    return part(w, ('Foot', 'Toe'))


def head_w(w):
    return part(w, FACE)


def along(B, co, a, b):
    """położenie punktu wzdłuż odcinka kość a → kość b (0..1) po tej stronie ciała, po której leży punkt"""
    side = 'L' if co.x > 0 else 'R'
    p0, p1 = B.H['Bip01 %s %s' % (side, a)], B.H['Bip01 %s %s' % (side, b)]
    d = p1 - p0
    return (co - p0).dot(d) / d.length_squared


# ---------------------------------------------------------------- powłoka
def clear(B, bm, gap):
    """odsuwa od ciała punkty, które po wygładzaniu znalazły się za blisko albo pod jego powierzchnią"""
    for v in bm.verts:
        loc, nrm, _, dist = B.tree.find_nearest(v.co)
        if loc is not None and (v.co - loc).dot(nrm) < gap:
            v.co = loc + nrm * gap


def folds(B, bm, amp=1.0):
    """Fałdy materiału: ubranie nie jest balonem. Zmarszczki zbierają się przy zgięciach (łokcie, kolana, pachy, krok),
    tułów poniżej klatki układa się w pionowe draperie, nogawki mają podłużne załamania, a całość lekko faluje."""
    from mathutils import noise
    J = []
    for sd in ('L', 'R'):
        J.append((B.H['Bip01 %s Forearm' % sd], 0.105, 0.0042, 92.0))
        J.append((B.H['Bip01 %s Calf' % sd], 0.12, 0.0046, 80.0))
        J.append((B.H['Bip01 %s UpperArm' % sd] + Vector((0, 0, -0.07)), 0.1, 0.0036, 100.0))
        J.append((B.H['Bip01 %s Thigh' % sd] + Vector((0, -0.05, -0.02)), 0.12, 0.004, 88.0))
    for v in bm.verts:
        if v.is_boundary:
            continue
        co = v.co
        d = 0.0026 * noise.noise(co * 11.0) + 0.0012 * noise.noise(co * 37.0)
        for j, rad, a, fq in J:
            r = (co - j).length
            k = math.exp(-(r / rad) ** 2)
            if k > 0.03:
                d += k * a * math.sin(r * fq + 2.0 * noise.noise(co * 14.0))
        if abs(co.x) < 0.24 and 0.86 < co.z < 1.3:
            # draperia tułowia: pionowe fale, mocniejsze ku dołowi i po bokach
            ang = math.atan2(co.x, -co.y)
            low = min(1.0, (1.3 - co.z) / 0.3)
            d += 0.0042 * low * math.sin(ang * 7.0 + 3.0 * noise.noise(Vector((co.x * 6.0, co.y * 6.0, co.z * 2.0))))
        elif co.z < 0.86 and abs(co.x) < 0.3:
            # nogawki: podłużne załamania i zbieranie się materiału nad butem
            ang = math.atan2(co.x - (0.09 if co.x > 0 else -0.09), -co.y)
            d += 0.0026 * math.sin(ang * 5.0 + co.z * 9.0 + 2.0 * noise.noise(co * 5.0))
            if co.z < 0.24:
                d += 0.0045 * math.sin(co.z * 150.0) * (1.0 - co.z / 0.24)
        calm = max(0.2, min(1.0, (1.52 - co.z) / 0.09)) if abs(co.x) < 0.16 else 1.0
        v.co += v.normal * max(-0.0025, d * amp * 1.5 * calm)


def shell(B, pick, offset, smooth=2, cuts=1, skip=('opacity',), rim=0.006, gap=0.003, wrinkle=0.0, post=None):
    """powierzchnia ciała tam, gdzie pick(co, w) — wygładzona, odsunięta o offset(co, w), zagęszczona, z brzegiem zawiniętym do środka"""
    bm = B.bm.copy()
    dl = bm.verts.layers.deform.verify()
    bm.verts.ensure_lookup_table()
    keep = set(v for v in bm.verts if pick(v.co, B.w(v, dl)))
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if B.mats[f.material_index] in skip or not all(v in keep for v in f.verts)], context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    for f in bm.faces:
        f.material_index = 0
    for _ in range(smooth):
        bmesh.ops.smooth_vert(bm, verts=bm.verts[:], factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm.normal_update()
    for v in bm.verts:
        v.co += v.normal * offset(v.co, B.w(v, dl))
    if cuts:
        bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, smooth=0.35, use_grid_fill=True)
        bmesh.ops.smooth_vert(bm, verts=[v for v in bm.verts if not v.is_boundary], factor=0.35, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    if wrinkle > 0.0:
        bm.normal_update()
        folds(B, bm, wrinkle)
    if gap > 0.0:
        clear(B, bm, gap)
    if post is not None:
        # równe cięcia i doszyte brzegi (dół bluzy, nogawki, mankiety) — po uformowaniu, przed zawinięciem brzegów
        post(bm)
    bm.normal_update()
    lps = loops(bm, lambda c: True)
    if rim > 0.0:
        nrm = {v: v.normal.copy() for v in bm.verts if v.is_boundary}
        ret = bmesh.ops.extrude_edge_only(bm, edges=[e for e in bm.edges if e.is_boundary])
        new = [g for g in ret['geom'] if isinstance(g, bmesh.types.BMVert)]
        for v in new:
            src = min(nrm, key=lambda o: (o.co - v.co).length_squared) if len(nrm) < 400 else None
            n = nrm[src] if src is not None else v.normal
            v.co -= n * rim
    bm.normal_update()
    return bm, lps


def cut(bm, co, no, test=None):
    """obcina powłokę płaszczyzną: znika wszystko po stronie, w którą patrzy normalna; test(co) zawęża cięcie do części siatki"""
    if test is None:
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
    else:
        vs = set(v for v in bm.verts if test(v.co))
        geom = list(vs) + [e for e in bm.edges if e.verts[0] in vs and e.verts[1] in vs] + [f for f in bm.faces if all(v in vs for v in f.verts)]
    bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-5, plane_co=co, plane_no=no, clear_outer=True)


def lengthen(bm, test, goal, steps=3, ease=1.0, weights=None):
    """Doszywa brzeg powłoki do nowego kształtu. Ciało ma ubranie wymodelowane po swojemu (workowate nogawki opadające
    na but, sweter do bioder), więc zdjęta z niego forma kończy się poszarpanym brzegiem w przypadkowym miejscu.
    test(środek krawędzi) wybiera brzeg, goal(co) daje punkt docelowy dla punktu brzegu, pośrednie pierścienie leżą
    po drodze; weights(v, q, co0) może poprawić wagi nowych punktów (q = 0..1 wzdłuż doszytego kawałka)."""
    edges = [e for e in bm.edges if e.is_boundary and test((e.verts[0].co + e.verts[1].co) / 2)]
    if not edges:
        return
    start, end = {}, {}
    for e in edges:
        for v in e.verts:
            if v not in start:
                start[v] = v.co.copy()
                end[v] = goal(v.co)
    origin = {v: v for v in start}
    for k in range(1, steps + 1):
        ret = bmesh.ops.extrude_edge_only(bm, edges=edges)
        new_v = [g for g in ret['geom'] if isinstance(g, bmesh.types.BMVert)]
        new_e = [g for g in ret['geom'] if isinstance(g, bmesh.types.BMEdge)]
        # nowy punkt powstaje dokładnie w miejscu starego
        where = {tuple(round(c, 6) for c in v.co): o for v, o in origin.items()}
        nxt = {v: where[tuple(round(c, 6) for c in v.co)] for v in new_v}
        q = (k / steps) ** ease
        for v, o in nxt.items():
            v.co = start[o].lerp(end[o], q)
            if weights is not None:
                weights(v, k / steps, start[o])
        origin = nxt
        edges = [e for e in new_e if e.verts[0] in nxt and e.verts[1] in nxt]


def _curve(pts, t):
    """gładka krzywa przez punkty (t, wartość)"""
    n = len(pts)
    if t <= pts[0][0]:
        return pts[0][1]
    if t >= pts[-1][0]:
        return pts[-1][1]
    for i in range(n - 1):
        t0, v0 = pts[i]
        t1, v1 = pts[i + 1]
        if t0 <= t <= t1:
            h = t1 - t0
            u = (t - t0) / h
            m0 = (v1 - pts[i - 1][1]) / (t1 - pts[i - 1][0]) if i > 0 else (v1 - v0) / h
            m1 = (pts[i + 2][1] - v0) / (pts[i + 2][0] - t0) if i < n - 2 else (v1 - v0) / h
            return ((2 * u ** 3 - 3 * u ** 2 + 1) * v0 + (u ** 3 - 2 * u ** 2 + u) * h * m0
                    + (-2 * u ** 3 + 3 * u ** 2) * v1 + (u ** 3 - u ** 2) * h * m1)
    return pts[-1][1]


def _edge_loops(bm):
    """brzegowe pętle jako listy krawędzi"""
    used, out = set(), []
    for e in bm.edges:
        if not e.is_boundary or e in used:
            continue
        loop, st = [], [e]
        used.add(e)
        while st:
            cur = st.pop()
            loop.append(cur)
            for v in cur.verts:
                for x in v.link_edges:
                    if x.is_boundary and x not in used:
                        used.add(x)
                        st.append(x)
        out.append(loop)
    return out


def pick_loops(lps, test):
    return [lp for lp in lps if test(sum(lp, Vector()) / len(lp))]


def ribbon(tree, a, b, cast, width, material, n=14, lift=0.002, name='tasma', thick=0.0):
    """płaska taśma położona na powierzchni od a do b (lampas, szew, plisa zamka)"""
    pts = [on_surface(tree, a.lerp(b, k / n), cast, lift) for k in range(n + 1)]
    bm = bmesh.new()
    rows = []
    for i, (p, nr) in enumerate(pts):
        t = (pts[min(i + 1, n)][0] - pts[max(i - 1, 0)][0]).normalized()
        bn = nr.cross(t).normalized()
        rows.append((bm.verts.new(p - bn * width / 2), bm.verts.new(p + nr * thick), bm.verts.new(p + bn * width / 2)))
    for i in range(n):
        for k in range(2):
            bm.faces.new((rows[i][k], rows[i][k + 1], rows[i + 1][k + 1], rows[i + 1][k]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    if sum(f.normal.dot(cast) for f in bm.faces) > 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    me.materials.append(material)
    return ob


def button(tree, p, cast, material, r=0.006, lift=0.002, name='guzik'):
    loc, nrm = on_surface(tree, p, cast, lift)
    b = lathe(name, [(0.0, 0.0), (r, 0.0), (r, r * 0.25), (r * 0.6, r * 0.42), (0.0, r * 0.3)], material, 8)
    b.rotation_euler = nrm.to_track_quat('Z', 'Y').to_euler()
    b.location = loc
    return b


def mesh_object(bm, name, material):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    me.materials.append(material)
    for p in me.polygons:
        p.use_smooth = True
    return ob


def to_object(B, bm, name, materials):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    for n in B.names:
        ob.vertex_groups.new(name=n)
    for m in materials:
        me.materials.append(m)
    for p in me.polygons:
        p.use_smooth = True
    return ob


def paint(ob, fn, index):
    """ściany, dla których fn(środek, normalna) — dostają materiał o numerze index"""
    for p in ob.data.polygons:
        if fn(p.center, p.normal):
            p.material_index = index


def loops(bm, test):
    """brzegowe pętle powłoki (posortowane listy punktów), których środek spełnia test"""
    edges = [e for e in bm.edges if e.is_boundary]
    used, out = set(), []
    for e in edges:
        if e in used:
            continue
        loop, cur, v = [], e, e.verts[0]
        while cur is not None and cur not in used:
            used.add(cur)
            loop.append(v.co.copy())
            v = cur.other_vert(v)
            cur = next((x for x in v.link_edges if x.is_boundary and x not in used), None)
        if len(loop) >= 6:
            c = sum(loop, Vector()) / len(loop)
            if test(c):
                out.append(loop)
    return out


def sweep(name, pts, radius, material, segs=6, closed=False, flat=1.0, wide=1.0):
    """lekki wałek wzdłuż łamanej: przekrój segs-kątny, flat = wysokość przekroju wzdłuż osi pętli, wide = szerokość na zewnątrz"""
    pts = [Vector(p) for p in pts]
    n = len(pts)
    c = sum(pts, Vector()) / n
    bm = bmesh.new()
    rings = []
    prev_n1 = None
    for i in range(n):
        a = pts[(i - 1) % n] if (closed or i > 0) else pts[i]
        b = pts[(i + 1) % n] if (closed or i < n - 1) else pts[i]
        t = (b - a).normalized()
        ref = (pts[i] - c)
        n1 = ref - t * ref.dot(t)
        if n1.length < 1e-5:
            n1 = prev_n1 if prev_n1 is not None else t.orthogonal()
        n1.normalize()
        if prev_n1 is not None and not closed and n1.dot(prev_n1) < 0:
            n1 = -n1
        prev_n1 = n1
        n2 = t.cross(n1)
        rings.append([bm.verts.new(pts[i] + n1 * (math.cos(k / segs * math.tau) * radius * wide) + n2 * (math.sin(k / segs * math.tau) * radius * flat)) for k in range(segs)])
    m = n if closed else n - 1
    for i in range(m):
        r0, r1 = rings[i], rings[(i + 1) % n]
        for k in range(segs):
            bm.faces.new((r0[k], r0[(k + 1) % segs], r1[(k + 1) % segs], r1[k]))
    if not closed:
        bm.faces.new(rings[0][::-1])
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    me.materials.append(material)
    for p in me.polygons:
        p.use_smooth = True
    return ob


def band(pts, radius, material, name='pasek', grow=0.0, flat=1.0, shift=Vector((0, 0, 0)), count=36, wide=1.0):
    """wałek wzdłuż zamkniętej pętli (ściągacz, lamówka, kołnierz); grow rozsuwa pętlę od jej środka, flat podwyższa przekrój w osi pętli"""
    c = sum(pts, Vector()) / len(pts)
    step = max(1, len(pts) // count)
    p = [(q + (q - c).normalized() * grow + shift) for q in pts[::step]]
    for _ in range(2):
        p = [(p[i - 1] + p[i] * 2 + p[(i + 1) % len(p)]) / 4 for i in range(len(p))]
    return sweep(name, p, radius, material, 6, True, flat, wide)


def patch(tree, center, right, up, w, h, lift, material, name='naszywka', nx=7, ny=7, corner=0.25, cast=None, max_d=0.25):
    """łata rzutowana na powierzchnię: siatka w×h wokół center (osie right/up), promienie wzdłuż cast; brzeg schodzi do powierzchni"""
    right, up = right.normalized(), up.normalized()
    cast = (cast or right.cross(up)).normalized()
    bm = bmesh.new()
    rows = []
    for j in range(ny + 1):
        row = []
        for i in range(nx + 1):
            u, v = i / nx * 2 - 1, j / ny * 2 - 1
            # zaokrąglone narożniki: punkty z rogów dosuwane do środka
            r = max(abs(u), abs(v))
            k = 1.0 - corner * max(0.0, abs(u) + abs(v) - 1.4)
            p = center + right * (u * k * w / 2) + up * (v * k * h / 2)
            loc, nrm, _, dist = tree.ray_cast(p - cast * 0.3, cast, 0.3 + max_d)
            if loc is None:
                loc, nrm, _, _ = tree.find_nearest(p)
            edge = r > 0.999
            row.append(bm.verts.new(loc + nrm * (0.0008 if edge else lift)))
        rows.append(row)
    for j in range(ny):
        for i in range(nx):
            bm.faces.new((rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]))
    bm.normal_update()
    # normalne mają patrzeć od ciała
    if sum((f.normal.dot(cast) for f in bm.faces)) > 0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    me.materials.append(material)
    for p in me.polygons:
        p.use_smooth = True
    return ob


def on_surface(tree, p, cast, lift=0.002):
    loc, nrm, _, _ = tree.ray_cast(p - cast.normalized() * 0.3, cast.normalized(), 0.6)
    if loc is None:
        loc, nrm, _, _ = tree.find_nearest(p)
    return loc + nrm * lift, nrm


def stitch(tree, a, b, cast, material, n=14, radius=0.0022, lift=0.0015, name='szew'):
    """szew albo sznurek: linia od a do b położona na powierzchni"""
    pts = [on_surface(tree, a.lerp(b, k / n), cast, lift)[0] for k in range(n + 1)]
    return sweep(name, pts, radius, material, 5)


def finish(B, ob, parts, name, bind=None, rigid=None, weigh=None):
    """dokleja detale, nadaje wagi (z najbliższego miejsca ciała albo na sztywno), rozkłada UV i zapisuje GLB"""
    n0 = len(ob.data.vertices)
    if parts:
        for o in bpy.context.selected_objects:
            o.select_set(False)
        for p in parts:
            p.select_set(True)
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.join()
    me = ob.data
    for p in me.polygons:
        p.use_smooth = True
    for o in bpy.context.selected_objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    # siatka ciała przyszła z własnymi normalnymi z pliku źródłowego — po przemodelowaniu są bezużyteczne i psują cieniowanie
    if me.has_custom_normals:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    while len(me.uv_layers) > 0:
        me.uv_layers.remove(me.uv_layers[0])
    me.uv_layers.new(name='UVMap')
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.01, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode='OBJECT')
    # jednakowa gęstość faktury: UV w metrach (1 jednostka UV ≈ 1 m tkaniny)
    area3 = sum(p.area for p in me.polygons)
    uv = me.uv_layers.active.data
    area2 = 0.0
    for p in me.polygons:
        ls = list(p.loop_indices)
        for k in range(1, len(ls) - 1):
            a, b, c = uv[ls[0]].uv, uv[ls[k]].uv, uv[ls[k + 1]].uv
            area2 += abs((b.x - a.x) * (c.y - a.y) - (c.x - a.x) * (b.y - a.y)) / 2
    k = math.sqrt(area3 / max(area2, 1e-9))
    for d in uv:
        d.uv = d.uv * k
    # drugie UV: rzut z przodu (krata koszuli biegnie równo po całym tułowiu)
    uv2 = me.uv_layers.new(name='rzut')
    arm = {}
    if not rigid:
        for side in ('L', 'R'):
            a, b = B.H['Bip01 %s UpperArm' % side], B.H['Bip01 %s Hand' % side]
            d = (b - a).normalized()
            e1 = d.cross(Vector((0, 1, 0))).normalized()
            arm[side] = (a, d, e1, d.cross(e1))
    for p in me.polygons:
        c = p.center
        side = 'L' if c.x > 0 else 'R'
        sleeve = False
        if arm:
            a, d, e1, e2 = arm[side]
            t = (c - a).dot(d)
            sleeve = t > 0.02 and ((c - a) - d * t).length < 0.11
        for li in p.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            if sleeve:
                r = co - a
                ang = math.atan2(r.dot(e2), r.dot(e1))
                uv2.data[li].uv = (ang * 0.055 + 0.37, r.dot(d) + 0.21)
            else:
                uv2.data[li].uv = (co.x + co.y * 0.35, co.z)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + '.glb')
    if rigid:
        o = B.H[rigid]
        for v in me.vertices:
            v.co -= o
        ob.select_set(True)
        bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_apply=True, export_yup=True, export_animations=False, export_skins=False)
    else:
        # detale (kieszenie, guziki, lamówki) trzymają się materiału: wagi biorą z najbliższego punktu powłoki, nie z ciała —
        # inaczej przy kroku odrywały się od doszytego dołu kurtki, który ma własne wagi
        shell_kd = None
        if weigh is None and not bind and n0 > 0 and any(v.groups for v in me.vertices[:n0]):
            shell_kd = KDTree(n0)
            for v in me.vertices[:n0]:
                shell_kd.insert(v.co, v.index)
            shell_kd.balance()
            shell_g = [[(g.group, g.weight) for g in v.groups] for v in me.vertices[:n0]]
        for v in me.vertices:
            if shell_kd is not None and v.index >= n0:
                _, si, _ = shell_kd.find(v.co)
                if shell_g[si]:
                    for gi, x in shell_g[si]:
                        ob.vertex_groups[gi].add([v.index], x, 'REPLACE')
                    continue
            if v.index >= n0 or not v.groups:
                if bind and v.index >= n0:
                    for bn, x in bind.items():
                        ob.vertex_groups[bn].add([v.index], x, 'REPLACE')
                elif weigh is not None:
                    for bn, x in weigh(v.co).items():
                        if x > 0.001 and bn in ob.vertex_groups:
                            ob.vertex_groups[bn].add([v.index], x, 'REPLACE')
                else:
                    for g, x in B.near_w(v.co):
                        ob.vertex_groups[B.names[g]].add([v.index], x, 'REPLACE')
        md = ob.modifiers.new('Armature', 'ARMATURE')
        md.object = B.arm
        B.arm.select_set(True)
        bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, export_apply=False, export_yup=True, export_animations=False, export_skins=True)
    print('UBRANIE %s  %d ścian  -> %s' % (name, len(me.polygons), os.path.relpath(path, ROOT)))


def tag(obs, material=None):
    return [o for o in obs if o is not None]


# ================================================================ GÓRA
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
FRONT = Vector((0, 1, 0))      # promień od przodu w stronę ciała
BACK = Vector((0, -1, 0))
DOWN = Vector((0, 0, -1))


NECK_CO = Vector((0, -0.08, 1.515))
NECK_NO = Vector((0, -0.312, 0.95)).normalized()
ZC = 0.9          # tułów powłoki kończy się równym cięciem na biodrach; niżej jest doszyty dół
WRIST = 1.12      # mankiet kończy się tuż za nadgarstkiem (zakrywa rękaw namalowany na ciele)
SLEEVE = 0.62     # rękaw powłoki kończy się równym cięciem w połowie przedramienia; dalej jest doszyty


def _cuff_w(B, bm, sd):
    """wagi doszytego końca rękawa: ku dłoni coraz mocniej idzie za nią (rękaw ciała pod spodem też się z nią zgina)"""
    dl = bm.verts.layers.deform.verify()
    gh = B.names.index('Bip01 %s Hand' % sd)

    def fn(v, q, co0):
        k = 0.55 * q
        d = v[dl]
        for g, x in list(d.items()):
            d[g] = x * (1.0 - k)
        d[gh] = d.get(gh, 0.0) + k
    return fn


def _skirt_w(B, bm, depth):
    """wagi doszytego dołu: im niżej, tym mocniej idzie za udem po swojej stronie (żeby noga nie przebijała w kroku)"""
    dl = bm.verts.layers.deform.verify()
    gl, gr = B.names.index('Bip01 L Thigh'), B.names.index('Bip01 R Thigh')

    def fn(v, q, co0):
        k = 0.7 * q * min(1.0, depth / 0.12)
        if k <= 0.0:
            return
        sl = 0.5 + 0.5 * max(-1.0, min(1.0, co0.x / 0.06))
        d = v[dl]
        for g, x in list(d.items()):
            d[g] = x * (1.0 - k)
        d[gl] = d.get(gl, 0.0) + k * sl
        d[gr] = d.get(gr, 0.0) + k * (1.0 - sl)
    return fn


def _top(B, hem, off, smooth, flare=1.03, wrist=0.8, wrinkle=1.0, extra=None):
    def pick(co, w):
        if hand_w(w) > 0.85 or head_w(w) + w.get('Bip01 Neck', 0.0) > 0.72:
            return False
        if top_w(w) >= 0.3:
            return True
        return co.z > ZC - 0.1 and abs(co.x) < 0.3 and legs_w(w) > 0.3
    def off2(co, w):
        o = off(co, w)
        if abs(co.x) < 0.3 and co.z < 1.1:
            # w pasie góra odstaje na tyle, żeby schować pasek, szlufki i kieszenie spodni (przebijały na plecach)
            k = min(1.0, (1.1 - co.z) / 0.07)
            o = max(o, 0.026 * k * k * (3 - 2 * k))
        if abs(co.x) < 0.3 and co.z < 1.0:
            o = max(o, 0.012 + 0.02 * min(1.0, (1.0 - co.z) / 0.06))
        return o
    def post(bm):
        cut(bm, Vector((0, 0, ZC)), -Z, lambda c: abs(c.x) < 0.32 and c.z < 1.02)
        # brzeg przy szyi: równa, pochylona płaszczyzna (z przodu niżej), bez postrzępionego karku
        cut(bm, NECK_CO, NECK_NO, lambda c: abs(c.x) < 0.2 and c.z > 1.44)
        for sd in ('L', 'R'):
            a, b = B.H['Bip01 %s Forearm' % sd], B.H['Bip01 %s Hand' % sd]
            sx = 1 if sd == 'L' else -1
            d = (b - a).normalized()
            cut(bm, a.lerp(b, SLEEVE), d, lambda c, sx=sx: c.x * sx > 0.36)
            on_arm = lambda m, sx=sx, a=a, b=b, d=d: m.x * sx > 0.36 and abs((m - a.lerp(b, SLEEVE)).dot(d)) < 0.002
            p0, p1 = a.lerp(b, SLEEVE), a.lerp(b, WRIST)
            lengthen(bm, on_arm, lambda co, p0=p0, p1=p1: p1 + (co - p0) * wrist, 4, 1.0, _cuff_w(B, bm, sd))
        on_hip = lambda m: abs(m.z - ZC) < 0.002 and abs(m.x) < 0.32
        vs = [v.co for v in bm.verts if v.is_boundary and on_hip(v.co)]
        if vs and hem < ZC - 0.005:
            c = sum(vs, Vector()) / len(vs)
            lengthen(bm, on_hip, lambda co: Vector((c.x + (co.x - c.x) * flare, c.y + (co.y - c.y) * flare, hem)),
                     max(2, int((ZC - hem) / 0.035) + 1), 1.0, _skirt_w(B, bm, ZC - hem))
        if extra is not None:
            extra(bm)
        # W pasie góra trzyma większy odstęp od ciała. Ciało ma tam wymodelowane szlufki i patki własnych spodni:
        # mocniej wygładzona góra kładła się na tych guzach, a mniej wygładzone spodnie przebijały przez nią plamami.
        waist = [v for v in bm.verts if not v.is_boundary and abs(v.co.x) < 0.3 and 0.86 < v.co.z < 1.12]
        for rnd in range(3):
            for v in bm.verts:
                g = 0.005
                if abs(v.co.x) < 0.3 and v.co.z < 1.1:
                    k = min(1.0, (1.1 - v.co.z) / 0.07)
                    g += 0.019 * k * k * (3 - 2 * k)
                loc, nrm, _, _ = B.tree.find_nearest(v.co)
                if loc is not None and (v.co - loc).dot(nrm) < g:
                    v.co = loc + nrm * g
            if rnd < 2:
                # odsunięte guzy rozchodzą się w gładkie wybrzuszenie zamiast pojedynczych garbów
                for _ in range(3):
                    bmesh.ops.smooth_vert(bm, verts=waist, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    bm, lps = shell(B, pick, off2, smooth, wrinkle=wrinkle, post=post)
    neck = pick_loops(lps, lambda c: c.z > 1.42 and abs(c.x) < 0.1)
    neck = [_neck_ring(neck)] if neck else []
    cuffs = pick_loops(lps, lambda c: abs(c.x) > 0.4)
    hems = pick_loops(lps, lambda c: c.z < 1.0 and abs(c.x) < 0.15)
    print('   góra: szyja %d, mankiety %d, dół %d' % (len(neck), len(cuffs), len(hems)))
    return bm, BVHTree.FromBMesh(bm), neck, cuffs, hems


def _neck_ring(lps, n=60):
    """Regularny pierścień wokół szyi. Brzeg powłoki jest tam poszarpany (ciało ma z przodu zachodzące na siebie poły
    kołnierza), więc kołnierze szyje się na wygładzonym obrysie: promień = największy w oknie kąta, wysokość z płaszczyzny cięcia."""
    pts = [p for lp in lps for p in lp]
    c = sum(pts, Vector()) / len(pts)
    rad = []
    for k in range(n):
        a = k / n * math.tau
        best = 0.0
        for p in pts:
            dx, dy = p.x - c.x, p.y - c.y
            da = abs((math.atan2(dx, -dy) - a + math.pi) % math.tau - math.pi)
            if da < math.radians(14):
                best = max(best, math.hypot(dx, dy))
        rad.append(best)
    for _ in range(4):
        rad = [rad[k] if rad[k] > 0.0 else max(rad[k - 1], rad[(k + 1) % n]) for k in range(n)]
    for _ in range(4):
        rad = [(rad[k - 1] + 2 * rad[k] + rad[(k + 1) % n]) / 4 for k in range(n)]
    ring = []
    for k in range(n):
        a = k / n * math.tau
        x, y = c.x + math.sin(a) * rad[k], c.y - math.cos(a) * rad[k]
        ring.append(Vector((x, y, NECK_CO.z - (NECK_NO.x * (x - NECK_CO.x) + NECK_NO.y * (y - NECK_CO.y)) / NECK_NO.z)))
    return ring


def _collar_stand(ring, material, parts, height=0.038, lean=0.006, thick=0.004, name='stojka'):
    """stójka: gładki pas wokół szyi; u dołu szerszy (zakrywa pofałdowany brzeg powłoki), ku górze pochyla się do środka"""
    c = sum(ring, Vector()) / len(ring)
    vb = bmesh.new()
    rows = []
    for p in ring:
        e = Vector((p.x - c.x, p.y - c.y, 0)).normalized()
        rows.append((vb.verts.new(p - Z * 0.022 + e * 0.017),
                     vb.verts.new(p + Z * (height * 0.3) + e * 0.012),
                     vb.verts.new(p + Z * (height * 0.7) + e * (0.01 - lean * 0.5)),
                     vb.verts.new(p + Z * height + e * (0.009 - lean))))
    n = len(rows)
    for i in range(n):
        for k in range(3):
            vb.faces.new((rows[i][k], rows[i][k + 1], rows[(i + 1) % n][k + 1], rows[(i + 1) % n][k]))
    bmesh.ops.recalc_face_normals(vb, faces=vb.faces[:])
    bmesh.ops.solidify(vb, geom=vb.faces[:], thickness=thick)
    parts.append(mesh_object(vb, name, material))


def _collar_leaf(ring, material, parts, stand=0.014, back=(0.02, 0.03), front=(0.034, 0.05), gap=24.0, name='kolnierz', thick=0.003, tree=None):
    """Wykładany kołnierz na pierścieniu szyi: stójka i liść, z tyłu węższy, z przodu rogi; gap = rozchylenie z przodu
    (stopnie). Z `tree` (powłoka ubrania) liść leży płasko na barkach i piersi — bez tego sterczał w bok jak wałek."""
    c = sum(ring, Vector()) / len(ring)
    n = len(ring)
    vb = bmesh.new()
    rows = []

    def lay(q, fallback, lift):
        if tree is not None:
            loc, nrm, _, _ = tree.ray_cast(Vector((q.x, q.y, q.z + 0.12)), DOWN, 0.4)
            if loc is not None:
                return loc + nrm * lift
        return fallback
    for k, p in enumerate(ring):
        a = k / n * 360.0
        if a < gap / 2 or a > 360.0 - gap / 2:
            continue
        e = Vector((p.x - c.x, p.y - c.y, 0)).normalized()
        fr = ((1.0 + math.cos(math.radians(a))) / 2.0) ** 2
        w = back[0] + (front[0] - back[0]) * fr
        dr = back[1] + (front[1] - back[1]) * fr
        # rogi: przy samym rozchyleniu liść wydłuża się w szpic
        edge = max(0.0, 1.0 - min(a - gap / 2, 360.0 - gap / 2 - a) / 16.0)
        dr += 0.012 * edge
        w += 0.01 * edge
        rows.append((vb.verts.new(p - Z * 0.016 + e * 0.006),
                     vb.verts.new(p + Z * stand + e * 0.004),
                     vb.verts.new(p + Z * (stand * 0.85) + e * 0.013),
                     vb.verts.new(lay(p + e * (w * 0.55 + 0.012), p + e * (w * 0.5 + 0.006) - Z * (dr * 0.3), 0.007)),
                     vb.verts.new(lay(p + e * (w + 0.012), p + e * (w + 0.007) - Z * dr, 0.0045))))
    for i in range(len(rows) - 1):
        for k in range(4):
            vb.faces.new((rows[i][k], rows[i][k + 1], rows[i + 1][k + 1], rows[i + 1][k]))
    bmesh.ops.recalc_face_normals(vb, faces=vb.faces[:])
    bmesh.ops.solidify(vb, geom=vb.faces[:], thickness=thick)
    parts.append(mesh_object(vb, name, material))


def _arm_dir(B, c):
    side = 'L' if c.x > 0 else 'R'
    return (B.H['Bip01 %s Hand' % side] - B.H['Bip01 %s Forearm' % side]).normalized()


def _cuff(B, co, t0=0.9):
    return abs(co.x) > 0.3 and along(B, co, 'Forearm', 'Hand') > t0


def bluza_kaptur():
    """bluza z kapturem: luźna dzianina, ściągacze na mankietach i dole, kieszeń-kangurka, kaptur ze sznurkami"""
    B = Body()
    knit = mat('dzianina_bluza', '4d5563', 0.95)
    rib = mat('sciagacz_bluza', '434a57', 0.95)
    cord = mat('plotno_sznurek', 'd8d6cf', 0.9)

    def off(co, w):
        if co.z < 0.9:
            return 0.02
        if part(w, ('UpperArm', 'Forearm')) > 0.5:
            return 0.011 if along(B, co, 'Forearm', 'Hand') > 0.82 else 0.017
        return 0.02 + 0.008 * max(0.0, 1.0 - abs(co.z - 0.98) / 0.1)
    bm, tree, neck, cuffs, hems = _top(B, 0.83, off, 3)
    ob = to_object(B, bm, 'bluza_kaptur', [knit, rib, cord])
    paint(ob, lambda c, n: c.z < 0.875 or _cuff(B, c), 1)
    parts = []
    for lp in neck:
        _collar_stand(lp, rib, parts, 0.012, 0.002, 0.003, name='karczek')
    for lp in cuffs:
        c = sum(lp, Vector()) / len(lp)
        parts.append(band(lp, 0.012, rib, 'mankiet', 0.001, 2.4, _arm_dir(B, c) * 0.012))
    for lp in hems:
        parts.append(band(lp, 0.012, rib, 'dol', 0.0, 2.6, Z * 0.012))
    parts.append(patch(tree, Vector((0, -0.3, 1.04)), X, Z, 0.31, 0.15, 0.011, knit, 'kangurka', 9, 6, 0.5, FRONT))
    for sx in (-1, 1):
        parts.append(stitch(tree, Vector((sx * 0.15, -0.3, 1.1)), Vector((sx * 0.1, -0.3, 0.975)), FRONT, rib, 6, 0.004, 0.011, 'wlot'))
        a = Vector((sx * 0.035, -0.3, 1.47))
        b = Vector((sx * 0.05, -0.3, 1.33))
        parts.append(stitch(tree, a, b, FRONT, cord, 8, 0.0032, 0.004, 'sznurek'))
        end, _ = on_surface(tree, b + Vector((0, 0, -0.012)), FRONT, 0.005)
        parts.append(lathe('koncowka', [(0.0, -0.012), (0.004, -0.012), (0.0045, 0.008), (0.0, 0.008)], mat('metal_koncowka', 'b9bcc2', 0.3, 0.9), 8, loc=tuple(end)))
    # kaptur leżący na karku: miękka sakwa z rantem
    nk = B.H['Bip01 Neck']
    hb = bmesh.new()
    bmesh.ops.create_uvsphere(hb, u_segments=18, v_segments=10, radius=1.0)
    for v in hb.verts:
        x, y, z = v.co
        sag = 1.0 - 0.35 * max(0.0, -z)
        v.co = Vector((x * 0.165 * sag, y * 0.085, z * 0.125 - 0.03 * (y + 1.0)))
    bmesh.ops.delete(hb, geom=[v for v in hb.verts if v.co.z > 0.05 and v.co.y < 0.03], context='VERTS')
    hb.transform(Matrix.Translation(nk + Vector((0, 0.105, 0.005))) @ Matrix.Rotation(math.radians(-22), 4, 'X'))
    for lp in loops(hb, lambda c: True):
        parts.append(band(lp, 0.011, rib, 'rant_kaptura'))
    parts.append(mesh_object(hb, 'kaptur', knit))
    finish(B, ob, parts, 'bluza_kaptur')


def kurtka_kieszenie():
    """kurtka polowa: sztywne płótno, stójka, zamek pod plisą, cztery kieszenie z patkami na zatrzask, ściągacz w pasie, patki na mankietach"""
    B = Body()
    cloth = mat('plotno_kurtka', '4f5a44', 0.9)
    dark = mat('plotno_kurtka_c', '434d3a', 0.9)
    metal = mat('metal_zamek', '6f7378', 0.4, 0.9)

    def off(co, w):
        if part(w, ('UpperArm', 'Forearm')) > 0.5:
            return 0.014 if along(B, co, 'Forearm', 'Hand') > 0.86 else 0.02
        return 0.023
    bm, tree, neck, cuffs, hems = _top(B, 0.79, off, 2)
    ob = to_object(B, bm, 'kurtka_kieszenie', [cloth, dark, metal])
    parts = []
    for lp in neck:
        _collar_stand(lp, dark, parts, 0.042, 0.007)
    for lp in cuffs:
        c = sum(lp, Vector()) / len(lp)
        parts.append(band(lp, 0.011, dark, 'mankiet', 0.001, 2.6, _arm_dir(B, c) * 0.01, wide=0.7))
    for lp in hems:
        parts.append(band(lp, 0.008, dark, 'dol', 0.001, 1.6))
    # plisa z zamkiem przez cały przód
    parts.append(ribbon(tree, Vector((0.012, -0.3, 0.87)), Vector((0.012, -0.3, 1.47)), FRONT, 0.05, dark, 18, 0.006, 'plisa', 0.003))
    parts.append(ribbon(tree, Vector((-0.016, -0.3, 0.87)), Vector((-0.016, -0.3, 1.47)), FRONT, 0.006, metal, 18, 0.004, 'zamek', 0.002))
    for z in (0.88, 1.02, 1.16, 1.3, 1.43):
        parts.append(button(tree, Vector((0.012, -0.3, z)), FRONT, metal, 0.007, 0.0095))
    for sx in (-1, 1):
        for cz, w, h in ((1.33, 0.105, 0.115), (0.99, 0.135, 0.145)):
            c = Vector((sx * (0.108 if cz > 1.2 else 0.125), -0.3, cz))
            parts.append(patch(tree, c, X, Z, w, h, 0.008, cloth, 'kieszen', 6, 6, 0.3, FRONT))
            parts.append(patch(tree, c + Z * (h / 2 - 0.012), X, Z, w + 0.008, 0.045, 0.014, dark, 'patka', 6, 3, 0.5, FRONT))
            parts.append(button(tree, c + Z * (h / 2 - 0.022), FRONT, metal, 0.006, 0.0155))
        # szwy na ramionach i pagony
        a = Vector((sx * 0.06, 0.0, 1.9))
        b = Vector((sx * 0.2, 0.0, 1.9))
        parts.append(ribbon(tree, a, b, DOWN, 0.04, dark, 6, 0.006, 'pagon', 0.002))
        parts.append(button(tree, Vector((sx * 0.085, 0.0, 1.9)), DOWN, metal, 0.005, 0.009))
    finish(B, ob, parts, 'kurtka_kieszenie')


def koszula():
    """koszula w kratę: cienkie płótno, kołnierzyk z rogami, plisa z guzikami, kieszonka na piersi, mankiety"""
    B = Body()
    plaid = mat('krata_koszula', '8f3a33', 0.9)
    btn = mat('guzik_koszula', 'e6dfcf', 0.4)

    def off(co, w):
        return 0.005 if part(w, ('UpperArm', 'Forearm')) > 0.5 else 0.006
    bm, tree, neck, cuffs, hems = _top(B, 0.84, off, 1)
    ob = to_object(B, bm, 'koszula', [plaid, btn])
    parts = []
    for lp in neck:
        _collar_stand(lp, plaid, parts, 0.012, 0.003)
        _collar_leaf(lp, plaid, parts, 0.016, (0.02, 0.03), (0.036, 0.052), 26.0, 'kolnierzyk', tree=tree)
    for lp in cuffs:
        c = sum(lp, Vector()) / len(lp)
        parts.append(band(lp, 0.009, plaid, 'mankiet', 0.001, 3.0, _arm_dir(B, c) * 0.004, wide=0.6))
        parts.append(button(tree, c + Vector((0, -0.05, 0.0)), FRONT, btn, 0.005, 0.011))
    parts.append(ribbon(tree, Vector((0.0, -0.3, 0.86)), Vector((0.0, -0.3, 1.46)), FRONT, 0.032, plaid, 18, 0.004, 'plisa', 0.001))
    for k in range(7):
        parts.append(button(tree, Vector((0.0, -0.3, 0.9 + k * 0.088)), FRONT, btn, 0.0055, 0.006))
    parts.append(patch(tree, Vector((0.105, -0.3, 1.33)), X, Z, 0.095, 0.105, 0.004, plaid, 'kieszonka', 5, 5, 0.25, FRONT))
    finish(B, ob, parts, 'koszula')


def kurtka_skorzana():
    """ramoneska: czarna skóra, wykładany kołnierz z klapami, skośny zamek, kieszenie na zamek, pas ze sprzączką"""
    B = Body()
    lea = mat('skora_ramoneska', '242220', 0.62)
    dark = mat('skora_ramoneska_c', '1c1a19', 0.62)
    metal = mat('metal_zamek', 'a9adb3', 0.35, 0.9)

    def off(co, w):
        if part(w, ('UpperArm', 'Forearm')) > 0.5:
            return 0.012 if along(B, co, 'Forearm', 'Hand') > 0.86 else 0.016
        return 0.018
    bm, tree, neck, cuffs, hems = _top(B, 0.86, off, 3, 1.02, 0.84, 0.5)
    ob = to_object(B, bm, 'kurtka_skorzana', [lea, dark, metal])
    parts = []
    for lp in neck:
        _collar_stand(lp, lea, parts, 0.012, 0.003)
        _collar_leaf(lp, dark, parts, 0.018, (0.03, 0.04), (0.055, 0.085), 40.0, 'kolnierz', 0.004, tree=tree)
    for lp in cuffs:
        c = sum(lp, Vector()) / len(lp)
        parts.append(band(lp, 0.008, dark, 'mankiet', 0.001, 2.0, _arm_dir(B, c) * 0.006, wide=0.7))
    for lp in hems:
        parts.append(band(lp, 0.011, dark, 'pas', 0.001, 2.6, Z * 0.006))
    for sx in (-1, 1):
        parts.append(ribbon(tree, Vector((sx * 0.07, -0.3, 1.12)), Vector((sx * 0.15, -0.3, 1.02)), FRONT, 0.008, metal, 8, 0.004, 'zamek_kieszeni', 0.002))
        parts.append(ribbon(tree, Vector((sx * 0.06, 0.0, 1.9)), Vector((sx * 0.19, 0.0, 1.9)), DOWN, 0.035, dark, 6, 0.005, 'pagon', 0.002))
        parts.append(button(tree, Vector((sx * 0.085, 0.0, 1.9)), DOWN, metal, 0.005, 0.008))
    parts.append(ribbon(tree, Vector((0.06, -0.3, 0.9)), Vector((-0.03, -0.3, 1.38)), FRONT, 0.008, metal, 18, 0.005, 'zamek', 0.002))
    loc, _ = on_surface(tree, Vector((0.05, -0.3, 0.885)), FRONT, 0.008)
    parts.append(rbox('sprzaczka', (0.035, 0.008, 0.028), metal, 0.003, tuple(loc)))
    finish(B, ob, parts, 'kurtka_skorzana')


def dres_gora():
    """bluza dresowa: śliska dzianina, stójka, zamek na całej długości, ściągacze, trzy białe paski wzdłuż rękawów"""
    B = Body()
    knit = mat('dzianina_dres_gora', '1f2a44', 0.8)
    rib = mat('sciagacz_dres_gora', '18213a', 0.9)
    white = mat('dzianina_lampas', 'e4e2dc', 0.9)
    metal = mat('metal_zamek', 'a9adb3', 0.35, 0.9)

    def off(co, w):
        if part(w, ('UpperArm', 'Forearm')) > 0.5:
            return 0.01 if along(B, co, 'Forearm', 'Hand') > 0.84 else 0.014
        return 0.016
    bm, tree, neck, cuffs, hems = _top(B, 0.85, off, 3)
    ob = to_object(B, bm, 'dres_gora', [knit, rib, white, metal])
    paint(ob, lambda c, n: c.z < 0.888 or _cuff(B, c), 1)
    parts = []
    for lp in neck:
        _collar_stand(lp, rib, parts, 0.046, 0.005)
    for lp in cuffs:
        c = sum(lp, Vector()) / len(lp)
        parts.append(band(lp, 0.01, rib, 'mankiet', 0.001, 2.4, _arm_dir(B, c) * 0.01))
    for lp in hems:
        parts.append(band(lp, 0.011, rib, 'dol', 0.0, 2.4, Z * 0.01))
    parts.append(ribbon(tree, Vector((0.0, -0.3, 0.88)), Vector((0.0, -0.3, 1.48)), FRONT, 0.007, metal, 18, 0.004, 'zamek', 0.002))
    for sd in ('L', 'R'):
        sh, el, wr = B.H['Bip01 %s UpperArm' % sd], B.H['Bip01 %s Forearm' % sd], B.H['Bip01 %s Hand' % sd]
        for a, b, t0, t1 in ((sh, el, 0.1, 1.0), (el, wr, 0.0, 0.8)):
            d = (b - a).normalized()
            up = (Z - d * Z.dot(d)).normalized()      # zewnętrzna strona ręki (w pozie spoczynkowej: wierzch)
            fw = d.cross(up).normalized()
            for k in (-1, 0, 1):
                p0 = a.lerp(b, t0) + fw * (0.02 * k) + up * 0.1
                p1 = a.lerp(b, t1) + fw * (0.02 * k) + up * 0.1
                parts.append(ribbon(tree, p0, p1, -up, 0.011, white, 10, 0.0025, 'pasek', 0.0008))
    finish(B, ob, parts, 'dres_gora')


def kurtka_puchowa():
    """kurtka puchowa: pikowane komory (poziome na tułowiu, w poprzek rękawów), wysoka stójka, zamek, ściągacze, kieszenie na zamek"""
    B = Body()
    nylon = mat('plotno_puch', '27324a', 0.5)
    rib = mat('sciagacz_puch', '1d2536', 0.9)
    metal = mat('metal_zamek', 'a9adb3', 0.35, 0.9)
    sh = {sd: B.H['Bip01 %s UpperArm' % sd] for sd in ('L', 'R')}
    hem = 0.84

    def off(co, w):
        return 0.015 if part(w, ('UpperArm', 'Forearm')) > 0.5 else 0.019

    def puff(bm):
        # gęstsza siatka, żeby komory miały z czego się wybrzuszyć
        bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=1, smooth=0.3, use_grid_fill=True)
        bm.normal_update()
        for v in bm.verts:
            if v.is_boundary:
                continue
            co = v.co
            sd = 'L' if co.x > 0 else 'R'
            if abs(co.x) > 0.2:
                q = (co - sh[sd]).length / 0.082
                edge = min(1.0, max(0.0, (1.0 - along(B, co, 'Forearm', 'Hand')) / 0.08))
            else:
                q = (co.z - hem) / 0.088
                edge = min(1.0, max(0.0, (co.z - hem - 0.04) / 0.03)) * min(1.0, max(0.0, (1.5 - co.z) / 0.04))
            p = abs(math.sin(math.pi * q)) ** 0.5
            v.co += v.normal * ((0.014 * p - 0.003) * edge)
    bm, tree, neck, cuffs, hems = _top(B, hem, off, 3, 1.0, 0.82, 0.3, puff)
    ob = to_object(B, bm, 'kurtka_puchowa', [nylon, rib, metal])
    paint(ob, lambda c, n: c.z < hem + 0.036 or _cuff(B, c, 0.97), 1)
    parts = []
    for lp in neck:
        _collar_stand(lp, nylon, parts, 0.055, 0.004, 0.006)
    for lp in cuffs:
        c = sum(lp, Vector()) / len(lp)
        parts.append(band(lp, 0.009, rib, 'mankiet', 0.001, 2.2, _arm_dir(B, c) * 0.006))
    for lp in hems:
        parts.append(band(lp, 0.01, rib, 'dol', 0.0, 2.2, Z * 0.008))
    parts.append(ribbon(tree, Vector((0.0, -0.3, hem + 0.03)), Vector((0.0, -0.3, 1.5)), FRONT, 0.012, rib, 30, 0.004, 'plisa', 0.002))
    parts.append(ribbon(tree, Vector((0.0, -0.3, hem + 0.03)), Vector((0.0, -0.3, 1.5)), FRONT, 0.005, metal, 30, 0.0065, 'zamek', 0.002))
    for sx in (-1, 1):
        parts.append(ribbon(tree, Vector((sx * 0.085, -0.3, 1.09)), Vector((sx * 0.15, -0.3, 0.98)), FRONT, 0.007, metal, 8, 0.004, 'zamek_kieszeni', 0.002))
    finish(B, ob, parts, 'kurtka_puchowa')


def marynarka():
    """marynarka: wełna, wykładany kołnierz z klapami do zapięcia na dwa guziki, kieszenie z patkami, brustasza,
    pod spodem widać białą koszulę"""
    B = Body()
    wool = mat('plotno_marynarka', '3a3f4c', 0.85)
    dark = mat('plotno_marynarka_c', '30343f', 0.85)
    shirt = mat('plotno_koszula_biala', 'e8e6df', 0.8)
    btn = mat('guzik_marynarka', '23252b', 0.5)

    def off(co, w):
        if part(w, ('UpperArm', 'Forearm')) > 0.5:
            return 0.011 if along(B, co, 'Forearm', 'Hand') > 0.86 else 0.014
        return 0.017
    bm, tree, neck, cuffs, hems = _top(B, 0.8, off, 2, 1.03, 0.86, 0.45)
    ob = to_object(B, bm, 'marynarka', [wool, dark, shirt, btn])
    parts = []
    for lp in neck:
        _collar_stand(lp, shirt, parts, 0.016, 0.008, 0.003, 'kolnierzyk')
        _collar_leaf(lp, dark, parts, 0.008, (0.028, 0.036), (0.028, 0.036), 120.0, 'kolnierz', 0.004, tree=tree)
    for lp in cuffs:
        c = sum(lp, Vector()) / len(lp)
        parts.append(band(lp, 0.006, shirt, 'mankiet_koszuli', -0.002, 1.6, _arm_dir(B, c) * 0.004, wide=0.6))
        for k in range(3):
            parts.append(button(tree, c - _arm_dir(B, c) * (0.03 + k * 0.018) + Vector((0, 0.06, 0)), BACK, btn, 0.0045, 0.004))
    for lp in hems:
        parts.append(band(lp, 0.004, dark, 'dol', 0.0005, 1.4))
    # biała koszula w wycięciu i klapy schodzące do górnego guzika
    zb = 1.13
    parts.append(patch(tree, Vector((0, -0.3, 1.31)), X, Z, 0.1, 0.34, 0.0055, shirt, 'gors', 6, 14, 0.2, FRONT))
    for sx in (-1, 1):
        a = Vector((sx * 0.05, -0.3, 1.48))
        b = Vector((sx * 0.004, -0.3, zb))
        parts.append(ribbon(tree, a + X * sx * 0.04, b + X * sx * 0.042, FRONT, 0.085, dark, 18, 0.0095, 'klapa', 0.003))
        # wcięcie klapy
        parts.append(stitch(tree, Vector((sx * 0.105, -0.3, 1.39)), Vector((sx * 0.06, -0.3, 1.375)), FRONT, wool, 4, 0.002, 0.0125, 'wciecie'))
        c = Vector((sx * 0.13, -0.3, 0.99))
        parts.append(patch(tree, c, X, Z, 0.13, 0.045, 0.006, dark, 'patka', 6, 3, 0.35, FRONT))
    parts.append(ribbon(tree, Vector((0.075, -0.3, 1.3)), Vector((0.145, -0.3, 1.3)), FRONT, 0.014, dark, 5, 0.004, 'brustasza', 0.001))
    parts.append(ribbon(tree, Vector((0.012, -0.3, 0.82)), Vector((0.012, -0.3, zb)), FRONT, 0.012, dark, 10, 0.004, 'zapiecie', 0.001))
    for z in (zb - 0.03, zb - 0.13):
        parts.append(button(tree, Vector((0.02, -0.3, z)), FRONT, btn, 0.008, 0.006))
    finish(B, ob, parts, 'marynarka')


def plaszcz():
    """płaszcz: gruba wełna do połowy uda, dwurzędowe zapięcie, szeroki kołnierz, pasek ze sprzączką, kieszenie na skos"""
    B = Body()
    wool = mat('plotno_plaszcz', '6f5a3e', 0.9)
    dark = mat('plotno_plaszcz_c', '5c4a33', 0.9)
    btn = mat('guzik_plaszcz', '2e241a', 0.5)
    metal = mat('metal_klamra', 'b9bcc2', 0.3, 0.9)

    def off(co, w):
        if part(w, ('UpperArm', 'Forearm')) > 0.5:
            return 0.014 if along(B, co, 'Forearm', 'Hand') > 0.86 else 0.019
        return 0.024
    bm, tree, neck, cuffs, hems = _top(B, 0.64, off, 2, 1.1, 0.86, 0.5)
    ob = to_object(B, bm, 'plaszcz', [wool, dark, btn, metal])
    parts = []
    for lp in neck:
        _collar_stand(lp, wool, parts, 0.014, 0.003)
        _collar_leaf(lp, dark, parts, 0.02, (0.04, 0.05), (0.07, 0.11), 50.0, 'kolnierz', 0.005, tree=tree)
    for lp in cuffs:
        c = sum(lp, Vector()) / len(lp)
        parts.append(band(lp, 0.007, dark, 'mankiet', 0.001, 2.4, _arm_dir(B, c) * 0.006, wide=0.6))
    for lp in hems:
        parts.append(band(lp, 0.005, dark, 'dol', 0.0005, 1.4))
    parts.append(ribbon(tree, Vector((0.06, -0.3, 0.68)), Vector((0.06, -0.3, 1.4)), FRONT, 0.012, dark, 20, 0.005, 'zakladka', 0.002))
    for z in (0.98, 1.14, 1.3):
        for x in (-0.05, 0.1):
            parts.append(button(tree, Vector((x, -0.3, z)), FRONT, btn, 0.011, 0.008))
    # pasek w talii ze sprzączką i szlufkami
    zp = 1.06
    pts = []
    for k in range(36):
        an = k / 36 * math.tau
        d = Vector((math.sin(an), -math.cos(an), 0))
        loc, nrm, _, _ = tree.ray_cast(Vector((0, 0, zp)) + d * 0.5, -d, 0.6)
        if loc is not None:
            pts.append(loc + nrm * 0.004)
    if len(pts) > 20:
        parts.append(sweep('pasek', pts, 0.006, dark, 5, True, 3.2, 0.5))
        loc, _ = on_surface(tree, Vector((0.02, -0.3, zp)), FRONT, 0.011)
        parts.append(rbox('sprzaczka', (0.05, 0.008, 0.045), metal, 0.003, tuple(loc)))
    for sx in (-1, 1):
        parts.append(ribbon(tree, Vector((sx * 0.1, -0.3, 0.95)), Vector((sx * 0.16, -0.3, 0.82)), FRONT, 0.02, dark, 8, 0.006, 'kieszen', 0.002))
    finish(B, ob, parts, 'plaszcz')


def kurtka_jeans():
    """kurtka jeansowa: sztywny dżins, karczek z przeszyciami, kieszenie na piersi ze spiczastymi patkami, metalowe guziki, pas u dołu"""
    B = Body()
    denim = mat('dzins_kurtka', '4f6f9c', 0.85)
    light = mat('dzins_kurtka_j', '6f8bb5', 0.85)
    thread = mat('plotno_nic', 'c99a3e', 0.8)
    metal = mat('metal_guzik', 'b08a4a', 0.35, 0.9)

    def off(co, w):
        if part(w, ('UpperArm', 'Forearm')) > 0.5:
            return 0.011 if along(B, co, 'Forearm', 'Hand') > 0.86 else 0.015
        return 0.017
    bm, tree, neck, cuffs, hems = _top(B, 0.88, off, 2, 1.0, 0.86, 0.6)
    ob = to_object(B, bm, 'kurtka_jeans', [denim, light, thread, metal])
    parts = []
    for lp in neck:
        _collar_stand(lp, denim, parts, 0.012, 0.003)
        _collar_leaf(lp, denim, parts, 0.018, (0.03, 0.04), (0.045, 0.065), 34.0, 'kolnierz', 0.004, tree=tree)
    for lp in cuffs:
        c = sum(lp, Vector()) / len(lp)
        parts.append(band(lp, 0.008, denim, 'mankiet', 0.001, 2.6, _arm_dir(B, c) * 0.008, wide=0.6))
        parts.append(button(tree, c - _arm_dir(B, c) * 0.02 + Vector((0, -0.06, 0)), FRONT, metal, 0.006, 0.008))
    for lp in hems:
        parts.append(band(lp, 0.011, denim, 'pas', 0.001, 2.8, Z * 0.012, wide=0.6))
    parts.append(ribbon(tree, Vector((0.0, -0.3, 0.9)), Vector((0.0, -0.3, 1.46)), FRONT, 0.04, denim, 18, 0.005, 'plisa', 0.002))
    for k in range(6):
        parts.append(button(tree, Vector((0.0, -0.3, 0.93 + k * 0.1)), FRONT, metal, 0.008, 0.008))
    for sx in (-1, 1):
        # szew karczka, kieszeń na piersi z patką w szpic, skośne przeszycia do pasa
        parts.append(stitch(tree, Vector((sx * 0.03, -0.3, 1.39)), Vector((sx * 0.2, -0.3, 1.39)), FRONT, thread, 8, 0.0013, 0.002, 'karczek'))
        c = Vector((sx * 0.105, -0.3, 1.29))
        parts.append(patch(tree, c, X, Z, 0.105, 0.11, 0.005, denim, 'kieszen', 5, 5, 0.2, FRONT))
        parts.append(patch(tree, c + Z * 0.05, X, Z, 0.11, 0.05, 0.009, light, 'patka', 5, 3, 0.9, FRONT))
        parts.append(button(tree, c + Z * 0.036, FRONT, metal, 0.006, 0.0105))
        for dx in (0.045, 0.165):
            parts.append(stitch(tree, Vector((sx * dx, -0.3, 1.23)), Vector((sx * (dx + 0.02), -0.3, 0.93)), FRONT, thread, 10, 0.0013, 0.002, 'przeszycie'))
        parts.append(stitch(tree, Vector((sx * 0.03, 0.3, 1.4)), Vector((sx * 0.2, 0.3, 1.37)), BACK, thread, 8, 0.0013, 0.002, 'karczek_tyl'))
    finish(B, ob, parts, 'kurtka_jeans')


def sweter():
    """sweter: gruba dzianina, okrągły ściągacz pod szyją, warkocze z przodu, ściągacze na mankietach i dole"""
    B = Body()
    knit = mat('dzianina_sweter', '7a3b34', 0.95)
    rib = mat('sciagacz_sweter', '6a322c', 0.95)

    def off(co, w):
        if part(w, ('UpperArm', 'Forearm')) > 0.5:
            return 0.009 if along(B, co, 'Forearm', 'Hand') > 0.84 else 0.013
        return 0.014
    bm, tree, neck, cuffs, hems = _top(B, 0.86, off, 3)
    ob = to_object(B, bm, 'sweter', [knit, rib])
    paint(ob, lambda c, n: c.z < 0.9 or _cuff(B, c), 1)
    parts = []
    for lp in neck:
        _collar_stand(lp, rib, parts, 0.014, 0.002, 0.004, 'sciagacz_szyi')
    for lp in cuffs:
        c = sum(lp, Vector()) / len(lp)
        parts.append(band(lp, 0.009, rib, 'mankiet', 0.001, 2.4, _arm_dir(B, c) * 0.01))
    for lp in hems:
        parts.append(band(lp, 0.01, rib, 'dol', 0.0, 2.4, Z * 0.01))
    # warkocze: trzy pionowe sploty z przodu (każdy z dwóch przeplatających się pasm) i prążki między nimi
    for x in (-0.085, 0.0, 0.085):
        for ph in (0.0, math.pi):
            pts = []
            for k in range(29):
                z = 0.93 + k * 0.0185
                p, _ = on_surface(tree, Vector((x + 0.011 * math.sin(k * 0.9 + ph), -0.3, z)), FRONT, 0.0035 + 0.002 * math.cos(k * 0.9 + ph))
                pts.append(p)
            parts.append(sweep('warkocz', pts, 0.0055, knit, 5))
    for x in (-0.135, -0.042, 0.042, 0.135):
        parts.append(stitch(tree, Vector((x, -0.3, 0.92)), Vector((x, -0.3, 1.44)), FRONT, rib, 16, 0.0028, 0.002, 'prazek'))
    finish(B, ob, parts, 'sweter')


def parka():
    """parka: długa kurtka do połowy uda, kaptur z futrzanym rantem, kryty zamek, dwie duże kieszenie z patkami, ściągacz w pasie"""
    B = Body()
    cloth = mat('plotno_parka', '3d4438', 0.92)
    dark = mat('plotno_parka_c', '33392f', 0.92)
    fur = mat('dzianina_futerko', '8a7b63', 1.0)
    metal = mat('metal_zamek', '6f7378', 0.4, 0.9)

    def off(co, w):
        if part(w, ('UpperArm', 'Forearm')) > 0.5:
            return 0.015 if along(B, co, 'Forearm', 'Hand') > 0.86 else 0.021
        return 0.026 if co.z < 0.95 else 0.024
    bm, tree, neck, cuffs, hems = _top(B, 0.74, off, 2, 1.07)
    ob = to_object(B, bm, 'parka', [cloth, dark, fur, metal])
    parts = []
    for lp in neck:
        _collar_stand(lp, dark, parts, 0.044, 0.006)
    for lp in cuffs:
        c = sum(lp, Vector()) / len(lp)
        parts.append(band(lp, 0.011, dark, 'mankiet', 0.001, 2.6, _arm_dir(B, c) * 0.01, wide=0.7))
    for lp in hems:
        parts.append(band(lp, 0.008, dark, 'dol', 0.001, 1.6))
    parts.append(ribbon(tree, Vector((0.012, -0.3, 0.765)), Vector((0.012, -0.3, 1.47)), FRONT, 0.055, dark, 20, 0.006, 'plisa', 0.003))
    for z in (0.8, 0.95, 1.1, 1.25, 1.4):
        parts.append(button(tree, Vector((0.012, -0.3, z)), FRONT, metal, 0.007, 0.0095))
    # sznurek ściągacza w pasie
    parts.append(ribbon(tree, Vector((-0.16, -0.3, 1.04)), Vector((0.16, -0.3, 1.04)), FRONT, 0.012, dark, 10, 0.004, 'sciagacz', 0.002))
    for sx in (-1, 1):
        c = Vector((sx * 0.125, -0.3, 0.9))
        parts.append(patch(tree, c, X, Z, 0.14, 0.14, 0.008, cloth, 'kieszen', 6, 6, 0.3, FRONT))
        parts.append(patch(tree, c + Z * 0.06, X, Z, 0.148, 0.048, 0.013, dark, 'patka', 6, 3, 0.5, FRONT))
        parts.append(button(tree, c + Z * 0.048, FRONT, metal, 0.006, 0.0145))
    # kaptur na karku z futrzanym rantem
    nk = B.H['Bip01 Neck']
    hb = bmesh.new()
    bmesh.ops.create_uvsphere(hb, u_segments=18, v_segments=10, radius=1.0)
    for v in hb.verts:
        x, y, z = v.co
        sag = 1.0 - 0.35 * max(0.0, -z)
        v.co = Vector((x * 0.18, y * 0.095, z * 0.14 - 0.03 * (y + 1.0)))
    bmesh.ops.delete(hb, geom=[v for v in hb.verts if v.co.z > 0.05 and v.co.y < 0.03], context='VERTS')
    hb.transform(Matrix.Translation(nk + Vector((0, 0.115, 0.01))) @ Matrix.Rotation(math.radians(-22), 4, 'X'))
    for lp in loops(hb, lambda c: True):
        parts.append(band(lp, 0.02, fur, 'futerko'))
    parts.append(mesh_object(hb, 'kaptur', cloth))
    finish(B, ob, parts, 'parka')


# ================================================================ SPODNIE
def chinosy():
    """chinosy: gładkie płótno, zaprasowany kant, pasek ze szlufkami, skośne kieszenie, nogawka bez podwinięcia"""
    B = Body()
    cloth = mat('plotno_chinosy', '8a7a5c', 0.9)
    dark = mat('plotno_chinosy_c', '76684e', 0.9)
    metal = mat('metal_guzik', '8a8d92', 0.35, 0.9)
    bm, tree, waist, ankles = _legs(B, lambda co, w: 0.007, 1, (0.088, 0.1), 0.8)
    ob = to_object(B, bm, 'chinosy', [cloth, dark, metal])
    parts = []
    for lp in waist:
        parts.append(band(lp, 0.01, dark, 'pasek', 0.002, 2.6, Z * -0.014, wide=0.7))
    for lp in ankles:
        parts.append(band(lp, 0.005, cloth, 'nogawka', 0.001, 1.4))
    wz = max((sum(lp, Vector()) / len(lp)).z for lp in waist) - 0.016 if waist else 0.98
    _belt_loops(tree, wz, dark, parts)
    parts.append(button(tree, Vector((0.0, -0.3, wz)), FRONT, metal, 0.007, 0.008))
    parts.append(ribbon(tree, Vector((0.014, -0.3, wz - 0.03)), Vector((0.014, -0.3, wz - 0.15)), FRONT, 0.028, cloth, 6, 0.004, 'rozporek', 0.001))
    for sx in (-1, 1):
        # kant z przodu nogawki i skośny wlot kieszeni
        parts.append(stitch(tree, Vector((sx * 0.095, -0.3, wz - 0.16)), Vector((sx * 0.095, -0.3, 0.16)), FRONT, dark, 22, 0.0016, 0.0022, 'kant'))
        pts = [on_surface(tree, Vector((sx * (0.07 + 0.1 * (k / 6)), -0.3, wz - 0.03 - 0.1 * (k / 6))), FRONT, 0.002)[0] for k in range(7)]
        parts.append(sweep('wlot', pts, 0.0014, dark, 4))
        c = Vector((sx * 0.088, 0.3, wz - 0.12))
        parts.append(ribbon(tree, c - X * 0.055, c + X * 0.055, BACK, 0.008, dark, 6, 0.003, 'kieszen_tyl', 0.001))
        parts.append(button(tree, c - Z * 0.012, BACK, metal, 0.005, 0.004))
    finish(B, ob, parts, 'chinosy')


ZL = 0.23         # nogawki powłoki kończą się równym cięciem nad kostką; niżej są doszyte
ZW = 1.0          # linia pasa spodni


def _leg_axis(B, sd, z):
    """punkt osi nogi (kolano → kostka) na wysokości z"""
    a, k = B.H['Bip01 %s Foot' % sd], B.H['Bip01 %s Calf' % sd]
    return a.lerp(k, (z - a.z) / (k.z - a.z))


def _foot_dir(B, sd):
    a, t = B.H['Bip01 %s Foot' % sd], B.H['Bip01 %s Toe0' % sd]
    return Vector((t.x - a.x, t.y - a.y, 0)).normalized()


def spodnie_garnitur():
    """spodnie od garnituru: gładka wełna z zaprasowanym kantem z przodu i z tyłu, pasek ze sprzączką, kieszenie w szwie"""
    B = Body()
    wool = mat('plotno_garnitur', '3a3f4c', 0.85)
    dark = mat('plotno_garnitur_c', '2f333d', 0.85)
    belt = mat('skora_pasek', '2a211b', 0.6)
    metal = mat('metal_klamra', 'b9bcc2', 0.3, 0.9)
    bm, tree, waist, ankles = _legs(B, lambda co, w: 0.0075, 1, (0.072, 0.088), 0.82)
    ob = to_object(B, bm, 'spodnie_garnitur', [wool, dark, belt, metal])
    parts = []
    for lp in waist:
        parts.append(band(lp, 0.009, belt, 'pasek', 0.002, 2.4, Z * -0.012, wide=0.6))
    for lp in ankles:
        parts.append(band(lp, 0.004, wool, 'nogawka', 0.0008, 1.4))
    wz = max((sum(lp, Vector()) / len(lp)).z for lp in waist) - 0.014 if waist else 0.98
    loc, _ = on_surface(tree, Vector((0.0, -0.3, wz)), FRONT, 0.006)
    parts.append(rbox('sprzaczka', (0.04, 0.005, 0.03), metal, 0.002, tuple(loc)))
    parts.append(ribbon(tree, Vector((0.012, -0.3, wz - 0.03)), Vector((0.012, -0.3, wz - 0.15)), FRONT, 0.026, wool, 6, 0.004, 'rozporek', 0.001))
    for sx in (-1, 1):
        parts.append(stitch(tree, Vector((sx * 0.095, -0.3, wz - 0.14)), Vector((sx * 0.095, -0.3, 0.14)), FRONT, dark, 24, 0.0018, 0.0026, 'kant'))
        parts.append(stitch(tree, Vector((sx * 0.1, 0.3, wz - 0.2)), Vector((sx * 0.1, 0.3, 0.14)), BACK, dark, 22, 0.0018, 0.0026, 'kant_tyl'))
        pts = [on_surface(tree, Vector((sx * (0.13 + 0.05 * (k / 6)), -0.3, wz - 0.03 - 0.13 * (k / 6))), FRONT, 0.002)[0] for k in range(7)]
        parts.append(sweep('wlot', pts, 0.0013, dark, 4))
    finish(B, ob, parts, 'spodnie_garnitur')


def _legs(B, off, smooth, hem=(0.084, 0.096), taper=0.9, cuff=None):
    """Nogawki. hem = wysokość brzegu (z tyłu, z przodu — z przodu nogawka opiera się na podbiciu buta), taper zwęża
    nogawkę prostą, cuff=(promień w bok, promień wzdłuż stopy) ściąga ją ściągaczem przy kostce (dres)."""
    def pick(co, w):
        return (legs_w(w) >= 0.3 or foot_w(w) > 0.0) and co.z > 0.11 and top_w(w) < 0.72 and hand_w(w) < 0.3
    def off2(co, w):
        # w pasie spodnie przylegają, żeby schować się pod bluzą czy koszulą
        return min(off(co, w), 0.009) if co.z > 0.88 else off(co, w)
    def post(bm):
        cut(bm, Vector((0, 0, ZL)), -Z, lambda c: c.z < 0.42)
        # równa linia pasa (na wysokości bioder); wyżej spodnie i tak chowają się pod górą
        cut(bm, Vector((0, 0, ZW)), Z, lambda c: c.z > 0.9)
        for sd in ('L', 'R'):
            sx = 1 if sd == 'L' else -1
            on_leg = lambda m, sx=sx: abs(m.z - ZL) < 0.002 and m.x * sx > 0
            vs = [v.co for v in bm.verts if v.is_boundary and on_leg(v.co)]
            if not vs:
                continue
            c = sum(vs, Vector()) / len(vs)
            f = _foot_dir(B, sd)
            side = Vector((-f.y, f.x, 0))

            def goal(co, c=c, f=f, side=side, sd=sd):
                e = Vector((co.x - c.x, co.y - c.y, 0))
                r0 = e.length
                e.normalize()
                z = hem[0] + (hem[1] - hem[0]) * (0.5 + 0.5 * e.dot(f)) ** 1.5
                ax = _leg_axis(B, sd, z)
                if cuff is not None:
                    return Vector((ax.x, ax.y, z)) + side * (e.dot(side) * cuff[0]) + f * (e.dot(f) * cuff[1])
                cc = c.lerp(ax, 0.6)
                return Vector((cc.x + e.x * r0 * taper, cc.y + e.y * r0 * taper, z))
            lengthen(bm, on_leg, goal, 4, 1.7 if cuff is not None else 1.0)
    bm, lps = shell(B, pick, off2, smooth, wrinkle=1.0, post=post)
    waist = pick_loops(lps, lambda c: c.z > 0.8)
    ankles = pick_loops(lps, lambda c: c.z < 0.3)
    print('   spodnie: pas %d, nogawki %d' % (len(waist), len(ankles)))
    return bm, BVHTree.FromBMesh(bm), waist, ankles


def _ankle(B, co, t0=0.86):
    return co.z < 0.3 and along(B, co, 'Calf', 'Foot') > t0


def _belt_loops(tree, z, material, parts, n=5):
    for k in range(n):
        a = math.radians((-140, -45, 45, 140, 180)[k % 5])
        d = Vector((math.sin(a), -math.cos(a), 0))
        p = Vector((0, 0, z)) + d * 0.3
        t = d.cross(Z).normalized()
        parts.append(patch(tree, p, t, Z, 0.016, 0.055, 0.007, material, 'szlufka', 1, 3, 0.0, -d))


def dresy():
    """spodnie dresowe: miękka dzianina, szeroka guma w pasie ze sznurkiem, podwójny lampas, ściągacze przy kostkach"""
    B = Body()
    knit = mat('dzianina_dresy', '4a4e58', 0.95)
    rib = mat('sciagacz_dresy', '3c4049', 0.95)
    white = mat('dzianina_lampas', 'e4e2dc', 0.9)
    cord = mat('plotno_sznurek', 'd8d6cf', 0.9)

    def off(co, w):
        if _ankle(B, co):
            return 0.007
        return 0.019 if part(w, ('Thigh',)) > 0.5 else 0.015
    bm, tree, waist, ankles = _legs(B, off, 3, (0.118, 0.118), cuff=(0.046, 0.054))
    ob = to_object(B, bm, 'dresy', [knit, rib, white, cord])
    paint(ob, lambda c, n: _ankle(B, c, 0.88), 1)
    parts = []
    for lp in waist:
        parts.append(band(lp, 0.008, rib, 'guma', 0.001, 2.8, Z * -0.012))
    for lp in ankles:
        parts.append(band(lp, 0.0055, rib, 'kostka', 0.0015, 2.6, Z * 0.012))
    for sx in (-1, 1):
        side = Vector((-sx, 0, 0))
        for dy in (-0.012, 0.012):
            parts.append(ribbon(tree, Vector((sx * 0.4, dy, 0.93)), Vector((sx * 0.4, dy - 0.012, 0.16)), side, 0.012, white, 22, 0.0025, 'lampas'))
        a = Vector((sx * 0.018, -0.3, 0.97))
        b = Vector((sx * 0.04, -0.3, 0.86))
        parts.append(stitch(tree, a, b, FRONT, cord, 6, 0.003, 0.004, 'sznurek'))
    finish(B, ob, parts, 'dresy')


def jeansy():
    """jeansy: sztywny dżins, pasek ze szlufkami i guzikiem, rozporek, tylne kieszenie z przeszyciem, żółte szwy boczne, podwinięte nogawki"""
    B = Body()
    denim = mat('dzins_jeansy', '34486a', 0.85)
    light = mat('dzins_podwiniecie', '6f84a3', 0.85)
    thread = mat('plotno_nic', 'c99a3e', 0.8)
    metal = mat('metal_guzik', 'b08a4a', 0.35, 0.9)

    def off(co, w):
        return 0.008
    bm, tree, waist, ankles = _legs(B, off, 1, (0.082, 0.096), 0.84)
    ob = to_object(B, bm, 'jeansy', [denim, light, thread, metal])
    parts = []
    for lp in waist:
        parts.append(band(lp, 0.011, denim, 'pasek', 0.002, 2.6, Z * -0.014, wide=0.7))
    for lp in ankles:
        parts.append(band(lp, 0.008, light, 'podwiniecie', 0.004, 3.0, Z * 0.02, wide=0.6))
    wz = max((sum(lp, Vector()) / len(lp)).z for lp in waist) - 0.016 if waist else 0.98
    _belt_loops(tree, wz, denim, parts)
    parts.append(button(tree, Vector((0.0, -0.3, wz)), FRONT, metal, 0.008, 0.008))
    parts.append(ribbon(tree, Vector((0.014, -0.3, wz - 0.03)), Vector((0.014, -0.3, wz - 0.15)), FRONT, 0.03, denim, 6, 0.004, 'rozporek', 0.001))
    parts.append(stitch(tree, Vector((0.03, -0.3, wz - 0.03)), Vector((0.022, -0.3, wz - 0.15)), FRONT, thread, 6, 0.0012, 0.0045, 'szew'))
    for sx in (-1, 1):
        side = Vector((-sx, 0, 0))
        parts.append(stitch(tree, Vector((sx * 0.4, 0.0, wz - 0.03)), Vector((sx * 0.4, -0.01, 0.14)), side, thread, 24, 0.0012, 0.0015, 'szew_boczny'))
        # wloty przednich kieszeni: łuk z podwójnym przeszyciem
        for d in (0.0, 0.006):
            pts = [on_surface(tree, Vector((sx * (0.06 + 0.11 * (k / 6) ** 0.7), -0.3, wz - 0.035 - d - 0.07 * (k / 6) ** 2)), FRONT, 0.0018)[0] for k in range(7)]
            parts.append(sweep('wlot', pts, 0.0012, thread, 4))
        c = Vector((sx * 0.088, 0.3, wz - 0.13))
        parts.append(patch(tree, c, X, Z, 0.125, 0.135, 0.004, denim, 'kieszen_tyl', 6, 6, 0.35, BACK))
        for k in range(2):
            pts = [on_surface(tree, c + X * (u * 0.05) + Z * (0.02 - k * 0.03 - 0.03 * abs(u)), BACK, 0.0055)[0] for u in (-1, -0.5, 0, 0.5, 1)]
            parts.append(sweep('przeszycie', pts, 0.0011, thread, 4))
    finish(B, ob, parts, 'jeansy')


def bojowki():
    """bojówki: luźne płótno, kieszenie cargo z patkami na udach, wzmocnione kolana, pasek ze szlufkami, ściągacz sznurkiem przy kostkach"""
    B = Body()
    cloth = mat('plotno_bojowki', '6a6a4c', 0.92)
    dark = mat('plotno_bojowki_c', '58583e', 0.92)
    metal = mat('metal_napa', '5a5d52', 0.4, 0.8)

    def off(co, w):
        if _ankle(B, co, 0.9):
            return 0.009
        return 0.02 if part(w, ('Thigh',)) > 0.5 else 0.017
    bm, tree, waist, ankles = _legs(B, off, 2, (0.084, 0.098), 0.95)
    ob = to_object(B, bm, 'bojowki', [cloth, dark, metal])
    parts = []
    for lp in waist:
        parts.append(band(lp, 0.011, dark, 'pasek', 0.002, 2.6, Z * -0.014, wide=0.7))
    for lp in ankles:
        parts.append(band(lp, 0.007, dark, 'sciagacz', 0.005, 1.6, Z * 0.012))
    wz = max((sum(lp, Vector()) / len(lp)).z for lp in waist) - 0.016 if waist else 0.98
    _belt_loops(tree, wz, dark, parts)
    parts.append(button(tree, Vector((0.0, -0.3, wz)), FRONT, metal, 0.007, 0.008))
    for sx in (-1, 1):
        side = Vector((-sx, 0, 0))
        c = Vector((sx * 0.4, -0.005, 0.63))
        parts.append(patch(tree, c, Y, Z, 0.15, 0.18, 0.016, cloth, 'cargo', 7, 7, 0.25, side))
        parts.append(patch(tree, c + Z * 0.075, Y, Z, 0.16, 0.055, 0.023, dark, 'patka', 7, 3, 0.4, side))
        parts.append(button(tree, c + Z * 0.062 + Y * -0.04, side, metal, 0.006, 0.0245))
        parts.append(button(tree, c + Z * 0.062 + Y * 0.04, side, metal, 0.006, 0.0245))
        # zaszewka pośrodku kieszeni
        parts.append(stitch(tree, c + Z * 0.04, c + Z * -0.085, side, dark, 6, 0.0035, 0.0165, 'zaszewka'))
        kz = B.H['Bip01 %s Calf' % ('L' if sx > 0 else 'R')]
        parts.append(patch(tree, Vector((kz.x, -0.3, kz.z + 0.01)), X, Z, 0.11, 0.15, 0.004, dark, 'kolano', 6, 7, 0.3, FRONT))
        parts.append(patch(tree, Vector((sx * 0.088, 0.3, wz - 0.1)), X, Z, 0.125, 0.045, 0.01, dark, 'patka_tyl', 6, 3, 0.4, BACK))
    finish(B, ob, parts, 'bojowki')


# ================================================================ DŁONIE
def _hands(B, off, t0=0.86):
    def pick(co, w):
        if hand_w(w) >= 0.4:
            return True
        return part(w, ('Forearm',)) > 0.3 and abs(co.x) > 0.3 and along(B, co, 'Forearm', 'Hand') > t0
    bm, lps = shell(B, pick, off, 0, 1, rim=0.003)
    return bm, BVHTree.FromBMesh(bm), pick_loops(lps, lambda c: True)


def rekawiczki():
    """rękawice robocze: zamsz z dzianinowym ściągaczem i wzmocnieniem na grzbiecie dłoni"""
    B = Body()
    suede = mat('skora_rekawiczki', 'b0915a', 0.95)
    rib = mat('sciagacz_rekawiczki', '9c8d58', 0.95)
    bm, tree, wrists = _hands(B, lambda co, w: 0.0045, 0.95)
    ob = to_object(B, bm, 'rekawiczki', [suede, rib])
    paint(ob, lambda c, n: along(B, c, 'Forearm', 'Hand') < 1.03, 1)
    parts = []
    for lp in wrists:
        c = sum(lp, Vector()) / len(lp)
        parts.append(band(lp, 0.004, rib, 'sciagacz', 0.0005, 1.8))
    finish(B, ob, parts, 'rekawiczki')


def rekawiczki_skora():
    """skórzane rękawiczki: cienka czarna skóra, pasek z klamerką na nadgarstku"""
    B = Body()
    lea = mat('skora_czarna', '1e1611', 0.55)
    metal = mat('metal_klamra', 'b9bcc2', 0.3, 0.9)
    bm, tree, wrists = _hands(B, lambda co, w: 0.003, 0.93)
    ob = to_object(B, bm, 'rekawiczki_skora', [lea, metal])
    parts = []
    for lp in wrists:
        c = sum(lp, Vector()) / len(lp)
        d = _arm_dir(B, c)
        parts.append(band(lp, 0.005, lea, 'lamowka', 0.001, 1.4))
        parts.append(band(lp, 0.005, lea, 'pasek', 0.002, 1.8, d * 0.03))
        loc, nrm, _, _ = tree.find_nearest(c + d * 0.03 + Vector((0, -0.05, 0)))
        bk = rbox('klamra', (0.016, 0.012, 0.004), metal, 0.001, tuple(loc + nrm * 0.006))
        bk.rotation_euler = nrm.to_track_quat('Z', 'Y').to_euler()
        parts.append(bk)
    finish(B, ob, parts, 'rekawiczki_skora')


# ================================================================ BUTY
# Ciało ma buty schowane pod workowatymi nogawkami (z przodu wystaje sam nosek, pięty nie ma wcale), więc formy buta
# nie da się z niego zdjąć. But powstaje od zera na kopycie: przekroje w poprzek stopy od pięty do noska.
RINGS = (0.012, 0.035, 0.07, 0.11, 0.16, 0.22, 0.29, 0.36, 0.43, 0.5, 0.57, 0.64, 0.71, 0.78, 0.84, 0.89, 0.93, 0.96, 0.98, 0.992)
WIDTH = [(0, 0.0), (0.03, 0.024), (0.08, 0.035), (0.16, 0.040), (0.3, 0.042), (0.45, 0.042), (0.6, 0.047), (0.72, 0.05), (0.84, 0.047), (0.92, 0.038), (0.97, 0.023), (1.0, 0.0)]


def _shoe_ring(hw, zb, zs, top, box, flare):
    """przekrój buta: spód, ścianka podeszwy, cholewka (box < 1 = pudełkowata, ze stojącymi bokami)"""
    pts = [(-hw * 0.9, zb), (-hw * 0.45, zb), (0.0, zb), (hw * 0.45, zb), (hw * 0.9, zb)]
    pts += [(hw, zb + (zs - zb) * 0.25), (hw, zb + (zs - zb) * 0.7), (hw - flare * 0.4, zs)]
    hu = hw - flare
    for k in range(9):
        a = math.radians(6 + k * 21)
        c, sn = math.cos(a), math.sin(a)
        pts.append((hu * (abs(c) ** box) * (1 if c >= 0 else -1), zs + 0.002 + (top - zs - 0.002) * sn ** box))
    pts += [(-hw + flare * 0.4, zs), (-hw, zb + (zs - zb) * 0.7), (-hw, zb + (zs - zb) * 0.25)]
    return pts


class Shoes:
    """para butów na kopycie `last`: len/heel = długość i odległość pięty od kostki, top/sole = profil wierzchu i podeszwy,
    spring = uniesienie noska, arch = podcięcie podeszwy przed obcasem, wide = poszerzenie, flare = wysunięcie podeszwy"""

    def __init__(self, B, last):
        self.B, self.last = B, last
        self.L = last['len']
        self.fr = {}
        bm = bmesh.new()
        for sd in ('L', 'R'):
            ank = B.H['Bip01 %s Foot' % sd]
            f = _foot_dir(B, sd)
            side = Vector((-f.y, f.x, 0))
            O = Vector((ank.x, ank.y, 0)) - f * last['heel']
            self.fr[sd] = (O, f, side)
            rings = []
            for t in RINGS:
                box = 0.45 + 0.35 * max(0.0, min(1.0, (t - 0.45) / 0.3))
                rings.append([bm.verts.new(O + f * (self.L * t) + side * x + Z * z)
                              for x, z in _shoe_ring(self.hw(t), self.zb(t), self.zs(t), self.top(t), box, last.get('flare', 0.0035))])
            n = len(rings[0])
            for i in range(len(rings) - 1):
                for k in range(n):
                    bm.faces.new((rings[i][k], rings[i][(k + 1) % n], rings[i + 1][(k + 1) % n], rings[i + 1][k]))
            bm.faces.new(rings[0])
            bm.faces.new(rings[-1])
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
        self.bm = bm
        self.tree = BVHTree.FromBMesh(bm)

    def hw(self, t):
        return _curve(WIDTH, t) + self.last.get('wide', 0.0) * math.sin(min(1.0, max(0.0, t)) * math.pi) ** 0.5

    def zb(self, t):
        z = self.last.get('spring', 0.0) * max(0.0, (t - 0.72) / 0.28) ** 2
        ar = self.last.get('arch', 0.0)
        if ar > 0.0:
            u = max(0.0, min(1.0, (t - 0.3) / 0.05)) * max(0.0, min(1.0, (0.62 - t) / 0.14))
            z += ar * u * u * (3 - 2 * u)
        return z

    def zs(self, t):
        return self.zb(t) + _curve(self.last['sole'], t)

    def top(self, t):
        return self.zb(t) * 0.5 + _curve(self.last['top'], t)

    def at(self, c):
        """strona, położenie wzdłuż buta (0 pięta … 1 nosek) i w bok dla punktu c"""
        sd = 'L' if c.x > 0 else 'R'
        O, f, side = self.fr[sd]
        d = c - O
        return sd, d.dot(f) / self.L, d.dot(side)

    def point(self, sd, t, x, z):
        O, f, side = self.fr[sd]
        return O + f * (self.L * t) + side * x + Z * z

    def drop(self, sd, t, x, lift=0.002):
        """punkt na wierzchu cholewki pod (t, x)"""
        p = self.point(sd, t, x, 0.6)
        loc, nrm, _, _ = self.tree.ray_cast(p, DOWN, 1.0)
        if loc is None:
            return self.point(sd, t, x, self.top(t) + lift)
        return loc + nrm * lift

    def wall(self, sd, t, z, out, lift=0.002):
        """punkt na bocznej ściance buta: out = +1 po stronie `side`, −1 po przeciwnej"""
        O, f, side = self.fr[sd]
        p = self.point(sd, t, 0.2 * out, z)
        loc, nrm, _, _ = self.tree.ray_cast(p, -side * out, 0.4)
        if loc is None:
            return self.point(sd, t, self.hw(t) * out, z)
        return loc + nrm * lift

    def seam(self, parts, material, radius, level=1.0, name='rant', out=0.0005):
        """wałek dookoła buta na ściance podeszwy: level = 1 na styku z cholewką, niżej = pasek na gumie"""
        for sd in ('L', 'R'):
            pts = []
            for o in (1, -1):
                for t in (RINGS if o > 0 else RINGS[::-1]):
                    z = self.zb(t) + (self.zs(t) - self.zb(t)) * level
                    w = self.hw(t) - (self.last.get('flare', 0.0035) * 0.4 if level > 0.9 else 0.0)
                    pts.append(self.point(sd, t, (w + out) * o, z))
            parts.append(sweep(name, pts, radius, material, 5, True))

    def collar(self, parts, material, radius=0.006, rx=0.035, ry=0.05, name='kolnierz', lift=0.002):
        """wyściełany brzeg wokół kostki: leży na cholewce, po bokach niżej niż z przodu i na pięcie"""
        for sd in ('L', 'R'):
            O, f, side = self.fr[sd]
            ank = self.B.H['Bip01 %s Foot' % sd]
            c = Vector((ank.x, ank.y, 0)) + f * 0.004
            pts = []
            for k in range(28):
                a = k / 28 * math.tau
                p = c + side * (math.cos(a) * rx) + f * (math.sin(a) * ry)
                loc, _, _, _ = self.tree.ray_cast(Vector((p.x, p.y, 0.6)), DOWN, 1.0)
                pts.append(Vector((p.x, p.y, (loc.z if loc is not None else 0.09) + lift)))
            parts.append(sweep(name, pts, radius, material, 6, True, 1.25))

    def tongue(self, parts, material, t0=0.56, t1=0.425, z1=0.12, width=0.044, thick=0.004):
        """język wystający spod sznurowania w stronę goleni"""
        for sd in ('L', 'R'):
            vb = bmesh.new()
            rows = []
            for j in range(6):
                v = j / 5
                t = t0 + (t1 - t0) * v
                z = (self.top(t0) + 0.0015) * (1 - v) + z1 * v + 0.005 * math.sin(v * math.pi)
                rows.append([vb.verts.new(self.point(sd, t, u * width / 2, z - 0.009 * u * u)) for u in (-1, -0.6, -0.2, 0.2, 0.6, 1)])
            for j in range(5):
                for i in range(5):
                    vb.faces.new((rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]))
            bmesh.ops.recalc_face_normals(vb, faces=vb.faces[:])
            bmesh.ops.solidify(vb, geom=vb.faces[:], thickness=thick)
            parts.append(mesh_object(vb, 'jezyk', material))

    def laces(self, parts, material, rows=5, t0=0.5, t1=0.68, lift=0.003, eyelet=None, radius=0.0021):
        """sznurowanie na podbiciu: poprzeczki, krzyże między nimi, oczka i kokardka"""
        for sd in ('L', 'R'):
            prev = None
            for k in range(rows):
                t = t0 + (t1 - t0) * k / max(1, rows - 1)
                w = 0.014 + 0.007 * k / max(1, rows - 1)
                row = [self.drop(sd, t, w * u, lift) for u in (-1, -0.5, 0, 0.5, 1)]
                parts.append(sweep('sznurowka', row, radius, material, 5))
                if prev is not None:
                    for i0, i1 in ((0, 4), (4, 0)):
                        a, b = prev[i0], row[i1]
                        mid = (a + b) / 2 + Z * 0.0025
                        parts.append(sweep('krzyz', [a + Z * 0.001, mid, b + Z * 0.001], radius * 0.85, material, 4))
                if eyelet is not None:
                    for q in (row[0], row[-1]):
                        e = lathe('oczko', [(0.0, 0.0), (0.0042, 0.0), (0.0042, 0.0012), (0.0, 0.0012)], eyelet, 8, loc=tuple(q - Z * 0.001))
                        parts.append(e)
                prev = row
            # kokardka u góry sznurowania
            c = self.drop(sd, t0 - 0.025, 0.0, lift + 0.002)
            O, f, side = self.fr[sd]
            for o in (-1, 1):
                loop = [c, c + side * (0.016 * o) + Z * 0.004 - f * 0.004, c + side * (0.022 * o) - f * 0.012 - Z * 0.002, c + side * (0.008 * o) - f * 0.006]
                parts.append(sweep('kokardka', loop, radius, material, 4, True))
                parts.append(sweep('koniec', [c, c + side * (0.012 * o) + f * 0.012 - Z * 0.004, c + side * (0.02 * o) + f * 0.024 - Z * 0.012], radius, material, 4))

    def stripe(self, parts, material, sd, out, t_a, z_a, t_b, z_b, width=0.008, name='pasek'):
        """pasek na boku cholewki od (t_a, z_a) do (t_b, z_b)"""
        O, f, side = self.fr[sd]
        vb = bmesh.new()
        rows = []
        for k in range(6):
            q = k / 5
            t, z = t_a + (t_b - t_a) * q, z_a + (z_b - z_a) * q
            p = self.wall(sd, t, z, out, 0.0018)
            dt = width / 2 / self.L
            rows.append((vb.verts.new(self.wall(sd, t - dt, z, out, 0.0018)), vb.verts.new(p), vb.verts.new(self.wall(sd, t + dt, z, out, 0.0018))))
        for k in range(5):
            for i in range(2):
                vb.faces.new((rows[k][i], rows[k][i + 1], rows[k + 1][i + 1], rows[k + 1][i]))
        bmesh.ops.recalc_face_normals(vb, faces=vb.faces[:])
        if sum(fc.normal.dot(side * out) for fc in vb.faces) < 0:
            bmesh.ops.reverse_faces(vb, faces=vb.faces[:])
        parts.append(mesh_object(vb, name, material))


def _leg_tube(B, name, material, lo, hi, r_lo, r_hi, lean=0.25, open_top=False, segs=18):
    """rura wokół osi nogi (skarpetka, cholewa): ciało ma tam szeroką nogawkę, więc formy nie da się z niego zdjąć.
    r_lo/r_hi = (promień w bok, promień wzdłuż stopy) u dołu i u góry"""
    bm = bmesh.new()
    tops = []
    for sd in ('L', 'R'):
        f = _foot_dir(B, sd)
        side = Vector((-f.y, f.x, 0))
        ank = B.H['Bip01 %s Foot' % sd]
        n = max(3, int((hi - lo) / 0.025) + 1)
        rings = []
        for i in range(n + 1):
            z = lo + (hi - lo) * i / n
            c = _leg_axis(B, sd, z) if z >= ank.z else Vector((ank.x, ank.y, z)) + f * (lean * (ank.z - z))
            k = i / n
            rx, ry = r_lo[0] + (r_hi[0] - r_lo[0]) * k, r_lo[1] + (r_hi[1] - r_lo[1]) * k
            rings.append([bm.verts.new(Vector((c.x, c.y, z)) + side * (math.cos(j / segs * math.tau) * rx) + f * (math.sin(j / segs * math.tau) * ry - 0.003))
                          for j in range(segs)])
        for i in range(n):
            for j in range(segs):
                bm.faces.new((rings[i][j], rings[i][(j + 1) % segs], rings[i + 1][(j + 1) % segs], rings[i + 1][j]))
        if not open_top:
            bm.faces.new(rings[-1])
        tops.append([v.co.copy() for v in rings[-1]])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    tree = BVHTree.FromBMesh(bm)
    return mesh_object(bm, name, material), tree, tops


def _sock(B, material, hi=0.27):
    """skarpetka: od wnętrza buta do łydki (pod nogawką), ze ściągaczem u góry"""
    ob, _, tops = _leg_tube(B, 'skarpetka', material, 0.055, hi, (0.033, 0.041), (0.042, 0.049))
    return [ob] + [band(lp, 0.0028, material, 'sciagacz_skarpety', 0.0005, 2.2, Z * -0.006) for lp in tops]


def _foot_weigh(sh):
    """wagi buta i skarpety liczone z położenia: stopa, palce od zgięcia w przód, nad kostką łydka (cholewa zgina się w kostce)"""
    def fn(co):
        sd, t, x = sh.at(co)
        c = max(0.0, min(1.0, (co.z - 0.105) / 0.055))
        c = c * c * (3 - 2 * c)
        tt = max(0.0, min(1.0, (t - 0.7) / 0.12)) if co.z < 0.09 else 0.0
        tt = tt * tt * (3 - 2 * tt)
        return {'Bip01 %s Calf' % sd: c, 'Bip01 %s Foot' % sd: (1 - c) * (1 - tt), 'Bip01 %s Toe0' % sd: (1 - c) * tt}
    return fn


def trampki():
    """trampki: czarne płótno, biała gumowa podeszwa z czerwonym paskiem, biały nosek, białe sznurowadła w metalowych oczkach, skarpetka"""
    B = Body()
    canvas = mat('plotno_trampki', '26282e', 0.9)
    rubber = mat('guma_trampki', 'e8e6df', 0.6)
    lace = mat('plotno_sznurowka', 'f0eee8', 0.9)
    stripe = mat('guma_pasek', 'b0382c', 0.6)
    sock = mat('dzianina_skarpeta', 'b4b3ad', 0.95)
    sh = Shoes(B, dict(len=0.292, heel=0.083, spring=0.006, flare=0.002, sole=[(0, 0.024), (1, 0.024)],
                       top=[(0, 0.07), (0.05, 0.088), (0.12, 0.096), (0.3, 0.097), (0.42, 0.092), (0.5, 0.08), (0.6, 0.067), (0.72, 0.057),
                            (0.85, 0.051), (0.94, 0.045), (0.985, 0.035), (1, 0.028)]))
    ob = to_object(B, sh.bm, 'trampki', [canvas, rubber, lace, stripe, sock])

    def rubber_part(c, n):
        sd, t, x = sh.at(c)
        return c.z < sh.zs(t) + 0.0015 or t > 0.855
    paint(ob, rubber_part, 1)
    parts = _sock(B, sock)
    sh.collar(parts, canvas, 0.0038, 0.035, 0.05, 'lamowka')
    sh.tongue(parts, canvas, 0.56, 0.43, 0.116, 0.042, 0.003)
    sh.seam(parts, rubber, 0.003, 1.0, 'otok')
    sh.seam(parts, stripe, 0.0015, 0.62, 'pasek', 0.0012)
    sh.laces(parts, lace, 6, 0.48, 0.7, eyelet=mat('metal_oczko', 'b9bcc2', 0.3, 0.9))
    for sd in ('L', 'R'):
        # łatka na pięcie i szew noska
        back = sh.point(sd, 0.0, 0.0, 0.05)
        parts.append(patch(sh.tree, back, sh.fr[sd][2], Z, 0.022, 0.03, 0.002, rubber, 'latka', 3, 3, 0.3, sh.fr[sd][1], 0.3))
        pts = [sh.drop(sd, 0.845 + 0.03 * (1 - u * u), 0.046 * u, 0.0018) for u in (-1, -0.75, -0.5, -0.25, 0, 0.25, 0.5, 0.75, 1)]
        parts.append(sweep('szew_noska', pts, 0.0016, rubber, 4))
    finish(B, ob, parts, 'trampki', weigh=_foot_weigh(sh))


def buty_bieg():
    """buty do biegania: siatkowa cholewka, gruba biała pianka, czarny bieżnik, trzy paski po bokach, zapiętek, wyściełany kołnierz"""
    B = Body()
    mesh = mat('plotno_bieg', 'c8482a', 0.85)
    foam = mat('guma_pianka', 'f1efe9', 0.7)
    sole = mat('guma_bieznik', '1c1c1f', 0.8)
    lace = mat('plotno_sznurowka', 'f0eee8', 0.9)
    grey = mat('skora_zapietek', '55585f', 0.7)
    sock = mat('dzianina_skarpeta', 'b4b3ad', 0.95)
    sh = Shoes(B, dict(len=0.3, heel=0.086, spring=0.014, flare=0.005, wide=0.001,
                       sole=[(0, 0.04), (0.3, 0.036), (0.6, 0.028), (0.85, 0.022), (1, 0.018)],
                       top=[(0, 0.076), (0.05, 0.095), (0.12, 0.104), (0.3, 0.103), (0.42, 0.097), (0.5, 0.085), (0.6, 0.071), (0.72, 0.061),
                            (0.85, 0.053), (0.94, 0.045), (0.985, 0.035), (1, 0.027)]))
    ob = to_object(B, sh.bm, 'buty_bieg', [mesh, foam, sole, lace, grey, sock])

    def kind(c):
        sd, t, x = sh.at(c)
        if c.z < sh.zb(t) + 0.007:
            return 2
        if c.z < sh.zs(t) + 0.0015:
            return 1
        if t < 0.17 and c.z < 0.088:
            return 4                      # zapiętek
        if t > 0.9:
            return 4                      # wzmocniony nosek
        return 0
    for pl in ob.data.polygons:
        pl.material_index = kind(pl.center)
    parts = _sock(B, sock)
    sh.collar(parts, grey, 0.0075, 0.035, 0.05)
    sh.tongue(parts, mesh, 0.57, 0.425, 0.124, 0.046, 0.006)
    sh.seam(parts, foam, 0.0032, 1.0, 'rant')
    sh.seam(parts, sole, 0.002, 0.16, 'bieznik', 0.001)
    sh.laces(parts, lace, 5, 0.5, 0.68)
    for sd in ('L', 'R'):
        for out in (1, -1):
            for k in range(3):
                t = 0.36 + k * 0.058
                sh.stripe(parts, foam, sd, out, t, 0.084 - k * 0.006, t + 0.07, sh.zs(t + 0.07) + 0.004, 0.011)
        # pętelka na pięcie
        O, f, side = sh.fr[sd]
        a = sh.point(sd, 0.004, 0.0, 0.07)
        parts.append(sweep('petelka', [a + Z * 0.004, a - f * 0.003 + Z * 0.02, a + f * 0.004 + Z * 0.03, a + f * 0.011 + Z * 0.026], 0.0022, grey, 4, False, 1.0, 2.4))
    finish(B, ob, parts, 'buty_bieg', weigh=_foot_weigh(sh))


def polbuty():
    """półbuty skórzane: smukłe kopyto, obcas, cienka podeszwa z rantem, szew noska, cienkie sznurowadła w pięciu dziurkach"""
    B = Body()
    lea = mat('skora_polbuty', '3a2619', 0.45)
    dark = mat('skora_polbuty_c', '2a1b12', 0.5)
    sole = mat('guma_podeszwa', '2a2623', 0.8)
    lace = mat('plotno_sznurowka_c', '2a211b', 0.9)
    sock = mat('dzianina_skarpeta_c', '3a3b40', 0.95)
    sh = Shoes(B, dict(len=0.305, heel=0.085, spring=0.007, arch=0.012, flare=0.0025, wide=-0.002,
                       sole=[(0, 0.03), (0.28, 0.03), (0.4, 0.016), (1, 0.014)],
                       top=[(0, 0.07), (0.05, 0.087), (0.12, 0.094), (0.3, 0.094), (0.42, 0.088), (0.5, 0.076), (0.6, 0.063), (0.72, 0.054),
                            (0.85, 0.047), (0.94, 0.04), (0.985, 0.03), (1, 0.022)]))
    ob = to_object(B, sh.bm, 'polbuty', [lea, dark, sole, lace, sock])

    def kind(c):
        sd, t, x = sh.at(c)
        if c.z < sh.zs(t) + 0.0012:
            return 2
        return 1 if t > 0.82 else 0
    for pl in ob.data.polygons:
        pl.material_index = kind(pl.center)
    parts = _sock(B, sock, 0.25)
    sh.collar(parts, dark, 0.0035, 0.034, 0.05, 'lamowka')
    sh.tongue(parts, lea, 0.56, 0.44, 0.106, 0.036, 0.003)
    sh.seam(parts, dark, 0.0022, 1.0, 'rant')
    sh.laces(parts, lace, 5, 0.47, 0.64, 0.0025, None, 0.0015)
    for sd in ('L', 'R'):
        pts = [sh.drop(sd, 0.8 + 0.035 * (1 - u * u), 0.044 * u, 0.0016) for u in (-1, -0.75, -0.5, -0.25, 0, 0.25, 0.5, 0.75, 1)]
        parts.append(sweep('szew_noska', pts, 0.0013, dark, 4))
    finish(B, ob, parts, 'polbuty', weigh=_foot_weigh(sh))


def trampki_wysokie():
    """wysokie trampki: płócienna cholewka za kostkę, biała gumowa podeszwa i nosek, okrągła naszywka na kostce, sznurowanie do góry"""
    B = Body()
    canvas = mat('plotno_trampki_w', '8a2f2a', 0.9)
    rubber = mat('guma_trampki', 'e8e6df', 0.6)
    lace = mat('plotno_sznurowka', 'f0eee8', 0.9)
    stripe = mat('guma_pasek', '26282e', 0.6)
    sock = mat('dzianina_skarpeta', 'b4b3ad', 0.95)
    metal = mat('metal_oczko', 'b9bcc2', 0.3, 0.9)
    sh = Shoes(B, dict(len=0.292, heel=0.083, spring=0.006, flare=0.002, sole=[(0, 0.026), (1, 0.026)],
                       top=[(0, 0.078), (0.05, 0.096), (0.12, 0.104), (0.3, 0.104), (0.42, 0.099), (0.5, 0.088), (0.6, 0.072), (0.72, 0.06),
                            (0.85, 0.052), (0.94, 0.046), (0.985, 0.036), (1, 0.03)]))
    ob = to_object(B, sh.bm, 'trampki_wysokie', [canvas, rubber, lace, stripe, sock, metal])

    def rubber_part(c, n):
        sd, t, x = sh.at(c)
        return c.z < sh.zs(t) + 0.0015 or t > 0.855
    paint(ob, rubber_part, 1)
    shaft, stree, tops = _leg_tube(B, 'cholewka', canvas, 0.07, 0.185, (0.039, 0.049), (0.043, 0.051), 0.25, True)
    parts = [shaft] + _sock(B, sock, 0.25)
    for lp in tops:
        parts.append(band(lp, 0.0045, canvas, 'lamowka', 0.0004, 1.4))
    sh.seam(parts, rubber, 0.003, 1.0, 'otok')
    sh.seam(parts, stripe, 0.0015, 0.62, 'pasek', 0.0012)
    sh.laces(parts, lace, 5, 0.5, 0.7, eyelet=metal)
    for sd in ('L', 'R'):
        O, f, side = sh.fr[sd]
        pts = [sh.drop(sd, 0.845 + 0.03 * (1 - u * u), 0.046 * u, 0.0018) for u in (-1, -0.75, -0.5, -0.25, 0, 0.25, 0.5, 0.75, 1)]
        parts.append(sweep('szew_noska', pts, 0.0016, rubber, 4))
        # sznurowanie po przodzie cholewki i okrągła naszywka po wewnętrznej stronie kostki
        prev = None
        for k in range(4):
            z = 0.112 + k * 0.022
            ax = _leg_axis(B, sd, z)
            row = []
            for u in (-1, -0.5, 0, 0.5, 1):
                p = Vector((ax.x, ax.y, z)) + side * (0.016 * u) + f * 0.2
                loc, nrm, _, _ = stree.ray_cast(p, -f, 0.4)
                row.append((loc + nrm * 0.0035) if loc is not None else p - f * 0.15)
            parts.append(sweep('sznurowka', row, 0.0021, lace, 5))
            if prev is not None:
                parts.append(sweep('krzyz', [prev[0] - f * 0.001, (prev[0] + row[4]) / 2 - f * 0.003, row[4] - f * 0.001], 0.0018, lace, 4))
                parts.append(sweep('krzyz', [prev[4] - f * 0.001, (prev[4] + row[0]) / 2 - f * 0.003, row[0] - f * 0.001], 0.0018, lace, 4))
            prev = row
        inner = side * (-1 if sd == 'L' else 1)
        ax = _leg_axis(B, sd, 0.13)
        loc, nrm, _, _ = stree.ray_cast(Vector((ax.x, ax.y, 0.13)) + inner * 0.2, -inner, 0.4)
        if loc is not None:
            e = lathe('naszywka', [(0.0, 0.0), (0.02, 0.0), (0.02, 0.002), (0.0, 0.002)], rubber, 14)
            e.rotation_euler = nrm.to_track_quat('Z', 'Y').to_euler()
            e.location = loc + nrm * 0.001
            parts.append(e)
    sh.tongue(parts, canvas, 0.58, 0.46, 0.13, 0.036, 0.003)
    finish(B, ob, parts, 'trampki_wysokie', weigh=_foot_weigh(sh))


def buty_robocze():
    """buty robocze: skóra za kostkę, wzmocniony nosek, gruba podeszwa z obcasem i rantem, sznurowanie z oczkami po cholewie, wyściełany kołnierz, pętelka z tyłu"""
    B = Body()
    lea = mat('skora_buty', '6b4a2b', 0.75)
    dark = mat('skora_buty_c', '4a321c', 0.75)
    sole = mat('guma_protektor', '1c1c1f', 0.85)
    lace = mat('plotno_sznurowka_b', 'c9a24a', 0.9)
    metal = mat('metal_oczko', 'b08a4a', 0.35, 0.9)
    sock = mat('dzianina_skarpeta_c', '3a3b40', 0.95)
    sh = Shoes(B, dict(len=0.302, heel=0.087, spring=0.008, arch=0.009, flare=0.0045, wide=0.003,
                       sole=[(0, 0.038), (0.3, 0.036), (0.45, 0.03), (1, 0.028)],
                       top=[(0, 0.082), (0.05, 0.1), (0.12, 0.109), (0.3, 0.109), (0.42, 0.105), (0.5, 0.096), (0.6, 0.083), (0.72, 0.073),
                            (0.85, 0.068), (0.94, 0.061), (0.985, 0.047), (1, 0.035)]))
    ob = to_object(B, sh.bm, 'buty_robocze', [lea, dark, sole, lace, metal, sock])

    def kind(c):
        sd, t, x = sh.at(c)
        if c.z < sh.zs(t) + 0.0015:
            return 2
        if t > 0.8 or (t < 0.16 and c.z < 0.095):
            return 1
        return 0
    for pl in ob.data.polygons:
        pl.material_index = kind(pl.center)
    # cholewa za kostkę i ciemna skarpeta w środku
    shaft, stree, tops = _leg_tube(B, 'cholewa', lea, 0.07, 0.205, (0.04, 0.05), (0.046, 0.054), 0.25, True)
    parts = [shaft] + _sock(B, sock, 0.25)
    for lp in tops:
        parts.append(band(lp, 0.0065, dark, 'kolnierz', 0.0005, 1.5))
    sh.seam(parts, dark, 0.0042, 1.0, 'rant')
    sh.laces(parts, lace, 4, 0.52, 0.68, 0.004, metal, 0.0024)
    for sd in ('L', 'R'):
        O, f, side = sh.fr[sd]
        # sznurowanie po przodzie cholewy
        prev = None
        for k in range(5):
            z = 0.112 + k * 0.021
            ax = _leg_axis(B, sd, z)
            row = []
            for u in (-1, -0.5, 0, 0.5, 1):
                p = Vector((ax.x, ax.y, z)) + side * (0.017 * u) + f * 0.2
                loc, nrm, _, _ = stree.ray_cast(p, -f, 0.4)
                row.append((loc + nrm * 0.004) if loc is not None else p - f * 0.15)
            parts.append(sweep('sznurowka', row, 0.0024, lace, 5))
            for q in (row[0], row[-1]):
                e = lathe('oczko', [(0.0, 0.0), (0.0045, 0.0), (0.0045, 0.0012), (0.0, 0.0012)], metal, 8)
                e.rotation_euler = (-f).to_track_quat('-Z', 'Y').to_euler()
                e.location = q - f * 0.0005
                parts.append(e)
            if prev is not None:
                parts.append(sweep('krzyz', [prev[0] - f * 0.001, (prev[0] + row[4]) / 2 - f * 0.003, row[4] - f * 0.001], 0.002, lace, 4))
                parts.append(sweep('krzyz', [prev[4] - f * 0.001, (prev[4] + row[0]) / 2 - f * 0.003, row[0] - f * 0.001], 0.002, lace, 4))
            prev = row
        # język pod sznurowaniem i pętelka z tyłu cholewy
        ax = _leg_axis(B, sd, 0.2)
        back = Vector((ax.x, ax.y, 0.2)) - f * 0.056
        parts.append(sweep('petelka', [back - Z * 0.02, back + Z * 0.012 - f * 0.006, back + Z * 0.03, back + Z * 0.012 + f * 0.004], 0.003, dark, 4, False, 1.0, 2.6))
    sh.tongue(parts, dark, 0.6, 0.47, 0.132, 0.038, 0.004)
    finish(B, ob, parts, 'buty_robocze', weigh=_foot_weigh(sh))


# ================================================================ SZYJA I GŁOWA
def envelope(B, b, verts, gap, rounds=3, steps=4):
    """Gładka otoczka zamiast odlewu: na zmianę wygładza i odsuwa od ciała to, co weszło pod powierzchnię. Wklęsłości
    (między uchem a czaszką, pod kosmykiem grzywki) zostają zamostkowane, wypukłości dalej przylegają."""
    for _ in range(rounds):
        for _ in range(steps):
            bmesh.ops.smooth_vert(b, verts=verts, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
        clear(B, b, gap)
    bmesh.ops.smooth_vert(b, verts=verts, factor=0.3, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    clear(B, b, gap * 0.8)


def ring_band(tree, axis, z_of, profile, material, name='wywiniecie', n=64):
    """Pas dookoła głowy położony na powłoce `tree`: profile = [(wysokość nad brzegiem, odsunięcie)…], z_of(y) = wysokość
    brzegu. Kąt 0 = przód (−Y). Zwraca obiekt o zamkniętym przekroju (wywinięty ściągacz czapki)."""
    vb = bmesh.new()
    rows = []
    for k in range(n):
        th = k / n * math.tau
        d = Vector((math.sin(th), -math.cos(th), 0))
        row = []
        for h, o in profile:
            z = z_of(axis.y + d.y * 0.1) + h
            hit = None
            for _ in range(3):
                loc, nrm, _, _ = tree.ray_cast(Vector((axis.x, axis.y, z)) + d * 0.4, -d, 0.5)
                if loc is None:
                    break
                hit = loc
                z = z_of(loc.y) + h
            if hit is None:
                hit = Vector((axis.x, axis.y, z)) + d * 0.1
            row.append(vb.verts.new(Vector((hit.x, hit.y, z)) + d * o))
        rows.append(row)
    m = len(profile)
    for k in range(n):
        a, b2 = rows[k], rows[(k + 1) % n]
        for j in range(m - 1):
            vb.faces.new((a[j], a[j + 1], b2[j + 1], b2[j]))
    bmesh.ops.recalc_face_normals(vb, faces=vb.faces[:])
    for _ in range(2):
        bmesh.ops.smooth_vert(vb, verts=vb.verts[:], factor=0.4, use_axis_x=True, use_axis_y=True, use_axis_z=False)
    return mesh_object(vb, name, material)


def _calm_face(B, b, ez, hy, gap=0.0115):
    """dzianina na twarzy nie odwzorowuje ust, nozdrzy ani małżowin: otwór po ustach zaszyty, te miejsca dodatkowo wygładzone"""
    # zęby, dziąsła i wewnętrzna strona warg (schowane za wargami) nie należą do powłoki — dawały „szczerzącą się” fakturę
    tr = BVHTree.FromBMesh(b)
    hidden = []
    for v in b.verts:
        if abs(v.co.x) < 0.045 and 1.56 < v.co.z < ez - 0.03 and v.co.y < hy - 0.03:
            loc, _, _, dist = tr.ray_cast(v.co + Vector((0, -0.0015, 0)), Vector((0, -1, 0)), 0.06)
            if loc is not None and dist > 0.0015:
                hidden.append(v)
    if hidden:
        bmesh.ops.delete(b, geom=hidden, context='VERTS')
    for lp_e in _edge_loops(b):
        cz = sum(((e.verts[0].co + e.verts[1].co) / 2 for e in lp_e), Vector()) / len(lp_e)
        if len(lp_e) < 60 and cz.z < ez - 0.03 and cz.z > 1.56 and cz.y < hy - 0.04:
            bmesh.ops.holes_fill(b, edges=lp_e, sides=0)
    # uszy: materiał przykrywa małżowinę gładkim wybrzuszeniem (bez odlewu ucha)
    ears = [v.co for v in b.verts if abs(v.co.x) > 0.085 and 1.6 < v.co.z < 1.74]
    if ears:
        xt = max(abs(c.x) for c in ears)
        cy = sum(c.y for c in ears) / len(ears)
        cz2 = sum(c.z for c in ears) / len(ears)
        for v in b.verts:
            if abs(v.co.x) < 0.06 or v.is_boundary:
                continue
            k = max(0.0, 1.0 - math.hypot((v.co.y - cy) / 0.06, (v.co.z - cz2) / 0.075))
            k = k * k * (3 - 2 * k)
            if k > 0.0:
                sx = 1.0 if v.co.x > 0 else -1.0
                v.co.x = sx * (abs(v.co.x) + (max(abs(v.co.x), xt * (0.93 + 0.07 * k)) - abs(v.co.x)) * min(1.0, k * 2.0))
    soft = [v for v in b.verts if not v.is_boundary and ((v.co.z < ez - 0.025 and v.co.y < hy - 0.02) or abs(v.co.x) > 0.082)]
    envelope(B, b, soft, gap, 5, 6)


def wrap_head(B, z0, off, top_fn=None, dome=False, n=64, rows=18, r_max=0.125, zc=None, straight=False):
    """Dzianina naciągnięta na głowę: siatka z promieni rzucanych z zewnątrz w stronę osi głowy. Promień zatrzymuje się na
    pierwszej (zewnętrznej) powierzchni, więc do powłoki nie trafiają nozdrza, wnętrze ust ani zakamarki uszu — kopia siatki
    twarzy dawała tam „odlew” z nakładającymi się warstwami. z0 = dolny brzeg, top_fn(kierunek) = górny brzeg (komin),
    dome = z czubkiem (kominiarka), off(z) = odsunięcie od skóry."""
    hz, hy = B.H['Bip01 Head'].z, B.H['Bip01 Head'].y
    ax = Vector((0, hy + 0.007, 0))
    zc = hz + 0.125 if zc is None else zc
    C = Vector((ax.x, ax.y, zc))
    z0_fn = z0 if callable(z0) else (lambda d: z0)

    def reach(o, d, lim):
        loc, _, _, _ = B.tree.ray_cast(o + d * 0.5, -d, 0.5)
        r = (loc - o).dot(d) if loc is not None else 0.09
        return max(0.045, min(lim, r))
    vb = bmesh.new()
    cols = []
    for k in range(n):
        th = k / n * math.tau
        d = Vector((math.sin(th), -math.cos(th), 0))
        ztop = top_fn(d) if top_fn is not None else zc
        zb = z0_fn(d)
        ring = []
        for j in range(rows + 1):
            z = zb + (ztop - zb) * j / rows
            o = Vector((ax.x, ax.y, z))
            # przy szyi promień nie może złapać barków ani kołnierza ciała
            lim = r_max if z > hz - 0.02 else 0.085 + (r_max - 0.085) * max(0.0, (z - zb) / max(0.01, hz - 0.02 - zb))
            ring.append([o, d, reach(o, d, lim) + off(z)])
        if dome:
            for j in range(1, 10):
                ph = j / 10 * math.pi / 2
                dd = d * math.cos(ph) + Z * math.sin(ph)
                ring.append([C, dd, reach(C, dd, 0.2) + off(zc)])
        if straight:
            # czapka nie zwęża się ku dołowi: poniżej najszerszego miejsca ścianka idzie prosto do brzegu
            for j in range(rows - 1, -1, -1):
                ring[j][2] = max(ring[j][2], ring[j + 1][2] * (1.0 if j + 1 <= rows else math.cos(math.pi / 20)))
        cols.append([vb.verts.new(o + dd * r) for o, dd, r in ring])
    m = len(cols[0])
    for k in range(n):
        a, b2 = cols[k], cols[(k + 1) % n]
        for j in range(m - 1):
            vb.faces.new((a[j], b2[j], b2[j + 1], a[j + 1]))
    if dome:
        pole = vb.verts.new(C + Z * (reach(C, Z, 0.2) + off(zc)))
        for k in range(n):
            vb.faces.new((cols[k][-1], cols[(k + 1) % n][-1], pole))
    bmesh.ops.recalc_face_normals(vb, faces=vb.faces[:])
    inner = [v for v in vb.verts if not v.is_boundary]
    for _ in range(3):
        bmesh.ops.smooth_vert(vb, verts=inner, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
        clear(B, vb, off(zc) * 0.8)
    bmesh.ops.smooth_vert(vb, verts=inner, factor=0.3, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    vb.normal_update()
    return vb


def komin():
    """komin naciągnięty na nos: elastyczna dzianina z poziomymi fałdami, obszyte brzegi"""
    B = Body()
    knit = mat('dzianina_komin', '3a3f48', 0.95)
    hz, hy = B.H['Bip01 Head'].z, B.H['Bip01 Head'].y

    def top(d):
        # z przodu sięga nasady nosa, z tyłu kończy się na karku
        k = max(0.0, min(1.0, (hy + 0.007 + d.y * 0.1 - (hy - 0.11)) / 0.2))
        return hz + 0.07 - 0.055 * k * k * (3 - 2 * k)
    bm = wrap_head(B, 1.5, lambda z: 0.0125 + 0.0028 * math.sin(z * 190.0), top, rows=16)
    lps = loops(bm, lambda c: True)
    ob = to_object(B, bm, 'komin', [knit])
    parts = [band(lp, 0.005, knit, 'obszycie', 0.001, 1.3) for lp in lps if len(lp) > 12]
    finish(B, ob, parts, 'komin')


def kominiarka():
    """kominiarka: dzianina na całą głowę i szyję z jednym otworem na oczy, obszyty brzeg otworu i dół"""
    B = Body()
    knit = mat('dzianina_kominiarka', '1b1c20', 0.95)
    hz, hy = B.H['Bip01 Head'].z, B.H['Bip01 Head'].y
    eL, eR = B.H['Bip01 LEye'], B.H['Bip01 REye']
    ez = (eL.z + eR.z) / 2
    bm = wrap_head(B, 1.525, lambda z: 0.012, dome=True, rows=20)
    # otwór na oczy: poziomy, zaokrąglony pas z przodu twarzy
    cut_f = []
    for f in bm.faces:
        c = f.calc_center_median()
        if c.y < hy - 0.04 and ((c.x / 0.07) ** 4 + ((c.z - ez - 0.002) / 0.021) ** 4) < 1.0:
            cut_f.append(f)
    bmesh.ops.delete(bm, geom=cut_f, context='FACES')
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context='VERTS')
    eye = [v for v in bm.verts if v.is_boundary and v.co.z > ez - 0.05 and v.co.y < hy]
    for _ in range(3):
        bmesh.ops.smooth_vert(bm, verts=eye, factor=0.5, use_axis_x=True, use_axis_y=False, use_axis_z=True)
    bm.normal_update()
    lps = loops(bm, lambda c: True)
    ob = to_object(B, bm, 'kominiarka', [knit])
    parts = []
    for lp in lps:
        if len(lp) > 10:
            parts.append(band(lp, 0.0045, knit, 'obszycie', 0.0008, 1.2))
    finish(B, ob, parts, 'kominiarka')


def _head_shell(B, rim_front, rim_back, off, smooth=3, rim=None, smooth_gap=0.0, straight=False):
    hz, hy = B.H['Bip01 Head'].z, B.H['Bip01 Head'].y

    def rim_z(y):
        if rim is not None:
            return rim(y)
        return hz + rim_front + (rim_back - rim_front) * max(0.0, min(1.0, (y - (hy - 0.11)) / 0.21))

    def pick(co, w):
        return head_w(w) >= 0.5 and co.z > rim_z(co.y) - 0.03

    def post(bm):
        if smooth_gap > 0.0:
            # gładka główka czapki: bez odlewu fryzury pod spodem
            envelope(B, bm, [v for v in bm.verts if not v.is_boundary], smooth_gap, 3, 4)
        if straight:
            # Czapka nie zwęża się pod główką: poniżej najszerszego miejsca boki idą prosto w dół do otoku
            # (głowa pod spodem jest tam węższa i powłoka robiła „grzybek”).
            ax = Vector((0, hy + 0.005, 0))
            nb = 48
            pol = []
            for v in bm.verts:
                dx, dy = v.co.x - ax.x, v.co.y - ax.y
                pol.append((v, int((math.atan2(dx, -dy) % math.tau) / math.tau * nb) % nb, math.hypot(dx, dy)))
            bins = [[] for _ in range(nb)]
            for v, k, r in pol:
                bins[k].append((v.co.z, r))
            for v, k, r in pol:
                if v.co.z > rim_z(v.co.y) + 0.06:
                    continue
                top = 0.0
                for kk in (k - 1, k, k + 1):
                    for z2, r2 in bins[kk % nb]:
                        if z2 > v.co.z + 0.004 and r2 > top:
                            top = r2
                if top * 0.985 > r and r > 1e-4:
                    f = top * 0.985 / r
                    v.co.x = ax.x + (v.co.x - ax.x) * f
                    v.co.y = ax.y + (v.co.y - ax.y) * f
            bmesh.ops.smooth_vert(bm, verts=[v for v in bm.verts if not v.is_boundary], factor=0.35, use_axis_x=True, use_axis_y=True, use_axis_z=False)
        # równy brzeg: to, co wystaje poniżej linii brzegu, schodzi się na nią
        for v in bm.verts:
            r = rim_z(v.co.y)
            if v.co.z < r:
                v.co.z = r
        bmesh.ops.dissolve_degenerate(bm, dist=0.0004, edges=bm.edges[:])
    bm, lps = shell(B, pick, off, smooth, 1, rim=0.004, gap=0.006, post=post)
    return bm, BVHTree.FromBMesh(bm), [lp for lp in lps if len(lp) > 20], rim_z


def czapka_daszek():
    """czapka z daszkiem: sześć klinów ze szwami i guzikiem, usztywniony panel czołowy, wygięty daszek z przeszyciami, pasek regulacji"""
    B = Body()
    cloth = mat('plotno_czapka', '2c4a7a', 0.9)
    under = mat('plotno_czapka_c', '223a60', 0.9)
    white = mat('plotno_naszywka', 'e8e6df', 0.9)
    hz, hy = B.H['Bip01 Head'].z, B.H['Bip01 Head'].y
    zf, zb = hz + 0.134, hz + 0.088

    def rim(y):
        # brzeg poziomy od czoła do miejsca nad uszami, dopiero z tyłu schodzi na potylicę
        k = max(0.0, min(1.0, (y - (hy + 0.035)) / 0.08))
        return zf + (zb - zf) * k * k * (3 - 2 * k)

    # główka z promieni rzucanych z zewnątrz (gładka, bez odlewu fryzury); ścianki idą prosto w dół do otoku
    bm = wrap_head(B, lambda d: rim(hy + 0.007 + d.y * 0.11), lambda z: 0.0085, dome=True, rows=5, zc=hz + 0.185, straight=True, r_max=0.14)
    tree = BVHTree.FromBMesh(bm)
    rims = [lp for lp in loops(bm, lambda c: True) if len(lp) > 20]
    rim_z = rim
    ob = to_object(B, bm, 'czapka_daszek', [cloth, under, white])
    parts = [band(lp, 0.0035, under, 'otok', 0.0008, 1.8) for lp in rims]
    # szwy klinów zbiegające się w guziku
    c = Vector((0, hy + 0.01, hz + 0.1))
    top, _ = on_surface(tree, c + Z * 0.4, DOWN, 0.001)
    for k in range(6):
        an = math.radians(30 + k * 60)
        pts = []
        for j in range(1, 9):
            al = math.radians(8 + j * 9.5)
            d = Vector((math.sin(an) * math.sin(al), math.cos(an) * math.sin(al), math.cos(al)))
            loc, nrm, _, _ = tree.ray_cast(c + d * 0.4, -d, 0.6)
            if loc is not None and loc.z > rim_z(loc.y) + 0.004:
                pts.append(loc + nrm * 0.0012)
        if len(pts) > 2:
            parts.append(sweep('szew', [top] + pts, 0.0016, under, 4))
    parts.append(lathe('guzik', [(0.0, 0.0), (0.008, 0.0), (0.008, 0.003), (0.004, 0.006), (0.0, 0.006)], cloth, 10, loc=tuple(top)))
    # daszek: wyrasta z brzegu panelu czołowego (ten sam łuk co czapka), wysunięty do przodu, wygięty na boki
    ax = Vector((0, hy + 0.005, 0))
    half = math.radians(66)
    nu, nv = 20, 7

    def bill(u, v, dz=0.0):
        th = half * u
        d = Vector((math.sin(th), -math.cos(th), 0))
        loc, _, _, _ = tree.ray_cast(ax + Z * (zf + 0.014) + d * 0.4, -d, 0.6)
        r = (Vector((loc.x, loc.y, 0)) - ax).length if loc is not None else 0.11
        base = ax + d * (r - 0.006) + Z * (zf + 0.003)
        ln = 0.074 * (1.0 - abs(u) ** 2.4) ** 0.75
        return base + Vector((0, -ln * v, -0.09 * ln * v - 0.017 * u * u * (0.35 + 0.65 * v) + dz))
    vb = bmesh.new()
    rows = [[vb.verts.new(bill(i / nu * 2 - 1, j / nv)) for i in range(nu + 1)] for j in range(nv + 1)]
    for j in range(nv):
        for i in range(nu):
            vb.faces.new((rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]))
    bmesh.ops.recalc_face_normals(vb, faces=vb.faces[:])
    if sum(fc.normal.z for fc in vb.faces) < 0:
        bmesh.ops.reverse_faces(vb, faces=vb.faces[:])
    for fc in vb.faces:
        fc.smooth = True
    ret = bmesh.ops.solidify(vb, geom=vb.faces[:], thickness=0.0045)
    bill_ob = mesh_object(vb, 'daszek', cloth)
    bill_ob.data.materials.append(under)
    for pl in bill_ob.data.polygons:
        if pl.normal.z < -0.5:
            pl.material_index = 1        # spód daszka ciemniejszy
    parts.append(bill_ob)
    for k in (0.3, 0.55, 0.8, 0.97):
        pts = [bill(i / nu * 2 - 1, k, 0.0006) for i in range(1, nu)]
        parts.append(sweep('przeszycie', pts, 0.0008, under, 4))
    # pasek regulacji z tyłu
    parts.append(patch(tree, Vector((0, hy + 0.3, zb + 0.018)), X, Z, 0.06, 0.014, 0.003, under, 'regulacja', 4, 2, 0.3, BACK))
    finish(B, ob, parts, 'czapka_daszek', rigid='Bip01 Head')


def czapka_zimowa():
    """czapka zimowa: gruba dzianina z wywiniętym ściągaczem, lekko opadający czubek, naszywka z boku"""
    B = Body()
    knit = mat('dzianina_czapka', '2a2c33', 0.95)
    rib = mat('sciagacz_czapka', '23252b', 0.95)
    tag_m = mat('skora_naszywka', '8a6a3a', 0.7)
    hz, hy = B.H['Bip01 Head'].z, B.H['Bip01 Head'].y

    def off(co, w):
        slouch = max(0.0, min(1.0, (co.z - hz - 0.17) / 0.05))
        return 0.014 + 0.014 * slouch
    bm, tree, rims, rim_z = _head_shell(B, 0.13, 0.05, off, smooth_gap=0.012)
    for v in bm.verts:
        k = max(0.0, min(1.0, (v.co.z - hz - 0.19) / 0.05))
        v.co.y += 0.02 * k
    tree = BVHTree.FromBMesh(bm)
    ob = to_object(B, bm, 'czapka_zimowa', [knit, rib, tag_m])
    parts = []
    # wywinięty ściągacz: równy, zaokrąglony pas dookoła głowy, położony na czapce
    axis = Vector((0, hy + 0.005, 0))
    cuff = ring_band(tree, axis, rim_z, [(-0.007, 0.001), (-0.004, 0.008), (0.006, 0.0115), (0.022, 0.0125), (0.038, 0.0125), (0.05, 0.0115), (0.058, 0.008), (0.06, 0.001)], rib)
    parts.append(cuff)
    parts.append(patch(BVHTree.FromBMesh(bmesh_from(cuff)), Vector((0.3, hy - 0.02, rim_z(hy - 0.02) + 0.028)), Y, Z, 0.034, 0.022, 0.002, tag_m, 'naszywka', 3, 2, 0.3, Vector((-1, 0, 0))))
    finish(B, ob, parts, 'czapka_zimowa', rigid='Bip01 Head')


def bmesh_from(ob):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    return bm


def okulary():
    """ciemne okulary: oprawki z zaokrąglonych ramek, mostek, noski, zauszniki zagięte za uchem, błyszczące szkła"""
    B = Body()
    frame = mat('plastik_oprawka', '0c0c0e', 0.35)
    glass = mat('szklo_okulary', '0a0b0f', 0.06, 0.7)
    metal = mat('metal_zawias', 'b9bcc2', 0.3, 0.9)
    eL, eR = B.H['Bip01 LEye'], B.H['Bip01 REye']
    y0 = min(eL.y, eR.y) - 0.03
    z0 = (eL.z + eR.z) / 2 - 0.002
    parts = []
    for e, sx in ((eL, 1), (eR, -1)):
        c = Vector((e.x * 1.04, y0 + 0.004, z0))
        rot = Matrix.Rotation(math.radians(-9 * sx), 4, 'Z')
        pts = []
        for k in range(24):
            a = k / 24 * math.tau
            ca, sa = math.cos(a), math.sin(a)
            # zaokrąglony prostokąt, lekko opadający na zewnątrz
            px = 0.026 * (abs(ca) ** 0.6) * (1 if ca >= 0 else -1)
            pz = 0.0185 * (abs(sa) ** 0.6) * (1 if sa >= 0 else -1) - 0.003 * (px * sx / 0.026 + 1) * (1 if sa < 0 else 0)
            pts.append(c + rot @ Vector((px, 0, pz)))
        parts.append(sweep('ramka', pts, 0.0022, frame, 6, True))
        lb = bmesh.new()
        vs = [lb.verts.new(p + Vector((0, 0.0006, 0))) for p in pts]
        lb.faces.new(vs)
        bmesh.ops.triangulate(lb, faces=lb.faces[:])
        parts.append(mesh_object(lb, 'szklo', glass))
        # zausznik: od zawiasu przy skroni za ucho
        h = c + rot @ Vector((0.027 * sx, 0, 0.008))
        tp = [h, h + Vector((0.006 * sx, 0.012, 0.0)), Vector((e.x * 1.04 + 0.042 * sx, y0 + 0.07, z0 + 0.01)), Vector((e.x * 1.04 + 0.044 * sx, y0 + 0.125, z0 + 0.009)), Vector((e.x * 1.04 + 0.04 * sx, y0 + 0.148, z0 - 0.012))]
        parts.append(sweep('zausznik', tp, 0.002, frame, 5, False, 1.6))
        parts.append(rbox('zawias', (0.004, 0.006, 0.006), metal, 0.001, tuple(h + Vector((0.003 * sx, 0.004, 0)))))
        parts.append(lathe('nosek', [(0.0, 0.0), (0.0035, 0.001), (0.004, 0.004), (0.0, 0.005)], frame, 8, loc=(c.x - 0.02 * sx, y0 + 0.009, z0 - 0.012)))
    mid = Vector((0, y0 + 0.001, z0 + 0.008))
    parts.append(sweep('mostek', [Vector((-0.011, y0 + 0.003, z0 + 0.006)), mid + Vector((0, -0.002, 0.003)), Vector((0.011, y0 + 0.003, z0 + 0.006))], 0.0022, frame, 6))
    ob = parts.pop(0)
    finish(B, ob, parts, 'okulary', rigid='Bip01 Head')


def lancuch():
    """łańcuch: prawdziwe ogniwa ułożone na karku i piersi, z blaszką pośrodku"""
    B = Body()
    gold = mat('metal_zloto', 'd9ae45', 0.28, 1.0)
    nk = B.H['Bip01 Neck']
    n = 46
    path = []
    for k in range(n):
        a = k / n * math.tau
        f = max(0.0, math.cos(a))
        d = Vector((math.sin(a), -math.cos(a), 0))
        z = nk.z - 0.004 - 0.085 * f ** 1.4 + 0.03 * max(0.0, -math.cos(a))
        loc, nrm, _, _ = B.tree.ray_cast(Vector((0, nk.y, z)) + d * 0.45, -d, 0.6)
        if loc is None:
            loc, nrm, _, _ = B.tree.find_nearest(Vector((0, nk.y, z)) + d * 0.12)
        path.append((loc + nrm * (0.005 + 0.02 * f ** 0.8), nrm))
    parts = []
    for k in range(n):
        p, nr = path[k]
        t = (path[(k + 1) % n][0] - path[k - 1][0]).normalized()
        bn = nr.cross(t).normalized()
        wv = nr if k % 2 == 0 else bn
        ln = (path[(k + 1) % n][0] - path[k - 1][0]).length * 0.36
        pts = [p + t * (ln * math.cos(j / 10 * math.tau)) + wv * (0.0034 * math.sin(j / 10 * math.tau)) for j in range(10)]
        parts.append(sweep('ogniwo', pts, 0.0011, gold, 5, True))
    p0, n0 = path[0]
    pl = rbox('blaszka', (0.014, 0.003, 0.02), gold, 0.002, tuple(p0 + Vector((0, -0.002, -0.016))))
    parts.append(pl)
    parts.append(sweep('zawieszka', [p0 + Vector((0.003 * math.cos(j / 8 * math.tau), -0.001, -0.004 + 0.004 * math.sin(j / 8 * math.tau))) for j in range(8)], 0.0008, gold, 4, True))
    ob = parts.pop(0)
    finish(B, ob, parts, 'lancuch', rigid='Bip01 Spine2')


ALL = (bluza_kaptur, kurtka_kieszenie, koszula, kurtka_skorzana, dres_gora, kurtka_puchowa, marynarka, plaszcz, kurtka_jeans, sweter, parka, chinosy, spodnie_garnitur, dresy, jeansy, bojowki, rekawiczki, rekawiczki_skora, trampki, trampki_wysokie, buty_bieg, polbuty, buty_robocze,
       komin, kominiarka, czapka_daszek, czapka_zimowa, okulary, lancuch)
if __name__ == '__main__':
    only = [a for a in sys.argv[sys.argv.index('--') + 1:]] if '--' in sys.argv else []
    for f in ALL:
        if not only or f.__name__ in only:
            f()
