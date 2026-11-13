#!/usr/bin/env python3
"""Closed, two-storey log buildings sculpted in 12.5 cm voxels, like portal assets.
Native editable VOX files, shared meshes and explicit collision envelopes.
"""
from pathlib import Path
import math,json
from make_creatures import box,line
from make_common_batch_01 import export
from preview_voxel_batch import ROOT,assemble,render,BOLD
from PIL import Image,ImageDraw,ImageFont
BASE={'wood':(111,66,37),'wood_light':(145,90,46),'wood_dark':(74,43,28),'end':(177,126,70),'ring':(121,78,41),'beam':(65,42,31),'stone':(116,117,113),'stone_light':(152,148,131),'mortar':(67,69,69),'roof':(83,102,74),'roof_light':(104,125,83),'roof_dark':(53,72,61),'glass':(94,155,166),'glow_window':(235,180,99),'iron':(60,65,70),'brass':(200,156,67),'plaster':(215,194,152),'snow':(222,234,232),'snow_shadow':(176,203,215),'cloth':(139,64,64),'leaf':(67,111,61),'flower':(208,151,141),'glow_fire':(246,141,53)}

def hval(x,y,z):return ((x*73856093)^(y*19349663)^(z*83492791))%13

def window(v,cx,cy,cz,axis='z',wide=8,tall=10,balcony=False):
 # Outward-facing inset panes, thick carved frame, cross muntins and shutters.
 for a in range(-wide//2-2,wide//2+3):
  for b in range(-tall//2-2,tall//2+3):
   c='beam' if abs(a)>wide//2 or abs(b)>tall//2 else 'glow_window' if (a+b)%5 else 'glass'
   if a==0 or b==0:c='wood_light'
   p=(cx+a,cy+b,cz) if axis=='z' else (cx,cy+b,cz+a)
   v[p]=c
 for s in [-1,1]:
  for a in range(wide//2+3,wide//2+6):
   for b in range(-tall//2,tall//2+1):
    p=(cx+a*s,cy+b,cz+1) if axis=='z' else (cx+1,cy+b,cz+a*s)
    v[p]='roof' if b%4 else 'iron'
 # Flower box under the sill.
 if axis=='z':
  box(v,cx-wide//2-1,cx+wide//2+2,cy-tall//2-5,cy-tall//2-2,cz-3,cz+1,'wood_dark')
  for x in range(cx-wide//2,cx+wide//2+1):v[(x,cy-tall//2-2,cz-2)]='leaf' if x%3 else 'flower'

def loghouse(theme,variant):
 pal=dict(BASE)
 if theme=='fosen':pal.update(roof=(62,90,103),roof_light=(91,126,139),roof_dark=(39,61,77),wood=(92,67,47),wood_light=(132,95,60),cloth=(66,112,139))
 if theme=='desert':pal.update(roof=(44,112,119),roof_light=(69,145,147),roof_dark=(31,77,91),wood=(158,104,56),wood_light=(187,136,76),plaster=(219,178,124),cloth=(125,72,139))
 v={};hx=26;hz=28
 # Dressed, chipped foundation stones; every mortar seam is actual voxel geometry.
 for x in range(-hx-2,hx+3):
  for z in range(-hz-2,hz+3):
   if abs(x)<hx-2 and abs(z)<hz-2:continue
   for y in range(0,6):v[(x,y,z)]='mortar' if y%4==0 or (x+z+(y//4)*3)%9==0 else 'stone_light' if hval(x,y,z)<3 else 'stone'
 # Two floors of round, overlapping logs. Exposed ends show concentric growth rings.
 for y in range(8,49,4):
  tone='wood_light' if y%12==0 else 'wood'
  for side in [-1,1]:
   for yy in range(y-2,y+2):
    for depth in range(-2,3):
     if (yy-y+.5)**2+depth**2>5.5:continue
     for x in range(-hx-3,hx+4):v[(x,yy,side*hz+depth)]=tone if (x+hval(x,yy,depth))%17 else 'wood_dark'
     for z in range(-hz-4,hz+5):v[(side*hx+depth,yy,z)]='wood_dark' if (z+y)%19==0 else tone
   for z in [-hz-5,hz+5]:
    for xx in range(-2,3):
     for yy in range(-2,2):
      r=xx*xx+(yy+.5)**2
      if r<=5.5:v[(side*hx+xx,y+yy,z)]='ring' if r<1.8 else 'end'
 # Corner posts, carved cornice and second-floor band.
 for x in [-hx+2,hx-2]:
  for z in [-hz+2,hz-2]:box(v,x-1,x+2,5,50,z-1,z+2,'beam')
 for y in [6,26,48]:
  box(v,-hx-3,hx+4,y,y+2,-hz-3,-hz,'beam');box(v,-hx-3,hx+4,y,y+2,hz,hz+3,'beam')
  box(v,-hx-3,-hx,y,y+2,-hz,hz,'beam');box(v,hx,hx+3,y,y+2,-hz,hz,'beam')
 # Closed iron-banded front door: visual only, the entire volume is solid collision.
 box(v,-6,7,6,24,-hz-4,-hz-2,'beam')
 for x in range(-4,5):
  for y in range(6,22):v[(x,y,-hz-5)]='wood_dark' if x%3==0 else 'wood_light'
 for y in [10,19]:box(v,-4,5,y,y+1,-hz-6,-hz-4,'iron')
 v[(3,14,-hz-6)]='brass'
 for x in [-16,16]:
  window(v,x,16,-hz-4,wide=7,tall=8)
  window(v,x,37,-hz-4,wide=7,tall=9)
 for x in [-16,16]:
  window(v,x,16,hz+4,wide=7,tall=8);window(v,x,37,hz+4,wide=7,tall=9)
 for side in [-1,1]:
  for z in [-13,13]:
   window(v,side*(hx+3),16,z,'x',8,9);window(v,side*(hx+3),37,z,'x',8,9)
 # Upper balcony and turned wooden railing, offset by design.
 left,right=(-18,19) if variant!=2 else (-23,8)
 box(v,left,right,27,29,-hz-13,-hz-2,'wood_dark')
 for x in range(left,right):
  if x%3:box(v,x,x+1,29,35,-hz-13,-hz-12,'wood_light')
 box(v,left,right,35,36,-hz-14,-hz-12,'beam')
 for x in [left,right-1]:
  box(v,x,x+1,29,35,-hz-13,-hz-2,'wood_light');line(v,(x,24,-hz-3),(x,27,-hz-12),'beam',2)
 # Roof planks and individual overlapping shingle courses; decorative scalloped fascia.
 rx=hx+6;rz=hz+7
 for z in range(-rz,rz+1):
  for x in range(-rx,rx+1):
   peak=23 if variant!=1 else 19
   roof_y=50+round((1-abs(x)/rx)*peak)
   if variant==2:roof_y+=round(math.sin(z*.065)*2)
   for thick in [0,1]:
    c='roof_dark' if (abs(x)//3)%2 else 'roof'
    if (z+(abs(x)//3%2)*3)%7==0:c='roof_dark'
    elif hval(x,roof_y,z)<3:c='roof_light'
    v[(x,roof_y+thick,z)]=c
   if z in [-rz,rz]:
    box(v,x,x+1,roof_y-2,roof_y,z,z+1,'beam')
   if theme=='fosen':
    cap=2+(1 if hval(x,roof_y,z)<6 else 0)
    for y in range(roof_y+2,roof_y+2+cap):v[(x,y,z)]='snow' if hval(x,y,z)>3 else 'snow_shadow'
 # Enclose gables with contrasting beams and pale inset panels.
 for z in [-hz-1,hz+1]:
  for x in range(-hx,hx+1):
   roof_y=50+round((1-abs(x)/rx)*(23 if variant!=1 else 19))
   for y in range(50,roof_y):v[(x,y,z)]='beam' if abs(x)<2 or (y-50-abs(x))%19<2 else 'plaster'
 window(v,0,58,-hz-2,wide=8,tall=6)
 # Crooked brick chimney and copper cap.
 cx,cz=17,13
 for y in range(43,79):
  for x in range(cx-3,cx+4):
   for z in range(cz-3,cz+4):
    if abs(x-cx)==3 or abs(z-cz)==3:v[(x,y,z)]='mortar' if y%4==0 or (x+z+y//4)%6==0 else 'stone'
 box(v,cx-4,cx+5,77,79,cz-4,cz+5,'stone_light')
 # Little hood over the entrance, carved knee brackets and hanging lanterns.
 for z in range(-hz-12,-hz-3):
  for x in range(-10,11):v[(x,24+round((1-abs(x)/11)*3),z)]='roof' if (z+x)%5 else 'roof_light'
 for x in [-9,9]:
  line(v,(x,20,-hz-3),(x,24,-hz-11),'beam',2)
 for x in [-12,12]:
  box(v,x-1,x+2,20,22,-hz-7,-hz-4,'iron');box(v,x,x+1,17,20,-hz-6,-hz-5,'iron');box(v,x-1,x+2,14,17,-hz-7,-hz-4,'glow_fire')
 # Projecting shield sign, strapped woodpile and rain barrel.
 box(v,hx-2,hx,29,30,-hz-12,-hz-1,'iron');box(v,hx-5,hx+3,21,28,-hz-13,-hz-11,'cloth')
 for y in [8,12,16]:
  for z in [12,17,22]:
   for yy in [-1,0,1]:
    for zz in [-1,0,1]:
     for x in range(hx+1,hx+8):v[(x,y+yy,z+zz)]='end' if x==hx+7 else 'wood_dark'
 for y in range(0,9):
  for x in range(-3,4):
   for z in range(-3,4):
    if x*x+z*z<=10:v[(-hx-3+x,y,17+z)]='iron' if y in [2,6] else 'wood'
 # Seeded design-specific dormer, front beam ornaments, or small turret.
 if variant==0:
  for x in range(-9,10):
   for y in range(53,61):v[(x,y,-hz-7)]='plaster'
  window(v,0,57,-hz-8,wide=7,tall=6)
  for x in range(-11,12):
   for z in range(-hz-10,-hz+2):v[(x,62+round((1-abs(x)/12)*6),z)]='roof_light'
 elif variant==1:
  for x in [-23,23]:line(v,(x,50,-hz-3),(0,69,-hz-3),'end',1)
 else:
  for x in range(-6,7):
   for z in range(18,32):
    y=68+round((1-abs(x)/7)*7);v[(x,y,z)]='brass' if theme=='desert' else 'snow' if theme=='fosen' else 'roof_light'
 return pal,v

def prop(kind):
 p=dict(BASE);v={}
 if kind=='market':
  for x in [-12,12]:
   for z in [-7,7]:box(v,x,x+2,0,24,z,z+2,'wood_dark')
  for x in range(-15,16):
   for z in range(-10,11):v[(x,25+round((1-abs(x)/16)*5),z)]='cloth' if (x//4)%2 else 'plaster'
  box(v,-12,14,7,9,-7,-3,'wood');box(v,-12,14,0,7,-6,-4,'wood_dark')
  for x in range(-9,10,4):box(v,x,x+3,9,11,-7,-4,'end' if x%2 else 'leaf')
 elif kind=='well':
  for y in range(0,9):
   for x in range(-10,11):
    for z in range(-10,11):
     rr=x*x+z*z
     if 55<rr<100:v[(x,y,z)]='mortar' if y%4==0 or (x+z)%9==0 else 'stone_light'
     elif rr<55 and y==2:v[(x,y,z)]='glass'
  for x in [-10,10]:box(v,x-1,x+2,0,23,-1,2,'beam')
  box(v,-12,13,21,24,-1,2,'wood');box(v,0,1,7,22,0,1,'end')
  for x in range(-13,14):
   for z in range(-10,11):v[(x,24+round((1-abs(z)/11)*7),z)]='roof'
 elif kind=='bench':
  for x in [-8,8]:box(v,x-1,x+2,0,5,-2,3,'iron')
  box(v,-10,11,5,7,-4,4,'wood_light');box(v,-10,11,7,13,3,5,'wood')
 return p,v

def main():
 names=[]
 for theme in ['woodland','fosen','desert']:
  for variant in range(3):
   name=f'{theme}_{variant}';pal,v=loghouse(theme,variant)
   folder=ROOT/'props/houses'/name
   export(folder,{'body':v},pal,dict(voxel_size=.125,parts={},limbs={},hand=[0,0,0],waddle=0))
   (folder/'building.json').write_text(json.dumps(dict(floors=2,closed=True,voxel_size=.125,body_size=[8.5,6,8.5]),indent=2)+'\n')
   # Separate lightweight surface preview from the native editable solid colors.
   vox,_=assemble(folder);render(vox,480,460,yaw=32).save(folder/'preview.png');names.append((name,folder))
 for kind in ['market','well','bench']:
  pal,v=prop(kind);export(ROOT/'props/town'/kind,{'body':v},pal,dict(voxel_size=.125,parts={},limbs={},hand=[0,0,0],waddle=0))
 sheet=Image.new('RGB',(1440,3*510),'#202832');d=ImageDraw.Draw(sheet)
 for i,(name,folder) in enumerate(names):
  sheet.paste(Image.open(folder/'preview.png'),(i%3*480,i//3*510));d.text((i%3*480+16,i//3*510+472),name.replace('_',' ').title(),font=ImageFont.truetype(BOLD,22),fill='white')
 sheet.save(ROOT/'tools/previews/detailed_houses.png');print('Generated nine two-storey voxel houses, three detailed town props and preview.')
if __name__=='__main__':main()
