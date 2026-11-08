#!/usr/bin/env python3
"""Create Vesperis props. Run: python3 tools/make_city_props.py

Create-only: refuses to overwrite any output. --validate checks existing exports.
Coordinates are game XYZ, +Y up, front -Z. The shared writer stores VOX ZXY.
Frames are symmetric on X/Z with their bottom at Y=0. Glow is disjoint from
the base and always exported, even when empty. No external packages required.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import struct
import sys

sys.dont_write_bytecode = True
import redesign_pixel_bosses as vox

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'props/city'
MANIFEST = OUT / 'city_props_manifest.json'
PALETTE = {
    'wood': (139, 76, 57), 'wood_light': (192, 119, 77),
    'wood_dark': (91, 48, 59), 'brass': (214, 163, 81),
    'gold': (250, 210, 124), 'plum': (98, 57, 112),
    'rose': (205, 108, 146), 'teal': (57, 137, 142),
    'mint': (140, 204, 168), 'cream': (248, 222, 177),
    'leaf': (64, 148, 116), 'leaf_light': (104, 188, 144),
    'soil': (80, 49, 64), 'glow_amber': (255, 192, 100),
    'glow_rose': (255, 141, 195), 'glow_teal': (100, 230, 220),
    'glow_violet': (195, 156, 255), 'glow_mint': (172, 255, 201),
}
IDS = ('sign_cafe sign_bar sign_noodles sign_shop sign_hotel sign_arcade '
       'holo_board street_lamp bench planter vending_machine coffee_machine '
       'beer_taps bar_stool cafe_table cafe_chair booth_sofa noodle_stall kiosk '
       'trash_bin air_vent ac_unit water_tank antenna pipe_bundle lantern_string '
       'arcade_cabinet potted_tree hydrant_fountain elevator_panel shelf_goods counter').split()

# Five by seven block lettering. Rows run top to bottom, columns left to right
# when viewed from -Z. The sign scale keeps all six words 3-4 metres wide.
FONT = {
    'A': ['01110','10001','10001','11111','10001','10001','10001'],
    'B': ['11110','10001','10001','11110','10001','10001','11110'],
    'C': ['01111','10000','10000','10000','10000','10000','01111'],
    'D': ['11110','10001','10001','10001','10001','10001','11110'],
    'E': ['11111','10000','10000','11110','10000','10000','11111'],
    'F': ['11111','10000','10000','11110','10000','10000','10000'],
    'H': ['10001','10001','10001','11111','10001','10001','10001'],
    'L': ['10000','10000','10000','10000','10000','10000','11111'],
    'N': ['10001','11001','11001','10101','10011','10011','10001'],
    'O': ['01110','10001','10001','10001','10001','10001','01110'],
    'P': ['11110','10001','10001','11110','10000','10000','10000'],
    'R': ['11110','10001','10001','11110','10100','10010','10001'],
    'S': ['01111','10000','10000','01110','00001','00001','11110'],
    'T': ['11111','00100','00100','00100','00100','00100','00100'],
    'U': ['10001','10001','10001','10001','10001','10001','01110'],
    ' ': ['00000'] * 7,
}
ICONS = {
    'cafe': ['000100000','001000000','000100000','111111100','011111011','011111001','011111110','001110000','111111110'],
    'bar': ['011110000','111111000','011110110','011110010','011110010','011110110','011110000','011110000','001100000'],
    'noodles': ['001001000','010010000','001001000','111111111','011111110','011111110','001111100','000111000','001111100'],
    'shop': ['000111000','001000100','001000100','011111110','010000010','010101010','010000010','010000010','011111110'],
    'hotel': ['100000000','100000000','101100000','111111110','111111110','111111111','100000001','100000001','000000000'],
    'arcade': ['000010000','000111000','111111111','011111110','001111100','011111110','011000110','110000011','000000000'],
}


class Model:
    def __init__(self):
        self.v = {}

    def box(self, a, b, color):
        vox.box(self.v, a, b, color)

    def ell(self, center, radius, color):
        vox.ell(self.v, center, radius, color)

    def line(self, a, b, color='brass', width=1):
        vox.line(self.v, a, b, color, width)

    def cyl(self, x, z, radius, y0, y1, color):
        for xx in range(math.floor(x-radius), math.ceil(x+radius)):
            for zz in range(math.floor(z-radius), math.ceil(z+radius)):
                if (xx+.5-x)**2+(zz+.5-z)**2 <= radius**2:
                    self.box((xx,y0,zz),(xx+1,y1,zz+1),color)

    def ring(self, x, z, radius, y, color, width=1):
        for xx in range(math.floor(x-radius), math.ceil(x+radius)):
            for zz in range(math.floor(z-radius), math.ceil(z+radius)):
                d = math.hypot(xx+.5-x,zz+.5-z)
                if radius-width <= d <= radius:
                    self.v[xx,y,zz] = color

    def panel(self, x0, y0, x1, y1, z, color='teal'):
        self.box((x0,y0,z),(x1,y1,z+3),'brass')
        self.box((x0+1,y0+1,z-1),(x1-1,y1-1,z),color)

    def text(self, word, x, y, z, color):
        for letter in word:
            self.pixels(FONT[letter],x,y,z,color)
            x += 6

    def pixels(self, rows, x, y, z, color):
        for row, pattern in enumerate(rows):
            for col, bit in enumerate(pattern):
                if bit == '1':
                    self.v[x+col,y+len(rows)-1-row,z] = color

    def legs(self, x, z, top, color='brass'):
        for xx in (-x,x-2):
            for zz in (-z,z-2):
                self.box((xx,0,zz),(xx+2,top,zz+2),color)

    def lantern(self, x, y, z, color='glow_amber', r=2):
        self.box((x-r,y,z-r),(x+r,y+1,z+r),'brass')
        self.box((x-r,y+1,z-r),(x+r,y+5,z+r),color)
        for xx in (x-r,x+r-1):
            for zz in (z-r,z+r-1):
                self.box((xx,y+1,zz),(xx+1,y+5,zz+1),'brass')
        self.ell((x,y+5,z),(r+1,2,r+1),'brass')
        self.line((x,y+6,z),(x,y+8,z),'wood_dark')


def sign(kind, color):
    m = Model()
    word = kind.upper()
    width = len(word)*6+15
    x = -width//2
    m.panel(x,0,x+width,15,0,'plum')
    m.box((x+2,1,-2),(x+width-2,2,-1),'wood_light')
    m.box((x+2,13,-2),(x+width-2,14,-1),'wood_light')
    m.pixels(ICONS[kind],x+3,3,-2,'glow_amber')
    m.text(word,x+14,4,-2,color)
    for xx in (x+2,x+width-3):
        m.box((xx,14,1),(xx+1,18,2),'brass')
    return m, round(3.6/(2*max(abs(x),abs(x+width))),8), False


def build(name):
    if name.startswith('sign_'):
        i = IDS.index(name)
        return sign(name[5:], ['glow_rose','glow_amber','glow_mint','glow_teal','glow_violet','glow_rose'][i])
    m = Model()
    unit, solid = .1, True
    if name == 'holo_board':
        m.panel(-30,0,30,35,0,'glow_teal')
        m.box((-27,3,-2),(27,32,-1),'plum')
        m.text('SHOP',-11,23,-3,'glow_rose')
        # Skyline graphic: stepped storybook towers and a crescent moon.
        for x,h in [(-24,8),(-18,12),(-12,7),(-6,15),(0,11),(6,17),(12,8),(18,13)]:
            m.box((x,5,-3),(x+4,h,-2),'glow_teal')
            m.ell((x+2,h,-2),(2,2,1),'glow_amber')
        m.ell((21,25,-2),(4,4,1),'glow_amber')
        m.ell((23,26,-2),(3,3,1),'plum')
        solid = False
    elif name == 'street_lamp':
        m.cyl(0,0,4,0,2,'brass'); m.cyl(0,0,3,2,5,'teal')
        m.cyl(0,0,1.5,5,38,'wood_dark')
        for y in (5,15,29,36): m.cyl(0,0,2,y,y+1,'brass')
        m.lantern(0,38,0,r=4)
        m.ell((0,44,0),(5,3,5),'teal')
        m.cyl(0,0,1,46,50,'brass')
        m.ring(0,0,7,37,'glow_rose'); m.line((-6,37,0),(6,37,0))
    elif name == 'bench':
        m.legs(9,4,5)
        for z in (-4,-1,2): m.box((-11,5,z),(11,6,z+2),'wood_light')
        for x in (-9,8): m.box((x,3,3),(x+1,13,4),'brass')
        for y in (8,11): m.box((-11,y,3),(11,y+2,5),'wood_light')
        for x in (-11,10): m.box((x,7,-4),(x+1,8,4),'brass')
    elif name in ('planter','potted_tree'):
        if name == 'planter':
            m.box((-10,0,-4),(10,6,4),'wood')
            m.box((-11,5,-5),(11,7,5),'brass')
            m.box((-9,6,-3),(9,7,3),'soil')
            for x in range(-8,9,4):
                m.box((x,1,-5),(x+1,5,-4),'wood_light')
                h = 12+(x%3)
                m.line((x,7,0),(x,h,0),'leaf')
                m.ell((x-1,10,0),(2,1,2),'leaf_light')
                for dx,dy in ((-1,0),(1,0),(0,1),(0,-1)):
                    m.ell((x+dx,h+dy,0),(1.3,1.3,1.3),'glow_rose')
                m.v[x,h,-1] = 'glow_amber'
        else:
            m.cyl(0,0,5,0,6,'teal'); m.cyl(0,0,6,5,7,'brass')
            m.cyl(0,0,4,6,7,'soil'); m.cyl(0,0,2,7,22,'wood')
            for x,y,z in [(-6,24,0),(5,26,2),(0,30,0),(0,23,-5)]:
                m.line((0,15,0),(x,y,z),'wood_light',2)
                m.ell((x,y,z),(6,5,5),'leaf')
                m.ell((x-1,y+2,z-1),(4,3,4),'leaf_light')
                m.ell((x-2,y-3,z-3),(1.5,2,1.5),'glow_amber')
    elif name == 'vending_machine':
        m.box((-7,0,-5),(7,23,5),'teal'); m.ell((0,22,0),(7,3,5),'teal')
        m.panel(-6,6,3,20,-6,'plum'); m.panel(3,10,6,17,-6,'glow_rose')
        for y in (8,12,16):
            m.box((-5,y-1,-7),(2,y,-6),'brass')
            for x,c in [(-4,'glow_amber'),(-1,'mint')]:
                m.box((x,y,-7),(x+2,y+2,-6),c)
        m.panel(-5,2,4,5,-6,'wood_dark')
        m.box((-4,22,-5),(4,23,-4),'glow_mint')
    elif name == 'coffee_machine':
        unit = .05
        m.box((-10,0,-6),(10,2,6),'brass')
        m.box((-9,2,1),(9,13,6),'teal'); m.ell((0,12,3),(9,3,3),'teal')
        for x in (-5,4):
            m.line((x,10,0),(x,6,-2),'brass',2)
            m.line((x,6,-2),(x+3,6,-2),'wood_dark')
            m.cyl(x,-3,2,2,5,'cream')
        m.line((8,11,-1),(8,4,-4),'brass')
        for x in (-4,0,4): m.v[x,11,0] = 'glow_amber'
        for x in range(-8,9,2): m.box((x,1,-5),(x+1,2,0),'wood_dark')
    elif name == 'beer_taps':
        unit = .05
        m.box((-14,0,-5),(14,2,5),'brass')
        for x in (-9,0,9):
            m.cyl(x,1,1.5,2,13,'brass')
            m.line((x,11,1),(x,11,-3),'brass',2)
            m.line((x,11,-3),(x,8,-3),'brass')
            m.box((x-1,12,-2),(x+2,17,0),'wood_dark')
            m.ell((x,16,-1),(2,2,1),['glow_amber','glow_rose','glow_mint'][(x+9)//9])
        for x in range(-12,13,3): m.box((x,1,-4),(x+1,2,-1),'wood_dark')
    elif name in ('bar_stool','cafe_table','cafe_chair'):
        if name == 'cafe_table':
            m.cyl(0,0,4,0,1,'brass'); m.cyl(0,0,1,1,8,'brass')
            m.cyl(0,0,6,8,9,'brass'); m.cyl(0,0,5.5,9,10,'wood_light')
            m.lantern(0,10,0,r=1)
        elif name == 'bar_stool':
            m.legs(3,3,8); m.ring(0,0,4,3,'brass')
            m.cyl(0,0,4,8,9,'brass'); m.cyl(0,0,4,9,11,'rose')
        else:
            m.legs(3,3,5); m.box((-4,5,-4),(4,6,4),'brass')
            m.box((-3,6,-3),(3,7,3),'mint')
            for x in (-4,3): m.box((x,5,3),(x+1,13,4),'brass')
            m.ell((0,11,3),(4,3,1),'teal')
    elif name == 'booth_sofa':
        # Semicircular booth open toward -Z, with a continuous upholstered back.
        unit = .05
        for x in range(-20,20):
            for z in range(-12,13):
                radius = math.hypot(x+.5,z+.5)
                if radius < 20 and (z >= 0 or abs(x+.5)>13):
                    m.box((x,0,z),(x+1,8,z+1),'wood_dark')
                    m.box((x,8,z),(x+1,11,z+1),'rose')
                    if radius > 16:
                        m.box((x,11,z),(x+1,23,z+1),'plum')
                        m.box((x,23,z),(x+1,24,z+1),'brass')
        for x in (-12,-6,0,6,12): m.v[x,16,12] = 'gold'
    elif name in ('noodle_stall','kiosk'):
        m.box((-15,0,-8),(15,10,8),'wood')
        for x in range(-14,15,4): m.box((x,1,-9),(x+1,9,-8),'wood_light')
        m.box((-16,10,-10),(16,12,9),'brass')
        for x in (-14,13):
            for z in (-7,6): m.box((x,12,z),(x+1,27,z+1),'wood_dark')
        for x in range(-17,17):
            for z in range(-12,11):
                y = 29-abs(z)//4
                m.box((x,y,z),(x+1,y+2,z+1),'cream' if (x+17)//4%2 else 'rose')
        for x in (-12,11): m.lantern(x,17,-7,r=2)
        if name == 'noodle_stall':
            for x in (-6,4):
                m.cyl(x,-2,4,12,16,'teal'); m.ring(x,-2,4,16,'brass')
                m.cyl(x,-2,3,16,17,'glow_amber')
                m.line((x+1,16,-2),(x+4,21,-2),'wood_light')
                for dy in range(4):
                    m.ell((x+(dy%2),18+dy*2,-2),(1,1.5,1),'cream')
            m.panel(-7,2,8,9,-10,'plum'); m.pixels(ICONS['noodles'],-4,1,-11,'glow_mint')
        else:
            m.panel(-11,13,3,24,7,'plum')
            for y in (15,18,21): m.box((-9,y,5),(0,y+1,6),'glow_mint')
            for x in (-10,-4,2,8):
                m.box((x,12,-7),(x+4,14,-2),'cream')
                m.box((x+1,14,-6),(x+3,15,-5),'teal')
            m.panel(-10,2,10,9,-10,'teal'); m.text('SHOP',-11,3,-11,'glow_amber')
    elif name == 'trash_bin':
        m.cyl(0,0,5,0,10,'teal'); m.ring(0,0,5,1,'brass')
        m.ell((0,10,0),(5,3,5),'brass')
        m.panel(-3,8,3,11,-5,'wood_dark')
        m.box((-1,4,-5),(1,6,-4),'glow_mint')
    elif name in ('air_vent','ac_unit'):
        if name == 'ac_unit':
            m.legs(9,6,2); m.box((-10,2,-7),(10,14,7),'teal')
            for y in range(4,12,2): m.box((6,y,-8),(9,y+1,-7),'brass')
            cx,cy,cz,r = -2,8,-8,5
            m.box((-9,14,-6),(9,15,6),'brass')
            for x in range(-8,9,3): m.box((x,15,-5),(x+1,16,5),'wood_dark')
        else:
            m.panel(-10,0,10,20,0,'teal')
            cx,cy,cz,r = 0,10,-2,8
            solid = False
        m.ell((cx,cy,cz),(r,r,1),'wood_dark')
        for angle in range(0,360,90):
            a = math.radians(angle)
            m.line((cx,cy,cz-1),(cx+round((r-2)*math.cos(a)),cy+round((r-2)*math.sin(a)),cz-1),'brass',2)
        m.ell((cx,cy,cz-2),(2,2,1),'rose')
        for yy in range(cy-r+1,cy+r,3):
            m.line((cx-r,yy,cz-3),(cx+r,yy,cz-3),'teal')
    elif name == 'water_tank':
        m.legs(8,8,6,'wood_dark'); m.cyl(0,0,11,6,25,'wood_light')
        for y in (6,12,23): m.cyl(0,0,11.5,y,y+1,'brass')
        m.ell((0,25,0),(12,5,12),'teal')
        m.cyl(0,0,2,28,32,'brass')
        for y in range(1,25,3): m.line((8,y,-10),(11,y,-10),'brass')
        for x in (8,11): m.line((x,0,-10),(x,26,-10),'brass')
        m.box((-2,8,-12),(0,21,-11),'glow_teal')
    elif name == 'antenna':
        m.cyl(0,0,5,0,2,'brass'); m.line((0,2,0),(0,13,2),'wood_dark',2)
        # Concave dish faces forward and upward, warm copper shell with pale face.
        for x in range(-9,9):
            for y in range(7,25):
                r2=(x+.5)**2+(y-16+.5)**2
                if r2<81:
                    z=round(r2/22)
                    m.v[x,y,z]='brass'; m.v[x,y,z-1]='cream'
        m.line((0,16,0),(0,16,-7),'brass')
        m.ell((0,16,-7),(2,2,2),'glow_rose')
        m.line((0,16,-7),(0,24,3),'brass')
        m.line((0,24,3),(0,28,3),'brass'); m.v[0,29,3]='glow_amber'
    elif name == 'pipe_bundle':
        for z,c in [(-4,'brass'),(0,'teal'),(4,'brass')]:
            m.box((-20,2,z-1),(20,4,z+1),c)
            for x in (-17,-8,8,17): m.box((x,1,z-2),(x+2,5,z+2),'gold')
        for x in (-14,13): m.box((x,0,-7),(x+2,1,7),'wood')
        for x,z in [(-7,-4),(7,4)]:
            m.line((x,3,z),(x,7,z),'brass')
            m.ring(x,z,3,7,'rose'); m.line((x-2,7,z),(x+2,7,z),'brass')
    elif name == 'lantern_string':
        for x in range(-30,30):
            y=9+round(5*(x/30)**2)
            m.v[x,y,0]='wood_dark'
        for i,x in enumerate(range(-25,26,10)):
            y=9+round(5*(x/30)**2)
            m.lantern(x,y-8,0,['glow_amber','glow_rose','glow_teal'][i%3],2)
        solid = False
    elif name == 'arcade_cabinet':
        m.box((-6,0,-5),(6,11,5),'plum')
        m.box((-6,10,0),(6,24,5),'rose')
        for x in (-6,5): m.box((x,11,-4),(x+1,25,5),'brass')
        m.panel(-5,14,5,22,-2,'glow_violet')
        m.box((-4,15,-4),(4,21,-3),'plum')
        m.pixels(['00100','01110','11111','01010','10001'],-2,16,-5,'glow_mint')
        m.box((-6,10,-7),(6,12,1),'teal')
        m.line((-3,12,-5),(-3,14,-5),'brass'); m.ell((-3,14,-5),(1.5,1.5,1.5),'rose')
        for x in (1,3): m.v[x,12,-5]='glow_amber'
        m.box((-5,23,-4),(5,25,-3),'glow_rose')
        m.panel(-2,3,2,6,-6,'wood_dark')
    elif name == 'hydrant_fountain':
        m.cyl(0,0,4,0,2,'brass'); m.cyl(0,0,2,2,9,'teal')
        m.ell((0,10,-1),(5,2,4),'brass'); m.ell((0,11,-1),(4,1,3),'glow_teal')
        m.line((0,8,2),(0,14,2),'brass',2); m.line((0,14,2),(0,14,-1),'brass')
        m.line((0,13,-1),(0,11,-2),'glow_teal')
        m.ell((3,9,1),(1.5,1.5,1.5),'rose')
    elif name == 'elevator_panel':
        unit, solid = .05, False
        m.panel(-5,0,5,24,0,'teal')
        for y,c in [(8,'glow_mint'),(16,'glow_rose')]:
            m.ell((0,y,-2),(3,3,1),'brass'); m.ell((0,y,-3),(2,2,1),c)
        m.pixels(['00100','01110','11111'],-2,20,-2,'glow_amber')
        m.pixels(['11111','01110','00100'],-2,1,-2,'glow_amber')
    elif name == 'shelf_goods':
        m.box((-10,0,3),(10,22,5),'wood_dark')
        for x in (-10,9): m.box((x,0,-4),(x+1,23,5),'wood_light')
        for y in (0,7,14,21): m.box((-10,y,-5),(10,y+1,5),'brass')
        for y in (1,8,15):
            for i,x in enumerate((-7,-2,4)):
                if i == 0:
                    m.cyl(x,0,2,y,y+4,'mint'); m.cyl(x,0,2,y+4,y+5,'brass')
                    m.v[x,y+2,-2]='glow_mint'
                elif i == 1:
                    m.box((x-1,y,-2),(x+3,y+5,2),'rose')
                    m.box((x,y+1,-3),(x+2,y+3,-2),'cream')
                else:
                    m.ell((x+1,y+2,0),(2,2,2),'teal')
                    m.line((x+1,y+3,0),(x+1,y+5,0),'brass')
                    m.v[x+1,y+2,-2]='glow_amber'
    elif name == 'counter':
        m.box((-14,0,-5),(14,11,5),'wood')
        for x in (-12,-4,4): m.panel(x,2,x+7,9,-6,'teal')
        m.box((-15,11,-7),(15,13,7),'wood_light')
        m.box((-15,11,-7),(15,12,-6),'brass')
        m.line((-14,3,-9),(13,3,-9),'brass')
        for x in (-12,11): m.line((x,3,-9),(x,3,-5),'brass')
    else:
        raise ValueError(name)
    return m, unit, solid


def prepare(name):
    m,unit,solid = build(name)
    # Shift bottom to zero and give both layers one symmetric, untrimmed frame.
    bottom = min(y for x,y,z in m.v)
    v = {(x,y-bottom,z):c for (x,y,z),c in m.v.items()}
    rx = max(max(x+1,-x) for x,y,z in v)
    rz = max(max(z+1,-z) for x,y,z in v)
    height = max(y for x,y,z in v)+1
    lo, size = (-rx,0,-rz), (2*rx,height,2*rz)
    assert all(0 < n <= 256 for n in size)
    base = {p:c for p,c in v.items() if not c.startswith('glow_')}
    glow = {p:c for p,c in v.items() if c.startswith('glow_')}
    meta = dict(voxel_size=unit,size_m=[round(n*unit,6) for n in size],solid=solid)
    return base,glow,lo,size,meta


def read_vox(path):
    data = path.read_bytes()
    assert data[:8] == b'VOX '+struct.pack('<I',150), path
    assert data[8:12] == b'MAIN', path
    assert struct.unpack_from('<II',data,12) == (0,len(data)-20), path
    offset, size, points, palette = 20,None,None,None
    while offset < len(data):
        tag,n,children = struct.unpack_from('<4sII',data,offset)
        assert children == 0
        payload = data[offset+12:offset+12+n]
        assert len(payload) == n
        if tag == b'SIZE': size=struct.unpack('<III',payload)
        elif tag == b'XYZI':
            count=struct.unpack_from('<I',payload)[0]
            assert len(payload) == 4+4*count
            points=[tuple(payload[i:i+4]) for i in range(4,len(payload),4)]
        elif tag == b'RGBA':
            assert n == 1024
            palette=[tuple(payload[i:i+4]) for i in range(0,n,4)]
        offset += 12+n
    assert offset == len(data) and size and points is not None and palette
    assert len(set(p[:3] for p in points)) == len(points)
    assert all(all(0 <= p[i] < size[i] for i in range(3)) and p[3]>0 for p in points)
    return size, {p[:3]:palette[p[3]-1][:3] for p in points}


def validate():
    manifest=json.loads(MANIFEST.read_text())
    assert [p['id'] for p in manifest['props']] == IDS
    total=0
    for record in manifest['props']:
        name=record['id']
        base,glow,lo,size,meta=prepare(name)
        folder=OUT/name
        assert json.loads((folder/'prop.json').read_text()) == meta
        assert record['frame_min'] == list(lo) and record['frame_size'] == list(size)
        occupied=set()
        for filename,expected in [('model.vox',base),('model_glow.vox',glow)]:
            path=folder/filename
            actual_size,actual=read_vox(path)
            assert actual_size == (size[2],size[0],size[1]), path
            expected_points={(z-lo[2],x-lo[0],y):PALETTE[c] for (x,y,z),c in expected.items()}
            assert actual == expected_points, path
            assert not occupied.intersection(actual), path
            occupied.update(actual)
            assert hashlib.sha256(path.read_bytes()).hexdigest() == record['sha256'][filename]
            total += len(actual)
        assert min(p[2] for p in occupied) == 0
        if name.startswith('sign_'):
            assert 3 <= meta['size_m'][0] <= 4 and glow
    print(f'Validated {len(IDS)} props, {len(IDS)*2} VOX files, {total:,} voxels: frames, palettes, geometry, origin, metadata and hashes match.')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--validate',action='store_true')
    args=parser.parse_args()
    if args.validate:
        validate()
        return
    targets=[MANIFEST]+[OUT/name/f for name in IDS for f in ('model.vox','model_glow.vox','prop.json')]
    collisions=[str(p.relative_to(ROOT)) for p in targets if p.exists()]
    if collisions:
        raise SystemExit('Create-only export refused existing files: '+', '.join(collisions))
    prepared={name:prepare(name) for name in IDS}
    manifest=dict(city='Vesperis, the Lantern City',generator='tools/make_city_props.py',
                  coordinates='Game XYZ: +Y up, front -Z; VOX file axes are ZXY',
                  origin='Centered frame on X/Z, bottom Y=0; both layers use the identical frame',
                  palette=PALETTE,requested_count=30,named_count=len(IDS),
                  note='The request enumerates 32 IDs; every named prop is included. Antenna beacon is static emissive; runtime blinking is not encoded in VOX.',props=[])
    for name,(base,glow,lo,size,meta) in prepared.items():
        folder=OUT/name
        folder.mkdir(parents=True,exist_ok=True)
        hashes={}
        for filename,points in [('model.vox',base),('model_glow.vox',glow)]:
            vox.write(folder/filename,points,PALETTE,lo,size)
            hashes[filename]=hashlib.sha256((folder/filename).read_bytes()).hexdigest()
        (folder/'prop.json').write_text(json.dumps(meta,indent=2)+'\n')
        manifest['props'].append(dict(id=name,path=f'props/city/{name}',**meta,
                                     frame_min=list(lo),frame_size=list(size),
                                     base_voxels=len(base),glow_voxels=len(glow),sha256=hashes))
    MANIFEST.write_text(json.dumps(manifest,indent=2)+'\n')
    validate()


if __name__ == '__main__':
    main()
