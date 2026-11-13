#!/usr/bin/env python3
"""Desktop contact sheet from actual Godot projectile model renders."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[1]
FOLDER=Path('/home/hugo/Desktop/Voidrealm Boss Projectile Previews')
MANIFEST={e['id']:e for e in json.loads((ROOT/'creatures/boss_projectiles/manifest.json').read_text())}
FONT='/usr/share/fonts/TTF/DejaVuSans.ttf';BOLD='/usr/share/fonts/TTF/DejaVuSans-Bold.ttf'
def font(size,bold=False):return ImageFont.truetype(BOLD if bold else FONT,size)
GROUPS=[
 ('BLUE DRAGON','Bluelay','#43c2e8',[('blue_orb','Azure fire orb',True),('blue_bolt','Forked azure bolt',False)]),
 ('RIMEHEART PRISM','Fosen','#65d6df',[('ice_bolt','Faceted ice shard',True),('ice_orb','Crystal comet',True)]),
 ('VHAROK','Lava - The Cinder Tyrant','#ed7847',[('fire_orb','Horned ember orb',True),('fire_cleave','Wide flame shard',True),('fire_bolt','Forked ember dart',False)]),
 ('SCARAB REGENT','Desert','#deb25a',[('gold_bolt','Winged gold needle',True),('gold_disc','Returning sun disc',True),('gold_orb','Solar orb',False)]),
 ('HOLLOW CROWN','Deep Dark','#b874d2',[('void_bolt','Twisted shadow bolt',True),('void_orb','Void eye orb',True)]),
]
sheet=Image.new('RGB',(3300,1560),'#0d131e');draw=ImageDraw.Draw(sheet)
draw.text((36,25),'VOIDREALM  /  BOSS PROJECTILES',font=font(43,True),fill='#ecf1f6')
draw.text((36,85),'All 12 authored models - Actual voxel geometry and glow - Grouped by boss',font=font(25),fill='#97aabd')
for col,(boss,biome,color,shots) in enumerate(GROUPS):
 x=28+col*650
 draw.rounded_rectangle((x,145,x+638,1460),radius=18,fill='#17202d',outline='#293648',width=2)
 draw.rounded_rectangle((x+20,163,x+618,168),radius=2,fill=color)
 draw.text((x+22,185),boss,font=font(30,True),fill='#ecf1f6')
 draw.text((x+22,229),biome,font=font(22),fill=color)
 for row,(key,label,live) in enumerate(shots):
  y=278+row*385
  image=Image.open(FOLDER/(key+'.png')).convert('RGB').resize((620,310),Image.Resampling.LANCZOS)
  sheet.paste(image,(x+9,y))
  draw.text((x+24,y+292),label,font=font(24,True),fill='#eef3f8')
  e=MANIFEST[key];dimensions=' × '.join(str(n) for n in e['size'])+' voxels'
  draw.text((x+24,y+330),dimensions,font=font(20),fill=color)
  badge='LIVE' if live else 'RESERVE ART'
  badge_font=font(16,True);box=draw.textbbox((0,0),badge,font=badge_font);width=box[2]-box[0]
  draw.rounded_rectangle((x+602-width-18,y+328,x+612,y+354),radius=6,fill='#203c3b' if live else '#353445')
  draw.text((x+602-width-4,y+332),badge,font=badge_font,fill='#8ed0b8' if live else '#b4acc6')
  if row<len(shots)-1:draw.line((x+24,y+370,x+614,y+370),fill='#303d50',width=1)
 if len(shots)==2:
  draw.text((x+24,1360),'2 projectile models',font=font(19),fill='#8195aa')
draw.text((36,1480),'LIVE = used by current boss attacks. RESERVE ART = authored model not currently fired by that boss.',font=font(22),fill='#a4b3c4')
draw.text((36,1517),'Close-ups are framed individually; dimensions show true voxel proportions. Animated rings, beams and arena hazards are separate effects.',font=font(20),fill='#8195aa')
output=Path('/home/hugo/Desktop/Voidrealm Boss Projectile Overview.png')
sheet.save(output)
sheet.save(ROOT/'tools/previews/boss_projectile_overview.png')
print(output)
