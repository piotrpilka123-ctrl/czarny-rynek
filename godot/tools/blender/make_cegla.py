"""Sprasowana „cegła” towaru: obła kostka zawinięta w folię, oklejona taśmą na krzyż, z wytłoczonym znakiem prasy.
TintCegla — folia (kolor nadaje gra wg towaru), Tasma — taśma pakowa. Spód na z = 0."""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
from lib import _finish
from mathutils import noise

S = Vector((0.236, 0.148, 0.066))
R = 0.02
# linie siatki ustawione tak, żeby wypadały na krawędziach taśmy i w zaokrągleniach
GRID = {0: (0.0, 0.089, 0.30, 0.445, 0.5), 1: (0.0, 0.108, 0.30, 0.42, 0.5), 2: (0.0, 0.15, 0.30, 0.42, 0.5)}


def remap(c, ax):
    i = int(round(abs(c) * 8))
    return math.copysign(GRID[ax][i], c) if i else 0.0


def surf(co):
    p = Vector((remap(co.x, 0) * S.x, remap(co.y, 1) * S.y, remap(co.z, 2) * S.z))
    inner = Vector((max(-S.x / 2 + R, min(S.x / 2 - R, p.x)), max(-S.y / 2 + R, min(S.y / 2 - R, p.y)), max(-S.z / 2 + R, min(S.z / 2 - R, p.z))))
    d = p - inner
    if d.length > 1e-9:
        p = inner + d.normalized() * R
    # poduszka: środek ścianek lekko wybrzuszony, jak ciasno owinięty blok
    fx = 1.0 - (2.0 * p.x / S.x) ** 2
    fy = 1.0 - (2.0 * p.y / S.y) ** 2
    fz = 1.0 - (2.0 * p.z / S.z) ** 2
    p.z *= 1.0 + 0.07 * fx * fy
    p.y *= 1.0 + 0.025 * fx * fz
    p.x *= 1.0 + 0.012 * fy * fz
    # zmarszczki folii
    w = noise.noise(p * 70.0) * 0.0011 + noise.noise(p * 190.0) * 0.0004
    return p * (1.0 + w / 0.06) + Vector((0, 0, S.z / 2 * 1.07))


def cegla():
    reset()
    wrap = mat('folia', 'd9d6cc', 0.5)
    tape = mat('tasma', '8a6a3a', 0.55)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=7, use_grid_fill=True)
    for v in bm.verts:
        v.co = surf(v.co.copy())
    bm.normal_update()
    # taśma: te same ścianki odsunięte o grubość taśmy, więc leży dokładnie na obłościach
    tb = bmesh.new()
    made = {}
    zc = S.z / 2 * 1.07
    for f in bm.faces:
        c = f.calc_center_median()
        end = abs(c.x) > S.x / 2 - 0.004
        side = abs(c.y) > S.y / 2 - 0.004
        cross = abs(c.x) < 0.021 and not end
        along = abs(c.y) < 0.016 and not side
        if not (cross or along):
            continue
        vs = []
        for v in f.verts:
            if v.index not in made:
                made[v.index] = tb.verts.new(v.co + v.normal * 0.0009)
            vs.append(made[v.index])
        tb.faces.new(vs)
    me = bpy.data.meshes.new('TintCegla')
    bm.to_mesh(me)
    bm.free()
    core = _finish(me, 'TintCegla', wrap, True, None)
    mt = bpy.data.meshes.new('Tasma')
    tb.to_mesh(mt)
    tb.free()
    _finish(mt, 'Tasma', tape, True, None)
    # znak prasy wytłoczony w rogu: pierścień z literą
    top = S.z * 1.07 + 0.0012
    cx, cy = 0.062, 0.037
    ring = [(cx + math.cos(a * math.tau / 18) * 0.0125, cy + math.sin(a * math.tau / 18) * 0.0125, top) for a in range(19)]
    parts = [core, tube('znak', ring, 0.0014, wrap, 6)]
    parts.append(text('litera', 'S', 0.017, wrap, (cx, cy - 0.0058, top - 0.0006), (0, 0, 0), 0.0014))
    # zgrzew folii na spodniej krawędzi krótkiego boku
    for sx in (-1, 1):
        parts.append(rbox('zgrzew', (0.004, 0.11, 0.012), wrap, 0.0015, (sx * (S.x / 2 + 0.001), 0, 0.016), (0, math.radians(sx * 14), 0), segs=1))
    join('TintCegla', parts)
    export('cegla')


cegla()
