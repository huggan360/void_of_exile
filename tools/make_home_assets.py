#!/usr/bin/env python3
"""Author native home village models. Layout lives in scenes/home/tavern.tscn.
Run this only to rebuild the model library, never during gameplay.
"""
import math,json,sys
from make_village_houses import BASE,loghouse,box,line,window
from make_common_batch_01 import export
from preview_voxel_batch import ROOT
OUT=ROOT/'props/home'
SPECS={}
SELECTED=set(sys.argv[1:]) if __name__=='__main__' else set()
def add(name,v,p=None,size=None,**info):
 if SELECTED and name not in SELECTED:return
 folder=OUT/name
 export(folder,{'body':v},p or BASE,dict(voxel_size=.125,parts={},limbs={},hand=[0,0,0],waddle=0))
 (folder/'building.json').write_text(json.dumps({'solid_size':size or [8.5,8,9], 'closed':True,**info},indent=2)+'\n')
 SPECS[name]=str(folder)
def stretch(v,sx=1,sy=1,sz=1):
 out={}
 for (x,y,z),c in v.items():
  for xx in range(math.floor(x*sx),math.floor((x+1)*sx)):
   for yy in range(math.floor(y*sy),math.floor((y+1)*sy)):
    for zz in range(math.floor(z*sz),math.floor((z+1)*sz)):out[xx,yy,zz]=c
 return out
def tower(v,cx,cz,r,height,palette='roof'):
 for y in range(height):
  for x in range(-r,r+1):
   for z in range(-r,r+1):
    d=math.hypot(x,z)
    if r-2<d<r+1:v[cx+x,y,cz+z]='beam' if y%20<2 else 'stone_light' if y%4==0 or (x+z)%8==0 else 'stone'
 for y in range(r*2+4):
  rr=max(0,r+4-y*.55)
  for x in range(-r-4,r+5):
   for z in range(-r-4,r+5):
    if rr-1.7<=math.hypot(x,z)<=rr+.8:v[cx+x,height+y,cz+z]='brass' if y>r*2 else palette if y%4 else 'roof_dark'
 for y in [17,39,61]:
  if y<height-5:window(v,cx,y,cz-r-1,wide=5,tall=9)
def forge_house():
 # Local -Z is the open plaza front; all dimensions use the home 12.5 cm grid.
 p=dict(BASE);p.update(roof=(66,71,78),roof_light=(94,102,110),roof_dark=(42,47,56),
  soot=(40,36,34),water=(58,112,132),glow_hot=(255,204,83))
 v={};colliders=[]
 def solid(x0,x1,y0,y1,z0,z1,c):
  box(v,x0,x1,y0,y1,z0,z1,c)
  colliders.append(dict(size=[(x1-x0)*.125,(y1-y0)*.125,(z1-z0)*.125],
   offset=[(x0+x1)*.0625,(y0+y1)*.0625,(z0+z1)*.0625]))
 # Floor and overhead beams stay visual-only: Tavern navigation projects colliders onto XZ.
 box(v,-38,38,-2,0,-34,34,'stone')
 solid(-38,-34,0,34,-32,34,'stone')
 solid(34,38,0,34,-32,34,'stone')
 solid(-34,34,0,34,30,34,'stone')
 for x in [-38,34]:
  for z in [-32,9,30]:solid(x,x+4,0,36,z,z+4,'beam')
 for x in [-38,34]:box(v,x,x+4,31,35,-32,34,'wood_light')
 box(v,-38,38,32,36,30,34,'beam')
 box(v,-38,38,33,37,-32,-28,'beam')
 for x in [-34,31]:line(v,(x,25,-30),(x+(-7 if x>0 else 7),34,-30),'beam',2)
 # Slate gable roof with a timber ridge and a clear 4 m bay below it.
 for x in range(-40,40):
  y=36+(39-abs(x))//3
  box(v,x,x+1,y,y+2,-36,36,'roof_dark' if x%9==0 else 'roof_light' if y%4==0 else 'roof')
 box(v,-2,2,49,52,-36,36,'beam')
 for z in [-31,31]:
  line(v,(-35,35,z),(0,48,z),'wood_light',1)
  line(v,(0,48,z),(35,35,z),'wood_light',1)
 # Massive hearth, recessed firebox, hood and open-topped stone chimney.
 solid(11,32,0,7,5,29,'stone')
 solid(11,15,7,22,5,29,'stone')
 solid(28,32,7,22,5,29,'stone')
 solid(15,28,7,22,25,29,'soot')
 solid(11,32,22,27,5,29,'stone')
 box(v,15,28,7,9,6,25,'glow_fire')
 box(v,15,28,9,19,24,25,'glow_fire')
 for x in range(16,28,3):
  box(v,x,x+1,9,11,8,23,'soot')
  box(v,x,x+1,10,12,11,13,'glow_hot')
 for y in range(27,37):
  inset=(y-27)//3
  box(v,11+inset,32-inset,y,y+1,5+inset,29-inset,'stone')
 solid(15,28,36,68,10,25,'stone')
 box(v,13,30,65,68,8,27,'stone_light')
 for x in range(18,25):
  for z in range(13,22):
   for y in range(61,68):v.pop((x,y,z),None)
 box(v,18,25,60,61,13,22,'soot')
 # Masonry courses and staggered pale blocks, including the hearth surround.
 for (x,y,z),c in list(v.items()):
  if c=='stone' and y>=0:
   if y%5==0 or (x+z+(y//5%2)*4)%9==0:v[x,y,z]='mortar'
   elif (x//4+y//5+z//4)%5==0:v[x,y,z]='stone_light'
 # Anvil on an iron-banded stump, with a tapered horn toward the open front.
 solid(-12,-4,0,7,-14,-6,'wood_dark')
 box(v,-12,-4,6,7,-14,-6,'iron');box(v,-11,-5,7,9,-13,-7,'iron')
 box(v,-10,-6,9,12,-12,-8,'iron')
 solid(-13,-3,12,14,-14,-6,'iron')
 for i in range(5):box(v,-11+i//2,-5-i//2,12,15-i//2,-15-i,-14-i,'iron')
 box(v,-13,-3,14,15,-13,-7,'stone_light')
 # Open water trough at the left wall, bound with dark iron hoops.
 solid(-31,-20,0,8,-19,-1,'wood')
 box(v,-29,-22,4,8,-17,-3,'water')
 for z in [-17,-5]:box(v,-32,-19,2,3,z,z+1,'iron')
 # Rack on the rear wall: hammer, tongs, poker and spare horseshoes.
 box(v,-29,-5,18,21,27,30,'wood_light')
 for x in [-26,-20,-14,-8]:
  line(v,(x,12,26),(x,24,26),'iron' if x!=-26 else 'wood_light',1)
 box(v,-29,-23,23,26,25,28,'iron')
 line(v,(-22,12,26),(-19,18,26),'iron',1)
 line(v,(-18,12,26),(-20,18,26),'iron',1)
 line(v,(-8,12,26),(-5,14,26),'iron',1)
 # Suspended sign under the right eave, with a pale hammer silhouette.
 line(v,(30,32,-30),(30,32,-35),'iron',1)
 for x in [23,31]:box(v,x,x+1,25,32,-35,-34,'iron')
 box(v,20,34,17,26,-36,-34,'wood_dark')
 box(v,21,33,18,25,-37,-36,'wood_light')
 box(v,26,28,18,23,-38,-37,'brass')
 box(v,23,31,22,25,-38,-37,'stone_light')
 add('forge_house',v,p,[10,8.5,9],closed=False,colliders=colliders,
  markers={'ForgeMouth':[2.6875,1.75,.625]})

def main():
 forge_house()
 if SELECTED=={'forge_house'}:
  print('Authored forge_house native home voxel asset.');return
 for name,sizes,variant,pal in [
  ('tall_townhouse',(0.8,1.25,1),0,{}),
  ('broad_lodge',(1.35,1,1.05),1,{'roof':(134,70,51),'roof_light':(172,94,62),'roof_dark':(91,45,40)}),
  ('blue_bakery',(1,.85,.85),2,{'roof':(56,105,133),'roof_light':(78,137,161),'roof_dark':(35,67,95)}),
  ('rose_cottage',(.85,.8,.85),0,{'roof':(133,76,105),'roof_light':(161,104,125),'roof_dark':(89,48,76)}),
  ('grand_tavern',(1.8,1.2,1.25),0,{'roof':(126,65,42),'roof_light':(162,92,50),'roof_dark':(83,45,36)}),
  ('smithy',(1.15,1,1),1,{'roof':(66,71,78),'roof_light':(94,102,110),'roof_dark':(42,47,56)})]:
  p,v=loghouse('woodland',variant);p.update(pal);v=stretch(v,*sizes)
  if name=='grand_tavern':
   tower(v,48,12,12,75)
   # Big suspended inn sign and crossed tankard brackets.
   line(v,(-48,45,-42),(-48,45,-62),'beam',2)
   box(v,-58,-38,29,41,-60,-57,'wood_light')
   box(v,-54,-45,31,39,-61,-60,'brass');box(v,-45,-42,33,38,-61,-60,'brass')
  if name=='smithy':
   # Open street-side forge, tall chimney, anvils, racks, covered workbench.
   for x in [-22,22]:box(v,x,x+2,0,29,-64,-62,'beam')
   for x in range(-25,26):
    for z in range(-65,-29):v[x,31+(z+65)//6,z]='roof_dark' if x%6==0 else 'roof'
   box(v,12,24,0,16,-60,-46,'stone');box(v,14,22,8,14,-61,-59,'glow_fire')
   box(v,15,22,16,53,-52,-45,'stone');box(v,13,24,52,55,-54,-43,'iron')
   box(v,-17,-6,0,7,-56,-47,'wood_dark');box(v,-19,-4,7,10,-58,-45,'iron')
   line(v,(-20,9,-53),(-25,10,-53),'iron',2)
  add(name,v,p,[8.5*sizes[0],9*sizes[1],9*sizes[2]])
 p,v=loghouse('woodland',2);p.update(roof=(72,55,120),roof_light=(109,84,162),roof_dark=(46,35,83),glow_window=(127,208,241))
 tower(v,22,16,18,91)
 # Crystal above the tower.
 for y in range(139,153):
  r=max(0,5-abs(y-145))
  box(v,22-r,23+r,y,y+1,16-r,17+r,'glow_window')
 add('magicians_house',v,p,[10,12,10])
 # Closed chapel: long nave, flying timber braces, rose window, bell tower.
 p=dict(BASE);p.update(roof=(57,91,109),roof_light=(80,123,137),roof_dark=(35,57,78))
 _,v=loghouse('woodland',1);v=stretch(v,1.15,1.15,1.85)
 tower(v,0,-40,17,103)
 for y in range(70,84):
  box(v,-6,7,y,y+1,-59,-56,'beam')
  if y<81:box(v,-4,5,y,y+1,-60,-59,'brass')
 line(v,(0,139,-40),(0,158,-40),'brass',2);line(v,(-6,151,-40),(6,151,-40),'brass',2)
 for z in [-30,0,30]:
  for s in [-1,1]:line(v,(s*42,0,z),(s*31,45,z),'stone_light',3)
 add('chapel',v,p,[11,13,16])
 # Sculpted three-tier fountain: scalloped outer rim, raised bowls and central crystal.
 p=dict(BASE);p.update(stone=(119,145,153),stone_light=(177,199,196),glass=(69,167,207),glow_window=(99,210,235))
 v={}
 for y,r in [(0,49),(1,49),(2,47),(3,47),(4,47),(5,47),(6,47),(7,48),(8,48),(9,48),(19,24),(20,25),(21,26),(22,26),(35,13),(36,14),(37,15)]:
  for x in range(-r,r+1):
   for z in range(-r,r+1):
    d=math.hypot(x,z);rim=r-3<d<=r
    if rim or y in [0,1,19,35] and d<=r:v[x,y,z]='stone_light' if rim and (x+z)%9 else 'stone'
    if d<r-3 and y in [6,21,37]:v[x,y,z]='glass'
 for y in range(2,44):
  r=6 if y<20 else 4
  for x in range(-r,r+1):
   for z in range(-r,r+1):
    if x*x+z*z<r*r:v[x,y,z]='stone_light' if (x+z)%3==0 else 'stone'
 for y in range(43,61):
  r=max(1,6-abs(y-50)//2)
  for x in range(-r,r+1):
   for z in range(-r,r+1):
    if abs(x)+abs(z)<r+1:v[x,y,z]='glow_window' if x<0 else 'glass'
 for a in range(0,360,45):
  x,z=round(46*math.cos(math.radians(a))),round(46*math.sin(math.radians(a)))
  box(v,x-2,x+3,8,13,z-2,z+3,'brass')
 add('fountain',v,p,[12.5,7.5,12.5])
 # Beds are real tiny flowers, clipped hedges and timber borders, not terrain cubes.
 v={}
 for x in range(-30,31):
  for z in range(-45,46):
   if abs(x)>27 or abs(z)>42:box(v,x,x+1,0,3,z,z+1,'stone_light')
   elif abs(x)>23 or abs(z)>38:
    for y in range(2,8+(x+z)%3):v[x,y,z]='leaf'
   elif (x%7==0 and z%7==0):
    box(v,x,x+1,0,5,z,z+1,'leaf')
    for dx,dz in [(0,0),(-1,0),(1,0),(0,-1),(0,1)]:v[x+dx,5,z+dz]='flower' if z%2 else 'brass'
 add('garden_bed',v,BASE,[7.7,1.3,11.5])
 # Lanterns with carved plinths and warm suspended glass.
 v={};box(v,-3,4,0,3,-3,4,'stone');box(v,-1,2,3,31,-1,2,'iron')
 line(v,(0,30,0),(6,30,0),'iron',1)
 box(v,4,9,23,29,-2,3,'brass');box(v,5,8,24,28,-3,4,'glow_window');box(v,3,10,29,31,-3,4,'iron')
 add('lantern',v,BASE,[1.4,4,1.4])
 # Orchard and blossom trees, sculpted in the same native voxel scale.
 for name,leaf in [('orchard_tree',(74,122,63)),('blossom_tree',(207,140,162))]:
  p=dict(BASE);p['leaf']=leaf;p['leaf_light']=tuple(min(255,c+24) for c in leaf)
  v={}
  for y in range(0,35):
   for x in range(-3,4):
    for z in range(-3,4):
     if x*x+z*z<11:v[x,y,z]='wood_light' if x==-2 else 'wood'
  for x,z in [(-12,0),(10,3),(0,-12),(0,11)]:line(v,(0,18,0),(x,36,z),'wood',2)
  for cx,cy,cz,rx,ry,rz in [(0,44,0,19,15,19),(-12,35,-2,13,12,14),(12,37,5,12,13,14),(0,35,-13,14,12,12)]:
   for x in range(cx-rx,cx+rx+1):
    for y in range(cy-ry,cy+ry+1):
     for z in range(cz-rz,cz+rz+1):
      if ((x-cx)/rx)**2+((y-cy)/ry)**2+((z-cz)/rz)**2<1:
       v[x,y,z]='leaf_light' if (x*3+y*5+z*7)%17<4 else 'leaf'
  add(name,v,p,[1,4,1])
 print('Authored',len(SPECS),'native home voxel assets.')
if __name__=='__main__':main()
