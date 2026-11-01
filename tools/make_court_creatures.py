#!/usr/bin/env python3
"""Editable 32-grid dungeon bosses, expanded x8, and their smaller court cast."""
import json
from pathlib import Path
import redesign_pixel_bosses as a
R=Path(__file__).resolve().parents[1]
a.PAL['gold'].update(glow_eye=(255,223,117),glow_core=(240,173,46))
a.PAL['fire'].update(base=(69,48,43),light=(113,70,44),shade=(39,31,36),wing=(97,39,23),accent=(166,83,31))

def boss(name,theme,style,body,arms,variants,unit):
 parts={'body':body};limbs={}
 for side,label in [(-1,'l'),(1,'r')]:
  pivot=(side*5,18,0);part=arms(side)
  parts['arm_'+label]=part;limbs['arm_'+label]=a.limb('arm_'+label,pivot,'arm',side,throws=False)
 for form,colors in variants.items():parts['body_'+form]=a.recolor(body,colors)
 a.save(name,name.replace('_',' ').title(),theme,parts,limbs,{f:{'body':'body_'+f} for f in variants},(0,16,-5),unit=unit)
 for folder in [R/'creatures'/name,R/'creatures'/name/'source_32']:
  p=folder/'rig.json';rig=json.loads(p.read_text());rig['animation_style']=style;rig['bob']=0.025;p.write_text(json.dumps(rig,indent=2)+'\n')

# Tall flared robes, a scarab breastplate, split headdress and a crescent staff.
b={};a.polygon(b,[(-8,1),(-5,17),(-4,22),(4,22),(5,17),(8,1)],-3,4,'wing')
a.polygon(b,[(-3,2),(-2,20),(2,20),(3,2)],-4,-3,'base')
for y in [3,8,13]:a.box(b,(-5,y,-4),(5,y+1,4),'base')
a.box(b,(-3,21,-3),(3,26,3),'bone');a.box(b,(-3,22,-4),(3,25,-3),'dark')
for side in [-1,1]:
 a.box(b,(side*2-1,23,-5),(side*2+1,24,-4),'glow_eye')
 a.polygon(b,[(side*2,26),(side*6,31),(side*7,20),(side*4,18)],-2,2,'base')
 a.line(b,(side*4,27,-3),(side*5,21,-3),'belly')
a.diamond(b,(0,17,-4),2,3,'base');a.ell(b,(0,17,-6),(2,2,1),'glow_core')
a.box(b,(-4,26,-3),(4,28,3),'base')
def viz_arm(side):
 v={};a.box(v,(-2,-7,-2),(2,0,2),'wing');a.box(v,(-2,-8,-3),(2,-6,1),'base')
 if side>0:
  a.box(v,(-1,-14,-4),(1,8,-2),'base')
  for s in [-1,1]:a.line(v,(0,7,-3),(s*3,10,-3),'bone');a.line(v,(s*3,10,-3),(s*3,13,-3),'base')
  a.ell(v,(0,10,-3),(1,2,1),'glow_eye')
 return v
boss('gilded_vizier','gold','wraith',b,viz_arm,{'kindled':{'wing':'belly','glow_core':'glow_eye'},'unbound':{'wing':'dark','base':'light','glow_core':'glow_eye'}},.026)

# Squat prison furnace, crenellated shoulders and a visible molten chest behind bars.
b={};a.box(b,(-6,7,-4),(6,22,5),'shade');a.box(b,(-7,12,-3),(7,20,4),'base')
a.box(b,(-4,11,-5),(4,19,-4),'glow_core')
for x in [-4,-1,2]:a.box(b,(x,10,-6),(x+1,20,-4),'dark')
a.box(b,(-3,22,-3),(3,27,3),'dark');a.box(b,(-3,23,-4),(3,25,-3),'glow_eye')
a.box(b,(-1,22,-5),(1,27,-4),'shade')
for side in [-1,1]:
 a.box(b,(side*5-2,19,-4),(side*5+2,23,4),'dark')
 a.line(b,(side*5,22,0),(side*6,29,1),'shade',2)
 a.box(b,(side*3-2,0,-3),(side*3+2,8,3),'dark')
 a.box(b,(side*3-2,0,-5),(side*3+2,2,3),'base')
def warden_arm(side):
 v={};a.box(v,(-2,-7,-2),(2,0,2),'base');a.box(v,(-3,-11,-4),(3,-5,3),'dark')
 for y in [-9,-6]:a.box(v,(-3,y,-5),(3,y+1,-4),'glow_core')
 if side>0:
  a.box(v,(-1,-13,-5),(1,4,-3),'bone');a.box(v,(-4,1,-6),(4,6,-2),'shade')
  a.box(v,(-3,2,-7),(3,4,-6),'glow_eye')
 return v
boss('magma_warden','fire','tyrant',b,warden_arm,{'kindled':{'base':'accent','glow_core':'glow_eye'},'unbound':{'shade':'wing','base':'light','glow_core':'glow_eye'}},.029)

# Hollow trunk, sprawling roots and a crown of jagged burning limbs, no leaf-ball silhouette.
b={};a.polygon(b,[(-7,0),(-5,9),(-4,20),(-2,25),(3,24),(5,14),(6,6),(8,0)],-4,4,'base')
a.box(b,(-3,10,-5),(3,20,-4),'dark');a.polygon(b,[(-2,11),(-1,17),(1,19),(2,12)],-6,-5,'glow_core')
a.box(b,(-3,20,-5),(-1,22,-4),'glow_eye');a.box(b,(1,20,-5),(3,22,-4),'glow_eye')
for side in [-1,1]:
 for z in [-4,2]:
  a.line(b,(side*3,5,z),(side*9,1,z-2),'shade',2);a.line(b,(side*9,1,z-2),(side*13,0,z-4),'base')
 a.line(b,(side*3,22,0),(side*8,27,1),'shade',2)
 a.line(b,(side*8,27,1),(side*10,31,1),'base')
 a.line(b,(side*7,26,1),(side*13,28,2),'base',2)
 a.line(b,(side*13,28,2),(side*15,31,2),'glow_core')
 a.line(b,(side*3,23,1),(side*4,31,0),'accent',2)
 a.line(b,(side*4,28,0),(side*6,30,-1),'glow_eye')
for x,y,z in [(-6,27,0),(2,28,0),(7,28,1),(-2,25,-2),(11,28,2)]:
 a.polygon(b,[(x-1,y),(x,y+4),(x+1,y+1),(x+2,y+3),(x+2,y)],z,z+2,'glow_core')
def ent_arm(side):
 v={};a.line(v,(0,0,0),(side*4,-3,-1),'base',3);a.line(v,(side*4,-3,-1),(side*7,-8,-2),'shade',2)
 for dx in [-1,1]:a.line(v,(side*7,-7,-2),(side*(8+dx),-12,-4),'accent');a.line(v,(side*4,-3,0),(side*7,2,0),'base')
 a.line(v,(side*5,-5,-3),(side*7,-6,-3),'glow_core')
 return v
b={(x,min(y,31),z):c for (x,y,z),c in b.items()}
boss('pyre_ent','fire','tyrant',b,ent_arm,{'kindled':{'base':'wing','accent':'glow_core'},'unbound':{'shade':'dark','base':'accent','glow_core':'glow_eye'}},.040)

# Small rigs retain the cave cast's coarse, readable parts and animated limbs.
def small(name,theme,body,parts=None,limbs=None,unit=.12,hover=0):
 folder=R/'creatures'/name;folder.mkdir(exist_ok=True)
 rig=dict(voxel_size=unit,parts={},limbs=limbs or {},hand=[3,8,-3],bob=.035,waddle=.15,hover=hover)
 for n,v in {'body':body,**(parts or {})}.items():
  lo,size=a.bounds(v);solid={p:c for p,c in v.items() if not c.startswith('glow')};glow={p:c for p,c in v.items() if c.startswith('glow')}
  info=dict(frame_min=list(lo),frame_size=list(size))
  if solid:a.write(folder/(n+'.vox'),solid,a.PAL[theme],lo,size)
  else:info['solid']=False
  if glow:a.write(folder/(n+'_glow.vox'),glow,a.PAL[theme],lo,size);info['glow']=True
  rig['parts'][n]=info
 (folder/'rig.json').write_text(json.dumps(rig,indent=2)+'\n')

def humanoid(name,theme,kind,unit):
 b={};a.box(b,(-3,4,-2),(3,12,2),'bone' if kind=='mummy' else 'wing');a.box(b,(-3,12,-3),(3,17,3),'base')
 a.box(b,(-2,14,-4),(2,15,-3),'dark')
 for side in [-1,1]:b[side,14,-4]='glow_eye'
 if kind=='imp':
  for side in [-1,1]:a.line(b,(side*2,16,0),(side*4,20,0),'bone')
 elif kind=='mummy':
  for y in range(5,18,3):a.box(b,(-3,y,-3),(3,y+1,3),'bone')
 elif kind=='priest':
  a.polygon(b,[(-4,1),(-3,12),(3,12),(4,1)],-2,3,'wing');a.diamond(b,(0,19,0),3,3,'base')
 else:
  a.box(b,(-4,8,-3),(4,12,3),'shade');a.box(b,(-2,9,-4),(2,11,-3),'glow_core')
 arm={};a.box(arm,(-1,-6,-1),(1,0,1),'bone' if kind=='mummy' else 'base')
 weapon=dict(arm);a.box(weapon,(-1,-7,-3),(1,4,-2),'accent');a.diamond(weapon,(0,5,-2),2,2,'glow_eye')
 leg={};a.box(leg,(-1,-4,-1),(1,0,1),'shade')
 limbs={'arm_l':dict(part='arm',pivot=[-4,12,0]),'arm_r':dict(part='weapon',pivot=[4,12,0]),'leg_l':dict(part='leg',pivot=[-2,4,0]),'leg_r':dict(part='leg',pivot=[2,4,0])}
 small(name,theme,b,dict(arm=arm,weapon=weapon,leg=leg),limbs,unit)
for args in [('sand_imp','gold','imp',.09),('mummy_guard','gold','mummy',.14),('sun_priest','gold','priest',.11),('gilded_sentinel','gold','golem',.20),('magma_imp','fire','imp',.09),('lava_golem','fire','golem',.16),('cinder_cultist','fire','priest',.11),('obsidian_brute','fire','golem',.21)]:humanoid(*args)
for name,theme in [('tomb_scarab','gold'),('ash_crawler','fire')]:
 b={};a.ell(b,(0,4,0),(4,3,5),'base');a.line(b,(0,5,-5),(0,7,4),'light');a.box(b,(-2,3,-6),(2,4,-5),'glow_eye')
 leg={};a.line(leg,(0,0,0),(3,-1,0),'shade');a.line(leg,(3,-1,0),(4,-3,-1),'base')
 limbs={}
 for side in [-1,1]:
  for i,z in enumerate([-3,0,3]):limbs[str(side)+'leg'+str(i)]=dict(part='leg',pivot=[side*3,3,z],role='leg',axis='y',phase=side*(-1)**i,yaw=0 if side>0 else 180)
 small(name,theme,b,dict(leg=leg),limbs,.12)
b={};a.diamond(b,(0,7,0),3,4,'bone');a.box(b,(-2,7,-3),(2,8,-2),'glow_eye')
for x in [-4,3]:a.line(b,(x,4,0),(x+1,1,0),'glow_core')
small('dust_wisp','gold',b,hover=.35)
b={};a.ell(b,(0,5,0),(2,3,2),'shade');a.box(b,(-2,5,-3),(2,6,-2),'glow_eye')
w={};a.polygon(w,[(0,0),(7,4),(10,-1),(5,0),(3,-3)],0,1,'wing');a.line(w,(0,0,0),(7,4,0),'glow_core')
small('ember_bat','fire',b,dict(wing_l={(-x,y,z):c for (x,y,z),c in w.items()},wing_r=w),{'wing_l':dict(part='wing_l',pivot=[-2,6,0],role='wing',phase=-1),'wing_r':dict(part='wing_r',pivot=[2,6,0],role='wing',phase=1)},.12,.4)
for name,unit in [('cinder_sapling',.12),('flame_dryad',.16)]:
 b={};a.box(b,(-2,0,-2),(2,15,2),'base');a.box(b,(-2,10,-3),(2,12,-2),'dark')
 for side in [-1,1]:
  b[side,11,-3]='glow_eye';a.line(b,(side,14,0),(side*5,19,0),'accent');a.line(b,(side,2,0),(side*5,0,-2),'shade')
  a.line(b,(side*4,17,0),(side*5,21,0),'glow_core')
 arm={};a.line(arm,(0,0,0),(3,-3,0),'base');a.line(arm,(3,-3,0),(4,0,-1),'glow_core')
 small(name,'fire',b,dict(arm=arm),{'arm_l':dict(part='arm',pivot=[-2,13,0],yaw=180,role='arm'),'arm_r':dict(part='arm',pivot=[2,13,0],role='arm')},unit)

v={};a.diamond(v,(0,0,0),2,1,'base');a.line(v,(0,0,-6),(0,0,5),'glow_eye');a.projectile('sand_needle','gold',v,.010)
v={};a.ell(v,(0,0,0),(4,1,4),'base');a.ell(v,(0,0,0),(2,1,2),'glow_eye');a.projectile('sun_seal','gold',v,.012)
v={};a.ell(v,(0,0,0),(3,3,4),'shade');a.box(v,(-1,-1,-4),(1,1,2),'glow_core');a.line(v,(0,1,1),(0,3,6),'glow_eye');a.projectile('magma_seed','fire',v,.011)
v={};a.polygon(v,[(0,-5),(-3,0),(0,5),(3,0)],-1,1,'accent');a.line(v,(0,-4,-2),(0,4,-2),'glow_core');a.projectile('pyre_leaf','fire',v,.010)
v={};a.line(v,(-6,0,0),(6,0,0),'shade',2);a.line(v,(-2,1,0),(-4,1,-4),'base');a.line(v,(2,1,0),(4,1,4),'base');a.line(v,(-5,2,0),(5,2,0),'glow_core');a.projectile('burning_branch','fire',v,.023)
(R/'creatures/court_creatures_manifest.json').write_text(json.dumps([m for m in a.MANIFEST if m['id'] in ['gilded_vizier','magma_warden','pyre_ent']],indent=2)+'\n')
print('Court cast and projectiles complete')
