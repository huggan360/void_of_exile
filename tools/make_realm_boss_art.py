#!/usr/bin/env python3
"""Four realm bosses + crystal supports, ART ONLY. No encounter/drop registration.
Coordinates: y up, faces -Z. Dense voxel sculptures within 256-voxel part limits.
Variants share fixed frames, compatible with CreatureModel.set_variant().
"""
import json,math,struct,hashlib
from pathlib import Path
import numpy as np
from voxel_sculpt import Part
from make_creatures import write_vox,fit_frame
from preview_voxel_batch import ROOT
OUT=ROOT/'creatures/staging/realm_bosses_01'
ICE={'ice':(117,185,210),'ice_light':(204,241,247),'ice_dark':(51,88,125),'edge':(239,252,255),'metal':(59,87,113),'metal_light':(141,180,200),'glow_core':(101,232,249),'glow_hot':(213,255,255),'glow_rune':(84,172,236)}
FIRE={'skin':(121,28,35),'skin_light':(165,43,40),'skin_dark':(71,21,31),'armor':(30,27,36),'armor_light':(57,47,55),'metal':(103,59,51),'horn':(183,137,104),'horn_light':(233,184,124),'wing':(87,21,33),'wing_light':(124,27,37),'glow_core':(255,70,32),'glow_hot':(255,177,68),'eye':(255,215,117),'dark':(15,12,23)}
GOLD={'gold':(205,156,47),'gold_light':(245,210,110),'gold_dark':(132,85,31),'ivory':(235,221,181),'ivory_dark':(174,155,118),'carapace':(47,68,77),'carapace_light':(70,97,107),'dark':(25,34,46),'glow_sun':(255,221,116),'glow_heart':(255,141,196),'glow_eye':(206,249,247)}
VOID={'cloth':(34,22,49),'cloth_light':(58,32,72),'cloth_dark':(14,13,27),'armor':(52,29,67),'edge':(104,53,114),'silver':(153,143,180),'gold':(177,141,83),'glow_core':(229,61,208),'glow_rune':(118,77,217),'glow_eye':(105,238,243),'dark':(7,7,17)}
MODELS=[]
def part(pal):return Part(1,pal)
def ring(p,c,r,thick,color,axis='y',n=72):
 pts=[]
 for i in range(n+1):
  a=i*math.tau/n;x,z=math.cos(a)*r,math.sin(a)*r
  q=(c[0]+x,c[1],c[2]+z) if axis=='y' else (c[0]+x,c[1]+z,c[2])
  pts.append(q)
 for a,b in zip(pts,pts[1:]):p.capsule(a,b,thick,thick,color)
def crystal(p,c,r,h,color,tip=None,sides=6,angle=0):
 # Flat prism facets with two tapered pointed ends, actual convex geometry.
 c=np.array(c,float);normals=np.array([(math.cos(angle+i*math.tau/sides),math.sin(angle+i*math.tau/sides)) for i in range(sides)])
 def sdf(q):
  q=q-c;t=np.abs(q[...,1])/(h*.5)
  radius=r*np.minimum(1.0,np.maximum(0,(1-t)/.36))
  d=np.max(q[...,[0,2]]@normals.T,axis=-1)-radius
  return np.maximum(d,np.abs(q[...,1])-h*.5)
 p._add(c-[(r*1.2),h*.5,r*1.2],c+[r*1.2,h*.5,r*1.2],sdf,color)
def enrich_ice(v):
 out={}
 for (x,y,z),color in v.items():
  if color=='ice':
   a=(math.atan2(z,x)+math.tau)%math.tau
   color=['ice','ice_light','ice','ice_dark','ice_dark','ice_light'][int(a*3/math.pi)%6]
   if (x*5+y*3+z*7)%131<3:color='edge'
  out[x,y,z]=color
 return out

def limb(part,pivot,role='sway',phase=1,yaw=0,**kw):return dict(part=part,pivot=pivot,role=role,phase=phase,yaw=yaw,**kw)
def merge_pose(parts,limbs,variant=None):
 swaps=variant or {};v=dict(parts[swaps.get('body','body')])
 for s in limbs.values():
  a=math.radians(s.get('yaw',0));ca,sa=math.cos(a),math.sin(a);pivot=s['pivot']
  for (x,y,z),co in parts[swaps.get(s['part'],s['part'])].items():
   v[round(ca*x+sa*z+pivot[0]),round(y+pivot[1]),round(-sa*x+ca*z+pivot[2])]=co
 return v

def save(name,title,biome,pal,parts,limbs=None,variants=None,unit=.04,**extras):
 limbs=limbs or {};variants=variants or {};folder=OUT/name;folder.mkdir(parents=True,exist_ok=True)
 rig=dict(voxel_size=unit,parts={},limbs=limbs,hand=extras.pop('hand',[0,110,-45]),waddle=0,hover=extras.pop('hover',.25),bob=.07,variants=variants,**extras)
 # A holder's frame is stable across all of its looks, required by CreatureModel.
 frames={}
 bases={'body'}|{s['part'] for s in limbs.values()}
 for base in bases:
  names={base}|{s.get(base,base) for s in variants.values()};coords={k:co for n in names for k,co in parts[n].items()}
  lo,size=fit_frame(coords);lo=tuple(a-1 for a in lo);size=tuple(a+2 for a in size)
  assert max(size)<=256,(name,base,size)
  for n in names:frames[n]=(lo,size)
 for n,v in parts.items():
  lo,size=frames[n];info={'frame_min':list(lo),'frame_size':list(size)}
  solid={k:co for k,co in v.items() if not co.startswith('glow')};glow={k:co for k,co in v.items() if co.startswith('glow')}
  if solid:write_vox(str(folder/(n+'.vox')),solid,pal,lo,size)
  else:info['solid']=False
  if glow:write_vox(str(folder/(n+'_glow.vox')),glow,pal,lo,size);info['glow']=True
  rig['parts'][n]=info
 (folder/'rig.json').write_text(json.dumps(rig,indent=2)+'\n')
 previews={}
 for form,swaps in {'sealed' if name=='rimeheart_prism' else 'default':{},**variants}.items():
  full=merge_pose(parts,limbs,swaps);lo,size=fit_frame(full)
  assert max(size)<=256,(name,form,size)
  filename='model.vox' if not swaps else 'model_'+form+'.vox'
  write_vox(str(folder/filename),full,pal,lo,size)
  previews[form]={'file':filename,'frame_min':list(lo),'size':list(size),'voxels':len(full)}
 (folder/'poses.json').write_text(json.dumps(previews,indent=2)+'\n')
 record=dict(id=name,display_name=title,biome=biome,folder=str(folder.relative_to(ROOT)),status='art_staging_only',voxel_size=unit,parts=list(parts),variants=list(variants),poses=previews)
 MODELS.append(record);print(name,':',sum(len(v) for v in parts.values()),'part voxels',flush=True)

def frost():
 parts={}
 for stage in ['sealed','conduit','tempest']:
  p=part(ICE)
  if stage=='sealed':
   crystal(p,(0,113,0),30,152,'ice')
   crystal(p,(0,125,-18),12,56,'glow_core')
   for s in [-1,1]:p.capsule((s*13,78,-26),(s*5,119,-31),1.3,1.3,'glow_rune')
  else:
   p.ellipsoid((0,111,0),(19,24,19),'glow_core')
   crystal(p,(0,112,0),12,47,'glow_hot')
   for y in [75,148]:
    ring(p,(0,y,0),28 if stage=='conduit' else 34,2,'metal_light',n=6)
   crystal(p,(0,180,0),9,31,'ice_light')
   crystal(p,(0,41,0),13,24,'ice')
  for i in range(6):
   a=i*math.tau/6
   x,z=math.cos(a)*31,math.sin(a)*31
   crystal(p,(x,20+(i%2)*6,z),7,23,'metal_light')
   crystal(p,(x,24+(i%2)*6,z),4,15,'glow_rune')
  parts['body' if stage=='sealed' else 'body_'+stage]=enrich_ice(p.voxels())
  q=part(ICE)
  if stage=='sealed':
   crystal(q,(0,2,5),13,103,'ice')
   crystal(q,(-8,-18,9),8,44,'ice_light')
   crystal(q,(0,38,4),4,18,'glow_rune')
  elif stage=='conduit':
   crystal(q,(0,11,28),17,118,'ice')
   crystal(q,(0,12,25),8,75,'ice_light')
   crystal(q,(0,62,28),4,18,'glow_core')
   ring(q,(0,-29,28),19,1.5,'metal',n=6)
  else:
   # Long radial blades: unmistakable six-point ice-star silhouette.
   q.triangle((-18,-3,14),(18,-3,14),(0,3,77),5,'ice')
   q.triangle((-11,1,19),(11,1,19),(0,6,69),2,'ice_light')
   q.capsule((0,4,16),(0,6,70),1.4,.4,'glow_core')
   crystal(q,(0,17,27),9,48,'ice')
  parts['petal' if stage=='sealed' else 'petal_'+stage]=enrich_ice(q.voxels())
 limbs={}
 for i in range(6):
  a=i*math.tau/6
  # A local +Z petal points radially outward after its yaw.
  limbs['shard_'+str(i)]=limb('petal',[round(math.sin(a)*34),100+(i%2)*8,round(math.cos(a)*34)],role='',yaw=i*60)
 save('rimeheart_prism','Rimeheart Prism','Fosen',ICE,parts,limbs,{'conduit':{'body':'body_conduit','petal':'petal_conduit'},'tempest':{'body':'body_tempest','petal':'petal_tempest'}},hand=[0,111,-30],hover=.6)
 # One of six identical hexagonal conduits; ports are separate emissive colors.
 p=part(ICE)
 crystal(p,(0,6,0),19,12,'metal')
 for y,r,h in [(24,10,36),(60,7,58),(100,13,27)]:crystal(p,(0,y,0),r,h,'ice')
 ring(p,(0,20,0),12,2,'metal_light',n=6);ring(p,(0,84,0),14,2,'metal_light',n=6)
 crystal(p,(0,100,0),7,22,'glow_core')
 for i in range(6):
  a=i*math.tau/6
  p.ellipsoid((math.cos(a)*12,85,math.sin(a)*12),(3,3,3),'glow_hot')
 save('rimeheart_conduit','Rimeheart Healing Conduit','Fosen support',ICE,{'body':enrich_ice(p.voxels())},unit=.032,hover=0,hand=[0,85,0])
 # Hostile shardling: a little floating ice crustacean with four sharp limbs.
 p=part(ICE);crystal(p,(0,29,0),13,39,'ice');crystal(p,(0,33,-9),7,19,'ice_dark')
 for s in [-1,1]:
  p.ellipsoid((s*5,34,-14),(2,2,1.2),'glow_hot')
  for z in [-3,6]:p.chain([(s*10,24,z),(s*21,20,z+2),(s*24,6,z-5)],3,.5,'ice_light')
 crystal(p,(0,45,3),5,25,'glow_core')
 save('rimeheart_shardling','Rimeheart Shardling','Fosen support',ICE,{'body':enrich_ice(p.voxels())},unit=.03,hover=.2,hand=[0,33,-16])

def demon():
 p=part(FIRE)
 p.ellipsoid((0,111,0),(33,44,21),'skin')
 p.ellipsoid((0,132,-4),(43,25,24),'skin_light')
 for s in [-1,1]:
  p.ellipsoid((s*18,135,-20),(18,16,8),'skin')
  p.ellipsoid((s*16,88,0),(19,18,18),'armor')
  # Sweeping shoulder pauldrons and jagged volcanic blades.
  p.ellipsoid((s*43,146,0),(22,15,24),'armor')
  for dx,dy,dz in [(0,24,-5),(14,10,0),(-6,9,17)]:
   p.capsule((s*43,151,dz),(s*(43+dx),151+dy,dz+6),7,.5,'metal')
 p.ellipsoid((0,168,-3),(18,24,16),'skin_dark')
 p.ellipsoid((0,166,-17),(15,12,13),'skin')
 p.box((-12,157,-28),(12,162,-24),'dark')
 for x in range(-10,12,4):p.capsule((x,162,-28),(x,158,-29),1.2,.2,'horn_light')
 for s in [-1,1]:
  p.ellipsoid((s*8,176,-19),(6,3,3),'glow_hot')
  p.capsule((s*3,182,-19),(s*16,181,-13),3.5,4,'armor')
  p.chain([(s*11,186,1),(s*25,201,8),(s*28,223,5),(s*18,235,-2)],7,1,'horn')
  p.capsule((s*22,222,5),(s*18,235,-2),2.5,.3,'horn_light')
 # Rib plates expose the red abdomen and molten center, never a full glowing body.
 for y in [101,112,123]:
  for s in [-1,1]:p.capsule((s*6,y,-20),(s*26,y+3,-16),3,4,'armor')
 p.ellipsoid((0,127,-25),(10,14,4),'armor')
 p.triangle((0,139,-30),(-6,122,-30),(6,122,-30),2,'glow_core')
 p.capsule((0,123,-30),(0,114,-25),2.3,.8,'glow_hot')
 body=p.voxels();parts={'body':body};limbs={}
 for s,label in [(-1,'l'),(1,'r')]:
  a=part(FIRE);a.chain([(0,0,0),(s*11,-23,-2),(s*12,-47,-12)],12,8,'skin')
  a.ellipsoid((s*10,-34,-5),(12,16,12),'armor')
  a.ellipsoid((s*12,-48,-13),(11,12,9),'skin_light')
  for j in range(4):a.chain([(s*(5+j*4),-51,-16),(s*(5+j*4),-63,-20),(s*(3+j*4),-65,-25)],2.4,.4,'horn')
  a.capsule((s*10,-27,-15),(s*13,-43,-22),1.5,.8,'glow_core')
  parts['arm_'+label]=a.voxels();limbs['arm_'+label]=limb('arm_'+label,[s*44,140,0],'arm',phase=-s,throws=False)
  l=part(FIRE);l.chain([(0,0,0),(s*5,-30,5),(s*8,-58,-3)],12,7,'skin_dark')
  l.ellipsoid((s*8,-62,-7),(11,7,15),'armor');l.box((s*8-1,-68,-24),(s*8+1,-58,-9),'dark')
  l.ellipsoid((s*6,-32,0),(11,14,10),'armor_light')
  parts['leg_'+label]=l.voxels();limbs['leg_'+label]=limb('leg_'+label,[s*20,69,0],'leg',phase=-s)
  w=part(FIRE)
  shoulder=(0,0,0);elbow=(s*30,28,8);wrist=(s*53,40,6)
  tips=[(s*84,31,8),(s*81,-9,14),(s*64,-36,20),(s*35,-47,18)]
  for i in range(3):w.triangle(wrist,tips[i],tips[i+1],2.8,'wing' if i%2 else 'wing_light')
  w.triangle(wrist,tips[-1],shoulder,3,'wing')
  w.chain([shoulder,elbow,wrist],4.5,3,'armor')
  for tip in tips:
   w.capsule(wrist,tip,2.5,1,'armor_light')
   w.capsule((tip[0]*.95,tip[1],tip[2]),tip,1,1,'glow_core')
  parts['wing_'+label]=w.voxels();limbs['wing_'+label]=limb('wing_'+label,[s*34,145,15],'wing',phase=-s)
 t=part(FIRE);t.chain([(0,0,0),(9,-15,24),(25,-31,49),(31,-18,66)],7,2,'skin_dark')
 t.triangle((25,-23,60),(35,-1,72),(41,-25,78),4,'glow_core')
 parts['tail']=t.voxels();limbs['tail']=limb('tail',[0,83,18])
 # Exposed furnace-heart variant with additional bright cracks.
 hot=dict(body)
 for (x,y,z),c in list(hot.items()):
  if c in ['skin','skin_light'] and z<-13 and ((x+int(y*.4))%21 in [0,1]):hot[x,y,z]='glow_core'
 parts['body_infernal']=hot
 save('vharok_cinder_tyrant','Vharok, the Cinder Tyrant','Lava',FIRE,parts,limbs,{'infernal':{'body':'body_infernal'}},hover=0,flap_rate=1.4,hand=[0,128,-30])

def scarab():
 p=part(GOLD)
 p.ellipsoid((0,78,14),(42,28,56),'carapace')
 p.ellipsoid((0,92,12),(39,22,51),'gold_dark')
 for s in [-1,1]:
  p.ellipsoid((s*19,99,16),(19,18,45),'gold')
  for z in [-12,6,24,42]:p.capsule((s*5,111,z),(s*32,102,z+8),2.3,2.3,'gold_light')
 # Ivory neck and ornate pharaonic face, winged sun behind the head.
 p.ellipsoid((0,106,-34),(23,34,20),'ivory')
 p.ellipsoid((0,138,-42),(20,27,15),'gold')
 for s in [-1,1]:
  p.ellipsoid((s*25,129,-29),(13,33,17),'carapace')
  for y in range(107,159,7):p.capsule((s*17,y,-42),(s*33,y-4,-34),2,2,'gold_light')
  p.box((s*9-5,141,-57),(s*9+5,145,-54),'dark')
  p.box((s*9-4,142,-58),(s*9+4,144,-56),'glow_eye')
  p.chain([(s*15,102,-42),(s*29,91,-61),(s*18,86,-77)],5,1,'ivory')
 p.capsule((0,143,-56),(0,129,-59),3,2,'gold_light')
 p.box((-7,123,-56),(7,125,-54),'gold_dark')
 p.chain([(0,122,-53),(0,111,-58),(0,108,-54)],4,2,'carapace')
 ring(p,(0,145,-12),36,4,'gold_light',axis='z')
 for i in range(12):
  a=i*math.tau/12
  p.capsule((math.cos(a)*37,145+math.sin(a)*37,-12),(math.cos(a)*45,145+math.sin(a)*45,-12),3,.5,'gold')
 p.ellipsoid((0,161,-15),(10,10,5),'glow_sun')
 p.ellipsoid((0,98,-13),(9,12,5),'glow_heart')
 parts={'body':p.voxels()};limbs={}
 for s,label in [(-1,'l'),(1,'r')]:
  l=part(GOLD);l.chain([(0,0,0),(s*20,-9,7),(s*29,-39,-3)],5,2,'carapace_light')
  l.capsule((s*29,-39,-3),(s*31,-43,-11),3,.5,'gold_light')
  parts['leg_'+label]=l.voxels()
  for i,z in enumerate([-22,8,37]):limbs[f'leg_{label}_{i}']=limb('leg_'+label,[s*37,53,z],'leg',phase=s*(-1 if i%2 else 1),axis='y',amount=.4)
  w=part(GOLD)
  # Layered gilded wing blades; visible plate seams and pink inlays.
  for i in range(5):
   a=(0,0,i*8-7);b=(s*(45+i*3),7-i*4,18+i*9);c=(s*(37+i*3),-3-i*4,30+i*9)
   w.triangle(a,b,c,3.5,'gold' if i%2 else 'ivory')
   w.capsule(a,b,1.3,.6,'gold_light')
  w.ellipsoid((s*24,0,15),(5,4,8),'glow_heart')
  parts['wing_'+label]=w.voxels();limbs['wing_'+label]=limb('wing_'+label,[s*35,102,2],'wing',phase=-s)
 save('aureate_scarab_regent','Aureate Scarab Regent','Desert',GOLD,parts,limbs,hover=.15,flap_rate=1.0,hand=[0,139,-59],unit=.044)

def wraith():
 p=part(VOID)
 # Flowing, split cloak around a hollow hood; no humanoid face fills the void.
 for s in [-1,1]:
  p.chain([(s*21,127,0),(s*32,91,10),(s*43,46,17),(s*31,9,25)],18,3,'cloth')
  p.chain([(s*20,121,-12),(s*31,78,-6),(s*45,32,10)],3,1,'edge')
  for i in range(3):p.chain([(s*(14+i*12),65,12),(s*(20+i*10),29,21),(s*(9+i*13),7+i*3,30)],5,.3,'cloth_light')
 p.ellipsoid((0,142,0),(29,34,24),'cloth_dark')
 p.ellipsoid((0,147,-17),(25,28,10),'armor')
 p.ellipsoid((0,146,-25),(20,23,7),'dark')
 # An eye floating within the black opening; two small stars are the only cyan.
 p.ellipsoid((0,148,-32),(10,5,2),'glow_core');p.ellipsoid((0,148,-34),(2,5,1),'glow_eye')
 p.ellipsoid((0,99,-13),(13,18,8),'armor');p.ellipsoid((0,99,-21),(8,12,3),'glow_core')
 ring(p,(0,184,0),32,3,'silver',n=8)
 for i in range(8):
  a=i*math.tau/8;x,z=math.cos(a)*31,math.sin(a)*31
  p.chain([(x,184,z),(x*1.1,203+(i%2)*7,z*1.1),(x*.85,218+(i%2)*5,z*.85)],4,.4,'edge')
  p.ellipsoid((x*1.05,200,z*1.05),(2,3,2),'glow_rune')
 for s in [-1,1]:
  p.ellipsoid((s*40,124,0),(17,13,19),'armor')
  for j in range(3):p.capsule((s*(32+j*7),131,0),(s*(39+j*9),146-j*3,3),4,.3,'silver')
  for x,y,z in [(s*31,63,6),(s*37,42,14),(s*20,85,-9)]:p.ellipsoid((x,y,z),(1.5,2,1.5),'glow_eye')
 parts={'body':p.voxels()};limbs={}
 for s,label in [(-1,'l'),(1,'r')]:
  a=part(VOID);a.chain([(0,0,0),(s*17,-23,-2),(s*29,-33,-17)],10,6,'cloth_light')
  a.ellipsoid((s*28,-33,-17),(10,9,8),'silver')
  for j in range(4):
   a.chain([(s*(20+j*4),-32,-20),(s*(24+j*5),-36,-33),(s*(21+j*5),-44,-36)],2.3,.3,'silver')
   a.ellipsoid((s*(24+j*5),-36,-33),(2,2,2),'glow_rune')
  # Dangling sleeve tassels, distinct from the bony fingers.
  for j in range(3):a.chain([(s*(4+j*4),-17,5),(s*(13+j*5),-43,8),(s*(7+j*8),-58,13)],3,.3,'cloth_dark')
  parts['arm_'+label]=a.voxels();limbs['arm_'+label]=limb('arm_'+label,[s*38,118,0],'arm',phase=-s,throws=False)
 # Broken orbital runic tablets create an open portal-like halo behind the crown.
 h=part(VOID)
 for i in range(9):
  a=(i*32+10)*math.pi/180;x,y=math.cos(a)*71,121+math.sin(a)*71
  h.ellipsoid((x,y,19),(6,11,4),'armor')
  h.capsule((x-2,y-3,14),(x+2,y+4,14),1.2,1.2,'glow_rune')
 parts['halo']=h.voxels();limbs['halo']=limb('halo',[0,0,0],role='')
 save('hollow_crown','The Hollow Crown','Dark',VOID,parts,limbs,hover=.55,hand=[0,99,-24])

def main():
 OUT.mkdir(parents=True,exist_ok=True)
 frost();demon();scarab();wraith()
 (OUT/'manifest.json').write_text(json.dumps(MODELS,indent=2)+'\n')
 print('Saved four bosses and two frost support models. No gameplay registration.',flush=True)
if __name__=='__main__':main()
