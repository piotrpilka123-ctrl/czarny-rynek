"""Stara Huta: przesuwna brama z nitowanej blachy, stalowe drzwi ewakuacyjne z lampą i tablicą EXIT, reflektor ścienny,
wisząca lampa przemysłowa; do tego latarka kątowa policjanta. Przód = −Y. Części „Swiatlo…” świecą."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *

R90 = math.radians(90)
rnd = random.Random(21)
RUST = (0.16, 0.08, 0.04)


def huta_brama():
    """brama hali 3,2 × 2,9 m (ściana w y=0): dwa skrzydła z nitowanej blachy z krzyżulcami na rolkach pod dwuteownikiem,
    rygiel z łańcuchem i kłódką, furtka z zakratowanym okienkiem, pasy ostrzegawcze, prowadnica w posadzce"""
    reset()
    plate = mat('blacha', '5d646b', 0.55, 0.5)
    frame = mat('profil', '3d4349', 0.5, 0.6)
    W, H = 3.2, 2.9
    p = [rbox('belka', (W + 0.9, 0.16, 0.2), frame, 0.008, (0, -0.1, H + 0.14))]
    p.append(rbox('polka_g', (W + 0.9, 0.24, 0.025), frame, 0.004, (0, -0.1, H + 0.245)))
    p.append(rbox('polka_d', (W + 0.9, 0.24, 0.025), frame, 0.004, (0, -0.1, H + 0.035)))
    for sx in (-1, 1):
        p.append(rbox('slup', (0.2, 0.22, H + 0.3), frame, 0.01, (sx * (W / 2 + 0.3), -0.06, (H + 0.3) / 2)))
        p.append(rbox('odboj', (0.08, 0.12, 0.3), frame, 0.01, (sx * (W / 2 + 0.16), -0.16, 0.15)))
    p.append(rbox('prowadnica', (W + 0.5, 0.08, 0.03), frame, 0.004, (0, -0.16, 0.015)))
    for sx in (-1, 1):
        lx = sx * W / 4
        lw = W / 2 - 0.02
        p.append(rbox('skrzydlo', (lw, 0.045, H - 0.06), plate, 0.004, (lx, -0.15, H / 2)))
        for z in (0.09, H / 2, H - 0.1):
            p.append(rbox('rygiel_h', (lw, 0.03, 0.09), frame, 0.004, (lx, -0.185, z)))
        for ex in (-1, 1):
            p.append(rbox('rygiel_v', (0.09, 0.03, H - 0.06), frame, 0.004, (lx + ex * (lw / 2 - 0.045), -0.185, H / 2)))
        ln = math.hypot(lw - 0.18, H / 2 - 0.2)
        an = math.atan2(H / 2 - 0.2, lw - 0.18)
        for k, zc in enumerate((H * 0.27, H * 0.75)):
            p.append(rbox('krzyzulec', (ln, 0.02, 0.07), frame, 0.003, (lx, -0.18, zc), (0, an * (1 if (k + (sx > 0)) % 2 == 0 else -1), 0)))
        p += bolts('nit%d' % sx, [(lx + ex * (lw / 2 - 0.045), -0.201, 0.2 + k * 0.32) for ex in (-1, 1) for k in range(9)], frame, 0.014, 0.008, 'Y')
        p += bolts('nit_h%d' % sx, [(lx - lw / 2 + 0.2 + k * 0.3, -0.201, z) for z in (0.09, H / 2, H - 0.1) for k in range(5)], frame, 0.014, 0.008, 'Y')
        for rx in (-0.5, 0.5):
            w = lathe('rolka', [(0.0, -0.03), (0.07, -0.03), (0.085, -0.02), (0.085, 0.02), (0.07, 0.03), (0.0, 0.03)], frame, 14)
            w.rotation_euler = (R90, 0, 0)
            w.location = (lx + rx, -0.15, H + 0.03)
            p.append(w)
            p.append(rbox('wieszak', (0.05, 0.06, 0.2), frame, 0.006, (lx + rx, -0.15, H - 0.06)))
    # rygiel w poprzek z uchwytami i łańcuchem
    p.append(rbox('zasuwa', (1.5, 0.05, 0.09), frame, 0.008, (0, -0.225, 1.25)))
    for sx in (-0.55, 0.55):
        p.append(rbox('uchwyt', (0.1, 0.09, 0.16), frame, 0.008, (sx, -0.22, 1.25)))
    p.append(tube('lancuch', [(-0.12, -0.25, 1.3), (-0.08, -0.27, 1.1), (0.0, -0.27, 1.02), (0.08, -0.27, 1.1), (0.12, -0.25, 1.3)], 0.012, mat('lancuch', '6a6e72', 0.45, 0.8), 6))
    p.append(rbox('klodka', (0.08, 0.035, 0.07), mat('mosiadz', 'b89a4a', 0.35, 0.9), 0.008, (0.0, -0.275, 0.97)))
    # furtka w prawym skrzydle: rama, klamka, zakratowane okienko
    fx = W / 4 + 0.1
    for ex in (-1, 1):
        p.append(rbox('furtka_v', (0.04, 0.02, 1.9), frame, 0.003, (fx + ex * 0.4, -0.2, 1.05)))
    p.append(rbox('furtka_h', (0.84, 0.02, 0.04), frame, 0.003, (fx, -0.2, 2.0)))
    p.append(rbox('okienko', (0.34, 0.012, 0.22), mat('szyba', '10161e', 0.15, 0.2), 0.0, (fx, -0.176, 1.62), segs=1))
    for k in range(4):
        p.append(tube('krata', [(fx - 0.12 + k * 0.08, -0.19, 1.5), (fx - 0.12 + k * 0.08, -0.19, 1.74)], 0.007, frame, 5))
    p.append(tube('klamka', [(fx - 0.3, -0.2, 1.1), (fx - 0.3, -0.25, 1.1), (fx - 0.3, -0.25, 1.0)], 0.011, frame, 8))
    ob = join('Brama', p)
    weather([ob], 2048, 0.8, 0.45, RUST)
    # pasy ostrzegawcze u dołu i napis z szablonu
    s = []
    for k in range(16):
        s.append(rbox('pas%d' % k, (0.1, 0.004, 0.36), mat('zolty' if k % 2 == 0 else 'czarny', 'c8a21a' if k % 2 == 0 else '17181a', 0.7), 0.0, (-W / 2 + 0.12 + k * 0.2, -0.176, 0.3), (0, math.radians(35), 0), segs=1))
    so = join('Pasy', s)
    weather([so], 1024, 0.5, 0.6, RUST)
    t = [text('napis', 'HALL 2', 0.26, mat('szablon', 'd8d4c8', 0.8), (-W / 4, -0.176, 2.2), (R90, 0, 0), 0.0008)]
    t.append(text('napis2', 'KEEP CLEAR', 0.1, mat('szablon', 'd8d4c8', 0.8), (-W / 4, -0.176, 1.95), (R90, 0, 0), 0.0008))
    join('Napisy', t)
    export('huta_brama')


def huta_drzwi():
    """stalowe drzwi ewakuacyjne 1,1 × 2,1 m w grubej ościeżnicy (ściana w y=0): nitowana blacha, drążek antypaniczny, samozamykacz,
    wizjer z drutem, kopniak, szewrony na ościeżnicy, kanał z przewodem, lampa okrętowa w koszu (Swiatlo) i tablica EXIT (SwiatloExit)"""
    reset()
    plate = mat('blacha', '59616a', 0.55, 0.5)
    frame = mat('profil', '363b41', 0.5, 0.6)
    p = []
    for sx in (-1, 1):
        p.append(rbox('oscieznica', (0.14, 0.2, 2.24), frame, 0.008, (sx * 0.64, -0.05, 1.12)))
        p += bolts('kotwa%d' % sx, [(sx * 0.64, -0.152, z) for z in (0.25, 0.9, 1.55, 2.1)], frame, 0.016, 0.008, 'Y')
    p.append(rbox('nadproze', (1.42, 0.2, 0.14), frame, 0.008, (0, -0.05, 2.26)))
    p.append(rbox('prog', (1.14, 0.2, 0.03), frame, 0.004, (0, -0.05, 0.015)))
    p.append(rbox('skrzydlo', (1.12, 0.055, 2.14), plate, 0.005, (0, -0.07, 1.1)))
    for z in (0.12, 1.1, 2.08):
        p.append(rbox('pas_h', (1.1, 0.02, 0.1), frame, 0.004, (0, -0.105, z)))
    for sx in (-1, 1):
        p.append(rbox('pas_v', (0.09, 0.02, 2.1), frame, 0.004, (sx * 0.505, -0.105, 1.1)))
        p += bolts('nit%d' % sx, [(sx * 0.505, -0.116, 0.22 + k * 0.235) for k in range(9)], frame, 0.013, 0.007, 'Y')
    p += bolts('nit_h', [(-0.36 + k * 0.18, -0.116, z) for z in (0.12, 1.1, 2.08) for k in range(5)], frame, 0.013, 0.007, 'Y')
    p.append(rbox('kopniak', (0.9, 0.008, 0.26), mat('kopniak', '8a8f95', 0.4, 0.8), 0.004, (0, -0.1, 0.35)))
    st = mat('stal', 'a9aeb3', 0.3, 0.85)
    p.append(tube('drazek', [(-0.44, -0.1, 1.02), (-0.44, -0.17, 1.02), (0.44, -0.17, 1.02), (0.44, -0.1, 1.02)], 0.018, st, 10))
    for sx in (-0.44, 0.44):
        p.append(rbox('okucie', (0.07, 0.03, 0.14), frame, 0.006, (sx, -0.11, 1.02)))
    p.append(rbox('wizjer', (0.16, 0.012, 0.34), mat('szyba', '10161e', 0.15, 0.2), 0.0, (0.26, -0.1, 1.62), segs=1))
    p.append(rbox('wizjer_r', (0.2, 0.016, 0.38), frame, 0.004, (0.26, -0.098, 1.62)))
    for k in range(4):
        p.append(rbox('drut', (0.16, 0.003, 0.004), st, 0.0, (0.26, -0.108, 1.5 + k * 0.08), segs=1))
    p.append(rbox('samozamykacz', (0.26, 0.06, 0.07), st, 0.008, (-0.28, -0.13, 2.1)))
    p.append(tube('ramie', [(-0.18, -0.14, 2.1), (0.1, -0.2, 2.18), (0.34, -0.08, 2.22)], 0.009, st, 6))
    for z in (0.3, 1.1, 1.9):
        p.append(lathe('zawias', [(0.0, -0.07), (0.022, -0.07), (0.022, 0.07), (0.0, 0.07)], frame, 10, loc=(-0.575, -0.11, z)))
    # kanał z przewodem do lampy i puszka
    p.append(tube('kanal', [(0.86, -0.03, 0.0), (0.86, -0.03, 2.6), (0.3, -0.03, 2.62), (0.0, -0.05, 2.62)], 0.014, frame, 6))
    p.append(rbox('puszka', (0.12, 0.06, 0.12), frame, 0.008, (0.86, -0.04, 1.35)))
    p.append(lathe('oprawa', [(0.0, 0.0), (0.1, 0.0), (0.1, 0.03), (0.075, 0.05), (0.0, 0.05)], frame, 14, loc=(0, -0.05, 2.6)))
    p[-1].rotation_euler = (R90, 0, 0)
    for k in range(6):
        a = k * math.tau / 6
        p.append(tube('kosz', [(math.cos(a) * 0.085, -0.1, 2.6 + math.sin(a) * 0.085), (math.cos(a) * 0.06, -0.2, 2.6 + math.sin(a) * 0.06), (0, -0.22, 2.6)], 0.004, st, 4))
    p.append(rbox('kaseton', (0.46, 0.07, 0.2), frame, 0.008, (0, -0.06, 2.92)))
    ob = join('Drzwi', p)
    weather([ob], 2048, 0.7, 0.35, RUST)
    # taśma ostrzegawcza na ościeżnicy i nadprożu: ciągłe żółto-czarne ukośne pasy (wcześniej osobne romby — nieczytelne)
    yel = mat('zolty', 'd2aa1c', 0.7)
    blk = mat('czarny', '17181a', 0.7)
    s = []
    from lib import profile as _pf
    for sx in (-1, 1):
        s.append(rbox('tasma', (0.1, 0.003, 2.2), yel, 0.0, (sx * 0.64, -0.1515, 1.1), segs=1))
        z = 0.0
        while z < 2.2:
            z1, z2 = z, min(2.2, z + 0.1)
            # równoległobok pasa: po lewej stronie drzwi pochylony w jedną stronę, po prawej w drugą
            lo_a, lo_b = (z1, min(2.2, z1 + 0.1)) if sx < 0 else (min(2.2, z1 + 0.1), z1)
            hi_a, hi_b = (z2, min(2.2, z2 + 0.1)) if sx < 0 else (min(2.2, z2 + 0.1), z2)
            pr = _pf('pas', [(-0.05, lo_a), (0.05, lo_b), (0.05, hi_b), (-0.05, hi_a)], 0.002, blk, 0.0004)
            pr.location = (sx * 0.64, -0.154, 0.0)
            s.append(pr)
            z += 0.2
    s.append(rbox('tasma_g', (1.38, 0.003, 0.1), yel, 0.0, (0, -0.1515, 2.26), segs=1))
    x = -0.69
    while x < 0.69:
        x1, x2 = x, min(0.69, x + 0.1)
        pr = _pf('pas_g', [(x1, 2.21), (x2, 2.21), (min(0.69, x2 + 0.1), 2.31), (min(0.69, x1 + 0.1), 2.31)], 0.002, blk, 0.0004)
        pr.location = (0, -0.154, 0.0)
        s.append(pr)
        x += 0.2
    # tabliczka na skrzydle: co to za drzwi
    tb = [rbox('tabliczka', (0.5, 0.004, 0.2), mat('tabl_z', '1f7a44', 0.6), 0.004, (-0.16, -0.118, 1.68)),
          text('tabl_t1', 'EMERGENCY EXIT', 0.05, mat('tabl_b', 'f2fff4', 0.5), (-0.16, -0.122, 1.71)),
          text('tabl_t2', 'KEEP CLEAR', 0.04, mat('tabl_b', 'f2fff4', 0.5), (-0.16, -0.122, 1.64))]
    tbo = join('Tabliczka', tb)
    weather([tbo], 512, 0.25, 0.3, RUST)
    so = join('Szewrony', s)
    weather([so], 512, 0.8, 0.9, RUST)
    lathe('Swiatlo', [(0.0, 0.05), (0.055, 0.05), (0.06, 0.1), (0.045, 0.16), (0.0, 0.18)], mat('klosz', 'ffe2b0', 0.3, 0.0, 4.0), 12, loc=(0, -0.05, 2.6)).rotation_euler = (R90, 0, 0)
    rbox('SwiatloExit', (0.42, 0.006, 0.16), mat('exit', '1f9a4c', 0.4, 0.0, 2.2), 0.0, (0, -0.098, 2.92), segs=1)
    text('SwiatloNapis', 'EXIT', 0.11, mat('exit_n', 'f2fff4', 0.4, 0.0, 3.5), (0, -0.103, 2.88), (R90, 0, 0), 0.001)
    export('huta_drzwi')


def huta_reflektor():
    """reflektor ścienny na wysięgniku (zaczep w 0,0,0, ściana w y=0): żebrowana obudowa na jarzmie, osłona z kratką, przewód w peszlu; szyba „Swiatlo”"""
    reset()
    fr = mat('profil', '363b41', 0.5, 0.6)
    p = [rbox('plyta', (0.18, 0.02, 0.18), fr, 0.006, (0, -0.01, 0))]
    p += bolts('sr', [(sx * 0.06, -0.021, sz * 0.06) for sx in (-1, 1) for sz in (-1, 1)], fr, 0.012, 0.006, 'Y')
    p.append(tube('wysiegnik', [(0, -0.02, 0), (0, -0.3, 0.04), (0, -0.42, 0.02)], 0.022, fr, 8))
    p.append(tube('jarzmo', [(-0.19, -0.5, -0.1), (-0.19, -0.42, 0.02), (0.19, -0.42, 0.02), (0.19, -0.5, -0.1)], 0.014, fr, 6))
    p.append(tube('peszel', [(0.06, -0.01, -0.08), (0.08, -0.15, -0.2), (0.05, -0.4, -0.12)], 0.01, mat('peszel', '1a1a1c', 0.7), 6))
    ob = join('Wysiegnik', p)
    h = [rbox('obudowa', (0.34, 0.2, 0.26), fr, 0.025, (0, 0, 0), segs=3)]
    for k in range(7):
        h.append(rbox('zebro', (0.3, 0.012, 0.24), fr, 0.003, (0, 0.108 + 0.0, -0.0), segs=1))
        h[-1].location = (-0.135 + k * 0.045, 0.11, 0)
        h[-1].scale = (0.04, 1.6, 1.0)
    h.append(rbox('ramka', (0.36, 0.025, 0.28), fr, 0.008, (0, -0.105, 0)))
    for k in range(5):
        h.append(tube('kratka', [(-0.16 + k * 0.08, -0.125, -0.12), (-0.16 + k * 0.08, -0.125, 0.12)], 0.004, mat('stal', 'a9aeb3', 0.3, 0.85), 4))
    hj = join('Glowica', h)
    hj.rotation_euler = (math.radians(-38), 0, 0)
    hj.location = (0, -0.5, -0.1)
    weather([ob, hj], 1024, 0.75, 0.7, RUST)
    g = rbox('Swiatlo', (0.3, 0.006, 0.22), mat('szyba_r', 'fff2d6', 0.2, 0.0, 6.0), 0.0, (0, -0.11, 0), segs=1)
    g.parent = hj
    export('huta_reflektor')


def huta_lampa():
    """lampa przemysłowa wisząca na łańcuchu (zaczep w 0,0,0): hak, przewód, emaliowany klosz z kołnierzem i koszem z drutu, żarówka „Swiatlo”"""
    reset()
    fr = mat('profil', '363b41', 0.5, 0.6)
    p = [rbox('hak_p', (0.1, 0.1, 0.012), fr, 0.004, (0, 0, -0.006))]
    p.append(tube('hak', [(0, 0, -0.012), (0, 0, -0.06), (0.02, 0, -0.08), (0, 0, -0.1)], 0.006, fr, 6))
    for k in range(9):
        z = -0.1 - k * 0.075
        pts = [(0.012 * math.cos(a), 0.0, z - 0.04 + 0.03 * math.sin(a)) if k % 2 == 0 else (0.0, 0.012 * math.cos(a), z - 0.04 + 0.03 * math.sin(a)) for a in [j * math.tau / 8 for j in range(9)]]
        p.append(tube('ogniwo', pts, 0.0035, fr, 4))
    p.append(tube('przewod', [(0.03, 0.02, -0.01), (0.035, 0.02, -0.4), (0.01, 0.01, -0.8)], 0.005, mat('przewod', '15151a', 0.7), 5))
    p.append(lathe('oprawka', [(0.0, -0.8), (0.03, -0.8), (0.04, -0.83), (0.04, -0.9), (0.0, -0.9)], fr, 12))
    en = mat('emalia', '2f4a3a', 0.4, 0.2)
    p.append(lathe('klosz', [(0.045, -0.86), (0.05, -0.86), (0.2, -1.0), (0.27, -1.08), (0.28, -1.1), (0.27, -1.105), (0.2, -1.03), (0.05, -0.89)], en, 22))
    p.append(lathe('klosz_w', [(0.05, -0.892), (0.2, -1.033), (0.268, -1.103)], mat('emalia_b', 'd8d6cc', 0.5), 22))
    for k in range(8):
        a = k * math.tau / 8
        p.append(tube('kosz', [(0.27 * math.cos(a), 0.27 * math.sin(a), -1.1), (0.2 * math.cos(a), 0.2 * math.sin(a), -1.2), (0.0, 0.0, -1.24)], 0.0035, fr, 4))
    ob = join('Lampa', p)
    weather([ob], 1024, 0.7, 0.6, RUST)
    lathe('Swiatlo', [(0.0, -0.9), (0.02, -0.905), (0.045, -0.96), (0.05, -1.0), (0.04, -1.04), (0.0, -1.055)], mat('zarowka', 'fff0d0', 0.3, 0.0, 6.0), 12)
    export('huta_lampa')


def pol_latarka():
    """latarka kątowa na szelce policjanta (środek korpusu w 0,0,0, świeci w −Y): korpus z żebrowaniem, klips, głowica z kołnierzem; szybka „Swiatlo”"""
    reset()
    bl = mat('korpus', '15171a', 0.5)
    p = [lathe('korpus', [(0.0, -0.06), (0.016, -0.06), (0.017, -0.05), (0.017, 0.04), (0.019, 0.045), (0.019, 0.06), (0.0, 0.06)], bl, 12)]
    for k in range(6):
        p.append(lathe('zebro', [(0.017, -0.045 + k * 0.014), (0.0185, -0.043 + k * 0.014), (0.017, -0.041 + k * 0.014)], bl, 12))
    hd = lathe('glowica', [(0.0, 0.0), (0.019, 0.0), (0.021, 0.02), (0.024, 0.03), (0.024, 0.04), (0.02, 0.04), (0.0, 0.036)], bl, 14)
    hd.rotation_euler = (R90, 0, 0)
    hd.location = (0, -0.012, 0.045)
    p.append(hd)
    p.append(rbox('klips', (0.012, 0.004, 0.07), mat('stal', 'a9aeb3', 0.3, 0.85), 0.002, (0, 0.02, -0.005)))
    p.append(rbox('wlacznik', (0.008, 0.005, 0.012), mat('guma', 'c8502a', 0.8), 0.002, (0.0, -0.019, 0.01)))
    ob = join('Latarka', p)
    weather([ob], 256, 0.3, 0.5)
    ln = lathe('Swiatlo', [(0.0, 0.0), (0.019, 0.0), (0.019, 0.002), (0.0, 0.004)], mat('szybka', 'eaf4ff', 0.2, 0.0, 6.0), 12)
    ln.rotation_euler = (R90, 0, 0)
    ln.location = (0, -0.05, 0.045)
    export('pol_latarka')


ALL = (huta_brama, huta_drzwi, huta_reflektor, huta_lampa, pol_latarka)
only = [a for a in sys.argv[sys.argv.index('--') + 1:]] if '--' in sys.argv else []
for f in ALL:
    if not only or f.__name__ in only:
        f()
