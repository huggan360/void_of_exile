#!/usr/bin/env python3
"""Create-only Lantern City NPCs. Run: python tools/make_city_npcs.py

Uses the existing VOX writer and local-pivot humanoid schema. No Godot or
third-party packages required. --validate checks existing outputs without writes.
Forward is -Z, Y is up; VOX storage follows the repository's Z, X, Y mapping.
"""
import copy
import json
import math
import struct
import sys
import zlib
from pathlib import Path

sys.dont_write_bytecode = True
import redesign_pixel_bosses as a

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'creatures/city_npcs_manifest.json'
CAST = [
    ('barista', 'Lantern Cafe Barista', 1.70, 'Cafe keeper'),
    ('bartender', 'Roseglass Bartender', 1.80, 'Tavern keeper'),
    ('noodle_cook', 'Moonsteam Noodle Cook', 1.85, 'Noodle stall cook'),
    ('vendor', 'Glimmer Gadget Vendor', 1.68, 'Gadget merchant'),
    ('courier', 'Skylane Courier', 1.72, 'Parcel courier'),
    ('noble', 'Lamplight Noble', 1.90, 'City patron'),
    ('guard', 'Friendly Lantern Guard', 1.88, 'Lantern watch'),
    ('mechanic', 'Brasswork Mechanic', 1.75, 'Hovercraft mechanic'),
    ('kid', 'Cat Hood Kid', 1.25, 'Neighborhood child'),
    ('dancer', 'Ribbonlight Dancer', 1.77, 'Street performer'),
    ('elder', 'Lantern Storykeeper', 1.76, 'City storyteller'),
    ('alien_tall', 'Three-Eyed Silk Walker', 2.35, 'Star chart scholar'),
    ('alien_fourarm', 'Four-Handed Merchant', 1.82, 'Market merchant'),
    ('alien_squid', 'Bubblehelm Wayfarer', 1.85, 'Aquatic visitor'),
    ('alien_frog', 'Raincoat Frog Folk', 1.45, 'Canal ferryman'),
    ('alien_moth', 'Lantern Moth Tender', 1.90, 'Lantern tender'),
    ('alien_crystal', 'Prism Songkeeper', 2.05, 'Crystal musician'),
    ('alien_mushroom', 'Little Cap Gardener', 1.35, 'Rooftop gardener'),
    ('robot_butler', 'Brass Bell Butler', 1.70, 'Hospitality robot'),
    ('robot_tiny', 'Little Errand Bot', 1.20, 'Service robot'),
]
BASE = dict(dark=(57,35,65), timber=(112,62,52), brass=(191,126,65),
            gold=(244,196,112), cream=(255,227,186), skin=(223,155,112),
            hair=(99,53,64), coat=(74,149,145), trim=(203,100,140),
            shade=(54,100,119), light=(166,211,191),
            glow_amber=(255,201,106), glow_rose=(255,137,184),
            glow_mint=(153,255,209), glow_violet=(204,169,255))
box, ell, line = a.box, a.ell, a.line


def lantern(v, x, y, z):
    box(v, (x-1,y-2,z-1), (x+2,y+2,z+2), 'brass')
    box(v, (x,y-1,z-2), (x+1,y+1,z+3), 'glow_amber')
    box(v, (x-2,y-1,z), (x+3,y+1,z+1), 'glow_amber')
    v[x,y+2,z] = 'gold'


def eyes(v, y=18, z=-4, xs=(-2,2), color='dark'):
    for x in xs:
        box(v, (x-1,y,z), (x+1,y+2,z+1), 'cream')
        v[x,y,z-1] = color
        v[x,y+1,z-1] = color
    box(v, (-1,y-2,z), (1,y-1,z+1), 'hair')


def make(kind, index):
    pal = dict(BASE)
    coats = [(55,151,142),(131,79,133),(203,112,114),(80,133,160),(175,110,163)]
    skins = [(229,168,125),(151,94,76),(248,199,151),(187,121,88)]
    pal['coat'] = coats[index % len(coats)]
    pal['skin'] = skins[index % len(skins)]
    pal['hair'] = [(93,51,54),(64,43,70),(178,105,62),(222,185,135)][index % 4]
    b = {}
    ell(b, (0,10,0), (4,6,3), 'coat')
    box(b, (-3,5,-2), (3,12,3), 'coat')
    box(b, (-3,6,-3), (3,7,3), 'brass')
    box(b, (-1,13,-1), (1,16,2), 'skin')
    ell(b, (0,18,0), (4,4,3.5), 'skin')
    ell(b, (0,20,1), (4,3,3), 'hair')
    box(b, (-3,17,-3), (3,21,-2), 'skin')
    eyes(b)
    # A lit back seam and collar remain readable from the gameplay camera.
    box(b, (-2,12,3), (2,13,4), 'gold')
    box(b, (0,8,3), (1,12,4), 'glow_amber')
    arms = {}
    for side in ('l','r'):
        v = {}
        ell(v, (0,-2,0), (2,3,2), 'coat')
        box(v, (-1,-6,-1), (1,-2,2), 'coat')
        box(v, (-1,-7,-1), (1,-5,1), 'skin')
        box(v, (-1,-5,-2), (1,-4,-1), 'gold')
        v[0,-4,-2] = 'glow_amber'
        arms['arm_'+side] = v
    r = arms['arm_r']
    leg = {}
    box(leg, (-1,-4,-1), (1,1,2), 'shade')
    box(leg, (-1,-5,-2), (2,-3,2), 'timber')
    box(leg, (-1,-4,-3), (2,-3,-2), 'gold')
    leg[0,-4,-3] = 'glow_amber'

    if kind == 'barista':
        box(b, (-2,6,-4), (2,13,-3), 'cream')
        box(b, (-1,9,-5), (1,11,-4), 'glow_amber')
        b[1,10,-5] = 'brass'
        for x,y in [(-1,12),(0,13),(1,12)]: b[x,y,-4] = 'glow_mint'
        box(b, (-3,8,3), (3,9,4), 'cream')
        for x in (-2,1): box(b, (x,8,4), (x+1,11,5), 'cream')
        ell(r, (0,-6,-3), (2,2,2), 'cream')
        box(r, (-1,-4,-4), (1,-3,-2), 'glow_amber')
    elif kind == 'bartender':
        box(b, (-1,7,-3), (1,14,-2), 'cream')
        for x in (-2,1): box(b, (x,13,-4), (x+1,14,-3), 'trim')
        for y in (8,10,12): b[0,y,-4] = 'gold'
        box(r, (-1,-6,-4), (2,-2,-2), 'glow_mint')
        box(r, (0,-2,-4), (1,0,-2), 'brass')
        box(r, (-1,-5,-5), (2,-4,-4), 'cream')
        box(b, (-2,9,3), (2,10,4), 'trim')
    elif kind == 'noodle_cook':
        box(b, (-3,5,-3), (3,13,-2), 'cream')
        ell(b, (0,23,0), (4,3,3), 'cream')
        box(b, (-4,21,-3), (4,22,3), 'trim')
        line(r, (0,-7,-3), (0,2,-3), 'brass')
        ell(r, (0,3,-3), (2,1,2), 'gold')
        r[0,3,-4] = 'glow_amber'
        box(b, (-2,9,3), (2,10,4), 'cream')
    elif kind == 'vendor':
        for x in (-3,1):
            for y in (6,9,12):
                box(b, (x,y,-4), (x+2,y+2,-3), 'timber')
                b[x,y+1,-5] = 'glow_mint' if y==9 else 'gold'
        box(b, (-4,18,-4), (4,21,-3), 'brass')
        for x in (-3,1): box(b, (x,19,-5), (x+2,20,-4), 'glow_mint')
        box(b, (-3,8,3), (3,12,5), 'timber')
        for x in (-2,0,2): b[x,12,4] = 'glow_rose'
    elif kind == 'courier':
        ell(b, (0,21,0), (4,2,4), 'coat')
        box(b, (-3,20,-6), (3,21,-2), 'trim')
        box(b, (-3,8,3), (3,13,6), 'timber')
        ell(b, (0,12,6), (2,8,1.5), 'coat')
        box(b, (-1,6,7), (1,19,8), 'glow_mint')
        for y in (8,16): ell(b, (0,y,7), (2,1,1), 'brass')
        line(b, (-3,13,-3), (2,7,-3), 'gold')
    elif kind == 'noble':
        a.polygon(b, [(-4,3),(-3,13),(3,13),(4,3)], -1,4, 'coat')
        for x in (-3,2): box(b, (x,3,-2), (x+1,13,-1), 'glow_rose')
        box(b, (-4,21,-4), (4,22,4), 'brass')
        box(b, (-3,22,-3), (3,26,3), 'coat')
        box(b, (-3,23,-3), (3,24,3), 'trim')
        lantern(b, 0,27,0)
        box(b, (-3,4,4), (3,5,5), 'glow_rose')
    elif kind == 'guard':
        ell(b, (0,10,0), (4,5,3.5), 'light')
        ell(b, (0,20,0), (4.5,3,4), 'brass')
        box(b, (-3,18,-4), (3,20,-3), 'glow_amber')
        eyes(b,18,-5)
        box(b, (-1,21,0), (1,24,2), 'trim')
        lantern(r,0,-4,-3)
        box(b, (-2,9,3), (2,12,4), 'glow_mint')
        for v in arms.values(): ell(v,(0,-1,0),(2.5,2,2.5),'light')
    elif kind == 'mechanic':
        box(b, (-2,5,-3), (2,12,-2), 'shade')
        for x in (-3,2): box(b, (x,10,-3), (x+1,15,-2), 'gold')
        box(b, (-4,20,-3), (4,21,3), 'trim')
        box(b, (-1,20,-4), (1,22,-3), 'glow_amber')
        line(r,(0,-7,-3),(0,1,-3),'brass',2)
        for x in (-2,2): box(r,(x,0,-3),(x+1,4,-1),'gold')
        box(r,(-2,0,-3),(3,1,-1),'gold')
        r[0,1,-4]='glow_mint'
        for x in (-2,1): box(b,(x,8,3),(x+1,14,4),'gold')
    elif kind == 'kid':
        ell(b,(0,19,1),(4.5,4,4),'coat')
        box(b,(-3,16,-4),(3,21,-3),'skin'); eyes(b,18,-5)
        for x in (-3,2):
            a.polygon(b,[(x-1,22),(x,26),(x+2,22)],-1,2,'coat')
            b[x,23,-2]='glow_rose'
        box(leg,(-1,-4,-3),(2,-3,2),'glow_mint')
        ell(b,(0,9,4),(2,3,2),'trim'); b[0,10,6]='glow_rose'
    elif kind == 'dancer':
        box(b,(-4,14,-3),(4,16,3),'trim')
        a.polygon(b,[(2,15),(7,14),(8,10),(6,8),(5,13)],2,4,'trim')
        line(b,(3,15,4),(7,13,4),'glow_rose')
        line(b,(7,13,4),(6,9,4),'glow_rose')
        box(b,(-3,21,-1),(3,22,2),'gold')
        for x in (-2,0,2): b[x,22,0]='glow_violet'
    elif kind == 'elder':
        a.polygon(b,[(-4,2),(-3,13),(3,13),(4,2)],-2,4,'coat')
        box(b,(-3,2,-3),(3,3,4),'gold')
        pal['hair']=(230,211,187)
        ell(b,(0,22,1),(2,2,2),'hair')
        for x in (-3,1): box(b,(x,18,-4),(x+2,20,-3),'brass')
        eyes(b,18,-5)
        line(r,(1,-13,-2),(1,6,-2),'timber')
        lantern(r,1,5,-2)
        box(b,(-1,4,4),(1,12,5),'trim')
        box(b,(0,5,5),(1,11,6),'glow_amber')
    elif kind == 'alien_tall':
        # Raise the head and lengthen the neck without changing the arm rig.
        b={((x,y+5,z) if y>=15 else (x,y,z)):c for (x,y,z),c in b.items()}
        box(b,(-1,13,-1),(1,22,2),'skin')
        pal['skin']=(155,204,186); pal['hair']=(93,137,150)
        a.polygon(b,[(-4,2),(-2,13),(2,13),(4,2)],-2,3,'coat')
        eyes(b,23,-4,xs=(-2,2)); eyes(b,26,-3,xs=(0,))
        for x in (-3,2): line(b,(x,3,-3),(x//2,13,-3),'glow_violet')
        box(b,(-1,3,3),(1,13,4),'gold')
    elif kind == 'alien_fourarm':
        pal['skin']=(187,148,205)
        for s in (-1,1):
            line(b,(s*3,9,1),(s*6,7,0),'coat',2)
            line(b,(s*6,7,0),(s*5,8,-3),'skin',2)
            b[s*5,8,-4]='gold'
        box(b,(-3,5,-4),(3,8,-3),'timber')
        for x in (-2,0,2): b[x,7,-5]='glow_amber'
        ell(b,(0,22,0),(4,2,3),'trim')
        box(b,(-2,9,3),(2,11,5),'brass')
    elif kind == 'alien_squid':
        pal['skin']=(212,141,185); pal['hair']=pal['skin']
        # An open bubble cage leaves the face unobscured, with rim and glints.
        for y in range(15,25):
            width=round(math.sqrt(max(0,25-(y-20)**2)))
            for x in (-width,width): b[x,y,0]='light'
        ell(b,(0,24,0),(3,1,3),'light')
        box(b,(-4,15,-3),(4,16,4),'brass')
        for x in (-3,-1,1,3):
            line(b,(x,17,-4),(x,14,-5),'skin')
            line(b,(x,14,-5),(x+1,12,-4),'skin')
            b[x+1,12,-5]='glow_rose'
        for x,y in [(-4,21),(-3,23)]: b[x,y,-3]='glow_mint'
        box(b,(-2,8,3),(2,13,5),'brass'); b[0,12,5]='glow_mint'
    elif kind == 'alien_frog':
        pal['skin']=(148,193,113); pal['coat']=(235,172,77)
        ell(b,(0,10,0),(5,6,4),'coat')
        ell(b,(0,18,0),(5,3,4),'skin')
        for x in (-3,3):
            ell(b,(x,21,-1),(2,2,2),'skin')
            box(b,(x-1,21,-3),(x+1,22,-2),'cream'); b[x,21,-4]='dark'
        line(b,(-2,17,-4),(2,17,-4),'hair')
        box(b,(-5,15,-3),(5,16,3),'gold')
        box(b,(-1,6,-4),(1,14,-3),'brass')
        box(b,(-3,8,4),(3,9,5),'glow_mint')
    elif kind == 'alien_moth':
        pal['skin']=(238,211,173); pal['hair']=(239,220,191)
        for s in (-1,1):
            ell(b,(s*5,12,4),(4,6,1.5),'trim')
            ell(b,(s*5,8,4),(3,3,1.5),'coat')
            ell(b,(s*5,13,5),(2,3,1),'gold')
            b[s*5,13,6]='glow_rose'
            line(b,(s*2,21,0),(s*4,25,0),'brass')
            ell(b,(s*4,25,0),(1.3,1.3,1.3),'glow_amber')
        ell(b,(0,14,0),(4,2,4),'cream')
        eyes(b,18,-4,color='dark')
    elif kind == 'alien_crystal':
        pal['skin']=(156,201,212); pal['hair']=(181,156,221)
        a.diamond(b,(0,20,0),4,5,'skin')
        eyes(b,19,-4)
        for x,y in [(-3,22),(2,23),(0,24)]:
            a.diamond(b,(x,y,1),1,3,'light'); b[x,y+2,1]='glow_violet'
        for y in range(7,15): b[(y%3)-1,y,-3]='glow_mint'
        for y in range(9,20): b[0,y,3]='glow_violet'
        for v in arms.values(): line(v,(0,-5,-2),(0,0,-2),'glow_mint')
    elif kind == 'alien_mushroom':
        pal['skin']=(245,216,173)
        ell(b,(0,21,0),(7,2,6),'cream')
        ell(b,(0,23,0),(7,3,6),'trim')
        for x,z in [(-4,0),(-2,-3),(2,2),(3,-2),(0,0)]:
            ell(b,(x,25,z),(1.5,1,1.5),'glow_amber')
        a.polygon(b,[(-4,7),(-4,13),(0,15),(4,13),(4,7)],2,4,'coat')
        box(b,(-3,7,4),(3,8,5),'gold')
    elif kind in ('robot_butler','robot_tiny'):
        pal['skin']=pal['brass']; pal['hair']=pal['gold']
        ell(b,(0,18,0),(4.5,4,4),'brass')
        box(b,(-3,16,-4),(3,21,-3),'dark')
        eyes(b,18,-5,color='glow_mint')
        box(b,(-1,16,-5),(1,17,-4),'glow_amber')
        ell(b,(0,10,0),(4.5,5,3.5),'brass')
        box(b,(-2,8,-4),(2,12,-3),'cream')
        box(b,(-2,9,3),(2,12,4),'timber')
        for x in (-1,1): line(b,(x,9,4),(x,11,4),'glow_mint')
        if kind=='robot_butler':
            for x in (-2,1): box(b,(x,14,-4),(x+1,15,-3),'trim')
            ell(r,(0,-6,-3),(3,1,3),'gold')
            lantern(r,0,-4,-3)
            box(b,(-2,22,-2),(2,24,2),'coat')
        else:
            line(b,(0,21,0),(0,24,0),'brass')
            ell(b,(0,25,0),(1.5,1.5,1.5),'glow_rose')
            for x in (-5,4): ell(b,(x,19,0),(1,2,2),'gold')
            box(b,(-2,7,-4),(2,8,-3),'glow_amber')
    return dict(body=b, **arms, leg=leg), pal


def png_bytes(pixels, width=128, height=128):
    def chunk(tag, data):
        return struct.pack('>I',len(data))+tag+data+struct.pack('>I',zlib.crc32(tag+data)&0xffffffff)
    raw=b''.join(b'\0'+bytes(sum(pixels[y*width:(y+1)*width],())) for y in range(height))
    return (b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('>2I5B',width,height,8,2,0,0,0))
            +chunk(b'IDAT',zlib.compress(raw,9))+chunk(b'IEND',b''))


def portrait(body,pal):
    # Orthographic pixel bust with a slightly elevated view, derived from voxels.
    points={p:c for p,c in body.items() if p[1]>=12}
    projected={}
    for (x,y,z),c in points.items():
        py=-y+round(z*.32)
        key=(x,py)
        depth=-z+y*.32
        if key not in projected or depth>projected[key][0]: projected[key]=(depth,c)
    lo_x=min(p[0] for p in projected); hi_x=max(p[0] for p in projected)
    lo_y=min(p[1] for p in projected); hi_y=max(p[1] for p in projected)
    scale=min(6,104//max(hi_x-lo_x+1,hi_y-lo_y+1))
    ox=(128-(hi_x-lo_x+1)*scale)//2; oy=(128-(hi_y-lo_y+1)*scale)//2
    pixels=[(63,43,79) if y<88 else (78,48,85) for y in range(128) for x in range(128)]
    for y in range(6,122):
        for x in (6,7,120,121): pixels[y*128+x]=(176,117,88)
    for y in (6,7,120,121):
        for x in range(6,122): pixels[y*128+x]=(176,117,88)
    for (x,y),(_,c) in projected.items():
        for dy in range(scale):
            for dx in range(scale):
                px=ox+(x-lo_x)*scale+dx; py=oy+(y-lo_y)*scale+dy
                pixels[py*128+px]=pal[c]
    return png_bytes(pixels)


def read_vox(path):
    data=path.read_bytes()
    assert data[:8]==b'VOX '+struct.pack('<I',150), path
    size=None; vox={}; pos=20
    while pos<len(data):
        tag,n,children=struct.unpack_from('<4sII',data,pos); pos+=12
        payload=data[pos:pos+n]; pos+=n
        if tag==b'SIZE': size=struct.unpack('<3I',payload)
        if tag==b'XYZI':
            count=struct.unpack_from('<I',payload)[0]
            assert len(payload)==4+count*4
            for i in range(count):
                z,x,y,c=struct.unpack_from('4B',payload,4+i*4)
                assert (x,y,z) not in vox
                vox[x,y,z]=c
    assert size and vox, path
    assert all(0<=x<size[1] and 0<=y<size[2] and 0<=z<size[0] and c for (x,y,z),c in vox.items())
    return (size[1],size[2],size[0]),vox


def validate(records):
    template=json.loads((ROOT/'creatures/npc_villager/rig.json').read_text())
    for record in records:
        folder=ROOT/record['folder']; rig=json.loads((folder/'rig.json').read_text())
        assert set(rig)==set(template)
        assert set(rig['parts'])==set(template['parts'])
        assert set(rig['limbs'])==set(template['limbs'])
        assembled={}
        for name in record['parts']:
            size,solid=read_vox(folder/(name+'.vox'))
            gsize,glow=read_vox(folder/(name+'_glow.vox'))
            assert size==gsize and not solid.keys() & glow.keys()
            assert rig['parts'][name]['glow'] is True
            origin=rig['parts'][name]['frame_min']
            local={tuple(p[k]+origin[k] for k in range(3)):c for p,c in (solid|glow).items()}
            pivots=[(0,0,0)] if name=='body' else [s['pivot'] for s in rig['limbs'].values() if s['part']==name]
            for pivot in pivots:
                assembled.update({tuple(round(p[k]+pivot[k]) for k in range(3)):c for p,c in local.items()})
        # Match export overlap ordering: body, left arm, right arm, both legs.
        size,solid=read_vox(folder/'model.vox'); gsize,glow=read_vox(folder/'model_glow.vox')
        assert size==gsize and not solid.keys() & glow.keys()
        lo,extent=a.bounds(assembled)
        expected={tuple(p[k]-lo[k] for k in range(3)):c for p,c in assembled.items()}
        assert solid|glow==expected and size==extent
        assert size[0]<=32 and size[2]<=32
        assert abs(size[1]*rig['voxel_size']-record['height_m'])<1e-8
        png=(folder/'portrait.png').read_bytes()
        assert png[:8]==b'\x89PNG\r\n\x1a\n' and struct.unpack_from('>II',png,16)==(128,128)
        print('Validated',record['id'], 'height',record['height_m'], 'frame',size)
    assert len(records)==20


def main():
    if '--validate' in sys.argv:
        validate(json.loads(MANIFEST.read_text())); return
    folders=[ROOT/'creatures'/('city_'+kind) for kind,*_ in CAST]
    # Stage everything before creating files. Existing identical bytes are left
    # untouched, making an interrupted run safe to resume without any overwrite.
    staged={}
    class Destination:
        def __init__(self,path): self.path=path
        def write_bytes(self,data): staged[self.path]=data
    records=[]
    for index,(kind,title,height,role) in enumerate(CAST):
        parts,pal=make(kind,index)
        rig=copy.deepcopy(json.loads((ROOT/'creatures/npc_villager/rig.json').read_text()))
        for side,x in [('l',-4),('r',4)]: rig['limbs']['arm_'+side]['pivot']=[x,13,0]
        for side,x in [('l',-2),('r',2)]: rig['limbs']['leg_'+side]['pivot']=[x,5,0]
        rig['hand']=[4,6,-2]
        full=dict(parts['body'])
        for spec in rig['limbs'].values():
            for p,c in parts[spec['part']].items(): full[tuple(p[k]+spec['pivot'][k] for k in range(3))]=c
        lo,size=a.bounds(full); rig['voxel_size']=height/size[1]
        assert size[0]<=32 and size[2]<=32
        folder=folders[index]
        for name,v in {**parts,'model':full}.items():
            origin,frame=a.bounds(v)
            solid={p:c for p,c in v.items() if not c.startswith('glow_')}
            glow={p:c for p,c in v.items() if c.startswith('glow_')}
            assert solid and glow
            a.write(Destination(folder/(name+'.vox')),solid,pal,origin,frame)
            a.write(Destination(folder/(name+'_glow.vox')),glow,pal,origin,frame)
            if name!='model': rig['parts'][name]=dict(frame_min=list(origin),glow=True)
        staged[folder/'rig.json']=(json.dumps(rig,indent=2)+'\n').encode()
        staged[folder/'portrait.png']=portrait(parts['body'],pal)
        records.append(dict(id='city_'+kind,name=title,folder='creatures/city_'+kind,
                            height_m=height,voxel_size=rig['voxel_size'],parts=list(parts),role=role))
    staged[MANIFEST]=(json.dumps(records,indent=2)+'\n').encode()
    for path,data in staged.items():
        if path.exists() and path.read_bytes()!=data:
            raise SystemExit('Refusing to replace existing file: '+str(path))
    for path,data in staged.items():
        if not path.exists():
            path.parent.mkdir(parents=True,exist_ok=True)
            with path.open('xb') as out: out.write(data)
    validate(records)
    print('Created 20 NPCs, 200 VOX files, 20 rigs and 20 portraits.')


if __name__=='__main__': main()
