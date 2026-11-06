#!/usr/bin/env python3
"""Four articulated dungeon bosses, sculpted on the existing coarse 32-cell grid.

Writes editable masters and nearest-neighbour x8 runtime parts, not renders.
Forward is -Z. Weapon grips and nested joints use the same local coordinates
as CreatureModel. The old assets are backed up before replacing these four rigs.
"""
import datetime
import json
import shutil
from pathlib import Path

import redesign_pixel_bosses as a

ROOT = Path(__file__).resolve().parents[1]


class Sculpt:
    def __init__(self):
        self.parts = {"body": {}}
        self.limbs = {}
        self.origins = {}

    def joint(self, name, pivot, role, phase=1, parent=None):
        self.parts[name] = {}
        self.origins[name] = pivot
        relative = pivot
        if parent:
            relative = tuple(pivot[k] - self.origins[parent][k] for k in range(3))
        self.limbs[name] = a.limb(name, relative, role, phase, throws=False,
                                  **({"parent_limb": parent} if parent else {}))
        return self.parts[name]

    def finish(self, name, title, theme, style, unit, forms, hand):
        # Work in world coarse cells when sculpting; export joint-local cells.
        parts = {key: a.part(v, self.origins[key]) if key in self.origins else v
                 for key, v in self.parts.items()}
        swaps = {}
        for form, colors in forms.items():
            swaps[form] = {}
            for key in ["body", "head", "jaw", "carapace"]:
                if key not in parts:
                    continue
                variant = key + "_" + form
                parts[variant] = a.recolor(parts[key], colors)
                swaps[form][key] = variant
        a.save(name, title, theme, parts, self.limbs, swaps, hand, unit=unit)
        for source in [False, True]:
            folder = a.OUT / name / ("source_32" if source else "")
            path = folder / "rig.json"
            rig = json.loads(path.read_text())
            rig.update(animation_style=style, bob=0.018 if style in ["cantor", "vizier"] else 0.0,
                       glow_strength=1.25, hand_limb="arm_r")
            # The hand point is relative to the weapon arm, not the root.
            rig["hand"] = [q * (1 if source else 8) for q in hand]
            path.write_text(json.dumps(rig, indent=2) + "\n")


def tube(v, points, radii, color):
    """Overlapping coarse ellipsoids: curved volumes with an actual underside."""
    for index, (start, end) in enumerate(zip(points, points[1:])):
        distance = max(abs(end[k] - start[k]) for k in range(3))
        for step in range(distance * 2 + 1):
            t = step / max(1, distance * 2)
            center = tuple(start[k] + (end[k] - start[k]) * t for k in range(3))
            radius = radii[index] * (1 - t) + radii[index + 1] * t
            a.ell(v, center, (radius, radius, radius), color)


def slash(v, points, color, width=1):
    for start, end in zip(points, points[1:]):
        a.line(v, start, end, color, width)


def cantor():
    a.PAL["blue"].update(base=(34,69,84), light=(95,139,151), shade=(21,38,58),
                         belly=(46,87,110), bone=(172,199,188), dark=(10,21,34),
                         wing=(30,53,74), accent=(61,123,126),
                         glow_eye=(169,247,220), glow_core=(58,174,222))
    s = Sculpt()
    b = s.parts["body"]
    # A hunched rib cage, open flooded belly and a segmented spine around back.
    a.ell(b, (0,18,1), (5,7,5), "shade")
    a.ell(b, (0,15,0), (4,5,4), "dark")
    for y in range(13,24,2):
        a.box(b, (-1,y,4), (2,y+1,6), "bone")
    for side in [-1,1]:
        for y in [15,18,21]:
            slash(b, [(0,y+1,-4),(side*3,y+1,-4),(side*5,y,0),(side*3,y,4)], "bone")
        slash(b, [(side*4,23,1),(side*7,24,3),(side*8,21,5)], "light", 2)
        a.box(b, (side*3-1,20,4), (side*3+1,23,6), "accent")
    a.diamond(b, (0,18,-4), 2,3,"glow_core")
    # Torn, volumetric lower vestments. Holes remain holes from every angle.
    for side in [-1,1]:
        r = s.joint("robe_"+str(side), (side*3,14,2), "cloth", side)
        a.polygon(r, [(side*2,14),(side*6,12),(side*8,4),(side*5,6),
                      (side*5,2),(side*2,7)], 0,4,"wing")
        slash(r, [(side*4,12,0),(side*6,7,0),(side*5,5,0)], "accent")
    # An abyssal bell-skull, with separate hanging lower jaw and rear gills.
    h = s.joint("head", (0,24,0), "head")
    a.ell(h, (0,25,0), (4,4,4), "shade")
    a.ell(h, (0,25,-2), (3,3,4), "bone")
    a.box(h, (-3,24,-6), (3,26,-4), "dark")
    for side in [-1,1]:
        a.box(h, (side*2-1,25,-6), (side*2+1,26,-5), "glow_eye")
        slash(h, [(side*3,26,0),(side*5,29,1),(side*5,30,3)], "light")
        for y in [24,26]:
            a.box(h, (side*3-1,y,2), (side*3+1,y+1,5), "accent")
    slash(h, [(-2,28,2),(0,30,3),(2,28,2)], "bone")
    j = s.joint("jaw", (0,24,-1), "jaw", parent="head")
    a.ell(j, (0,22,-3), (3,2,3), "shade")
    a.box(j, (-3,22,-6), (3,23,-4), "bone")
    for x in [-2,0,2]:
        a.box(j, (x,23,-6), (x+1,24,-5), "bone")
    a.box(j, (-1,22,-6), (1,23,-5), "glow_core")
    # Arms are outside the ribs. The right grip carries an entire offset bell staff.
    for side, label in [(-1,"l"),(1,"r")]:
        v = s.joint("arm_"+label, (side*7,21,0), "arm", -side)
        tube(v, [(side*7,21,0),(side*9,18,-1),(side*10,14,-3)], [2,1.6,1.3], "light")
        a.ell(v, (side*8,20,1), (3,2,3), "wing")
        for digit in range(3):
            slash(v, [(side*(9+digit),15,-3),(side*(9+digit),12,-4),
                      (side*(9+digit),12,-5)], "bone")
        if side == 1:
            a.line(v, (11,5,-4), (11,27,-4), "bone")
            a.line(v, (11,6,-3), (11,26,-3), "accent")
            a.ell(v, (11,26,-4), (3,3,3), "shade")
            a.box(v, (8,23,-7), (15,24,-1), "light")
            a.box(v, (9,24,-6), (14,25,-2), "accent")
            a.box(v, (10,22,-5), (12,24,-3), "glow_eye")
            a.diamond(v, (11,29,-4),1,2,"glow_core")
    # Two long articulated eel-like vestment tails curling around the deep back.
    for side in [-1,1]:
        t = s.joint("tail_"+str(side), (side*2,12,3), "tail", side)
        tube(t, [(side*2,12,3),(side*4,8,7),(side*7,5,9)], [2.5,2,1.5], "base")
        slash(t, [(side*2,12,5),(side*4,8,9),(side*7,5,10)], "accent")
        tip = s.joint("tail_tip_"+str(side), (side*7,5,9), "tail_tip", side,
                      parent="tail_"+str(side))
        tube(tip, [(side*7,5,9),(side*10,3,7),(side*10,2,3),(side*8,3,1)],
             [1.5,1.3,1,.6],"wing")
        slash(tip, [(side*8,5,9),(side*11,3,7),(side*11,2,3)], "glow_core")
    s.finish("drowned_cantor", "Drowned Cantor", "blue", "cantor", .029,
             {"resonant":{"accent":"glow_core"},
              "unbound":{"bone":"light","accent":"glow_eye","belly":"glow_core"}}, (4,-7,-4))


def vizier():
    a.PAL["gold"].update(base=(164,113,40), light=(233,190,82), shade=(82,62,43),
                         belly=(66,112,112), bone=(209,195,144), dark=(19,29,39),
                         wing=(27,65,74), accent=(56,155,148),
                         glow_eye=(255,224,127), glow_core=(236,127,73))
    s = Sculpt(); b = s.parts["body"]
    # An upright mummified oracle rising out of a heavy, truly round serpent coil.
    tube(b, [(0,5,1),(0,11,1),(0,18,1),(0,21,0)], [4,3,4.2,3.5], "wing")
    for y in range(8,22,3):
        a.ell(b, (0,y,-1), (3,1.2,3), "belly")
        a.box(b, (-2,y,-4), (2,y+1,-3), "light")
    a.ell(b, (0,20,1), (5,3,4), "base")
    for side in [-1,1]:
        slash(b, [(side*1,21,-3),(side*4,18,-3),(side*3,15,-3)], "light")
        a.box(b, (side*3,17,3), (side*3+1,21,5), "accent")
    a.diamond(b, (0,18,-4),2,2,"glow_core")
    # Back hood has a convex, striped shell, with inset turquoise scale panels.
    hood = s.joint("carapace", (0,22,3), "hood")
    for y,width in [(19,4),(20,6),(21,7),(22,8),(23,8),(24,7),(25,6),(26,4)]:
        a.ell(hood, (0,y,3), (width,1.1,3.5), "base")
        for side in [-1,1]:
            a.box(hood, (side*(width-1),y,1), (side*(width-1)+1,y+1,5),
                  "light" if y%2 else "accent")
    for y in [20,22,24]:
        slash(hood, [(-4,y,5),(0,y+1,6),(4,y,5)], "light")
    h = s.joint("head", (0,23,0), "head")
    a.ell(h, (0,25,-1), (3,3,4), "shade")
    a.ell(h, (0,24,-3), (3,2,3), "base")
    a.box(h, (-3,25,-5), (3,26,-4), "dark")
    for side in [-1,1]:
        a.box(h, (side*2-1,25,-6), (side*2+1,26,-5), "glow_eye")
        slash(h, [(side*2,26,-3),(side*2,28,-2),(side*1,29,-1)], "light")
    a.diamond(h, (0,28,-3),1,2,"glow_core")
    j = s.joint("jaw", (0,24,-2), "jaw", parent="head")
    a.box(j, (-2,22,-5), (2,23,-1), "bone")
    for x in [-2,1]:
        a.box(j, (x,23,-5), (x+1,24,-4), "bone")
    slash(j, [(0,22,-5),(0,21,-7),(-1,21,-8)],"glow_core")
    # Curving arms, asymmetric claws and a crescent staff held away from the hood.
    for side, label in [(-1,"l"),(1,"r")]:
        v = s.joint("arm_"+label, (side*6,20,0), "arm", -side)
        tube(v, [(side*6,20,0),(side*8,17,-1),(side*9,14,-3)], [2,1.2,1.4],"base")
        a.ell(v, (side*7,20,1),(2.7,2,3),"light")
        for digit in [-1,0,1]:
            slash(v, [(side*9+digit,15,-3),(side*10+digit,12,-4),
                      (side*10+digit,12,-5)], "bone")
        for y in [16,18]:
            a.box(v, (side*8-1,y,-2), (side*8+1,y+1,0),"light")
        if side == 1:
            a.line(v, (11,4,-4),(11,24,-4),"shade")
            for y in range(6,23,4):
                a.box(v, (10,y,-5),(12,y+1,-3),"light")
            slash(v, [(11,22,-4),(14,24,-4),(14,27,-4),(12,29,-4)],"light",2)
            a.diamond(v,(11,26,-4),1,2,"glow_eye")
        else:
            a.diamond(v,(-10,12,-5),1,2,"glow_core")
    # Wide S-shaped coiled tail, split into actual delayed-animation joints.
    t = s.joint("tail", (0,7,2), "tail")
    tube(t, [(0,7,2),(-5,4,5),(-8,3,2),(-6,3,-3),(0,3,-5)], [3,3,2.8,2.4,2.2],"base")
    tip = s.joint("tail_tip", (0,3,-5), "tail_tip", parent="tail")
    tube(tip, [(0,3,-5),(6,3,-3),(8,3,3),(5,3,9),(-1,3,11),(-5,4,9)],
         [2.2,2,1.8,1.6,1.1,.6],"wing")
    for x,y,z in [(-7,5,2),(-5,5,-2),(0,5,-5),(5,5,-3)]:
        a.box(t if x<=0 else tip,(x,y,z),(x+1,y+1,z+2),"light")
    for x,y,z in [(7,4,3),(5,4,8),(0,4,10),(-4,5,9)]:
        a.diamond(tip,(x,y,z),1,1,"accent")
    s.finish("gilded_vizier", "Gilded Vizier", "gold", "vizier", .026,
             {"kindled":{"accent":"glow_core"},
              "unbound":{"accent":"glow_eye","belly":"accent","bone":"light"}}, (5,-6,-4))


def warden():
    a.PAL["fire"].update(base=(59,49,48), light=(118,83,61), shade=(32,31,40),
                         belly=(106,42,29), bone=(163,131,87), dark=(16,20,29),
                         wing=(72,47,44), accent=(174,69,27),
                         glow_eye=(255,214,106), glow_core=(246,92,24))
    s = Sculpt(); b = s.parts["body"]
    # A furnace beast, low and deep with a lava heart behind an iron rib grille.
    a.ell(b, (0,16,1), (6,7,6),"shade")
    a.ell(b, (0,16,-2), (4,5,4),"glow_core")
    for x in [-4,-2,0,2,4]:
        slash(b, [(x,12,-4),(x,16,-6),(x,20,-4)],"base")
    for y in [12,20]:
        a.box(b,(-4,y,-5),(5,y+1,-3),"light")
    a.ell(b,(0,11,1),(5,3,5),"base")
    shell = s.joint("carapace", (0,18,3),"carapace")
    a.ell(shell,(0,19,4),(7,7,6),"base")
    # Layered plates wrap over the back; open seams expose light from within.
    for y,width in [(14,6),(17,7),(20,6),(23,4)]:
        a.ell(shell,(0,y,6),(width,1.6,4),"shade")
        slash(shell,[(-width+1,y,7),(-2,y+1,9),(2,y+1,9),(width-1,y,7)],"light")
    slash(shell,[(-2,14,9),(-1,17,9),(1,19,9),(0,22,8)],"glow_core")
    for side in [-1,1]:
        for y,z in [(20,4),(23,3),(25,2)]:
            tube(shell,[(side*4,y,z),(side*5,y+3,z+1)], [1.8,.6],"shade")
            a.box(shell,(side*5-1,y+2,z),(side*5+1,y+3,z+2),"glow_core")
    # Small horned skull set forward of the furnace, not a square face on a slab.
    h = s.joint("head",(0,23,-1),"head")
    a.ell(h,(0,24,-2),(4,3,4),"base")
    a.ell(h,(0,23,-5),(3,2,2),"shade")
    for side in [-1,1]:
        slash(h,[(side*3,24,-2),(side*5,27,-1),(side*4,30,-2)],"bone",2)
        a.box(h,(side*2-1,24,-6),(side*2+1,25,-5),"glow_eye")
    a.box(h,(-1,25,-6),(1,26,-4),"light")
    j = s.joint("jaw",(0,23,-2),"jaw",parent="head")
    a.ell(j,(0,21,-4),(3,2,3),"wing")
    a.box(j,(-2,22,-6),(2,23,-5),"glow_core")
    for x in [-2,1]:
        a.box(j,(x,22,-7),(x+1,24,-6),"bone")
    # Four independent planted haunches, with ankles and hooked basalt toes.
    for side in [-1,1]:
        for row,z in [("front",-2),("back",5)]:
            key = "leg_"+row+str(side)
            leg = s.joint(key,(side*4,12,z),"leg",side*(1 if row=="front" else -1))
            tube(leg,[(side*4,12,z),(side*7,8,z+1),(side*8,6,z)], [2.5,2.2,1.7],"base")
            a.ell(leg,(side*7,8,z),(2.6,2.5,2.5),"shade")
            a.box(leg,(side*7-1,8,z-3),(side*7+1,10,z-2),"glow_core")
            foot = s.joint("knee_"+row+str(side),(side*8,6,z),"knee",side*(1 if row=="front" else -1),
                           parent=key)
            tube(foot,[(side*8,6,z),(side*8,2,z-1)], [1.7,2],"shade")
            a.ell(foot,(side*8,2,z-2),(3,2,3),"base")
            for digit in [-1,1]:
                slash(foot,[(side*8+digit,2,z-3),(side*8+digit,1,z-5)],"bone")
    for side,label in [(-1,"l"),(1,"r")]:
        v = s.joint("arm_"+label,(side*7,20,0),"arm",-side)
        tube(v,[(side*7,20,0),(side*10,17,-1),(side*10,13,-3)], [2.5,2,2.4],"base")
        a.ell(v,(side*8,20,1),(3,3,3),"shade")
        slash(v,[(side*7,22,0),(side*9,20,-2),(side*10,17,-3)],"glow_core")
        if side==1:
            a.line(v,(11,7,-4),(11,24,-4),"bone")
            a.ell(v,(11,25,-4),(4,3,4),"shade")
            a.box(v,(8,23,-7),(14,26,-6),"light")
            slash(v,[(10,23,-8),(11,25,-8),(13,26,-6)],"glow_core")
        else:
            for digit in [-1,1]:
                slash(v,[(-10+digit,14,-3),(-12+digit,11,-4),(-11+digit,10,-6)],"bone",2)
    # Basalt tail with an ember-filled, articulated spiked flail at its tip.
    t=s.joint("tail",(0,12,6),"tail")
    tube(t,[(0,12,6),(2,9,9),(4,6,11)], [2.5,2,1.5],"base")
    tip=s.joint("tail_tip",(4,6,11),"tail_tip",parent="tail")
    tube(tip,[(4,6,11),(7,4,11),(9,4,9)], [1.5,1.4,2.5],"shade")
    a.ell(tip,(9,4,9),(2.5,2.5,2.5),"glow_core")
    for delta in [(-3,0,0),(3,0,0),(0,3,0),(0,0,3)]:
        a.diamond(tip,(9+delta[0],4+delta[1],9+delta[2]),1,2,"base")
    s.finish("magma_warden", "Magma Warden", "fire", "warden", .029,
             {"kindled":{"belly":"glow_core","accent":"glow_core"},
              "unbound":{"accent":"glow_eye","light":"accent","glow_core":"glow_eye"}}, (4,-7,-4))


def king():
    a.PAL["void"].update(base=(48,52,65),light=(133,145,155),shade=(24,29,41),
                         belly=(68,55,68),bone=(205,209,190),dark=(10,14,23),
                         wing=(33,28,42),accent=(86,102,111),
                         glow_eye=(182,243,223),glow_core=(82,164,166))
    s = Sculpt(); b=s.parts["body"]
    # Wasted knight: rounded cuirass, exposed old ribs and layered angular plates.
    a.ell(b,(0,19,0),(4,6,3.5),"shade")
    a.ell(b,(0,20,-1),(4,4,3.5),"base")
    for side in [-1,1]:
        for y in [17,19,21]:
            slash(b,[(0,y+1,-4),(side*3,y,-4),(side*4,y,0)],"light")
        slash(b,[(side*3,22,-2),(side*5,23,0),(side*4,24,3)],"accent",2)
    a.box(b,(-1,15,-3),(1,23,-2),"dark")
    a.diamond(b,(0,20,-4),1,3,"glow_core")
    a.ell(b,(0,14,0),(4,2.5,3),"base")
    for x in [-3,-1,1,3]:
        a.box(b,(x,14,-4),(x+1,15,-3),"bone")
    # A deep hood and battered crown encase a narrow skull with hollow eyes.
    h=s.joint("head",(0,24,0),"head")
    a.ell(h,(0,26,0),(4,4,4),"wing")
    a.ell(h,(0,25,-2),(3,3,3),"dark")
    a.ell(h,(0,25,-4),(2.5,2.7,1.8),"bone")
    for side in [-1,1]:
        a.box(h,(side*2-1,25,-6),(side*2+1,26,-5),"dark")
        a.box(h,(side*2-1,25,-7),(side*2,26,-6),"glow_eye")
        slash(h,[(side*3,25,-3),(side*4,28,-2),(side*3,31,-1)],"light")
    a.box(h,(-1,24,-6),(1,25,-5),"dark")
    slash(h,[(-3,28,-3),(0,29,-4),(3,28,-3)],"accent")
    a.line(h,(0,28,2),(0,31,2),"light")
    j=s.joint("jaw",(0,24,-2),"jaw",parent="head")
    a.box(j,(-2,22,-5),(2,23,-3),"shade")
    for x in [-2,0,1]:
        a.box(j,(x,23,-6),(x+1,24,-5),"bone")
    # Pauldrons and gauntlets are asymmetric, blade arm kept well outside the torso.
    for side,label in [(-1,"l"),(1,"r")]:
        v=s.joint("arm_"+label,(side*6,22,0),"arm",-side)
        tube(v,[(side*6,22,0),(side*8,18,0),(side*8,15,-2)],[2,1.4,1.6],"base")
        a.ell(v,(side*6,22,0),(3,2.5,3),"shade")
        slash(v,[(side*4,24,0),(side*6,25,1),(side*9,23,1)],"light",2)
        slash(v,[(side*8,19,-2),(side*9,16,-3),(side*8,14,-3)],"accent")
        for digit in [-1,0,1]:
            slash(v,[(side*8+digit,15,-2),(side*9+digit,13,-3),(side*9+digit,13,-4)],"bone")
        if side==1:
            # A long executioner's sword, serrated and channelled with ghost light.
            a.line(v,(11,10,-3),(11,17,-3),"dark",2)
            a.line(v,(8,16,-3),(14,16,-3),"bone")
            a.polygon(v,[(10,17),(9,21),(10,27),(11,30),(13,27),(14,20),(12,17)],-4,-2,"shade")
            slash(v,[(10,18,-5),(10,23,-5),(11,28,-5)],"light")
            slash(v,[(12,18,-5),(12,22,-5),(11,26,-5)],"glow_core")
            for y in [20,24]:
                a.box(v,(13,y,-4),(15,y+1,-2),"light")
        else:
            a.diamond(v,(-9,13,-4),1,2,"glow_core")
    # Bent, separate hips, knees and sabatons, needed for throne and death poses.
    for side,label in [(-1,"l"),(1,"r")]:
        leg=s.joint("leg_"+label,(side*2,13,0),"leg",-side)
        tube(leg,[(side*2,13,0),(side*3,8,-1)],[1.8,1.5],"shade")
        a.ell(leg,(side*3,8,-1),(2,2,2),"base")
        a.box(leg,(side*3-1,8,-4),(side*3+1,10,-3),"light")
        knee=s.joint("knee_"+label,(side*3,8,-1),"knee",-side,parent="leg_"+label)
        tube(knee,[(side*3,8,-1),(side*3,2,0)],[1.5,1.3],"base")
        a.ell(knee,(side*3,1.5,-2),(2,1.5,3),"shade")
        slash(knee,[(side*3,7,-3),(side*3,3,-3),(side*3,1,-5)],"light")
    # Five independently hanging back strips wrap the shoulders, with empty gaps
    # and ripped hems. The side tabards drape over the thighs instead of hiding them.
    for x,length in [(-4,15),(-2,20),(0,18),(2,17),(4,13)]:
        c=s.joint("cape_"+str(x),(x,23,3),"cape",x/4 if x else .3)
        bottom=23-length
        a.polygon(c,[(x-1,23),(x+2,23),(x+3,15),(x+2,bottom+2),
                     (x+1,bottom),(x,bottom+4),(x-1,bottom+1)],3,5,"wing")
        slash(c,[(x,21,5),(x+1,16,6),(x+1,bottom+4,6)],"belly")
        for y in range(bottom+5,22,6):
            a.box(c,(x,y,5),(x+1,y+2,6),"accent")
    for side in [-1,1]:
        c=s.joint("tabard_"+str(side),(side*3,14,-2),"cloth",side)
        a.polygon(c,[(side*1,14),(side*4,14),(side*5,5),(side*3,3),
                     (side*3,6),(side*1,5)],-4,-2,"wing")
        slash(c,[(side*2,13,-5),(side*3,9,-5),(side*3,7,-5)],"accent")
    s.finish("hollow_king","The Hollow King","void","death_knight",.035,{},(5,-7,-3))


def main():
    backup=Path.home()/"tmp"/("dungeon_bosses_before_rework_"+
                             datetime.datetime.now().strftime("%Y%m%d_%H%M%S"))
    backup.mkdir(parents=True)
    for name in ["drowned_cantor","gilded_vizier","magma_warden","hollow_king"]:
        shutil.copytree(a.OUT/name,backup/name)
    shutil.copy2(a.OUT/"realm_boss_manifest.json",backup/"realm_boss_manifest.json")
    cantor(); vizier(); warden(); king()
    (a.OUT/"realm_boss_manifest.json").write_text(json.dumps(a.MANIFEST,indent=2)+"\n")
    print("Previous assets saved in",backup,flush=True)


if __name__ == "__main__":
    main()
