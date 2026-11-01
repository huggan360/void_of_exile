#!/usr/bin/env python3
"""Arrange actual Godot renders into the desktop boss art sheet."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
ROOT=Path(__file__).resolve().parents[1]
FOLDER=Path('/home/hugo/Desktop/Voidrealm Boss Previews')
FONT='/usr/share/fonts/TTF/DejaVuSans.ttf'
BOLD='/usr/share/fonts/TTF/DejaVuSans-Bold.ttf'
def font(size,bold=False):return ImageFont.truetype(BOLD if bold else FONT,size)
entries=[
 ('blue_dragon','BLUE DRAGON','Bluelay','#43c2e8',[('enraged','Enraged')]),
 ('rimeheart_prism','RIMEHEART PRISM','Fosen','#65d6df',[('conduit','Conduit'),('tempest','Tempest')]),
 ('vharok_cinder_tyrant','VHAROK','Lava · The Cinder Tyrant','#ed7847',[('infernal','Infernal'),('heart_unbound','Heart Unbound')]),
 ('aureate_scarab_regent','SCARAB REGENT','Desert','#deb25a',[('sunwings','Sunwings'),('sunheart','Sunheart')]),
 ('hollow_crown','HOLLOW CROWN','Deep Dark','#b874d2',[('fractured_court','Fractured Court'),('unbound','Unbound')]),
]
sheet=Image.new('RGB',(3300,1460),'#0d131e');draw=ImageDraw.Draw(sheet)
draw.text((36,24),'VOIDREALM  /  BOSS ART',font=font(43,True),fill='#ecf1f6')
draw.text((36,81),'Live voxel models  ·  32-cell silhouettes enlarged to 256  ·  Default forms and phase transformations',font=font(24),fill='#97aabd')
for i,(key,title,biome,color,forms) in enumerate(entries):
 x=28+i*650
 draw.rounded_rectangle((x,139,x+638,1409),radius=18,fill='#17202d',outline='#293648',width=2)
 draw.rounded_rectangle((x+20,158,x+618,163),radius=2,fill=color)
 draw.text((x+22,180),title,font=font(31,True),fill='#ecf1f6')
 draw.text((x+22,224),biome,font=font(23),fill=color)
 image=Image.open(FOLDER/(key+'_default.png')).convert('RGB').resize((620,689),Image.Resampling.LANCZOS)
 sheet.paste(image,(x+9,264))
 draw.text((x+22,949),'DEFAULT FORM',font=font(19,True),fill='#8fa3b7')
 draw.line((x+22,990,x+615,990),fill='#354155',width=2)
 for j,(form,label) in enumerate(forms):
  offset=x+12+j*310 if len(forms)>1 else x+164
  image=Image.open(FOLDER/(key+'_'+form+'.png')).convert('RGB').resize((300,333),Image.Resampling.LANCZOS)
  sheet.paste(image,(offset,1007))
  box=draw.textbbox((0,0),label,font=font(21,True));width=box[2]-box[0]
  draw.text((offset+(300-width)/2,1352),label,font=font(21,True),fill=color)
draw.text((36,1429),'Rendered from the current game assets · 1 November 2026',font=font(17),fill='#8195aa')
output=Path('/home/hugo/Desktop/Voidrealm Boss Preview.png')
sheet.save(output)
sheet.save(ROOT/'docs/realm_expansion/pixel_boss_preview.png')
print(output)
