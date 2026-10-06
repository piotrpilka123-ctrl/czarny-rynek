"""Plac zabaw z blokowiska: piaskownica z betonowym obrzeżem, karuzela-talerz, huśtawka wagowa („ważka”),
drabinka łukowa i niski płotek. Stal malowana na żywe kolory, dawno nieodnawiana. Przód = −Y, spód na z = 0."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
from lib import _finish
from mathutils import noise

R90 = math.radians(90)
rnd = random.Random(31)


def plac_piaskownica():
    """piaskownica 3×3 m: betonowe obrzeże z wyszczerbieniami, deski-siedziska na dwóch bokach, pagórek piasku,
    wiaderko, łopatka i foremka"""
    reset()
    con = mat('beton', 'a9a59b', 0.92)
    wood = mat('deska', '8a6a44', 0.85)
    S = 3.0
    p = []
    for k, (cx, cy, w, d) in enumerate(((0, -S / 2, S, 0.22), (0, S / 2, S, 0.22), (-S / 2, 0, 0.22, S - 0.22), (S / 2, 0, 0.22, S - 0.22))):
        p.append(rbox('obrzeze', (w, d, 0.3), con, 0.025, (cx, cy, 0.13), segs=2))
    for (cx, cy, w, d) in ((0, -S / 2, S - 0.5, 0.26), (S / 2, 0, 0.26, S - 0.7)):
        p.append(rbox('siedzisko', (w, d, 0.035), wood, 0.008, (cx, cy, 0.3)))
    rim = join('Obrzeze', p)
    # piasek: pofalowana powierzchnia z pagórkiem i dołkiem
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=22, y_segments=22, size=(S - 0.22) / 2)
    for v in bm.verts:
        x, y = v.co.x, v.co.y
        h = 0.12 + 0.035 * noise.noise(Vector((x * 1.7, y * 1.7, 0.4))) + 0.012 * noise.noise(Vector((x * 6, y * 6, 2.0)))
        h += 0.2 * math.exp(-((x - 0.5) ** 2 + (y - 0.3) ** 2) / 0.12)       # babka z piasku
        h -= 0.07 * math.exp(-((x + 0.6) ** 2 + (y + 0.5) ** 2) / 0.1)      # wykopany dołek
        v.co.z = h
    me = bpy.data.meshes.new('Piasek')
    bm.to_mesh(me)
    bm.free()
    sand = _finish(me, 'Piasek', mat('piasek', 'c9b48a', 0.97), True, None)
    # zabawki zostawione w piasku
    red = mat('plastik_cz', 'c8352b', 0.5)
    yel = mat('plastik_z', 'e0b81e', 0.5)
    blue = mat('plastik_n', '2d6fc0', 0.5)
    t = [lathe('wiaderko', [(0.0, 0.0), (0.075, 0.0), (0.1, 0.17), (0.106, 0.17), (0.106, 0.178), (0.092, 0.178), (0.07, 0.012), (0.0, 0.012)], red, 14, loc=(-0.35, 0.45, 0.13))]
    t[-1].rotation_euler = (0.25, 0.1, 0)
    t.append(tube('palak', [(-0.45, 0.45, 0.3), (-0.4, 0.46, 0.38), (-0.3, 0.47, 0.38), (-0.25, 0.48, 0.3)], 0.005, yel, 5))
    t.append(rbox('lopatka', (0.07, 0.12, 0.012), yel, 0.01, (0.15, -0.5, 0.14), (0.15, 0, 0.6)))
    t.append(tube('trzonek', [(0.17, -0.44, 0.145), (0.27, -0.3, 0.16)], 0.009, yel, 6))
    t.append(lathe('foremka', [(0.0, 0.05), (0.05, 0.05), (0.065, 0.0), (0.07, 0.0), (0.055, 0.058), (0.0, 0.058)], blue, 5, loc=(0.75, 0.2, 0.14)))
    toys = join('Zabawki', t)
    weather([rim], 1024, 0.7, 0.75)
    export('plac_piaskownica')


def plac_karuzela():
    """karuzela-talerz o średnicy 2 m: stalowa tarcza z desek na piaście, cztery pałąki do trzymania, wytarta farba"""
    reset()
    steel = mat('stal_cz', 'b5372c', 0.5, 0.3)
    yel = mat('stal_z', 'd9a91e', 0.5, 0.3)
    wood = mat('deska', '80603e', 0.85)
    dark = mat('ciemny', '2a2c2e', 0.7, 0.4)
    p = [lathe('piasta', [(0.0, 0.0), (0.16, 0.0), (0.16, 0.06), (0.07, 0.1), (0.07, 0.3), (0.0, 0.3)], dark, 14)]
    p.append(lathe('obrecz', [(0.93, 0.27), (1.0, 0.27), (1.0, 0.34), (0.93, 0.34)], steel, 28))
    p.append(lathe('slupek', [(0.0, 0.3), (0.045, 0.3), (0.045, 1.0), (0.06, 1.02), (0.0, 1.04)], yel, 12))
    for k in range(4):
        a = k * math.tau / 4 + 0.4
        ca, sa = math.cos(a), math.sin(a)
        p.append(tube('palak', [(ca * 0.92, sa * 0.92, 0.33), (ca * 0.9, sa * 0.9, 0.85), (ca * 0.5, sa * 0.5, 0.98), (0.03 * ca, 0.03 * sa, 0.98)], 0.022, yel if k % 2 else steel, 8))
        p.append(tube('ramie', [(0, 0, 0.26), (ca * 0.95, sa * 0.95, 0.29)], 0.025, dark, 6))
    ob = join('Stelaz', p)
    # podłoga z desek: wycinki koła
    d = []
    n = 12
    for k in range(n):
        a0 = k * math.tau / n + 0.02
        a1 = (k + 1) * math.tau / n - 0.02
        bm = bmesh.new()
        vs = [bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)) for z in (0.31, 0.34) for (a, r) in ((a0, 0.1), (a0, 0.93), (a1, 0.93), (a1, 0.1))]
        bm.faces.new(vs[4:8])
        bm.faces.new(vs[0:4][::-1])
        for i in range(4):
            bm.faces.new((vs[i], vs[(i + 1) % 4], vs[4 + (i + 1) % 4], vs[4 + i]))
        me = bpy.data.meshes.new('deska')
        bm.to_mesh(me)
        bm.free()
        d.append(_finish(me, 'deska', wood, False, None))
    deski = join('Deski', d)
    weather([ob, deski], 1024, 0.6, 0.8, (0.2, 0.11, 0.05))
    export('plac_karuzela')


def plac_wazka():
    """huśtawka wagowa: stojak z rur, belka 3,2 m przechylona na jedną stronę, siedziska z desek, uchwyty, opony-odbojniki"""
    reset()
    steel = mat('stal_n', '2f67b3', 0.5, 0.3)
    yel = mat('stal_z', 'd9a91e', 0.5, 0.3)
    wood = mat('deska', '8a6a44', 0.85)
    rub = mat('guma', '18181a', 0.9)
    p = []
    for sy in (-1, 1):
        p.append(tube('noga', [(0, sy * 0.28, 0.0), (0, sy * 0.1, 0.55)], 0.03, steel, 8))
    p.append(tube('os', [(0, -0.16, 0.55), (0, 0.16, 0.55)], 0.03, steel, 8))
    for sy in (-1, 1):
        p.append(lathe('stopa', [(0.0, 0.0), (0.09, 0.0), (0.07, 0.04), (0.0, 0.04)], mat('beton', 'a9a59b', 0.9), 8, loc=(0, sy * 0.28, 0)))
    tilt = math.radians(14)
    L = 1.6
    def pt(x, dz=0.0):
        return (x * math.cos(tilt), 0, 0.6 + x * math.sin(tilt) + dz)
    p.append(tube('belka', [pt(-L), pt(L)], 0.035, yel, 8))
    for sx in (-1, 1):
        x = sx * (L - 0.25)
        b = rbox('siedzisko', (0.42, 0.24, 0.03), wood, 0.008, pt(x, 0.05), (0, -tilt, 0))
        p.append(b)
        hx = sx * (L - 0.55)
        top = pt(hx, 0.28)
        p.append(tube('uchwyt', [pt(hx, 0.03), top], 0.014, steel, 6))
        p.append(tube('poprzeczka', [(top[0], -0.15, top[2]), (top[0], 0.15, top[2])], 0.014, steel, 6))
        # opona wkopana w ziemię pod końcem belki
        t = lathe('opona', [(0.17, -0.08), (0.27, -0.08), (0.3, -0.05), (0.3, 0.05), (0.27, 0.08), (0.17, 0.08)], rub, 14)
        t.rotation_euler = (R90, 0, 0)
        t.location = (sx * (L - 0.2), 0, 0.06)
        p.append(t)
    ob = join('Wazka', p)
    weather([ob], 1024, 0.6, 0.8, (0.2, 0.11, 0.05))
    export('plac_wazka')


def plac_drabinka():
    """drabinka łukowa („przeplotnia”): dwa łuki z rur wysokie na 1,9 m, szczeble co 28 cm"""
    reset()
    green = mat('stal_ziel', '3c8a4a', 0.5, 0.3)
    red = mat('stal_cz', 'b5372c', 0.5, 0.3)
    R, Wd = 1.6, 0.9
    p = []
    arcs = {}
    for sy in (-1, 1):
        pts = [(math.cos(a) * R, sy * Wd / 2, math.sin(a) * R * 1.18) for a in [math.pi * i / 16 for i in range(17)]]
        arcs[sy] = pts
        p.append(tube('luk', pts, 0.028, green, 8))
        for ex in (pts[0], pts[-1]):
            p.append(lathe('stopa', [(0.0, 0.0), (0.09, 0.0), (0.07, 0.04), (0.0, 0.04)], mat('beton', 'a9a59b', 0.9), 8, loc=(ex[0], ex[1], 0)))
    for i in range(1, 16):
        a, b = arcs[-1][i], arcs[1][i]
        p.append(tube('szczebel', [a, b], 0.018, red, 6))
    ob = join('Drabinka', p)
    weather([ob], 1024, 0.6, 0.8, (0.2, 0.11, 0.05))
    export('plac_drabinka')


def plac_plotek():
    """przęsło niskiego płotka placu zabaw (2 m × 0,8 m): rama z rur, pionowe pręty na przemian w trzech kolorach"""
    reset()
    cols = [mat('p_cz', 'b5372c', 0.5, 0.3), mat('p_z', 'd9a91e', 0.5, 0.3), mat('p_n', '2f67b3', 0.5, 0.3), mat('p_ziel', '3c8a4a', 0.5, 0.3)]
    frame = mat('rama', '4a5057', 0.5, 0.5)
    p = [tube('slupek', [(-1.0, 0, 0.0), (-1.0, 0, 0.86)], 0.025, frame, 8)]
    p.append(lathe('kapturek', [(0.0, 0.86), (0.03, 0.86), (0.02, 0.89), (0.0, 0.895)], frame, 8, loc=(-1.0, 0, 0)))
    for z in (0.16, 0.78):
        p.append(tube('rygiel', [(-1.0, 0, z), (1.0, 0, z)], 0.016, frame, 6))
    for i in range(13):
        x = -0.86 + i * 0.145
        p.append(tube('pret', [(x, 0, 0.16), (x, 0, 0.78)], 0.009, cols[i % 4], 5))
    ob = join('Plotek', p)
    weather([ob], 512, 0.5, 0.8, (0.2, 0.11, 0.05))
    export('plac_plotek')


only = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
for fn in (plac_piaskownica, plac_karuzela, plac_wazka, plac_drabinka, plac_plotek):
    if not only or fn.__name__ in only:
        fn()
