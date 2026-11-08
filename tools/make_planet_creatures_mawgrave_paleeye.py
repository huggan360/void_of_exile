#!/usr/bin/env python3
"""Create-only Mawgrave and The Pale Eye cast. Run from the repository root.

Uses the Theory generator pipeline: shared VOX geometry/writer, extracted court
rig helper, local limb pivots, split glow, and x8 editable god exports.
"""
import ast
import json
import math
import sys
from pathlib import Path

sys.dont_write_bytecode = True
import redesign_pixel_bosses as a
from make_theory_creatures import assemble, read_vox

R = Path(__file__).resolve().parents[1]
MANIFEST = R / 'creatures/planet_creatures_mawgrave_paleeye_manifest.json'
SHOTS = ('spore_bomb', 'storm_bolt')
a.PAL['mawgrave'] = dict(base=(100,45,135), light=(173,94,188), shade=(51,24,74),
    dark=(16,12,24), belly=(201,151,190), bone=(219,197,208), wing=(143,67,166),
    accent=(212,67,161), glow_eye=(179,255,65), glow_core=(255,78,191))
a.PAL['paleeye'] = dict(base=(39,43,61), light=(108,123,149), shade=(23,25,38),
    dark=(9,11,19), belly=(68,79,102), bone=(187,213,230), wing=(81,98,126),
    accent=(112,167,201), glow_eye=(255,55,79), glow_core=(157,231,255))

source = ast.parse((R / 'tools/make_court_creatures.py').read_text())
for node in source.body:
    if isinstance(node, ast.FunctionDef) and node.name in ('small', 'boss'):
        exec(compile(ast.Module(body=[node], type_ignores=[]), 'court_rig_helpers', 'exec'))
source = ast.parse((R / 'tools/redesign_pixel_bosses.py').read_text())
node = next(n for n in source.body if isinstance(n, ast.FunctionDef) and n.name == 'save')
tables = [n for n in ast.walk(node) if isinstance(n, ast.Dict)
          and any(isinstance(k, ast.Constant) and k.value == 'blue' for k in n.keys)]
assert len(tables) == 1
for key, label in [('mawgrave', 'Mawgrave'), ('paleeye', 'The Pale Eye')]:
    tables[0].keys.append(ast.Constant(key))
    tables[0].values.append(ast.Constant(label))
exec(compile(ast.fix_missing_locations(ast.Module(body=[node], type_ignores=[])),
             'planet_boss_writer', 'exec'), a.__dict__)


def attach(parts, limbs, name, voxels, pivot, role, phase=1, **extra):
    parts[name] = voxels
    limbs[name] = a.limb(name, pivot, role, phase, throws=False, **extra)
    limbs[name]['pivot'] = list(pivot)


def face(v, y=0, z=-3, wide=2):
    for x in (-wide, wide):
        a.box(v, (x-1,y,z), (x+1,y+2,z+1), 'dark')
        v[x,y+1,z-1] = 'glow_eye'
    a.line(v, (-1,y-1,z), (1,y-1,z), 'dark')


def mushroom(v, center, radius, glow=False):
    x,y,z = center
    a.ell(v, (x,y-1,z), (radius,1,radius), 'belly')
    a.ell(v, (x,y,z), (radius,2,radius), 'wing')
    for dx,dz in [(-2,0),(1,-2),(1,1)]:
        if abs(dx)<radius and abs(dz)<radius:
            a.box(v, (x+dx,y+1,z+dz), (x+dx+1,y+2,z+dz+1),
                  'glow_core' if glow else 'accent')


def drone():
    b,p,l = {},{},{}
    a.ell(b, (0,5,1), (3,3,4), 'glow_core')
    a.ell(b, (0,7,1), (3,1.5,4), 'wing')
    a.line(b, (0,8,-1), (0,8,3), 'glow_eye')
    h = {}; a.ell(h, (0,0,0), (3,2,2), 'base'); face(h,0,-2,1)
    attach(p,l,'head',h,(0,6,-3),'sway')
    for s,side in [(-1,'l'),(1,'r')]:
        w = {}; a.ell(w,(s*4,1,1),(5,1,3),'glow_eye')
        a.line(w,(0,0,0),(s*7,1,1),'wing')
        attach(p,l,'wing_'+side,w,(s*2,7,0),'wing',s)
        arm = {}; a.line(arm,(0,0,0),(s,-2,-1),'base')
        attach(p,l,'arm_'+side,arm,(s*2,4,-2),'arm',s)
    return b,p,l


def tender():
    b,p,l = {},{},{}
    a.ell(b,(0,8,1),(5,4,5),'base'); mushroom(b,(0,11,1),6)
    h={}; a.ell(h,(0,0,0),(3,3,3),'belly'); face(h,0,-3)
    attach(p,l,'head',h,(0,9,-4),'head')
    for s,side in [(-1,'l'),(1,'r')]:
        for i,z in enumerate((-2,4)):
            v={}; a.line(v,(0,0,0),(s*2,-2,0),'shade',2)
            a.line(v,(s*2,-2,0),(s*3,-5,-1),'base',2)
            attach(p,l,f'leg_{side}_{i}',v,(s*3,5,z),'leg',s*(-1)**i)
        v={}; a.line(v,(0,0,0),(s,-3,-3),'base',2)
        a.line(v,(s,-3,-3),(-s*2,-3,-5),'belly',2)
        if s==1:
            a.ell(v,(-3,-2,-5),(3,2,2),'shade')
            for x in (-5,-3,-1): a.ell(v,(x,0,-5),(1.5,2,1.5),'glow_eye')
            a.ell(v,(-3,1,-5),(1.5,2,1.5),'glow_core')
        attach(p,l,'arm_'+side,v,(s*4,9,-2),'arm',s)
    return b,p,l


def brute():
    b,p,l={},{},{}
    a.ell(b,(0,14,0),(7,8,5),'base')
    for s in (-1,1):
        for y in (11,16,20): mushroom(b,(s*5,y,2),4,True)
    for x,y in [(-3,13),(2,17),(0,11)]: a.ell(b,(x,y,-5),(2,2,1),'glow_eye')
    h={}; a.ell(h,(0,0,0),(4,4,3),'belly'); mushroom(h,(0,4,0),8,True); face(h,0,-3)
    attach(p,l,'head',h,(0,23,-1),'head')
    for s,side in [(-1,'l'),(1,'r')]:
        v={}; a.box(v,(-2,-6,-2),(2,1,2),'shade'); a.box(v,(-2,-6,-4),(3,-4,2),'base')
        attach(p,l,'leg_'+side,v,(s*3,6,0),'leg',s)
        v={}; a.ell(v,(s,-4,0),(3,6,3),'base'); mushroom(v,(s,0,0),4)
        a.ell(v,(s,-7,-2),(2,2,2),'glow_core')
        attach(p,l,'arm_'+side,v,(s*8,19,0),'arm',s)
    return b,p,l


def mother():
    b,p,l={},{},{}
    a.ell(b,(0,5,2),(12,5,11),'shade')
    a.ell(b,(0,13,1),(7,10,6),'base')
    for s in (-1,1):
        for z in (-5,1,7):
            a.ell(b,(s*8,6,z),(3,4,3),'glow_core')
            a.line(b,(s*8-1,4,z-3),(s*8-1,8,z-3),'glow_eye')
        mushroom(b,(s*6,16,3),5,True)
    for y in (10,14,18):
        a.ell(b,(0,y,-5),(3,2,1),'dark')
        a.ell(b,(0,y,-6),(2,1,1),'glow_eye')
    h={}; a.ell(h,(0,0,0),(4,4,3),'belly'); face(h,0,-3)
    mushroom(h,(0,4,1),7,True)
    for x in (-5,-2,2,5):
        a.line(h,(x,4,0),(x,8-abs(x)//3,0),'accent')
        a.ell(h,(x,8-abs(x)//3,0),(1,1,1),'glow_eye')
    attach(p,l,'head',h,(0,23,-2),'head')
    jaw={}; a.ell(jaw,(0,-1,-1),(3,1,2),'base')
    attach(p,l,'jaw',jaw,(0,-2,-2),'jaw',parent_limb='head')
    for s,side in [(-1,'l'),(1,'r')]:
        for i in range(3):
            v={}; a.line(v,(0,0,0),(s*3,-2,-1),'wing',2)
            a.line(v,(s*3,-2,-1),(s*2,-4,-3),'belly',2)
            v[s*2,-4,-4]='glow_eye'
            attach(p,l,f'arm_{side}_{i}',v,(s*6,19-i*4,-2),'arm',s)
    return b,p,l


def shard():
    b,p,l={},{},{}
    a.diamond(b,(0,7,0),4,7,'base')
    for y,x in [(2,0),(4,-1),(6,1),(8,0),(10,1),(12,0)]:
        a.line(b,(x,y,-2),(x,y+1,-2),'glow_core',2)
    face(b,8,-3,1)
    for s,side in [(-1,'l'),(1,'r')]:
        v={}; a.diamond(v,(s*2,0,0),2,3,'base')
        a.line(v,(0,0,0),(s*3,2,0),'glow_core')
        attach(p,l,'spark_'+side,v,(s*5,6,0),'wing',s)
    return b,p,l


def knight(god=False):
    b,p,l={},{},{}
    a.box(b,(-5,9,-3),(5,21,4),'shade')
    a.polygon(b,[(-6,21),(6,21),(4,11),(0,9),(-4,11)],-4,-2,'base')
    for y in (12,16,20): a.line(b,(-4,y,-4),(4,y,-4),'light')
    a.ell(b,(0,16,-5),(3 if god else 1,4 if god else 2,1),'glow_core')
    h={}; a.box(h,(-3,-2,-2),(3,4,3),'base')
    a.box(h,(-3,0,-3),(3,2,-2),'glow_eye'); a.box(h,(-1,-2,-4),(1,0,-2),'light')
    if god:
        for x in (-5,-3,0,3,5):
            a.line(h,(x,2,0),(x,6-abs(x)//3,0),'light')
            h[x,6-abs(x)//3,-1]='glow_eye'
        # An eye-shaped corona, visible from the front and high camera.
        for s in (-1,1):
            a.line(h,(-6,3,2),(0,3+s*3,2),'glow_core')
            a.line(h,(0,3+s*3,2),(6,3,2),'glow_core')
    else: a.polygon(h,[(-2,4),(0,7),(2,4)],0,2,'light')
    attach(p,l,'head',h,(0,24,0),'head')
    for s,side in [(-1,'l'),(1,'r')]:
        v={}; a.box(v,(-2,-9,-2),(2,0,2),'base'); a.box(v,(-2,-9,-4),(2,-7,2),'light')
        a.box(v,(-2,-5,-3),(2,-3,-2),'glow_core' if god else 'belly')
        attach(p,l,'leg_'+side,v,(s*3,9,0),'leg',s)
        v={}; a.ell(v,(0,0,0),(4,3,4),'light'); a.box(v,(-2,-9,-2),(2,0,2),'base')
        if god:
            for y in (-7,-3,1): a.line(v,(-2,y,-3),(2,y+1,-3),'glow_core')
            a.ell(v,(0,-9,-1),(3,3,3),'glow_core')
            a.line(v,(s*2,-6,0),(s*5,-3,0),'glow_core')
            a.line(v,(s*5,-3,0),(s*4,1,0),'glow_core')
        elif s==1:
            a.box(v,(-1,-8,-5),(1,-5,-3),'bone')
            a.box(v,(-3,-5,-5),(3,-4,-3),'light')
            a.polygon(v,[(-1,-4),(-1,7),(1,10),(2,6),(2,-4)],-5,-3,'base')
            a.line(v,(2,-3,-5),(2,7,-5),'glow_core')
        else:
            a.polygon(v,[(-3,-2),(3,-2),(3,-7),(0,-10),(-3,-7)],-4,-2,'shade')
            a.line(v,(0,-3,-5),(0,-8,-5),'glow_core')
        attach(p,l,'arm_'+side,v,(s*7,20,0),'arm',s)
    return b,p,l


def watcher():
    b,p,l={},{},{}
    a.ell(b,(0,10,0),(7,5,4),'base')
    a.ell(b,(0,10,-3),(6,4,2),'glow_core')
    h={}; a.ell(h,(0,0,0),(3,3,1),'glow_eye')
    a.box(h,(-1,-2,-1),(1,3,0),'dark'); h[-1,2,-2]='bone'
    attach(p,l,'iris',h,(0,10,-5),'sway')
    for i in range(6):
        theta=math.tau*i/6
        dx,dy=round(math.cos(theta)*5),round(math.sin(theta)*4)
        v={}; a.polygon(v,[(0,0),(dx,dy),(dx+(-1 if dx<0 else 1),dy+2),(0,2)],0,2,'light')
        a.line(v,(0,0,-1),(dx,dy,-1),'glow_core')
        attach(p,l,'petal_'+str(i),v,(round(math.cos(theta)*6),10+round(math.sin(theta)*4),0),
               'wing',1 if dx>=0 else -1)
    return b,p,l


DEFINITIONS = [
    ('spore_drone','Spore Drone','mawgrave','Mawgrave',.8,'orbit',True,.25,drone),
    ('hive_tender','Hive Tender','mawgrave','Mawgrave',1.4,'skirmish',False,0,tender),
    ('fungal_brute','Fungal Brute','mawgrave','Mawgrave',2.8,'chase',False,0,brute),
    ('hive_mother','The Hive Mother','mawgrave','Mawgrave',4.5,'stationary',True,0,mother),
    ('storm_shard','Storm Shard','paleeye','The Pale Eye',1.,'dart',True,.3,shard),
    ('obsidian_knight','Obsidian Knight','paleeye','The Pale Eye',2.2,'chase',False,0,knight),
    ('eye_watcher','Eye Watcher','paleeye','The Pale Eye',1.8,'stationary',True,.3,watcher),
    ('storm_warden','The Storm Warden','paleeye','The Pale Eye',4.5,'strafe',True,0,lambda:knight(True)),
]


def validate(folder):
    rig=json.loads((folder/'rig.json').read_text())
    assert 'body' in rig['parts'] and rig['limbs']
    for name,info in rig['parts'].items():
        assert info.get('solid',True) or info.get('glow',False)
        for suffix,enabled in [('',info.get('solid',True)),('_glow',info.get('glow',False))]:
            if enabled:
                size,points=read_vox(folder/(name+suffix+'.vox'))
                assert points and size==tuple(info['frame_size'][i] for i in (2,0,1))
    seen=set()
    for name,spec in rig['limbs'].items():
        assert spec['part'] in rig['parts']
        assert not spec.get('parent_limb') or spec['parent_limb'] in seen
        seen.add(name)
    return rig


def main():
    targets=[R/'creatures'/d[0] for d in DEFINITIONS]
    targets += [R/'creatures/boss_projectiles'/name for name in SHOTS]
    existing=[str(p.relative_to(R)) for p in [*targets,MANIFEST] if p.exists()]
    if existing: raise SystemExit('Create-only generator refuses existing outputs: '+', '.join(existing))
    authored=[]
    for definition in DEFINITIONS:
        name,title,theme,biome,height,behavior,glowing,hover,factory=definition
        b,p,l=factory(); full=assemble(b,p,l)
        assert all(-16<=x<16 and 0<=y<32 and -16<=z<16 for x,y,z in full), name
        for v in [b,*p.values()]: assert v and all(c in a.PAL[theme] for c in v.values())
        authored.append((b,p,l,full))
    records=[]
    for definition,(b,p,l,full) in zip(DEFINITIONS,authored):
        name,title,theme,biome,height,behavior,glowing,hover,_=definition
        god=name in ('hive_mother','storm_warden')
        scale=8 if god else 1
        unit=height/(a.bounds(full)[1][1]*scale)
        folder=R/'creatures'/name
        if god:
            scaled=json.loads(json.dumps(l))
            for spec in scaled.values(): spec['pivot']=[q*8 for q in spec['pivot']]
            a.save(name,title,theme,{'body':b,**p},scaled,{},(0,16,-7),unit=unit)
        else: small(name,theme,b,p,l,unit,hover)
        for dest in ([folder,folder/'source_32'] if god else [folder]):
            path=dest/'rig.json'; rig=json.loads(path.read_text())
            rig.update(pixel_art=True,material_jitter=0.,glow_strength=2.8 if glowing else 1.5,
                       bob=.025 if hover else .012,waddle=.035,flap_rate=22. if name=='spore_drone' else 2.5)
            if name in ('hive_tender','fungal_brute','hive_mother','obsidian_knight','storm_warden'):
                rig['animation_style']='xeno_queen'
            rig['hand']=[0,16*(8 if god and dest==folder else 1),-7*(8 if god and dest==folder else 1)]
            path.write_text(json.dumps(rig,indent=2)+'\n')
            validate(dest)
        rig=validate(folder)
        records.append(dict(id=name,display_name=title,biome=biome,folder='creatures/'+name,
            status='live',height_m=height,voxel_size=unit,parts=list(rig['parts']),behavior=behavior,
            glow=glowing,god=god,design_grid=[32,32,32],upscale=scale))
        assert math.isclose(unit*a.bounds(full)[1][1]*scale,height)
    v={}; a.ell(v,(0,0,0),(3,3,3),'glow_core')
    for c in [(-2,1,-2),(2,1,1),(0,-2,-2),(0,3,0)]: a.ell(v,c,(1.5,1.5,1.5),'glow_eye')
    a.line(v,(-2,0,-2),(2,0,-2),'shade'); a.projectile('spore_bomb','mawgrave',v,.012)
    v={}
    for start,end in [((0,0,-7),(-2,0,-1)),((-2,0,-1),(2,0,0)),((2,0,0),(0,0,7))]:
        a.line(v,start,end,'glow_core',2)
    a.line(v,(1,1,1),(4,1,4),'glow_core'); v[0,1,-6]='bone'
    a.projectile('storm_bolt','paleeye',v,.010)
    for name in SHOTS:
        folder=R/'creatures/boss_projectiles'/name
        read_vox(folder/'model.vox')
        assert json.loads((folder/'rig.json').read_text())['upscale']==8
    MANIFEST.write_text(json.dumps(records,indent=2)+'\n')
    assert {r['id'] for r in json.loads(MANIFEST.read_text())}=={d[0] for d in DEFINITIONS}
    for target in [*targets,MANIFEST]:
        for path in ([target] if target.is_file() else target.rglob('*')):
            if path.suffix=='.vox': read_vox(path)
            if path.suffix=='.json': assert all(chr(c) not in path.read_text() for c in (0xB7,0x2022))
    for r in records: print(f"{r['id']}: {len(r['parts'])} parts, {r['height_m']} m - "+', '.join(r['parts']))
    print('Validated 8 rigs, 2 editable god rigs, all VOX files and 2 projectiles.')


if __name__=='__main__': main()
