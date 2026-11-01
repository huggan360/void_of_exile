#!/usr/bin/env python3
"""Five staged common enemies. Generates assets only; never registers enemies.
Run python tools/make_common_batch_01.py. Output: creatures/staging/common_batch_01/.
Uses the same VOX axis order, split glow parts and rigs as make_creatures.py.
"""
from pathlib import Path
import json,math,hashlib
from PIL import Image,ImageDraw,ImageFont
from make_creatures import write_vox,fit_frame,box,line,shade
from voxel_sculpt import Part
from preview_voxel_batch import assemble,render,ROOT,FONT,BOLD
OUT=ROOT/'creatures/staging/common_batch_01'
SPECS={}

def sculpt(palette):return Part(1,palette)
def limb(part,pivot,role='leg',phase=1,**kw):return dict(part=part,pivot=pivot,role=role,phase=phase,**kw)
def add(name,palette,parts,limbs,hand,**kw):
 # CreatureModel.hand_position uses the model root, not the hovering internal rig.
 # Include resting hover in the muzzle height; the small decorative bob remains visual.
 hand=list(hand)
 hand[1]+=kw.get('hover',0)/kw.get('voxel_size',.09)
 SPECS[name]=dict(palette=palette,parts=parts,rig=dict(voxel_size=kw.pop('voxel_size',.09),limbs=limbs,hand=hand,**kw))
def feet(pal,length=4):
 p=sculpt(pal);p.capsule((0,0,0),(0,-length+1,0),1.15,1.0,'skin');p.box((-1,-length,-2),(1,-length+1,1),'dark');return p.voxels()

# 1. Sporeback: stout fungal walker with an obvious spore nozzle beneath its cap.
P={'cap':(181,75,42),'cap_light':(213,111,52),'cap_dark':(133,49,35),'cream':(231,205,155),'gill':(163,137,95),'skin':(173,152,108),'skin_b':(156,130,88),'dark':(55,48,33),'moss':(96,127,50),'glow_spore':(179,218,86),'eye':(240,186,61)}
p=sculpt(P)
p.ellipsoid((0,7.5,0),(4.0,4.8,3.1),'skin');p.ellipsoid((0,11,0),(4.6,2.9,3.6),'skin')
p.ellipsoid((0,13.2,0),(7.7,1.3,6.4),'gill');p.ellipsoid((0,14.4,.3),(8.1,3.7,6.6),'cap')
p.ellipsoid((0,16,.7),(6.4,2.6,5.0),'cap_light')
# Raised ivory cap spots, deliberately placed on the surface, not random noise.
for c,rad in [((-4.5,16.9,-1.8),(1.6,.6,1.3)),((2.8,17.7,.6),(1.9,.55,1.5)),((.1,17.7,-2.9),(1.1,.55,1.0)),((5.9,15.7,-1.5),(1.1,.7,1.1)),((-2.2,16.8,4.2),(1.1,.6,.9))]:p.ellipsoid(c,rad,'cream')
# Gill stripes visible under the overhang.
for x in [-6,-4,-2,1,3,5]:p.box((x,12.4,-5),(x+.65,13.1,-2.6),'cream')
p.ellipsoid((0,7.6,-3.1),(2.0,1.8,1.2),'gill');p.ellipsoid((0,7.8,-4.0),(1.1,1.0,.5),'dark');p.ellipsoid((0,7.8,-4.4),(.6,.6,.3),'glow_spore')
for x in [-2.4,2.4]:
 p.box((x-.7,10,-3.5),(x+.7,11.2,-2.8),'dark');p.box((x-.35,10.3,-3.7),(x+.35,10.9,-3.4),'eye')
p.ellipsoid((-2,5.1,2.5),(2.0,2.2,1),'moss');p.ellipsoid((2,5.5,2.5),(1.5,2.1,1),'moss')
a=sculpt(P);a.chain([(0,0,0),(-.7,-2,.1),(0,-4,-.8)],1.25,.85,'skin');a.box((-1,-4.5,-1.2),(1,-3.5,.2),'gill')
add('sporeback',P,{'body':p.voxels(),'arm':a.voxels(),'leg':feet(P,4)}, {'arm_l':limb('arm',[-4,10,0],'arm',1,throws=False),'arm_r':limb('arm',[4,10,0],'arm',-1,throws=False),'leg_l':limb('leg',[-2,4,0]),'leg_r':limb('leg',[2,4,0],phase=-1)},[0,7.8,-4.9],voxel_size=.095,waddle=.55)

# 2. Thorn Hopper: a broad-faced jungle amphibian, with thorny seed pods on its back.
P={'skin':(70,123,76),'skin_b':(57,105,64),'belly':(174,181,107),'pod':(43,79,48),'thorn':(231,209,144),'dark':(27,47,34),'eye':(236,168,43),'glow_venom':(173,220,65),'web':(104,143,72)}
p=sculpt(P);p.ellipsoid((0,6.0,1.8),(5.5,3.7,6),'skin');p.ellipsoid((0,7.3,-3.6),(5.9,3.5,4),'skin');p.ellipsoid((0,5.4,-5.8),(4.7,1.9,1.9),'belly')
for x in [-3.6,3.6]:
 p.ellipsoid((x,9.5,-4.4),(2,2.2,1.9),'skin');p.ellipsoid((x,10,-5.9),(1.25,1.15,.6),'eye');p.box((x-.4,9.2,-6.6),(x+.4,10.9,-6.2),'dark')
p.box((-3,5.4,-7.6),(3,6.1,-7),'dark');p.ellipsoid((0,6.1,-7.5),(1,.65,.35),'glow_venom')
for x,z in [(-3,0),(3,0),(-3,3),(3,3),(0,4),(0,1)]:
 p.ellipsoid((x,9,z),(1.8,1.7,1.7),'pod');p.capsule((x,9.8,z),(x*1.15,12.5,z+1.2),.9,.12,'thorn')
h=sculpt(P);h.ellipsoid((1,-.7,1),(2.7,2.1,2.7),'skin');h.chain([(1,-1,1),(3,-2,3),(2,-4,-.5)],1.2,.8,'skin_b');h.box((.5,-5,-3),(4,-4,.7),'web')
f=sculpt(P);f.chain([(0,0,0),(.5,-2,-.4),(1,-3.5,-2)],.9,.7,'skin');f.box((0,-4,-3.7),(2.8,-3,-1.7),'web')
left={(-x-1,y,z):c for (x,y,z),c in h.voxels().items()};left_f={(-x-1,y,z):c for (x,y,z),c in f.voxels().items()}
add('thorn_hopper',P,{'body':p.voxels(),'hind_r':h.voxels(),'hind_l':left,'front_r':f.voxels(),'front_l':left_f},{'leg_hind_l':limb('hind_l',[-4,5,3],phase=1,amount=.5),'leg_hind_r':limb('hind_r',[4,5,3],phase=-1,amount=.5),'leg_front_l':limb('front_l',[-3,4,-4],phase=-1,amount=.65),'leg_front_r':limb('front_r',[3,4,-4],phase=1,amount=.65)},[0,6.1,-8.0],voxel_size=.09,waddle=.25)

# 3. Cinder Beetle: split charcoal wing cases, amber seams, low furnace mouth.
P={'shell':(62,53,52),'shell_b':(79,65,58),'rim':(115,79,48),'skin':(88,54,39),'dark':(29,29,31),'leg':(56,43,38),'tooth':(184,155,113),'glow_ember':(244,99,26),'glow_hot':(255,194,71)}
p=sculpt(P);p.ellipsoid((0,5,1),(5.7,3.1,7),'skin');p.ellipsoid((-2.5,7,2),(3.4,3.5,6.3),'shell');p.ellipsoid((2.5,7,2),(3.4,3.5,6.3),'shell')
p.box((-.5,7.3,-2.8),(.5,10.4,7.1),'glow_ember');p.box((-.5,9.5,.1),(.5,10.6,3),'glow_hot')
for s in [-1,1]:
 for z in [-1.5,1.5,4.5]:p.capsule((s*4.9,7,z),(s*5.3,6.2,z+.5),.45,.45,'glow_ember')
p.ellipsoid((0,5,-5.4),(3.9,2.8,2.8),'shell_b');p.box((-2,4.3,-8),(2,5.8,-7.4),'dark');p.box((-1,4.8,-8.2),(1,5.4,-7.9),'glow_hot')
for s in [-1,1]:
 p.box((s*2.3-.55,6,-7.2),(s*2.3+.55,7,-6.6),'glow_ember')
 p.chain([(s*2.7,4,-7),(s*3.2,3.8,-9),(s*1.8,4,-9.2)],.65,.35,'tooth')
 p.chain([(s*2.4,7,-6),(s*3.2,9,-7),(s*4.5,9,-7)],.4,.3,'dark')
leg=sculpt(P);leg.chain([(0,0,0),(3,-.7,1),(4.6,-3.5,.8),(5,-4,-.4)],.85,.4,'leg');leg.ellipsoid((3,-.7,1),(1,1,1),'rim');vl=leg.voxels();vl_l={(-x-1,y,z):c for (x,y,z),c in vl.items()}
limbs={}
for i,z in enumerate([-3,1,5]):
 for s in [-1,1]:limbs[f'leg_{"l" if s<0 else "r"}{i}']=limb('leg_l' if s<0 else 'leg_r',[s*4.5,4,z],phase=(1 if (i+(s>0))%2==0 else -1),axis='y',amount=.4,yaw=(-18+i*18)*(-s))
add('cinder_beetle',P,{'body':p.voxels(),'leg_l':vl_l,'leg_r':vl},limbs,[0,5.1,-8.7],voxel_size=.09,waddle=.12)

# 4. Frost Moth: pale fur collar, blue ocelli, four scalloped wing lobes.
P={'fur':(218,224,217),'fur_shadow':(163,187,191),'dark':(45,65,88),'skin':(109,146,171),'wing':(100,160,185),'wing_light':(154,210,223),'wing_edge':(66,106,141),'spot':(46,82,123),'glow_ice':(153,231,246),'eye':(255,221,128)}
p=sculpt(P);p.ellipsoid((0,7,0),(1.9,4.0,2.3),'fur_shadow');p.ellipsoid((0,9,-1),(2.7,2.9,2.6),'fur');p.ellipsoid((0,11,-2.4),(2.4,2.1,2.2),'fur')
for s in [-1,1]:
 p.ellipsoid((s*1.6,11.6,-4),(1,1,.6),'dark');p.ellipsoid((s*1.6,11.7,-4.4),(.6,.6,.35),'eye')
 p.chain([(s*.8,12.4,-2.5),(s*1.6,14.7,-3.5),(s*3.6,15.5,-3.4)],.4,.2,'fur_shadow');p.capsule((s*2.2,15,-3.5),(s*3.6,15.5,-3.4),.55,.3,'fur')
 for yy in [5,7,9]:p.chain([(s,yy,-1.5),(s*2.6,yy-.6,-3),(s*2,yy-1.4,-3.5)],.3,.2,'dark')
p.ellipsoid((0,10,-4.3),(.65,.6,.45),'glow_ice')
w=sculpt(P)
# Wings lie in XY so existing wing role bends them about Z.
w.ellipsoid((5,3,.3),(5.8,4.5,.8),'wing_edge');w.ellipsoid((5,3,.0),(5,3.8,.8),'wing_light');w.ellipsoid((4,-2.6,.6),(4.6,3.9,.9),'wing_edge');w.ellipsoid((4,-2.6,.2),(3.8,3.2,.8),'wing')
w.chain([(0,0,-.8),(4,2.5,-.8),(8,5,-.6)],.45,.25,'fur_shadow');w.chain([(0,0,-.8),(3,-2,-.8),(6,-4,-.6)],.45,.25,'fur_shadow')
for x,y,rx,ry in [(6,3.3,1.9,2.0),(4.8,-2.7,1.5,1.6)]:
 w.ellipsoid((x,y,-.9),(rx,ry,.4),'spot');w.ellipsoid((x,y,-1.2),(rx*.6,ry*.6,.3),'glow_ice');w.ellipsoid((x,y,-1.4),(.5,.7,.2),'fur')
vr=w.voxels();vl={(-x-1,y,z):c for (x,y,z),c in vr.items()}
add('frost_moth',P,{'body':p.voxels(),'wing_r':vr,'wing_l':vl},{'wing_l':limb('wing_l',[-1.4,8,0],'wing',1),'wing_r':limb('wing_r',[1.4,8,0],'wing',-1)},[0,10,-4.9],voxel_size=.075,hover=.42,bob=.08,waddle=0,flap_rate=5)

# 5. Ruin Watcher: small hovering stone eye, chipped masonry and orbitless brackets.
P={'stone':(104,119,132),'stone_b':(87,99,113),'light':(146,156,161),'dark':(34,46,63),'trim':(66,88,108),'glow_rune':(79,195,216),'glow_eye':(190,242,240),'iris':(38,117,149)}
p=sculpt(P)
p.box((-4,3,-2),(4,11,3),'stone');p.box((-3,2,-1),(3,3,2),'stone_b');p.box((-3,11,-1),(3,12,2),'light')
p.box((-3,5,-3),(3,10,-2),'trim');p.box((-2,6,-4),(2,9,-3),'dark');p.box((-1,6.6,-4.4),(1,8.6,-3.8),'iris');p.box((-.5,6.8,-4.8),(.5,8.4,-4.3),'glow_eye')
# Uneven broken top and etched stone corners distinguish it from a boss crown.
p.box((-4,10,0),(-2,12,3),'stone_b');p.box((2,9,0),(4,11,3),'light')
p.box((-4,9,-2.5),(-2,10,-2),'glow_rune');p.box((2,4,-2.5),(4,5,-2),'glow_rune')
p.box((-4,6,1),(-3,7,3),'dark');p.box((-3,5,2),(0,6,3.5),'dark');p.box((0,4,2),(1,6,3.5),'dark')
p.box((-.5,2,-1),(.5,3,1),'glow_rune')
a=sculpt(P);a.box((-1,-2,-1),(1,2,1),'stone_b');a.box((-1,1,-1),(1,2,2),'light');a.box((-.6,-1.2,-1.5),(.6,.6,-1),'glow_rune')
add('ruin_watcher',P,{'body':p.voxels(),'bracket':a.voxels()},{'bracket_l':limb('bracket',[-5.5,7,0],'sway',1),'bracket_r':limb('bracket',[5.5,7,0],'sway',-1)},[0,7.5,-5.2],voxel_size=.095,hover=.35,bob=.07,waddle=0)

# Editable projectile concepts. Gameplay currently builds procedural pellet/bolt/orb
# meshes; these are art references and are intentionally not plugged into that path.
def projectile(name,pal):
 p=sculpt(pal)
 if name=='sporeback':
  p.ellipsoid((0,0,0),(1.8,1.7,1.7),'moss');p.ellipsoid((-.4,.5,-.8),(1.1,1.0,1),'glow_spore');p.ellipsoid((.7,-.3,.6),(.8,.7,.7),'gill')
 elif name=='thorn_hopper':
  p.capsule((0,0,2.8),(0,0,-3.4),1.2,.1,'thorn');p.ellipsoid((0,0,.7),(1.25,1.25,1.7),'pod');p.box((-.5,-.5,-1),(.5,.5,2),'glow_venom')
  for s in [-1,1]:p.capsule((0,0,1),(s*2,0,2.5),.6,.1,'thorn')
 elif name=='cinder_beetle':
  p.ellipsoid((0,0,0),(1.6,1.5,2.3),'glow_ember');p.ellipsoid((0,0,-.9),(1.1,1.1,1.4),'glow_hot');p.capsule((0,0,1),(0,0,4),1,.15,'rim')
 elif name=='frost_moth':
  p.capsule((0,0,2),(0,0,-3.6),1.1,.05,'glow_ice');p.capsule((0,0,.4),(-1.3,0,1.8),.7,.1,'wing_light');p.capsule((0,0,.4),(1.3,0,1.8),.7,.1,'fur')
 elif name=='ruin_watcher':
  p.ellipsoid((0,0,0),(1.8,1.8,1.8),'iris');p.box((-.5,-1.6,-1.6),(.5,1.6,-1),'glow_eye');p.box((-1.5,-.5,-1.6),(1.5,.5,-1),'glow_rune')
 return p.voxels()

PLANS={
'sporeback':dict(name='Sporeback',biome='Woods',role='Slow fungal skirmisher',hp=110,defense=2,xp=16,behavior='skirmish',move_speed=2.8,keep_distance=6.0,body_height=1.8,hit_radius=.65,attack=dict(style='pellet',pattern='spread',count=3,spread_deg=13,damage_min=10,damage_max=15,speed=8.5,range=9.5,size=.8,cooldown=2.1,windup=.6,root=True,recover=.35,from_hand=True,color=[.70,.85,.34]),telegraph='Stops walking and leans back; the green nozzle under the cap is the launch point.',counterplay='Wide gaps between the slow spores. Sidestep after the pause.',projectile='Spore clump; no poison cloud or damage-over-time assumed.'),
 'thorn_hopper':dict(name='Thorn Hopper',biome='Jungle',role='Darting seed spitter',hp=140,defense=3,xp=24,behavior='dart',move_speed=4.2,keep_distance=6.5,body_height=1.25,hit_radius=.8,attack=dict(style='bolt',pattern='burst',count=2,interval=.22,damage_min=12,damage_max=18,speed=12,range=10.5,size=.8,cooldown=2.3,windup=.5,root=True,recover=.3,from_hand=True,color=[.68,.86,.25]),telegraph='The throat nozzle and thorn pods advertise the seed attack; pauses before the two aimed shots.',counterplay='Keep moving through the second shot; each burst shot re-aims.',projectile='Barbed seed dart. Uses ordinary hit damage; no new poison system.'),
 'cinder_beetle':dict(name='Cinder Beetle',biome='Doom',role='Low armored ember shooter',hp=180,defense=8,xp=32,behavior='skirmish',move_speed=2.7,keep_distance=6.0,body_height=1.0,hit_radius=.8,attack=dict(style='fireball',pattern='aimed',count=1,damage_min=17,damage_max=23,speed=8,range=10,size=.65,cooldown=2.2,windup=.65,root=True,recover=.4,from_hand=True,color=[.96,.39,.10]),telegraph='Furnace mouth and hot wing-case seam indicate fire. Stops before firing a small ember.',counterplay='One slow straight shot; use rocks or sidestep. No boss ring or persistent fire field.',projectile='Small ember; intended to use the existing procedural voxel-fire style.'),
 'frost_moth':dict(name='Frost Moth',biome='Fosen',role='Fragile flying shard skirmisher',hp=95,defense=1,xp=20,behavior='strafe',move_speed=3.7,keep_distance=7.0,body_height=1.65,hit_radius=.45,attack=dict(style='bolt',pattern='spread',count=2,spread_deg=16,damage_min=11,damage_max=16,speed=10,range=10.5,size=.75,cooldown=1.9,windup=.5,root=True,recover=.2,from_hand=True,anim='flap',color=[.60,.91,.96]),telegraph='Wing ocelli and mouth are ice blue; wings beat during the attack using the existing flap animation.',counterplay='Two separated straight shards; the wing tips are visual and not part of the body hitbox.',projectile='Forked ice chip. No freeze or slow debuff required.'),
 'ruin_watcher':dict(name='Ruin Watcher',biome='Bluelay ruins',role='Small floating stone sentry',hp=135,defense=6,xp=26,behavior='stationary',move_speed=0,keep_distance=7.0,body_height=1.6,hit_radius=.6,attack=dict(style='orb',pattern='aimed',count=1,damage_min=14,damage_max=20,speed=8.5,range=11,size=.65,cooldown=2.4,windup=.7,root=True,recover=.4,from_hand=True,magic=True,color=[.31,.76,.85]),telegraph='The single recessed cyan eye is the projectile origin; long visible attack pause.',counterplay='Slow stationary target, single orb, no teleport, summons, shield, or boss phases.',projectile='Small rune orb with the existing magic halo; no impact ripple.')}

def export(folder,parts,pal,rig):
 folder.mkdir(parents=True,exist_ok=True);rig=dict(rig,parts={})
 for part,v in parts.items():
  fmin,fsize=fit_frame(v);assert max(fsize)<=256
  # One voxel of fixed empty padding protects silhouette edits from frame movement.
  fmin=tuple(n-1 for n in fmin);fsize=tuple(n+2 for n in fsize)
  base={k:c for k,c in v.items() if not c.startswith('glow')};glow={k:c for k,c in v.items() if c.startswith('glow')}
  info={'frame_min':list(fmin)}
  if base:write_vox(str(folder/(part+'.vox')),base,pal,fmin,fsize)
  else:info['solid']=False
  if glow:write_vox(str(folder/(part+'_glow.vox')),glow,pal,fmin,fsize);info['glow']=True
  rig['parts'][part]=info
 (folder/'rig.json').write_text(json.dumps(rig,indent=2)+'\n')
 # A single-file rest pose for opening directly in Goxel/MagicaVoxel.
 full=dict(parts['body'])
 for spec in rig['limbs'].values():
  angle=math.radians(spec.get('yaw',0));ca,sa=math.cos(angle),math.sin(angle);pivot=spec['pivot']
  for (x,y,z),c in parts[spec['part']].items():full[(round(ca*x+sa*z+pivot[0]),round(y+pivot[1]),round(-sa*x+ca*z+pivot[2]))]=c
 fmin,fsize=fit_frame(full);write_vox(str(folder/'model.vox'),full,pal,fmin,fsize)
 return rig,full

def main():
 OUT.mkdir(parents=True,exist_ok=True);manifest=[];cards=[]
 for name,spec in SPECS.items():
  folder=OUT/name;rig,full=export(folder,spec['parts'],spec['palette'],spec['rig'])
  v=projectile(name,spec['palette']);prig,_=export(folder/'projectile',{'body':v},spec['palette'],{'voxel_size':.07,'limbs':{},'hand':[0,0,0],'waddle':0})
  plan=PLANS[name];plan=dict(plan,status='ART_STAGING_ONLY',model=f'staging/common_batch_01/{name}',model_scale=1.0,spawn_anim='pop',suggested_pack_size=[2,4],notes='Suggested tuning only. Not an EnemyDef or spawn registration; gameplay unchanged. Projectile VOX is a visual concept; runtime uses procedural meshes.')
  (folder/'design.json').write_text(json.dumps(plan,indent=2)+'\n');(folder/'palette.json').write_text(json.dumps(spec['palette'],indent=2)+'\n')
  assembled,_=assemble(folder);front=render(assembled,440,360,yaw=32);back=render(assembled,220,205,yaw=215)
  projectile_v,_=assemble(folder/'projectile');shot=render(projectile_v,200,180,yaw=30)
  front.save(folder/'preview.png');back.save(folder/'preview_back.png')
  # Front ortho has a useful independent check for eyes, muzzles and limb symmetry.
  render(assembled,360,340,yaw=0).save(folder/'preview_front.png')
  card=Image.new('RGB',(480,750),'#202832');d=ImageDraw.Draw(card)
  d.text((24,18),plan['name'],font=ImageFont.truetype(BOLD,27),fill='#f1eee5');d.text((24,58),plan['biome']+' / Common enemy',font=ImageFont.truetype(FONT,15),fill='#98b4c5')
  card.paste(front,(20,91));card.paste(back,(10,449));card.paste(shot,(252,460));d.text((24,658),'BACK',font=ImageFont.truetype(BOLD,12),fill='#98b4c5');d.text((269,658),'PROJECTILE CONCEPT',font=ImageFont.truetype(BOLD,12),fill='#98b4c5')
  a=plan['attack'];d.text((24,693),a['pattern'].upper()+f" / {a['count']} shot"+('s' if a['count']>1 else '')+f" / {a['style']}",font=ImageFont.truetype(FONT,14),fill='#f1eee5');cards.append(card)
  manifest.append({'id':name,'display_name':plan['name'],'folder':str(folder.relative_to(ROOT)),'body_voxels':len(spec['parts']['body']),'rest_pose_voxels':len(full),'voxel_size':rig['voxel_size'],'parts':list(rig['parts']),'rig_limbs':len(rig['limbs']),'projectile_style':a['style'],'status':'art_staging_only'})
 sheet=Image.new('RGB',(5*480+4*6,750),'#10161e')
 for j,card in enumerate(cards):sheet.paste(card,(j*486,0))
 sheet.save(OUT/'lineup.png');(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print('Exported 5 common enemies and 5 projectile concepts with rigs, combined VOX models, palettes and geometry previews.')
if __name__=='__main__':main()
