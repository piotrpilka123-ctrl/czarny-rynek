"""Widok z gry bez okna: renderuje wycinek świata wyeksportowany przez grę (--glb) z kamery gracza.
Użycie: Blender -b --python tools/blender/widok.py -- swiat.glb wynik.png x y z yaw pitch [fov=75] [w=960] [h=540]
Współrzędne i kąty jak w grze (metry świata, Y w górę; yaw 0 patrzy na −z, 90 na −x; pitch w górę dodatni)."""
import sys, math
import bpy
from mathutils import Vector

a = sys.argv[sys.argv.index('--') + 1:]
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
cd.clip_start = 0.05
cd.clip_end = 900.0
cam = bpy.data.objects.new('k', cd)
sc.collection.objects.link(cam)
cam.location = (x, -z, y)
yr, pr = math.radians(yaw), math.radians(pitch)
f = Vector((-math.sin(yr) * math.cos(pr), math.cos(yr) * math.cos(pr), math.sin(pr)))
cam.rotation_euler = f.to_track_quat('-Z', 'Y').to_euler()
sc.camera = cam
for (e, rot) in ((3.2, (math.radians(52), 0, math.radians(35))), (0.5, (math.radians(60), 0, math.radians(215)))):
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
