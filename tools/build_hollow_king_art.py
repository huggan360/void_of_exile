#!/usr/bin/env python3
"""32-cell editable knight masters, expanded with the existing pixel boss pipeline."""
import json, importlib.util, zipfile
from pathlib import Path
from PIL import Image
spec=importlib.util.spec_from_file_location('pixel',Path(__file__).with_name('redesign_pixel_bosses.py'))
p=importlib.util.module_from_spec(spec);spec.loader.exec_module(p)
p.PAL['void']={'base':(30,33,43),'light':(174,182,197),'shade':(17,20,29),'belly':(48,52,65),'bone':(229,232,236),'dark':(9,11,17),'wing':(31,25,43),'glow_eye':(231,220,255),'glow_core':(157,100,224),'accent':(111,116,133)}
for name,title in [('hollow_king','The Hollow King'),('castle_knight','Castle Knight'),('castle_champion','Castle Champion')]:
 body={};p.box(body,(-4,13,-2),(4,22,3),'base');p.box(body,(-4,20,-3),(4,22,-2),'bone')
 p.box(body,(-3,14,-3),(3,19,-2),'belly');p.box(body,(-1,16,-4),(1,21,-3),'light')
 p.box(body,(-4,12,-3),(4,14,3),'light');p.box(body,(-3,22,-2),(3,28,3),'base')
 p.box(body,(-3,24,-3),(3,25,-2),'glow_eye');p.box(body,(-1,22,-4),(1,28,-3),'bone')
 p.box(body,(-4,27,-3),(4,28,4),'light')
 if name=='hollow_king':
  p.box(body,(-4,28,-3),(4,29,4),'bone')
  for x in [-4,-1,2]:p.box(body,(x,29,-3),(x+2,32,-1),'bone')
  p.box(body,(-1,28,-4),(1,30,-3),'glow_core')
 else:p.box(body,(-1,27,-1),(1,31,3),'bone')
 parts={'body':body};limbs={}
 for side,label in [(-1,'l'),(1,'r')]:
  arm={};p.box(arm,(-2,-7,-2),(2,1,2),'base');p.box(arm,(-3,-1,-3),(3,2,3),'light');p.box(arm,(-2,-6,-3),(2,-4,-2),'bone')
  if label=='r':
   p.box(arm,(-1,-10,-3),(1,-5,-1),'dark');p.box(arm,(-4,-5,-3),(4,-4,-1),'light')
   p.box(arm,(-1,-4,-3),(1,9,-1),'bone');p.box(arm,(0,-4,-4),(1,8,-3),'light')
  elif name=='castle_knight':
   p.box(arm,(-4,-9,-4),(4,-1,-3),'base');p.box(arm,(-4,-9,-5),(-3,-1,-4),'bone');p.box(arm,(3,-9,-5),(4,-1,-4),'bone');p.box(arm,(-1,-8,-5),(1,-2,-4),'light')
  parts['arm_'+label]=arm;limbs['arm_'+label]=p.limb('arm_'+label,(side*6,21,0),'arm',phase=-side)
  leg={};p.box(leg,(-2,-5,-2),(2,1,2),'base');p.box(leg,(-2,-5,-3),(2,-3,-2),'bone')
  knee={};p.box(knee,(-2,-6,-2),(2,1,2),'base');p.box(knee,(-2,-6,-4),(2,-4,2),'light')
  parts['leg_'+label]=leg;parts['knee_'+label]=knee
  limbs['leg_'+label]=p.limb('leg_'+label,(side*2,12,0),'leg',phase=side)
  limbs['knee_'+label]=p.limb('knee_'+label,(0,-5,0),'knee',phase=side,parent_limb='leg_'+label)
 p.save(name,title,'void',parts,limbs,{},(7,14,-3),unit=.035)
 folder=p.OUT/name;rig=json.loads((folder/'rig.json').read_text());rig.update(animation_style='knight',bob=0,waddle=0)
 (folder/'rig.json').write_text(json.dumps(rig,indent=2)+'\n')
 coarse=folder/'source_32/rig.json';r=json.loads(coarse.read_text());r.update(animation_style='knight',bob=0,waddle=0);coarse.write_text(json.dumps(r,indent=2)+'\n')
(p.OUT/'realm_boss_manifest.json').write_text(json.dumps(p.MANIFEST,indent=2)+'\n')
# Distinct authored metallic blades and white/violet magic, using the same writer.
for name in ['iron_bolt','iron_cleave','king_spell']:
 v={}
 if name=='iron_cleave':
  for x in range(-15,16):
   z=abs(x)//3;p.box(v,(x,-1,z),(x+1,2,z+3),'light' if x%3==0 else 'base')
 elif name=='iron_bolt':
  p.box(v,(-1,-1,-6),(2,2,5),'base');p.box(v,(0,0,-7),(1,1,6),'bone')
 else:
  p.ell(v,(0,0,0),(3,3,4),'glow_core');p.box(v,(-1,-1,-5),(1,1,5),'bone')
 folder=p.OUT/'boss_projectiles'/name;folder.mkdir(exist_ok=True)
 expanded=p.upscale(v);lo,size=p.bounds(expanded);p.write(folder/'model.vox',expanded,p.PAL['void'],lo,size)
 (folder/'rig.json').write_text(json.dumps({'voxel_size':.024 if name=='iron_cleave' else .012,'design_grid':32,'upscale':8},indent=2)+'\n')
manifest=p.OUT/'boss_projectiles/manifest.json'
records=json.loads(manifest.read_text())
for name in ['iron_bolt','iron_cleave','king_spell']:
 folder=p.OUT/'boss_projectiles'/name
 rig=json.loads((folder/'rig.json').read_text())
 records=[r for r in records if r['id']!=name]
 records.append(dict(id=name,folder='creatures/boss_projectiles/'+name,voxel_size=rig['voxel_size']))
manifest.write_text(json.dumps(records,indent=2)+'\n')
# Iron set was absent from the supplied source catalog; author matching editable masters.
source=Path.home()/'Documents/Voidrealm_textures';template=source/'story/story_sun_seal.pxo'
with zipfile.ZipFile(template) as z: entries={n:z.read(n) for n in z.namelist()}
def icon(folder,name,pattern,palette):
 folder.mkdir(parents=True,exist_ok=True);im=Image.new('RGBA',(8,8))
 for y,row in enumerate(pattern):
  for x,c in enumerate(row):
   if c!='.':im.putpixel((x,y),palette[c])
 im.save(folder/(name+'.png'))
 data=json.loads(entries['data.json']);data['size_x']=data['size_y']=8;data['layers']=data['layers'][:1]
 for frame in data['frames']:frame['cels']=frame['cels'][:1]
 with zipfile.ZipFile(folder/(name+'.pxo'),'w',zipfile.ZIP_DEFLATED) as out:
  for key,value in entries.items():
   if key.startswith('image_data/frames/'):continue
   out.writestr(key,json.dumps(data).encode() if key=='data.json' else value)
  out.writestr('image_data/frames/1/layer_1',im.tobytes())
pal={'w':(232,235,242,255),'s':(124,135,158,255),'b':(39,43,57,255),'v':(181,139,237,255)}
icon(source/'story','story_throne_key',['..www...','.wbbw...','.wbvw...','..wws...','....s...','....sw..','....sbw.','....ww..'],pal)
patterns={'bow':['..ws....','.w.bs...','w..b.s..','w..b..v.','w..b.s..','.w.bs...','..ws....','........'],
 'wand':['..www...','..wvw...','...s....','...s....','...s....','...b....','...b....','........'],
 'trident':['.w.w.w..','.w.w.w..','.wswsw..','..www...','...s....','...s....','...b....','...b....'],
 'cloak':['..wwww..','.wsbbsw.','wsbbbbsw','wbbbbbbw','.bbbbbb.','..bbbb..','...ww...','........'],
 'robe':['..w..w..','.wsbbsw.','wsbbbbsw','..sbbS..'.replace('S','s'),'..sbbS..'.replace('S','s'),'.wsbbsw.','.wwwwww.','........'],
 'spell':['.wwwww..','wssbbsw.','wswvvbw.','wsbvvbw.','wsbbwbw.','wssbbsw.','.wwwww..','........'],
 'bonus':['...ww...','...wv...','.wwwwww.','.vwswv..','...wb...','...wb...','...ww...','........']}
for kind,pattern in patterns.items():icon(source/'Divine/Iron','D_'+('bonus_crucifix' if kind=='bonus' else kind)+'_ofiron',pattern,pal)
