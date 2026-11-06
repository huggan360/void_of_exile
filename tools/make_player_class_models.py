#!/usr/bin/env python3
"""Source art for the five playable player rigs. Does not register classes.
Uses the Archer's exact voxel size, shoulder/hip positions and face proportions.
"""
import json, math, struct
import make_hero
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'characters'
UNIT=1.8/16
COMMON={'skin':(232,182,140),'skin_shade':(202,145,108),'eye':(24,20,28),'blush':(220,146,129),'gold':(226,178,71),'gold_dark':(158,111,41),'wood':(112,73,48),'wood_light':(157,107,67),'leather':(79,53,39),'paper':(231,220,187),'cream':(230,225,207),'glass':(107,183,185),'glow':(90,198,217)}
SPECS={
 'wizard':dict(title='Wizard',cloth=(75,83,165),cloth_light=(98,113,198),shade=(49,52,112),accent=(128,79,165),hair=(225,217,196),boot=(67,53,81),glow=(100,198,232)),
 'priest':dict(title='Priest',cloth=(229,224,207),cloth_light=(249,241,216),shade=(185,177,159),accent=(92,145,173),hair=(103,69,48),boot=(90,67,46),skin=(215,164,123),glow=(159,218,228)),
 'alchemist':dict(title='Alchemist',cloth=(61,129,112),cloth_light=(89,162,133),shade=(39,90,83),accent=(191,130,63),hair=(107,63,38),boot=(68,49,37),glow=(139,208,101)),
 'merrow':dict(title='Merrow',cloth=(57,143,157),cloth_light=(86,181,187),shade=(36,87,112),accent=(209,139,131),hair=(42,102,138),boot=(77,151,157),skin=(165,218,204),skin_shade=(117,180,172),glow=(106,216,216)),
}
def box(v,a,b,c):
 for x in range(a[0],b[0]):
  for y in range(a[1],b[1]):
   for z in range(a[2],b[2]):v[x,y,z]=c

def head(v,cover):
 box(v,(-4,9,-3),(4,16,3),cover)
 for x in range(-4,4):
  for z in range(-3,3):
   if x in [-4,3] or z in [-3,2]:v.pop((x,15,z),None)
 box(v,(-2,10,-3),(2,14,-2),'skin')
 v[-2,12,-3]='eye';v[1,12,-3]='eye'


def robe(v):
 box(v,(-3,4,-2),(3,9,2),'cloth')
 box(v,(-3,4,-2),(-2,9,2),'shade');box(v,(2,4,-2),(3,9,2),'shade')
 box(v,(-3,2,2),(3,9,3),'shade')
 box(v,(-3,3,-2),(3,4,2),'cloth')
 box(v,(-3,2,-2),(-1,3,2),'shade');box(v,(1,2,-2),(3,3,2),'shade')
 box(v,(-3,4,-2),(3,5,2),'leather');v[0,4,-3]='gold'


def wizard():
 v={};robe(v);head(v,'accent')
 # A soft, crooked pointed hat above the Archer-sized face.
 box(v,(-5,14,-4),(5,15,4),'shade')
 box(v,(-3,15,-2),(3,17,3),'cloth')
 box(v,(-2,17,-1),(2,18,2),'cloth')
 box(v,(-1,18,-1),(2,19,2),'cloth_light')
 box(v,(0,19,0),(3,20,2),'cloth')
 v[2,18,0]='cloth';v[0,15,-3]='gold'
 # Small beard leaves the same two dot eyes as the Archer.
 box(v,(-2,10,-3),(2,11,-2),'hair');box(v,(-1,9,-3),(1,10,-2),'hair')
 box(v,(-1,5,-3),(1,8,-2),'accent');v[0,8,-3]='gold'
 for p in [(-2,6,-3),(2,3,-2),(-1,12,3)]:v[p]='gold'
 staff={};box(staff,(0,-3,0),(1,10,1),'wood')
 box(staff,(-1,8,0),(2,10,1),'gold_dark')
 for y in range(10,14):
  r=1 if y in [10,13] else 2
  box(staff,(-r,y,0),(r+1,y+1,1),'gold')
 for p in [(0,11,-1),(0,12,-1),(-1,11,0),(1,11,0)]:staff[p]='glow'
 return v,staff,{}


def priest():
 v={};robe(v);head(v,'cloth')
 box(v,(-3,8,-3),(3,10,3),'accent');box(v,(-2,10,-3),(2,14,-2),'skin')
 v[-2,12,-3]='eye';v[1,12,-3]='eye'
 box(v,(-3,14,-2),(3,17,3),'cloth')
 box(v,(-2,17,-1),(2,18,2),'cloth_light')
 box(v,(-1,18,0),(1,19,2),'cloth')
 box(v,(-3,14,-3),(3,15,-2),'gold')
 box(v,(0,15,-3),(1,18,-2),'gold');box(v,(-1,16,-3),(2,17,-2),'gold')
 # Gold stole, with a simple readable symbol over the ivory robe.
 for x in [-2,1]:box(v,(x,5,-3),(x+1,9,-2),'gold')
 v[0,7,-3]='gold';v[0,6,-3]='gold';v[-1,7,-3]='gold';v[1,7,-3]='gold'
 staff={};box(staff,(0,-3,0),(1,10,1),'wood_light')
 box(staff,(0,8,0),(1,14,1),'gold');box(staff,(-2,11,0),(3,12,1),'gold')
 staff[0,10,-1]='glow';staff[0,12,0]='cream'
 book={};box(book,(-1,-1,0),(2,2,2),'accent');box(book,(-1,-1,-1),(2,2,0),'paper');box(book,(-1,-1,-1),(0,2,2),'gold_dark');book[1,0,-2]='gold'
 return v,staff,{'book':dict(voxels=book,parent='arm_l',pivot=[0,-4,-2],label='Prayer Book')}


def alchemist():
 v={};robe(v);head(v,'hair')
 # Tousled hair and brass goggles pushed up over the visible dot eyes.
 box(v,(-3,14,-3),(3,15,-2),'leather')
 for x in [-3,1]:
  box(v,(x,14,-4),(x+2,15,-3),'gold');v[x,14,-5]='glass'
 v[-2,15,-2]='hair';v[1,15,-2]='hair';v[2,14,-3]='hair'
 box(v,(-1,5,-3),(1,8,-2),'paper');box(v,(-3,8,-3),(3,9,-2),'accent')
 box(v,(-3,4,-3),(-1,6,-2),'leather');box(v,(2,4,-3),(4,6,-1),'leather')
 v[-2,5,-4]='gold';v[2,5,-4]='gold'
 # Rear satchel and a pair of unmistakable reagent bottles.
 box(v,(-2,4,3),(3,10,5),'leather');box(v,(-2,9,3),(3,10,5),'accent')
 for x,color in [(-2,'glow'),(1,'glass')]:
  box(v,(x,6,5),(x+2,9,6),color);v[x,9,5]='gold_dark'
 staff={};box(staff,(0,-3,0),(1,9,1),'wood')
 box(staff,(-1,8,0),(2,9,1),'gold_dark')
 box(staff,(-2,9,0),(3,12,2),'glass')
 for p in [(-2,9,0),(2,9,0),(-2,11,0),(2,11,0)]:staff.pop(p,None)
 box(staff,(-1,9,-1),(2,11,0),'glow')
 box(staff,(0,12,0),(1,14,2),'gold_dark');box(staff,(-1,13,0),(2,14,2),'wood_light')
 flask={};box(flask,(-1,-1,0),(2,1,2),'glass');box(flask,(-1,-1,-1),(2,0,0),'accent');box(flask,(0,1,0),(1,3,2),'gold_dark')
 return v,staff,{'flask':dict(voxels=flask,parent='arm_l',pivot=[0,-4,-2],label='Reagent Flask')}


def merrow():
 v={};robe(v);head(v,'hair')
 # Sea-folk fins, a little crest, and a coral shell in the hair.
 for side in [-1,1]:
  x=-5 if side<0 else 4
  box(v,(x,11,-1),(x+1,14,2),'cloth_light');v[x,13,0]='gold';v[x,10,0]='cloth'
 box(v,(-2,15,0),(1,17,2),'cloth_light');v[0,17,1]='hair'
 box(v,(2,13,-3),(4,15,-2),'accent');v[2,14,-4]='paper'
 for x in [-3,2]:box(v,(x,7,-3),(x+1,9,2),'cloth_light')
 box(v,(-3,3,-2),(3,4,2),'gold_dark')
 box(v,(-1,5,-3),(1,8,-2),'shade');v[0,7,-4]='paper';v[0,5,-4]='gold'
 box(v,(-2,4,3),(2,8,4),'cloth_light')
 staff={};box(staff,(0,-3,0),(1,8,1),'wood_light')
 box(staff,(-2,8,0),(3,9,1),'gold_dark')
 for x in [-2,0,2]:
  box(staff,(x,9,0),(x+1,13 if x==0 else 12,1),'gold')
  staff[x,12 if x==0 else 11,0]='glow'
 staff[0,7,-1]='glass'
 return v,staff,{}


def arm_parts(name):
 upper={};forearm={};hand={}
 box(upper,(-1,-2,-1),(1,0,1),'hood' if name=='archer' else 'cloth')
 box(forearm,(-1,-2,-1),(1,0,1),'tunic_dark' if name=='archer' else 'cloth')
 box(forearm,(-1,-2,-1),(1,-1,1),'tunic_dark' if name=='archer' else ('gold' if name in ['priest','merrow'] else 'accent'))
 # The central column is empty: the shaft and skin never share a voxel.
 box(hand,(-1,-1,-1),(2,0,2),'skin');hand.pop((0,-1,0))
 return {'upper_arm':upper,'forearm':forearm,'hand':hand}

def leg(name):
 v={};box(v,(-1,-2,-1),(2,0,2),'shade');box(v,(-1,-4,-1),(2,-2,2),'boot');box(v,(-1,-4,-2),(2,-3,-1),'boot')
 if name=='merrow':box(v,(-1,-4,-2),(2,-3,0),'skin_shade');v[0,-3,-2]='gold_dark'
 return v

def bounds(v):
 lo=tuple(min(p[i] for p in v) for i in range(3));size=tuple(max(p[i] for p in v)-lo[i]+1 for i in range(3))
 return lo,size

def write_vox(path,v,palette,lo,size):
 names=list(palette);indices={c:i+1 for i,c in enumerate(names)}
 xyzi=bytearray(struct.pack('<I',len(v)))
 for (x,y,z),c in v.items():xyzi.extend((z-lo[2],x-lo[0],y-lo[1],indices[c]))
 rgba=b''.join(bytes((*palette[names[i]],255)) if i<len(names) else bytes((0,0,0,255)) for i in range(256))
 def chunk(k,data):return k+struct.pack('<II',len(data),0)+data
 children=chunk(b'SIZE',struct.pack('<III',size[2],size[0],size[1]))+chunk(b'XYZI',xyzi)+chunk(b'RGBA',rgba)
 path.write_bytes(b'VOX '+struct.pack('<I',150)+b'MAIN'+struct.pack('<II',0,len(children))+children)


def save(name,builder=None):
 archer=name=='archer'
 if archer:
  title='Archer';palette=make_hero.PALETTE
  body=make_hero.body();accessories={}
  parts={'body':body,'leg':make_hero.leg(),'bow_frame':{p:c for p,c in make_hero.bow().items() if c!='string'}}
 else:
  spec=SPECS[name];title=spec['title'];palette=dict(COMMON);palette.update({k:v for k,v in spec.items() if k!='title'})
  body,staff,accessories=builder()
  parts={'body':body,'leg':leg(name),'staff':staff}
 parts.update(arm_parts(name))
 for label,info in accessories.items():parts[label]=info['voxels']
 folder=OUT/name;folder.mkdir(parents=True,exist_ok=True)
 limbs={}
 for side,x in [('l',-4),('r',4)]:
  limbs['arm_'+side]={'part':'upper_arm','pivot':[x,9,-1 if archer else 0],'mesh_scale':[1,1.25,1]}
  limbs['forearm_'+side]={'part':'forearm','parent':'arm_'+side,'pivot':[0,-2.5,0],'mesh_scale':[.9,1.25,.8]}
  limbs['hand_'+side]={'part':'hand','name':'LeftHand' if side=='l' else 'RightHand','parent':'forearm_'+side,'pivot':[0,-3,0],
   'mesh_scale':[1,1,.55 if archer and side=='l' else 1],
   'mesh_offset':[-.5,.5,-.575 if archer and side=='l' else -1.5]}
 limbs.update({'leg_l':{'part':'leg','pivot':[-2,4,0]},'leg_r':{'part':'leg','pivot':[1,4,0]}})
 weapon='bow_frame' if archer else 'staff'
 attachments={weapon:{'part':weapon,'name':'Bow' if archer else 'Staff','parent':'hand_r','pivot':[0,0,-1],
  'mesh_scale':[.9,1,.8 if archer else .9],'mesh_offset':[-.45,-.5 if archer else 0,-.4 if archer else -.45]}}
 for label,info in accessories.items():
  attachments[label]={'part':label,'parent':'hand_l','pivot':[-.5,0,-4.5],'label':info['label']}
 rig={'status':'playable','voxel_size':UNIT,'facing':'-Z','right_hand':'+X','body_height_voxels':16,
  'upper_arm_length':2.5,'forearm_length':3.0,'grip':[0,0,-1],'reference':'characters/archer',
  'parts':{},'limbs':limbs,'attachments':attachments}
 for label,v in parts.items():
  lo,size=((-8,0,-8),(16,16 if archer else 21,16)) if label=='body' else bounds(v)
  rig['parts'][label]={'frame_min':list(lo),'frame_size':list(size)}
  # Preserve the Archer's existing body/legs, including their palette variation.
  if archer and label in ['body','leg']:continue
  for suffix,voxels in [('',{p:c for p,c in v.items() if c!='glow'}),('_glow',{p:c for p,c in v.items() if c=='glow'})]:
   if voxels:write_vox(folder/(label+suffix+'.vox'),voxels,palette,lo,size)
   if suffix and voxels:rig['parts'][label]['glow']=True
 # A coarse assembled source for voxel editors; the scene retains fractional rig pivots.
 full=dict(body);origins={}
 for key,info in list(limbs.items())+list(attachments.items()):
  base=origins.get(info.get('parent'),[0,0,0]);origin=[base[i]+info['pivot'][i] for i in range(3)];origins[key]=origin
  scale=info.get('mesh_scale',[1,1,1]);offset=info.get('mesh_offset',[0,0,0])
  for p,c in parts[info['part']].items():
   full[tuple(math.floor(origin[i]+offset[i]+(p[i]+.5)*scale[i]) for i in range(3))]=c
 lo,size=bounds(full);write_vox(folder/'model.vox',full,palette,lo,size)
 (folder/'rig.json').write_text(json.dumps(rig,indent=2)+'\n')
 (folder/'palette.json').write_text(json.dumps(palette,indent=2)+'\n')
 (folder/'README.md').write_text(f'# {title}\n\nPlayable {UNIT} m voxel rig, facing -Z with +X right. Open `model.tscn` for the articulated model; `model.vox` is a coarse, unposed voxel-editor reference. `ArmL`/`ArmR` contain separate `ForearmL`/`ForearmR` elbow pivots and wrist sockets (`LeftHand`/`RightHand`). The weapon lives below `Rig/ArmR/ForearmR/RightHand`; the fist has a shaft hole. See `../README.md` for axes, animation and regeneration. `rig.json` records frames, hierarchy, mesh offsets and scales.\n')
 return {'id':name,'name':title,'folder':'characters/'+name,'status':'playable','scene':'characters/'+name+'/model.tscn','voxel_size':UNIT,'held_in':'right_hand','rig_version':2}

if __name__=='__main__':
 models=[save('archer')]+[save(n,fn) for n,fn in [('wizard',wizard),('priest',priest),('alchemist',alchemist),('merrow',merrow)]]
 (OUT/'class_model_manifest.json').write_text(json.dumps(models,indent=2)+'\n')
 print('Created articulated player rigs: Archer, Wizard, Priest, Alchemist, Merrow')
