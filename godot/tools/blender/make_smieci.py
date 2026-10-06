"""Drobiazgi leżące na ziemi (każdy to jeden mały obiekt do rozsiewania setkami): zgnieciona puszka, butelka po piwie,
butelka PET, paczka po papierosach, gazeta, zmięta reklamówka, kubek po kawie, rozbite szkło, niedopałki, ulotka.
Spód na z = 0, wymiary prawdziwe."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
from lib import _finish
from mathutils import noise

R90 = math.radians(90)
rnd = random.Random(8)


def _gnieciony(name, r, material, sq, seed, sub=2):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1.0)
    for v in bm.verts:
        k = 1.0 + 0.45 * noise.noise(v.co * 2.4 + Vector((seed, seed * 0.3, 2.0)))
        v.co = Vector((v.co.x * r * k, v.co.y * r * k * 0.8, (v.co.z * 0.5 + 0.5) * r * 2.0 * sq * k))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return _finish(me, name, material, True, None)


def smiec_puszka():
    reset()
    alu = mat('alu', 'b9bcc0', 0.3, 0.8)
    col = mat('nadruk', 'b2301f', 0.4, 0.5)
    p = [lathe('plaszcz', [(0.0, 0.0), (0.03, 0.0), (0.033, 0.012), (0.026, 0.05), (0.031, 0.085), (0.027, 0.105), (0.0, 0.105)], col, 10)]
    p.append(lathe('denko', [(0.0, -0.001), (0.026, -0.001), (0.031, 0.01)], alu, 10))
    ob = join('Puszka', p)
    ob.rotation_euler = (R90, 0, 0)
    ob.location = (0, 0, 0.03)
    ob.scale = (1.0, 0.7, 1.0)        # przydepnięta
    export('smiec_puszka')


def smiec_butelka():
    reset()
    gl = mat('szklo_b', '4a2f16', 0.12, 0.2)
    p = [lathe('butelka', [(0.0, 0.0), (0.03, 0.0), (0.033, 0.01), (0.033, 0.15), (0.016, 0.2), (0.013, 0.245), (0.015, 0.25), (0.0, 0.25)], gl, 12)]
    p.append(lathe('etykieta', [(0.0335, 0.05), (0.0335, 0.12)], mat('etykieta', 'd9d2b6', 0.7), 12))
    ob = join('Butelka', p)
    ob.rotation_euler = (R90, 0, 0)
    ob.location = (0, 0.12, 0.033)
    export('smiec_butelka')


def smiec_pet():
    reset()
    pl = mat('pet', 'a8c8d8', 0.15, 0.0, 0.0, 0.45)
    p = [lathe('butelka', [(0.0, 0.0), (0.034, 0.0), (0.04, 0.02), (0.036, 0.09), (0.04, 0.16), (0.04, 0.2), (0.016, 0.255), (0.014, 0.28), (0.0, 0.28)], pl, 10)]
    p.append(lathe('nakretka', [(0.0, 0.28), (0.016, 0.28), (0.016, 0.3), (0.0, 0.3)], mat('nakretka', '2a56b0', 0.5), 8))
    p.append(lathe('etykieta', [(0.0405, 0.11), (0.0405, 0.17)], mat('etykieta_n', '2f6fc0', 0.5), 10))
    ob = join('Pet', p)
    ob.rotation_euler = (R90, 0, 0)
    ob.location = (0, 0.14, 0.04)
    ob.scale = (1.0, 0.8, 1.0)
    export('smiec_pet')


def smiec_paczka():
    reset()
    p = [rbox('paczka', (0.056, 0.088, 0.02), mat('paczka', 'e6e2d6', 0.6), 0.003, (0, 0, 0.012), (0.08, 0.05, 0), segs=1)]
    p.append(rbox('pas', (0.057, 0.03, 0.021), mat('pas', 'b22a20', 0.6), 0.003, (0, 0.02, 0.0125), (0.08, 0.05, 0), segs=1))
    p.append(rbox('wieczko', (0.056, 0.03, 0.004), mat('paczka', 'e6e2d6', 0.6), 0.0, (0, 0.058, 0.03), (0.9, 0.05, 0), segs=1))
    join('Paczka', p)
    export('smiec_paczka')


def smiec_gazeta():
    reset()
    pap = mat('papier', 'c9c4b4', 0.95)
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=8, y_segments=10, size=0.5)
    for v in bm.verts:
        x, y = v.co.x * 2, v.co.y * 2
        v.co = Vector((x * 0.15, y * 0.2, 0.004 + 0.012 * abs(noise.noise(Vector((x * 2.0, y * 2.0, 0.5)))) + (0.02 * max(0.0, x - 0.4))))
    me = bpy.data.meshes.new('Gazeta')
    bm.to_mesh(me)
    bm.free()
    g = _finish(me, 'gazeta', pap, True, None)
    sol = g.modifiers.new('g', 'SOLIDIFY')
    sol.thickness = 0.003
    p = [g]
    ink = mat('druk', '3a3a3c', 0.9)
    for k in range(6):
        p.append(rbox('szpalta', (0.11, 0.012, 0.0006), ink, 0.0, (-0.06, 0.15 - k * 0.055, 0.019), segs=1))
    p.append(rbox('zdjecie', (0.09, 0.07, 0.0006), mat('zdjecie', '6a6f74', 0.9), 0.0, (0.07, 0.1, 0.02), segs=1))
    join('Gazeta', p)
    export('smiec_gazeta')


def smiec_reklamowka():
    reset()
    _gnieciony('Reklamowka', 0.09, mat('folia', 'e8e6dc', 0.5), 0.45, 4.0)
    export('smiec_reklamowka')


def smiec_kubek():
    reset()
    p = [lathe('kubek', [(0.0, 0.0), (0.027, 0.0), (0.04, 0.11), (0.042, 0.112), (0.039, 0.113), (0.026, 0.004), (0.0, 0.004)], mat('kubek', 'ddd8cc', 0.8), 12)]
    p.append(lathe('opaska', [(0.031, 0.04), (0.0365, 0.085)], mat('opaska', '7a4a2a', 0.8), 12))
    ob = join('Kubek', p)
    ob.rotation_euler = (R90 * 0.97, 0, 0.3)
    ob.location = (0, 0.05, 0.036)
    export('smiec_kubek')


def smiec_szklo():
    reset()
    gl = mat('szklo_z', '3a6a44', 0.1, 0.2)
    p = []
    for k in range(9):
        a = rnd.uniform(0, 6.28)
        r = rnd.uniform(0.0, 0.11)
        s = rnd.uniform(0.012, 0.035)
        p.append(rbox('odlamek', (s, s * rnd.uniform(0.5, 1.0), 0.004), gl, 0.0, (math.cos(a) * r, math.sin(a) * r, 0.004), (rnd.uniform(-0.3, 0.3), rnd.uniform(-0.3, 0.3), a), segs=1))
    nk = lathe('szyjka', [(0.012, 0.0), (0.015, 0.0), (0.016, 0.05), (0.03, 0.09), (0.028, 0.09), (0.013, 0.05)], gl, 8)
    nk.rotation_euler = (R90, 0, 0.9)
    nk.location = (0.03, -0.02, 0.016)
    p.append(nk)
    join('Szklo', p)
    export('smiec_szklo')


def smiec_niedopalki():
    reset()
    p = []
    for k in range(7):
        a = rnd.uniform(0, 6.28)
        r = rnd.uniform(0.0, 0.09)
        b = rbox('filtr', (0.022, 0.0075, 0.0075), mat('filtr', 'c98a4a', 0.9), 0.003, (math.cos(a) * r, math.sin(a) * r, 0.004), (0, 0, rnd.uniform(0, 3.1)), segs=1)
        p.append(b)
        c = rbox('bibulka', (0.012, 0.007, 0.007), mat('bibulka', 'e4e0d4', 0.9), 0.003, (math.cos(a) * r, math.sin(a) * r, 0.004), (0, 0, b.rotation_euler[2]), segs=1)
        c.location.x += math.cos(b.rotation_euler[2]) * 0.016
        c.location.y += math.sin(b.rotation_euler[2]) * 0.016
        p.append(c)
    join('Niedopalki', p)
    export('smiec_niedopalki')


def smiec_ulotka():
    reset()
    p = [rbox('ulotka', (0.105, 0.148, 0.0012), mat('ulotka', 'd8c23a', 0.8), 0.0, (0, 0, 0.002), (0.03, 0.02, 0), segs=1)]
    p.append(rbox('napis', (0.08, 0.02, 0.0004), mat('druk_c', 'a02018', 0.8), 0.0, (0, 0.04, 0.0034), (0.03, 0.02, 0), segs=1))
    p.append(rbox('napis2', (0.07, 0.008, 0.0004), mat('druk', '2a2a2c', 0.8), 0.0, (0, 0.0, 0.0031), (0.03, 0.02, 0), segs=1))
    p.append(rbox('napis3', (0.07, 0.008, 0.0004), mat('druk', '2a2a2c', 0.8), 0.0, (0, -0.02, 0.003), (0.03, 0.02, 0), segs=1))
    join('Ulotka', p)
    export('smiec_ulotka')


only = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
for fn in (smiec_puszka, smiec_butelka, smiec_pet, smiec_paczka, smiec_gazeta, smiec_reklamowka, smiec_kubek, smiec_szklo, smiec_niedopalki, smiec_ulotka):
    if not only or fn.__name__ in only:
        fn()
