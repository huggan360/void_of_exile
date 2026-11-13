#!/usr/bin/env python3
"""Create-only: the Veiled Herald, the mini boss of Reach mission 6
(The Eye Behind the Stars), and its three projectiles.
Run: python3 tools/make_veil_herald.py, then godot --headless --import.

Reuses the planet boss pipeline (tools/make_planet_bosses.py): 64-cell parts
at x4, a rig with head, arms, robe tails and two rune halos, and two phase
variants ('unveiled', 'shattered').
"""
import json
import math
import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
import make_planet_bosses as mpb
from make_theory_creatures import assemble, read_vox

a = mpb.a
R = mpb.R
DEF = ('veil_herald', 'The Veiled Herald', 'Shardheart', 7.0, ('unveiled', 'shattered'),
       ('herald_rune', 'veil_needle', 'pale_tear'))
COLORS = [(214,220,236),(250,250,255),(128,136,170),(30,28,52),(176,226,240),(245,240,224),
          (140,110,200),(90,60,150),(235,250,255),(150,190,255)]
a.PAL[DEF[0]] = dict(zip(('base','light','shade','dark','belly','bone','wing','accent','glow_eye','glow_core'), COLORS))
a.PAL[DEF[0]].update(glow_white=(255,255,244), glow_red=(255,49,74), glow_green=(165,255,57),
                     glow_magenta=(255,27,196), crimson=(82,8,35), obsidian=(14,10,25))
attach, ring, chain = mpb.attach, mpb.ring, mpb.chain


def herald(form=''):
    b, p, l = {}, {}, {}
    torn = form in ('unveiled', 'shattered')
    # A tall bell of veils, layered and hanging free of the ground.
    for tier, (y, r) in enumerate(((10, 13), (18, 11), (26, 9), (33, 7))):
        a.ell(b, (0, y, 0), (r, 5, r*0.85), 'base' if tier % 2 else 'light')
        for i in range(10):
            t = i*math.tau/10+tier*0.3
            x, z = math.cos(t)*r, math.sin(t)*r*0.85
            if torn and (i+tier) % 3 == 0: continue
            a.line(b, (round(x), y+3, round(z)), (round(x*1.15), y-6, round(z*1.15)), 'shade' if i % 2 else 'belly')
    # A slit down the front shows the cold light inside.
    a.box(b, (-1, 8, -12), (2, 34, -9), 'glow_core')
    for y in (14, 22, 30):
        a.diamond(b, (0, y, -12), 2, 2, 'glow_white' if torn else 'glow_eye')
    a.ell(b, (0, 39, 0), (6, 4, 5), 'wing')
    if form == 'shattered':
        b = a.recolor(b, {'light': 'shade', 'glow_core': 'glow_red', 'belly': 'obsidian'})
        for x, y, z in list(b):
            if (x*3+y+z*5) % 23 < 2 and y < 30: del b[x, y, z]
    h = {}
    # Hood and veil; one pale eye where a face should be.
    a.ell(h, (0, 0, 0), (6, 8, 6), 'light')
    a.ell(h, (0, -1, -2), (4.5, 6, 4), 'dark')
    a.ell(h, (0, 0, -5), (2.5, 2.5, 1), 'glow_red' if form == 'shattered' else 'glow_white')
    a.ell(h, (0, 0, -6), (1, 1, 0.6), 'dark')
    if not torn:
        for x in range(-4, 5):
            a.line(h, (x, 3, -6), (x, -8+abs(x)//2, -6), 'belly')
        h[0, 0, -7] = 'glow_eye'
    ring(h, (0, 10, 3), 7, 'glow_red' if form == 'shattered' else 'glow_core', plane='xy')
    for i in range(6):
        t = i*math.tau/6
        a.diamond(h, (round(7*math.cos(t)), 10+round(7*math.sin(t)), 3), 1, 2, 'glow_white')
    attach(p, l, 'head', h, (0, 42, 0), 'head')
    for s, side in ((-1, 'l'), (1, 'r')):
        arm = {}
        a.ell(arm, (s*2, -1, 0), (3, 3, 3), 'base')
        a.line(arm, (0, 0, 0), (s*7, -9, -3), 'shade', 2)
        a.line(arm, (s*7, -9, -3), (s*9, -16, -6), 'bone', 1)
        if s < 0:
            # A censer on a chain, smoking pale light.
            a.line(arm, (s*9, -16, -6), (s*9, -21, -6), 'accent')
            a.ell(arm, (s*9, -24, -6), (3, 3, 3), 'accent')
            a.ell(arm, (s*9, -24, -6), (2, 2, 2), 'glow_core')
        else:
            # A staff topped with a little closed eye.
            a.line(arm, (s*9, -2, -6), (s*9, -28, -6), 'accent', 1)
            a.ell(arm, (s*9, 0, -6), (3, 2, 2), 'bone')
            a.box(arm, (s*9-1, 0, -8), (s*9+2, 1, -7), 'glow_red' if torn else 'glow_eye')
        attach(p, l, 'arm_'+side, arm, (s*7, 37, 0), 'arm', s)
    for i, x in enumerate((-6, 0, 6)):
        chain(p, l, f'veil_tail_{i}', (x, 22, 6), 3, 'wing')
    for i, tilt in enumerate((0.35, -0.3)):
        v = {}
        ring(v, (0, 0, 0), 20, 'accent', tilt=tilt)
        for j in range(5):
            t = j*math.tau/5+i*0.6
            x, z = round(20*math.cos(t)), round(20*math.sin(t))
            a.diamond(v, (x, round(z*tilt), z), 2, 3, 'glow_red' if form == 'shattered' else 'glow_core')
        attach(p, l, f'halo_{i}', v, (0, 22+i*8, 0), '', (-1)**i)
    return b, p, l


def projectile(name):
    v = {}
    if name == 'herald_rune':
        ring(v, (0, 0, 0), 5, 'glow_core', plane='xz')
        a.line(v, (-3, 0, -3), (3, 0, 3), 'glow_white')
        a.line(v, (-3, 0, 3), (3, 0, -3), 'glow_white')
        a.ell(v, (0, 0, 0), (1.5, 1, 1.5), 'glow_eye')
    elif name == 'veil_needle':
        for z in range(-9, 6):
            r = 1 if -5 < z < 3 else 0
            for x in range(-r, r+1):
                v[x, 0, z] = 'glow_eye'
            v[0, 0, z] = 'glow_white'
        a.line(v, (0, 0, 5), (2, 1, 9), 'glow_core')
        a.line(v, (0, 0, 5), (-2, -1, 9), 'glow_core')
    else:  # pale_tear
        for z in range(-5, 7):
            r = 4*math.sin(math.pi*(z+6)/13) if z < 3 else max(0.6, 4-(z-2)*0.9)
            for x in range(-4, 5):
                for y in range(-4, 5):
                    if x*x+y*y <= r*r: v[x, y, z] = 'glow_core' if x*x+y*y > (r-1.2)**2 else 'glow_white'
        a.ell(v, (0, 0, -1), (1.5, 1.5, 1.5), 'glow_red')
    return v


def main():
    name, title, planet, height, forms, shots = DEF
    folder = R/'creatures'/name
    targets = [folder, *[R/'creatures/boss_projectiles'/s for s in shots]]
    existing = [str(t.relative_to(R)) for t in targets if t.exists()]
    if existing: raise SystemExit('Create-only generator refuses existing outputs: '+', '.join(existing))
    b, p, l = herald()
    variants = {}
    for form in forms:
        vb, vp, vl = herald(form)
        assert vl == l
        swaps = {'body': 'body_'+form, 'head': 'head_'+form}
        p['body_'+form] = vb
        p['head_'+form] = vp['head']
        for n in vp:
            if n != 'head' and vp[n] != p[n]:
                p[n+'_'+form] = vp[n]
                swaps[n] = n+'_'+form
        variants[form] = swaps
    full = assemble(b, p, l)
    for swaps in ({}, *variants.values()):
        pose = assemble(b, p, l, swaps)
        assert all(-32 <= x < 32 and 0 <= y < 64 and -32 <= z < 32 for x, y, z in pose), name
    for v in (b, *p.values()): assert v and set(v.values()) <= a.PAL[name].keys()
    mpb.DEFS.append(DEF)
    mpb.install_64_writer()
    extent = a.bounds(full)[1][1]
    unit = height/(extent*4)
    scaled = json.loads(json.dumps(l))
    for spec in scaled.values(): spec['pivot'] = [q*4 for q in spec['pivot']]
    a.save(name, title, name, {'body': b, **p}, scaled, variants, (0, 38, -20), unit=unit)
    for dest in (folder, folder/'source_64'):
        path = dest/'rig.json'
        rig = json.loads(path.read_text())
        rig.update(design_grid=[64, 64, 64], upscale=4 if dest == folder else 1,
                   height_m=height, glow_strength=1.8, bob=.05, waddle=.02, flap_rate=1.6, animation_style='wraith')
        path.write_text(json.dumps(rig, indent=2)+'\n')
        mpb.validate(dest)
    for shot in shots:
        v = projectile(shot)
        assert sum(c.startswith('glow') for c in v.values()) > len(v)*.5
        a.projectile(shot, name, v, .012)
        read_vox(R/'creatures/boss_projectiles'/shot/'model.vox')
    print(f'{name}: {len(p)+1} parts, {height} m, variants {", ".join(forms)}; projectiles {", ".join(shots)}')


if __name__ == '__main__': main()
