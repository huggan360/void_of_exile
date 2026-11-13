#!/usr/bin/env python3
"""Preserve scripted boss shot expressions and extract static preview parameters."""
import json,re
from pathlib import Path
p=Path('/home/hugo/tmp/void_wiki/catalog.json'); c=json.loads(p.read_text())
def args(s,start):
 depth=1;quote='';parts=[];beg=start
 for i in range(start,len(s)):
  x=s[i]
  if quote:
   if x==quote and s[i-1]!='\\':quote=''
  elif x in '\"\'':quote=x
  elif x in '([{':depth+=1
  elif x in ')]}':
   depth-=1
   if depth==0:parts.append(s[beg:i].strip());return parts,i
  elif x==',' and depth==1:parts.append(s[beg:i].strip());beg=i+1
 return [],start
for e in c['enemies']:
 src=e.get('actor_source','');e['review_attacks']=[]
 for m in re.finditer(r'Boss\.shot\(',src):
  a,end=args(src,m.end())
  if len(a)<6 or not a[0].startswith('"'):continue
  row={'style':a[0].strip('"'),'source_expression':src[m.start():end+1],'source_line':src[:m.start()].count('\n')+1}
  for key,i in [('speed',3),('radius',4),('range',5)]:
   try:row[key]=float(a[i])
   except ValueError:row[key+'_expression']=a[i]
  dmg=re.match(r'Vector2i\((\d+),\s*(\d+)\)',a[2])
  if dmg:row.update(damage_min=int(dmg[1]),damage_max=int(dmg[2]))
  else:row['damage_expression']=a[2]
  row['color']=e.get('actor_constants',{}).get(a[1],{'type':'Color','hex':'85bceaff'})
  extra=a[6] if len(a)>6 else ''
  for key in ['voxel_model']:
   v=re.search(key+r'\s*=\s*"([^"]+)"',extra)
   if v:row[key]=v[1]
  for key in ['authored_projectile','pixel_projectile','magic']:
   if re.search(key+r'\s*=\s*true',extra):row[key]=True
  size=re.search(r'size\s*=\s*([\d.]+)',extra)
  if size:row['size']=float(size[1])
  e['review_attacks'].append(row)
 # Reach bosses: PlanetBosses.shot(model, style, color, damage, speed, range, size, extras).
 for m in re.finditer(r'PlanetBosses\.shot\(',src):
  a,end=args(src,m.end())
  if len(a)<6 or not a[0].startswith('"'):continue
  row={'style':a[1].strip('"'),'source_expression':src[m.start():end+1],'source_line':src[:m.start()].count('\n')+1,
   'voxel_model':'boss_projectiles/'+a[0].strip('"'),'authored_projectile':True,'pixel_projectile':True}
  for key,i in [('speed',4),('range',5)]:
   try:row[key]=float(a[i])
   except ValueError:row[key+'_expression']=a[i]
  try:row['size']=float(a[6]) if len(a)>6 else 1.0
  except ValueError:row['size']=1.0
  row['radius']=0.18*row['size']
  dmg=re.match(r'Vector2i\((\d+),\s*(\d+)\)',a[3])
  if dmg:row.update(damage_min=int(dmg[1]),damage_max=int(dmg[2]))
  else:row['damage_expression']=a[3]
  col=re.match(r'Color\("([0-9a-fA-F]+)"\)',a[2])
  row['color']={'type':'Color','hex':col[1]+'ff'} if col else e.get('actor_constants',{}).get(a[2],{'type':'Color','hex':'85bceaff'})
  extra=a[7] if len(a)>7 else ''
  if re.search(r'magic\s*=\s*true',extra):row['magic']=True
  effects=re.findall(r'id\s*=\s*"(\w+)"',extra)
  if effects:row['effects']=[{'id':x} for x in effects]
  if row['source_expression'] not in [r.get('source_expression') for r in e['review_attacks']]:e['review_attacks'].append(row)
 # Blue Dragon's helper calls have concrete per-pattern values.
 for m in re.finditer(r'_flame\(',src):
  a,end=args(src,m.end())
  if len(a)<3 or 'Vector2i(' not in a[2]:continue
  row={'style':'fireball','source_expression':src[m.start():end+1],'source_line':src[:m.start()].count('\n')+1,'color':e['actor_constants']['AZURE'],'range':24}
  dmg=re.match(r'Vector2i\((\d+),\s*(\d+)\)',a[2])
  if dmg:row.update(damage_min=int(dmg[1]),damage_max=int(dmg[2]))
  for key,i in [('size',0),('speed',1)]:
   try:row[key]=float(a[i])
   except ValueError:row[key+'_expression']=a[i]
  e['review_attacks'].append(row)
p.write_text(json.dumps(c,indent=2))
print('Boss shot definitions:',sum(len(e['review_attacks']) for e in c['enemies']))
