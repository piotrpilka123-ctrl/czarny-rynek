"""Próba mimiki na kościach twarzy modeli Rocketbox: te same przesunięcia, które potem nakłada gra (scripts/face.gd).
Renderuje twarz w kilku minach obok siebie, żeby sprawdzić kierunki i siłę ruchu bez uruchamiania gry.
Użycie: Blender -b --python tools/blender/twarz_test.py -- wynik.png [m02]"""
import sys, os, math, json
import bpy
from mathutils import Vector, Matrix

args = sys.argv[sys.argv.index('--') + 1:]
out = args[0]
model = args[1] if len(args) > 1 else 'm02'
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MINY = json.load(open(os.path.join(ROOT, 'tools', 'blender', 'miny.json')))

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=os.path.join(ROOT, 'assets', 'people', model, model + '.fbx'))
arm = [o for o in bpy.data.objects if o.type == 'ARMATURE'][0]
pb = arm.pose.bones
bpy.context.view_layer.update()


def head(n):
    return pb[n].head.copy()

R, Lf = head('Bip01 REye'), head('Bip01 LEye')
mid = (R + Lf) * 0.5
right = (R - Lf).normalized()
# „góra” twarzy: od górnej wargi do środka brwi (obie kości leżą na powierzchni twarzy, więc oś nie ucieka w przód)
up = (head('Bip01 MMiddleEyebrow') - head('Bip01 MUpperLip'))
up = (up - right * up.dot(right)).normalized()
fwd = right.cross(up)
if (head('Bip01 MNose') - mid).dot(fwd) < 0:
    fwd = -fwd
ied = (R - Lf).length
REST = {b.name: b.matrix.copy() for b in pb}
print('TWARZ ied=%.4f right=%s up=%s fwd=%s' % (ied, tuple(round(v, 2) for v in right), tuple(round(v, 2) for v in up), tuple(round(v, 2) for v in fwd)))


def pose(weights):
    for b in pb:
        b.matrix = REST[b.name]
    bpy.context.view_layer.update()
    acc = {}
    jaw = 0.0
    blink = 0.0
    for name, w in weights.items():
        if name == 'blink':
            blink = w
            continue
        m = MINY[name]
        jaw += m.get('jaw', 0.0) * w
        for bone, off in m.get('bones', {}).items():
            for side in ('L', 'R'):
                bn = 'Bip01 ' + (bone.replace('*', side) if '*' in bone else bone)
                if bn not in pb:
                    continue
                sx = 1.0 if side == 'R' else -1.0
                v = (right * (off[0] * sx if '*' in bone else off[0]) + up * off[1] + fwd * off[2]) * ied * w
                acc[bn] = acc.get(bn, Vector((0, 0, 0))) + v
                if '*' not in bone:
                    break
    if jaw != 0.0:
        j = pb['Bip01 MJaw']
        o = REST['Bip01 MJaw'].to_translation()
        chin = (REST['Bip01 MBottomLip'].to_translation() - o)
        a = math.radians(jaw)
        if (Matrix.Rotation(a, 4, right) @ chin).dot(up) > chin.dot(up):
            a = -a
        j.matrix = Matrix.Translation(o) @ Matrix.Rotation(a, 4, right) @ Matrix.Translation(-o) @ j.matrix
        bpy.context.view_layer.update()
    for bn, v in acc.items():
        pb[bn].matrix = Matrix.Translation(v) @ pb[bn].matrix
        bpy.context.view_layer.update()
    if blink > 0.0:
        for side in ('L', 'R'):
            t, b = pb['Bip01 %sEyeBlinkTop' % side], pb['Bip01 %sEyeBlinkBottom' % side]
            d = (REST[b.name].to_translation() - REST[t.name].to_translation())
            t.matrix = Matrix.Translation(d * 0.82 * blink) @ t.matrix
            bpy.context.view_layer.update()
            b.matrix = Matrix.Translation(-d * 0.1 * blink) @ b.matrix
            bpy.context.view_layer.update()


# scena: światła i kamera na wprost twarzy (w układzie armatury → świat)
M = arm.matrix_world
wmid = M @ mid
wf = (M.to_3x3() @ fwd).normalized()
wu = (M.to_3x3() @ up).normalized()
wied = (M @ R - M @ Lf).length
cam_d = bpy.data.cameras.new('k')
cam_d.lens = 85
cam = bpy.data.objects.new('k', cam_d)
bpy.context.scene.collection.objects.link(cam)
cam.location = wmid + wf * wied * 8.0 - wu * wied * 0.5 + (M.to_3x3() @ right).normalized() * wied * 2.4
cam.rotation_euler = ((wmid - wu * wied * 0.55) - cam.location).to_track_quat('-Z', 'Y').to_euler()
for (k, e) in ((1.0, 3.5), (-1.3, 1.4)):
    ld = bpy.data.lights.new('s', 'SUN')
    ld.energy = e
    lo = bpy.data.objects.new('s', ld)
    bpy.context.scene.collection.objects.link(lo)
    d = -(wf + (M.to_3x3() @ right).normalized() * k * 0.7 + wu * 0.5)
    lo.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
skin = bpy.data.materials.new('skora')
skin.use_nodes = True
skin.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (0.72, 0.52, 0.42, 1)
skin.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = 0.6
for o in bpy.data.objects:
    if o.type == 'MESH':
        for sl in o.material_slots:
            sl.material = skin
world = bpy.data.worlds.new('w')
world.use_nodes = True
world.node_tree.nodes['Background'].inputs[0].default_value = (0.5, 0.52, 0.56, 1)
bpy.context.scene.world = world
sc = bpy.context.scene
sc.camera = cam
sc.render.engine = 'BLENDER_EEVEE_NEXT'
sc.render.resolution_x = 300
sc.render.resolution_y = 340
sc.view_settings.view_transform = 'Standard'
tests = [{}, {'blink': 1.0}, {'usmiech': 1.0}, {'zlosc': 1.0}, {'smutek': 1.0}, {'zdziwienie': 1.0}, {'mowa': 1.0}, {'usmiech': 0.6, 'mowa': 0.6}]
files = []
for i, t in enumerate(tests):
    pose(t)
    f = out.replace('.png', '_%d.png' % i)
    sc.render.filepath = f
    bpy.ops.render.render(write_still=True)
    files.append(f)
print('TWARZ pliki', ' '.join(files))
