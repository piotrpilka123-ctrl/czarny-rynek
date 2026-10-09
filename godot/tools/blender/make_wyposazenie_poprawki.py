"""Dokładniejsza ceramika klubowa i przestrzenne narzędzia garażu. Metry; przód -Y."""
import os,sys,math
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from lib import *

def toilet():
    reset()
    ceramic=mat('ceramika','e7e8e1',.18)
    plastic=mat('deska','f2f0e8',.3)
    steel=mat('chrom','bfc8cf',.22,.85)
    # Zamknięty profil z wnętrzem misy, bez pełnego dysku zamiast otworu.
    body=lathe('Misa',[(0,.02),(.13,.02),(.15,.06),(.12,.21),(.19,.3),(.235,.38),(.24,.42),(.22,.435),(.195,.41),(.16,.34),(.07,.26),(0,.26)],ceramic,48)
    body.scale.y=1.32
    rbox('Stopa',(.25,.36,.055),ceramic,.023,(0,.045,.03),segs=4)
    rbox('Zbiornik',(.38,.17,.39),ceramic,.036,(0,.28,.57),segs=5)
    rbox('Pokrywa_zbiornika',(.395,.184,.03),plastic,.013,(0,.28,.78),segs=4)
    for x in [-.045,.03]:
        b=lathe('Przycisk',[(0,0),(.027,0),(.027,.008),(0,.008)],steel,20,loc=(x,.28,.799))
    # Owalna deska z otwartym środkiem i widocznymi zawiasami.
    seat=lathe('Deska',[(.198,.442),(.242,.442),(.246,.459),(.24,.474),(.198,.474),(.193,.46),(.198,.442)],plastic,48)
    seat.scale.y=1.32
    for x in [-.12,.12]:
        rbox('Zawias',(.04,.07,.027),steel,.005,(x,.225,.46),segs=2)
    lid=rbox('Uniesiona_pokrywa',(.43,.033,.5),plastic,.016,(0,.205,.70),rot=(math.radians(-8),0,0),segs=5)
    rbox('Dystans',(.025,.05,.012),plastic,.004,(-.12,.172,.61))
    rbox('Dystans',(.025,.05,.012),plastic,.004,(.12,.172,.61))
    for x in [-.1,.1]:
        rbox('Sruba_podstawy',(.024,.035,.014),plastic,.005,(x,-.09,.063))
    join('Toaleta',[o for o in bpy.context.scene.objects if o.type=='MESH'])
    export('klub_toaleta')

def board():
    reset()
    panel=mat('blacha_panelu','53605c',.58,.5)
    dark=mat('otwory','242b29',.9)
    steel=mat('stal_narzedzi','bcc4c8',.26,.86)
    grip=mat('guma','aa3c2b',.82)
    wood=mat('trzonek','a57a49',.8)
    rbox('Panel',(1.6,.035,.9),panel,.009,(0,0,0),segs=2)
    for x in [-.8,.8]:rbox('Rama',(.025,.055,.91),steel,.003,(x,-.012,0))
    for z in [-.45,.45]:rbox('Rama',(1.6,.055,.025),steel,.003,(0,-.012,z))
    holes=[]
    for ix in range(23):
        for iz in range(12):
            o=lathe('Otwor',[(0,0),(.007,0),(.007,.001),(0,.001)],dark,8,loc=(-.726+ix*.066,-.019,-.363+iz*.066))
            o.rotation_euler=(math.pi/2,0,0);holes.append(o)
    join('Perforacja',holes)
    # Klucze oczkowo-płaskie: wycięte szczęki, cienka szyjka i oczko.
    for k in range(4):
        x=-.62+k*.125; z=.18; ln=.16+k*.045; jaw=.027+k*.004
        rbox('Trzon_klucza',(.022,.014,ln),steel,.005,(x,-.062,z),segs=3)
        pts=[(-jaw,0),(-jaw-.014,.025),(-jaw-.01,.06),(-jaw*.52,.043),(-jaw*.52,.02),(jaw*.52,.02),(jaw*.52,.043),(jaw+.01,.06),(jaw+.014,.025),(jaw,0)]
        head=profile('Szczeki',pts,.017,steel,.002);head.location=(x,-.062,z+ln/2-.015)
        ring=lathe('Oczko',[(jaw*.58,0),(jaw,.0),(jaw,.015),(jaw*.58,.015),(jaw*.58,0)],steel,20,loc=(x,-.07,z-ln/2-.023));ring.rotation_euler=(math.pi/2,0,0)
        text('Rozmiar',str(10+2*k),.024,dark,(x,-.071,z),depth=.0005)
        tube('Hak',[(x,-.018,z+.03),(x,-.06,z+.03),(x,-.063,z+.05)],.004,steel,6)
    # Młotek: stalowa główka ze zwężeniem, drewniany trzonek.
    rbox('Trzonek_mlotka',(.036,.03,.30),wood,.01,(.03,-.065,.12),segs=4)
    rbox('Glowka_mlotka',(.19,.047,.055),steel,.009,(.03,-.065,.29),segs=3)
    rbox('Obuch',(.035,.06,.062),steel,.008,(-.075,-.065,.29))
    # Piła ze zróżnicowanymi zębami i otworem w rękojeści.
    pts=[(.26,.12),(.66,.16),(.70,.29),(.27,.31)]
    blade=profile('Brzeszczot',pts,.006,steel,.001);blade.location.y=-.065
    for k in range(21):
        x=.28+k*.018
        tooth=profile('Zab',[(x,.135),(x+.009,.114),(x+.018,.136)],.006,steel,.0004);tooth.location.y=-.065
    handle=profile('Rekojesc_pily',[(.19,.12),(.29,.12),(.32,.3),(.22,.33)],.03,grip,.003,holes=([(.225,.16),(.26,.16),(.28,.28),(.24,.29)],));handle.location.y=-.075
    # Śrubokręty: uchwyty z karbowaniem i rzeczywiste końcówki.
    for k in range(4):
        x=.12+k*.11
        rbox('Grot',(.009,.009,.145),steel,.002,(x,-.066,-.11))
        rbox('Uchwyt',(.035,.028,.092),grip if k%2==0 else mat('zolty','cba136',.75),.011,(x,-.066,-.225),segs=4)
        for dz in [-.026,0,.026]:rbox('Zlobienie',(.037,.006,.005),dark,.001,(x,-.081,-.225+dz))
    # Kombinerki i zwinięta taśma.
    for side in [-1,1]:
        tube('Raczka_kombinerek',[(-.57+side*.048,-.065,-.34),(-.57+side*.028,-.065,-.25),(-.57,-.065,-.19)],.012,grip,8)
        tube('Szczeka_kombinerek',[(-.57-side*.027,-.065,-.13),(-.57-side*.018,-.065,-.16),(-.57,-.065,-.19)],.009,steel,8)
    tape=lathe('Tasma',[(.041,0),(.073,0),(.073,.027),(.041,.027),(.041,0)],dark,28,loc=(-.22,-.052,-.27));tape.rotation_euler=(math.pi/2,0,0)
    join('Tablica_narzedzi',[o for o in bpy.context.scene.objects if o.type=='MESH'])
    export('garaz_narzedzia')

toilet();board()
