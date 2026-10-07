"""Cztery klasy wag na stół roboczy (przód = −Y, spód na z = 0, środek szalki mniej więcej w (0, 0.03)):
waga_kuchenna — biała plastikowa z miską; waga_jubilerska — kieszonkowa z odchylaną klapką i odważnikiem;
waga_lab — analityczna ze szklaną osłoną przeciwwiatrową; waga_dozownik — półautomat z lejkiem, rynną i tacką porcji.
Wyświetlacze, cyfry, szkło i porcja towaru są osobnymi obiektami bez wypalanego brudu.
Użycie: Blender -b --python tools/blender/make_wagi.py [-- nazwa …]"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
from lib import _finish

R90 = math.radians(90)


def _lcd(x, y, z, w, h, body, size, color='bfe4ff', rx=0.0):
    rbox('Wyswietlacz', (w, h, 0.0008), mat('lcd', color, 0.25, 0.0, 1.8), 0.002, (x, y, z), (rx, 0, 0))
    text('Cyfry', body, size, mat('cyfry', '0a1a2a', 0.5), (x, y - math.sin(rx) * 0.001, z + 0.001), (rx, 0, 0), 0.0002)


def _porcja(x, y, z, r=0.03, kolor='3f7a3a'):
    """kupka suszu na szalce: spłaszczona, nieregularna"""
    rnd = random.Random(int(r * 1000))
    pr = []
    for i in range(7):
        a = i * 0.9
        pr.append(lathe('grudka%d' % i, [(0.0, 0.0), (r * 0.45, 0.0), (r * 0.5, r * 0.18), (r * 0.3, r * 0.4), (0.0, r * 0.45)], mat('susz', kolor, 0.95), 7,
                        loc=(x + math.cos(a) * r * rnd.uniform(0.0, 0.55), y + math.sin(a) * r * rnd.uniform(0.0, 0.55), z + rnd.uniform(0.0, r * 0.15))))
    join('Porcja', pr)


def _lyzeczka(p, st, x, y):
    p.append(tube('lyzeczka', [(x, y, 0.003), (x - 0.05, y + 0.02, 0.005), (x - 0.095, y + 0.025, 0.003)], 0.0025, st, 6))
    p.append(lathe('czerpak', [(0.0, 0.0), (0.011, 0.002), (0.013, 0.006)], st, 10, loc=(x + 0.007, y - 0.003, 0.001)))


def waga_kuchenna():
    """stara kuchenna: pożółkły plastik, stalowa miska, mały szary wyświetlacz, dwa gumowe przyciski, naklejka z zakresem"""
    reset()
    pl = mat('plastik', 'e2dccb', 0.5)
    plc = mat('plastik_c', 'bdb6a2', 0.55)
    st = mat('stal', 'c4c8cc', 0.3, 0.9)
    guma = mat('guma', '3a3d42', 0.85)
    p = [rbox('korpus', (0.2, 0.24, 0.04), pl, 0.015, (0, 0, 0.022), segs=4),
         rbox('cokol', (0.18, 0.22, 0.006), plc, 0.004, (0, 0, 0.003)),
         rbox('panel', (0.2, 0.06, 0.012), plc, 0.006, (0, -0.092, 0.04), (math.radians(18), 0, 0))]
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(lathe('nozka', [(0.0, 0.0), (0.011, 0.0), (0.011, 0.004)], guma, 8, loc=(sx * 0.075, sy * 0.095, -0.002)))
    # talerz pod miskę i miska
    p.append(lathe('talerz', [(0.0, 0.042), (0.062, 0.042), (0.066, 0.046), (0.062, 0.05), (0.0, 0.05)], plc, 20, loc=(0, 0.03, 0)))
    p.append(lathe('miska', [(0.0, 0.05), (0.05, 0.05), (0.085, 0.07), (0.105, 0.105), (0.108, 0.108), (0.103, 0.108), (0.083, 0.074), (0.048, 0.055), (0.0, 0.055)], st, 24, loc=(0, 0.03, 0)))
    for k in range(2):
        p.append(lathe('przycisk%d' % k, [(0.0, 0.0), (0.009, 0.0), (0.009, 0.003), (0.006, 0.005), (0.0, 0.005)], mat('przycisk%d' % k, ['a8322a', '56606a'][k], 0.6), 10,
                       loc=(0.045 + k * 0.03, -0.1, 0.043)))
    p.append(rbox('naklejka', (0.05, 0.02, 0.0006), mat('naklejka', 'f2efe6', 0.6), 0.002, (-0.07, -0.02, 0.0425)))
    # obok: słoik po dżemie z towarem, łyżeczka, kartka z rachunkami
    p.append(lathe('sloik', [(0.0, 0.0), (0.035, 0.0), (0.038, 0.004), (0.038, 0.07), (0.03, 0.08), (0.03, 0.088), (0.0, 0.088)], mat('sloik', '8fa39a', 0.15, 0.1), 16, loc=(-0.21, 0.04, 0)))
    p.append(lathe('zakretka', [(0.0, 0.086), (0.034, 0.086), (0.034, 0.098), (0.0, 0.1)], mat('zakretka', 'b0281e', 0.5, 0.4), 16, loc=(-0.21, 0.04, 0)))
    p.append(rbox('kartka', (0.1, 0.14, 0.0006), mat('papier', 'efeade', 0.9), 0.0, (0.2, -0.02, 0.0005), (0, 0, 0.2), segs=1))
    p.append(tube('olowek', [(0.17, -0.07, 0.004), (0.25, 0.01, 0.004)], 0.0035, mat('olowek', 'd9a514', 0.6), 6))
    _lyzeczka(p, st, -0.1, -0.1)
    ob = join('Waga', p)
    weather([ob], 1024, 0.45, 0.5, (0.14, 0.12, 0.08))
    _lcd(-0.03, -0.098, 0.0445, 0.07, 0.026, '13 g', 0.016, 'c9d2c0', math.radians(18))
    _porcja(0, 0.03, 0.056, 0.035)
    export('waga_kuchenna')


def waga_jubilerska():
    """kieszonkowa waga jubilerska: czarny korpus, szczotkowana szalka, niebieski wyświetlacz, odchylona dymna klapka, odważnik 50 g, pęseta"""
    reset()
    dark = mat('korpus', '111215', 0.22)
    st = mat('stal', 'c4c8cc', 0.3, 0.9)
    p = [rbox('korpus', (0.13, 0.2, 0.02), dark, 0.008, (0, 0, 0.012), segs=4)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(lathe('nozka', [(0.0, 0.0), (0.008, 0.0), (0.008, 0.003)], mat('guma', '3a3d42', 0.85), 8, loc=(sx * 0.05, sy * 0.085, -0.001)))
    p.append(rbox('szalka', (0.105, 0.105, 0.004), st, 0.008, (0, 0.035, 0.0245), segs=4))
    p.append(rbox('szlif', (0.09, 0.09, 0.0006), mat('szlif', 'aeb2b7', 0.45, 0.9), 0.006, (0, 0.035, 0.0268)))
    for k in range(3):
        p.append(lathe('pole%d' % k, [(0.0065, 0.0), (0.008, 0.0), (0.008, 0.0006), (0.0065, 0.0006)], mat('pole', '5a5e66', 0.4, 0.4), 12, loc=(0.012 + k * 0.02, -0.078, 0.022)))
    # zawiasy klapki i odważnik kalibracyjny w mosiądzu, pęseta, mała łopatka
    for sx in (-1, 1):
        p.append(lathe('zawias', [(0.0, 0.0), (0.004, 0.0), (0.004, 0.012), (0.0, 0.012)], dark, 6, loc=(sx * 0.05, 0.1, 0.014)))
    p.append(lathe('odwaznik', [(0.0, 0.0), (0.013, 0.0), (0.013, 0.02), (0.006, 0.023), (0.006, 0.027), (0.009, 0.029), (0.009, 0.033), (0.0, 0.033)], mat('mosiadz', 'b89a4a', 0.3, 0.9), 14, loc=(0.12, -0.06, 0)))
    p.append(tube('peseta_a', [(0.1, 0.02, 0.003), (0.19, 0.06, 0.003)], 0.002, st, 5))
    p.append(tube('peseta_b', [(0.1, 0.02, 0.003), (0.188, 0.068, 0.003)], 0.002, st, 5))
    p.append(lathe('pojemnik', [(0.0, 0.0), (0.03, 0.0), (0.032, 0.003), (0.032, 0.03), (0.0, 0.03)], mat('pojemnik', '1c1e22', 0.4), 14, loc=(-0.15, 0.03, 0)))
    p.append(lathe('wieczko', [(0.0, 0.0), (0.034, 0.0), (0.034, 0.006), (0.0, 0.007)], mat('wieczko', '2a6ac8', 0.5), 14, loc=(-0.15, -0.05, 0)))
    _lyzeczka(p, st, -0.09, -0.09)
    ob = join('Waga', p)
    weather([ob], 1024, 0.2, 0.3)
    # dymna klapka odchylona do tyłu (osobno — przezroczysta)
    rbox('Klapka', (0.128, 0.004, 0.19), mat('klapka', '30343a', 0.15, 0.0, 0.0, 0.45), 0.004, (0, 0.118, 0.105), (math.radians(-12), 0, 0))
    _lcd(-0.03, -0.078, 0.0226, 0.055, 0.024, '1.00 g', 0.015)
    _porcja(0, 0.035, 0.027, 0.022)
    export('waga_jubilerska')


def waga_lab():
    """waga analityczna: jasny korpus z panelem, okrągła szalka na trzpieniu, szklana osłona przeciwwiatrowa w stalowej ramie,
    przesuwne drzwiczki z gałką, poziomica, nóżki do poziomowania; obok naczynko wagowe i szpatułka"""
    reset()
    jas = mat('korpus', 'd9dcdd', 0.4)
    szary = mat('panel', '42474d', 0.45)
    st = mat('stal', 'c4c8cc', 0.3, 0.9)
    p = [rbox('korpus', (0.21, 0.34, 0.07), jas, 0.012, (0, 0, 0.04), segs=4),
         rbox('panel', (0.2, 0.09, 0.012), szary, 0.006, (0, -0.135, 0.072), (math.radians(24), 0, 0)),
         rbox('podstawa_oslony', (0.2, 0.2, 0.008), szary, 0.004, (0, 0.06, 0.079))]
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(lathe('nozka', [(0.0, 0.0), (0.014, 0.0), (0.014, 0.004), (0.006, 0.006), (0.006, 0.012), (0.0, 0.012)], st, 10, loc=(sx * 0.085, sy * 0.15, -0.006)))
    # szalka na trzpieniu
    p.append(lathe('trzpien', [(0.0, 0.083), (0.006, 0.083), (0.006, 0.098), (0.0, 0.098)], st, 8, loc=(0, 0.06, 0)))
    p.append(lathe('szalka', [(0.0, 0.098), (0.045, 0.098), (0.047, 0.1), (0.045, 0.102), (0.0, 0.102)], st, 22, loc=(0, 0.06, 0)))
    p.append(lathe('pierscien', [(0.055, 0.083), (0.06, 0.083), (0.06, 0.09), (0.055, 0.09)], st, 22, loc=(0, 0.06, 0)))
    # rama osłony: cztery słupki i wieniec, uchwyt górnej szyby, gałki drzwiczek
    h0, h1 = 0.083, 0.31
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(rbox('slupek', (0.008, 0.008, h1 - h0), st, 0.002, (sx * 0.096, 0.06 + sy * 0.096, (h0 + h1) / 2)))
        p.append(rbox('wieniec_b', (0.008, 0.2, 0.008), st, 0.002, (sx * 0.096, 0.06, h1)))
        p.append(lathe('galka', [(0.0, 0.0), (0.006, 0.0), (0.008, 0.006), (0.005, 0.012), (0.0, 0.013)], szary, 8, loc=(sx * 0.103, -0.01, 0.19)))
    for sy in (-1, 1):
        p.append(rbox('wieniec_f', (0.2, 0.008, 0.008), st, 0.002, (0, 0.06 + sy * 0.096, h1)))
    p.append(rbox('uchwyt', (0.05, 0.012, 0.008), szary, 0.003, (0, 0.0, h1 + 0.008)))
    # panel: klawisze, poziomica
    for k in range(4):
        p.append(rbox('klawisz%d' % k, (0.022, 0.014, 0.003), mat('klawisz', 'e8e8e2', 0.5), 0.003, (0.03 + (k % 2) * 0.03, -0.128 - (k // 2) * 0.022, 0.079 - (k // 2) * 0.0098), (math.radians(24), 0, 0)))
    p.append(lathe('poziomica', [(0.0, 0.0), (0.009, 0.0), (0.009, 0.003), (0.0, 0.004)], mat('poziomica', '9fe06a', 0.1, 0.0, 0.3), 12, loc=(-0.08, -0.07, 0.075)))
    # obok: naczynka wagowe, szpatułka, notes
    for k in range(3):
        p.append(lathe('naczynko%d' % k, [(0.0, 0.0), (0.02, 0.0), (0.024, 0.012), (0.022, 0.012), (0.019, 0.002), (0.0, 0.002)], mat('alu', 'cfd3d6', 0.3, 0.9), 12, loc=(0.17 + k * 0.012, -0.02 + k * 0.05, 0)))
    p.append(tube('szpatulka', [(0.15, -0.13, 0.003), (0.24, -0.1, 0.003)], 0.0025, st, 5))
    p.append(rbox('szpatulka_k', (0.03, 0.01, 0.001), st, 0.0, (0.255, -0.095, 0.003), (0, 0, 0.32), segs=1))
    p.append(rbox('notes', (0.11, 0.15, 0.008), mat('notes', '23324d', 0.7), 0.003, (-0.2, -0.02, 0.004), (0, 0, -0.15)))
    p.append(rbox('notes_k', (0.1, 0.14, 0.001), mat('papier', 'efeade', 0.9), 0.0, (-0.2, -0.02, 0.0086), (0, 0, -0.15), segs=1))
    ob = join('Waga', p)
    weather([ob], 1024, 0.2, 0.25)
    # szyby osłony (osobno — przezroczyste)
    g = mat('szklo', 'cfe3e6', 0.05, 0.0, 0.0, 0.22)
    sz = [rbox('szyba_f', (0.184, 0.002, h1 - h0 - 0.01), g, 0.0, (0, 0.06 - 0.096, (h0 + h1) / 2), segs=1),
          rbox('szyba_b', (0.184, 0.002, h1 - h0 - 0.01), g, 0.0, (0, 0.06 + 0.096, (h0 + h1) / 2), segs=1),
          rbox('szyba_g', (0.184, 0.184, 0.002), g, 0.0, (0, 0.06, h1 - 0.002), segs=1)]
    for sx in (-1, 1):
        sz.append(rbox('szyba_bok', (0.002, 0.184, h1 - h0 - 0.01), g, 0.0, (sx * 0.096, 0.06, (h0 + h1) / 2), segs=1))
    join('Szklo', sz)
    _lcd(-0.04, -0.137, 0.0796, 0.085, 0.03, '1.000 g', 0.017, 'bfe4ff', math.radians(24))
    _porcja(0, 0.06, 0.102, 0.02)
    export('waga_lab')


def waga_dozownik():
    """półautomat: stalowy lejek zasypowy na kolumnie, wibracyjna rynna, kubek na szalce, panel z klawiaturą,
    a obok tacka z rzędem odmierzonych porcji w pojemniczkach"""
    reset()
    ciem = mat('korpus', '2b3036', 0.4, 0.5)
    st = mat('stal', 'c4c8cc', 0.3, 0.9)
    stm = mat('stal_m', '9ea4a8', 0.45, 0.85)
    p = [rbox('korpus', (0.26, 0.34, 0.07), ciem, 0.012, (0, 0, 0.04), segs=4),
         rbox('panel', (0.24, 0.1, 0.014), mat('panel', '191c20', 0.4), 0.006, (0, -0.13, 0.074), (math.radians(26), 0, 0))]
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(lathe('nozka', [(0.0, 0.0), (0.015, 0.0), (0.015, 0.005)], mat('guma', '3a3d42', 0.85), 8, loc=(sx * 0.105, sy * 0.145, -0.002)))
    # szalka i kubek
    p.append(rbox('szalka', (0.11, 0.11, 0.005), st, 0.008, (0.03, -0.01, 0.0775), segs=3))
    p.append(lathe('kubek', [(0.0, 0.08), (0.028, 0.08), (0.034, 0.125), (0.036, 0.125), (0.03, 0.082), (0.0, 0.083)], st, 16, loc=(0.03, -0.01, 0)))
    # kolumna z ramieniem, lejek, zasuwa, rynna wibracyjna
    p.append(tube('kolumna', [(-0.09, 0.13, 0.07), (-0.09, 0.13, 0.36)], 0.012, stm, 10))
    p.append(rbox('stopa_kolumny', (0.06, 0.06, 0.012), stm, 0.004, (-0.09, 0.13, 0.081)))
    p.append(tube('ramie', [(-0.09, 0.13, 0.33), (-0.02, 0.1, 0.33)], 0.009, stm, 8))
    p.append(lathe('lejek', [(0.014, 0.0), (0.016, 0.0), (0.085, 0.13), (0.09, 0.132), (0.09, 0.15), (0.086, 0.15), (0.084, 0.134), (0.014, 0.004)], st, 22, loc=(-0.02, 0.1, 0.24)))
    p.append(rbox('zasuwa', (0.045, 0.03, 0.006), stm, 0.002, (-0.02, 0.1, 0.236)))
    p.append(lathe('silnik', [(0.0, 0.0), (0.022, 0.0), (0.022, 0.04), (0.0, 0.04)], mat('silnik', '1d5fa8', 0.5, 0.3), 10, loc=(-0.02, 0.1, 0.19)))
    ang = math.atan2(0.19 - 0.135, 0.1 - 0.02)
    ln = math.hypot(0.19 - 0.135, 0.1 - 0.02) + 0.04
    yc, zc = 0.055, 0.166
    p.append(rbox('rynna_dno', (0.036, ln, 0.002), st, 0.0, (0.005, yc, zc), (ang, 0, 0.3), segs=1))
    for sx in (-1, 1):
        p.append(rbox('rynna_bok', (0.002, ln, 0.014), st, 0.0, (0.005 + sx * 0.018 * math.cos(0.3), yc + sx * 0.018 * math.sin(0.3), zc + 0.007), (ang, 0, 0.3), segs=1))
    # klawiatura i pokrętło na panelu
    for r in range(3):
        for c in range(3):
            p.append(rbox('klawisz', (0.016, 0.012, 0.003), mat('klawisz', 'd9dcdd', 0.5), 0.002,
                          (0.045 + c * 0.021, -0.112 - r * 0.018, 0.0885 - r * 0.0088), (math.radians(26), 0, 0)))
    p.append(lathe('start', [(0.0, 0.0), (0.011, 0.0), (0.011, 0.004), (0.0, 0.006)], mat('start', '2f9a4a', 0.5), 12, loc=(-0.1, -0.15, 0.0705)))
    p.append(lathe('stop', [(0.0, 0.0), (0.011, 0.0), (0.011, 0.004), (0.0, 0.006)], mat('stop', 'b0281e', 0.5), 12, loc=(-0.1, -0.118, 0.086)))
    # tacka z odmierzonymi porcjami: dwa rzędy pojemniczków z wieczkami
    p.append(rbox('tacka', (0.2, 0.13, 0.006), stm, 0.006, (0.27, -0.02, 0.003)))
    for sy in (-1, 1):
        p.append(rbox('tacka_rant', (0.2, 0.004, 0.012), stm, 0.002, (0.27, -0.02 + sy * 0.063, 0.008)))
    for r in range(2):
        for c in range(4):
            x, y = 0.2 + c * 0.046, -0.05 + r * 0.058
            p.append(lathe('pojemniczek', [(0.0, 0.006), (0.017, 0.006), (0.019, 0.026), (0.0, 0.026)], mat('pojemniczek', '23262b', 0.4), 10, loc=(x, y, 0)))
            if (r + c) % 3 != 0:
                p.append(lathe('wieczko', [(0.0, 0.026), (0.02, 0.026), (0.02, 0.03), (0.0, 0.031)], mat('wieczko', '2a6ac8', 0.5), 10, loc=(x, y, 0)))
    # worek z towarem przy lejku i szufelka
    p.append(rbox('worek', (0.13, 0.09, 0.07), mat('worek', '3c4a2e', 0.9, wzor='tkanina'), 0.03, (-0.24, 0.06, 0.035), (0, 0, 0.2)))
    p.append(rbox('worek_g', (0.11, 0.07, 0.03), mat('worek', '3c4a2e', 0.9, wzor='tkanina'), 0.012, (-0.24, 0.06, 0.082), (0, 0.15, 0.2)))
    p.append(rbox('szufelka', (0.05, 0.07, 0.02), st, 0.006, (-0.23, -0.08, 0.011), (0, 0, -0.4)))
    p.append(tube('szufelka_r', [(-0.245, -0.11, 0.012), (-0.27, -0.16, 0.014)], 0.006, mat('raczka', '15161a', 0.6), 6))
    ob = join('Waga', p)
    weather([ob], 1024, 0.2, 0.3)
    _lcd(-0.03, -0.128, 0.0825, 0.1, 0.032, '1.00 g  x64', 0.014, 'c8ffd2', math.radians(26))
    _porcja(-0.02, 0.1, 0.375, 0.05)
    _porcja2 = lathe('PorcjaKubek', [(0.0, 0.085), (0.027, 0.085), (0.02, 0.1), (0.0, 0.104)], mat('susz', '3f7a3a', 0.95), 10, loc=(0.03, -0.01, 0))
    export('waga_dozownik')


FUNCS = {'waga_kuchenna': waga_kuchenna, 'waga_jubilerska': waga_jubilerska, 'waga_lab': waga_lab, 'waga_dozownik': waga_dozownik}
names = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else list(FUNCS)
for n in names:
    FUNCS[n]()
