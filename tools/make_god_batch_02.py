#!/usr/bin/env python3
"""Native VOX gods and lesser creatures, exported using the project's rig conventions."""
import json,math
from PIL import Image,ImageDraw,ImageFont
from make_common_batch_01 import export
from voxel_sculpt import Part
from preview_voxel_batch import ROOT,assemble,render,BOLD,FONT
FIRE={'shell':(49,43,48),'shade':(73,57,55),'edge':(113,83,62),'bone':(216,183,126),'dark':(21,24,30),'glow':(242,93,24),'glow_hot':(255,202,79)}
ICE={'shell':(79,122,151),'shade':(53,83,117),'edge':(144,189,207),'bone':(231,238,226),'dark':(27,45,65),'glow':(91,211,230),'glow_hot':(191,248,251)}
MODELS={}
def part(pal):return Part(1,pal)
def limb(pivot,role='leg',phase=1,part='leg',**kw):return dict(part=part,pivot=pivot,role=role,phase=phase,**kw)
def save(name,pal,p,limbs={},parts={},hand=[0,10,-5],hover=0,size=.1):
 rig=dict(voxel_size=size,limbs=limbs,hand=[hand[0],hand[1]+hover/size,hand[2]],hover=hover,bob=.07 if hover else 0,waddle=.25)
 export(ROOT/'creatures'/name,{'body':p.voxels(),**parts},pal,rig)
 shot=part(pal);shot.capsule((0,0,2),(0,0,-3),1.2,.1,'glow');shot.ellipsoid((0,0,0),(1.4,1.4,1.5),'glow_hot')
 export(ROOT/'creatures'/name/'projectile',{'body':shot.voxels()},pal,dict(voxel_size=.075,limbs={},hand=[0,0,0],waddle=0))
 MODELS[name]=pal
# Squared volcanic walking fortress, glowing fault lines and slab fists.
p=part(FIRE);p.box((-5,5,-2),(5,13,3),'shell');p.box((-4,12,-3),(4,17,3),'shade');p.box((-4,14,-3.5),(4,15,-3),'dark')
for x in [-2.5,2.5]:p.box((x-.8,14,-3.8),(x+.8,15,-3.3),'glow_hot')
p.box((-.5,5,-2.5),(.5,12,-2),'glow');p.box((-3,8,-2.5),(3,9,-2),'glow');p.box((-5,12,0),(-3,15,4),'edge')
a=part(FIRE);a.box((-2,-7,-2),(2,0,2),'shell');a.box((-2,-6,-2.5),(2,-5,-2),'glow');a.box((-2,-8,-3),(2,-6,2),'shade')
l=part(FIRE);l.box((-1.5,-5,-1.5),(1.5,0,1.5),'shade');l.box((-2,-5,-3),(2,-3.5,2),'shell')
save('basalt_bulwark',FIRE,p,{'arm_l':limb([-7,12,0],'arm',1,'arm',throws=False),'arm_r':limb([7,12,0],'arm',-1,'arm',throws=True),'leg_l':limb([-3,5,0]),'leg_r':limb([3,5,0],phase=-1)},dict(arm=a.voxels(),leg=l.voxels()),[7,5,-3])
# Six-legged furnace creature, enormous flared mouth and back chimneys.
p=part(FIRE);p.ellipsoid((0,7,1),(6,4,7),'shell');p.ellipsoid((0,8,-5),(5,3.5,3),'edge');p.ellipsoid((0,8,-7),(3.8,2.6,1),'dark');p.ellipsoid((0,8,-7.6),(2.7,1.8,.5),'glow');p.ellipsoid((0,8,-7.9),(1.5,1,.3),'glow_hot')
for x in [-3,3]:
 p.box((x-1,7,2),(x+1,14,4),'shade');p.box((x-.6,12,1.8),(x+.6,14,4.2),'glow')
 for y in [6,10]:p.capsule((x,y,-7),(x*.8,y+(.6 if y==6 else -.6),-8),.5,.15,'bone')
l=part(FIRE);l.chain([(0,0,0),(3,-1,1),(4,-4,0)],1,.6,'shade')
left={(-x-1,y,z):c for (x,y,z),c in l.voxels().items()};limbs={}
for i,z in enumerate([-3,1,5]):
 for s in [-1,1]:limbs[f'leg_{s}_{i}']=limb([s*5,4,z],phase=(-1 if (i+(s>0))%2 else 1),part='leg_l' if s<0 else 'leg_r',axis='y',amount=.4)
save('furnace_maw',FIRE,p,limbs,dict(leg_l=left,leg_r=l.voxels()),[0,8,-8.5])
# Obsidian floating censer with hanging chains and a single eye, not a boss crown.
p=part(FIRE);p.ellipsoid((0,9,0),(4,4,3),'shell');p.box((-4,6,-3),(4,10,3),'shade');p.box((-3,10,-2),(3,13,2),'shell');p.box((-3,9,-3.5),(3,10,-3),'glow');p.box((-.5,8,-4),(.5,11,-3.5),'glow_hot')
for s in [-1,1]:
 p.chain([(s*4,9,0),(s*6,7,0),(s*5,4,0)],.6,.4,'edge');p.ellipsoid((s*5,4,0),(1.7,1.4,1.7),'glow')
for x in [-2,0,2]:p.chain([(x,6,0),(x,3,0),(x+1,1,1)],.45,.2,'edge')
save('cinder_oracle',FIRE,p,hand=[0,9.5,-4.4],hover=.4)
# Long-legged frost cervid, branching antlers and a crystalline throat.
p=part(ICE);p.ellipsoid((0,9,1),(3,3,5.5),'bone');p.chain([(0,9,-3),(0,14,-5)],2.5,1.8,'edge');p.ellipsoid((0,15,-5),(2.2,2.4,2),'bone');p.ellipsoid((0,14,-7),(1.5,1.3,1.8),'shade');p.box((-.6,12,-6.8),(.6,14,-6),'glow')
for s in [-1,1]:
 p.box((s*1.7-.4,15,-6.7),(s*1.7+.4,16,-6),'glow_hot');p.chain([(s,16,-4),(s*3,20,-3),(s*4,23,-4)],.7,.25,'edge');p.chain([(s*2.4,19,-3.5),(s*4.5,20,-2),(s*5.5,22,-2)],.55,.15,'glow');p.capsule((s*3,20,-3),(s*1.5,22,-2),.5,.15,'bone')
l=part(ICE);l.capsule((0,0,0),(0,-7,0),.8,.6,'edge');l.box((-1,-8,-2),(1,-6.8,1),'shade')
limbs={f'leg_{s}_{z}':limb([s*2,8,z],phase=s*(1 if z<0 else -1)) for s in [-1,1] for z in [-3,5]}
save('rime_stag',ICE,p,limbs,dict(leg=l.voxels()),[0,14,-9],size=.085)
# Spiral-armored hermit, ice spines and an asymmetric oversized claw.
p=part(ICE);p.ellipsoid((0,7,2),(5.5,5,5.5),'shade');p.ellipsoid((0,8,2),(4.5,4.5,5),'edge');p.ellipsoid((0,9,6),(3.5,3.4,.7),'bone');p.ellipsoid((0,9,6.6),(2.5,2.4,.4),'shade');p.ellipsoid((0,9,6.9),(1.4,1.4,.3),'glow');p.ellipsoid((0,5,-3),(4,2.6,3),'shade')
for s in [-1,1]:p.capsule((s*2.5,6,-4),(s*2.5,9,-5),.6,.6,'edge');p.ellipsoid((s*2.5,9,-5),(1,1,.8),'glow_hot')
for x,z in [(-3,0),(3,0),(0,2)]:p.capsule((x,10,z),(x*1.2,15,z+1),1,.15,'glow')
c=part(ICE);c.chain([(0,0,0),(2,0,-3),(3,1,-6)],1.3,2.0,'edge');c.capsule((3,1,-6),(2,2,-9),1.3,.4,'bone');c.capsule((3,1,-6),(4,0,-9),1.3,.4,'bone')
l=part(ICE);l.chain([(0,0,0),(3,-1,0),(4,-3,-1)],.8,.5,'shade')
vl={(-x-1,y,z):co for (x,y,z),co in l.voxels().items()};cl={(-x-1,y,z):co for (x,y,z),co in c.voxels().items()}
limbs={'claw_l':limb([-4,5,-2],'claw',1,'claw_l'),'claw_r':limb([4,5,-2],'claw',-1,'claw_r')}
for i,z in enumerate([0,3]):
 for s in [-1,1]:limbs[f'leg_{s}_{i}']=limb([s*4,3,z],phase=s*(-1 if i else 1),part='leg_l' if s<0 else 'leg_r',axis='y',amount=.5)
save('glacier_hermit',ICE,p,limbs,dict(claw_l=cl,claw_r=c.voxels(),leg_l=vl,leg_r=l.voxels()),[0,5,-6])
# Angular snow raptor, swept flight feathers and a fan tail.
p=part(ICE);p.ellipsoid((0,8,0),(2,3,3),'bone');p.ellipsoid((0,11,-2),(2,2,2),'edge');p.capsule((0,11,-3),(0,10,-6),1.2,.1,'shade');p.box((-2,11,-3.5),(2,12,-3),'dark');p.box((-1.7,11,-3.7),(1.7,11.6,-3.4),'glow_hot')
for x in [-2,0,2]:p.capsule((0,6,2),(x,4,6),1,.2,'edge')
w=part(ICE)
for i in range(5):w.chain([(0,0,0),(3+i,1-i*.6,0),(7+i,1-i,2+i*.7)],1.2,.15,'bone' if i%2 else 'edge')
w.chain([(0,0,-.7),(4,0,-.7),(8,0,1)],.55,.2,'glow')
v=w.voxels();vl={(-x-1,y,z):c for (x,y,z),c in v.items()}
save('hail_harrier',ICE,p,{'wing_l':limb([-1,9,0],'wing',1,'wing_l'),'wing_r':limb([1,9,0],'wing',-1,'wing_r')},dict(wing_l=vl,wing_r=v),[0,10,-6.5],hover=.65,size=.09)
# Lesser enemies with their own silhouettes, also used as finite followers.
for name,pal,kind in [('ember_mite',FIRE,0),('rime_skitter',ICE,1),('snow_wisp',ICE,2)]:
 p=part(pal)
 if kind<2:
  p.ellipsoid((0,3,0),(3,2,4),'shell');p.ellipsoid((0,4,0),(2.2,1.5,2.8),'glow' if kind==0 else 'bone')
  for x in [-1.5,1.5]:p.ellipsoid((x,3,-3.5),(.6,.6,.5),'glow_hot')
  for s in [-1,1]:
   for z in [-2,1,3]:p.chain([(s*2,3,z),(s*4,2,z),(s*4.5,0,z-1)],.5,.25,'edge')
  if kind==1:
   for z in [-1,2]:p.capsule((0,4,z),(0,7,z+1),.8,.1,'glow')
 else:
  p.ellipsoid((0,4,0),(2.3,2.8,2),'bone');p.ellipsoid((0,4,-1.8),(1.4,1,.4),'dark');p.box((-.7,4,-2.4),(.7,5,-2),'glow_hot');p.chain([(0,2,0),(1,0,1),(2,-1,2)],1,.1,'glow')
 save(name,pal,p,hand=[0,3,-4],hover=.4 if kind==2 else 0,size=.09)
# Contact sheet renders actual voxel geometry.
sheet=Image.new('RGB',(3*460,3*410),'#202832');d=ImageDraw.Draw(sheet)
for j,name in enumerate(MODELS):
 v,_=assemble(ROOT/'creatures'/name);sheet.paste(render(v,460,350),(j%3*460,j//3*410));d.text((j%3*460+18,j//3*410+367),name.replace('_',' ').title(),font=ImageFont.truetype(BOLD,22),fill='white')
out=ROOT/'creatures/batch_02_preview.png';sheet.save(out);print(f'Created {len(MODELS)} rigged models and projectile assets: {out}')
