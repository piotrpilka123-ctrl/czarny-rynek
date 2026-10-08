import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lib
from lib import *
reset()
con = mat('Beton kruszywowy', 'a49f92', 0.98, wzor='beton')
parts = []
for y in [-0.105, 0.105]:
    parts.append(rbox('ścianka', (0.49, 0.03, 0.24), con, 0.003, (0, y, 0.12), segs=1))
for x in [-0.2275, 0.0, 0.2275]:
    parts.append(rbox('przegroda', (0.035 if x else 0.025, 0.18, 0.24), con, 0.002, (x, 0, 0.12), segs=1))
block = join('Pustak — dwie otwarte komory', parts)
weather([block], 1024, 0.18, 0.16, samples=12)
export('pustak_beton')
