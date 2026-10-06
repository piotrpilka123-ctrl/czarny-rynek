"""Rekwizyty: radiomagnetofon do kawalerki i pistolet służbowy policji."""
import sys, os, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *


def radio():
    """radiomagnetofon z lat 90.: dwa głośniki, kieszeń na kasetę, skala, pokrętła, antena, rączka"""
    reset()
    body = mat('obudowa', '2b2d31', 0.55)
    silver = mat('srebrny', 'a9adb3', 0.35, 0.6)
    dark = mat('siatka', '111214', 0.8)
    W, D, H = 0.46, 0.12, 0.22
    parts = [rbox('korpus', (W, D, H), body, 0.018, (0, 0, H / 2), segs=4)]
    parts.append(rbox('front', (W - 0.02, 0.006, H - 0.02), silver, 0.004, (0, -D / 2 - 0.001, H / 2), segs=2))
    for sx in (-0.15, 0.15):
        ring = lathe('ring', [(0.066, 0.0), (0.07, 0.004), (0.07, 0.01), (0.062, 0.012)], silver, 28)
        ring.rotation_euler = (math.radians(90), 0, 0)
        ring.location = (sx, -D / 2 - 0.002, 0.095)
        cone = lathe('membrana', [(0.0, 0.004), (0.018, 0.002), (0.022, 0.006), (0.058, 0.0), (0.062, 0.006)], dark, 28, cap_bottom=False)
        cone.rotation_euler = (math.radians(90), 0, 0)
        cone.location = (sx, -D / 2 - 0.003, 0.095)
        parts += [ring, cone]
    # kieszeń kasety, skala radia, przyciski
    parts.append(rbox('kaseta', (0.13, 0.008, 0.075), dark, 0.004, (0, -D / 2 - 0.004, 0.085), segs=2))
    parts.append(rbox('okienko', (0.09, 0.004, 0.03), mat('szybka', '3b4650', 0.15, 0.2), 0.002, (0, -D / 2 - 0.009, 0.09), segs=1))
    parts.append(rbox('skala', (0.2, 0.004, 0.022), mat('skala', 'e9e2c4', 0.4, 0.0, 0.6), 0.002, (0, -D / 2 - 0.004, 0.178), segs=1))
    parts.append(rbox('wskaznik', (0.004, 0.005, 0.02), mat('czerwony', 'd0302a', 0.4, 0.0, 1.5), 0.001, (0.03, -D / 2 - 0.006, 0.178), segs=1))
    for k in range(5):
        parts.append(rbox('klawisz%d' % k, (0.022, 0.012, 0.012), silver, 0.003, (-0.046 + k * 0.023, -D / 2 + 0.01, H + 0.004), segs=2))
    for sx in (-0.19, 0.19):
        kn = lathe('galka', [(0.0, 0.0), (0.014, 0.0), (0.016, 0.003), (0.015, 0.014), (0.0, 0.015)], silver, 16)
        kn.rotation_euler = (math.radians(90), 0, 0)
        kn.location = (sx, -D / 2 - 0.002, 0.178)
        parts.append(kn)
    parts.append(tube('raczka', [(-0.2, 0, H - 0.01), (-0.2, 0, H + 0.05), (0.2, 0, H + 0.05), (0.2, 0, H - 0.01)], 0.008, body, 10))
    parts.append(tube('antena', [(0.2, 0.04, H), (0.26, 0.04, H + 0.3)], 0.003, silver, 6, taper=0.0015))
    for sx in (-0.19, 0.19):
        parts.append(rbox('nozka', (0.03, 0.08, 0.008), dark, 0.003, (sx, 0, -0.002), segs=1))
    rad = join('Radio', parts)
    weather([rad], 1024, 0.6, 0.6)
    led = rbox('Lampka', (0.008, 0.004, 0.008), mat('dioda', '4ade80', 0.4, 0.0, 4.0), 0.002, (0.13, -D / 2 - 0.004, 0.178), segs=1)
    export('radio')


def pistolet():
    """Pistolet służbowy w typie Glocka 17, modelowany z sylwetki bocznej: zamek z nacięciami i oknem wyrzutnika,
    szkielet z szyną i kabłąkiem, pochylony chwyt z fakturą, lufa, przyrządy, spust, zrzut magazynka. Lufa wzdłuż −X."""
    reset()
    steel = mat('oksyda', '1c1d20', 0.42, 0.75)
    poly = mat('polimer', '17181a', 0.78)
    T = 0.03
    parts = []
    # zamek: prostopadłościan ze ściętym przodem
    parts.append(profile('zamek', [(-0.127, 0.118), (-0.122, 0.141), (0.058, 0.141), (0.061, 0.136), (0.061, 0.118)], T * 0.9, steel, 0.0025))
    # nacięcia do przeładowania z tyłu zamka (po obu stronach)
    for k in range(7):
        for sy in (-1, 1):
            parts.append(rbox('nac%d' % k, (0.0035, 0.0012, 0.018), mat('nac', '0e0f11', 0.6, 0.5), 0.0, (0.02 + k * 0.006, sy * T * 0.455, 0.13), (0, math.radians(12), 0), segs=1))
    parts.append(rbox('okno', (0.03, 0.012, 0.004), mat('lufa_sr', '5a5d63', 0.3, 0.9), 0.001, (-0.02, 0.006, 0.1405), segs=1))
    # szkielet z szyną, kabłąkiem (otwór) i chwytem pochylonym do tyłu
    frame = [(-0.122, 0.117), (-0.122, 0.098), (-0.058, 0.098), (-0.056, 0.092), (-0.05, 0.062), (-0.035, 0.052), (-0.004, 0.052), (0.006, 0.058),
             (0.022, -0.012), (0.03, -0.018), (0.075, -0.01), (0.078, -0.002), (0.062, 0.07), (0.066, 0.098), (0.07, 0.11), (0.066, 0.117)]
    guard = [(-0.044, 0.09), (-0.04, 0.066), (-0.03, 0.06), (-0.006, 0.06), (0.002, 0.066), (0.004, 0.09)]
    parts.append(profile('szkielet', frame, T * 0.82, poly, 0.003, holes=(guard,)))
    # żłobki szyny akcesoriów
    for k in range(3):
        parts.append(rbox('szyna%d' % k, (0.004, T * 0.86, 0.004), mat('nac', '0e0f11', 0.6, 0.5), 0.0, (-0.108 + k * 0.012, 0, 0.099), segs=1))
    # faktura chwytu: rzędy małych wypustek po bokach
    for r in range(6):
        for c in range(4):
            for sy in (-1, 1):
                x = 0.03 + c * 0.009 + r * 0.0025
                z = 0.0 + r * 0.011
                parts.append(rbox('f', (0.004, 0.0012, 0.004), poly, 0.0, (x, sy * T * 0.415, z + 0.004), (0, math.radians(13), 0), segs=1))
    parts.append(rbox('stopka', (0.058, T * 0.9, 0.007), poly, 0.002, (0.053, 0, -0.016), (0, math.radians(-10), 0), segs=2))
    # lufa w wylocie zamka + prowadnica sprężyny
    lufa = lathe('lufa', [(0.0, 0.0), (0.0045, 0.0), (0.0045, 0.002), (0.0072, 0.002), (0.0072, 0.012), (0.0, 0.012)], mat('lufa_sr', '5a5d63', 0.3, 0.9), 14)
    lufa.rotation_euler = (0, math.radians(90), 0)
    lufa.location = (-0.129, 0, 0.131)
    parts.append(lufa)
    sp = lathe('sprezyna', [(0.0, 0.0), (0.004, 0.0), (0.004, 0.006), (0.0, 0.006)], steel, 10)
    sp.rotation_euler = (0, math.radians(90), 0)
    sp.location = (-0.125, 0, 0.121)
    parts.append(sp)
    # przyrządy celownicze, spust z bezpiecznikiem, zatrzask zamka, zrzut magazynka, kołek
    parts.append(rbox('muszka', (0.006, 0.004, 0.005), steel, 0.001, (-0.112, 0, 0.1435), segs=1))
    for sy in (-0.006, 0.006):
        parts.append(rbox('szczerbinka', (0.008, 0.005, 0.006), steel, 0.001, (0.05, sy, 0.144), segs=1))
    parts.append(tube('spust', [(-0.02, 0, 0.09), (-0.024, 0, 0.076), (-0.018, 0, 0.066)], 0.003, steel, 8))
    for sy in (-1, 1):
        parts.append(rbox('zatrzask', (0.022, 0.002, 0.004), steel, 0.0008, (0.02, sy * T * 0.43, 0.108), segs=1))
        parts.append(rbox('zrzut', (0.007, 0.002, 0.009), steel, 0.0008, (0.004, sy * T * 0.43, 0.082), segs=1))
        kolek = lathe('kolek', [(0.0, 0.0), (0.0025, 0.0), (0.0025, 0.001)], steel, 8)
        kolek.rotation_euler = (math.radians(90 * sy), 0, 0)
        kolek.location = (-0.03, sy * T * 0.41, 0.1)
        parts.append(kolek)
    gun = join('Pistolet', parts)
    weather([gun], 1024, 0.35, 0.85, (0.05, 0.05, 0.05))
    export('pistolet')


for f in (radio, pistolet):
    f()
