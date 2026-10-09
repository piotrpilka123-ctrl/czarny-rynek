"""Plecak miejski: spłaszczony tył, nylon, dwie kieszenie, taśmy i metalowe suwaki."""
import os,sys
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from lib import *
reset()
cloth=mat('nylon','303a40',.94)
web=mat('tasmy','252c30',.95)
seam=mat('szwy','58636a',.9)
metal=mat('suwaki','81898c',.3,.7)
parts=[rbox('Komora',(.31,.145,.405),cloth,.038,(0,0,0),segs=5),
       rbox('Panel_tylny',(.255,.018,.32),web,.008,(0,.075,-.01),segs=3),
       rbox('Kieszen_przednia',(.26,.052,.19),cloth,.023,(0,-.083,-.066),segs=5),
       rbox('Gorna_kieszen',(.235,.025,.063),cloth,.012,(0,-.084,.103),segs=4)]
weather(parts,512,.16,.12,samples=8)
# Obszycia paneli, dwie linie zamków i widoczne uchwyty.
for z,w,y in [(.137,.228,-.097),(.021,.245,-.114)]:
    tube('Zamek',[(-w/2,y,z),(w/2,y,z)],.0022,web,6)
    for i in range(24):
        rbox('Zabek',(.0018,.002,.0028),metal,.0005,(-w/2+i*w/23,y-.001,z),segs=1)
    rbox('Uchwyt_suwaka',(.009,.004,.022),metal,.002,(w/2-.018,y-.006,z-.01),segs=3)
tube('Obszycie',[(-.125,-.104,.008),(-.13,-.103,-.135),(-.11,-.102,-.16),(.11,-.102,-.16),(.13,-.103,-.135),(.125,-.104,.008)],.0015,seam,6)
for side in [-1,1]:
    x=side*.10
    pts=[(x,.067,.16),(x,.15,.19),(x,.205,.10),(x,.20,-.11),(x,.095,-.175)]
    for a,b in zip(pts,pts[1:]):
        # Taśmy jako spłaszczone paski, zamiast grubych sznurów.
        ob=tube('Szelka',[a,b],.013,web,8)
        ob.scale.x=1.25
    rbox('Regulator',(.033,.012,.024),metal,.002,(x,.20,-.075),segs=2)
    rbox('Boczna_kieszen',(.027,.095,.13),web,.012,(side*.158,-.003,-.09),segs=4)
tube('Uchwyt',[(-.05,.035,.19),(-.045,.03,.23),(.045,.03,.23),(.05,.035,.19)],.007,web,8)
join('Plecak',[o for o in bpy.context.scene.objects if o.type=='MESH'])
export('gracz_plecak')
