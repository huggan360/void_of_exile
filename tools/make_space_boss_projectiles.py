#!/usr/bin/env python3
"""Create-only projectiles for the Reach bosses' four-stage fights. Run from the repository root.

Vaelith (the Stormeye Tyrant): frost_shard (freezes), dizzy_bubble (drunk),
arcane_sphere (magic ball), abyss_ink and sucker_disc (thrown by its squid arms).
One new shot for each other fortress boss: pollen_mote (Briarrose), resin_blob
(Aurum), eclipse_orb (Selenarch), brood_egg (Brood Matriarch).
Uses the shared 32-cell pixel boss writer (x8 upscale) and appends to manifest.json.
"""
import json
import sys
from pathlib import Path

sys.dont_write_bytecode = True
import redesign_pixel_bosses as a

R = Path(__file__).resolve().parents[1]
MANIFEST = R / 'creatures/boss_projectiles/manifest.json'


def pal(base, light, shade, dark, glow_eye, glow_core, bone=(230, 236, 245)):
    return dict(base=base, light=light, shade=shade, dark=dark, belly=light, bone=bone,
                wing=base, accent=light, glow_eye=glow_eye, glow_core=glow_core)


a.PAL['vaelith_frost'] = pal((70, 150, 210), (170, 225, 250), (35, 80, 140), (12, 26, 52), (220, 250, 255), (120, 220, 255))
a.PAL['vaelith_mind'] = pal((120, 60, 170), (200, 140, 240), (70, 30, 110), (25, 12, 45), (255, 170, 250), (190, 110, 255))
a.PAL['vaelith_arcane'] = pal((60, 70, 160), (130, 150, 240), (30, 30, 90), (10, 10, 35), (255, 255, 255), (154, 176, 255))
a.PAL['vaelith_ink'] = pal((40, 25, 70), (90, 60, 140), (22, 14, 40), (8, 6, 16), (255, 74, 90), (140, 90, 220))
a.PAL['vaelith_sucker'] = pal((150, 110, 175), (215, 190, 230), (95, 60, 120), (35, 20, 50), (255, 120, 150), (230, 160, 255))
a.PAL['rose_pollen'] = pal((230, 190, 60), (255, 235, 140), (160, 120, 30), (60, 40, 20), (255, 250, 200), (255, 150, 210))
a.PAL['amber_resin'] = pal((190, 110, 25), (245, 180, 70), (120, 60, 20), (45, 25, 10), (255, 230, 150), (255, 190, 80))
a.PAL['moon_eclipse'] = pal((20, 25, 35), (60, 80, 70), (10, 12, 18), (4, 5, 8), (200, 255, 210), (125, 255, 106))
a.PAL['brood_egg'] = pal((200, 170, 190), (240, 220, 230), (140, 100, 130), (50, 30, 50), (179, 255, 65), (255, 95, 210))

SHOTS = []


def shot(name, theme, voxels, unit):
    SHOTS.append(name)
    a.projectile(name, theme, voxels, unit)


def frost_shard():
    # A long six-sided ice spike pointing forward (-Z) with a glowing core.
    v = {}
    for z in range(-7, 6):
        r = 2.4 if z > -3 else 2.4 * (z + 8) / 5
        a.ell(v, (0, 0, z + .5), (max(.6, r), max(.6, r), .6), 'light')
    a.line(v, (0, 0, -8), (0, 0, 5), 'glow_eye')
    for side in (-1, 1):
        a.line(v, (side * 3, 0, 1), (side * 2, 0, -3), 'base')
        a.line(v, (0, side * 3, 2), (0, side * 2, -2), 'shade')
    return v


def dizzy_bubble():
    # A wobbling soap-bubble of mind-light with three little stars inside.
    v = {}
    a.ell(v, (0, 0, 0), (4, 4, 4), 'light')
    for x in range(-4, 4):
        for y in range(-4, 4):
            for z in range(-4, 4):
                if (x + .5) ** 2 + (y + .5) ** 2 + (z + .5) ** 2 < 9 and (x, y, z) in v:
                    del v[x, y, z]
    for c in [(-1, 1, 0), (1, -1, 1), (0, 0, -1)]:
        a.ell(v, c, (1, 1, 1), 'glow_core')
    v[2, 2, -3] = 'glow_eye'
    v[-2, 3, -2] = 'glow_eye'
    return v


def arcane_sphere():
    # A heavy ball of storm magic ringed by a band of runes.
    v = {}
    a.ell(v, (0, 0, 0), (5, 5, 5), 'base')
    a.ell(v, (0, 0, 0), (4, 4, 4), 'glow_core')
    a.ell(v, (0, 0, -1), (2, 2, 2), 'glow_eye')
    for k in range(16):
        import math
        t = k * math.tau / 16
        v[round(6 * math.cos(t)), 0, round(6 * math.sin(t))] = 'glow_eye' if k % 2 else 'light'
    return v


def abyss_ink():
    # A dripping glob of black ink with a red eye of light in it.
    v = {}
    a.ell(v, (0, 0, -1), (3, 3, 3.5), 'base')
    a.ell(v, (0, 0, 3), (2, 2, 2.5), 'shade')
    a.ell(v, (0, 0, 5), (1, 1, 1.5), 'dark')
    a.ell(v, (0, 1, -2), (1.2, 1.2, 1.2), 'glow_eye')
    for c in [(2, -1, 0), (-2, 1, 1)]:
        v[c] = 'glow_core'
    return v


def sucker_disc():
    # A ring torn off a tentacle's sucker: a flat pale disc with a hollow middle.
    v = {}
    for x in range(-6, 6):
        for z in range(-6, 6):
            d = ((x + .5) ** 2 + (z + .5) ** 2) ** .5
            if 2.2 < d < 6:
                v[x, 0, z] = 'light' if d < 4.4 else 'base'
                if d < 3.2:
                    v[x, 1, z] = 'glow_core'
            elif d <= 2.2:
                v[x, -1, z] = 'shade'
    return v


def pollen_mote():
    v = {}
    a.ell(v, (0, 0, 0), (3, 3, 3), 'base')
    a.ell(v, (0, 0, 0), (2, 2, 2), 'glow_eye')
    for c in [(3, 0, 0), (-3, 0, 0), (0, 3, 0), (0, -3, 0), (0, 0, 3), (0, 0, -3)]:
        a.ell(v, c, (1, 1, 1), 'glow_core')
    return v


def resin_blob():
    v = {}
    a.ell(v, (0, 0, 0), (4, 3, 4.5), 'base')
    a.ell(v, (0, 1, -1), (2.5, 2, 3), 'light')
    a.ell(v, (0, 1, -2), (1, 1, 1), 'glow_eye')
    for c in [(3, -2, 2), (-2, -2, 3)]:
        a.ell(v, c, (1, 1.5, 1), 'shade')
    return v


def eclipse_orb():
    # A black moon with a burning green corona.
    v = {}
    a.ell(v, (0, 0, 0), (5, 5, 5), 'glow_core')
    a.ell(v, (0, 0, -1), (4.2, 4.2, 4.2), 'dark')
    for k in range(12):
        import math
        t = k * math.tau / 12
        v[round(5.5 * math.cos(t)), round(5.5 * math.sin(t)), 0] = 'glow_eye'
    return v


def brood_egg():
    v = {}
    a.ell(v, (0, 0, 0), (3, 3, 4.5), 'light')
    for c in [(2, 1, -2), (-2, -1, 1), (1, 2, 2), (-1, 2, -1)]:
        a.ell(v, c, (1, 1, 1), 'glow_core')
    a.line(v, (-3, 0, -1), (3, 0, 1), 'glow_eye')
    a.ell(v, (0, -2, 0), (2, 1, 3), 'shade')
    return v


def main():
    names = ['frost_shard', 'dizzy_bubble', 'arcane_sphere', 'abyss_ink', 'sucker_disc',
             'pollen_mote', 'resin_blob', 'eclipse_orb', 'brood_egg']
    existing = [n for n in names if (R / 'creatures/boss_projectiles' / n).exists()]
    if existing:
        raise SystemExit('Create-only generator refuses existing outputs: ' + ', '.join(existing))
    shot('frost_shard', 'vaelith_frost', frost_shard(), .010)
    shot('dizzy_bubble', 'vaelith_mind', dizzy_bubble(), .012)
    shot('arcane_sphere', 'vaelith_arcane', arcane_sphere(), .014)
    shot('abyss_ink', 'vaelith_ink', abyss_ink(), .012)
    shot('sucker_disc', 'vaelith_sucker', sucker_disc(), .012)
    shot('pollen_mote', 'rose_pollen', pollen_mote(), .011)
    shot('resin_blob', 'amber_resin', resin_blob(), .012)
    shot('eclipse_orb', 'moon_eclipse', eclipse_orb(), .013)
    shot('brood_egg', 'brood_egg', brood_egg(), .012)
    manifest = json.loads(MANIFEST.read_text())
    manifest += [p for p in a.PROJECTILES if p['id'] in SHOTS]
    MANIFEST.write_text(json.dumps(manifest, indent=2) + '\n')
    print('Wrote', ', '.join(SHOTS))


if __name__ == '__main__':
    main()
