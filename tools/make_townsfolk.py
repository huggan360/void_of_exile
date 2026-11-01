#!/usr/bin/env python3
"""Small friendly villagers, native editable VOX rigs and portrait renders."""
from make_common_batch_01 import export
from make_creatures import box
from preview_voxel_batch import ROOT,assemble,render
from PIL import Image,ImageDraw,ImageFont
from preview_voxel_batch import BOLD
ROLES={'smith':((83,66,60),(57,55,58),(68,48,35)), 'magician':((82,75,150),(203,177,112),(70,46,77)), 'baker':((190,126,89),(239,227,195),(101,67,39)), 'gardener':((83,130,106),(198,175,118),(90,59,34)), 'villager':((166,96,118),(221,196,159),(76,49,34)), 'traveler':((93,138,166),(173,183,179),(128,89,54))}
sheet=Image.new('RGB',(6*240,320),'#202832');d=ImageDraw.Draw(sheet)
for j,(role,(cloth,apron,hair)) in enumerate(ROLES.items()):
 pal={'skin':(228,173,133),'shade':(188,128,99),'hair':hair,'cloth':cloth,'apron':apron,'boot':(65,51,44),'eye':(35,35,44),'white':(252,241,217),'cheek':(219,129,117),'glow':(143,220,226),'metal':(142,151,159)}
 v={};box(v,-2,2,3,7,-1,2,'cloth');box(v,-2,2,3,6,-2,-1,'apron');box(v,-1,1,6,7,-2,-1,'apron')
 box(v,-3,3,7,12,-2,3,'skin');box(v,-3,3,11,13,-2,3,'hair');box(v,-3,-2,9,12,-2,3,'hair');box(v,2,3,9,12,-2,3,'hair')
 for x in [-2,1]:box(v,x,x+1,9,10,-3,-2,'eye')
 box(v,-1,1,8,9,-3,-2,'shade');v[(-2,8,-2)]='cheek';v[(2,8,-2)]='cheek'
 if role=='smith':box(v,-3,3,10,12,3,4,'hair');box(v,-3,3,10,11,-3,-2,'boot')
 if role=='baker':box(v,-3,3,12,14,-2,3,'white');box(v,-2,2,14,15,-1,2,'white')
 if role=='magician':
  box(v,-4,4,12,13,-3,4,'cloth');box(v,-2,2,13,15,-1,2,'cloth');box(v,-1,1,15,17,0,1,'cloth');v[(0,14,-2)]='glow'
 if role=='gardener':box(v,-4,4,12,13,-3,4,'apron');box(v,-2,2,13,14,-1,2,'apron')
 if role=='traveler':box(v,-3,3,6,7,-2,3,'apron');box(v,-2,2,3,7,2,4,'boot')
 a={};box(a,-1,1,-3,0,-1,1,'cloth');box(a,-1,1,-4,-3,-1,1,'skin')
 ar=dict(a)
 if role=='smith':box(ar,0,1,-5,-2,-2,-1,'hair');box(ar,-1,2,-3,-2,-3,-1,'metal')
 if role=='magician':box(ar,0,1,-5,1,-2,-1,'hair');box(ar,-1,2,0,2,-3,-1,'glow')
 if role=='baker':box(ar,-1,2,-4,-2,-3,-1,'apron')
 leg={};box(leg,-1,1,-2,0,-1,1,'cloth');box(leg,-1,1,-3,-2,-2,1,'boot')
 limbs={'arm_l':dict(part='arm_l',pivot=[-3,7,0],role='arm',phase=1,throws=False),'arm_r':dict(part='arm_r',pivot=[3,7,0],role='arm',phase=-1,throws=False),'leg_l':dict(part='leg',pivot=[-1.2,3,0],role='leg',phase=1),'leg_r':dict(part='leg',pivot=[1.2,3,0],role='leg',phase=-1)}
 folder=ROOT/'creatures'/('npc_'+role)
 export(folder,{'body':v,'arm_l':a,'arm_r':ar,'leg':leg},pal,dict(voxel_size=.095,parts={},limbs=limbs,hand=[3,3,-1],waddle=.6))
 vox,_=assemble(folder);render(vox,128,128,yaw=5).save(folder/'portrait.png');sheet.paste(render(vox,240,270,yaw=25),(j*240,0));d.text((j*240+12,288),role.title(),font=ImageFont.truetype(BOLD,21),fill='white')
sheet.save(ROOT/'creatures/townsfolk_preview.png');print('Six native townsfolk rigs and portraits saved.')
