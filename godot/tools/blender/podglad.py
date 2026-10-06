"""Podgląd modeli bez uruchamiania gry: renderuje pliki GLB do PNG (Eevee, trzy światła, kamera dopasowana do bryły).
Użycie: Blender -b --python tools/blender/podglad.py -- wynik.png model1 [model2 …] [--az=35] [--el=18] [--zoom=1.0]
Kilka modeli staje obok siebie w rzędzie."""
import sys, os, math
import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index('--') + 1:]
out = args[0]
names = [a for a in args[1:] if not a.startswith('--')]
opt = {a.split('=')[0][2:]: float(a.split('=')[1]) for a in args[1:] if a.startswith('--')}
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

bpy.ops.wm.read_factory_settings(use_empty=True)
x = 0.0
lo = Vector((1e9, 1e9, 1e9))
hi = Vector((-1e9, -1e9, -1e9))
for n in names:
    path = n if os.path.exists(n) else os.path.join(ROOT, 'assets', 'models', n + '.glb')
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    bpy.context.view_layer.update()
    mn = Vector((1e9, 1e9, 1e9))
    mx = Vector((-1e9, -1e9, -1e9))
    for o in new:
        if o.type == 'MESH':
            for c in o.bound_box:
                w = o.matrix_world @ Vector(c)
                mn = Vector((min(mn.x, w.x), min(mn.y, w.y), min(mn.z, w.z)))
                mx = Vector((max(mx.x, w.x), max(mx.y, w.y), max(mx.z, w.z)))
    shift = x - mn.x
    for o in new:
        if o.parent is None:
            o.location.x += shift
    lo = Vector((min(lo.x, mn.x + shift), min(lo.y, mn.y), min(lo.z, mn.z)))
    hi = Vector((max(hi.x, mx.x + shift), max(hi.y, mx.y), max(hi.z, mx.z)))
    x += (mx.x - mn.x) + 0.25 * max(0.3, mx.x - mn.x)
c = (lo + hi) * 0.5
size = max((hi - lo).length, 0.05)
# podłoże i światła
bpy.ops.mesh.primitive_plane_add(size=size * 8, location=(c.x, c.y, lo.z - 0.0005))
gm = bpy.data.materials.new('ziemia')
gm.use_nodes = True
gm.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (0.32, 0.33, 0.34, 1)
gm.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = 0.9
bpy.context.object.data.materials.append(gm)
for (dx, dy, dz, e, col) in ((1.2, -1.4, 1.6, 4.0, (1, 0.96, 0.9)), (-1.6, -0.6, 0.9, 1.6, (0.8, 0.88, 1.0)), (0.2, 1.6, 1.2, 1.2, (1, 1, 1))):
    ld = bpy.data.lights.new('s', 'SUN')
    ld.energy = e
    ld.color = col
    lo_ = bpy.data.objects.new('s', ld)
    bpy.context.scene.collection.objects.link(lo_)
    lo_.location = (c.x + dx, c.y + dy, c.z + dz)
    d = Vector((-dx, -dy, -dz))
    lo_.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
world = bpy.data.worlds.new('w')
world.use_nodes = True
world.node_tree.nodes['Background'].inputs[0].default_value = (0.55, 0.6, 0.68, 1)
world.node_tree.nodes['Background'].inputs[1].default_value = 0.6
bpy.context.scene.world = world
az = math.radians(opt.get('az', 35.0))
el = math.radians(opt.get('el', 18.0))
dist = size * 2.1 / opt.get('zoom', 1.0)
cam_d = bpy.data.cameras.new('k')
cam_d.lens = 55
cam = bpy.data.objects.new('k', cam_d)
bpy.context.scene.collection.objects.link(cam)
cam.location = (c.x + math.sin(az) * math.cos(el) * dist, c.y - math.cos(az) * math.cos(el) * dist, c.z + math.sin(el) * dist)
cam.rotation_euler = (c - cam.location).to_track_quat('-Z', 'Y').to_euler()
sc = bpy.context.scene
sc.camera = cam
sc.render.engine = 'BLENDER_EEVEE_NEXT' if 'BLENDER_EEVEE_NEXT' in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE'
sc.render.resolution_x = int(opt.get('w', 960))
sc.render.resolution_y = int(opt.get('h', 540))
sc.render.filepath = out
sc.view_settings.view_transform = 'Standard'
bpy.ops.render.render(write_still=True)
print('PODGLAD', out)
