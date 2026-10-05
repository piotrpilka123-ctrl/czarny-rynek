import sys,os,json
from PIL import Image,ImageDraw
d=sys.argv[1]; cols=int(sys.argv[2]) if len(sys.argv)>2 else 2; rows=int(sys.argv[3]) if len(sys.argv)>3 else 2
names=sorted(f for f in os.listdir(d) if f.endswith('.jpg') and not f.startswith('sheet'))
if len(sys.argv)>4:
    order=[e['name']+'.jpg' for e in json.load(open(sys.argv[4]))]; names=[n for n in order if n in names]
per=cols*rows
for k in range(0,len(names),per):
    ims=[Image.open(os.path.join(d,n)) for n in names[k:k+per]]
    w,h=ims[0].size
    sh=Image.new('RGB',(w*cols,h*rows))
    dr=ImageDraw.Draw(sh)
    for i,im in enumerate(ims):
        x=(i%cols)*w; y=(i//cols)*h
        sh.paste(im,(x,y)); dr.rectangle([x,y,x+150,y+16],fill=(0,0,0)); dr.text((x+4,y+2),names[k+i][:-4],fill=(255,255,0))
    sh.save(os.path.join(d,'sheet%02d.jpg'%(k//per)),quality=86)
print(len(names))
