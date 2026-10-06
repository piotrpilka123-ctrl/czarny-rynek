"""Auta z blokowiska: sedan, hatchback, kombi, „maluch”, furgon, radiowóz i furgon antyterrorystów.
Każde auto to boczna sylwetka wyciągnięta na szerokość (z prawdziwymi wycięciami nadkoli), kabina zwężająca się
ku dachowi, szyby, koła jako osobne obiekty (Kolo1…4 — gra może nimi kręcić), światła, zderzaki, lusterka, tablice.
TintKaroseria — lakier (kolor nadaje gra). Przód = −Y, koła stoją na z = 0.
Użycie: Blender -b --python tools/blender/make_auta.py [-- nazwa …]"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *

R90 = math.radians(90)
BB = 0.035      # zaokrąglenie krawędzi nadwozia (krzywa rozszerza przez to sylwetkę o tyle samo)
CB = 0.03       # zaokrąglenie kabiny

# sylwetki: współrzędna x rośnie ku przodowi auta; lower = górna krawędź nadwozia od tyłu do przodu,
# cabin = [podstawa szyby przedniej, przód dachu, tył dachu, podstawa szyby tylnej]
TYPY = {
    'sedan': {'W': 1.70, 'wr': 0.31, 'axf': 1.27, 'axr': -1.25, 'z0': 0.2,
              'lower': [(-2.18, 0.30), (-2.20, 0.58), (-2.15, 0.86), (-1.50, 0.95), (1.05, 0.97), (1.95, 0.84), (2.16, 0.66), (2.18, 0.32)],
              'cabin': [(1.10, 0.95), (0.38, 1.39), (-0.80, 1.38), (-1.52, 0.93)], 'bpil': -0.05},
    'hatch': {'W': 1.66, 'wr': 0.30, 'axf': 1.22, 'axr': -1.20, 'z0': 0.2,
              'lower': [(-1.96, 0.30), (-1.98, 0.60), (-1.94, 0.94), (0.98, 0.97), (1.76, 0.86), (1.95, 0.66), (1.96, 0.32)],
              'cabin': [(1.02, 0.95), (0.28, 1.41), (-1.46, 1.38), (-1.93, 0.93)], 'bpil': -0.12},
    'kombi': {'W': 1.72, 'wr': 0.31, 'axf': 1.32, 'axr': -1.30, 'z0': 0.2,
              'lower': [(-2.25, 0.30), (-2.27, 0.60), (-2.22, 0.95), (1.12, 0.97), (2.03, 0.85), (2.23, 0.66), (2.25, 0.32)],
              'cabin': [(1.16, 0.95), (0.44, 1.43), (-2.00, 1.41), (-2.21, 0.93)], 'bpil': 0.0, 'cpil': -1.05},
    'maluch': {'W': 1.38, 'wr': 0.25, 'axf': 0.93, 'axr': -0.91, 'z0': 0.17,
               'lower': [(-1.53, 0.28), (-1.55, 0.52), (-1.50, 0.80), (-1.15, 0.90), (0.78, 0.88), (1.38, 0.80), (1.52, 0.60), (1.53, 0.30)],
               'cabin': [(0.80, 0.87), (0.26, 1.33), (-0.72, 1.31), (-1.15, 0.88)], 'bpil': -0.22, 'two_door': True},
    'van': {'W': 1.92, 'wr': 0.34, 'axf': 1.58, 'axr': -1.45, 'z0': 0.26,
            'lower': [(-2.45, 0.36), (-2.47, 0.72), (-2.45, 1.16), (1.80, 1.16), (2.28, 1.04), (2.43, 0.74), (2.45, 0.38)],
            'cabin': [(1.84, 1.14), (1.22, 1.97), (-2.40, 1.97), (-2.44, 1.14)], 'bpil': 0.42, 'van': True},
}


def _arch(cx, r, z0, n=9):
    """łuk nadkola od przedniej krawędzi do tylnej (x maleje)"""
    return [(cx + r * math.cos(math.pi * i / n), z0 + r * math.sin(math.pi * i / n)) for i in range(n + 1)]


def _outline(T):
    lo = list(T['lower'])
    z0 = T['z0']
    ra = T['wr'] + 0.07 + BB
    pts = lo[:]
    front_x = lo[-1][0]
    rear_x = lo[0][0]
    pts.append((front_x - 0.03, z0 + 0.03))
    pts += _arch(T['axf'], ra, z0)
    pts += _arch(T['axr'], ra, z0)
    pts.append((rear_x + 0.03, z0 + 0.03))
    return pts


def _bryla(name, pts, depth, material, bevel, taper=None):
    """sylwetka (x do przodu, z) wyciągnięta na szerokość; taper(fx, z) -> mnożnik szerokości w danym punkcie"""
    ob = profile(name, [(-x, z) for (x, z) in pts], depth, material, bevel)
    if taper is not None:
        for v in ob.data.vertices:
            # układ siatki: x = −(do przodu), y = wysokość, z = szerokość
            v.co.z *= taper(-v.co.x, v.co.y)
    ob.rotation_euler = (R90, 0, R90)
    return ob


def _kolo(name, r, w, loc, rub, rim, dark, side):
    """koło: opona z bieżnikiem, felga z kołpakiem i śrubami; oś obrotu = oś X obiektu"""
    tyre = lathe('opona', [(r * 0.6, -w / 2), (r * 0.94, -w / 2), (r, -w / 2 + 0.035), (r, w / 2 - 0.035), (r * 0.94, w / 2), (r * 0.6, w / 2)], rub, 20)
    parts = [tyre]
    o = w / 2 * side
    parts.append(lathe('felga', [(0.0, o * 0.55), (r * 0.2, o * 0.62), (r * 0.56, o * 0.5), (r * 0.62, o * 0.86), (r * 0.6, o)], rim, 20))
    parts.append(lathe('kapsel', [(0.0, o * 0.72), (r * 0.16, o * 0.7), (r * 0.17, o * 0.6)], dark, 10))
    for k in range(5):
        a = k * math.tau / 5
        parts.append(rbox('otwor', (r * 0.14, r * 0.2, 0.012), dark, 0.004, (math.cos(a) * r * 0.4, math.sin(a) * r * 0.4, o * 0.56), (0, 0, a), segs=1))
    for g in range(10):
        a = g * math.tau / 10
        parts.append(rbox('biez', (0.012, r * 0.1, w * 0.8), dark, 0.0, (math.cos(a) * r * 1.002, math.sin(a) * r * 1.002, 0), (0, 0, a), segs=1))
    ob = join(name, parts)
    ob.rotation_euler = (0, R90, 0)
    ob.location = loc
    return ob


def auto(nazwa, typ, wersja=''):
    reset()
    T = TYPY[typ]
    W = T['W']
    cab = T['cabin']
    lakier = mat('lakier', 'f2f2f2', 0.38, 0.35)
    szyba = mat('szyba', '10161c', 0.08, 0.6)
    guma = mat('guma', '141414', 0.9)
    czarny = mat('plastik', '1b1c1e', 0.75)
    chrom = mat('chrom', 'b8bcc2', 0.25, 0.9)
    felga = mat('felga', '8f949a', 0.4, 0.8)
    L2 = max(abs(T['lower'][0][0]), abs(T['lower'][-1][0]))
    zb = cab[0][1]
    zr = max(cab[1][1], cab[2][1])

    def taper_body(fx, z):
        # w rzucie z góry nos i kufer lekko się zwężają, progi są ciut węższe niż pas boczny
        k = 1.0 - 0.07 * max(0.0, (abs(fx) - (L2 - 0.55)) / 0.55) ** 2
        return k * (1.0 - 0.03 * max(0.0, (0.45 - z) / 0.3))

    def taper_cab(fx, z):
        t = max(0.0, min(1.0, (z - zb) / max(0.01, zr - zb)))
        return 1.0 - (0.04 if T.get('van') else 0.11) * t

    body = [_bryla('nadwozie', _outline(T), W, lakier, BB, taper_body)]
    cw = W * (0.94 if T.get('van') else 0.9)
    body.append(_bryla('kabina', [(cab[0][0], cab[0][1] - 0.04), cab[1], cab[2], (cab[3][0], cab[3][1] - 0.04)], cw, lakier, CB, taper_cab))
    det = []
    # --- szyby boczne: wstawione w kabinę, rozdzielone słupkiem
    ins = 0.075
    def okno(xa, xb, nm):
        # trapez między linią pasa a dachem, przycięty do zadanego zakresu x i skosów szyb
        def edge_x(z, front):
            a, b = (cab[0], cab[1]) if front else (cab[3], cab[2])
            t = (z - a[1]) / (b[1] - a[1])
            return a[0] + (b[0] - a[0]) * t + (-ins * 1.3 if front else ins * 1.3)
        z1, z2 = zb + ins * 0.7, zr - ins
        p = [(min(xa, edge_x(z1, True)), z1), (min(xa, edge_x(z2, True)), z2), (max(xb, edge_x(z2, False)), z2), (max(xb, edge_x(z1, False)), z1)]
        if p[0][0] - p[3][0] < 0.12:
            return
        det.append(_bryla(nm, p, cw + 0.014, szyba, 0.003, taper_cab))
    bp = T['bpil']
    if T.get('van'):
        okno(9.0, bp + 0.05, 'okno_p')
    else:
        okno(9.0, bp + 0.04, 'okno_p')
        okno(bp - 0.04, T.get('cpil', -9.0) + (0.04 if 'cpil' in T else 0.0), 'okno_t')
        if 'cpil' in T:
            okno(T['cpil'] - 0.04, -9.0, 'okno_b')
    # --- szyba przednia i tylna: cienkie tafle na skosach kabiny
    def tafla(a, b, nm, shrink=0.15):
        ay, by = -a[0], -b[0]
        dy, dz = by - ay, b[1] - a[1]
        ln = math.hypot(dy, dz)
        n1 = (dz / ln, -dy / ln)
        if n1[1] < 0:
            n1 = (-n1[0], -n1[1])
        zm = (a[1] + b[1]) / 2
        wd = cw * taper_cab(0, zm) - 0.16
        ob = rbox(nm, (wd, 0.016, ln - shrink), szyba, 0.004, (0, (ay + by) / 2 + n1[0] * (CB + 0.004), zm + n1[1] * (CB + 0.004)), (-math.atan2(dy, dz), 0, 0))
        det.append(ob)
        return ((ay + by) / 2, zm, n1, ln, wd, -math.atan2(dy, dz), (dy / ln, dz / ln))
    front = tafla(cab[0], cab[1], 'szyba_p')
    if not T.get('van'):
        tafla(cab[3], cab[2], 'szyba_t', 0.17)
    else:
        # tylne drzwi furgonu: dwie małe szybki i szczelina między skrzydłami
        for sx in (-1, 1):
            det.append(rbox('szybka', (0.42, 0.012, 0.36), szyba, 0.02, (sx * 0.3, -cab[3][0] + CB + 0.004, 1.62)))
        det.append(rbox('szczelina', (0.012, 0.012, 1.6), czarny, 0.0, (0, -cab[3][0] + CB + 0.004, 1.1), segs=1))
    # wycieraczki
    if front:
        cy, cz, n1, ln, wd, rx, dd = front
        for sx in (-0.3, 0.22):
            # pióro leży na dole szyby, lekko skośnie
            det.append(rbox('wycieraczka', (0.46, 0.014, 0.018), czarny, 0.004,
                            (sx, cy - dd[0] * ln * 0.36 + n1[0] * (CB + 0.02), cz - dd[1] * ln * 0.36 + n1[1] * (CB + 0.02)), (rx, 0.12, 0)))
    # --- wnętrze nadkoli (żeby przez wycięcie nie było widać na wylot) i podłoga
    for ax in (T['axf'], T['axr']):
        det.append(rbox('nadkole', (W - 0.46, T['wr'] * 2 + 0.2, T['wr'] + 0.34), czarny, 0.0, (0, -ax, T['z0'] + (T['wr'] + 0.34) / 2 - 0.02), segs=1))
    det.append(rbox('podloga', (W - 0.2, L2 * 2 - 0.5, 0.06), czarny, 0.0, (0, 0, T['z0'] + 0.03), segs=1))
    # --- koła
    kola = []
    k = 1
    for ax in (T['axf'], T['axr']):
        for sx in (-1, 1):
            kola.append(_kolo('Kolo%d' % k, T['wr'], 0.19 if typ != 'maluch' else 0.15, (sx * (W / 2 - 0.115), -ax, T['wr']), guma, felga, czarny, sx))
            k += 1
    # --- przód: zderzak, atrapa, reflektory, kierunkowskazy, tablica
    fx = T['lower'][-1][0] + BB
    fz = T['lower'][-2][1]
    hood_z = T['lower'][-3][1] + BB
    lamp_z = (fz + hood_z) / 2 - 0.02 if not T.get('van') else 0.86
    det.append(rbox('zderzak_p', (W + 0.03, 0.14, 0.16), czarny, 0.04, (0, -fx + 0.03, T['z0'] + 0.2), segs=3))
    det.append(rbox('atrapa', (W * 0.42, 0.03, 0.11), czarny, 0.01, (0, -fx + 0.035, lamp_z)))
    for g in range(4):
        det.append(rbox('zebro', (W * 0.4, 0.012, 0.008), chrom, 0.0, (0, -fx + 0.018, lamp_z - 0.04 + g * 0.026), segs=1))
    rear_x = T['lower'][0][0] - BB
    tail_z = T['lower'][2][1] - 0.12
    swiatla = []
    for sx in (-1, 1):
        if typ == 'maluch':
            swiatla.append(lathe('Reflektor', [(0.0, 0.0), (0.075, 0.0), (0.085, 0.02), (0.07, 0.045), (0.0, 0.05)], mat('reflektor', 'f4f1dc', 0.15, 0.0, 0.6), 14, loc=(sx * (W / 2 - 0.2), -fx + 0.06, lamp_z + 0.03)))
            swiatla[-1].rotation_euler = (R90, 0, 0)
        else:
            swiatla.append(rbox('Reflektor', (W * 0.2, 0.05, 0.11), mat('reflektor', 'f4f1dc', 0.15, 0.0, 0.6), 0.02, (sx * (W / 2 - W * 0.16), -fx + 0.06, lamp_z), segs=3))
        det.append(rbox('kierunek', (0.1, 0.03, 0.05), mat('pomarancz', 'd98a1e', 0.3, 0.0, 0.2), 0.012, (sx * (W / 2 - 0.1), -fx + 0.085, T['z0'] + 0.31)))
        # tył: lampy zespolone, odblask
        th = 0.2 if T.get('van') else 0.13
        swiatla.append(rbox('LampaTyl', (0.07 if T.get('van') else W * 0.2, 0.04, th + (0.25 if T.get('van') else 0.0)), mat('lampa_tyl', 'a01414', 0.25, 0.0, 0.5), 0.015, (sx * (W / 2 - (0.07 if T.get('van') else W * 0.14)), -rear_x - 0.03, tail_z if not T.get('van') else 1.0), segs=3))
        det.append(rbox('cofania', (0.07, 0.03, 0.05), mat('biale', 'e8e8e8', 0.3), 0.01, (sx * (W / 2 - W * 0.3), -rear_x - 0.035, tail_z - (0.0 if not T.get('van') else 0.5))))
        # lusterka i klamki
        ms = -(cab[0][0] - 0.12)
        det.append(rbox('lusterko', (0.13, 0.06, 0.09), czarny, 0.025, (sx * (cw / 2 + 0.085), ms, zb + 0.09), segs=3))
        det.append(rbox('lusterko_szklo', (0.1, 0.006, 0.07), chrom, 0.02, (sx * (cw / 2 + 0.085), ms + 0.033, zb + 0.09)))
        det.append(rbox('ramie', (0.1, 0.03, 0.03), czarny, 0.01, (sx * (cw / 2 + 0.03), ms, zb + 0.06)))
        doors = [bp + 0.42] if (T.get('two_door') or T.get('van')) else [bp + 0.5, bp - 0.55]
        for dx in doors:
            det.append(rbox('klamka', (0.016, 0.12, 0.028), chrom if typ != 'van' else czarny, 0.008, (sx * (W / 2 + 0.004), -dx + 0.38, zb - 0.1)))
        # szczeliny drzwi i listwa boczna
        edges = [cab[0][0] - 0.02, bp] + ([] if T.get('two_door') or T.get('van') else [max(cab[3][0] + 0.25, T['axr'] + 0.45)])
        for ex in edges:
            det.append(rbox('szczelina', (0.008, 0.01, zb - T['z0'] - 0.1), czarny, 0.0, (sx * (W / 2 + 0.002), -ex, (zb + T['z0']) / 2 + 0.03), segs=1))
        det.append(rbox('listwa', (0.012, abs(T['axf'] - T['axr']) - T['wr'] * 2 - 0.25, 0.04), czarny, 0.005, (sx * (W / 2 + 0.004), -(T['axf'] + T['axr']) / 2, T['z0'] + 0.3)))
        if T.get('van'):
            # drzwi przesuwne: prowadnica i pionowa szczelina
            det.append(rbox('prowadnica', (0.012, 1.5, 0.03), czarny, 0.004, (sx * (W / 2 + 0.004), 0.75, 1.2)))
            det.append(rbox('szczelina', (0.008, 0.01, 1.6), czarny, 0.0, (sx * (cw / 2 * 0.985 + 0.004), 1.5, 1.2), segs=1))
    det.append(rbox('zderzak_t', (W + 0.03, 0.13, 0.16), czarny, 0.04, (0, -rear_x - 0.03, T['z0'] + 0.2), segs=3))
    biale = mat('tablica', 'e9e9e4', 0.5)
    tusz = mat('tusz', '15161a', 0.6)
    nr = random.Random(hash(nazwa) % 9999)
    numer = '%s %d%s' % (nr.choice(['KR', 'SK', 'WA', 'KT', 'SH', 'SL']), nr.randint(1000, 9999), nr.choice('ACEGHKL'))
    det.append(rbox('tablica_p', (0.46, 0.012, 0.105), biale, 0.004, (0, -fx - 0.045, T['z0'] + 0.2)))
    det.append(text('nr_p', numer, 0.075, tusz, (0, -fx - 0.053, T['z0'] + 0.175)))
    det.append(rbox('tablica_t', (0.46, 0.012, 0.105), biale, 0.004, (0, -rear_x + 0.04, tail_z - 0.16 if not T.get('van') else 0.62)))
    t2 = text('nr_t', numer, 0.075, tusz, (0, -rear_x + 0.048, (tail_z - 0.185) if not T.get('van') else 0.595))
    t2.rotation_euler = (R90, 0, math.radians(180))
    det.append(t2)
    det.append(tube('wydech', [(W * 0.28, -rear_x - 0.12, T['z0'] + 0.04), (W * 0.28, -rear_x + 0.05, T['z0'] + 0.03)], 0.025, chrom, 8))
    det.append(tube('antena', [(-cw * 0.3, -cab[1][0] + 0.15, zr - 0.01), (-cw * 0.3, -cab[1][0] + 0.4, zr + 0.42)], 0.004, czarny, 4))
    if typ == 'kombi':
        for sx in (-1, 1):
            det.append(tube('reling', [(sx * cw * 0.36, -cab[1][0] + 0.25, zr + 0.0), (sx * cw * 0.36, -cab[1][0] + 0.3, zr + 0.05), (sx * cw * 0.36, -cab[2][0] - 0.3, zr + 0.05), (sx * cw * 0.36, -cab[2][0] - 0.25, zr + 0.0)], 0.012, czarny, 6))
    # --- wersje służbowe
    koguty = []
    if wersja in ('policja', 'swat'):
        nieb = mat('niebieski', '1d3a8a', 0.4, 0.2)
        if wersja == 'policja':
            for sx in (-1, 1):
                det.append(rbox('pas', (0.006, L2 * 1.5, 0.17), nieb, 0.0, (sx * (W / 2 + 0.003), 0.05, zb - 0.26), segs=1))
                tx = text('napis', 'POLICE', 0.13, mat('bialy_napis', 'f4f4f4', 0.5), (sx * (W / 2 + 0.008), -bp + 0.05, zb - 0.31))
                tx.rotation_euler = (R90, 0, R90 if sx > 0 else -R90)
                det.append(tx)
            hp = text('napis_maska', 'POLICE', 0.16, nieb, (0, -(cab[0][0] + fx) / 2 - 0.1, hood_z + 0.075), (math.radians(4), 0, 0))
            det.append(hp)
        else:
            for sx in (-1, 1):
                tx = text('napis', 'POLICE', 0.26, mat('bialy_napis', 'f4f4f4', 0.5), (sx * (cw / 2 * 0.975 + 0.012), 0.6, 1.3))
                tx.rotation_euler = (R90, 0, R90 if sx > 0 else -R90)
                det.append(tx)
                det.append(rbox('krata', (0.012, 0.6, 0.4), czarny, 0.0, (sx * (cw / 2 * 0.97 + 0.012), -bp + 0.42, 1.55), segs=1))
            # orurowanie z przodu i stopnie
            for z in (0.5, 0.78):
                det.append(tube('orurowanie', [(-W * 0.38, -fx - 0.1, z), (W * 0.38, -fx - 0.1, z)], 0.025, czarny, 8))
            for sx in (-0.4, 0.0, 0.4):
                det.append(tube('orurowanie', [(sx * W, -fx - 0.1, 0.38), (sx * W, -fx - 0.1, 0.9)], 0.025, czarny, 8))
            for sx in (-1, 1):
                det.append(rbox('stopien', (0.16, 1.6, 0.03), czarny, 0.01, (sx * (W / 2 + 0.07), 0.4, 0.36)))
        # belka świetlna: podstawa i dwa klosze (osobne obiekty — gra nimi miga)
        ry = -(cab[1][0] - 0.35)
        det.append(rbox('belka', (cw * 0.72, 0.22, 0.035), czarny, 0.01, (0, ry, zr + 0.03)))
        for sx, nm in ((-1, 'KogutL'), (1, 'KogutP')):
            koguty.append(rbox(nm, (cw * 0.32, 0.2, 0.09), mat('kogut', '2a52ff', 0.2, 0.0, 2.5), 0.03, (sx * cw * 0.19, ry, zr + 0.09), segs=3))
        det.append(rbox('glosnik', (cw * 0.07, 0.2, 0.08), czarny, 0.02, (0, ry, zr + 0.085)))
    kar = join('TintKaroseria', body)
    dj = join('Detale', det)
    wear = {'maluch': 0.6, 'van': 0.4}.get(typ, 0.3)
    dirt = 0.15 if wersja else 0.32
    weather([kar], 1024, dirt, wear if not wersja else 0.15, (0.13, 0.1, 0.08))
    export(nazwa)


LISTA = {'auto_sedan': ('sedan', ''), 'auto_hatch': ('hatch', ''), 'auto_kombi': ('kombi', ''), 'auto_maluch': ('maluch', ''), 'auto_van': ('van', ''),
         'auto_policja': ('sedan', 'policja'), 'auto_swat': ('van', 'swat')}
only = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
for n, (t, w) in LISTA.items():
    if not only or n in only:
        auto(n, t, w)
