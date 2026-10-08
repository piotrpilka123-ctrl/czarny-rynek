"""Trzy lekkie modele roślin: łodygi, gałązki, składane liście i kwiatostany.
Zastępują skrzyżowane karty. Wysokość znormalizowana; gra skaluje wzrost.
"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
from lib import _finish


def blade(name, base, angle, length, width, material, tilt=0.0):
    forward = Vector((math.cos(angle), math.sin(angle), tilt)).normalized()
    side = Vector((-math.sin(angle), math.cos(angle), 0))
    vertices, faces, rows = [], [], []
    for step in range(9):
        t = step / 8
        center = Vector(base) + forward * length * t
        center.z += math.sin(t * math.pi) * length * 0.075 - t*t*length*0.12
        w = width * math.sin(t * math.pi)**0.85 * (1.08 if step % 2 else 0.86)
        if step in (0, 8):
            index = len(vertices); vertices.append(tuple(center)); rows.append((index, index, index))
        else:
            start = len(vertices)
            vertices.extend([tuple(center - side*w - Vector((0, 0, w*0.15))), tuple(center + Vector((0, 0, w*0.09))), tuple(center + side*w - Vector((0, 0, w*0.15)))])
            rows.append((start, start+1, start+2))
    for previous, current in zip(rows[:-1], rows[1:]):
        for tri in [(previous[1], previous[0], current[0]), (previous[1], current[0], current[1]), (previous[1], current[1], current[2]), (previous[1], current[2], previous[2])]:
            if len(set(tri)) == 3: faces.append(tri)
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    return _finish(mesh, name, material, False, None)


def plant(stage):
    reset()
    rnd = random.Random(170 + stage)
    stem = mat('lodyga', '6e8451', 0.9)
    leaf = mat('lisc', '44723a', 0.9)
    underside = mat('lisc_jasny', '597c43', 0.93)
    bloom = mat('kwiat', '71804b', 0.97)
    parts = [tube('Glowna lodyga', [(0,0,0), (0.015,0.01,0.4), (-0.006,0.005,0.75), (0,0,1.0)], 0.009, stem, 7, taper=[1,0.75,0.45,0.1])]
    levels = 2 if stage == 1 else (5 if stage == 2 else 7)
    for level in range(levels):
        height = 0.32 + level * (0.48 / max(1, levels-1))
        for arm in range(2):
            angle = level*2.1 + arm*math.pi + rnd.uniform(-0.16, 0.16)
            extent = (0.14 if stage == 1 else 0.24) * (1.0 - level/levels*0.3)
            base = Vector((math.cos(angle)*extent, math.sin(angle)*extent, height + 0.04))
            parts.append(tube('Galaz', [(0,0,height), tuple(base)], 0.004, stem, 6, taper=[1,0.3]))
            fingers = 3 if stage == 1 else (5 if stage == 2 else 7)
            for finger in range(fingers):
                off = (finger - (fingers-1)/2) * 0.24
                length = (0.16 if stage == 1 else 0.19) * (1-abs(off)*0.38)
                parts.append(blade('Lisc', base, angle+off, length, 0.018 if stage > 1 else 0.022, leaf if finger%3 else underside, rnd.uniform(-0.15, 0.12)))
            if stage == 3 and level > 2:
                parts.append(lathe('Kwiatostan', [(0,0), (0.015,0.01), (0.022,0.04), (0.018,0.065), (0.004,0.09), (0,0.095)], bloom, 7, loc=(base.x*0.85, base.y*0.85, base.z)))
    if stage == 3:
        parts.append(lathe('Szczyt', [(0,0), (0.02,0.02), (0.023,0.06), (0.01,0.1), (0,0.12)], bloom, 8, loc=(0,0,0.88)))
    model = join('Roslina', parts)
    weather([model], 1024, 0.06, 0.02, samples=8)
    export('roslina_%d' % stage)

for stage in (1, 2, 3): plant(stage)
