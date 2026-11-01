#!/usr/bin/env python3
"""Native articulated gods and ordinary creatures; production assets for realm batch 03."""
import math,json
from voxel_sculpt import Part
from make_common_batch_01 import export
from preview_voxel_batch import ROOT
FIRE={'shell':(47,36,42),'shade':(78,49,49),'edge':(136,78,53),'bone':(219,179,115),'dark':(20,17,28),'glow':(245,93,35),'glow_hot':(255,202,102)}
ICE={'shell':(73,112,143),'shade':(46,72,107),'edge':(139,188,210),'bone':(222,239,235),'dark':(23,37,60),'glow':(98,219,237),'glow_hot':(192,255,249)}
BLUE={'shell':(48,64,112),'shade':(29,39,74),'edge':(91,139,172),'bone':(193,222,226),'dark':(16,20,42),'glow':(68,199,218),'glow_hot':(167,251,239)}
SAND={'shell':(158,112,61),'shade':(102,71,47),'edge':(208,163,89),'bone':(238,216,161),'dark':(43,32,39),'glow':(248,174,63),'glow_hot':(255,235,158)}
DARK={'shell':(65,33,85),'shade':(34,23,53),'edge':(124,69,145),'bone':(179,159,193),'dark':(13,13,28),'glow':(179,75,218),'glow_hot':(230,167,251)}
WOOD={'shell':(70,105,63),'shade':(42,65,43),'edge':(126,149,77),'bone':(202,184,126),'dark':(27,36,33),'glow':(178,201,85),'glow_hot':(236,221,139)}
PALS={'doom':FIRE,'fosen':ICE,'blue':BLUE,'desert':SAND,'dark':DARK,'normal':WOOD}
manifest=[]
def p(pal):return Part(3,pal)
def joint(part,at,role='leg',phase=1,**kw):return dict(part=part,pivot=[round(x*3) for x in at],role=role,phase=phase,**kw)
def mirror(v):return {(-x-1,y,z):c for (x,y,z),c in v.items()}
def ring(s,c,r,color='edge',axis='y',n=32):
 points=[]
 for i in range(n+1):
  a=i*math.tau/n;x,z=r*math.cos(a),r*math.sin(a)
  points.append((c[0]+x,c[1],c[2]+z) if axis=='y' else (c[0]+x,c[1]+z,c[2]))
 for a,b in zip(points,points[1:]):s.capsule(a,b,.3,.3,color)
def spike(s,a,b,r=1,color='bone'):s.capsule(a,b,r,.04,color)
def eye(s,x,y,z,r=.5):
 s.ellipsoid((x,y,z),(r*1.6,r,r*.5),'dark');s.ellipsoid((x,y,z-.3),(r,r*.65,r*.3),'glow_hot')
def crystal(s,c,r,h,color='glow'):
 # Eight triangular facets form a pointed crystal rather than a rounded cone.
 x,y,z=c
 for i in range(4):
  a=i*math.tau/4;b=(i+1)*math.tau/4
  v=(x+math.cos(a)*r,y,z+math.sin(a)*r);w=(x+math.cos(b)*r,y,z+math.sin(b)*r)
  s.triangle((x,y+h,z),v,w,.45,color if i%2 else 'bone')
  s.triangle((x,y-h*.65,z),v,w,.45,'edge')
def legs(pal,n=2,length=6):
 l=p(pal);l.chain([(0,0,0),(.4,-length*.5,.2),(0,-length,-.6)],.8,.5,'shade');l.box((-1,-length-1,-2),(1,-length+.2,1),'shell');return l.voxels()
def save(name,biome,s,limbs=None,parts=None,hand=(0,12,-5),hover=0,extra=None):
 pal=PALS[biome];parts={'body':s.voxels(),**(parts or {})}
 rig=dict(voxel_size=.035,parts={},limbs=limbs or {},hand=[hand[0]*3,hand[1]*3+hover/.035,hand[2]*3],hover=hover,bob=.05 if hover else 0,waddle=.3,**(extra or {}))
 export(ROOT/'creatures'/name,parts,pal,rig)
 shot=Part(2,pal)
 if biome in ['fosen','blue']:crystal(shot,(0,0,0),1.2,3)
 elif biome=='dark':shot.triangle((-1.5,0,1),(1.5,0,1),(0,0,-4),.8,'glow');ring(shot,(0,0,0),1,'glow_hot')
 else:shot.capsule((0,0,1),(0,0,-3),1.2,.1,'glow');shot.ellipsoid((0,0,0),(.7,.7,1),'glow_hot')
 export(ROOT/'creatures'/name/'projectile',{'body':shot.voxels()},pal,dict(voxel_size=.06,parts={},limbs={},hand=[0,0,0],waddle=0))
 manifest.append(dict(id=name,biome=biome,folder='creatures/'+name,parts=list(parts),art_voxels=sum(len(v) for v in parts.values())))
 print('Exported',name,flush=True)

def gods():
 # Volcanic seraph: three-layered bat pinions and a suspended furnace halo.
 pal=FIRE;s=p(pal);s.ellipsoid((0,12,0),(2.5,5,2),'shell');s.ellipsoid((0,16,-.5),(2,2.5,1.8),'shade');eye(s,0,16,-2,.8)
 ring(s,(0,19,1),3.8,'edge',axis='z');crystal(s,(0,10,-2),1.1,2,'glow')
 w=p(pal)
 for i in range(3):
  w.triangle((0,0,0),(-7-i,4-i*2,1),(-5-i,-2-i*2,3),.7,'shade')
  w.chain([(0,0,0),(-4,3-i,1),(-7-i,4-i*2,1)],.45,.1,'glow' if i==0 else 'edge')
 v=w.voxels();save('slag_seraph','doom',s,{'wing_l':joint('wing_l',(-2,14,0),'wing',1),'wing_r':joint('wing_r',(2,14,0),'wing',-1)},dict(wing_l=v,wing_r=mirror(v)),hover=.5)
 # Ram: heavy four-legged body, curling horns, black plates and molten muzzle.
 s=p(pal);s.ellipsoid((0,10,1),(4,3,6),'shell');s.ellipsoid((0,12,-4),(3.5,3.2,3),'shade');eye(s,-1.7,13,-6.5);eye(s,1.7,13,-6.5)
 s.ellipsoid((0,11,-7),(2,1.5,1),'glow')
 for sign in [-1,1]:s.chain([(sign*2,14,-4),(sign*5,17,-3),(sign*6,15,-6),(sign*4,13,-7)],1.2,.3,'edge')
 for z in [-1,2,5]:spike(s,(0,12,z),(0,15,z+1),1.1,'edge')
 lv=legs(pal,length=6);j={f'leg_{a}_{z}':joint('leg',(a*2.8,7,z),phase=a*(1 if z<0 else -1)) for a in [-1,1] for z in [-3,5]}
 save('obsidian_ram','doom',s,j,{'leg':lv},hand=(0,11,-8))
 # Lich: ragged cinder vestments, skull and long hooked staff.
 s=p(pal);s.ellipsoid((0,11,0),(3,5,2),'shade');s.ellipsoid((0,17,0),(2.4,2.8,2),'bone')
 for a in [-1,1]:eye(s,a,17,-2,.6);s.chain([(a*2,8,0),(a*4,3,1),(a*2,1,2)],.9,.05,'shell')
 s.box((-1,14,-2.1),(1,15,-1.6),'dark');s.ellipsoid((0,12,-2),(1,1.7,.6),'glow')
 a=p(pal);a.chain([(0,0,0),(2,-2,-1),(3,-4,-3)],.8,.6,'edge');a.capsule((3,-8,-3),(3,8,-3),.4,.4,'bone');ring(a,(3,8,-3),2,'edge',axis='z');a.ellipsoid((3,8,-3),(1.2,1.2,1.2),'glow')
 av=a.voxels();save('ember_lich','doom',s,{'arm_r':joint('arm',(3,13,0),'arm',-1,throws=True)},{'arm':av},hover=.2,hand=(6,21,-3))
 # Frost knight: not a boss, split crystal pauldrons and a grounded ice lance.
 pal=ICE;s=p(pal);s.box((-2.8,6,-1.7),(2.8,14,1.7),'shell');s.ellipsoid((0,17,0),(2.3,2.5,2),'bone');s.box((-2,17,-2.3),(2,17.8,-1.9),'dark');eye(s,0,17.4,-2.4,.65)
 for sign in [-1,1]:crystal(s,(sign*4,14,0),2,3,'glow')
 s.capsule((0,7,-2),(0,13,-2),.3,.3,'glow')
 a=p(pal);a.chain([(0,0,0),(1,-3,0),(1,-5,-1)],.8,.65,'edge');a.capsule((1,-8,-2),(1,4,-2),.4,.4,'shade');crystal(a,(1,6,-2),1,3,'glow')
 save('aurora_sentinel','fosen',s,{'arm_r':joint('arm',(3,13,0),'arm',-1),'leg_l':joint('leg',(-1.5,6,0)),'leg_r':joint('leg',(1.5,6,0),phase=-1)},dict(arm=a.voxels(),leg=legs(pal,length=5)),hand=(4,18,-3))
 # Broad snow owl with facial disc, antler-like crest and jagged flight feathers.
 s=p(pal);s.ellipsoid((0,10,0),(3.4,4.5,3),'bone');s.ellipsoid((0,15,-1),(4,3.5,2.6),'edge')
 for a in [-1,1]:s.ellipsoid((a*1.7,15,-3),(1.7,2,.6),'bone');eye(s,a*1.6,15,-3.7,.7);spike(s,(a*2.5,17,0),(a*4,21,1),.8,'glow')
 spike(s,(0,14,-3),(0,12.5,-5),.9,'shade');w=p(pal)
 for i in range(5):w.chain([(0,0,0),(-4-i,1-i*.3,1),(-7-i,-2-i*.6,3+i*.4)],.85,.06,'bone' if i%2 else 'edge')
 v=w.voxels();save('hoarfrost_owl','fosen',s,{'wing_l':joint('wing_l',(-2,12,0),'wing',1),'wing_r':joint('wing_r',(2,12,0),'wing',-1)},dict(wing_l=v,wing_r=mirror(v)),hand=(0,14,-5),hover=.65)
 # Colossus: thick asymmetrical ice boulder torso and oversized articulated fists.
 s=p(pal);s.ellipsoid((0,12,0),(5,6,3.5),'shade');s.ellipsoid((0,18,0),(2.5,2.6,2.4),'bone');eye(s,0,18,-2.5,.8)
 for x,y,z in [(-4,17,1),(3,16,2),(0,20,1)]:crystal(s,(x,y,z),1.5,3,'glow')
 s.capsule((-1,8,-3),(1,15,-3),.5,.5,'glow');a=p(pal);a.ellipsoid((0,-3,0),(1.7,4,1.8),'edge');a.ellipsoid((0,-6,-1),(2.4,2.4,2.5),'bone')
 save('icebound_colossus','fosen',s,{'arm_l':joint('arm',(-6,14,0),'arm',1,throws=False),'arm_r':joint('arm',(6,14,0),'arm',-1),'leg_l':joint('leg',(-2.5,6,0)),'leg_r':joint('leg',(2.5,6,0),phase=-1)},dict(arm=a.voxels(),leg=legs(pal,length=5)),hand=(6,9,-3))
 # Prism ray: horizontal diamond wings, long kite tail and glowing back gems.
 pal=BLUE;s=p(pal);s.ellipsoid((0,9,0),(3,1.8,5),'shell');s.chain([(0,9,4),(0,8,8),(2,7,12)],1,.08,'edge')
 for a in [-1,1]:eye(s,a*1.3,9,-4.5,.5)
 crystal(s,(0,11,0),1.2,2,'glow');w=p(pal);w.triangle((0,0,-2),(-10,1,2),(-2,0,6),.7,'edge');w.capsule((0,.5,-2),(-10,1,2),.35,.1,'glow')
 v=w.voxels();save('prism_ray','blue',s,{'wing_l':joint('wing_l',(-2,9,0),'wing',1),'wing_r':joint('wing_r',(2,9,0),'wing',-1)},dict(wing_l=v,wing_r=mirror(v)),hand=(0,9,-5),hover=.55)
 # Archivist: open stone tome with runic page lines, eye and detached orbit seals.
 s=p(pal)
 for a in [-1,1]:
  s.box((min(a*5,a*.5),8,-1),(max(a*5,a*.5),16,1),'bone')
  for y in [10,12,14]:s.capsule((a,y,-1.3),(a*4,y,-1.3),.22,.22,'glow')
  s.capsule((a*5,7,1),(a*5,17,1),.6,.6,'edge');crystal(s,(a*7,12,0),.9,2,'glow')
 s.ellipsoid((0,13,-2),(1.5,2,.7),'dark');eye(s,0,13,-2.8,.8);ring(s,(0,17,0),3,'edge')
 save('runic_archivist','blue',s,hand=(0,13,-3),hover=.5)
 # Azure medusa: bell-shaped jellyfish, scalloped cap and separate flowing tendrils.
 s=p(pal);s.ellipsoid((0,16,0),(5.5,3.3,4.5),'shell');s.ellipsoid((0,18,0),(4.3,2,3.5),'edge');s.ellipsoid((0,15,-3),(2,1.5,1),'glow')
 for i in range(8):
  a=i*math.tau/8;spike(s,(math.cos(a)*4,15,math.sin(a)*3),(math.cos(a)*5,13,math.sin(a)*4),.8,'glow')
 t=p(pal);t.chain([(0,0,0),(.8,-4,1),(-.5,-8,2),(1,-11,2)],.6,.12,'glow');v=t.voxels()
 j={f'tentacle_{i}':joint('tentacle',(math.cos(i*math.tau/6)*3,14,math.sin(i*math.tau/6)*2),'sway') for i in range(6)}
 save('azure_medusa','blue',s,j,{'tentacle':v},hand=(0,15,-4),hover=.45)
 # Solar jackal with gold death-mask, engraved collar, four legs and tall ears.
 pal=SAND;s=p(pal);s.ellipsoid((0,9,1),(2.8,2.8,5),'shell');s.chain([(0,10,-3),(0,14,-5)],2.4,1.5,'shade');s.ellipsoid((0,15,-5),(2.3,2.4,2),'edge');spike(s,(0,14,-6),(0,14,-9),1.6,'bone')
 for a in [-1,1]:spike(s,(a*1.4,17,-4),(a*2,21,-3),1,'shade');eye(s,a*1.3,15,-6.5,.55)
 ring(s,(0,11,-3),2.8,'glow');s.chain([(0,9,5),(1,10,8),(2,12,9)],.9,.1,'edge')
 j={f'leg_{a}_{z}':joint('leg',(a*1.9,7,z),phase=a*(1 if z<0 else -1)) for a in [-1,1] for z in [-3,4]}
 save('sun_jackal','desert',s,j,{'leg':legs(pal,length=6)},hand=(0,14,-9))
 # Rune monolith, segmented with negative gaps, orbiting triangular sandstone tablets.
 s=p(pal)
 for y in [5,10,15]:s.box((-3,y,-2),(3,y+3.5,2),'shell');s.box((-2.6,y+.5,-2.3),(2.6,y+1,-2),'edge')
 eye(s,0,17,-2.5,.9);s.capsule((0,6,-2.5),(0,13,-2.5),.3,.3,'glow');crystal(s,(0,21,0),1.6,3,'glow')
 for a in [-1,1]:s.triangle((a*5,8,0),(a*7,12,0),(a*4,15,0),1,'bone')
 save('dune_monolith','desert',s,hand=(0,17,-3),hover=.5)
 # Glass scorpion with faceted dorsal crystals and an articulated stinger.
 s=p(pal);s.ellipsoid((0,6,0),(4,2.6,5),'shade')
 for z in [-2,1,4]:crystal(s,(0,8,z),1.4,2.4,'glow')
 for a in [-1,1]:
  eye(s,a*1.5,7,-4.5)
  for z in [-3,0,3]:s.chain([(a*3,6,z),(a*6,4,z),(a*7,1,z-1)],.55,.2,'bone')
  s.chain([(a*3,6,-3),(a*6,6,-6),(a*4,7,-8)],.9,.2,'edge')
 t=p(pal);t.chain([(0,0,0),(0,3,3),(0,8,2),(0,10,-2)],1.4,.4,'edge');crystal(t,(0,10,-3),.9,2,'glow')
 save('glass_scorpion','desert',s,{'tail':joint('tail',(0,7,4),'tail')},{'tail':t.voxels()},hand=(0,10,-4),extra={'hand_limb':'tail'})
 # Reaper: sweeping purple cloak and a curved crescent scythe, hollow face.
 pal=DARK;s=p(pal);s.ellipsoid((0,12,0),(2.6,5,2),'shade');s.ellipsoid((0,18,-.5),(3,3,2.5),'shell');s.ellipsoid((0,18,-2.5),(2,2,.8),'dark');eye(s,0,18,-3.2,.7)
 for a in [-1,1]:s.chain([(a*2,9,0),(a*4,4,1),(a*2,1,3)],1,.08,'edge')
 a=p(pal);a.chain([(0,0,0),(2,-2,0),(3,-4,-2)],.7,.6,'bone');a.capsule((3,-8,-2),(3,7,-2),.35,.35,'shade');a.chain([(3,7,-2),(0,9,-2),(-4,7,-2),(-6,4,-2)],.8,.08,'glow')
 save('umbral_reaper','dark',s,{'arm_r':joint('arm',(3,14,0),'arm',-1)},{'arm':a.voxels()},hand=(0,20,-3),hover=.25)
 # Amethyst widow: eight long articulated legs, glowing abdomen and gem eyes.
 s=p(pal);s.ellipsoid((0,9,2),(4.8,3.8,5),'shell');s.ellipsoid((0,8,-3),(3,2.5,3),'shade')
 crystal(s,(0,12,3),1.6,3,'glow')
 for x in [-1.5,0,1.5]:eye(s,x,9,-5.5,.45)
 l=p(pal);l.chain([(0,0,0),(4,2,1),(7,-2,2),(8,-6,0)],.65,.2,'edge');v=l.voxels();j={}
 for i,z in enumerate([-4,-1,2,5]):
  for a in [-1,1]:j[f'leg_{a}_{i}']=joint('leg_l' if a<0 else 'leg_r',(a*2.5,7,z),'leg',a*(-1 if i%2 else 1),axis='y',amount=.45)
 save('amethyst_widow','dark',s,j,dict(leg_l=mirror(v),leg_r=v),hand=(0,9,-6))
 # Nightbell idol: inverted bell with open dark throat, three rune chains.
 s=p(pal);s.ellipsoid((0,15,0),(4,5,3.5),'shell');s.box((-5,10,-3),(5,12,3),'edge');s.ellipsoid((0,10,-2),(3.5,1,2),'dark');s.ellipsoid((0,12,-3),(1.6,1.2,.5),'glow');ring(s,(0,20,0),2,'bone',axis='z')
 for x in [-3,0,3]:s.chain([(x,10,0),(x,6,0),(x+1,3,1)],.4,.25,'bone');crystal(s,(x+1,2,1),.7,1.6,'glow')
 save('nightbell_idol','dark',s,hand=(0,12,-4),hover=.45)

def common():
 # Woodland fox with bramble mane and bushy jointed tail.
 pal=WOOD;s=p(pal);s.ellipsoid((0,6,1),(2.3,2,4),'edge');s.ellipsoid((0,8,-3),(2,2,2),'shell');spike(s,(0,7,-4),(0,7,-6),1.1,'bone')
 for a in [-1,1]:eye(s,a,8,-4.5,.35);spike(s,(a,9,-3),(a*2,12,-2),.7,'shade')
 t=p(pal);t.chain([(0,0,0),(0,1,3),(1,2,6)],1.7,.2,'edge')
 j={f'leg_{a}_{z}':joint('leg',(a*1.4,4.5,z),phase=a*(1 if z<0 else -1)) for a in [-1,1] for z in [-2,3]};j['tail']=joint('tail',(0,6,4),'sway')
 save('bramble_fox','normal',s,j,dict(leg=legs(pal,length=3.5),tail=t.voxels()),hand=(0,7,-6))
 # Tortoise: low ridged moss shell, thick feet, mushrooms growing from its back.
 s=p(pal);s.ellipsoid((0,5,1),(4.5,3,5),'shade');s.ellipsoid((0,6,1),(4,2.5,4.5),'shell');s.ellipsoid((0,4,-4),(1.8,1.4,2),'bone')
 for a in [-1,1]:eye(s,a,4.5,-5.4,.3)
 for x,z in [(-2,1),(1,3),(0,-1)]:s.capsule((x,7,z),(x,10,z),.35,.35,'bone');s.ellipsoid((x,10,z),(1.2,.7,1.2),'glow')
 for a in [-1,1]:
  for z in [-2,4]:s.ellipsoid((a*3,1.5,z),(1.2,1.2,1.5),'edge')
 save('moss_tortoise','normal',s,hand=(0,4,-6))
 # Jungle mantis: tall leaf shoulders and two hooked animated forearms.
 s=p(pal);s.ellipsoid((0,9,1),(1.7,4,2.2),'shell');s.ellipsoid((0,14,-1),(2.7,1.5,1.6),'edge')
 for a in [-1,1]:eye(s,a*1.6,14,-2.5,.45);s.triangle((a,11,1),(a*4,15,3),(a*2,6,4),.5,'edge')
 a=p(pal);a.chain([(0,0,0),(3,1,-1),(4,-3,-3),(2,-4,-4)],.7,.12,'bone');v=a.voxels()
 save('vine_mantis','normal',s,{'arm_l':joint('arm_l',(-2,11,0),'claw',1),'arm_r':joint('arm_r',(2,11,0),'claw',-1),'leg_l':joint('leg',(-1.2,6,1)),'leg_r':joint('leg',(1.2,6,1),phase=-1)},dict(arm_l=mirror(v),arm_r=v,leg=legs(pal,length=5)),hand=(0,14,-3))
 # Shore snail: striped spiral shell, two eye stalks, broad cyan foot.
 pal=BLUE;s=p(pal);s.ellipsoid((0,2,0),(3,1.3,5),'edge');s.ellipsoid((0,5,1),(3.3,3.5,3.6),'bone')
 for r,z in [(2.5,-2.4),(1.7,-2.8),(.8,-3)]:ring(s,(0,5,z),r,'shell',axis='z')
 for a in [-1,1]:s.capsule((a,2,-4),(a*1.5,6,-5),.35,.3,'edge');eye(s,a*1.5,6,-5.3,.3)
 save('tide_snail','blue',s,hand=(0,3,-5))
 # Deep dune crawler: armored segmented worm with a flared ivory mouth.
 pal=SAND;s=p(pal)
 for i in range(5):s.ellipsoid((0,3+i*.3,i*2),(2.5-i*.2,2.4,1.7),'shell' if i%2 else 'edge')
 s.ellipsoid((0,4,-2),(2.5,2.3,2),'bone');s.ellipsoid((0,4,-3.8),(1.5,1.4,.5),'dark')
 for a in [-1,1]:eye(s,a*1.7,5,-3,.35)
 save('dune_crawler','desert',s,hand=(0,4,-4))
 # Purple cave bat, bright eyes and scalloped wings.
 pal=DARK;s=p(pal);s.ellipsoid((0,6,0),(1.5,2.3,1.4),'shade')
 for a in [-1,1]:eye(s,a*.65,7,-1.5,.3);spike(s,(a*.7,8,0),(a*1.5,10,0),.6,'edge')
 w=p(pal)
 for i in range(3):w.triangle((0,0,0),(-4-i,2-i,0),(-3-i,-2,2+i),.4,'shell')
 v=w.voxels();save('gloam_bat','dark',s,{'wing_l':joint('wing_l',(-1,6,0),'wing',1),'wing_r':joint('wing_r',(1,6,0),'wing',-1)},dict(wing_l=v,wing_r=mirror(v)),hand=(0,7,-2),hover=.7)
 # Bile bandit: purple hood, wrapped boots, belt, masked face, one real voxel torch.
 pal=DARK;s=p(pal);s.box((-2.2,6,-1.3),(2.2,12,1.3),'shell');s.box((-2.3,7,-1.5),(2.3,8,1.5),'bone');s.box((-.5,7,-1.7),(.5,8.2,-1.4),'glow')
 s.ellipsoid((0,15,0),(2.7,3,2.3),'shade');s.box((-1.9,13,-2.5),(1.9,16.5,-2),'bone');s.box((-2,12.5,-2.7),(2,14.4,-2.3),'shell')
 for a in [-1,1]:eye(s,a*.8,15.6,-2.7,.25)
 a=p(pal);a.chain([(0,0,0),(-1,-2,-1),(-1,-4,-2)],.65,.65,'shell');a.capsule((-1,-5,-2),(-1,5,-2),.3,.3,'bone')
 # Orange flames are intentionally a separate palette from the purple clothing.
 pal=dict(pal);pal['glow_fire']=(255,125,39);pal['glow_fire_hot']=(255,218,115)
 a.names=list(pal);s.names=list(pal)
 a.ellipsoid((-1,6,-2),(.9,1.8,.8),'glow_fire');spike(a,(-1,6,-2),(-.5,9,-2),.55,'glow_fire_hot')
 arm=p(pal);arm.chain([(0,0,0),(0,-3,0),(0,-5,-1)],.65,.55,'edge')
 parts={'body':s.voxels(),'arm_l':a.voxels(),'arm_r':arm.voxels(),'leg':legs(pal,length=5)}
 rig=dict(voxel_size=.035,parts={},limbs={'arm_l':joint('arm_l',(-2.7,12,0),'arm',1,throws=False),'arm_r':joint('arm_r',(2.7,12,0),'arm',-1,throws=False),'leg_l':joint('leg',(-1.2,6,0)),'leg_r':joint('leg',(1.2,6,0),phase=-1)},hand=[-3,18,-6],hand_limb='arm_l',waddle=.25)
 export(ROOT/'creatures/bile_bandit',parts,pal,rig);manifest.append(dict(id='bile_bandit',biome='dark',folder='creatures/bile_bandit',parts=list(parts),art_voxels=sum(len(v) for v in parts.values())))
 print('Exported bile_bandit',flush=True)

def main():
 gods();common()
 (ROOT/'creatures/realm_expansion_03.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print('Created',len(manifest),'production models.',flush=True)
if __name__=='__main__':main()
