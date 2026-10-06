"""Stanowisko pracy w mieszkaniu — współczesne zamiast staroci: biurko na stalowej ramie z kontenerkiem, cienki laptop,
waga precyzyjna, krzesło obrotowe i szafa z frontami w okleinie. Przód = −Y. „Ekran…”, „Wyswietlacz” świecą."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *

R90 = math.radians(90)
rnd = random.Random(8)


def dom_biurko():
    """biurko 1,9 × 0,85 m: blat w okleinie dębowej z ciemnym obrzeżem, rama z profili, kontenerek z trzema szufladami, przelotka, podkładka"""
    reset()
    oak = mat('okleina', 'd4bd98', 0.55)
    edge = mat('obrzeze', '3a3027', 0.6)
    st = mat('profil', '1d1f23', 0.45, 0.6)
    W, D, H = 1.9, 0.85, 0.8
    p = [rbox('blat', (W, D, 0.032), oak, 0.004, (0, 0, H - 0.016))]
    p.append(rbox('obrzeze_p', (W + 0.002, 0.004, 0.034), edge, 0.0, (0, -D / 2 - 0.001, H - 0.016), segs=1))
    p.append(rbox('obrzeze_t', (W + 0.002, 0.004, 0.034), edge, 0.0, (0, D / 2 + 0.001, H - 0.016), segs=1))
    for sx in (-1, 1):
        p.append(rbox('obrzeze_b', (0.004, D, 0.034), edge, 0.0, (sx * (W / 2 + 0.001), 0, H - 0.016), segs=1))
        x = sx * (W / 2 - 0.09)
        for sy in (-1, 1):
            p.append(rbox('noga', (0.045, 0.045, H - 0.04), st, 0.005, (x, sy * (D / 2 - 0.08), (H - 0.04) / 2)))
            p.append(lathe('stopka', [(0.0, 0.0), (0.02, 0.0), (0.02, 0.008), (0.0, 0.008)], mat('guma', '111113', 0.9), 10, loc=(x, sy * (D / 2 - 0.08), -0.001)))
        p.append(rbox('plaza_d', (0.045, D - 0.16, 0.03), st, 0.004, (x, 0, 0.09)))
        p.append(rbox('plaza_g', (0.045, D - 0.12, 0.03), st, 0.004, (x, 0, H - 0.05)))
    p.append(rbox('belka', (W - 0.2, 0.03, 0.05), st, 0.004, (0, D / 2 - 0.1, H - 0.06)))
    # koryto na kable pod blatem
    p.append(rbox('koryto', (0.9, 0.12, 0.008), st, 0.002, (-0.2, D / 2 - 0.18, H - 0.14)))
    for sx in (-0.63, 0.23):
        p.append(rbox('wieszak', (0.008, 0.12, 0.1), st, 0.002, (sx, D / 2 - 0.18, H - 0.09)))
    p.append(lathe('przelotka', [(0.0, 0.0), (0.034, 0.0), (0.034, 0.003), (0.03, 0.004), (0.0, 0.004)], mat('przelotka', '15161a', 0.5), 16, loc=(0.55, D / 2 - 0.09, H)))
    # kontenerek z szufladami pod prawą stroną
    gr = mat('grafit', '2f3237', 0.5)
    cx = W / 2 - 0.36
    p.append(rbox('kontener', (0.42, 0.6, 0.58), gr, 0.006, (cx, -0.06, 0.37)))
    hd = mat('uchwyt', '9a9ea4', 0.3, 0.8)
    for k in range(3):
        z = 0.56 - k * 0.185
        p.append(rbox('front', (0.404, 0.016, 0.175), mat('front', '383b41', 0.45), 0.004, (cx, -0.366, z)))
        p.append(rbox('uchwyt', (0.14, 0.012, 0.01), hd, 0.003, (cx, -0.38, z + 0.06)))
    p.append(lathe('zamek', [(0.0, 0.0), (0.008, 0.0), (0.008, 0.003), (0.0, 0.003)], hd, 8, loc=(cx + 0.16, -0.375, 0.615)))
    p[-1].rotation_euler = (R90, 0, 0)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(lathe('kolko', [(0.0, -0.012), (0.022, -0.012), (0.028, 0.0), (0.022, 0.012), (0.0, 0.012)], mat('guma', '111113', 0.9), 10, loc=(cx + sx * 0.16, -0.06 + sy * 0.24, 0.04)))
            p[-1].rotation_euler = (0, R90, 0)
    ob = join('Biurko', p)
    weather([ob], 1024, 0.22, 0.22)
    m = rbox('Podkladka', (0.82, 0.36, 0.004), mat('filc', '26282d', 0.95), 0.012, (-0.25, -0.16, H + 0.002), segs=3)
    weather([m], 512, 0.25, 0.1)
    export('dom_biurko')


def dom_laptop():
    """cienki laptop: aluminiowa podstawa z wyspową klawiaturą i gładzikiem, pokrywa uchylona, ekran z oknami programu (Ekran), zasilacz"""
    reset()
    al = mat('aluminium', '4a4d53', 0.35, 0.8)
    key = mat('klawisz', '15161a', 0.6)
    W, D = 0.325, 0.225
    p = [rbox('podstawa', (W, D, 0.013), al, 0.005, (0, 0, 0.0075), segs=3)]
    p.append(rbox('wanna', (0.286, 0.108, 0.0008), mat('wanna', '2a2c31', 0.5, 0.5), 0.0, (0, 0.036, 0.0142), segs=1))
    kw = 0.0195
    for r in range(5):
        n = 14 if r < 4 else 0
        for c in range(n):
            wk = kw * (1.5 if (c in (0, 13) and r > 0) else 1.0)
            x = -0.136 + c * 0.0209 + (0.002 * r if r < 4 else 0)
            p.append(rbox('k', (min(wk, 0.0185), 0.0165, 0.0018), key, 0.0, (x, 0.08 - r * 0.0205, 0.0152), segs=1))
    for c, wk in enumerate((0.03, 0.022, 0.022, 0.108, 0.022, 0.022, 0.03)):
        x = -0.128 + sum((0.03, 0.022, 0.022, 0.108, 0.022, 0.022, 0.03)[:c]) + c * 0.003 + wk / 2 - 0.004
        p.append(rbox('k5', (wk, 0.0165, 0.0018), key, 0.0, (x, -0.002, 0.0152), segs=1))
    p.append(rbox('gladzik', (0.115, 0.072, 0.0006), mat('gladzik', '5a5d63', 0.25, 0.8), 0.004, (0, -0.062, 0.0143)))
    for sx in (-1, 1):
        p.append(rbox('port', (0.002, 0.012, 0.004), key, 0.0, (sx * 0.1625, 0.06, 0.0075), segs=1))
        p.append(rbox('port2', (0.002, 0.009, 0.0035), key, 0.0, (sx * 0.1625, 0.035, 0.0075), segs=1))
        p.append(rbox('nozka', (0.05, 0.008, 0.002), mat('guma', '111113', 0.9), 0.001, (sx * 0.11, 0.09, 0.0)))
        p.append(rbox('nozka2', (0.05, 0.008, 0.002), mat('guma', '111113', 0.9), 0.001, (sx * 0.11, -0.09, 0.0)))
    hinge = tube('zawias', [(-0.12, D / 2 - 0.004, 0.014), (0.12, D / 2 - 0.004, 0.014)], 0.006, al, 8)
    p.append(hinge)
    th = math.radians(-18)
    piv = Vector((0, D / 2 - 0.004, 0.016))
    cl = piv + Vector((0, math.sin(-th) * 0.108, math.cos(th) * 0.108))
    p.append(rbox('pokrywa', (W, 0.005, 0.216), al, 0.004, tuple(cl), (th, 0, 0), segs=3))
    nrm = Vector((0, -math.cos(th), -math.sin(th)))
    p.append(rbox('ramka', (W - 0.006, 0.0012, 0.208), mat('ramka', '0b0b0d', 0.3), 0.0, tuple(cl + nrm * 0.0028), (th, 0, 0), segs=1))
    logo = lathe('logo', [(0.0, 0.0), (0.016, 0.0), (0.016, 0.0006), (0.0, 0.0006)], mat('logo', 'b9bcc2', 0.2, 0.9), 16)
    logo.rotation_euler = (th - R90, 0, 0)
    logo.location = tuple(cl - nrm * 0.0027)
    p.append(logo)
    # zasilacz i przewód
    p.append(rbox('zasilacz', (0.11, 0.05, 0.03), mat('zasilacz', '1a1b1e', 0.6), 0.008, (-0.3, 0.12, 0.015), (0, 0, 0.5)))
    p.append(tube('przewod', [(-0.164, 0.06, 0.008), (-0.2, 0.06, 0.004), (-0.24, 0.09, 0.004), (-0.27, 0.11, 0.012)], 0.0025, mat('zasilacz', '1a1b1e', 0.6), 6))
    ob = join('Laptop', p)
    weather([ob], 1024, 0.15, 0.2)
    up = Vector((0, math.sin(-th), math.cos(th)))
    sc = cl + nrm * 0.0036
    rbox('Ekran', (0.3, 0.0006, 0.19), mat('ekran', '101b2e', 0.15, 0.0, 0.9), 0.0, tuple(sc), (th, 0, 0), segs=1)
    w = []
    glow = mat('okno', 'dfe8f5', 0.3, 0.0, 2.2)
    acc = mat('okno_z', '3ddc6e', 0.3, 0.0, 2.6)
    w.append(rbox('pasek', (0.3, 0.0004, 0.008), mat('pasek', '2a3a55', 0.3, 0.0, 1.4), 0.0, tuple(sc + up * 0.091 + nrm * 0.0004), (th, 0, 0), segs=1))
    for k in range(7):
        ln = rnd.uniform(0.05, 0.13)
        w.append(rbox('wiersz%d' % k, (ln, 0.0004, 0.0045), acc if k in (2, 5) else glow, 0.0, tuple(sc + Vector((-0.135 + ln / 2, 0, 0)) + up * (0.066 - k * 0.016) + nrm * 0.0004), (th, 0, 0), segs=1))
    w.append(rbox('okno', (0.1, 0.0004, 0.1), mat('okno_t', '1c2c48', 0.3, 0.0, 1.2), 0.0, tuple(sc + Vector((0.09, 0, 0)) + up * 0.01 + nrm * 0.0003), (th, 0, 0), segs=1))
    for k in range(4):
        hbar = 0.02 + rnd.uniform(0.0, 0.05)
        w.append(rbox('slupek%d' % k, (0.014, 0.0004, hbar), acc, 0.0, tuple(sc + Vector((0.058 + k * 0.021, 0, 0)) + up * (-0.035 + hbar / 2) + nrm * 0.0006), (th, 0, 0), segs=1))
    join('EkranOkna', w)
    export('dom_laptop')


def dom_waga():
    """waga precyzyjna: płaski czarny korpus, szczotkowana szalka, podświetlany wyświetlacz i dotykowe pola, poziomica; obok odważnik, woreczki, słoik, łyżeczka"""
    reset()
    dark = mat('korpus', '111215', 0.22)
    st = mat('stal', 'c4c8cc', 0.3, 0.9)
    p = [rbox('korpus', (0.16, 0.225, 0.02), dark, 0.008, (0, 0, 0.012), segs=4)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(lathe('nozka', [(0.0, 0.0), (0.009, 0.0), (0.009, 0.003)], mat('guma', '3a3d42', 0.85), 10, loc=(sx * 0.062, sy * 0.095, -0.001)))
            p.append(lathe('trzpien', [(0.0, 0.022), (0.006, 0.022), (0.006, 0.028), (0.0, 0.028)], st, 8, loc=(sx * 0.05, 0.03 + sy * 0.05, 0)))
    p.append(rbox('szalka', (0.14, 0.14, 0.005), st, 0.01, (0, 0.03, 0.0305), segs=4))
    p.append(rbox('szlif', (0.118, 0.118, 0.0006), mat('szlif', 'aeb2b7', 0.45, 0.9), 0.008, (0, 0.03, 0.0333)))
    for k in range(2):
        p.append(lathe('pole%d' % k, [(0.0075, 0.0), (0.009, 0.0), (0.009, 0.0006), (0.0075, 0.0006)], mat('pole', '5a5e66', 0.4, 0.4), 14, loc=(0.036 + k * 0.024, -0.086, 0.022)))
    p.append(lathe('poziomica', [(0.0, 0.0), (0.007, 0.0), (0.007, 0.003), (0.0, 0.004)], mat('poziomica', '9fe06a', 0.1, 0.0, 0.3, 0.8), 12, loc=(-0.066, -0.05, 0.022)))
    # odważnik kalibracyjny, słoik z zakrętką, łyżeczka
    p.append(lathe('odwaznik', [(0.0, 0.0), (0.013, 0.0), (0.013, 0.02), (0.006, 0.023), (0.006, 0.027), (0.009, 0.029), (0.009, 0.033), (0.0, 0.033)], mat('mosiadz', 'b89a4a', 0.3, 0.9), 14, loc=(0.13, -0.08, 0)))
    p.append(lathe('sloik', [(0.0, 0.0), (0.04, 0.0), (0.042, 0.004), (0.042, 0.055), (0.038, 0.06), (0.0, 0.06)], mat('sloik', '2a2d33', 0.25, 0.0, 0.0, 0.85), 18, loc=(-0.2, 0.02, 0)))
    p.append(lathe('zakretka', [(0.0, 0.058), (0.044, 0.058), (0.044, 0.074), (0.04, 0.078), (0.0, 0.078)], mat('zakretka', '15161a', 0.5), 18, loc=(-0.2, 0.02, 0)))
    p.append(tube('lyzeczka', [(-0.12, -0.09, 0.003), (-0.17, -0.07, 0.005), (-0.215, -0.065, 0.003)], 0.0025, st, 6))
    p.append(lathe('czerpak', [(0.0, 0.0), (0.011, 0.002), (0.013, 0.006)], st, 12, loc=(-0.113, -0.093, 0.001)))
    ob = join('Waga', p)
    weather([ob], 1024, 0.2, 0.3)
    bags = []
    r2 = random.Random(4)
    for k in range(7):
        bags.append(rbox('woreczek%d' % k, (0.07, 0.1, 0.0012), mat('folia', 'e6eef2', 0.15, 0.0, 0.0, 0.45), 0.0004, (0.2 + r2.uniform(-0.01, 0.01), 0.03 + r2.uniform(-0.012, 0.012), 0.001 + k * 0.0016), (0, 0, r2.uniform(-0.3, 0.3))))
        bags.append(rbox('struna%d' % k, (0.068, 0.004, 0.0016), mat('struna', '2a6ac8', 0.5), 0.0, (0.2, 0.074, 0.001 + k * 0.0016), segs=1))
    join('Woreczki', bags)
    rbox('Wyswietlacz', (0.075, 0.028, 0.0008), mat('lcd', 'bfe4ff', 0.25, 0.0, 1.8), 0.002, (-0.028, -0.086, 0.0226))
    text('Cyfry', '0.00 g', 0.018, mat('cyfry', '0a1a2a', 0.5), (-0.028, -0.086, 0.0236), (0, 0, 0), 0.0002)
    export('dom_waga')


def dom_krzeslo():
    """krzesło obrotowe: pięcioramienna podstawa na kółkach, siłownik, tapicerowane siedzisko, siatkowe oparcie na ramie, podłokietniki, dźwignia"""
    reset()
    pl = mat('tworzywo', '1c1d21', 0.5)
    fab = mat('tkanina', '2d3036', 0.95)
    st = mat('chrom', 'b9bcc2', 0.2, 0.9)
    p = [lathe('piasta', [(0.0, 0.07), (0.045, 0.07), (0.045, 0.12), (0.03, 0.13), (0.0, 0.13)], pl, 14)]
    for k in range(5):
        a = k * math.tau / 5 + 0.3
        ex, ey = math.cos(a) * 0.3, math.sin(a) * 0.3
        p.append(tube('ramie', [(math.cos(a) * 0.03, math.sin(a) * 0.03, 0.105), (ex * 0.6, ey * 0.6, 0.085), (ex, ey, 0.07)], 0.02, pl, 8, taper=0.014))
        for d in (-0.014, 0.014):
            w = lathe('kolko', [(0.0, -0.01), (0.022, -0.01), (0.027, 0.0), (0.022, 0.01), (0.0, 0.01)], pl, 10)
            w.rotation_euler = (0, R90, a + R90)
            w.location = (ex - math.sin(a) * d, ey + math.cos(a) * d, 0.027)
            p.append(w)
        p.append(lathe('trzpien', [(0.0, 0.03), (0.008, 0.03), (0.008, 0.065), (0.0, 0.065)], st, 8, loc=(ex, ey, 0)))
    p.append(lathe('silownik', [(0.0, 0.12), (0.025, 0.12), (0.025, 0.25), (0.016, 0.25), (0.016, 0.4), (0.0, 0.4)], st, 14))
    p.append(lathe('oslona', [(0.03, 0.13), (0.033, 0.13), (0.03, 0.27), (0.027, 0.27)], pl, 14))
    p.append(rbox('mechanizm', (0.2, 0.24, 0.04), pl, 0.01, (0, 0.02, 0.415)))
    p.append(tube('dzwignia', [(0.09, 0.0, 0.41), (0.2, -0.02, 0.4), (0.24, -0.02, 0.39)], 0.007, pl, 6))
    p.append(rbox('dzwignia_k', (0.04, 0.02, 0.012), pl, 0.004, (0.25, -0.02, 0.39)))
    for sx in (-1, 1):
        p.append(tube('podl_slup', [(sx * 0.12, 0.04, 0.42), (sx * 0.27, 0.04, 0.43), (sx * 0.28, 0.04, 0.64)], 0.016, pl, 8))
        p.append(rbox('podlokietnik', (0.07, 0.26, 0.03), pl, 0.012, (sx * 0.28, 0.0, 0.66), segs=3))
    # rama oparcia i łącznik
    p.append(tube('lacznik', [(0, 0.1, 0.42), (0, 0.26, 0.44), (0, 0.29, 0.62)], 0.022, pl, 8))
    p.append(tube('rama', [(-0.2, 0.27, 0.56), (-0.22, 0.3, 0.8), (-0.19, 0.33, 1.02), (0.0, 0.34, 1.06), (0.19, 0.33, 1.02), (0.22, 0.3, 0.8), (0.2, 0.27, 0.56), (0.0, 0.26, 0.53), (-0.2, 0.27, 0.56), (-0.21, 0.28, 0.66)], 0.016, pl, 8))
    p.append(tube('ledzwie', [(-0.2, 0.27, 0.7), (0.0, 0.25, 0.7), (0.2, 0.27, 0.7)], 0.012, pl, 6))
    fr = join('Stelaz', p)
    weather([fr], 1024, 0.25, 0.3)
    s = [rbox('siedzisko', (0.5, 0.48, 0.075), fab, 0.034, (0, -0.01, 0.47), segs=4)]
    for k in range(3):
        s.append(rbox('przeszycie', (0.47, 0.006, 0.078), mat('szew', '202227', 0.95), 0.003, (0, -0.15 + k * 0.14, 0.47), segs=1))

    def bulge(u, v):
        return (0.0, 0.03 * (1.0 - (u * 2 - 1) ** 2) + 0.012 * math.sin(v * math.pi), 0.0)
    back = sheet('siatka', 0.4, 0.48, 12, 12, bulge, mat('siatka', '34373d', 0.9), loc=(0, 0.27, 0.55))
    back.rotation_euler = (math.radians(-9), 0, 0)
    s.append(back)
    so = join('Tapicerka', s)
    weather([so], 1024, 0.3, 0.15, (0.1, 0.1, 0.11))
    export('dom_krzeslo')


def dom_szafa():
    """szafa dwudrzwiowa 1,3 × 0,58 × 1,9 m: grafitowy korpus na cokole, fronty w okleinie dębowej ze szczelinami, pionowe uchwyty, lustro na skrzydle"""
    reset()
    W, D, H = 1.3, 0.58, 1.9
    gr = mat('korpus', '34373c', 0.5)
    oak = mat('okleina', 'd4bd98', 0.55)
    p = [rbox('korpus', (W, D, H - 0.08), gr, 0.004, (0, 0, 0.08 + (H - 0.08) / 2))]
    p.append(rbox('cokol', (W - 0.04, D - 0.06, 0.08), mat('cokol', '1b1c1f', 0.6), 0.002, (0, 0.02, 0.04)))
    p.append(rbox('wieniec', (W + 0.012, D + 0.008, 0.02), gr, 0.004, (0, -0.002, H - 0.01)))
    hd = mat('uchwyt', '15161a', 0.4, 0.5)
    dw = (W - 0.012) / 2
    for sx in (-1, 1):
        x = sx * (dw / 2 + 0.002)
        p.append(rbox('front', (dw - 0.004, 0.018, H - 0.13), oak, 0.003, (x, -D / 2 - 0.009, 0.09 + (H - 0.13) / 2)))
        p.append(rbox('uchwyt', (0.014, 0.022, 0.5), hd, 0.004, (sx * 0.05, -D / 2 - 0.03, 1.0)))
        for z in (0.3, 1.0, 1.7):
            p.append(rbox('zawias', (0.008, 0.014, 0.06), mat('zawias', '9a9ea4', 0.3, 0.8), 0.002, (sx * (W / 2 - 0.002), -D / 2 - 0.004, z)))
    # słoje okleiny: delikatne pionowe pasy w dwóch odcieniach
    for k in range(9):
        x = -W / 2 + 0.07 + k * 0.145
        if abs(x) < 0.06:
            continue
        p.append(rbox('sloj', (rnd.uniform(0.012, 0.03), 0.0006, H - 0.14), mat('sloj%d' % (k % 2), 'c9b28c' if k % 2 else 'dcc7a4', 0.55), 0.0, (x, -D / 2 - 0.0184, 0.09 + (H - 0.13) / 2), segs=1))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(lathe('stopka', [(0.0, 0.0), (0.02, 0.0), (0.02, 0.006), (0.0, 0.006)], mat('cokol', '1b1c1f', 0.6), 8, loc=(sx * (W / 2 - 0.08), sy * (D / 2 - 0.07), -0.001)))
    ob = join('Szafa', p)
    weather([ob], 1024, 0.2, 0.2)
    rbox('Lustro', (0.32, 0.003, 1.35), mat('lustro', 'b8c4cc', 0.12, 0.35), 0.004, (0.36, -D / 2 - 0.0195, 1.02))
    export('dom_szafa')


ALL = (dom_biurko, dom_laptop, dom_waga, dom_krzeslo, dom_szafa)
only = [a for a in sys.argv[sys.argv.index('--') + 1:]] if '--' in sys.argv else []
for f in ALL:
    if not only or f.__name__ in only:
        f()
