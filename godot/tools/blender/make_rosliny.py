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
    bloom = mat('kwiat', '4e633c', 0.97)
    parts = [tube('Glowna lodyga', [(0,0,0), (0.015,0.01,0.4), (-0.006,0.005,0.75), (0,0,1.0)], 0.009, stem, 7, taper=[1,0.75,0.45,0.1])]
    def fan(base, angle, length, fingers, tilt):
        for finger in range(fingers):
            off = (finger-(fingers-1)/2)*0.36
            leaf_length = length*(1-abs(off)*0.48)*rnd.uniform(0.94,1.06)
            parts.append(blade('Lisc',base,angle+off,leaf_length,0.025 if stage>1 else 0.021,
                               leaf if rnd.random()>0.28 else underside,tilt+rnd.uniform(-0.1,0.1)))
    levels = 2 if stage==1 else (7 if stage==2 else 9)
    for level in range(levels):
        height = 0.16+level*(0.68/max(1,levels-1))
        for arm in range(2):
            angle = level*1.57+arm*math.pi+rnd.uniform(-0.24,0.24)
            envelope = math.sin((0.2+level/levels*0.7)*math.pi)
            extent = (0.11 if stage==1 else 0.27)*envelope
            base = Vector((math.cos(angle)*extent,math.sin(angle)*extent,height+0.07))
            midpoint = Vector((base.x*0.6,base.y*0.6,height+0.025))
            parts.append(tube('Galaz',[(0,0,height),tuple(midpoint),tuple(base)],0.004,stem,6,taper=[1,0.7,0.25]))
            fingers = 3 if stage==1 else (5 if level==levels-1 else 7)
            length = (0.13 if stage==1 else 0.24)*(1-level/levels*0.38)
            fan(base,angle,length,fingers,rnd.uniform(-0.18,0.16))
            if stage>1 and level<levels-1:
                # Liście na bocznych pędach wypełniają koronę zamiast odsłaniać sam pień.
                for side in [-1,1]:
                    secondary = angle+side*0.9
                    tip = midpoint+Vector((math.cos(secondary)*0.075,math.sin(secondary)*0.075,0.045))
                    parts.append(tube('Ped boczny',[tuple(midpoint),tuple(tip)],0.0023,stem,5,taper=[1,0.25]))
                    fan(tip,secondary,length*0.66,5,rnd.uniform(-0.05,0.3))
            if stage==3 and level>5:
                # Nieregularne skupiska, bez jednolitego kształtu stożka.
                for floret in range(3):
                    offset = Vector((rnd.uniform(-0.016,0.016),rnd.uniform(-0.016,0.016),floret*0.025))
                    parts.append(lathe('Kwiatostan',[(0,0),(0.012,0.012),(0.015,0.026),(0.009,0.040),(0,0.049)],bloom,7,
                                       loc=tuple(Vector((base.x*0.85,base.y*0.85,base.z))+offset)))
    if stage==3:
        for crown in range(3):
            parts.append(lathe('Szczyt',[(0,0),(0.017,0.015),(0.020,0.032),(0.011,0.052),(0,0.07)],bloom,8,
                               loc=(rnd.uniform(-0.014,0.014),rnd.uniform(-0.014,0.014),0.82+crown*0.026)))
    model = join('Roslina', parts)
    weather([model], 1024, 0.06, 0.02, samples=8)
    export('roslina_%d' % stage)

for stage in (1, 2, 3): plant(stage)
