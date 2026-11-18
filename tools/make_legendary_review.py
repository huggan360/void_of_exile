#!/usr/bin/env python3
"""Compose actual Godot projectile renders and sampled flight paths for review.
Run tools/preview_legendary_review.tscn first. Nothing is published.
"""
from pathlib import Path
import json,math
from PIL import Image,ImageDraw,ImageFont,ImageColor
ROOT=Path(__file__).resolve().parents[1]
OUT=Path('/home/hugo/tmp/legendary_review')
ROWS=json.loads((OUT/'paths.json').read_text())
FONT=ROOT/'fonts/BreeSerif.ttf'
def font(n): return ImageFont.truetype(str(FONT),n)
BG='#0a1019'; CARD='#111925'; EDGE='#33455c'; INK='#f2e9dc'; DIM='#9faec0'; BLUE='#66b7ff'; GOLD='#e8bd79'
def wrap(draw,text,at,width,size=14,color=DIM,maxlines=4):
 words=text.split();line='';lines=[]
 for word in words:
  trial=(line+' '+word).strip()
  if draw.textlength(trial,font=font(size))>width and line:lines.append(line);line=word
  else:line=trial
 if line:lines.append(line)
 for n,line in enumerate(lines[:maxlines]):draw.text((at[0],at[1]+n*(size+4)),line,font=font(size),fill=color)
def path_panel(target,at,size,paths,color,charge=False):
 factor=3; canvas=Image.new('RGB',(size[0]*factor,size[1]*factor),'#0c1420');d=ImageDraw.Draw(canvas)
 # Fixed oblique projection for all weapons: real x/y/z paths, no invented shape.
 def project(p):
  x,y,z=p;return ((20+x*12-z*10.4)*factor,(size[1]-19+z*5.7-y*19)*factor)
 for z in [-4,-8,-12]:
  a=project([-2,0,z]);b=project([2,0,z]);d.line([a,b],fill='#1b2839',width=factor)
 rgb=ImageColor.getrgb(color);end_color=tuple(min(255,int(c*.6+90)) for c in rgb)
 for i,path in enumerate(paths):
  points=[project(p) for p in path['points']]
  tint=tuple(min(255,int(c*(.68+.32*((i%3)/2)))) for c in rgb)
  d.line(points,fill=tint,width=2*factor)
  for j in [23,45,65,80]:
   x,y=points[j];r=2*factor;d.rectangle((x-r,y-r,x+r,y+r),fill=end_color)
 x,y=project([0,0,0]);d.ellipse((x-3*factor,y-3*factor,x+3*factor,y+3*factor),fill=GOLD)
 target.paste(canvas.resize(size,Image.Resampling.LANCZOS),at)
def card(row):
 im=Image.new('RGB',(588,388),CARD);d=ImageDraw.Draw(im)
 d.rounded_rectangle((0,0,587,387),radius=9,outline=EDGE,width=1)
 d.text((16,12),row['name'],font=font(25),fill=BLUE)
 icon=Image.open(ROOT/'items/textures'/(row['id']+'.png')).convert('RGBA')
 filled=sum(p[3]>0 for p in icon.get_flattened_data())
 d.text((17,47),f"{row['kind']}  /  8x8 icon  /  {filled} pixels",font=font(13),fill=DIM)
 d.rounded_rectangle((16,75,96,155),radius=4,fill='#0a1019',outline=EDGE)
 art=icon.resize((64,64),Image.Resampling.NEAREST);im.paste(art,(24,83),art)
 projectile=Image.open(OUT/(row['id']+'.png')).convert('RGB').resize((195,135),Image.Resampling.LANCZOS)
 im.paste(projectile,(105,64))
 d.text((138,176),'PROJECTILE',font=font(11),fill=DIM)
 wrap(d,row['description'],(310,75),258,15,INK,3)
 wrap(d,row['charged_description'],(310,133),258,13,DIM,3)
 d.text((17,201),f"PRIMARY  /  {len(row['primary'])} shot{'s' if len(row['primary'])!=1 else ''}",font=font(14),fill=INK)
 d.text((306,201),row['charge_name'].upper(),font=font(14),fill=GOLD)
 path_panel(im,(16,226),(267,140),row['primary'],'#'+row['colors'][0])
 path_panel(im,(305,226),(267,140),row['charged'],'#'+row['colors'][1],True)
 return im
def sheet(rows,name):
 cols=3;width=1828;header=190;h=header+math.ceil(len(rows)/cols)*404+30
 im=Image.new('RGB',(width,h),BG);d=ImageDraw.Draw(im)
 d.text((24,20),'LEGENDARY WEAPONS  /  REVIEW',font=font(38),fill=INK)
 d.text((26,75),'Individual 8x8 icons, actual in-game projectile meshes, and sampled firing paths.',font=font(21),fill=DIM)
 d.text((26,110),'Left path: primary attack. Right path: charged attack. Gold dot: launch point. Not released.',font=font(18),fill=GOLD)
 for n,row in enumerate(rows):im.paste(card(row),(20+(n%cols)*602,header+(n//cols)*404))
 im.save(OUT/name)
 return im
ordered=[r for kind in ['Bow','Wand','Trident'] for r in ROWS if r['kind']==kind]
sheet(ordered,'legendary_weapons_all.png')
for kind,name in [('Bow','bows.png'),('Wand','wands.png'),('Trident','tridents.png')]:sheet([r for r in ordered if r['kind']==kind],name)
# Direct comparison at identical scale, with the original silhouettes untouched.
ids=['G1_bow','G4_bow','G8_bow']+[r['id'] for r in ordered if r['kind']=='Bow']
preview=Image.new('RGB',(7*180,2*180+80),BG);d=ImageDraw.Draw(preview)
d.text((18,12),'Regular bows first, then the 11 redesigned Legendary bows',font=font(22),fill=INK)
for n,id in enumerate(ids):
 icon=Image.open(ROOT/'items/textures'/(id+'.png')).convert('RGBA');art=icon.resize((96,96),Image.Resampling.NEAREST);x=n%7*180;y=60+(n//7)*180
 preview.paste(art,(x+40,y),art)
 label=id[6:].replace('_',' ').title() if id.startswith('L_') else id
 wrap(d,label,(x+8,y+108),168,15,BLUE if id.startswith('L_') else GOLD)
preview.save(OUT/'bow_comparison.png')
print('Review sheets:',OUT/'legendary_weapons_all.png')
