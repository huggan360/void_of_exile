#!/usr/bin/env python3
"""Bluelay dungeon cast: editable coarse rigs and 32-grid, x8 boss masters."""
import ast, json
from pathlib import Path
import redesign_pixel_bosses as a
R=Path(__file__).resolve().parents[1]
# Reuse the established rig writers without running the court's content generator.
source=ast.parse((R/'tools/make_court_creatures.py').read_text())
for node in source.body:
 if isinstance(node,ast.FunctionDef) and node.name in ('small','boss'):
  exec(compile(ast.Module(body=[node],type_ignores=[]),'court_rig_helpers','exec'))
a.PAL['blue'].update(bone=(163,204,213),accent=(87,113,173),glow_eye=(154,245,255),glow_core=(52,208,205))

def face(b,y=14,z=-4):
 a.box(b,(-2,y,z),(2,y+2,z+1),'dark')
 for side in [-1,1]:b[side,y+1,z-1]='glow_eye'

def robed(name,kind,unit):
 b={};a.polygon(b,[(-5,1),(-3,14),(3,14),(5,1)],-2,3,'wing');a.box(b,(-3,13,-3),(3,19,3),'shade');face(b,15)
 for y in [3,7,11]:a.box(b,(-3,y,-3),(3,y+1,-2),'accent')
 if kind=='knight':
  a.box(b,(-4,8,-4),(4,14,-2),'base');a.box(b,(-3,18,-3),(3,20,3),'bone');a.diamond(b,(0,12,-5),2,2,'glow_core')
 if kind=='bell':
  a.polygon(b,[(-5,14),(-3,21),(3,21),(5,14)],-4,4,'bone');a.box(b,(-5,13,-4),(5,15,4),'accent');a.line(b,(0,13,-5),(0,10,-5),'glow_eye')
 if kind=='ghost':
  for side in [-1,1]:a.line(b,(side*3,18,0),(side*5,23,1),'light');a.line(b,(side*3,2,1),(side*6,0,1),'glow_core')
 arm={};a.box(arm,(-1,-6,-1),(1,0,1),'light')
 weapon=dict(arm);a.line(weapon,(0,-8,-3),(0,6,-3),'bone');a.diamond(weapon,(0,6,-3),2,2,'glow_core')
 small(name,'blue',b,dict(arm=arm,weapon=weapon),{'arm_l':dict(part='arm',pivot=[-4,13,0],role='arm',phase=-1),'arm_r':dict(part='weapon',pivot=[4,13,0],role='arm',phase=1)},unit, .25 if kind=='ghost' else 0)
for args in [('reef_guardian','knight',.15),('drowned_acolyte','priest',.11),('tide_knight','knight',.16),('choir_wraith','ghost',.13),('bell_warden','bell',.19)]:robed(*args)
for name,unit in [('grotto_crab',.13),('coral_skitter',.10),('brine_matron',.40)]:
 b={};a.ell(b,(0,4,0),(4,3,5),'base');face(b,4,-5)
 for side in [-1,1]:
  a.line(b,(side*3,5,0),(side*5,10,1),'accent');a.diamond(b,(side*5,10,1),1,3,'glow_core')
 if name=='brine_matron':
  for x in [-2,0,2]:a.diamond(b,(x,8,0),1,3,'glow_eye')
 leg={};a.line(leg,(0,0,0),(3,-1,0),'shade');a.line(leg,(3,-1,0),(4,-3,-1),'light')
 claw={};a.line(claw,(0,0,0),(3,0,-3),'base',2);a.box(claw,(1,0,-6),(5,2,-3),'accent');a.box(claw,(2,0,-6),(3,2,-4),'dark')
 limbs={}
 for side in [-1,1]:
  for i,z in enumerate([-3,0,3]):limbs[f'leg{side}_{i}']=dict(part='leg',pivot=[side*3,3,z],role='leg',axis='y',phase=side*(-1)**i,yaw=0 if side>0 else 180)
  limbs[f'claw{side}']=dict(part='claw',pivot=[side*4,4,-3],role='arm',yaw=0 if side>0 else 180)
 small(name,'blue',b,dict(leg=leg,claw=claw),limbs,unit)
b={};a.diamond(b,(0,7,0),3,5,'belly');face(b,7,-3)
for side in [-1,1]:a.line(b,(side*2,5,0),(side*4,1,0),'glow_core')
small('tide_wisp','blue',b,unit=.13,hover=.4)
b={};a.ell(b,(0,10,0),(5,4,5),'belly');a.box(b,(-4,8,-4),(4,9,4),'glow_core');face(b,10,-5)
t={};a.line(t,(0,0,0),(1,-5,1),'accent');a.line(t,(1,-5,1),(-1,-8,0),'glow_core')
small('bubble_jelly','blue',b,dict(tentacle=t),{f't{i}':dict(part='tentacle',pivot=[x,8,z],role='arm',phase=(-1)**i) for i,(x,z) in enumerate([(-3,-2),(3,-2),(-3,2),(3,2)])},.13,.3)
for name,unit in [('deep_angler',.19),('spire_eel',.11)]:
 b={};a.ell(b,(0,6,0),(4,4,6),'shade');a.line(b,(0,6,4),(0,4,12),'base',2);face(b,6,-6)
 for side in [-1,1]:a.polygon(b,[(side*3,5),(side*8,9),(side*5,3)],-1,2,'wing')
 if name=='deep_angler':
  a.box(b,(-3,3,-7),(3,5,-5),'dark');a.line(b,(0,9,-2),(0,14,-3),'accent');a.line(b,(0,14,-3),(0,14,-7),'bone');a.ell(b,(0,13,-7),(2,2,2),'glow_eye')
 small(name,'blue',b,unit=unit,hover=.25)
# Boss silhouettes: curling mermaid tail and coral crown / bell mitre and choir mantle.
for name in ['abyssal_siren','drowned_cantor']:
 b={};a.polygon(b,[(-6,2),(-4,16),(-3,23),(3,23),(4,16),(6,2)],-3,4,'wing');a.box(b,(-3,23,-3),(3,28,3),'bone');face(b,24,-4)
 a.diamond(b,(0,19,-4),2,3,'glow_core')
 if name=='abyssal_siren':
  a.line(b,(0,8,2),(8,3,4),'base',3);a.line(b,(8,3,4),(12,5,2),'light',2)
  a.polygon(b,[(10,4),(15,9),(15,3),(11,1)],1,4,'belly')
  for side in [-1,1]:
   a.line(b,(side*2,27,0),(side*6,31,0),'accent');a.line(b,(side*4,29,0),(side*7,29,0),'glow_core')
 else:
  a.polygon(b,[(-6,23),(-3,31),(3,31),(6,23)],-3,4,'base');a.box(b,(-6,22,-4),(6,24,4),'bone')
  a.line(b,(0,25,-5),(0,30,-5),'glow_eye')
  for side in [-1,1]:
   a.polygon(b,[(side*3,21),(side*12,18),(side*10,5),(side*6,8)],0,4,'shade')
   for y in [9,14,19]:a.line(b,(side*6,y,-1),(side*10,y-2,-1),'glow_core')
 def arms(side):
  v={};a.box(v,(-2,-8,-2),(2,0,2),'base');a.box(v,(-2,-9,-3),(2,-7,1),'bone')
  if side>0:
   a.line(v,(0,-12,-4),(0,8,-4),'bone')
   if name=='drowned_cantor':
    a.polygon(v,[(-4,2),(-2,8),(2,8),(4,2)],-6,-2,'accent');a.box(v,(-4,1,-6),(4,3,-2),'glow_eye')
   else:a.diamond(v,(0,7,-4),3,4,'glow_eye')
  return v
 boss(name,'blue','wraith',b,arms,{'resonant':{'glow_core':'glow_eye','wing':'accent'},'unbound':{'wing':'dark','base':'light','glow_core':'glow_eye'}},.027 if name=='abyssal_siren' else .029)
for name in ['tide_shard','siren_echo','bell_note']:
 v={}
 if name=='tide_shard':a.diamond(v,(0,0,0),2,2,'light');a.line(v,(0,0,-6),(0,0,5),'glow_core')
 elif name=='siren_echo':
  a.ell(v,(0,0,0),(5,1,5),'light');a.ell(v,(0,0,0),(3,1,3),'glow_eye')
 else:
  a.line(v,(1,0,-4),(1,0,3),'bone');a.ell(v,(-1,0,3),(3,1,2),'glow_core');a.line(v,(1,0,-4),(4,0,-2),'glow_eye')
 a.projectile(name,'blue',v,.012)
(R/'creatures/blue_dungeon_manifest.json').write_text(json.dumps([m for m in a.MANIFEST if m['id'] in ['abyssal_siren','drowned_cantor']],indent=2)+'\n')
print('Blue dungeon models complete')
