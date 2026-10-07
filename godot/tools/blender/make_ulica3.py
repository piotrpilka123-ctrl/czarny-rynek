"""Drobiazgi w jezdni: żeliwna kratka ściekowa przy krawężniku (rama, żebra, betonowy kołnierz, liście w rogu).
Wierzch 2 cm nad z = 0, dłuższy bok wzdłuż X."""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lib import *
from lib import _finish

rnd = random.Random(5)


def ul_kratka():
    reset()
    iron = mat('zeliwo', '3b3936', 0.75, 0.6)
    con = mat('beton', '8e8a80', 0.92, wzor='beton')
    p = [rbox('kolnierz', (0.86, 0.62, 0.03), con, 0.008, (0, 0, -0.003)),
         rbox('dol', (0.6, 0.38, 0.012), mat('czern', '050505', 1.0), 0.0, (0, 0, 0.008), segs=1)]
    for sy in (-1, 1):
        p.append(rbox('rama_d', (0.68, 0.05, 0.04), iron, 0.006, (0, sy * 0.215, 0.0)))
    for sx in (-1, 1):
        p.append(rbox('rama_k', (0.05, 0.48, 0.04), iron, 0.006, (sx * 0.315, 0, 0.0)))
    for i in range(8):
        p.append(rbox('zebro%d' % i, (0.032, 0.39, 0.034), iron, 0.006, (-0.245 + i * 0.07, 0, 0.001)))
    p.append(rbox('poprzeczka', (0.6, 0.03, 0.03), iron, 0.005, (0, 0, -0.002)))
    for i in range(4):
        p.append(rbox('lisc%d' % i, (rnd.uniform(0.03, 0.045), rnd.uniform(0.018, 0.026), 0.003), mat('lisc%d' % (i % 2), '4a3a1e' if i % 2 else '5a4a22', 0.9), 0.001,
                      (0.2 + rnd.uniform(-0.1, 0.1), -0.12 + rnd.uniform(-0.07, 0.07), 0.021 + i * 0.0006), (0, 0, rnd.uniform(0, 3.1)), segs=1))
    ob = join('Kratka', p)
    weather([ob], 512, 0.7, 0.6, (0.07, 0.06, 0.05))
    export('ul_kratka')


ul_kratka()
