#!/usr/bin/env python3
"""Create Vesperis vehicles: python3 tools/make_city_vehicles.py.

Create-only: an existing output is checked byte-for-byte and never overwritten.
Coordinates are game XYZ, Y up, front -Z. The imported writer stores VOX ZXY.
Apply manifest frame_min * voxel_size when loading an uncentered voxel buffer.
All dimensions include decorations. No scene, rig, or engine changes are made.
"""
import io
import json
import math
from pathlib import Path
import struct
import sys

sys.dont_write_bytecode = True
import redesign_pixel_bosses as art

ROOT = Path(__file__).resolve().parents[1]
PALETTE = {
    'amber': (231, 157, 55), 'rose': (220, 110, 151),
    'teal': (47, 161, 157), 'violet': (151, 111, 193),
    'cream': (255, 232, 185), 'blue': (79, 129, 200),
    'mint': (154, 218, 180), 'brass': (194, 139, 67),
    'gold': (246, 201, 104), 'wood': (133, 77, 62),
    'timber': (183, 113, 73), 'plum': (68, 48, 86),
    'glass': (72, 123, 153), 'seat': (120, 63, 101),
    'glow_warm': (255, 216, 132), 'glow_mint': (143, 255, 217),
    'glow_rose': (255, 130, 175), 'glow_blue': (145, 202, 255),
    'glow_violet': (220, 171, 255),
}


def box(v, x0, y0, z0, x1, y1, z1, c):
    art.box(v, (x0, y0, z0), (x1, y1, z1), c)


def rounded(v, lo, hi, color, radius=3):
    """Rounded solid with flat readable panels and stepped voxel corners."""
    r = min(radius, *(float(b-a)/2 for a, b in zip(lo, hi)))
    for x in range(lo[0], hi[0]):
        for y in range(lo[1], hi[1]):
            for z in range(lo[2], hi[2]):
                distance = sum(max(a+r-(p+.5), 0, p+.5-(b-r))**2
                               for p, a, b in zip((x,y,z), lo, hi))
                if distance <= r*r:
                    v[x,y,z] = color


def lantern(v, x, y, z, glow='glow_warm'):
    rounded(v, (x-2,y,z-2), (x+2,y+5,z+2), 'brass', 1)
    box(v, x-2,y+1,z-1,x+2,y+4,z+1,glow)
    box(v, x-1,y+1,z-2,x+1,y+4,z+2,glow)
    box(v, x-1,y+5,z-1,x+1,y+6,z+1,'gold')


def chassis(v, w, h, half, color, ground=False):
    rounded(v, (-w,3,-half), (w,h,half), color)
    rounded(v, (-w+1,2,-half+1), (w-1,5,half-1), 'brass', 2)
    # Flat brass bumpers establish the exact advertised length.
    for z in (-half, half-1):
        box(v,-w+4,5,z,w-4,7,z+1,'gold')
        for x in (-w+3,w-6):
            box(v,x,7,z,x+3,9,z+1,'glow_warm' if z<0 else 'glow_rose')
    for s in (-1,1):
        x = -w if s<0 else w-1
        box(v,x,4,-half+6,x+1,5,half-6,'glow_mint')
    if ground:
        for x in (-w,w):
            for z in (-half+9,half-9):
                art.ell(v,(x,4,z),(2,4,4),'plum')
                art.ell(v,(x+(-1 if x<0 else 1),4,z),(1,2,2),'brass')
    else:
        for x in (-w+3,w-3):
            for z in (-half+9,half-9):
                rounded(v,(x-3,0,z-4),(x+3,4,z+4),'brass',1)
                box(v,x-2,0,z-3,x+2,1,z+3,'glow_violet')
        for x in (-w+4,w-7):
            box(v,x,4,half-1,x+3,7,half,'glow_mint')


def bubble(v, w, y, front, rear):
    art.ell(v,(0,y,(front+rear)/2),(w,7,(rear-front)/2),'glow_blue')
    # Opaque brass ribs divide the lit bubble into window panes.
    for p in list(v):
        x, py, z = p
        if v[p]=='glow_blue' and (x in (-1,0) or z in (front+4,rear-5)):
            v[p]='brass'


def car(name, color, half=23, sports=False, ground=False):
    v={}; w=10
    chassis(v,w,11,half,color,ground)
    bubble(v,8,11,-half+9,half-6)
    box(v,-1,10,-half+3,1,12,-half+9,'gold')
    for s in (-1,1):
        x=-w if s<0 else w-1
        box(v,x,9,-half+7,x+1,10,half-5,'gold')
        if sports:
            art.polygon(v,[(s*7,9),(s*12,16),(s*12,8)],half-11,half-2,color)
            box(v,min(s*12,s*11),15,half-8,max(s*12,s*11),16,half-3,'glow_rose')
    if name=='sky_taxi':
        for x in (-10,9):
            for z in range(-half+6,half-5):
                for y in (7,8):
                    v[x,y,z]='cream' if (z//2+y)%2 else 'plum'
        rounded(v,(-4,17,-3),(4,21,3),'brass',1)
        box(v,-3,18,-3,3,20,-2,'glow_warm')
    if name=='sky_police':
        box(v,-7,17,-2,7,18,2,'brass')
        lantern(v,-5,18,0,'glow_blue'); lantern(v,5,18,0,'glow_warm')
        for x in (-10,9):
            box(v,x,7,-9,x+1,10,10,'blue')
            box(v,x,8,-1,x+1,10,1,'gold')
    return v


def cabin(v,w,y0,y1,z0,z1,color,decks=1):
    rounded(v,(-w,y0,z0),(w,y1,z1),color,3)
    for y in range(y0+3,y1-3,9 if decks>1 else max(y1-y0,1)):
        for x in (-w,w-1):
            for z in range(z0+5,z1-5,8):
                box(v,x,y-1,z-1,x+1,min(y+6,y1-2),z+6,'brass')
                box(v,x,y,z,x+1,min(y+5,y1-3),z+5,'glow_warm')
    box(v,-w+3,y0+3,z0,w-3,y0+9,z0+1,'glow_blue')
    box(v,-1,y0+3,z0,1,y0+9,z0+1,'brass')
    rounded(v,(-w+1,y1-2,z0+1),(w-1,y1+1,z1-1),'brass',2)
    rounded(v,(-w+2,y1-1,z0+2),(w-2,y1+2,z1-2),color,2)


def large(name):
    v={}
    half={'sky_van':28,'sky_bus':60,'sky_hauler':50,
          'ground_truck':30,'ground_tram':50}[name]
    color={'sky_van':'violet','sky_bus':'teal','sky_hauler':'mint',
           'ground_truck':'rose','ground_tram':'amber'}[name]
    ground=name.startswith('ground')
    chassis(v,13,12,half,color,ground)
    if name=='sky_hauler':
        # Raise the flying tug above its suspended cargo.
        v={(x,y+23,z):c for (x,y,z),c in v.items()}
        cabin(v,11,33,47,-half+2,-half+25,color)
        rounded(v,(-10,0,-12),(10,18,half-7),'timber',1)
        for z in range(-11,half-7,7):
            box(v,-10,1,z,10,17,z+1,'wood')
        for z in (-10,half-10):
            box(v,-11,0,z,11,2,z+2,'brass')
            for x in (-10,9):
                box(v,x,0,z,x+1,31,z+2,'brass')
        for x in (-11,10):
            box(v,x,2,-10,x+1,16,-8,'glow_warm')
        return v
    top=34 if name=='sky_bus' else 25
    cabin(v,12,10,top,-half+2,half-2,color,2 if name=='sky_bus' else 1)
    if name=='sky_van':
        # Parcel pictogram: glowing square, ribbon, and fold on both sides.
        for x in (-13,12):
            box(v,x,13,-3,x+1,23,15,'violet')
            box(v,x,15,1,x+1,22,11,'glow_warm')
            box(v,x,15,5,x+1,22,7,'brass')
            box(v,x,18,1,x+1,19,11,'brass')
    if name=='ground_truck':
        # Serving hatch, timber counter, striped luminous scalloped awning.
        box(v,12,12,-5,13,22,18,'plum')
        box(v,12,14,-3,13,20,16,'glow_warm')
        box(v,12,12,-6,18,14,19,'timber')
        for z in range(-7,21):
            box(v,12,22,z,19,24,z+1,'cream' if (z//3)%2 else 'rose')
            box(v,18,21,z,19,22,z+1,'glow_warm')
        for z in (-3,5,13):
            art.ell(v,(15,14,z),(2,1,2),'amber')
        lantern(v,-5,27,3,'glow_mint'); lantern(v,5,27,3,'glow_rose')
    if name=='ground_tram':
        for x in (-6,5):
            art.line(v,(x,27,-11),(x,36,0),'brass')
            art.line(v,(x,36,0),(x,29,11),'brass')
        box(v,-8,36,-2,8,38,2,'gold')
        for x in (-12,11):
            for z in (-half+12,half-16):
                box(v,x,7,z,x+1,23,z+4,'wood')
                box(v,x,14,z+1,x+1,21,z+3,'glow_warm')
    return v


def bike():
    v={}
    rounded(v,(-3,3,-12),(3,8,12),'teal',2)
    for z in (-8,8):
        rounded(v,(-5,0,z-3),(5,4,z+3),'brass',2)
        box(v,-3,0,z-2,3,1,z+2,'glow_mint')
    rounded(v,(-3,8,0),(3,10,8),'seat',1)
    rounded(v,(-3,7,-10),(3,12,-4),'teal',2)
    box(v,-2,9,-12,2,11,-11,'glow_warm')
    box(v,-2,5,11,2,7,12,'glow_rose')
    art.line(v,(0,10,-5),(0,14,-3),'brass')
    box(v,-6,14,-4,6,15,-2,'wood')
    for x in (-6,4):
        box(v,x,14,-4,x+2,15,-2,'glow_rose')
    box(v,-6,5,1,6,6,4,'brass')
    return v


def gondola():
    v={}
    rounded(v,(-8,0,-22),(8,8,22),'wood',3)
    rounded(v,(-7,5,-23),(7,9,23),'brass',2)
    box(v,-5,7,-18,5,9,18,'seat')
    for z in (-13,13):
        box(v,-6,9,z,6,11,z+3,'timber')
        for x in (-7,6):
            box(v,x,8,z,x+1,30,z+1,'brass')
    art.ell(v,(0,36,0),(16,19,30),'violet')
    # Alternating peach and rose balloon gores, with slender brass seams.
    for p in list(v):
        x,y,z=p
        if y>=17 and v[p]=='violet':
            angle=math.atan2(x/16,z/30)
            stripe=int((angle+math.pi)*12/(2*math.pi))
            v[p]=('rose','cream','violet')[stripe%3]
            if x in (-1,0): v[p]='brass'
            if y in (35,36): v[p]='gold'
    for x in (-10,10):
        for z in (-17,17):
            art.line(v,(x,20,z),(x,12,z),'brass')
            lantern(v,x,7,z)
    box(v,-2,54,-2,2,57,2,'brass')
    box(v,-1,57,-1,1,59,1,'glow_mint')
    return v


def parse_vox(data):
    assert data[:8]==b'VOX '+struct.pack('<I',150)
    assert data[8:12]==b'MAIN'
    assert struct.unpack_from('<I',data,16)[0]==len(data)-20
    offset=20; size=None; points={}
    while offset<len(data):
        tag,n,children=struct.unpack_from('<4sII',data,offset)
        assert children==0
        chunk=data[offset+12:offset+12+n]
        if tag==b'SIZE': size=struct.unpack('<III',chunk)
        if tag==b'XYZI':
            count=struct.unpack_from('<I',chunk)[0]
            assert len(chunk)==4+count*4
            for i in range(count):
                x,y,z,c=chunk[4+4*i:8+4*i]
                assert c and all(0<=q<s for q,s in zip((x,y,z),size))
                assert (x,y,z) not in points
                points[x,y,z]=c
        if tag==b'RGBA': assert len(chunk)==1024
        offset+=12+n
    assert offset==len(data) and size and points
    return size,points


def encoded(v,lo,size):
    class Sink:
        def write_bytes(self,data): self.data=data
    sink=Sink()
    art.write(sink,v,PALETTE,lo,size)
    return sink.data


def main():
    designs=[
        ('sky_taxi',4.5,car('sky_taxi','amber'),'Amber checker taxi with bubble canopy'),
        ('sky_sedan',4.5,car('sky_sedan','rose'),'Rose bubble sedan with brass ribs'),
        ('sky_sports',4.2,car('sky_sports','teal',21,True),'Teal coupe with swept rear fins'),
        ('sky_police',4.6,car('sky_police','cream'),'Cream patrol car with blue and warm lanterns'),
        ('sky_van',5.5,large('sky_van'),'Violet delivery van with parcel pictograms'),
        ('sky_bus',12.0,large('sky_bus'),'Double-deck teal sky tram with warm window rows'),
        ('sky_hauler',10.0,large('sky_hauler'),'Mint cargo tug with suspended timber crate'),
        ('sky_bike',2.4,bike(),'Teal hover bike with empty plum seat'),
        ('sky_gondola',6.0,gondola(),'Rose cream and violet balloon with lantern gondola'),
        ('ground_cab',4.0,car('ground_cab','mint',20,ground=True),'Rounded mint street cab with brass wheel hubs'),
        ('ground_truck',6.0,large('ground_truck'),'Rose food truck with striped glowing awning'),
        ('ground_tram',10.0,large('ground_tram'),'Amber timber street tram with brass pantograph'),
    ]
    outputs={}; records=[]
    for name,length,v,description in designs:
        # Center every complete silhouette, including asymmetric serving awnings.
        low,span=art.bounds(v)
        shift=(-(2*low[0]+span[0])//2,-low[1],-(2*low[2]+span[2])//2)
        v={tuple(p[i]+shift[i] for i in range(3)):c for p,c in v.items()}
        low,span=art.bounds(v)
        width=2*max(-low[0],low[0]+span[0])
        depth=2*max(-low[2],low[2]+span[2])
        lo=(-width//2,0,-depth//2); size=(width,span[1],depth)
        assert max(size)<=256 and min(p[1] for p in v)==0
        unit=length/depth
        solid={p:c for p,c in v.items() if not c.startswith('glow_')}
        glow={p:c for p,c in v.items() if c.startswith('glow_')}
        base=encoded(solid,lo,size); emissive=encoded(glow,lo,size)
        bs,bp=parse_vox(base); gs,gp=parse_vox(emissive)
        assert bs==gs==(depth,width,span[1]) and not bp.keys() & gp.keys()
        assert len(bp)==len(solid) and len(gp)==len(glow)
        metadata=dict(voxel_size=unit,length_m=length,width_m=width*unit,
                      height_m=span[1]*unit,kind='sky' if name.startswith('sky') else 'ground',front='-z')
        folder=Path('vehicles')/name
        outputs[folder/'model.vox']=base
        outputs[folder/'model_glow.vox']=emissive
        outputs[folder/'vehicle.json']=(json.dumps(metadata,indent=2)+'\n').encode()
        records.append(dict(id=name,description=description,folder=folder.as_posix(),
                            **metadata,frame_min=list(lo),frame_size=list(size),
                            solid_voxels=len(solid),glow_voxels=len(glow)))
    manifest=dict(planet='Vesperis, the Lantern City',generator='tools/make_city_vehicles.py',
                  coordinates='Game XYZ, Y up, front -Z; VOX file axes are ZXY',
                  origin='Centered X/Z, bottom Y=0. Shared base/glow frame_min is in game voxels.',
                  vehicles=records)
    outputs[Path('vehicles/city_vehicles_manifest.json')]=(json.dumps(manifest,indent=2)+'\n').encode()
    # Preflight the whole set before creating anything. Reruns only verify.
    for path,data in outputs.items():
        target=ROOT/path
        if target.exists() and target.read_bytes()!=data:
            raise FileExistsError(f'Refusing to change existing file: {path}')
    created=0
    for path,data in outputs.items():
        target=ROOT/path
        if not target.exists():
            target.parent.mkdir(parents=True,exist_ok=True)
            with target.open('xb') as stream: stream.write(data)
            created+=1
        assert target.read_bytes()==data
    for item in records:
        print(f"{item['id']}: {item['length_m']:g} m, frame {item['frame_size']}, "
              f"{item['solid_voxels']} solid + {item['glow_voxels']} glow")
    print(f'Validated 12 vehicles, 24 VOX files and 12 metadata files; created {created} outputs.')


if __name__=='__main__':
    main()
