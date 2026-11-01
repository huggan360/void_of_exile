#!/usr/bin/env python3
"""Orthographic previews of real .vox geometry and assembled CreatureModel rigs.
No game files or spawn tables are changed. Coordinates match make_creatures.py.
"""
import json,math,struct
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1]
FONT='/usr/share/fonts/TTF/DejaVuSans.ttf'
BOLD='/usr/share/fonts/TTF/DejaVuSans-Bold.ttf'
def read_vox(path):
 b=Path(path).read_bytes();assert b[:4]==b'VOX ';off=20;points=[];palette=[];size=None
 while off<len(b):
  key=b[off:off+4];n,children=struct.unpack_from('<II',b,off+4);content=b[off+12:off+12+n]
  if key==b'SIZE':size=struct.unpack('<III',content)
  elif key==b'XYZI':
   count=struct.unpack_from('<I',content)[0];points=[tuple(content[4+4*i:8+4*i]) for i in range(count)]
  elif key==b'RGBA':palette=[tuple(content[4*i:4*i+3]) for i in range(256)]
  off+=12+n
 assert size and points and len(palette)==256,path
 return {(b,c,a):palette[k-1] for a,b,c,k in points}
def assemble(folder):
 folder=Path(folder);rig=json.loads((folder/'rig.json').read_text());v={}
 for part,pivot,yaw in [('body',[0,0,0],0)]+[(s['part'],s['pivot'],s.get('yaw',0)) for s in rig['limbs'].values()]:
  frame=rig['parts'][part]['frame_min'];a=math.radians(yaw);ca,sa=math.cos(a),math.sin(a)
  for suffix in ['', '_glow']:
   f=folder/(part+suffix+'.vox')
   if not f.exists():continue
   for p,color in read_vox(f).items():
    x,y,z=[p[k]+frame[k] for k in range(3)]
    xyz=(round(ca*x+sa*z+pivot[0]),round(y+pivot[1]),round(-sa*x+ca*z+pivot[2]))
    v[xyz]=(color,suffix=='_glow')
 return v,rig

def render(v,width=460,height=400,yaw=35,scale=None):
 # Painter's algorithm over exposed faces, with a low orthographic camera.
 a=math.radians(yaw);h=math.radians(28);ca,sa=math.cos(a),math.sin(a);sh,ch=math.sin(h),math.cos(h)
 right=np.array([ca,0,sa]);up=np.array([-sa*sh,ch,ca*sh]);eye=np.array([-sa*ch,sh,ca*ch])
 # Front of the creature is -z; camera sees the front and its left flank.
 eye=np.array([sa*ch,sh,-ca*ch]);right=np.array([ca,0,sa]);up=np.cross(right,eye)
 points=np.array(list(v),float);px=points@right;py=points@up
 if scale is None:scale=min((width-60)/max(1,np.ptp(px)+3),(height-55)/max(1,np.ptp(py)+3))
 center=((px.min()+px.max())/2,(py.min()+py.max())/2)
 def proj(p):return (width/2+(np.dot(p,right)-center[0])*scale,height/2-(np.dot(p,up)-center[1])*scale)
 faces=[]
 shapes=[((1,0,0),[(1,0,0),(1,1,0),(1,1,1),(1,0,1)],.77),((-1,0,0),[(0,0,0),(0,0,1),(0,1,1),(0,1,0)],.86),((0,1,0),[(0,1,0),(0,1,1),(1,1,1),(1,1,0)],1.12),((0,0,-1),[(0,0,0),(0,1,0),(1,1,0),(1,0,0)],.94),((0,0,1),[(0,0,1),(1,0,1),(1,1,1),(0,1,1)],.73)]
 for pos,(color,glow) in v.items():
  p=np.array(pos,float)
  for normal,corners,light in shapes:
   if np.dot(normal,eye)<=0:continue
   n=tuple(pos[i]+normal[i] for i in range(3))
   if n in v:continue
   pts=[p+corner for corner in corners];depth=np.dot(p+0.5+np.array(normal)*.5,eye)
   rgb=tuple(min(255,int(c*(1.08 if glow else light))) for c in color)
   faces.append((depth,[proj(q) for q in pts],rgb))
 im=Image.new('RGB',(width*2,height*2),'#202832');d=ImageDraw.Draw(im)
 for _,poly,color in sorted(faces,key=lambda f:f[0]):d.polygon([(x*2,y*2) for x,y in poly],fill=color)
 return im.resize((width,height),Image.Resampling.LANCZOS)

def reference():
 names=['goblin','crab','sand_scorpion','green_dragon','genie_brown','spirit_purple'];sheet=Image.new('RGB',(3*380,2*360),'#202832');d=ImageDraw.Draw(sheet)
 for j,name in enumerate(names):
  v,_=assemble(ROOT/'creatures'/name);sheet.paste(render(v,380,310),((j%3)*380,(j//3)*360));d.text(((j%3)*380+18,(j//3)*360+320),name,font=ImageFont.truetype(BOLD,18),fill='white')
 sheet.save(ROOT/'creatures/staging/common_batch_01/existing_enemies_reference.png')
if __name__=='__main__':reference()
