#!/usr/bin/env python3
"""Farm animals for Vesperis's countryside: a black-and-white cow that grazes
in the farmsteads' pastures (CityLife). Same rig format as the other creatures.

Run:  cd tools && python3 make_farm_animals.py
Output: creatures/farm_cow/*.vox and rig.json
"""
from voxel_sculpt import Part
from make_common_batch_01 import export
from preview_voxel_batch import ROOT

COW = {'shell': (236, 230, 220), 'shade': (46, 40, 44), 'edge': (222, 156, 158), 'bone': (226, 212, 176),
       'dark': (22, 18, 24), 'hoof': (70, 56, 48), 'glow': (0, 0, 0)}


def joint(part, at, phase):
    return dict(part=part, pivot=[round(x * 3) for x in at], role='leg', phase=phase, amount=0.35)


def cow():
    s = Part(3, COW)
    # Barrel body, a little patched; head low in front with a pink muzzle.
    s.ellipsoid((0, 8, 0.5), (3.0, 2.6, 5.4), 'shell')
    for c, r in [((1.6, 9.2, 2.2), (1.9, 1.6, 2.2)), ((-1.8, 8.0, -1.6), (1.7, 1.9, 1.8)), ((0.4, 10.0, -3.4), (1.6, 1.0, 1.4))]:
        s.ellipsoid(c, r, 'shade')
    s.ellipsoid((0, 8, 0.5), (3.0, 2.6, 5.4), 'shell')  # repaint the outline round the patches
    for c, r in [((2.6, 9.0, 2.0), (0.6, 1.5, 2.0)), ((-2.6, 8.2, -1.4), (0.6, 1.6, 1.6)), ((0.6, 10.5, -3.2), (1.4, 0.3, 1.2))]:
        s.ellipsoid(c, r, 'shade')
    s.ellipsoid((0, 8.6, -6.4), (1.6, 1.7, 1.9), 'shell')
    s.ellipsoid((0, 7.7, -7.9), (1.3, 1.0, 0.9), 'edge')
    for a in (-1, 1):
        s.ellipsoid((a * 0.5, 7.7, -8.7), (0.25, 0.25, 0.2), 'dark')  # nostrils
        s.ellipsoid((a * 1.15, 9.3, -7.4), (0.3, 0.35, 0.3), 'dark')  # eyes
        s.capsule((a * 1.2, 10.0, -6.2), (a * 2.1, 10.9, -6.0), 0.35, 0.25, 'bone')  # horns
        s.ellipsoid((a * 1.9, 9.6, -5.8), (0.8, 0.35, 0.5), 'shade')  # ears
    s.ellipsoid((0, 5.6, 2.6), (1.0, 0.7, 1.0), 'edge')  # udder
    s.capsule((0, 9.6, 5.8), (0, 6.2, 6.6), 0.35, 0.3, 'shell')  # tail
    s.ellipsoid((0, 5.9, 6.7), (0.45, 0.7, 0.45), 'shade')
    leg = Part(3, COW)
    leg.capsule((0, 0, 0), (0, -5.2, 0), 0.75, 0.65, 'shell')
    leg.box((-0.8, -6.0, -0.8), (0.8, -5.0, 0.8), 'hoof')
    limbs = {f'leg_{a}_{z}': joint('leg', (a * 1.6, 6.0, z), a * (1 if z < 0 else -1)) for a in (-1, 1) for z in (-3, 3.5)}
    rig = dict(voxel_size=0.045, parts={}, limbs=limbs, hand=[0, 26, -24], hover=0, bob=0, waddle=0.15)
    export(ROOT / 'creatures' / 'farm_cow', {'body': s.voxels(), 'leg': leg.voxels()}, COW, rig)
    print('Exported farm_cow')


if __name__ == '__main__':
    cow()
