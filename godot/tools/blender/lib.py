"""Wspólne klocki do modeli robionych w Blenderze (uruchamiane bez okna):
   /Applications/Blender.app/Contents/MacOS/Blender -b --python tools/blender/make_grow.py
Każdy skrypt czyści scenę, buduje model z brył (toczenie profilu, zaokrąglone pudełka, rurki) i zapisuje GLB
do assets/models/. Jednostki: metry, oś Z w górę (eksport zamienia na Y w górę dla Godota)."""
import bpy, bmesh, math, os
from mathutils import Vector, Matrix

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, 'assets', 'models')
_mats = {}


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats.clear()


def mat(name, color, rough=0.7, metal=0.0, emit=0.0, alpha=1.0):
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    c = color if isinstance(color, tuple) else tuple(int(color[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    c = tuple(pow(v, 2.2) for v in c)          # kolory podawane jak na ekranie (sRGB)
    b.inputs['Base Color'].default_value = (*c, 1.0)
    b.inputs['Roughness'].default_value = rough
    b.inputs['Metallic'].default_value = metal
    if emit > 0.0:
        b.inputs['Emission Color'].default_value = (*c, 1.0)
        b.inputs['Emission Strength'].default_value = emit
    if alpha < 1.0:
        b.inputs['Alpha'].default_value = alpha
        m.blend_method = 'BLEND'
    _mats[name] = m
    return m


def _finish(me, name, material, smooth=True, parent=None):
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    if material is not None:
        me.materials.append(material)
    if smooth:
        for p in me.polygons:
            p.use_smooth = True
    if parent is not None:
        ob.parent = parent
    return ob


def empty(name, loc=(0, 0, 0), parent=None):
    ob = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(ob)
    ob.location = loc
    if parent is not None:
        ob.parent = parent
    return ob


def lathe(name, profile, material, segs=32, parent=None, loc=(0, 0, 0), cap_top=False, cap_bottom=False):
    """bryła obrotowa: profile = [(promień, wysokość), ...] od dołu do góry"""
    bm = bmesh.new()
    rings = []
    for r, z in profile:
        rings.append([bm.verts.new((math.cos(2 * math.pi * i / segs) * r, math.sin(2 * math.pi * i / segs) * r, z)) for i in range(segs)])
    for a, b in zip(rings[:-1], rings[1:]):
        for i in range(segs):
            j = (i + 1) % segs
            bm.faces.new((a[i], a[j], b[j], b[i]))
    if cap_bottom:
        bm.faces.new(list(reversed(rings[0])))
    if cap_top:
        bm.faces.new(rings[-1])
    bm.normal_update()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = _finish(me, name, material, True, parent)
    ob.location = loc
    return ob


def rbox(name, size, material, bevel=0.01, loc=(0, 0, 0), rot=(0, 0, 0), parent=None, segs=3):
    """pudełko z zaokrąglonymi krawędziami"""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    if bevel > 0.0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=min(bevel, min(size) * 0.45), segments=segs, profile=0.5, affect='EDGES')
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = _finish(me, name, material, True, parent)
    ob.location = loc
    ob.rotation_euler = rot
    return ob


def tube(name, pts, radius, material, segs=10, parent=None, taper=None):
    """rurka wzdłuż łamanej (uchwyty, dzióbki, przewody); taper = promień na końcu"""
    cu = bpy.data.curves.new(name, 'CURVE')
    cu.dimensions = '3D'
    cu.bevel_depth = radius
    cu.bevel_resolution = max(1, segs // 4)
    cu.use_fill_caps = True
    sp = cu.splines.new('BEZIER' if len(pts) > 2 else 'POLY')
    if sp.type == 'POLY':
        sp.points.add(len(pts) - 1)
        for i, p in enumerate(pts):
            sp.points[i].co = (*p, 1.0)
            if taper is not None:
                sp.points[i].radius = 1.0 + (taper / radius - 1.0) * i / (len(pts) - 1)
    else:
        sp.bezier_points.add(len(pts) - 1)
        for i, p in enumerate(pts):
            bp = sp.bezier_points[i]
            bp.co = p
            bp.handle_left_type = bp.handle_right_type = 'AUTO'
            if taper is not None:
                bp.radius = 1.0 + (taper / radius - 1.0) * i / (len(pts) - 1)
    ob = bpy.data.objects.new(name, cu)
    bpy.context.scene.collection.objects.link(ob)
    cu.materials.append(material)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    bpy.data.objects.remove(ob)
    return _finish(me, name, material, True, parent)


def join(name, objs, parent=None):
    """skleja części o różnych materiałach w jeden obiekt (mniej rysowań w grze)"""
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    ob.data.name = name
    if parent is not None:
        ob.parent = parent
    return ob


def export(name):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + '.glb')
    for o in bpy.context.scene.objects:
        if o.type == 'MESH':
            # ostre krawędzie zostają ostre, reszta gładka
            mod = o.modifiers.new('wn', 'WEIGHTED_NORMAL')
            mod.keep_sharp = True
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', export_apply=True, export_yup=True, use_selection=False, export_materials='EXPORT')
    tris = sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type == 'MESH')
    print('MODEL %s  ok. %d ścian  -> %s' % (name, tris, os.path.relpath(path, ROOT)))
