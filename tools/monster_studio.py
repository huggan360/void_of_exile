"""The monster remake's workshop (tools/remake_monsters.py): sculpt in meters
at a chosen voxel size, paint with a few hand-picked tones per material and
export creatures/<id>/ parts and rig.json the game reads (CreatureModel).

Art rules this file keeps:
- Coarse enough to read as pixel art: about 28-36 voxels of height for a
  2-3 m monster (the goblins and frost moths are the reference).
- Three tones per material, painted from the shape itself: top edges catch
  the light (+), undersides fall into shade (-), rough materials get a soft
  grain (~). Glowing colors ('glow...') are never shaded.
- Story-game silhouettes: hoods, cloaks, staffs with a clear focus, weight
  low, a face or eyes that read at a distance.

Coordinates: y up, the creature faces -z, x to its left is -x... as in
tools/make_creatures.py. Limb parts are sculpted around their joint (0, 0, 0)
and hang down -y; arms raise toward -z when they attack.
"""
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, str(Path(__file__).resolve().parent))
from voxel_sculpt import Part  # noqa: E402
from make_common_batch_01 import export  # noqa: E402
from preview_voxel_batch import ROOT, assemble, render, BOLD  # noqa: E402

LIGHT = 1.2
SHADE = 0.74
GRAIN = 0.9


def mix(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def tone(rgb, k):
    """Lighter (k > 1) or darker (k < 1), a little warmer in the light and
    cooler in the shade so the ramps don't look grey."""
    r, g, b = rgb
    if k >= 1.0:
        warm = (255, 244, 224)
        return mix((min(255, r * k), min(255, g * k), min(255, b * k)), warm, (k - 1.0) * 0.35)
    cool = (30, 32, 60)
    return mix((r * k, g * k, b * k), cool, (1.0 - k) * 0.3)


class Model:
    """One creature: its palette (name -> (r, g, b)), the parts sculpted in
    meters and the rig built from joints placed in meters."""

    def __init__(self, name, vs, palette, rough=()):
        self.name = name
        self.vs = vs
        self.palette = dict(palette)
        self.rough = set(rough)
        self.parts = {}
        self.limbs = {}
        self.extra = {}
        self.hand = (0.0, 1.0, -0.3)

    def part(self, name):
        p = Part(1.0 / self.vs, self.palette)
        self.parts[name] = p
        return p

    def joint(self, limb, part, at, role, phase=1.0, **kw):
        spec = dict(part=part, pivot=[int(round(c / self.vs)) for c in at], role=role, phase=phase)
        spec.update(kw)
        self.limbs[limb] = spec

    # --- painting ------------------------------------------------------------

    def _shade(self, vox):
        out = {}
        for (x, y, z), name in vox.items():
            if name.startswith('glow'):
                out[(x, y, z)] = name
                continue
            if (x, y + 1, z) not in vox:
                out[(x, y, z)] = name + '+'
            elif (x, y - 1, z) not in vox:
                out[(x, y, z)] = name + '-'
            elif name in self.rough and ((x * 73856093) ^ (y * 19349663) ^ (z * 83492791)) % 5 == 0:
                out[(x, y, z)] = name + '~'
            else:
                out[(x, y, z)] = name
        return out

    def _full_palette(self):
        pal = {}
        for name, rgb in self.palette.items():
            pal[name] = tuple(rgb)
            if name.startswith('glow'):
                continue
            pal[name + '+'] = tone(rgb, LIGHT)
            pal[name + '-'] = tone(rgb, SHADE)
            pal[name + '~'] = tone(rgb, GRAIN)
        assert len(pal) < 255, f"{self.name}: too many colors ({len(pal)})"
        return pal

    # --- output --------------------------------------------------------------

    def save(self, keep=None):
        """Writes creatures/<name>/ (parts, rig.json, model.vox). `keep`: rig
        fields carried over from the old rig (animation style, variants...)."""
        folder = ROOT / 'creatures' / self.name
        old = json.loads((folder / 'rig.json').read_text()) if (folder / 'rig.json').exists() else {}
        for path in folder.glob('*.vox'):
            path.unlink()
        for path in folder.glob('*.vox.import'):
            path.unlink()
        vox = {name: self._shade(p.voxels(hollow_above=6000)) for name, p in self.parts.items()}
        rig = dict(voxel_size=self.vs, parts={}, limbs=self.limbs,
                   hand=[int(round(c / self.vs)) for c in self.hand])
        # Fields the game reads beyond the mesh: boss animation styles, poses
        # and variant tables carry over unless the remake sets them itself.
        for key in tuple(keep or ()) + ('animation_style', 'poses', 'variants', 'flap_rate'):
            if key in old and key not in self.extra:
                rig[key] = old[key]
        rig.update(self.extra)
        export(folder, vox, self._full_palette(), rig)
        return folder


def _assemble(folder):
    """The rest pose like assemble(), with child limbs (knees, jaws) placed on
    their parent joints as the game does."""
    from preview_voxel_batch import read_vox
    rig = json.loads((folder / 'rig.json').read_text())
    limbs = rig['limbs']

    def origin(limb):
        spec = limbs[limb]
        p = spec['pivot']
        parent = spec.get('parent_limb')
        if parent:
            q = origin(parent)
            return [p[i] + q[i] for i in range(3)]
        return list(p)

    v = {}
    for part, pivot in [('body', [0, 0, 0])] + [(spec['part'], origin(name)) for name, spec in limbs.items()]:
        frame = rig['parts'][part]['frame_min']
        for suffix in ('', '_glow'):
            f = folder / (part + suffix + '.vox')
            if not f.exists():
                continue
            for pos, color in read_vox(f).items():
                v[tuple(pos[k] + frame[k] + pivot[k] for k in range(3))] = (color, suffix == '_glow')
    return v


def sheet(names, out):
    """Front, three-quarter, side and back views of each creature, one row each."""
    rows = []
    font = ImageFont.truetype(BOLD, 22)
    for name in names:
        v = _assemble(ROOT / 'creatures' / name)
        views = [render(v, 300, 300, yaw=y) for y in (0, 35, 90, 200)]
        row = Image.new('RGB', (1220, 340), '#151b22')
        ImageDraw.Draw(row).text((14, 6), name, font=font, fill='#e8e4da')
        for i, im in enumerate(views):
            row.paste(im, (10 + i * 302, 36))
        rows.append(row)
    im = Image.new('RGB', (1220, 340 * len(rows)), '#151b22')
    for i, row in enumerate(rows):
        im.paste(row, (0, i * 340))
    im.save(out)


# --- recurring pieces ----------------------------------------------------------------

def ring(p, center, radius, thick, color, axis='y', n=40):
    """A torus as a chain of capsules (crowns, hems, halos)."""
    cx, cy, cz = center
    pts = []
    for i in range(n + 1):
        a = i * math.tau / n
        u, v = radius * math.cos(a), radius * math.sin(a)
        pts.append((cx + u, cy, cz + v) if axis == 'y' else (cx + u, cy + v, cz) if axis == 'z' else (cx, cy + u, cz + v))
    for a, b in zip(pts, pts[1:]):
        p.capsule(a, b, thick, thick, color)


def robe(p, top, bottom, r_top, r_bottom, color, depth=0.75, trim=None, trim_h=0.08):
    """A flaring robe or coat from the chest down to its hem."""
    steps = 6
    for i in range(steps):
        t0, t1 = i / steps, (i + 1) / steps
        y0 = top + (bottom - top) * t0
        y1 = top + (bottom - top) * t1
        r0 = r_top + (r_bottom - r_top) * t0 ** 1.4
        r1 = r_top + (r_bottom - r_top) * t1 ** 1.4
        p.capsule((0, y0, 0), (0, y1, 0), r0, r1, color)
    if trim:
        ring(p, (0, bottom + trim_h * 0.5, 0), r_bottom * 0.98, trim_h * 0.6, trim, n=48)


def hood(p, head, size, cloth, inner, eyes=None, eye_gap=0.07, point=0.16):
    """A deep hood around a shadowed face, with a little peak at the back.
    eyes: a glow color for two eyes in the dark."""
    x, y, z = head
    p.ellipsoid((x, y + size * 0.1, z + size * 0.12), (size, size * 1.05, size * 1.0), cloth)
    # The peak falls back over the shoulders (not a wizard's hat).
    p.capsule((x, y + size * 0.55, z + size * 0.45), (x, y + size * 0.15, z + size + point), size * 0.5, 0.03, cloth)
    # The opening: a dark hollow that eats into the front of the hood.
    p.ellipsoid((x, y - size * 0.05, z - size * 0.62), (size * 0.62, size * 0.72, size * 0.55), inner)
    if eyes:
        for side in (-1, 1):
            p.ellipsoid((x + side * eye_gap, y + size * 0.02, z - size * 0.78), (0.035, 0.03, 0.03), eyes)


def staff(p, base, tip, r, wood, cap=None, cap_r=0.0):
    p.capsule(base, tip, r, r * 0.85, wood)
    if cap:
        p.ellipsoid(tip, (cap_r, cap_r * 1.2, cap_r), cap)


def plate(p, lo, hi, color):
    """A slightly rounded box: armour plates, stone slabs."""
    lo, hi = np.array(lo, float), np.array(hi, float)
    c = (lo + hi) / 2
    r = (hi - lo) / 2
    p.box(lo + [0.0, 0.0, 0.0], hi, color)
    p.ellipsoid(tuple(c), tuple(r * 1.08), color)


class _Mirrored:
    """A part reflected across x (a right wing from the left one)."""

    def __init__(self, part):
        self.part = part

    def voxels(self, hollow_above=20000):
        return {(-x - 1, y, z): c for (x, y, z), c in self.part.voxels(hollow_above=hollow_above).items()}


def mirror_part(model, part):
    return _Mirrored(part)
