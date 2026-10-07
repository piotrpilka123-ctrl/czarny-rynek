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
        v.co += v.normal * max(-0.0025, d * amp * 1.5)


def shell(B, pick, offset, smooth=2, cuts=1, skip=('opacity',), rim=0.006, gap=0.003, wrinkle=0.0):
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


def finish(B, ob, parts, name, bind=None, rigid=None):
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
        for v in me.vertices:
            if v.index >= n0 or not v.groups:
                if bind and v.index >= n0:
                    for bn, x in bind.items():
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


def _top(B, hem, off, smooth):
    def pick(co, w):
        if hand_w(w) > 0.85 or head_w(w) + w.get('Bip01 Neck', 0.0) > 0.72:
            return False
        if top_w(w) >= 0.3:
            return True
        return co.z > hem and abs(co.x) < 0.3 and legs_w(w) > 0.3 and part(w, ('Thigh',)) < 0.75
    def off2(co, w):
        o = off(co, w)
        if abs(co.x) < 0.3 and co.z < 1.0:
            o = max(o, 0.012 + 0.02 * min(1.0, (1.0 - co.z) / 0.06))
        return o
    bm, lps = shell(B, pick, off2, smooth, wrinkle=1.0)
    neck = pick_loops(lps, lambda c: c.z > 1.42 and abs(c.x) < 0.1)
    cuffs = pick_loops(lps, lambda c: abs(c.x) > 0.4)
    hems = pick_loops(lps, lambda c: c.z < 1.0 and abs(c.x) < 0.15)
    return bm, BVHTree.FromBMesh(bm), neck, cuffs, hems


def _arm_dir(B, c):
    side = 'L' if c.x > 0 else 'R'
    return (B.H['Bip01 %s Hand' % side] - B.H['Bip01 %s Forearm' % side]).normalized()


def _cuff(B, co, t0=0.82):
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
    paint(ob, lambda c, n: c.z < 0.905 or _cuff(B, c), 1)
    parts = []
    for lp in neck:
        parts.append(band(lp, 0.011, rib, 'karczek', 0.002, 1.3))
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
        parts.append(band(lp, 0.011, dark, 'stojka', 0.004, 3.4, Z * 0.022, wide=0.8))
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
        parts.append(band(lp, 0.006, plaid, 'stojka', 0.002, 2.2, Z * 0.008, wide=0.6))
    for lp in cuffs:
        c = sum(lp, Vector()) / len(lp)
        parts.append(band(lp, 0.009, plaid, 'mankiet', 0.001, 3.0, _arm_dir(B, c) * 0.004, wide=0.6))
        parts.append(button(tree, c + Vector((0, -0.05, 0.0)), FRONT, btn, 0.005, 0.011))
    parts.append(ribbon(tree, Vector((0.0, -0.3, 0.86)), Vector((0.0, -0.3, 1.46)), FRONT, 0.032, plaid, 18, 0.004, 'plisa', 0.001))
    for k in range(7):
        parts.append(button(tree, Vector((0.0, -0.3, 0.9 + k * 0.088)), FRONT, btn, 0.0055, 0.006))
    parts.append(patch(tree, Vector((0.105, -0.3, 1.33)), X, Z, 0.095, 0.105, 0.004, plaid, 'kieszonka', 5, 5, 0.25, FRONT))
    # rogi kołnierzyka: dwa trójkątne płaty rozchodzące się od szyi
    for sx in (-1, 1):
        r = (X * sx + Z * -0.75).normalized()
        u = (Z + X * sx * 0.75).normalized()
        parts.append(patch(tree, Vector((sx * 0.052, -0.3, 1.475)), r, u, 0.085, 0.05, 0.009, plaid, 'rog', 5, 3, 0.9, FRONT))
    finish(B, ob, parts, 'koszula')


# ================================================================ SPODNIE
def _legs(B, off, smooth, tight=0.86):
    def pick(co, w):
        return legs_w(w) >= 0.3 and top_w(w) < 0.72 and foot_w(w) < 0.6 and hand_w(w) < 0.3
    def off2(co, w):
        # w pasie spodnie przylegają, żeby schować się pod bluzą czy koszulą
        return min(off(co, w), 0.009) if co.z > 0.88 else off(co, w)
    bm, lps = shell(B, pick, off2, smooth, wrinkle=1.0)
    waist = pick_loops(lps, lambda c: c.z > 0.8)
    ankles = pick_loops(lps, lambda c: c.z < 0.3)
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
    bm, tree, waist, ankles = _legs(B, off, 3)
    ob = to_object(B, bm, 'dresy', [knit, rib, white, cord])
    paint(ob, lambda c, n: _ankle(B, c, 0.88), 1)
    parts = []
    for lp in waist:
        parts.append(band(lp, 0.008, rib, 'guma', 0.001, 2.8, Z * -0.012))
    for lp in ankles:
        parts.append(band(lp, 0.009, rib, 'kostka', 0.004, 2.6, Z * 0.014))
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
    bm, tree, waist, ankles = _legs(B, off, 1)
    ob = to_object(B, bm, 'jeansy', [denim, light, thread, metal])
    parts = []
    for lp in waist:
        parts.append(band(lp, 0.011, denim, 'pasek', 0.002, 2.6, Z * -0.014, wide=0.7))
    for lp in ankles:
        parts.append(band(lp, 0.009, light, 'podwiniecie', 0.007, 3.2, Z * 0.022, wide=0.6))
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
    bm, tree, waist, ankles = _legs(B, off, 2)
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
    bm, tree, wrists = _hands(B, lambda co, w: 0.0045)
    ob = to_object(B, bm, 'rekawiczki', [suede, rib])
    paint(ob, lambda c, n: along(B, c, 'Forearm', 'Hand') < 0.97, 1)
    parts = []
    for lp in wrists:
        c = sum(lp, Vector()) / len(lp)
        parts.append(band(lp, 0.005, rib, 'sciagacz', 0.001, 1.8))
    finish(B, ob, parts, 'rekawiczki')


def rekawiczki_skora():
    """skórzane rękawiczki: cienka czarna skóra, pasek z klamerką na nadgarstku"""
    B = Body()
    lea = mat('skora_czarna', '1e1611', 0.55)
    metal = mat('metal_klamra', 'b9bcc2', 0.3, 0.9)
    bm, tree, wrists = _hands(B, lambda co, w: 0.003, 0.82)
    ob = to_object(B, bm, 'rekawiczki_skora', [lea, metal])
    parts = []
    for lp in wrists:
        c = sum(lp, Vector()) / len(lp)
        d = _arm_dir(B, c)
        parts.append(band(lp, 0.005, lea, 'lamowka', 0.001, 1.4))
        parts.append(band(lp, 0.006, lea, 'pasek', 0.003, 1.8, d * 0.045))
        loc, nrm, _, _ = tree.find_nearest(c + d * 0.045 + Vector((0, -0.05, 0)))
        bk = rbox('klamra', (0.016, 0.012, 0.004), metal, 0.001, tuple(loc + nrm * 0.006))
        bk.rotation_euler = nrm.to_track_quat('Z', 'Y').to_euler()
        parts.append(bk)
    finish(B, ob, parts, 'rekawiczki_skora')


# ================================================================ BUTY
def _feet(B, off, shaft=None, smooth=1, top=0.105):
    """cholewka ze stopy; niskie buty kończą się pod kostką (top), wysokie obejmują łydkę od `shaft` w dół"""
    def pick(co, w):
        if foot_w(w) >= 0.35:
            return shaft is not None or co.z < top
        return shaft is not None and part(w, ('Calf',)) > 0.3 and co.z < 0.35 and along(B, co, 'Calf', 'Foot') > shaft
    bm, lps = shell(B, pick, off, smooth, 1, rim=0.004)
    return bm, BVHTree.FromBMesh(bm), pick_loops(lps, lambda c: c.z > 0.06)


def _sock(B, material, hi=0.16):
    """skarpetka między butem a nogawką"""
    def pick(co, w):
        return co.z < hi and (foot_w(w) >= 0.2 or part(w, ('Calf',)) > 0.3)
    bm, lps = shell(B, pick, lambda co, w: 0.002, 1, 1, rim=0.0, gap=0.0015)
    ob = mesh_object(bm, 'skarpetka', material)
    for n in B.names:
        ob.vertex_groups.new(name=n)
    return ob


def _welt(B, tree, z, radius, material, parts, name='rant'):
    """wałek dookoła każdego buta na wysokości z: zakrywa granicę podeszwy i cholewki"""
    for side in ('L', 'R'):
        ank, toe = B.H['Bip01 %s Foot' % side], B.H['Bip01 %s Toe0' % side]
        c = Vector(((ank.x + toe.x) / 2, (ank.y + toe.y) / 2 - 0.01, z))
        pts = []
        for k in range(30):
            an = k / 30 * math.tau
            d = Vector((math.sin(an), math.cos(an), 0))
            loc, nrm, _, _ = tree.ray_cast(c + d * 0.2, -d, 0.2)
            if loc is None or abs(loc.x - c.x) > 0.075:
                loc, nrm, _, _ = tree.find_nearest(c + d * 0.06)
            pts.append(loc + nrm * 0.001)
        parts.append(sweep(name, pts, radius, material, 5, True))


def _laces(B, tree, material, parts, rows=5, s0=0.2, s1=0.72, lift=0.003, eyelet=None):
    for side in ('L', 'R'):
        ank, toe = B.H['Bip01 %s Foot' % side], B.H['Bip01 %s Toe0' % side]
        p0 = Vector((ank.x + 0.004 * (1 if side == 'L' else -1), ank.y - 0.045, 0.5))
        p1 = Vector((toe.x, toe.y - 0.005, 0.5))
        fwd = (p1 - p0).normalized()
        right = Vector((-fwd.y, fwd.x, 0))
        prev = None
        for k in range(rows):
            c = p0.lerp(p1, s0 + (s1 - s0) * k / max(1, rows - 1))
            hw = 0.015 + 0.006 * k / rows
            a, b = c - right * hw, c + right * hw
            parts.append(stitch(tree, a, b, DOWN, material, 4, 0.0022, lift, 'sznurowka'))
            if prev is not None:
                parts.append(stitch(tree, prev[0], b, DOWN, material, 4, 0.0018, lift + 0.0015, 'krzyz'))
                parts.append(stitch(tree, prev[1], a, DOWN, material, 4, 0.0018, lift + 0.0015, 'krzyz'))
            if eyelet is not None:
                parts.append(button(tree, a, DOWN, eyelet, 0.004, lift))
                parts.append(button(tree, b, DOWN, eyelet, 0.004, lift))
            prev = (a, b)


def trampki():
    """trampki: czarne płótno, biała gumowa podeszwa z czerwonym paskiem, biały nosek, białe sznurowadła, skarpetka"""
    B = Body()
    canvas = mat('plotno_trampki', '26282e', 0.9)
    rubber = mat('guma_trampki', 'e8e6df', 0.6)
    lace = mat('plotno_sznurowka', 'f0eee8', 0.9)
    stripe = mat('guma_pasek', 'b0382c', 0.6)
    sock = mat('dzianina_skarpeta', 'b4b3ad', 0.95)
    bm, tree, tops = _feet(B, lambda co, w: 0.006 if co.z < 0.03 else 0.0035)
    ob = to_object(B, bm, 'trampki', [canvas, rubber, lace, stripe, sock])
    toe_y = min(B.H['Bip01 L Toe0'].y, B.H['Bip01 R Toe0'].y)
    paint(ob, lambda c, n: c.z < 0.03 or (c.y < toe_y - 0.025 and c.z < 0.07), 1)
    parts = [_sock(B, sock)]
    for lp in tops:
        parts.append(band(lp, 0.004, canvas, 'cholewka', 0.0005, 1.4))
    _welt(B, tree, 0.031, 0.0035, rubber, parts)
    _welt(B, tree, 0.018, 0.0016, stripe, parts, 'pasek')
    _laces(B, tree, lace, parts, 5, eyelet=mat('metal_oczko', 'b9bcc2', 0.3, 0.9))
    finish(B, ob, parts, 'trampki')


def buty_bieg():
    """buty do biegania: siatkowa cholewka, gruba biała pianka, czarny bieżnik, trzy paski po bokach, zapiętek, skarpetka"""
    B = Body()
    mesh = mat('plotno_bieg', 'c8482a', 0.85)
    foam = mat('guma_pianka', 'f1efe9', 0.7)
    sole = mat('guma_bieznik', '1c1c1f', 0.8)
    lace = mat('plotno_sznurowka', 'f0eee8', 0.9)
    grey = mat('skora_zapietek', '55585f', 0.7)
    sock = mat('dzianina_skarpeta', 'b4b3ad', 0.95)
    bm, tree, tops = _feet(B, lambda co, w: 0.009 if co.z < 0.04 else 0.004)
    ob = to_object(B, bm, 'buty_bieg', [mesh, foam, sole, lace, grey, sock])
    paint(ob, lambda c, n: c.z < 0.042, 1)
    paint(ob, lambda c, n: c.z < 0.012, 2)
    heel_y = max(B.H['Bip01 L Foot'].y, B.H['Bip01 R Foot'].y)
    paint(ob, lambda c, n: c.y > heel_y + 0.03 and 0.042 <= c.z < 0.1, 4)
    parts = [_sock(B, sock, 0.15)]
    for lp in tops:
        parts.append(band(lp, 0.005, grey, 'kolnierz', 0.0005, 1.4))
    _welt(B, tree, 0.043, 0.004, foam, parts)
    _welt(B, tree, 0.012, 0.003, sole, parts, 'bieznik')
    _laces(B, tree, lace, parts, 5)
    for side in ('L', 'R'):
        sx = 1 if side == 'L' else -1
        ank = B.H['Bip01 %s Foot' % side]
        for k in range(3):
            a = Vector((ank.x + sx * 0.2, ank.y - 0.035 - k * 0.022, 0.082))
            b = Vector((ank.x + sx * 0.2, ank.y - 0.06 - k * 0.022, 0.05))
            parts.append(ribbon(tree, a, b, Vector((-sx, 0, 0)), 0.008, foam, 4, 0.0015, 'pasek'))
    finish(B, ob, parts, 'buty_bieg')


def buty_robocze():
    """buty robocze: skóra za kostkę, wzmocniony nosek, gruba podeszwa z rantem, sznurowanie z oczkami, wyściełany kołnierz, pętelka z tyłu"""
    B = Body()
    lea = mat('skora_buty', '6b4a2b', 0.75)
    dark = mat('skora_buty_c', '4a321c', 0.75)
    sole = mat('guma_protektor', '1c1c1f', 0.85)
    lace = mat('plotno_sznurowka_b', 'c9a24a', 0.9)
    metal = mat('metal_oczko', 'b08a4a', 0.35, 0.9)
    bm, tree, tops = _feet(B, lambda co, w: 0.0085 if co.z < 0.04 else 0.0045, 0.74, 2)
    ob = to_object(B, bm, 'buty_robocze', [lea, dark, sole, lace, metal])
    toe_y = min(B.H['Bip01 L Toe0'].y, B.H['Bip01 R Toe0'].y)
    paint(ob, lambda c, n: c.y < toe_y - 0.005 and c.z < 0.085, 1)
    paint(ob, lambda c, n: c.z < 0.038, 2)
    parts = []
    for lp in tops:
        parts.append(band(lp, 0.006, dark, 'kolnierz', 0.001, 1.5))
    _welt(B, tree, 0.04, 0.0045, dark, parts)
    _laces(B, tree, lace, parts, 6, 0.02, 0.6, 0.004, metal)
    for side in ('L', 'R'):
        ank = B.H['Bip01 %s Foot' % side]
        a = Vector((ank.x, ank.y + 0.2, 0.17))
        parts.append(ribbon(tree, a, a + Z * 0.06, BACK, 0.016, dark, 3, 0.004, 'petelka', 0.002))
    finish(B, ob, parts, 'buty_robocze')


# ================================================================ SZYJA I GŁOWA
def komin():
    """komin naciągnięty na nos: elastyczna dzianina z poziomymi fałdami, obszyte brzegi"""
    B = Body()
    knit = mat('dzianina_komin', '3a3f48', 0.95)
    hz = B.H['Bip01 Head'].z
    hy = B.H['Bip01 Head'].y

    def pick(co, w):
        if w.get('Bip01 Neck', 0.0) >= 0.2 and co.z > 1.47:
            return True
        top = hz + 0.066 - 0.05 * max(0.0, min(1.0, (co.y - (hy - 0.11)) / 0.2))
        return head_w(w) >= 0.5 and co.z < top and w.get('Bip01 MTongue', 0.0) < 0.01

    def off(co, w):
        return 0.012 + 0.003 * math.sin(co.z * 210.0)
    bm, lps = shell(B, pick, off, 3, 1, rim=0.004, gap=0.009)
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

    def pick(co, w):
        if w.get('Bip01 LEye', 0.0) + w.get('Bip01 REye', 0.0) > 0.5 or w.get('Bip01 MTongue', 0.0) > 0.01:
            return False
        if w.get('Bip01 Neck', 0.0) >= 0.2 and co.z > 1.47:
            return True
        if head_w(w) < 0.5:
            return False
        # otwór na oczy: poziomy pas z przodu twarzy
        return not (co.y < hy - 0.055 and abs(co.z - ez) < 0.017 and abs(co.x) < 0.064)
    bm, lps = shell(B, pick, lambda co, w: 0.01, 3, 1, rim=0.004, gap=0.009)
    ob = to_object(B, bm, 'kominiarka', [knit])
    parts = []
    for lp in lps:
        c = sum(lp, Vector()) / len(lp)
        if len(lp) > 10:
            parts.append(band(lp, 0.0045, knit, 'obszycie', 0.0008, 1.2))
    finish(B, ob, parts, 'kominiarka')


def _head_shell(B, rim_front, rim_back, off, smooth=3):
    hz, hy = B.H['Bip01 Head'].z, B.H['Bip01 Head'].y

    def rim_z(y):
        return hz + rim_front + (rim_back - rim_front) * max(0.0, min(1.0, (y - (hy - 0.11)) / 0.21))

    def pick(co, w):
        return head_w(w) >= 0.5 and co.z > rim_z(co.y)
    bm, lps = shell(B, pick, off, smooth, 1, rim=0.004, gap=0.006)
    return bm, BVHTree.FromBMesh(bm), [lp for lp in lps if len(lp) > 20], rim_z


def czapka_daszek():
    """czapka z daszkiem: sześć klinów ze szwami i guzikiem, usztywniony przód, wygięty daszek z przeszyciami, naszywka"""
    B = Body()
    cloth = mat('plotno_czapka', '2c4a7a', 0.9)
    under = mat('plotno_czapka_c', '223a60', 0.9)
    white = mat('plotno_naszywka', 'e8e6df', 0.9)
    hz, hy = B.H['Bip01 Head'].z, B.H['Bip01 Head'].y

    def off(co, w):
        # przód usztywniony i wyższy, tył dopasowany
        front = max(0.0, min(1.0, (hy - co.y) / 0.1))
        return 0.008 + 0.01 * front * max(0.0, min(1.0, (co.z - hz - 0.13) / 0.05))
    bm, tree, rims, rim_z = _head_shell(B, 0.136, 0.072, off)
    ob = to_object(B, bm, 'czapka_daszek', [cloth, under, white])
    parts = [band(lp, 0.004, under, 'otok', 0.001, 1.6) for lp in rims]
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
            if loc is not None:
                pts.append(loc + nrm * 0.0012)
        if len(pts) > 2:
            parts.append(sweep('szew', [top] + pts, 0.0016, under, 4))
    parts.append(lathe('guzik', [(0.0, 0.0), (0.008, 0.0), (0.008, 0.003), (0.004, 0.006), (0.0, 0.006)], cloth, 10, loc=tuple(top)))
    # daszek: łuk przylegający do czoła, wygięty na boki, z grubością
    zr = rim_z(hy - 0.11) + 0.004
    fy = min(v.co.y for v in bm.verts if abs(v.co.x) < 0.02 and v.co.z < zr + 0.03)
    R = 0.086
    yc = fy + 0.004 + R
    vb = bmesh.new()
    rows = []
    nu, nv = 14, 6
    for j in range(nv + 1):
        v = j / nv
        row = []
        for i in range(nu + 1):
            u = i / nu * 2 - 1
            th = math.radians(62) * u
            base = Vector((R * math.sin(th), yc - R * math.cos(th), zr - 0.01 * u * u))
            L = 0.074 * (1.0 - 0.42 * u * u)
            row.append(vb.verts.new(base + Vector((0, -L * v, -0.02 * v - 0.012 * v * u * u))))
        rows.append(row)
    for j in range(nv):
        for i in range(nu):
            vb.faces.new((rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]))
    bmesh.ops.recalc_face_normals(vb, faces=vb.faces[:])
    bmesh.ops.solidify(vb, geom=vb.faces[:], thickness=0.004)
    parts.append(mesh_object(vb, 'daszek', cloth))
    for k in (0.3, 0.55, 0.8):
        pts = []
        for i in range(nu + 1):
            u = i / nu * 2 - 1
            th = math.radians(62) * u
            base = Vector((R * math.sin(th), yc - R * math.cos(th), zr - 0.01 * u * u))
            L = 0.074 * (1.0 - 0.42 * u * u)
            pts.append(base + Vector((0, -L * k, -0.02 * k - 0.012 * k * u * u + 0.0045)))
        parts.append(sweep('przeszycie', pts, 0.0009, under, 4))
    # pasek regulacji z tyłu
    parts.append(patch(tree, Vector((0, hy + 0.3, rim_z(hy + 0.1) + 0.02)), X, Z, 0.06, 0.016, 0.003, under, 'regulacja', 4, 2, 0.3, BACK))
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
    bm, tree, rims, rim_z = _head_shell(B, 0.108, 0.035, off)
    for v in bm.verts:
        k = max(0.0, min(1.0, (v.co.z - hz - 0.19) / 0.05))
        v.co.y += 0.02 * k
    ob = to_object(B, bm, 'czapka_zimowa', [knit, rib, tag_m])
    parts = []
    # wywinięty ściągacz: druga, grubsza warstwa nad brzegiem
    def pick2(co, w):
        r = rim_z(co.y)
        return head_w(w) >= 0.5 and r < co.z < r + 0.062
    b2, l2 = shell(B, pick2, lambda co, w: 0.021, 3, 1, rim=0.007, gap=0.016)
    cuff = mesh_object(b2, 'wywiniecie', rib)
    for n in B.names:
        cuff.vertex_groups.new(name=n)
    parts.append(cuff)
    for lp in l2:
        if len(lp) > 20:
            parts.append(band(lp, 0.006, rib, 'rant', 0.0, 1.2))
    parts.append(patch(BVHTree.FromBMesh(bmesh_from(cuff)), Vector((0.3, hy - 0.02, rim_z(hy - 0.02) + 0.03)), Y, Z, 0.034, 0.022, 0.002, tag_m, 'naszywka', 3, 2, 0.3, Vector((-1, 0, 0))))
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


ALL = (bluza_kaptur, kurtka_kieszenie, koszula, dresy, jeansy, bojowki, rekawiczki, rekawiczki_skora, trampki, buty_bieg, buty_robocze,
       komin, kominiarka, czapka_daszek, czapka_zimowa, okulary, lancuch)
if __name__ == '__main__':
    only = [a for a in sys.argv[sys.argv.index('--') + 1:]] if '--' in sys.argv else []
    for f in ALL:
        if not only or f.__name__ in only:
            f()
