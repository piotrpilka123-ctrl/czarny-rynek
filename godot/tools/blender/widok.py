"""Widok z gry bez okna: renderuje wycinek świata wyeksportowany przez grę (--glb) z kamery gracza.
Użycie: Blender -b --python tools/blender/widok.py -- swiat.glb wynik.png x y z yaw pitch [fov=75] [w=960] [h=540]
Współrzędne i kąty jak w grze (metry świata, Y w górę; yaw 0 patrzy na −z, 90 na −x; pitch w górę dodatni)."""
import sys, math
import bpy
from mathutils import Vector

a = sys.argv[sys.argv.index('--') + 1:]
kw = dict(v.split('=', 1) for v in a if '=' in v)      # cel=x,y,z (patrz na punkt), wnetrze=1 (światło w pokoju)
a = [v for v in a if '=' not in v]
glb, out = a[0], a[1]
x, y, z, yaw, pitch = [float(v) for v in a[2:7]]
fov = float(a[7]) if len(a) > 7 else 75.0
w = int(a[8]) if len(a) > 8 else 960
h = int(a[9]) if len(a) > 9 else 540
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
sc = bpy.context.scene
cd = bpy.data.cameras.new('k')
cd.sensor_fit = 'VERTICAL'
cd.angle = math.radians(fov)
cd.clip_start = 0.02
cd.clip_end = 900.0
cam = bpy.data.objects.new('k', cd)
sc.collection.objects.link(cam)
cam.location = (x, -z, y)
yr, pr = math.radians(yaw), math.radians(pitch)
f = Vector((-math.sin(yr) * math.cos(pr), math.cos(yr) * math.cos(pr), math.sin(pr)))
if 'cel' in kw:
    tx, ty, tz = [float(v) for v in kw['cel'].split(',')]
    f = Vector((tx - x, -(tz - z), ty - y))
cam.rotation_euler = f.to_track_quat('-Z', 'Y').to_euler()
sc.camera = cam
inside = 'wnetrze' in kw
if inside:
    # we wnętrzu słońce nie ma jak wpaść: lampa pod sufitem i druga przy kamerze
    for (px, py, pz, e) in ((x, -z, y + 1.6, 220.0), (x + 0.6, -z - 0.8, 2.2, 160.0)):
        pd = bpy.data.lights.new('p', 'POINT')
        pd.energy = e
        pd.shadow_soft_size = 0.3
        po = bpy.data.objects.new('p', pd)
        po.location = (px, py, pz)
        sc.collection.objects.link(po)
for (e, rot) in ((3.2, (math.radians(52), 0, math.radians(35))), (0.5, (math.radians(60), 0, math.radians(215)))):
    if inside:
        break
    ld = bpy.data.lights.new('s', 'SUN')
    ld.energy = e
    lo = bpy.data.objects.new('s', ld)
    lo.rotation_euler = rot
    sc.collection.objects.link(lo)
world = bpy.data.worlds.new('w')
world.use_nodes = True
world.node_tree.nodes['Background'].inputs[0].default_value = (0.55, 0.65, 0.8, 1)
world.node_tree.nodes['Background'].inputs[1].default_value = 0.9
sc.world = world
sc.render.engine = 'BLENDER_EEVEE_NEXT' if 'BLENDER_EEVEE_NEXT' in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties['engine'].enum_items] else 'BLENDER_EEVEE'
sc.render.resolution_x = w
sc.render.resolution_y = h
sc.render.filepath = out
sc.view_settings.view_transform = 'Standard'
bpy.ops.render.render(write_still=True)
print('WIDOK', out)
