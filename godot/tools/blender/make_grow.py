"""Zestaw ogrodnika: doniczka, konewka, butelka nawozu, sekator, lampa LED do uprawy."""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *


def doniczka():
    reset()
    terra = mat('terakota', 'a8623f', 0.9)
    terra_in = mat('terakota_srodek', '7c452c', 0.95)
    H = 0.27
    # ścianka z rantem i wnętrzem — ziemia leży poniżej krawędzi
    body = lathe('Pot', [(0.0, 0.0), (0.118, 0.0), (0.124, 0.006), (0.158, H - 0.05), (0.176, H - 0.048), (0.18, H - 0.04), (0.18, H - 0.006), (0.174, H),
                         (0.166, H), (0.16, H - 0.006), (0.158, H - 0.045)], terra, 40)
    inner = lathe('PotIn', [(0.158, H - 0.045), (0.15, H - 0.06), (0.0, H - 0.06)], terra_in, 40)
    saucer = lathe('Saucer', [(0.0, -0.001), (0.17, -0.001), (0.196, 0.004), (0.2, 0.022), (0.192, 0.022), (0.186, 0.008), (0.0, 0.008)], terra, 40)
    join('Pot', [body, inner, saucer])
    # ziemia: lekko wypukła, z grudkami — osobny obiekt, bo gra przyciemnia ją po podlaniu
    soil = lathe('Soil', [(0.156, H - 0.04), (0.15, H - 0.03), (0.09, H - 0.024), (0.0, H - 0.02)], mat('ziemia', '3a2a1e', 1.0), 28)
    import random
    rnd = random.Random(3)
    clods = []
    for k in range(16):
        a = rnd.uniform(0, 6.283)
        r = rnd.uniform(0.02, 0.135)
        s = rnd.uniform(0.008, 0.02)
        c = rbox('c%d' % k, (s * 1.6, s * 1.3, s), mat('grudka', '2a1d14', 1.0), s * 0.35, (math.cos(a) * r, math.sin(a) * r, H - 0.024 + s * 0.2), (rnd.uniform(0, 1), rnd.uniform(0, 1), a), segs=2)
        clods.append(c)
    join('Clods', clods)
    fert = empty('Fert')
    gr = []
    for k in range(14):
        a = k * 2.4
        r = 0.03 + (k % 5) * 0.022
        gr.append(lathe('g%d' % k, [(0.0, -0.005), (0.005, -0.003), (0.006, 0.0), (0.005, 0.003), (0.0, 0.005)], mat('granulka_a' if k % 2 else 'granulka_b', '8fc7ff' if k % 2 else 'f2f2ea', 0.5), 8,
                        loc=(math.cos(a) * r, math.sin(a) * r, H - 0.012)))
    join('FertMesh', gr, fert)
    export('doniczka')


def konewka():
    reset()
    green = mat('blacha_zielona', '3f7a4a', 0.38, 0.55)
    dark = mat('blacha_ciemna', '2a5534', 0.45, 0.55)
    brass = mat('mosiadz', 'b08a3c', 0.3, 0.9)
    body = lathe('body', [(0.0, 0.0), (0.092, 0.0), (0.098, 0.006), (0.098, 0.012), (0.094, 0.016), (0.09, 0.15), (0.094, 0.154), (0.094, 0.166), (0.088, 0.17), (0.0, 0.172)], green, 36)
    hoop = lathe('hoop', [(0.091, 0.08), (0.096, 0.083), (0.096, 0.09), (0.091, 0.093)], dark, 36)
    # dzióbek w stronę −X, rozszerzony sitkiem
    spout = tube('spout', [(-0.07, 0, 0.04), (-0.17, 0, 0.11), (-0.285, 0, 0.19)], 0.02, green, 12, taper=0.012)
    rose = lathe('rose', [(0.012, 0.0), (0.016, 0.004), (0.036, 0.03), (0.036, 0.036), (0.0, 0.04)], brass, 20)
    rose.rotation_euler = (0, -math.radians(55), 0)
    rose.location = (-0.285, 0, 0.19)
    handle_back = tube('ucho', [(0.085, 0, 0.14), (0.15, 0, 0.15), (0.17, 0, 0.09), (0.14, 0, 0.03), (0.09, 0, 0.03)], 0.008, dark, 10)
    handle_top = tube('palak', [(-0.07, 0, 0.165), (-0.05, 0, 0.225), (0.03, 0, 0.235), (0.07, 0, 0.165)], 0.008, dark, 10)
    join('Konewka', [body, hoop, spout, rose, handle_back, handle_top])
    empty('Spout', (-0.31, 0, 0.21))
    export('konewka')


def nawoz():
    reset()
    pl = mat('plastik_zielony', '2f8f4e', 0.35)
    cap = mat('nakretka', 'e8e4d6', 0.45)
    lab = mat('etykieta', 'f0ead2', 0.75)
    body = lathe('body', [(0.0, 0.0), (0.046, 0.0), (0.05, 0.005), (0.05, 0.14), (0.046, 0.152), (0.026, 0.172), (0.021, 0.178), (0.021, 0.186)], pl, 28)
    label = lathe('label', [(0.0508, 0.045), (0.0508, 0.115)], lab, 28)
    stripe = lathe('stripe', [(0.0512, 0.07), (0.0512, 0.085)], mat('pasek', '1f6b38', 0.6), 28)
    c = lathe('cap', [(0.024, 0.182), (0.025, 0.184), (0.025, 0.212), (0.022, 0.216), (0.0, 0.216)], cap, 20)
    join('Nawoz', [body, label, stripe, c])
    empty('Mouth', (0, 0, 0.22))
    export('nawoz')


def sekator():
    reset()
    steel = mat('stal', 'b9bec6', 0.22, 0.9)
    grip = mat('rekojesc', 'c2302a', 0.55)
    for k, sgn in ((0, 1.0), (1, -1.0)):
        arm = empty('A' if k == 0 else 'B')
        # ostrze: spłaszczona, zwężająca się blaszka; rękojeść: gruba rurka po drugiej stronie nitu
        blade = rbox('ostrze', (0.1, 0.022, 0.004), steel, 0.0015, (-0.055, 0.006 * sgn, 0.0025 * sgn), (0, 0, 0.1 * sgn), segs=2)
        tip = rbox('czubek', (0.035, 0.012, 0.004), steel, 0.0015, (-0.115, 0.012 * sgn, 0.0025 * sgn), (0, 0, 0.32 * sgn), segs=2)
        shank = rbox('trzon', (0.05, 0.012, 0.006), steel, 0.002, (0.025, -0.008 * sgn, 0.0), (0, 0, -0.25 * sgn), segs=2)
        g = tube('rek', [(0.045, -0.014 * sgn, 0), (0.1, -0.028 * sgn, 0), (0.16, -0.026 * sgn, 0)], 0.009, grip, 10)
        join('Arm%d' % k, [blade, tip, shank, g], arm)
    lathe('nit', [(0.0, -0.006), (0.007, -0.006), (0.008, -0.004), (0.008, 0.004), (0.007, 0.006), (0.0, 0.006)], mat('nit', '6a6e75', 0.3, 0.85), 14)
    export('sekator')


def lampa_led():
    reset()
    H = 1.98
    alu = mat('alu_czarne', '1b1c20', 0.42, 0.7)
    steel = mat('stal_ciemna', '2b2e33', 0.45, 0.8)
    parts = [rbox('panel', (1.5, 0.62, 0.035), alu, 0.008, (0, 0, H))]
    for k in range(13):
        parts.append(rbox('zebro%d' % k, (1.42, 0.008, 0.03), alu, 0.002, (0, -0.27 + k * 0.045, H + 0.03), segs=1))
    parts.append(rbox('zasilacz', (0.26, 0.11, 0.05), mat('zasilacz', '2a2c31', 0.5, 0.5), 0.008, (0.45, 0, H + 0.07)))
    for sx in (-0.62, 0.62):
        for sy in (-0.22, 0.22):
            parts.append(tube('linka', [(sx, sy, H + 0.02), (sx * 0.96, sy * 0.9, H + 0.9)], 0.003, steel, 6))
            parts.append(lathe('zaczep', [(0.0, 0.0), (0.012, 0.0), (0.012, 0.012), (0.0, 0.016)], steel, 10, loc=(sx, sy, H + 0.017)))
    parts.append(tube('kabel', [(0.58, 0, H + 0.08), (0.66, 0.02, H + 0.3), (0.7, 0.0, H + 0.9)], 0.006, mat('kabel', '0c0c0e', 0.8), 8))
    join('Lampa', parts)
    bars = empty('Bars')
    off = empty('BarsOff')
    on_p, off_p = [], []
    for sy in (-0.2, 0.0, 0.2):
        on_p.append(rbox('led', (1.38, 0.075, 0.012), mat('led_on', 'e24bff', 0.4, 0.0, 4.5), 0.003, (0, sy, H - 0.022), segs=1))
        off_p.append(rbox('ledoff', (1.38, 0.075, 0.012), mat('led_off', '3a2a40', 0.5), 0.003, (0, sy, H - 0.022), segs=1))
    join('BarsMesh', on_p, bars)
    join('BarsOffMesh', off_p, off)
    export('lampa_led')


for f in (doniczka, konewka, nawoz, sekator, lampa_led):
    f()
