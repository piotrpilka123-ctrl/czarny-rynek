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


def mat(name, color, rough=0.7, metal=0.0, emit=0.0, alpha=1.0, wzor=''):
    """wzor: faktura wypalana razem z brudem (weather) — 'sztruks', 'drewno', 'karton', 'beton', 'tkanina', 'cegla'"""
    if name in _mats:
        return _mats[name]
    m = bpy.data.materials.new(name)
    if wzor:
        m['wzor'] = wzor
    m.use_nodes = True
    b = m.node_tree.nodes['Principled BSDF']
    c = color if isinstance(color, tuple) else tuple(int(color[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    # żadnej idealnej czerni: najciemniejszy kolor modelu to ciemny grafit (świecących materiałów to nie dotyczy)
    if emit <= 0.0 and max(c[:3]) < 0.105:
        add = 0.105 - max(c[:3])
        c = tuple(v + add for v in c[:3])
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


def profile(name, pts, depth, material, bevel=0.003, parent=None, holes=()):
    """płaski kształt z boku (lista punktów X,Z) wyciągnięty na grubość `depth` wzdłuż Y — do sylwetek (broń, narzędzia)"""
    cu = bpy.data.curves.new(name, 'CURVE')
    cu.dimensions = '2D'
    cu.fill_mode = 'BOTH'
    cu.extrude = max(0.0005, depth * 0.5 - bevel)
    cu.bevel_depth = bevel
    cu.bevel_resolution = 2
    for loop in (pts,) + tuple(holes):
        sp = cu.splines.new('POLY')
        sp.points.add(len(loop) - 1)
        for i, (x, z) in enumerate(loop):
            sp.points[i].co = (x, z, 0.0, 1.0)
        sp.use_cyclic_u = True
    ob = bpy.data.objects.new(name, cu)
    bpy.context.scene.collection.objects.link(ob)
    cu.materials.append(material)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    bpy.data.objects.remove(ob)
    out = _finish(me, name, material, True, parent)
    out.rotation_euler = (math.radians(90), 0, 0)      # płaszczyzna XY krzywej -> XZ modelu
    return out


def sheet(name, w, h, nx, ny, fn, material, parent=None, loc=(0, 0, 0)):
    """tkanina: stojący prostokąt w×h (płaszczyzna XZ, dół na z=0) przesuwany funkcją fn(u, v) -> (dx, dy, dz)"""
    bm = bmesh.new()
    rows = []
    for j in range(ny + 1):
        row = []
        for i in range(nx + 1):
            u, v = i / nx, j / ny
            dx, dy, dz = fn(u, v)
            row.append(bm.verts.new((-w / 2 + u * w + dx, dy, v * h + dz)))
        rows.append(row)
    for j in range(ny):
        for i in range(nx):
            bm.faces.new((rows[j][i], rows[j][i + 1], rows[j + 1][i + 1], rows[j + 1][i]))
    bm.normal_update()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = _finish(me, name, material, True, parent)
    ob.location = loc
    return ob


def text(name, body, size, material, loc=(0, 0, 0), rot=(math.radians(90), 0, 0), depth=0.0008, parent=None, align='CENTER'):
    """napis jako płaska siatka (etykiety, tabliczki); domyślnie stoi pionowo, czytany od strony −Y"""
    cu = bpy.data.curves.new(name, 'FONT')
    cu.body = body
    cu.size = size
    cu.extrude = depth
    cu.align_x = align
    cu.align_y = 'CENTER'
    ob = bpy.data.objects.new(name, cu)
    bpy.context.scene.collection.objects.link(ob)
    cu.materials.append(material)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    bpy.data.objects.remove(ob)
    out = _finish(me, name, material, False, parent)
    out.location = loc
    out.rotation_euler = rot
    return out


def bolts(prefix, pts, material, r=0.008, h=0.006, axis='Z'):
    """rząd łbów śrub w podanych punktach (drobny detal, który łamie gładkie powierzchnie)"""
    out = []
    for i, p in enumerate(pts):
        b = lathe('%s%d' % (prefix, i), [(0.0, 0.0), (r, 0.0), (r, h * 0.7), (r * 0.6, h), (0.0, h)], material, 6)
        b.location = p
        if axis == 'Y':
            b.rotation_euler = (math.radians(90), 0, 0)
        elif axis == '-Y':
            b.rotation_euler = (math.radians(-90), 0, 0)
        elif axis == 'X':
            b.rotation_euler = (0, math.radians(90), 0)
        out.append(b)
    return out


def wz(color, kind):
    """Kolor bazowy, po którym faktura `kind` wypali się na zadany kolor (szesnastkowo, jak na ekranie).
    Faktury mnożą przez siebie kilka pasm o barwie bazowej (drewno i tkanina trzy, beton, karton i cegła dwa),
    więc wypalony kolor to baza do potęgi i ciemne kolory wychodzą bez tej poprawki prawie czarne.
    Starsze modele mają kolory dobrane na oko pod ten efekt — dlatego samych faktur nie zmieniam."""
    n = {'drewno': 3, 'tkanina': 3, 'karton': 2, 'beton': 2, 'cegla': 2}.get(kind, 1)
    c = tuple(int(color[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    return tuple(pow(min(1.0, pow(pow(v, 2.2) / 0.86, 1.0 / n)), 1 / 2.2) for v in c)


def _pattern(nt, kind, base):
    """faktura materiału jako kolor (wyjście węzła) albo None: prążki sztruksu, słoje drewna, żeberka kartonu, pory betonu, splot tkaniny"""
    if not kind:
        return None
    N = nt.nodes
    L = nt.links
    tc = N.new('ShaderNodeTexCoord')

    def shade(fac_out, lo, hi, p0=0.3, p1=0.7):
        r = N.new('ShaderNodeValToRGB')
        r.color_ramp.elements[0].position = p0
        r.color_ramp.elements[0].color = (*[c * lo for c in base[:3]], 1)
        r.color_ramp.elements[1].position = p1
        r.color_ramp.elements[1].color = (*[min(1.0, c * hi) for c in base[:3]], 1)
        L.new(fac_out, r.inputs['Fac'])
        return r.outputs['Color']

    def wave(direction, scale, dist=0.0, detail=0.0):
        w = N.new('ShaderNodeTexWave')
        w.wave_type = 'BANDS'
        w.bands_direction = direction
        w.inputs['Scale'].default_value = scale
        w.inputs['Distortion'].default_value = dist
        w.inputs['Detail'].default_value = detail
        L.new(tc.outputs['Object'], w.inputs['Vector'])
        return w.outputs['Fac']

    def noise(scale, detail=4.0):
        n = N.new('ShaderNodeTexNoise')
        n.inputs['Scale'].default_value = scale
        n.inputs['Detail'].default_value = detail
        L.new(tc.outputs['Object'], n.inputs['Vector'])
        return n.outputs['Fac']

    def mul(a, b):
        m = N.new('ShaderNodeMixRGB')
        m.blend_type = 'MULTIPLY'
        m.inputs['Fac'].default_value = 1.0
        L.new(a, m.inputs['Color1'])
        L.new(b, m.inputs['Color2'])
        return m.outputs['Color']

    if kind == 'sztruks':
        # prążki co ok. centymetr i wyleżane, jaśniejsze placki
        ribs = shade(wave('X', 95.0, 0.4, 1.0), 0.72, 1.12)
        wornp = N.new('ShaderNodeValToRGB')
        wornp.color_ramp.elements[0].position = 0.42
        wornp.color_ramp.elements[0].color = (0.8, 0.8, 0.8, 1)
        wornp.color_ramp.elements[1].position = 0.75
        wornp.color_ramp.elements[1].color = (1.25, 1.2, 1.15, 1)
        L.new(noise(4.5, 3.0), wornp.inputs['Fac'])
        return mul(ribs, wornp.outputs['Color'])
    if kind == 'tkanina':
        a = shade(wave('X', 150.0), 0.8, 1.1)
        b = shade(wave('Z', 150.0), 0.8, 1.1)
        return mul(a, mul(b, shade(noise(7.0, 3.0), 0.95, 1.15)))
    if kind == 'drewno':
        # słoje: pasma mocno zniekształcone szumem, do tego sęki i przebarwienia
        g1 = shade(wave('Y', 16.0, 7.0, 3.0), 0.62, 1.08, 0.25, 0.8)
        g2 = shade(wave('X', 16.0, 7.0, 3.0), 0.8, 1.05, 0.3, 0.8)
        return mul(mul(g1, g2), shade(noise(2.5, 2.0), 0.95, 1.2))
    if kind == 'karton':
        ribs = shade(wave('Z', 210.0), 0.9, 1.04)
        return mul(ribs, shade(noise(5.0, 4.0), 0.86, 1.12))
    if kind == 'beton':
        pores = shade(noise(160.0, 2.0), 0.7, 1.08, 0.35, 0.55)
        return mul(pores, shade(noise(3.0, 5.0), 0.82, 1.15))
    if kind == 'cegla':
        # cegły 25 × 6,5 cm ze spoiną, w wiązaniu wozówkowym; współrzędna pozioma = x + y, więc wzór trzyma się ścian obu kierunków
        sep = N.new('ShaderNodeSeparateXYZ')
        L.new(tc.outputs['Object'], sep.inputs['Vector'])
        add = N.new('ShaderNodeMath')
        add.operation = 'ADD'
        L.new(sep.outputs['X'], add.inputs[0])
        L.new(sep.outputs['Y'], add.inputs[1])
        comb = N.new('ShaderNodeCombineXYZ')
        L.new(add.outputs[0], comb.inputs['X'])
        L.new(sep.outputs['Z'], comb.inputs['Y'])
        br = N.new('ShaderNodeTexBrick')
        br.offset = 0.5
        br.inputs['Scale'].default_value = 1.0
        br.inputs['Mortar Size'].default_value = 0.014
        br.inputs['Mortar Smooth'].default_value = 0.1
        br.inputs['Bias'].default_value = 0.0
        br.inputs['Brick Width'].default_value = 0.262
        br.inputs['Row Height'].default_value = 0.079
        br.inputs['Color1'].default_value = (*[c * 0.72 for c in base[:3]], 1)
        br.inputs['Color2'].default_value = (*[min(1.0, c * 1.15) for c in base[:3]], 1)
        br.inputs['Mortar'].default_value = (0.36, 0.34, 0.31, 1)
        L.new(comb.outputs['Vector'], br.inputs['Vector'])
        return mul(br.outputs['Color'], shade(noise(2.0, 4.0), 0.82, 1.12))
    return None


def weather(objs, size=1024, dirt=0.55, wear=0.5, grime=(0.09, 0.075, 0.06), samples=24):
    """Zużycie zamiast „plasteliny”: każdy obiekt dostaje jedną teksturę koloru wypaloną z materiałów —
    brud w zakamarkach (AO), wytarte krawędzie, plamy i zacieki z szumu. Metaliczność i chropowatość zostają liczbami."""
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = samples
    sc.render.bake.use_pass_direct = False
    sc.render.bake.use_pass_indirect = False
    sc.render.bake.use_pass_color = True
    sc.render.bake.margin = 6
    for ob in objs:
        if ob.type != 'MESH':
            continue
        for o in bpy.context.selected_objects:
            o.select_set(False)
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.object.mode_set(mode='EDIT')
        bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
        bpy.ops.object.mode_set(mode='OBJECT')
        img = bpy.data.images.new(ob.name + '_kolor', size, size)
        rough = []
        metal = []
        for slot in ob.material_slots:
            m = slot.material.copy()
            slot.material = m
            nt = m.node_tree
            b = nt.nodes['Principled BSDF']
            base = tuple(b.inputs['Base Color'].default_value)
            rough.append(b.inputs['Roughness'].default_value)
            metal.append(b.inputs['Metallic'].default_value)
            emit = b.inputs['Emission Strength'].default_value > 0.0
            N = nt.nodes
            L = nt.links
            ao = N.new('ShaderNodeAmbientOcclusion')
            ao.inputs['Distance'].default_value = 0.05
            ao.samples = 8
            geo = N.new('ShaderNodeNewGeometry')
            n1 = N.new('ShaderNodeTexNoise')
            n1.inputs['Scale'].default_value = 9.0
            n1.inputs['Detail'].default_value = 6.0
            n2 = N.new('ShaderNodeTexNoise')
            n2.inputs['Scale'].default_value = 70.0
            n2.inputs['Detail'].default_value = 3.0
            # 1) drobna nierówność koloru
            mix1 = N.new('ShaderNodeMixRGB')
            mix1.blend_type = 'MULTIPLY'
            mix1.inputs['Fac'].default_value = 0.0 if emit else 0.35
            mix1.inputs['Color1'].default_value = base
            pat = _pattern(nt, m.get('wzor', ''), base) if not emit else None
            if pat is not None:
                L.new(pat, mix1.inputs['Color1'])
            ramp2 = N.new('ShaderNodeValToRGB')
            ramp2.color_ramp.elements[0].position = 0.3
            ramp2.color_ramp.elements[0].color = (0.55, 0.55, 0.55, 1)
            ramp2.color_ramp.elements[1].position = 0.75
            L.new(n2.outputs['Fac'], ramp2.inputs['Fac'])
            L.new(ramp2.outputs['Color'], mix1.inputs['Color2'])
            # 2) brud: zakamarki (AO) + duże plamy
            dramp = N.new('ShaderNodeValToRGB')
            dramp.color_ramp.elements[0].position = 0.45
            dramp.color_ramp.elements[1].position = 0.95
            L.new(ao.outputs['AO'], dramp.inputs['Fac'])
            pramp = N.new('ShaderNodeValToRGB')
            pramp.color_ramp.elements[0].position = 0.5
            pramp.color_ramp.elements[1].position = 0.72
            L.new(n1.outputs['Fac'], pramp.inputs['Fac'])
            dmask = N.new('ShaderNodeMath')
            dmask.operation = 'MULTIPLY'
            inv = N.new('ShaderNodeInvert')
            L.new(pramp.outputs['Color'], inv.inputs['Color'])
            L.new(dramp.outputs['Color'], dmask.inputs[0])
            L.new(inv.outputs['Color'], dmask.inputs[1])
            mix2 = N.new('ShaderNodeMixRGB')
            mix2.inputs['Color1'].default_value = (*grime, 1)
            L.new(dmask.outputs['Value'], mix2.inputs['Fac'])
            L.new(mix1.outputs['Color'], mix2.inputs['Color2'])
            fade = N.new('ShaderNodeMixRGB')
            fade.inputs['Fac'].default_value = 0.0 if emit else dirt
            L.new(mix1.outputs['Color'], fade.inputs['Color1'])
            L.new(mix2.outputs['Color'], fade.inputs['Color2'])
            # 3) wytarte krawędzie: jaśniejszy podkład tam, gdzie siatka jest wypukła
            wr = N.new('ShaderNodeValToRGB')
            wr.color_ramp.elements[0].position = 0.57
            wr.color_ramp.elements[1].position = 0.7
            L.new(geo.outputs['Pointiness'], wr.inputs['Fac'])
            wn = N.new('ShaderNodeMath')
            wn.operation = 'MULTIPLY'
            L.new(wr.outputs['Color'], wn.inputs[0])
            L.new(n2.outputs['Fac'], wn.inputs[1])
            wm = N.new('ShaderNodeMath')
            wm.operation = 'MULTIPLY'
            wm.inputs[1].default_value = 0.0 if emit else wear * 1.1
            L.new(wn.outputs['Value'], wm.inputs[0])
            edge = N.new('ShaderNodeMixRGB')
            lum = 0.3 * base[0] + 0.5 * base[1] + 0.2 * base[2]
            worn = tuple(min(1.0, c * 1.5 + (0.1 if lum < 0.25 else 0.06)) for c in base[:3])
            edge.inputs['Color2'].default_value = (*worn, 1)
            L.new(wm.outputs['Value'], edge.inputs['Fac'])
            L.new(fade.outputs['Color'], edge.inputs['Color1'])
            L.new(edge.outputs['Color'], b.inputs['Base Color'])
            b.inputs['Metallic'].default_value = 0.0      # wypalanie koloru nie znosi metalu
            tex = N.new('ShaderNodeTexImage')
            tex.image = img
            N.active = tex
        bpy.ops.object.bake(type='DIFFUSE')
        img.pack()
        # jeden prosty materiał z wypaloną teksturą
        mats = [s.material for s in ob.material_slots]
        emis = [m for m in mats if m.node_tree.nodes['Principled BSDF'].inputs['Emission Strength'].default_value > 0.0]
        final = bpy.data.materials.new(ob.name + '_mat')
        final.use_nodes = True
        fb = final.node_tree.nodes['Principled BSDF']
        ft = final.node_tree.nodes.new('ShaderNodeTexImage')
        ft.image = img
        final.node_tree.links.new(ft.outputs['Color'], fb.inputs['Base Color'])
        fb.inputs['Roughness'].default_value = min(0.95, sum(rough) / len(rough) + 0.12)
        fb.inputs['Metallic'].default_value = min(0.6, max(metal) * 0.6)
        if emis:
            eb = emis[0].node_tree.nodes['Principled BSDF']
            final.node_tree.links.new(ft.outputs['Color'], fb.inputs['Emission Color'])
            fb.inputs['Emission Strength'].default_value = eb.inputs['Emission Strength'].default_value
        ob.data.materials.clear()
        ob.data.materials.append(final)
        for p in ob.data.polygons:
            p.material_index = 0


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
