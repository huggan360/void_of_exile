#!/usr/bin/env python3
"""Compose a labeled diagram from the generator's map and exported seed plan."""
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import json
r=Path(__file__).resolve().parents[1];folder=r/'tools/previews'
plan=json.loads((folder/'seed_20261031.json').read_text())
out=Image.new('RGB',(1360,1100),'#19232e');out.paste(Image.open(folder/'map_base.png').resize((1008,1008),Image.Resampling.NEAREST),(24,65));d=ImageDraw.Draw(out)
def font(n,bold=False):return ImageFont.truetype('/usr/share/fonts/TTF/DejaVuSans'+('-Bold' if bold else '')+'.ttf',n)
def xy(x,z):return (24+(x+420)*1.2,65+(z+420)*1.2)
d.text((24,18),'VOID REALMS / SEEDED VILLAGES & STRONGHOLDS',font=font(25,True),fill='#f1e4c8')
for road in plan['roads']:d.line([xy(x,z) for x,z in road],fill='#d2bf93',width=3)
labels=[]
for town in plan['towns']:
 x,y=xy(town['x'],town['z']);rad=town['radius']*1.2;d.rectangle((x-rad,y-rad,x+rad,y+rad),fill='#826e4c',outline='#f1d9a2',width=2)
 labels.append((x-rad,y-rad-25 if town['name']=='Bramblebrook' else y+rad+5,town['name'],17))
for fort in plan['forts']:
 x,y=xy(fort['x'],fort['z']);d.rectangle((x-11,y-11,x+11,y+11),fill='#b9dce4',outline='#fff3cb',width=2);labels.append((x-60,y+17,fort['name'],15))
for x,y,label,size in labels:d.text((x,y),label,font=font(size,True),fill='#fff4cd',stroke_width=2,stroke_fill='#19232e')
x,y=xy(0,0);d.ellipse((x-5,y-5,x+5,y+5),fill='white')
d.text((1060,82),'SEED 20261031',font=font(20,True),fill='#f1e4c8')
for i,(label,c) in enumerate([('Woodland heart','#436d4c'),('Fosen','#9cbac9'),('Bluelay','#405f8b'),('Desert / deep dunes','#b78c59'),('Doom / lava','#704238'),('Deep Dark','#393548')]):
 y=140+i*44;d.rectangle((1060,y,1080,y+20),fill=c);d.text((1092,y),label,font=font(16),fill='#dee5e7')
y=440
for line in ['CENTRAL VILLAGE','12 seeded houses','Smith, lodge, market','and arrival portal','','THREE OUTPOSTS','Forest, desert, Fosen','Mandatory smith in Fosen','Magician in the desert','','FIVE STRONGHOLDS','16 x 16 raised arenas','Blue Dragon in Bluelay','','Solid cream: road network','White dot: realm arrival','','Biome directions and','house designs change','with the realm seed.']:
 d.text((1060,y),line,font=font(15,line.isupper()),fill='#cbd9df');y+=25
out.save(folder/'realm_map.png')
