#!/usr/bin/env python3
"""Create-only planet bosses. Run: python3 tools/make_planet_bosses.py.

64-cell authored models use the shared boss pipeline at x4, fitting the VOX
256-cell limit. Projectiles use the original x8 authored projectile pipeline.
Only the listed new output folders and planet_bosses_manifest.json are written.
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
MANIFEST = R / 'creatures/planet_bosses_manifest.json'
DEFS = [
    ('queen_briarrose', 'Queen Briarrose', 'Rosamund', 7.5, ('bloom', 'wilted'), ('rose_petal', 'thorn_spike')),
    ('amber_colossus', 'Aurum, the Amber Colossus', 'Amberfall', 9.0, ('molten', 'hive'), ('amber_shard', 'honey_orb')),
    ('selenarch', 'Selenarch, the Moon-Eater', 'Hollowmoon', 8.0, ('eclipse', 'void'), ('moon_shard', 'ghost_wisp')),
    ('brood_matriarch', 'The Brood Matriarch', 'Mawgrave', 8.5, ('swarm', 'rot'), ('spore_cluster', 'acid_lance')),
    ('stormeye_tyrant', 'The Stormeye Tyrant', 'The Pale Eye', 9.5, ('tempest', 'cataclysm'), ('storm_orb', 'eye_lance')),
]
# Local palettes include distinct phase colors without changing existing themes.
COLORS = [
    [(199,45,105),(255,144,191),(102,16,55),(29,9,25),(255,211,226),(255,240,229),(225,128,191),(42,124,57),(255,248,247),(255,49,177)],
    [(175,120,63),(255,200,77),(103,62,31),(35,24,20),(224,166,73),(245,222,165),(187,96,24),(92,60,33),(255,246,154),(255,166,19)],
    [(71,76,91),(149,157,169),(30,32,56),(9,12,23),(187,191,171),(235,235,205),(47,52,74),(166,126,60),(224,255,216),(100,255,151)],
    [(118,48,148),(189,101,192),(60,22,83),(18,9,31),(225,144,192),(218,204,159),(99,38,113),(157,74,153),(179,255,60),(255,69,182)],
    [(37,42,62),(85,110,150),(20,23,38),(6,9,19),(209,225,241),(245,249,255),(70,102,151),(155,18,47),(222,252,255),(49,164,255)],
]
for d, colors in zip(DEFS, COLORS):
    a.PAL[d[0]] = dict(zip(('base','light','shade','dark','belly','bone','wing','accent','glow_eye','glow_core'), colors))
    a.PAL[d[0]].update(glow_white=(255,255,244), glow_red=(255,49,74),
                       glow_green=(165,255,57), glow_magenta=(255,27,196),
                       crimson=(82,8,35), obsidian=(14,10,25))

# Extract court helpers without executing its top-level authoring calls.
source = ast.parse((R / 'tools/make_court_creatures.py').read_text())
for node in source.body:
    if isinstance(node, ast.FunctionDef) and node.name in ('small', 'boss'):
        exec(compile(ast.Module(body=[node], type_ignores=[]), 'court_rig_helpers', 'exec'))


def install_64_writer():
    """Adapt only grid constants in memory; retain shared split/rig/pose logic."""
    source = ast.parse((R / 'tools/redesign_pixel_bosses.py').read_text())
    class Grid64(ast.NodeTransformer):
        def visit_Constant(self, node):
            value = node.value
            if type(value) is int:
                value = {8: 4, 7: 3, 32: 64}.get(value, value)
            elif value == 'source_32':
                value = 'source_64'
            return ast.copy_location(ast.Constant(value), node)
    for name in ('save', 'upscale'):
        node = next(n for n in source.body if isinstance(n, ast.FunctionDef) and n.name == name)
        if name == 'save':
            tables = [n for n in ast.walk(node) if isinstance(n, ast.Dict)
                      and any(isinstance(k, ast.Constant) and k.value == 'blue' for k in n.keys)]
            assert len(tables) == 1
            for d in DEFS:
                tables[0].keys.append(ast.Constant(d[0]))
                tables[0].values.append(ast.Constant(d[2]))
        node = Grid64().visit(node)
        exec(compile(ast.fix_missing_locations(ast.Module(body=[node], type_ignores=[])),
                     'planet_64_writer', 'exec'), a.__dict__)


def attach(parts, limbs, name, v, pivot, role, phase=1, **extra):
    parts[name] = v
    limbs[name] = a.limb(name, pivot, role, phase, throws=False, **extra)
    limbs[name]['pivot'] = list(pivot)


def ring(v, center, radius, color, plane='xz', tilt=0, width=1):
    x,y,z = center
    for i in range(180):
        t = math.tau*i/180
        u,w = round(radius*math.cos(t)), round(radius*math.sin(t))
        p = (x+u, y+round(w*tilt), z+w) if plane == 'xz' else (x+u,y+w,z)
        a.box(v,p,tuple(q+width for q in p),color)


def eyes(v, y=0, z=-5, spread=3):
    for s in (-1,1):
        a.ell(v,(s*spread,y,z),(2.5,2,1.5),'dark')
        a.box(v,(s*spread-1,y,z-2),(s*spread+1,y+1,z),'glow_eye')


def rose(v, center, r, color='light'):
    x,y,z = center
    for i in range(5):
        t=i*math.tau/5
        a.ell(v,(x+math.cos(t)*r*.55,y,z+math.sin(t)*r*.55),(r*.65,2,r*.65),color)
    a.ell(v,(x,y+1,z),(r*.45,2,r*.45),'base')
    v[round(x),round(y+2),round(z)]='glow_eye'


def thorn(v, start, end, color='accent'):
    a.line(v,start,end,color)
    a.ell(v,start,(2,2,2),color)


def queen(form=''):
    b,p,l={},{},{}
    wilt=form=='wilted'; bloom=form=='bloom'
    # Stacked radial petals, with gaps and contrasting edges visible from above.
    for tier,(y,r) in enumerate(((7,16),(16,13),(25,10),(33,7))):
        for i in range(8):
            t=i*math.tau/8+tier*.35
            radius=r+(2 if bloom else 0)
            x,z=math.cos(t)*radius*.65,math.sin(t)*radius*.65
            a.ell(b,(x,y,z),(radius*.49,7,radius*.49),'crimson' if wilt else ('base' if i%2 else 'light'))
            a.ell(b,(x,y+5,z),(radius*.35,1.5,radius*.35),'obsidian' if wilt else 'belly')
            if wilt: thorn(b,(round(x),y+4,round(z)),(round(x*1.4),y+10,round(z*1.4)))
    a.ell(b,(0,37,0),(6,7,5),'base')
    a.diamond(b,(0,38,-5),3,5,'glow_core')
    h={};a.ell(h,(0,0,0),(6,7,5),'bone');eyes(h,1,-4)
    a.line(h,(-2,-3,-5),(2,-3,-5),'crimson')
    for x,z in ((-6,0),(-3,-2),(0,-3),(3,-2),(6,0),(0,3)):
        a.diamond(h,(x,7-abs(x)//3,z),2,4,'glow_white' if bloom else 'belly')
        rose(h,(x,8-abs(x)//3,z),3,'bone')
    if wilt: h=a.recolor(h,{'glow_eye':'glow_white','base':'crimson','belly':'obsidian'})
    attach(p,l,'head',h,(0,47,-1),'head')
    for s,side in ((-1,'l'),(1,'r')):
        arm={};a.line(arm,(0,0,0),(s*5,-7,-1),'accent',3)
        a.line(arm,(s*5,-7,-1),(s*3,-14,-5),'accent',2)
        for j in range(3): thorn(arm,(s*(2+j),-3-j*3,0),(s*(6+j),-1-j*3,1))
        rose(arm,(s*3,-14,-5),4)
        attach(p,l,'arm_'+side,arm,(s*6,39,0),'arm',s)
        for i in range(2):
            w={}
            # Thin perforated petal membranes suggest translucency in the opaque voxel renderer.
            for x in range(1,23):
                width=max(1,round(8*math.sin(math.pi*x/24)))
                for z in range(-width,width+1):
                    if (x+z)%4==0 and abs(z)<width-1: continue
                    y=round(x*(.42 if i==0 else -.25))
                    w[s*x,y,z]='glow_magenta' if bloom or abs(z)>=width-1 else 'wing'
            a.line(w,(0,0,0),(s*21,9 if i==0 else -5,0),'glow_core')
            if wilt:w=a.recolor(w,{'wing':'crimson','glow_core':'glow_white','glow_magenta':'glow_red'})
            attach(p,l,f'wing_{side}_{i}',w,(s*6,39 if i==0 else 29,6 if i==0 else 12),'wing',s)
    return b,p,l


def honeycomb(v, center, radius=7, color='glow_core'):
    x,y,z=center
    for dx in range(-radius,radius+1,4):
        for dy in range(-radius,radius+1,4):
            if dx*dx+dy*dy>radius*radius:continue
            a.ell(v,(x+dx,y+dy,z),(2.3,2.3,2),'light')
            a.ell(v,(x+dx,y+dy,z-1),(1.3,1.3,1.5),color)


def amber(form=''):
    b,p,l={},{},{}
    a.ell(b,(0,23,4),(17,14,21),'base')
    a.ell(b,(0,30,8),(18,13,20),'shade')
    for s in (-1,1):
        a.ell(b,(s*(11 if form=='hive' else 8),34,8),(8,10,19),'light')
        for z in range(-6,24,6):
            a.ell(b,(s*10,40,z),(5,2,2),'glow_core')
            a.line(b,(s*15,30,z),(s*12,37,z),'accent')
    honeycomb(b,(0,19,-16),11)
    if form=='hive':
        a.box(b,(-5,31,-9),(6,45,24),'dark')
        for z in range(-5,23,5):
            a.ell(b,(0,40,z),(4,4,3),'glow_core')
            ring(b,(0,43,z),3,'light')
        for x,z in ((-8,-8),(8,3),(-5,16)):
            a.ell(b,(x,47,z),(2,2,3),'dark');a.box(b,(x-1,47,z),(x+2,49,z+1),'glow_eye')
            a.ell(b,(x-3,48,z),(3,1,2),'bone');a.ell(b,(x+3,48,z),(3,1,2),'bone')
    if form=='molten':
        for s in (-1,1):
            for z in range(-7,25,5):a.line(b,(s*3,43,z),(s*15,31,z+3),'glow_eye',2)
    h={};a.ell(h,(0,0,0),(7,8,6),'base')
    for s in (-1,1):
        a.polygon(h,[(s*4,8),(s*10,4),(s*11,-9),(s*6,-7)],-2,5,'light')
        for y in range(-7,8,3):a.line(h,(s*6,y,-3),(s*10,y,-3),'accent')
    eyes(h,1,-5,3);a.box(h,(-1,-3,-7),(2,3,-5),'light')
    a.diamond(h,(0,-7,-5),2,4,'light');a.diamond(h,(0,9,-2),3,4,'glow_core')
    if form:h=a.recolor(h,{'accent':'glow_core','light':'glow_eye'} if form=='molten' else {'base':'light'})
    attach(p,l,'head',h,(0,43,-14),'head')
    for s,side in ((-1,'l'),(1,'r')):
        for i,z in enumerate((-10,17)):
            v={};a.ell(v,(s*2,-5,0),(5,7,5),'base');a.box(v,(-4,-12,-7),(5,-7,4),'light')
            for x in (-2,1,3):a.line(v,(x,-11,-7),(x,-8,-7),'accent')
            attach(p,l,f'leg_{side}_{i}',v,(s*13,12,z),'leg',s*(-1)**i)
        v={};a.ell(v,(s*3,-4,-1),(5,7,5),'light');a.ell(v,(s*5,-11,-3),(5,5,5),'base')
        a.box(v,(s*5-3,-14,-8),(s*5+4,-8,-6),'glow_core')
        attach(p,l,'arm_'+side,v,(s*15,33,-10),'arm',s)
    return b,p,l


def chain(p,l,prefix,root,count=3,color='wing',cloud=False):
    for i in range(count):
        v={};r=max(1,3-i*.65)
        a.ell(v,(0,-3,1),(r,4,r),'base' if cloud else color)
        a.line(v,(0,0,0),(0,-6,2),color,2 if i==0 else 1)
        if cloud:
            a.ell(v,(2,-3,1),(r,2,r),'wing')
            a.line(v,(-1,-1,0),(1,-5,1),'glow_core')
        else:
            a.polygon(v,[(-3,0),(3,0),(2,-5),(0,-7),(-2,-4)],0,2,color)
        extra={'parent_limb':f'{prefix}_{i-1}'} if i else {}
        attach(p,l,f'{prefix}_{i}',v,root if i==0 else (0,-6,2),
               'tail_chain',segment=i,segments=count,**extra)


def lich(form=''):
    b,p,l={},{},{}
    a.ell(b,(0,29,2),(10,16,8),'wing')
    for s in (-1,1):
        a.polygon(b,[(s*3,42),(s*12,36),(s*13,15),(s*7,20)],-1,5,'base')
        a.line(b,(s*3,40,-5),(s*9,18,-5),'accent',2)
    a.ell(b,(0,34,-6),(6,10,3),'dark')
    for y in range(28,42,4):
        for s in (-1,1):
            a.line(b,(s*(3 if form=='void' else 1),y,-9),(s*7,y+2,-7),'bone')
    a.diamond(b,(0,34,-8),4,7,'glow_core')
    if form=='void':
        for s in (-1,1):a.line(b,(0,34,-11),(s*6,34,-11),'glow_white')
    if form=='eclipse':b=a.recolor(b,{'accent':'glow_core','base':'shade'})
    h={}
    # Vertical moon disc, cracked away in several jagged sectors.
    for x in range(-13,14):
        for y in range(-13,14):
            d=x*x+y*y
            if 96<=d<=180 and not (x>5 and abs(y-x//2)<2):
                a.box(h,(x,y+3,4),(x+1,y+4,6),'dark' if form=='eclipse' else 'belly')
    ring(h,(0,3,4),14,'glow_core' if form else 'accent',plane='xy')
    a.ell(h,(0,0,-1),(6,7,5),'bone');eyes(h,1,-5)
    a.box(h,(-1,-2,-6),(1,1,-4),'dark')
    for x in range(-4,5,2):a.box(h,(x,-6,-5),(x+1,-3,-3),'bone')
    a.line(h,(1,6,-4),(0,2,-6),'dark')
    if form=='void':h=a.recolor(h,{'glow_core':'glow_white','glow_eye':'glow_white'})
    attach(p,l,'head',h,(0,46,-2),'head')
    for s,side in ((-1,'l'),(1,'r')):
        v={};a.ell(v,(s,-1,0),(4,3,4),'base')
        a.line(v,(0,0,0),(s*5,-10,-3),'bone',2)
        a.line(v,(s*5,-10,-3),(s*7,-14,-8),'bone',2)
        for j in range(3):a.line(v,(s*7+j-1,-14,-8),(s*7+j-1,-18,-11),'bone')
        attach(p,l,'arm_'+side,v,(s*10,38,0),'arm',s)
    for i,x in enumerate((-6,0,6)):chain(p,l,f'robe_tail_{i}',(x,20,4),3,'glow_core' if form=='eclipse' else 'wing')
    for i,tilt in enumerate((.3,-.4)):
        v={};ring(v,(0,0,0),23,'accent',tilt=tilt)
        for j in range(4):
            t=j*math.tau/4+i*.7;x,z=round(23*math.cos(t)),round(23*math.sin(t))
            a.ell(v,(x,round(z*tilt),z),(3,3,3),'glow_white' if form=='void' else 'glow_core')
        attach(p,l,f'orrery_{i}',v,(0,29+i*5,0),'',(-1)**i)
    return b,p,l


def cap(v,center,r):
    x,y,z=center
    a.line(v,(x,y-5,z),(x,y,z),'belly',2)
    a.ell(v,(x,y-1,z),(r,1.5,r),'glow_eye')
    a.ell(v,(x,y+1,z),(r,3,r),'base')
    for dx,dz in ((-2,0),(2,1),(0,-3)):a.ell(v,(x+dx,y+3,z+dz),(1.5,1,1.5),'light')


def brood(form=''):
    b,p,l={},{},{}
    a.ell(b,(0,22,8),(18,15,20),'base')
    for s in (-1,1):
        for z in (-3,6,15,22):
            a.ell(b,(s*13,29,z),(5,5,4),'shade')
            a.ell(b,(s*14,31,z),(3.5,4,3),'glow_core')
            if form=='swarm':
                a.ell(b,(s*14,34,z),(2,2,2),'dark')
                for dx in (-3,3):a.line(b,(s*14,33,z),(s*14+dx,38,z+2),'glow_core')
    a.ell(b,(0,36,-8),(8,12,7),'wing')
    for y in (31,36,41):a.line(b,(-5,y,-14),(5,y,-14),'glow_eye')
    if form=='rot':
        b=a.recolor(b,{'base':'obsidian','wing':'crimson','glow_core':'glow_green'})
        for s in (-1,1):
            for z in range(-3,26,5):a.line(b,(0,37,z),(s*15,30,z+2),'glow_green')
    h={};a.ell(h,(0,0,0),(7,5,5),'shade');eyes(h,1,-5,4)
    for x,z,r in ((0,1,8),(-7,0,5),(7,0,5),(-4,5,5),(4,5,5)):cap(h,(x,8-abs(x)//3,z),r)
    if form=='swarm':h=a.recolor(h,{'base':'glow_core'})
    if form=='rot':h=a.recolor(h,{'base':'obsidian','light':'glow_green'})
    attach(p,l,'head',h,(0,48,-10),'head')
    jaw={};a.ell(jaw,(0,-1,-1),(5,2,3),'shade')
    for s in (-1,1):
        a.line(jaw,(s*4,0,0),(s*7,-1,-4),'light',2)
        a.line(jaw,(s*7,-1,-4),(s*3,0,-7),'bone')
    attach(p,l,'jaw',jaw,(0,-3,-3),'jaw',parent_limb='head')
    for s,side in ((-1,'l'),(1,'r')):
        for i,z in enumerate((-7,5,18)):
            v={};a.line(v,(0,0,0),(s*10,3,2),'wing',3)
            a.line(v,(s*10,3,2),(s*13,-12,1),'shade',2)
            a.line(v,(s*13,-12,1),(s*12,-15,-2),'bone')
            a.line(v,(s*9,3,1),(s*12,-7,0),'light')
            attach(p,l,f'leg_{side}_{i}',v,(s*12,15,z),'leg',s*(-1)**i)
        v={};a.line(v,(0,0,0),(s*9,-6,-3),'wing',3)
        a.polygon(v,[(s*9,-5),(s*13,-9),(s*10,-23),(s*7,-15)],-5,-2,'light')
        a.line(v,(s*12,-10,-6),(s*10,-22,-6),'glow_eye')
        attach(p,l,'arm_'+side,v,(s*7,41,-9),'arm',s)
    return b,p,l


def storm(form=''):
    b,p,l={},{},{}
    a.ell(b,(0,39,1),(19,18,16),'shade')
    # Armored rear shell surrounds an open forward aperture.
    a.ell(b,(0,40,-5),(16,14,11),'belly')
    for s in (-1,1):
        for y,z in ((29,0),(39,3),(48,2)):
            a.ell(b,(s*(17 if form else 15),y,z),(5,6,12),'base')
            thorn(b,(s*18,y,2),(s*27,y+4,4),'obsidian')
            if form:a.line(b,(s*18,y-3,-7),(s*20,y+3,-2),'glow_red' if form=='cataclysm' else 'glow_core',2)
    for x,z in ((-10,3),(-5,7),(0,6),(6,5),(11,2)):
        a.diamond(b,(x,54,z),3,6,'glow_core')
    if form=='cataclysm':
        b=a.recolor(b,{'glow_core':'glow_white','belly':'glow_red','light':'glow_red'})
        for x,y,z in list(b):
            if z>1 and (x+y+z)%17<2:del b[x,y,z]
    h={};a.ell(h,(0,0,0),(12,12,5),'bone')
    a.ell(h,(0,1,-4),(9,10,3),'glow_red' if form=='cataclysm' else 'glow_core')
    ring(h,(0,1,-7),8,'glow_white' if form else 'glow_eye',plane='xy')
    a.ell(h,(0,1,-7),(2,8,1.5),'glow_white' if form=='cataclysm' else 'glow_red')
    a.ell(h,(-3,5,-7),(2,2,1),'glow_white')
    attach(p,l,'head',h,(0,40,-14),'head')
    for i in range(6):
        t=i*math.tau/6
        chain(p,l,f'tentacle_{i}',(round(12*math.cos(t)),25,round(9*math.sin(t))+2),4,'wing',True)
    if form:
        for n in p:
            if n!='head':p[n]=a.recolor(p[n],{'glow_core':'glow_white' if form=='cataclysm' else 'glow_core','wing':'glow_red' if form=='cataclysm' else 'wing'})
    return b,p,l


FACTORIES = (queen,amber,lich,brood,storm)


def projectile(name):
    v={}
    if name=='rose_petal':
        for z in range(-6,7):
            width=max(1,round(4*math.sin(math.pi*(z+7)/14)))
            for x in range(-width,width+1):
                v[x,(z*z)//15,z]='glow_magenta' if abs(x)>=width-1 else 'glow_core'
        a.line(v,(0,0,-4),(0,2,5),'base')
    elif name in ('thorn_spike','acid_lance','eye_lance'):
        for z in range(-10,8):
            radius=max(0,round((z+10)/7)) if z<0 else max(0,2-z//3)
            for x in range(-radius,radius+1):
                for y in range(-radius,radius+1):
                    if abs(x)+abs(y)<=radius:
                        v[x,y,z]='glow_green' if name=='acid_lance' else 'glow_red'
            v[0,0,z]='glow_white' if name=='eye_lance' else 'glow_core'
        if name=='thorn_spike':a.line(v,(1,0,-2),(2,0,5),'accent')
        if name=='acid_lance':
            for z in (0,4):a.line(v,(1,0,z),(1,-4,z+1),'glow_green')
    elif name=='amber_shard':
        a.diamond(v,(0,0,0),4,7,'glow_core')
        v=a.recolor(v,{'light':'glow_eye','shade':'glow_core'})
        a.line(v,(-1,-4,-1),(-1,4,-1),'glow_white')
    elif name=='moon_shard':
        for x in range(-6,7):
            for z in range(-7,8):
                if x*x+z*z<=49 and (x-3)**2+z*z>36:
                    a.box(v,(x,-1,z),(x+1,1,z+1),'glow_eye' if x<-4 else 'glow_core')
    elif name=='ghost_wisp':
        a.ell(v,(0,0,-2),(4,4,4),'glow_core');eyes(v,0,-5,2)
        for i in range(7):a.ell(v,(round(math.sin(i)),i//3,i+1),(max(.7,2-i/4),1.5,1.5),'glow_eye')
    else:
        a.ell(v,(0,0,0),(4,4,4),'glow_core')
        if name=='spore_cluster':
            for c in ((-3,2,-2),(3,1,1),(0,-3,2),(0,3,1)):a.ell(v,c,(2.5,2.5,2.5),'glow_core')
            for c in ((-3,3,-3),(3,2,0),(0,4,1)):a.ell(v,c,(1,1,1),'glow_eye')
        elif name=='honey_orb':
            a.ell(v,(1,-3,1),(2,4,2),'glow_core');a.ell(v,(-1,2,-3),(2,1,1),'glow_eye')
        else:
            for s in (-1,1):
                a.line(v,(s*3,1,-2),(s*6,2,0),'glow_eye')
                a.line(v,(s*6,2,0),(s*4,3,3),'glow_eye')
            a.ell(v,(-1,1,-3),(2,2,1),'glow_white')
    return v


def validate(folder):
    rig=json.loads((folder/'rig.json').read_text())
    for n,info in rig['parts'].items():
        for suffix,enabled in (('',info.get('solid',True)),('_glow',info.get('glow',False))):
            if enabled:
                size,_=read_vox(folder/(n+suffix+'.vox'))
                assert size==tuple(info['frame_size'][i] for i in (2,0,1)), n
    seen=set()
    for name,spec in rig['limbs'].items():
        assert spec['part'] in rig['parts']
        assert not spec.get('parent_limb') or spec['parent_limb'] in seen
        seen.add(name)
    for swaps in rig['variants'].values():
        assert 'body' in swaps and 'head' in swaps
        for base,alt in swaps.items():
            for key in ('frame_min','frame_size'):assert rig['parts'][base][key]==rig['parts'][alt][key]
        for base in ('body','head'):
            assert rig['parts'][swaps[base]].get('glow')
            assert rig['parts'][swaps[base]].get('solid',True)
    return rig


def main():
    targets=[R/'creatures'/d[0] for d in DEFS]
    targets += [R/'creatures/boss_projectiles'/s for d in DEFS for s in d[5]]
    existing=[str(p.relative_to(R)) for p in [*targets,MANIFEST] if p.exists()]
    if existing:raise SystemExit('Create-only generator refuses existing outputs: '+', '.join(existing))
    authored=[]
    for d,factory in zip(DEFS,FACTORIES):
        b,p,l=factory();variants={}
        for form in d[4]:
            vb,vp,vl=factory(form)
            assert vl==l
            swaps={'body':'body_'+form,'head':'head_'+form}
            p['body_'+form]=vb;p['head_'+form]=vp['head']
            for name in vp:
                if name!='head' and vp[name]!=p[name]:
                    p[name+'_'+form]=vp[name];swaps[name]=name+'_'+form
            variants[form]=swaps
        full=assemble(b,p,l)
        for swaps in ({},*variants.values()):
            pose=assemble(b,p,l,swaps)
            assert all(-32<=x<32 and 0<=y<64 and -32<=z<32 for x,y,z in pose), d[0]
        for v in (b,*p.values()):assert v and set(v.values())<=a.PAL[d[0]].keys()
        authored.append((b,p,l,variants,full))
    original_upscale=a.upscale
    install_64_writer()
    records=[]
    for d,(b,p,l,variants,full) in zip(DEFS,authored):
        name,title,planet,height,forms,shots=d
        extent=a.bounds(full)[1][1]
        unit=height/(extent*4)
        scaled=json.loads(json.dumps(l))
        for spec in scaled.values():spec['pivot']=[q*4 for q in spec['pivot']]
        a.save(name,title,name,{'body':b,**p},scaled,variants,(0,38,-20),unit=unit)
        folder=R/'creatures'/name
        for dest in (folder,folder/'source_64'):
            path=dest/'rig.json';rig=json.loads(path.read_text())
            rig.update(design_grid=[64,64,64],upscale=4 if dest==folder else 1,
                       height_m=height,glow_strength=1.6,bob=.035,waddle=.025,flap_rate=2.2)
            # Generic wings retain flap(); dungeon animation supplies head/jaw/slam poses.
            rig['animation_style']='wraith' if name in ('queen_briarrose','selenarch') else 'xeno_queen'
            path.write_text(json.dumps(rig,indent=2)+'\n')
            validate(dest)
        rig=validate(folder)
        poses=json.loads((folder/'poses.json').read_text())
        for pose in poses.values():
            size,points=read_vox(folder/pose['file'])
            assert size==(256,256,256) and len(points)==pose['voxels']
        _,points=read_vox(folder/'model.vox')
        assert math.isclose((max(q[2] for q in points)-min(q[2] for q in points)+1)*unit,height)
        records.append(dict(id=name,display_name=title,planet=planet,folder='creatures/'+name,
            status='live',height_m=height,voxel_size=unit,parts=list(rig['parts']),variants=list(forms),
            projectiles=list(shots),design_grid=[64,64,64],upscale=4))
    a.upscale=original_upscale
    for d in DEFS:
        for name in d[5]:
            v=projectile(name)
            assert sum(c.startswith('glow') for c in v.values())>len(v)*.5
            a.projectile(name,d[0],v,.012)
            dest=R/'creatures/boss_projectiles'/name
            read_vox(dest/'model.vox')
            assert json.loads((dest/'rig.json').read_text())['upscale']==8
    MANIFEST.write_text(json.dumps(records,indent=2)+'\n')
    assert {d['id'] for d in json.loads(MANIFEST.read_text())}=={d[0] for d in DEFS}
    for target in [*targets,MANIFEST,Path(__file__)]:
        for path in ([target] if target.is_file() else target.rglob('*')):
            if path.suffix=='.vox':read_vox(path)
            if path.suffix in ('.json','.py'):assert all(chr(c) not in path.read_text() for c in (0xB7,0x2022))
    for record in records:
        print(f"{record['id']}: {len(record['parts'])} parts, {record['height_m']} m, variants "+', '.join(record['variants']))
    print('Validated 5 live rigs, 5 editable rigs, 15 assembled poses and 10 projectiles.')


if __name__=='__main__':main()
