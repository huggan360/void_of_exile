#!/usr/bin/env python3
"""Author live, rigged 32-cell bosses, expanded 8x into 256-cell VOX frames.
Only exposed faces are stored; the block silhouette is exact nearest-neighbor.
No previews or tests. Existing art is backed up before replacement.
"""
import json, math, struct, shutil, datetime
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'creatures'
STEP=8
PAL={
 'blue':{'base':(29,79,169),'light':(66,143,213),'shade':(19,39,94),'belly':(101,186,211),'bone':(199,169,92),'dark':(11,20,43),'wing':(26,107,158),'glow_eye':(42,226,229),'glow_core':(34,161,237),'accent':(52,111,183)},
 'ice':{'base':(49,123,174),'light':(108,195,222),'shade':(29,58,116),'belly':(68,162,193),'bone':(152,217,228),'dark':(15,30,72),'wing':(58,95,151),'glow_eye':(56,229,231),'glow_core':(80,173,242),'accent':(75,125,198)},
 'fire':{'base':(132,27,38),'light':(183,46,37),'shade':(67,23,37),'belly':(84,28,34),'bone':(183,133,74),'dark':(22,18,30),'wing':(89,21,37),'glow_eye':(251,148,29),'glow_core':(238,66,19),'accent':(54,42,51)},
 'gold':{'base':(187,124,33),'light':(231,181,63),'shade':(112,66,29),'belly':(34,101,111),'bone':(207,175,97),'dark':(17,35,52),'wing':(29,81,94),'glow_eye':(242,108,151),'glow_core':(242,158,42),'accent':(51,145,146)},
 'void':{'base':(57,30,88),'light':(97,46,127),'shade':(31,23,55),'belly':(70,39,105),'bone':(158,121,74),'dark':(13,15,33),'wing':(43,24,67),'glow_eye':(51,207,207),'glow_core':(209,45,167),'accent':(115,61,146)},
}
def box(v,a,b,c):
 for x in range(a[0],b[0]):
  for y in range(a[1],b[1]):
   for z in range(a[2],b[2]):v[x,y,z]=c

def ell(v,center,r,c):
 for x in range(math.floor(center[0]-r[0]),math.ceil(center[0]+r[0])):
  for y in range(math.floor(center[1]-r[1]),math.ceil(center[1]+r[1])):
   for z in range(math.floor(center[2]-r[2]),math.ceil(center[2]+r[2])):
    if sum(((q+.5-p)/s)**2 for q,p,s in zip((x,y,z),center,r))<=1:v[x,y,z]=c

def line(v,a,b,c,w=1):
 n=max(abs(b[i]-a[i]) for i in range(3))*3+1
 for j in range(n):
  p=[round(a[k]+(b[k]-a[k])*j/max(1,n-1)) for k in range(3)]
  box(v,p,[q+w for q in p],c)

def polygon(v,points,z0,z1,c):
 for y in range(min(p[1] for p in points),max(p[1] for p in points)+1):
  for x in range(min(p[0] for p in points),max(p[0] for p in points)+1):
   inside=False;j=len(points)-1
   for i,(px,py) in enumerate(points):
    qx,qy=points[j]
    if (py>y+.5)!=(qy>y+.5) and x+.5<(qx-px)*(y+.5-py)/(qy-py)+px:inside=not inside
    j=i
   if inside:box(v,(x,y,z0),(x+1,y+1,z1),c)

def diamond(v,c,r,h,color):
 for y in range(c[1]-h,c[1]+h+1):
  width=r*(1-abs(y-c[1])/(h+1))
  for x in range(math.floor(c[0]-r),math.ceil(c[0]+r)+1):
   for z in range(math.floor(c[2]-r),math.ceil(c[2]+r)+1):
    if abs(x-c[0])+abs(z-c[2])<=width:
     v[x,y,z]='shade' if x>c[0] else 'light' if z<c[2]-1 else color

def part(v,pivot):return {(x-pivot[0],y-pivot[1],z-pivot[2]):c for (x,y,z),c in v.items()}
def limb(name,pivot,role,phase=1,**kw):return dict(part=name,pivot=[x*8 for x in pivot],role=role,phase=phase,yaw=kw.pop("yaw",0),**kw)
def recolor(v,changes):return {p:changes.get(c,c) for p,c in v.items()}
def upscale(v):
 # Empty interior prevents millions of invisible tiny voxels per body.
 out={}
 dirs=[(1,0,0),(-1,0,0),(0,1,0),(0,-1,0),(0,0,1),(0,0,-1)]
 for (x,y,z),color in v.items():
  origin=(x*8,y*8,z*8)
  for dx,dy,dz in dirs:
   if (x+dx,y+dy,z+dz) in v:continue
   axis=0 if dx else 1 if dy else 2
   side=7 if (dx+dy+dz)>0 else 0
   others=[i for i in range(3) if i!=axis]
   for a in range(8):
    for b in range(8):
     p=list(origin);p[axis]+=side;p[others[0]]+=a;p[others[1]]+=b
     out[tuple(p)]=color
 # Sparse two-pixel glints inside selected coarse glow tiles, not noisy sculpting.
 for p,c in list(out.items()):
  if c=='glow_eye' and p[0]%8 in (3,4) and p[1]%8 in (3,4):out[p]='glow_core'
 return out

def write(path,v,pal,lo,size):
 names=list(pal);indices={c:i+1 for i,c in enumerate(names)}
 points=bytearray(struct.pack('<I',len(v)))
 for (x,y,z),color in v.items():points.extend((z-lo[2],x-lo[0],y-lo[1],indices[color]))
 rgba=b''.join(bytes((*pal[names[i]],255)) if i<len(names) else bytes((0,0,0,255)) for i in range(256))
 def chunk(name,data):return name+struct.pack('<II',len(data),0)+data
 children=chunk(b'SIZE',struct.pack('<III',size[2],size[0],size[1]))+chunk(b'XYZI',points)+chunk(b'RGBA',rgba)
 path.write_bytes(b'VOX '+struct.pack('<I',150)+b'MAIN'+struct.pack('<II',0,len(children))+children)

def bounds(v):
 lo=tuple(min(p[k] for p in v) for k in range(3));hi=tuple(max(p[k] for p in v)+1 for k in range(3))
 return lo,tuple(hi[k]-lo[k] for k in range(3))

MANIFEST=json.loads((OUT/'realm_boss_manifest.json').read_text())
def save(name,title,theme,parts,limbs,variants,hand,unit=.04,hover=0):
 folder=OUT/name;folder.mkdir(exist_ok=True)
 expanded={n:upscale(v) for n,v in parts.items()}
 if name=='blue_dragon':
  # Tiny inset eye slits, rather than friendly full-block glowing eyes.
  for n in ['body','body_enraged']:
   for p,c in list(expanded[n].items()):
    if p[0]//8 in [-2,2] and p[1]//8==18 and p[2]//8==-12 and c.startswith('glow'):
     if p[1]%8 not in [3,4]:expanded[n][p]='shade'
 rig=dict(voxel_size=unit,parts={},limbs=limbs,variants=variants,hand=[q*8 for q in hand],hover=hover,bob=.06,waddle=0,flap_rate=1.4,pixel_art=True,material_jitter=0.0,glow_strength=1.1)
 if name=='vharok_cinder_tyrant':rig['animation_style']='tyrant';rig['bob']=0.0
 if name=='aureate_scarab_regent':rig['animation_style']='scarab'
 rig['animation_style']={'blue_dragon':'dragon','hollow_crown':'wraith','rimeheart_prism':'prism'}.get(name,rig.get('animation_style'))
 if rig['animation_style'] is None:del rig['animation_style']
 for base in {'body'}|{s['part'] for s in limbs.values()}:
  names={base}|{s.get(base,base) for s in variants.values()}
  allpoints={p:c for n in names for p,c in expanded[n].items()};lo,size=bounds(allpoints)
  for n in names:
   v=expanded[n];solid={p:c for p,c in v.items() if not c.startswith('glow')};glow={p:c for p,c in v.items() if c.startswith('glow')}
   info=dict(frame_min=list(lo),frame_size=list(size))
   for suffix,data in [('',solid),('_glow',glow)]:
    path=folder/(n+suffix+'.vox')
    if data:write(path,data,PAL[theme],lo,size)
    elif path.exists():path.unlink()
   if not solid:info['solid']=False
   if glow:info['glow']=True
   rig['parts'][n]=info
 (folder/'rig.json').write_text(json.dumps(rig,indent=2)+'\n')
 # Editable low-resolution masters accompany the enlarged in-game rig.
 source=folder/'source_32';source.mkdir(exist_ok=True)
 coarse_rig=json.loads(json.dumps(rig));coarse_rig['voxel_size']=unit*8
 coarse_rig['hand']=[q/8 for q in rig['hand']]
 for spec in coarse_rig['limbs'].values():spec['pivot']=[q/8 for q in spec['pivot']]
 for n,info in coarse_rig['parts'].items():
  lo=tuple(q//8 for q in info['frame_min']);size=tuple(q//8 for q in info['frame_size'])
  info['frame_min']=list(lo);info['frame_size']=list(size)
  for suffix,data in [('',{p:c for p,c in parts[n].items() if not c.startswith('glow')}),('_glow',{p:c for p,c in parts[n].items() if c.startswith('glow')})]:
   if data:write(source/(n+suffix+'.vox'),data,PAL[theme],lo,size)
 (source/'rig.json').write_text(json.dumps(coarse_rig,indent=2)+'\n')
 poses={}
 for form,swaps in {'default':{},**variants}.items():
  full=dict(expanded[swaps.get('body','body')])
  for spec in limbs.values():
   pivot=list(spec['pivot']);ancestor=spec.get('parent_limb')
   while ancestor:
    parent=limbs[ancestor];pivot=[pivot[k]+parent['pivot'][k] for k in range(3)];ancestor=parent.get('parent_limb')
   a=math.radians(spec.get('yaw',0));co,si=math.cos(a),math.sin(a)
   for (x,y,z),c in expanded[swaps.get(spec['part'],spec['part'])].items():full[round(co*x+si*z+pivot[0]),y+pivot[1],round(-si*x+co*z+pivot[2])]=c
  # An explicit 256 cube is the editor canvas; occupied silhouette stays coarse.
  lo=(-128,0,-128);size=(256,256,256)
  filename='model.vox' if form=='default' else 'model_'+form+'.vox'
  write(folder/filename,full,PAL[theme],lo,size)
  poses[form]=dict(file=filename,frame_min=list(lo),size=list(size),voxels=len(full))
 (folder/'poses.json').write_text(json.dumps(poses,indent=2)+'\n')
 record=dict(id=name,display_name=title,biome={'blue':'Bluelay','ice':'Fosen','fire':'Lava','gold':'Desert','void':'Dark'}[theme],folder='creatures/'+name,status='live',voxel_size=unit,parts=list(parts),variants=list(variants),poses=poses,design_grid=[32,32,32],upscale=8)
 for i,old in enumerate(MANIFEST):
  if old['id']==name:MANIFEST[i]=record;break
 else:MANIFEST.append(record)
 print('Authored',name,flush=True)

def dragon():
 # A long, low four-legged predator, not an upright mascot.
 PAL['blue'].update(base=(22,56,115),light=(43,94,151),shade=(12,27,61),belly=(51,91,110),bone=(172,156,116),dark=(8,17,34),wing=(17,48,82),glow_eye=(244,158,37),glow_core=(24,164,220),accent=(27,76,133))
 body={}
 ell(body,(0,10,2),(4,4,7),'base')
 ell(body,(0,12,-3),(4,4,4),'base')
 # Rising S-neck, wedge skull, long armored snout and lowered snarling jaw.
 ell(body,(0,14,-6),(2.5,4,3),'base')
 ell(body,(0,17,-9),(3,3,4),'base')
 box(body,(-2,15,-15),(2,17,-9),'base')
 box(body,(-2,13,-14),(2,14,-8),'shade')
 box(body,(-2,14,-15),(2,15,-9),'dark')
 box(body,(-1,15,-16),(1,16,-15),'shade')
 box(body,(-1,14,-15),(1,15,-14),'glow_core')
 for side in [-1,1]:
  # Single-cell slitted eyes sit below heavy, forward-sloping brow ridges.
  body[side*2,18,-12]='glow_eye'
  line(body,(side*2,19,-13),(side*3,20,-9),'shade')
  line(body,(side*3,18,-9),(side*5,17,-5),'light')
  line(body,(side*2,19,-7),(side*4,22,-3),'bone')
  line(body,(side*4,22,-3),(side*4,23,0),'bone')
  for z in [-13,-10]:body[side,14,z]='bone'
  # Muscular rear haunches and forward-planted forelegs, with three talons.
  ell(body,(side*4,7,5),(2.5,4,3),'base')
  line(body,(side*5,6,5),(side*5,2,7),'shade',2)
  box(body,(side*5-1,0,3),(side*5+2,2,8),'base')
  ell(body,(side*3.5,9,-4),(2,3,2),'base')
  line(body,(side*4,8,-5),(side*5,3,-6),'shade',2)
  box(body,(side*5-1,0,-8),(side*5+2,3,-4),'base')
  for x in [side*5-1,side*5,side*5+1]:
   body[x,0,-9]='bone';body[x,0,2]='bone'
  # Shoulder spikes slope backward along the body.
  line(body,(side*3,13,-2),(side*5,16,1),'shade')
 for y,z in [(11,-5),(13,-7),(15,-9)]:box(body,(-1,y,z-1),(1,y+1,z),'belly')
 for z in [-2,1,4,7]:
  line(body,(0,14 if z<4 else 13,z),(0,17 if z<4 else 16,z+1),'shade')
  body[0,17 if z<4 else 16,z+1]='light'
 parts={'body':body,'body_enraged':recolor(body,{'base':'accent','glow_eye':'glow_core','light':'base'})}
 limbs={}
 for side,suffix in [(-1,'l'),(1,'r')]:
  wing={}
  # Swept bat wings tower above the small predatory head; torn bays between fingers.
  points=[(side*x,y) for x,y in [(3,13),(6,22),(13,29),(15,27),(14,18),(12,14),(10,17),(8,11),(6,14),(4,10)]]
  polygon(wing,points,1,3,'wing')
  line(wing,(side*3,13,0),(side*6,22,0),'base',2)
  line(wing,(side*6,22,0),(side*13,29,1),'shade')
  for x,y in [(15,27),(14,18),(12,14),(8,11),(4,10)]:
   line(wing,(side*6,22,0),(side*x,y,1),'light' if x==15 else 'base')
  line(wing,(side*13,29,1),(side*15,30,2),'bone')
  name='wing_'+suffix;pivot=(side*3,13,1)
  parts[name]=part(wing,pivot)
  parts[name+'_enraged']=recolor(parts[name],{'wing':'shade','light':'glow_core'})
  limbs[name]=limb(name,pivot,'wing',-side)
 tail={}
 for start,end,width in [((0,9,7),(1,6,10),3),((1,6,10),(3,4,13),2),((3,4,13),(5,6,15),1)]:line(tail,start,end,'base',width)
 for x,y,z in [(1,8,9),(2,7,11),(3,6,13)]:line(tail,(x,y,z),(x,y+2,z+1),'shade')
 diamond(tail,(4,6,13),1,2,'shade')
 parts['tail']=part(tail,(0,9,7))
 parts['tail_enraged']=recolor(parts['tail'],{'shade':'glow_core'})
 limbs['tail']=limb('tail',(0,9,7),'sway')
 save('blue_dragon','Blue Dragon','blue',parts,limbs,{'enraged':{n:n+'_enraged' for n in ['body','wing_l','wing_r','tail']}},(0,14,-15),unit=.045,hover=.12)

def demon():
 body={};polygon(body,[(-6,20),(-5,12),(-3,9),(3,9),(5,12),(6,20),(4,23),(-4,23)],-3,4,'base')
 polygon(body,[(-6,21),(-5,17),(0,15),(5,17),(6,21),(3,22),(0,19),(-3,22)],-4,-3,'dark')
 box(body,(-3,10,-4),(3,12,4),'accent');box(body,(-1,10,-5),(1,12,-4),'bone')
 box(body,(-3,22,-3),(3,27,3),'base');box(body,(-3,24,-4),(3,26,-3),'dark')
 for side in [-1,1]:
  box(body,(side*2-1,24,-5),(side*2+1,25,-4),'glow_eye');line(body,(side*2,26,0),(side*5,28,1),'bone',2);line(body,(side*5,28,1),(side*5,31,0),'bone')
  box(body,(side*2-1,22,-4),(side*2,23,-3),'bone')
 box(body,(-2,22,-4),(2,23,-3),'dark');diamond(body,(0,16,-4),2,3,'glow_core')
 # Preserve a small ember heart, with much more exposed flame in phase three.
 for p in list(body):
  if body[p] in ['light','shade'] and abs(p[0])<=1 and 14<=p[1]<=18:body[p]='glow_core'
 # Heavy, jagged pauldrons and a lowered armored brow sharpen the silhouette.
 for side in [-1,1]:
  box(body,(side*5-2,19,-3),(side*5+2,22,3),'dark')
  line(body,(side*6,21,0),(side*8,24,1),'accent',2)
  box(body,(side*2-1,25,-5),(side*2+1,26,-4),'dark')
  body[side*2,24,-5]='glow_eye'
 parts={'body':body,'body_infernal':recolor(body,{'base':'light','glow_eye':'glow_core'}),'body_unbound':dict(body)}
 for y in range(13,20):
  for x in range(-2,3):
   if abs(x)+abs(y-16)<=4:parts['body_unbound'][x,y,-4]='glow_eye' if abs(x)+abs(y-16)<=1 else 'glow_core'
 limbs={}
 for side,suffix in [(-1,'l'),(1,'r')]:
  arm={};line(arm,(side*6,20,0),(side*9,16,-1),'base',3);box(arm,(side*8-2,12,-4),(side*8+2,17,1),'dark')
  for dx in [-1,1]:line(arm,(side*8+dx,13,-4),(side*8+dx,10,-5),'bone')
  for k in [0,2]:line(arm,(side*(7+k),20,0),(side*(8+k),23,0),'accent')
  pivot=(side*6,20,0);name='arm_'+suffix;parts[name]=part(arm,pivot);limbs[name]=limb(name,pivot,'arm',-side,throws=False)
  # Braced split stance: bent knees, left foot forward, right foot behind.
  foot_z=-3 if side==-1 else 4
  knee_z=-2 if side==-1 else 2
  leg={}
  line(leg,(side*3-1,7,0),(side*4-1,4,knee_z),'shade',3)
  line(leg,(side*4-1,4,knee_z),(side*4-1,1,foot_z),'base',3)
  box(leg,(side*4-2,0,foot_z-3),(side*4+2,2,foot_z+3),'dark')
  box(leg,(side*4-2,3,knee_z-1),(side*4+2,5,knee_z),'accent')
  for dx in [-1,1]:box(leg,(side*4+dx,0,foot_z-4),(side*4+dx+1,1,foot_z-2),'bone')
  name='leg_'+suffix;pivot=(side*3,8,1)
  upper={p:c for p,c in leg.items() if p[1]>=4};lower={p:c for p,c in leg.items() if p[1]<4}
  parts[name]=part(upper,pivot);limbs[name]=limb(name,pivot,'leg',-side)
  knee=(side*4,4,knee_z);shin='shin_'+suffix
  parts[shin]=part(lower,knee)
  relative=tuple(knee[k]-pivot[k] for k in range(3))
  limbs[shin]=limb(shin,relative,'knee',-side,parent_limb=name)
  wing={};polygon(wing,[(side*x,y) for x,y in [(5,20),(14,27),(15,17),(12,13),(10,17),(7,14)]],4,5,'wing')
  for x,y in [(14,27),(15,17),(12,13)]:line(wing,(side*5,20,3),(side*x,y,3),'dark')
  name='wing_'+suffix;pivot=(side*5,20,4);parts[name]=part(wing,pivot);parts[name+'_unbound']=recolor(parts[name],{'wing':'base','dark':'glow_core'});limbs[name]=limb(name,pivot,'wing',-side)
 tail={};line(tail,(0,10,4),(3,6,9),'shade',2);line(tail,(3,6,9),(5,9,12),'base');diamond(tail,(5,9,12),1,2,'glow_core');parts['tail']=part(tail,(0,10,4));limbs['tail']=limb('tail',(0,10,4),'sway')
 # Lower the torso into the bent legs, with the chest and head leaning forward.
 for name in ['body','body_infernal','body_unbound']:
  parts[name]={(x,y-2,z-1):color for (x,y,z),color in parts[name].items()}
 for name,spec in limbs.items():
  if name.startswith(('leg','shin')):continue
  spec['pivot'][1]-=16;spec['pivot'][2]-=8
 save('vharok_cinder_tyrant' ,'Vharok, the Cinder Tyrant','fire',parts,limbs,{'infernal':{'body':'body_infernal'},'heart_unbound':{'body':'body_unbound','wing_l':'wing_l_unbound','wing_r':'wing_r_unbound'}},(0,15,-6))

def frost():
 body={};diamond(body,(0,16,0),5,12,'base');box(body,(-2,15,-5),(2,18,-4),'dark');box(body,(-1,16,-6),(1,17,-5),'glow_eye')
 for y in [6,25]:box(body,(-1,y,-2),(1,y+1,2),'bone')
 conduit={};diamond(conduit,(0,16,0),3,7,'base');box(conduit,(-2,15,-3),(2,18,-2),'glow_eye')
 for y in [8,24]:
  for x in range(-4,5):
   for z in range(-4,5):
    if max(abs(x),abs(z))==4:conduit[x,y,z]='bone'
 tempest=dict(conduit);diamond(tempest,(0,16,-1),2,4,'glow_core')
 petals={}
 diamond(petals,(0,0,0),2,7,'base');petals[0,1,-2]='glow_eye'
 openpetal={};diamond(openpetal,(0,1,3),2,7,'base');openpetal[0,2,1]='glow_core'
 storm={}
 for z in range(0,9):
  r=2 if 2<=z<=6 else 1
  box(storm,(-r,-1,z),(r+1,2,z+1),'light' if z%3 else 'base')
 box(storm,(-1,0,3),(2,1,7),'glow_core')
 parts={'body':body,'body_conduit':conduit,'body_tempest':tempest,'petal':petals,'petal_conduit':openpetal,'petal_tempest':storm};limbs={}
 for i in range(6):
  angle=i*math.tau/6;pivot=(round(math.sin(angle)*5),15+(i%2),round(math.cos(angle)*5))
  limbs['shard_'+str(i)]=limb('petal',pivot,'',yaw=i*60)
 save('rimeheart_prism','Rimeheart Prism','ice',parts,limbs,{'conduit':{'body':'body_conduit','petal':'petal_conduit'},'tempest':{'body':'body_tempest','petal':'petal_tempest'}},(0,16,-6),hover=.6)

def scarab():
 body={};ell(body,(0,14,2),(6,7,8),'wing');ell(body,(0,17,3),(5,5,6),'base');box(body,(-1,14,-5),(1,22,9),'shade')
 box(body,(-3,20,-7),(3,26,-2),'base');box(body,(-2,21,-8),(2,25,-7),'belly')
 for side in [-1,1]:
  for y in range(20,27):box(body,(side*4-1,y,-6),(side*4+1,y+1,-2),'base' if y%2 else 'belly')
  box(body,(side*2-1,23,-9),(side*2+1,24,-8),'glow_eye')
  line(body,(side*2,20,-6),(side*4,18,-10),'base');line(body,(side*4,18,-10),(side*2,19,-11),'light')
 line(body,(0,25,-4),(0,30,-3),'base',2)
 for side in [-1,1]:line(body,(0,28,-3),(side*3,31,-3),'light')
 diamond(body,(0,15,-5),2,3,'glow_core')
 parts={'body':body,'body_sunwings':recolor(body,{'base':'light'}),'body_sunheart':recolor(body,{'base':'shade','glow_core':'glow_eye'})};limbs={}
 for side,suffix in [(-1,'l'),(1,'r')]:
  leg={};line(leg,(0,0,0),(side*4,-3,0),'shade',2);line(leg,(side*4,-3,0),(side*6,-8,-1),'base');parts['leg_'+suffix]=leg
  for i,z in enumerate([-4,1,6]):limbs['leg_'+suffix+'_'+str(i)]=limb('leg_'+suffix,(side*5,10,z),'leg',(-1)**i*side,axis='y',amount=.35)
  wing={};polygon(wing,[(side*x,y) for x,y in [(0,0),(7,4),(9,-1),(7,-5),(2,-6)]],0,6,'base')
  for j in [1,3,5]:line(wing,(side*2,-j,0),(side*7,2-j,0),'light')
  name='wing_'+suffix;parts[name]=wing
  opened={};polygon(opened,[(side*x,y) for x,y in [(0,0),(9,7),(10,1),(8,-3),(3,-4)]],0,2,'belly')
  for j in [0,2,4]:line(opened,(0,0,0),(side*(10-j),7-j,0),'base')
  parts[name+'_sunwings']=opened;parts[name+'_sunheart']=recolor(opened,{'belly':'shade','base':'glow_core'});limbs[name]=limb(name,(side*4,18,1),'wing',-side)
 save('aureate_scarab_regent','Aureate Scarab Regent','gold',parts,limbs,{s:{'body':'body_'+s,'wing_l':'wing_l_'+s,'wing_r':'wing_r_'+s} for s in ['sunwings','sunheart']},(0,22,-10),unit=.044,hover=.15)

def wraith():
 body={};polygon(body,[(-7,3),(-5,12),(-4,20),(0,23),(4,20),(5,12),(7,3),(3,5),(1,1),(-1,4),(-4,1)],-2,3,'base')
 polygon(body,[(-3,7),(-2,20),(0,21),(2,20),(3,7),(0,10)],-3,-2,'shade')
 box(body,(-3,21,-3),(3,26,2),'dark')
 for side in [-1,1]:
  box(body,(side*2-1,23,-4),(side*2+1,24,-3),'glow_eye' if side<0 else 'glow_core')
  line(body,(side*3,21,-2),(side*5,19,-1),'light',2)
 box(body,(-4,26,-3),(4,28,3),'bone')
 for x in [-3,0,3]:box(body,(x,28,-3),(x+1,31 if x==0 else 30,-1),'bone')
 box(body,(-2,21,-4),(2,22,-3),'shade');box(body,(0,21,-4),(1,22,-3),'bone')
 diamond(body,(0,15,-3),2,3,'glow_core')
 parts={'body':body,'body_fractured':recolor(body,{'bone':'accent'}),'body_unbound':recolor(body,{'base':'shade','glow_eye':'glow_core'})};limbs={}
 for side,suffix in [(-1,'l'),(1,'r')]:
  arm={};line(arm,(side*5,20,0),(side*8,15,-2),'base',2);box(arm,(side*9-2,12,-4),(side*9+2,15,-1),'light')
  for dx in [-1,0,1]:line(arm,(side*9+dx,13,-4),(side*9+dx,10,-5),'bone')
  name='arm_'+suffix;pivot=(side*5,20,0);parts[name]=part(arm,pivot);limbs[name]=limb(name,pivot,'arm',-side,throws=False)
 halo={};fractured={};unbound={}
 for i in range(8):
  a=i*math.tau/8;b=(i+.7)*math.tau/8
  p=(round(math.cos(a)*9),21+round(math.sin(a)*9),4);q=(round(math.cos(b)*9),21+round(math.sin(b)*9),4)
  line(halo,p,q,'accent');line(fractured,(p[0],p[1],5),(q[0],q[1],5),'glow_core' if i%3==0 else 'accent')
  line(unbound,p,q,'glow_core' if i%2==0 else 'light')
 parts.update(halo=halo,halo_fractured=fractured,halo_unbound=unbound);limbs['halo']=limb('halo',(0,0,0),'')
 save('hollow_crown','The Hollow Crown','void',parts,limbs,{'fractured_court':{'body':'body_fractured','halo':'halo_fractured'},'unbound':{'body':'body_unbound','halo':'halo_unbound'}},(0,17,-5),hover=.55)

def shell(name,theme):
 body={};ell(body,(0,8,0),(5,8,5),'base')
 for x in [-3,0,3]:line(body,(x,4,-4),(x,12,-3),'shade')
 if theme=='fire':
  for side in [-1,1]:line(body,(side*3,10,0),(side*5,17,0),'dark')
 if theme=='gold':box(body,(-5,0,-5),(5,2,5),'shade');box(body,(-2,7,-5),(2,10,-4),'belly')
 variants={};parts={'body':body}
 for stage in range(1,4):
  v=dict(body)
  for j in range(stage*3):
   y=3+j;x=(j%3)-1
   for z in [-5,-4]:
    if (x,y,z) in v:v[x,y,z]='glow_core'
  parts['body_crack'+str(stage)]=v;variants['crack'+str(stage)]={'body':'body_crack'+str(stage)}
 save(name,{'egg_blue_dragon':'Azure Egg','egg_rimeheart':'Frost Geode','egg_vharok':'Obsidian Cocoon','egg_scarab':'Solar Reliquary','egg_hollow_crown':'Black Reliquary'}[name],theme,parts,{},variants,(0,8,-5))

PROJECTILES=[]
def projectile(name,theme,v,unit):
 folder=OUT/'boss_projectiles'/name;folder.mkdir(parents=True,exist_ok=True)
 full=upscale(v);lo,size=bounds(full);write(folder/'model.vox',full,PAL[theme],lo,size)
 (folder/'rig.json').write_text(json.dumps(dict(voxel_size=unit,design_grid=32,upscale=8),indent=2)+'\n')
 PROJECTILES.append(dict(id=name,folder=str(folder.relative_to(ROOT)),size=list(size),voxel_size=unit))

def fire_crescent():
 # Forward is -Z. The tips and ragged tongues sweep back along +Z.
 flame={}
 for x in range(-12,13):
  center=-3+round(7*(abs(x)/12)**1.7)
  thin=abs(x)>=11
  for z in range(center-(0 if thin else 1),center+(1 if thin else 2)):
   for y in ([0] if thin else [-1,0,1]):
    front=z<=center
    color='shade' if y==-1 else 'glow_core' if front else 'base'
    if y>=0 and z==center and abs(x)<10:color='glow_eye'
    flame[x,y,z]=color
 for x,length in [(-9,2),(-6,3),(-3,2),(2,3),(6,2),(9,2)]:
  center=-3+round(7*(abs(x)/12)**1.7)
  for tail in range(2,length+3):
   flame[x,0,center+tail]='base' if tail==length+2 else 'glow_core'
 return flame

def write_fire_collision(flame):
 # Merge matching neighboring columns into thin offset boxes following the arc.
 full=upscale(flame);lo,size=bounds(full)
 center=[lo[k]+size[k]/2 for k in range(3)];groups=[]
 for x in range(-12,13):
  column=[p for p in flame if p[0]==x]
  profile=(min(p[1] for p in column),max(p[1] for p in column)+1,min(p[2] for p in column),max(p[2] for p in column)+1)
  if groups and groups[-1][2]==profile:groups[-1][1]=x+1
  else:groups.append([x,x+1,profile])
 boxes=[]
 for x0,x1,(y0,y1,z0,z1) in groups:
  offset=[((a+b)*4-center[k])*.014 for k,(a,b) in enumerate([(x0,x1),(y0,y1),(z0,z1)])]
  half=[(b-a)*4*.014 for a,b in [(x0,x1),(y0,y1),(z0,z1)]]
  boxes.append(dict(offset=offset,half=half))
 path=OUT/'boss_projectiles/fire_cleave/rig.json'
 rig=json.loads(path.read_text());rig['collision_half_extents']=[q*.014/2 for q in size];rig['collision_boxes']=boxes
 path.write_text(json.dumps(rig,indent=2)+'\n')

def vharok_shots():
 flame=fire_crescent()
 projectile('fire_shard','fire',flame,.014*.32)
 PAL['white']={'shade':(132,142,161),'base':(214,219,230),'glow_core':(249,249,255),'glow_eye':(255,244,216)}
 ember={};ell(ember,(0,0,0),(3,3,3),'shade');ell(ember,(0,0,-.5),(2,2,2),'base')
 box(ember,(-1,-1,-3),(1,1,-2),'glow_core')
 ember[0,1,-2]='glow_eye';ember[-2,0,-1]='glow_core'
 projectile('white_ember','white',ember,.009)


def shots():
 for theme in ['blue','ice','fire','gold','void']:
  bolt={}
  for z in range(-5,6):
   width=1 if abs(z)>2 else 2
   for x in range(-width,width+1):
    for y in range(-1,2):
     if abs(x)+abs(y)<=width:bolt[x,y,z]='shade' if abs(x)==width else 'glow_core' if y==0 else 'base'
  box(bolt,(-1,0,-4),(1,1,3),'glow_eye')
  if theme=='blue':
   for side in [-1,1]:line(bolt,(side*2,0,1),(side*3,0,4),'base');bolt[side*3,0,4]='glow_core'
  elif theme=='ice':
   bolt.clear()
   for z in range(-7,7):
    width=max(0,3-abs(z)//2)
    for x in range(-width,width+1):
     for y in range(-1,2):
      if abs(x)+abs(y)<=width:bolt[x,y,z]='shade' if x<0 else 'base' if y else 'glow_core'
  elif theme=='fire':
   for side in [-1,1]:line(bolt,(side*2,0,1),(side*3,0,6),'base');bolt[side*3,0,6]='glow_core'
  elif theme=='gold':
   for side in [-1,1]:
    box(bolt,(side*2-1,0,1),(side*2+1,1,4),'base');bolt[side*2,0,1]='belly'
  elif theme=='void':
   bolt.clear()
   for z in range(-5,6):
    x=round(math.sin(z*.45)*2)
    box(bolt,(x-1,-1,z),(x+2,1,z+1),'shade');bolt[x,0,z]='glow_core'
  projectile(theme+'_bolt',theme,bolt,.010 if theme!='ice' else .009)
  orb={};ell(orb,(0,0,0),(3,3,3),'shade');ell(orb,(0,0,-1),(2,2,2),'base');box(orb,(-1,-1,-3),(1,1,-2),'glow_core')
  for side in [-1,1]:line(orb,(side*3,-1,0),(side*3,1,0),'glow_eye')
  if theme=='blue':
   for z in range(2,6):box(orb,(-1,0,z),(1,1,z+1),'base' if z%2 else 'glow_core')
  elif theme=='ice':
   orb.clear()
   for z in range(-5,6):
    r=max(0,3-abs(z)//2)
    for x in range(-r,r+1):
     for y in range(-r,r+1):
      if abs(x)+abs(y)<=r:orb[x,y,z]='shade' if x<0 else 'glow_core' if y==0 else 'base'
  elif theme=='fire':
   for side in [-1,1]:line(orb,(side*2,1,1),(side*3,3,3),'base')
  elif theme=='gold':
   for side in [-1,1]:box(orb,(side*3-1,0,-1),(side*3+1,1,2),'belly')
  elif theme=='void':
   box(orb,(-2,-1,-3),(2,1,-2),'glow_core');box(orb,(0,-1,-4),(1,1,-3),'dark')
   for side in [-1,1]:orb[side*4,side,0]='glow_eye'
  projectile(theme+'_orb',theme,orb,.012)
 disc={}
 for x in range(-4,5):
  for z in range(-4,5):
   d=abs(x)+abs(z)
   if 2<=d<=5:box(disc,(x,-1,z),(x+1,1,z+1),'shade' if d==5 else 'base')
 box(disc,(-1,-1,-1),(2,1,2),'glow_core');projectile('gold_disc','gold',disc,.014)
 flame=fire_crescent()
 projectile('fire_cleave','fire',flame,.014)
 write_fire_collision(flame)
 vharok_shots()
 (OUT/'boss_projectiles/manifest.json').write_text(json.dumps(PROJECTILES,indent=2)+'\n')

def main():
 names=['blue_dragon','rimeheart_prism','vharok_cinder_tyrant','aureate_scarab_regent','hollow_crown','egg_blue_dragon','egg_rimeheart','egg_vharok','egg_scarab','egg_hollow_crown']
 backup=Path('/home/hugo/tmp')/('boss_art_before_pixel_redesign_'+datetime.datetime.now().strftime('%Y%m%d_%H%M%S'));backup.mkdir(parents=True)
 for name in names:shutil.copytree(OUT/name,backup/name)
 shutil.copy2(OUT/'realm_boss_manifest.json',backup/'realm_boss_manifest.json')
 dragon();frost();demon();scarab();wraith()
 for name,theme in [('egg_blue_dragon','blue'),('egg_rimeheart','ice'),('egg_vharok','fire'),('egg_scarab','gold'),('egg_hollow_crown','void')]:shell(name,theme)
 shots();(OUT/'realm_boss_manifest.json').write_text(json.dumps(MANIFEST,indent=2)+'\n')
 print('Source art saved; previous files:',backup,flush=True)
if __name__=='__main__':main()
