#!/usr/bin/env python3
"""Desktop sheet of five native prop renders at the same world scale."""
import json
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1]
OUTPUT=Path('/home/hugo/Desktop/Voidrealm Gravestone Previews')
FONT='/usr/share/fonts/TTF/DejaVuSans.ttf';BOLD='/usr/share/fonts/TTF/DejaVuSans-Bold.ttf'
def font(size,bold=False):return ImageFont.truetype(BOLD if bold else FONT,size)
def compose():
 manifest=json.loads((ROOT/'props/gravestones/manifest.json').read_text())
 image=Image.new('RGB',(3300,1110),'#0d131e');draw=ImageDraw.Draw(image)
 draw.text((36,26),'VOIDREALM  /  GRAVESTONE TIERS',font=font(43,True),fill='#edf1f6')
 draw.text((36,85),'From a humble wooden marker to a legendary monument - All five shown at the same scale',font=font(24),fill='#97aabd')
 colors=['#c69a61','#a7b7bd','#b6cccf','#d9b369','#94e0dd']
 for index,(entry,color) in enumerate(zip(manifest,colors)):
  x=28+index*650
  draw.rounded_rectangle((x,145,x+638,1048),radius=18,fill='#17202d',outline='#293648',width=2)
  draw.rounded_rectangle((x+20,163,x+618,168),radius=2,fill=color)
  draw.text((x+22,186),f"TIER {entry['tier']}  /  {entry['rank_hint'].upper()}",font=font(27,True),fill=color)
  draw.text((x+22,230),entry['name'],font=font(24),fill='#edf1f6')
  render=Image.open(OUTPUT/(entry['id']+'.png')).convert('RGB').resize((620,775),Image.Resampling.LANCZOS)
  image.paste(render,(x+9,269))
  draw.text((x+23,1003),f"Height {entry['size_m'][1]:.2f} m",font=font(20),fill=color)
 draw.text((36,1071),'Native voxel props - Editable models and source parts in props/gravestones - Not connected to character death yet',font=font(21),fill='#8195aa')
 path=Path('/home/hugo/Desktop/Voidrealm Gravestones.png')
 image.save(path);image.save(ROOT/'props/gravestones/preview.png')
 print(path)
if __name__=='__main__':compose()
