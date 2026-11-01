#!/usr/bin/env python3
"""Cave cast and editable coarse 32-grid Goblin King, enlarged eightfold."""
import json
from pathlib import Path
import redesign_pixel_bosses as art
R=Path(__file__).resolve().parents[1]
P={'base':(79,121,47),'light':(126,161,66),'shade':(43,68,34),'belly':(110,136,62),'bone':(229,209,144),'dark':(27,31,27),'wing':(92,48,37),'glow_eye':(239,174,66),'glow_core':(235,199,63),'accent':(163,109,39)}
art.PAL['gold']=P
b={}
art.ell(b,(0,12,0),(8,8,5),'base');art.ell(b,(0,12,-3),(6,6,3),'belly')
art.box(b,(-7,5,-4),(7,8,4),'wing');art.box(b,(-7,7,-5),(7,8,4),'accent')
art.box(b,(-1,7,-6),(2,9,-5),'glow_core')
art.ell(b,(0,22,0),(5,5,4),'base');art.box(b,(-4,20,-5),(4,23,-3),'light')
for side in [-1,1]:
 art.polygon(b,[(side*4,25),(side*11,26),(side*6,20)],-1,1,'base')
 art.box(b,(side*2-1,23,-4),(side*2+1,24,-3),'dark')
 art.box(b,(side*2-1,23,-5),(side*2,24,-4),'glow_eye')
 art.box(b,(side*3,19,-5),(side*3+1,21,-4),'bone')
art.box(b,(-5,26,-3),(5,28,3),'accent')
for x in [-4,0,4]:
 art.box(b,(x-1,28,-3),(x+1,31,-1),'glow_core')
art.box(b,(-1,27,-4),(1,29,-3),'glow_eye')
arm={};art.box(arm,(-2,-7,-2),(2,0,2),'base');art.box(arm,(-2,-7,-3),(2,-5,1),'light')
club=dict(arm);art.box(club,(-1,-9,-4),(1,1,-2),'accent');art.ell(club,(0,0,-3),(3,4,3),'dark')
for x,y in [(-3,0),(3,0),(0,4)]:art.box(club,(x-1,y,-4),(x+1,y+2,-2),'bone')
leg={};art.box(leg,(-2,-4,-2),(2,0,2),'base');art.box(leg,(-2,-5,-4),(2,-3,2),'wing')
limbs={'arm_l':art.limb('arm',(-7,19,0),'arm',-1),'arm_r':art.limb('club',(7,19,0),'arm',1),'leg_l':art.limb('leg',(-4,5,0),'leg',-1),'leg_r':art.limb('leg',(4,5,0),'leg',1)}
art.save('goblin_king','Goblin King','gold',{'body':b,'arm':arm,'club':club,'leg':leg},limbs,{},(7,13,-3),unit=.0185)
p=R/'creatures/goblin_king/rig.json';rig=json.loads(p.read_text());rig['animation_style']='goblin_king';p.write_text(json.dumps(rig,indent=2)+'\n')
p=R/'creatures/goblin_king/source_32/rig.json';rig=json.loads(p.read_text());rig['animation_style']='goblin_king';p.write_text(json.dumps(rig,indent=2)+'\n')
# Smaller cast uses the same flat, readable palette and the ordinary rig format.
def save(name,body,parts=None,limbs=None,unit=.12):
 folder=R/'creatures'/name;folder.mkdir(exist_ok=True)
 parts={'body':body,**(parts or {})};rig={'voxel_size':unit,'parts':{},'limbs':limbs or {},'hand':[3,6,-2],'bob':.04,'waddle':.06}
 for name2,vox in parts.items():
  lo,size=art.bounds(vox);art.write(folder/(name2+'.vox'),vox,P,lo,size);rig['parts'][name2]={'frame_min':list(lo),'frame_size':list(size)}
 (folder/'rig.json').write_text(json.dumps(rig,indent=2)+'\n')
def goblin(name,robe=False,large=False):
 body={};art.box(body,(-3,3,-2),(3,10,2),'wing' if robe else 'base');art.box(body,(-4,9,-3),(4,14,3),'base')
 art.box(body,(-3,10,-4),(3,12,-3),'light')
 for s in [-1,1]:
  art.box(body,(s*4-1,11,-1),(s*6+1 if s>0 else s*4+1,13,1),'base') if s>0 else art.box(body,(-6,11,-1),(-3,13,1),'base')
  art.box(body,(s*2-1,12,-4),(s*2,13,-3),'glow_eye')
 if robe:art.box(body,(-4,14,-3),(4,15,3),'accent');art.box(body,(-2,15,-2),(2,18,2),'wing')
 if large:art.box(body,(-5,7,-3),(5,10,3),'dark');art.box(body,(-3,14,-3),(3,15,3),'accent')
 a={};art.box(a,(-1,-5,-1),(1,0,1),'base')
 right=dict(a);art.box(right,(-1,-6,-3),(1,3,-2),'accent')
 if robe:art.box(right,(-2,3,-4),(2,5,0),'glow_eye')
 else:art.box(right,(-2,0,-4),(2,4,0),'dark')
 l={};art.box(l,(-1,-3,-1),(1,0,1),'wing')
 ls={'arm_l':{'part':'arm','pivot':[-4,9,0]},'arm_r':{'part':'weapon','pivot':[4,9,0]},'leg_l':{'part':'leg','pivot':[-2,3,0]},'leg_r':{'part':'leg','pivot':[2,3,0]}}
 save(name,body,{'arm':a,'weapon':right,'leg':l},ls,.15 if large else .12)
goblin('cave_slinger');goblin('goblin_brute',large=True);goblin('cave_shaman',robe=True);goblin('goblin_warlord',robe=True,large=True)
bat={};art.ell(bat,(0,5,0),(3,3,2),'base');art.box(bat,(-2,5,-3),(2,6,-2),'glow_eye')
wing={};art.polygon(wing,[(0,0),(8,4),(10,-2),(4,-1),(2,-3)],0,1,'shade');art.line(wing,(0,0,0),(8,4,0),'base')
left={(-x,y,z):c for (x,y,z),c in wing.items()}
save('moss_bat',bat,{'wing_r':wing,'wing_l':left},{'wing_l':{'part':'wing_l','pivot':[-2,6,0],'role':'wing','phase':-1},'wing_r':{'part':'wing_r','pivot':[2,6,0],'role':'wing','phase':1}})
body={};art.box(body,(-3,1,-3),(3,6,3),'bone');art.ell(body,(0,7,0),(6,3,5),'wing')
for x,z in [(-3,-2),(2,-3),(0,1)]:art.box(body,(x,8,z),(x+2,10,z+2),'light')
art.box(body,(-2,3,-4),(-1,4,-3),'dark');art.box(body,(1,3,-4),(2,4,-3),'dark')
save('mushroom_crawler',body)
chest={};art.box(chest,(-5,0,-3),(5,6,3),'accent');art.box(chest,(-5,6,-3),(5,8,3),'wing')
for x in [-4,3]:art.box(chest,(x,0,-4),(x+1,8,4),'glow_core')
art.box(chest,(-1,4,-4),(1,6,-3),'dark');save('goblin_treasure',chest)
coin={};art.ell(coin,(0,0,0),(4,4,1),'accent');art.ell(coin,(0,0,-.5),(3,3,1),'glow_core');art.box(coin,(-1,-2,-2),(1,2,-1),'shade')
art.projectile('goblin_coin','gold',coin,.012)
club={};art.box(club,(-1,-1,-5),(1,1,4),'accent');art.ell(club,(0,0,-3),(3,3,3),'dark')
for s in [-1,1]:art.box(club,(s*3-1,-1,-4),(s*3+1,1,-2),'bone')
art.projectile('goblin_club','gold',club,.012)
print('Cave art complete')
