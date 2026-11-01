#!/usr/bin/env python3
"""Five standalone grave-marker props, authored on a chunky voxel grid."""
import json,math,struct
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'props/gravestones'
UNIT=.08
PAL={'wood':(126,85,49),'wood_light':(157,110,63),'wood_dark':(80,51,33),'rope':(179,150,99),'iron':(58,59,62),'earth':(89,70,47),'earth_light':(118,91,55),'grass':(87,117,64),'stone':(121,132,139),'stone_light':(168,180,181),'stone_dark':(76,86,96),'stone_edge':(140,154,161),'lichen':(118,139,97),'ink':(40,48,60),'granite':(63,76,94),'granite_light':(91,112,134),'granite_dark':(38,48,65),'gold':(201,151,55),'gold_light':(236,191,83),'gold_dark':(136,91,37),'marble':(221,225,213),'marble_light':(244,239,217),'marble_dark':(165,185,186),'glow_blue':(71,183,211),'glow_pearl':(126,225,221)}
def box(v,a,b,c):
 for x in range(a[0],b[0]):
  for y in range(a[1],b[1]):
   for z in range(a[2],b[2]):v[x,y,z]=c

def line(v,a,b,c):
 steps=max(abs(b[i]-a[i]) for i in range(3))*3+1
 for j in range(steps):v[tuple(round(a[k]+(b[k]-a[k])*j/max(1,steps-1)) for k in range(3))]=c

def ellipse(v,rx,rz,y,c):
 for x in range(-rx,rx+1):
  for z in range(-rz,rz+1):
   if (x/(rx+.5))**2+(z/(rz+.5))**2<=1:v[x,y,z]=c

def arch(v,width,bottom,shoulder,top,depth,c):
 half=width//2
 for y in range(bottom,top+1):
  inset=0 if y<=shoulder else math.ceil((y-shoulder)/(top-shoulder)*min(half-1,3))
  box(v,(-half+inset,y,-depth),(half-inset+1,y+1,depth+1),c)

def inscription(v,text,y,z,color='ink'):
 glyphs={'R':['110','101','110','101','101'],'I':['111','010','010','010','111'],'P':['110','101','110','100','100']}
 start=-((len(text)*4-1)//2)
 for n,ch in enumerate(text):
  for row,bits in enumerate(glyphs[ch]):
   for col,bit in enumerate(bits):
    if bit=='1':v[-(start+n*4+col),y+4-row,z]=color

def wood():
 v={};ellipse(v,4,3,0,'earth');ellipse(v,3,2,1,'earth_light')
 box(v,(-1,1,-1),(1,13,1),'wood');box(v,(-4,8,-1),(4,10,1),'wood')
 box(v,(-1,11,-1),(0,13,1),'wood_light')
 for y in [2,3,6,7,11]:v[-1,y,-1]='wood_dark'
 for x in [-3,-2,2,3]:v[x,9,-1]='wood_light'
 for y in [8,9,10]:v[0,y,-2]='rope'
 v[-1,9,-2]='iron';v[1,8,-2]='rope';v[-1,11,-2]='wood_dark'
 v[-3,1,1]='grass';v[-3,2,1]='grass';v[3,1,-1]='grass'
 return v

def fieldstone():
 v={};ellipse(v,7,4,0,'earth');box(v,(-6,0,-3),(7,2,4),'stone_dark')
 arch(v,13,2,11,15,1,'stone')
 for y in range(3,12):v[-6,y,-1]='stone_dark';v[6,y,-1]='stone_edge'
 box(v,(-5,3,-2),(6,4,-1),'stone_dark')
 inscription(v,'RIP',6,-2)
 line(v,(3,14,-2),(2,12,-2),'stone_dark');v[3,11,-2]='stone_dark'
 v.pop((-3,15,-1),None)
 for p in [(-5,3,-2),(-5,4,-2),(-4,3,-2),(5,2,-2),(4,2,-2)]:v[p]='lichen'
 return v

def veteran():
 v={};box(v,(-8,0,-4),(9,2,5),'stone_dark');box(v,(-7,2,-3),(8,4,4),'stone_edge')
 arch(v,15,4,16,20,2,'stone')
 arch(v,13,5,16,19,2,'stone_light')
 box(v,(-7,5,-3),(-6,16,-2),'stone_dark');box(v,(6,5,-3),(7,16,-2),'stone_edge')
 box(v,(-6,8,-3),(7,15,-2),'stone_dark');box(v,(-5,9,-4),(6,14,-3),'stone')
 inscription(v,'RIP',9,-5)
 # A carved cross with a slightly raised central boss, above the epitaph.
 box(v,(0,16,-3),(1,20,-2),'stone_dark');box(v,(-2,18,-3),(3,19,-2),'stone_dark')
 v[0,18,-4]='iron'
 for x in range(-5,6):v[x,4,-3]='stone_light'
 for x in [-4,0,4]:v[x,6,-3]='stone_dark'
 return v

def hero():
 v={};box(v,(-9,0,-5),(10,2,6),'granite_dark');box(v,(-8,2,-4),(9,4,5),'granite_light');box(v,(-7,4,-3),(8,5,4),'gold_dark')
 arch(v,15,5,19,24,2,'granite')
 for x in [-7,7]:
  box(v,(x,5,-3),(x+1,19,3),'gold_dark');box(v,(x,6,-4),(x+1,18,-3),'gold')
 box(v,(-8,18,-3),(9,20,3),'granite_light');box(v,(-6,20,-3),(7,21,3),'gold')
 # A bronze sword and shield carved into the tomb's dark face.
 for y in range(10,18):
  r=3 if y>=13 else max(0,y-10)
  box(v,(-r,y,-3),(r+1,y+1,-2),'granite_dark')
 box(v,(0,10,-4),(1,19,-3),'gold_light');box(v,(-2,16,-4),(3,17,-3),'gold')
 box(v,(0,18,-4),(1,20,-3),'wood_dark');v[0,20,-4]='glow_blue'
 for x in [-4,-2,0,2,4]:box(v,(x,6,-3),(x+1,8,-2),'stone_edge')
 # Two restrained blue votive stones on the lower step.
 for x in [-6,6]:
  box(v,(x-1,4,-4),(x+1,6,-2),'gold_dark');v[x,6,-3]='glow_blue'
 return v

def legend():
 v={};box(v,(-12,0,-6),(13,2,7),'marble_dark');box(v,(-11,2,-5),(12,4,6),'marble');box(v,(-9,4,-4),(10,5,5),'gold_dark');box(v,(-8,5,-3),(9,6,4),'marble_light')
 arch(v,13,6,23,27,2,'marble')
 for x in [-6,6]:box(v,(x,6,-3),(x+1,23,-2),'gold')
 box(v,(-5,8,-3),(6,21,-2),'granite_dark')
 inscription(v,'RIP',10,-4,'marble_light')
 # Small funerary skull above the inscription; dark eyes keep it legible.
 box(v,(-2,17,-4),(3,20,-3),'marble_light')
 box(v,(-1,16,-4),(2,17,-3),'marble')
 v[-1,18,-5]='ink';v[1,18,-5]='ink';v[0,17,-5]='gold_dark'
 # Paired carved feathers, stepped and swept upward around the slab.
 for side in [-1,1]:
  for offset in range(6):
   x=side*(7+offset)
   low=11+offset*2
   high=20+offset
   for y in range(low,high+1):
    v[x,y,0]='marble_light' if offset%2==0 else 'marble'
    v[x,y,1]='marble_dark'
   v[x,low,-1]='gold_dark'
  line(v,(side*6,11,0),(side*12,24,0),'gold')
 # Crown and a tiny spirit crystal at the peak, rather than a fully glowing slab.
 box(v,(-4,24,-2),(5,25,3),'gold')
 for x in [-3,0,3]:box(v,(x,25,-2),(x+1,27 if x else 28,-1),'gold_light')
 for y in range(27,31):
  r=0 if y in [27,30] else 1
  box(v,(-r,y,0),(r+1,y+1,1),'glow_pearl')
 for x in [-8,8]:box(v,(x-1,4,-4),(x+2,6,-1),'marble');v[x,6,-3]='glow_pearl'
 return v

def bounds(v):
 lo=tuple(min(p[k] for p in v) for k in range(3));size=tuple(max(p[k] for p in v)-lo[k]+1 for k in range(3))
 return lo,size

def write(path,v,lo,size):
 names=list(PAL);indices={c:i+1 for i,c in enumerate(names)}
 data=bytearray(struct.pack('<I',len(v)))
 for (x,y,z),c in v.items():data.extend((z-lo[2],x-lo[0],y-lo[1],indices[c]))
 rgba=b''.join(bytes((*PAL[names[i]],255)) if i<len(names) else bytes((0,0,0,255)) for i in range(256))
 def chunk(k,b):return k+struct.pack('<II',len(b),0)+b
 children=chunk(b'SIZE',struct.pack('<III',size[2],size[0],size[1]))+chunk(b'XYZI',data)+chunk(b'RGBA',rgba)
 path.write_bytes(b'VOX '+struct.pack('<I',150)+b'MAIN'+struct.pack('<II',0,len(children))+children)


def main():
 OUT.mkdir(exist_ok=True);manifest=[]
 for tier,(key,title,rank,builder) in enumerate([
  ('t1_wooden','Wooden Marker','Novice',wood),('t2_fieldstone','Weathered Headstone','Adventurer',fieldstone),('t3_veteran','Carved Veteran Grave','Veteran',veteran),('t4_hero','Hero Memorial','Hero',hero),('t5_legend','Winged Legend Monument','Legend',legend)],1):
  v=builder();lo,size=bounds(v);folder=OUT/key;folder.mkdir(exist_ok=True)
  write(folder/'model.vox',v,lo,size)
  for suffix,data in [('',{p:c for p,c in v.items() if not c.startswith('glow')}),('_glow',{p:c for p,c in v.items() if c.startswith('glow')})]:
   if data:write(folder/('body'+suffix+'.vox'),data,lo,size)
  info=dict(tier=tier,name=title,rank_hint=rank,status='art_only',voxel_size=UNIT,parts={'body':dict(frame_min=list(lo),frame_size=list(size),glow=any(c.startswith('glow') for c in v.values()))},limbs={},hand=[0,0,0],facing='-Z',size_m=[round(n*UNIT,3) for n in size])
  (folder/'rig.json').write_text(json.dumps(info,indent=2)+'\n')
  manifest.append(dict(id=key,tier=tier,name=title,rank_hint=rank,folder='props/gravestones/'+key,scene='props/gravestones/'+key+'/model.tscn',size_voxels=list(size),size_m=info['size_m']))
 (OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 (OUT/'palette.json').write_text(json.dumps(PAL,indent=2)+'\n')
 print('Authored five gravestone tiers')
if __name__=='__main__':main()
