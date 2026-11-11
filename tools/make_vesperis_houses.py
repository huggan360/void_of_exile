#!/usr/bin/env python3
"""Vesperis's town buildings, in the Tavern's cosy voxel style (12.5 cm grid).

Every house is a real building you can walk into: a door in the front (-Z),
a planked floor, a hearth, a table and a bed, and colliders only for its walls
(building.json). The halls hold the city's cafes, bars and shops: their room
interior comes from CityDistrict, so a hall's front is left open for it, and
the bars get three 1950s neon tubes round the eaves. The Lantern Spire is the
city's landmark: a walk-in round hall (spire_hall) under a tall stone shaft
with a copper orb (spire, 50 cm grid); a lift attendant in the hall takes
you up to the orb (no elevator: a fade to black, like boarding a ship).

Each model also gets two coarser copies (body_lod1.vox at 2x, body_lod2.vox
at 4x) for distance. Bake them with tools/bake_vesperis_houses.gd.
Run: python3 tools/make_vesperis_houses.py [names...]
"""
import json, math, sys
from collections import Counter
from make_creatures import box, line, write_vox, fit_frame
from make_common_batch_01 import export
from preview_voxel_batch import ROOT

OUT = ROOT/'props/vesperis'
SELECTED = set(sys.argv[1:])
# The Tavern's palette (make_village_houses.BASE) and its roof colours.
BASE = {'wood': (111, 66, 37), 'wood_light': (145, 90, 46), 'wood_dark': (74, 43, 28), 'end': (177, 126, 70), 'ring': (121, 78, 41),
	'beam': (65, 42, 31), 'stone': (116, 117, 113), 'stone_light': (152, 148, 131), 'mortar': (67, 69, 69),
	'roof': (83, 102, 74), 'roof_light': (104, 125, 83), 'roof_dark': (53, 72, 61), 'glass': (94, 155, 166),
	'glow_window': (235, 180, 99), 'iron': (60, 65, 70), 'brass': (200, 156, 67), 'plaster': (215, 194, 152),
	'cloth': (139, 64, 64), 'leaf': (67, 111, 61), 'flower': (208, 151, 141), 'flower2': (226, 196, 108),
	'glow_fire': (246, 141, 53), 'plank': (150, 104, 62), 'plank_dark': (118, 80, 48), 'rug': (128, 58, 52), 'linen': (226, 214, 190),
	'copper': (166, 98, 60), 'copper_light': (196, 132, 82), 'thatch': (184, 150, 86), 'thatch_dark': (146, 114, 62)}
ROOFS = {
	'moss': {'roof': (83, 102, 74), 'roof_light': (104, 125, 83), 'roof_dark': (53, 72, 61)},
	'red': {'roof': (134, 70, 51), 'roof_light': (172, 94, 62), 'roof_dark': (91, 45, 40)},
	'blue': {'roof': (56, 105, 133), 'roof_light': (78, 137, 161), 'roof_dark': (35, 67, 95)},
	'plum': {'roof': (133, 76, 105), 'roof_light': (161, 104, 125), 'roof_dark': (89, 48, 76)},
	'slate': {'roof': (66, 71, 78), 'roof_light': (94, 102, 110), 'roof_dark': (42, 47, 56)},
	'thatch': {'roof': (184, 150, 86), 'roof_light': (208, 176, 104), 'roof_dark': (146, 114, 62)},
}
NEON = {'pink': (255, 92, 168), 'mint': (92, 255, 196), 'amber': (255, 182, 72)}
U = 0.125  # metres per voxel


def h(x, y, z):
	return ((x*73856093) ^ (y*19349663) ^ (z*83492791)) % 17


class House:
	"""A building in progress: voxels plus its wall colliders (metres)."""
	def __init__(self):
		self.v = {}
		self.colliders = []

	def solid(self, x0, x1, y0, y1, z0, z1):
		self.colliders.append({'size': [(x1-x0)*U, (y1-y0)*U, (z1-z0)*U], 'offset': [(x0+x1)*U/2, (y0+y1)*U/2, (z0+z1)*U/2]})

	def wall(self, x0, x1, y0, y1, z0, z1, style, solid=True):
		v = self.v
		for x in range(x0, x1):
			for y in range(y0, y1):
				for z in range(z0, z1):
					if style == 'log':
						course = (y-y0)//4
						c = 'wood_light' if course % 3 == 0 else 'wood'
						if (y-y0) % 4 == 3: c = 'wood_dark'
						elif h(x, course, z) < 2: c = 'ring'
					elif style == 'stone':
						c = 'mortar' if y % 5 == 0 or (x+z+(y//5)*3) % 8 == 0 else 'stone_light' if h(x, y, z) < 4 else 'stone'
					else:
						c = 'plaster'
					v[x, y, z] = c
		if solid: self.solid(x0, x1, y0, y1, z0, z1)

	def carve(self, x0, x1, y0, y1, z0, z1):
		for x in range(x0, x1):
			for y in range(y0, y1):
				for z in range(z0, z1):
					self.v.pop((x, y, z), None)

	def window(self, cx, cy, face, out, wide=8, tall=10, flowers=True):
		"""A window through a wall: `face` the wall's outer plane, `out` +-1 on
		z (front/back) or +-2 on x (sides). Lit panes, a frame and shutters."""
		v = self.v
		axis_z = abs(out) == 1
		s = 1 if out > 0 else -1
		for a in range(-wide//2-1, wide//2+2):
			for b in range(-tall//2-1, tall//2+2):
				for d in range(0, 4):
					p = (cx+a, cy+b, face-s*d) if axis_z else (face-s*d, cy+b, cx+a)
					v.pop(p, None)
		for a in range(-wide//2-1, wide//2+2):
			for b in range(-tall//2-1, tall//2+2):
				edge = abs(a) > wide//2 or abs(b) > tall//2
				c = 'beam' if edge else 'wood_light' if a == 0 or b == 0 else 'glow_window'
				p = (cx+a, cy+b, face-s) if axis_z else (face-s, cy+b, cx+a)
				v[p] = c
		for side in [-1, 1]:
			for a in range(wide//2+2, wide//2+5):
				for b in range(-tall//2, tall//2+1):
					p = (cx+a*side, cy+b, face) if axis_z else (face, cy+b, cx+a*side)
					v[p] = 'roof_dark' if b % 3 == 0 else 'roof'
		if flowers:
			for a in range(-wide//2-1, wide//2+2):
				for d in range(0, 3):
					p = (cx+a, cy-tall//2-2, face+s*d) if axis_z else (face+s*d, cy-tall//2-2, cx+a)
					v[p] = 'wood_dark'
					if d == 1:
						q = (p[0], p[1]+1, p[2])
						v[q] = 'leaf' if (a+cx) % 3 else ('flower' if (a+cy) % 2 else 'flower2')

	def roof(self, hx, hz, base, rise, along_x, over=5, color='roof'):
		"""A gable roof over the walls: ridge along x (slopes to +-z) or z."""
		v = self.v
		span = hz+over if along_x else hx+over
		length = hx+over if along_x else hz+over
		for a in range(-span, span+1):
			y = base+round((1-abs(a)/span)*rise)
			for b in range(-length, length+1):
				for t in [0, 1]:
					c = 'roof_dark' if (abs(a)//3) % 2 else 'roof'
					if (b+(abs(a)//3 % 2)*2) % 6 == 0: c = 'roof_dark'
					elif h(a, y, b) < 3: c = 'roof_light'
					p = (b, y+t, a) if along_x else (a, y+t, b)
					v[p] = c
				if abs(b) == length:
					p = (b, y-1, a) if along_x else (a, y-1, b)
					v[p] = 'beam'
		# Ridge beam and the gable ends filled with plaster between beams.
		for b in range(-length, length+1):
			p = (b, base+rise+2, 0) if along_x else (0, base+rise+2, b)
			v[p] = 'beam'
		inner = hx if along_x else hz
		for end in [-1, 1]:
			for a in range(-(hz if along_x else hx), (hz if along_x else hx)+1):
				top = base+round((1-abs(a)/span)*rise)
				for y in range(base, top):
					p = (end*(inner-1), y, a) if along_x else (a, y, end*(inner-1))
					v[p] = 'beam' if abs(a) < 2 or (y-base+abs(a)) % 11 < 2 else 'plaster'

	def chimney(self, cx, cz, y0, y1):
		for y in range(y0, y1):
			for x in range(cx-3, cx+4):
				for z in range(cz-3, cz+4):
					if abs(x-cx) == 3 or abs(z-cz) == 3:
						self.v[x, y, z] = 'mortar' if y % 4 == 0 else 'stone'
		box(self.v, cx-4, cx+5, y1, y1+2, cz-4, cz+5, 'stone_light')

	def door(self, hz, x=0, wide=14, tall=19):
		"""An open doorway in the front wall (-Z), a step, a frame and a lantern."""
		v = self.v
		self.carve(x-wide//2, x+wide//2, 1, tall, -hz-4, -hz+4)
		for y in range(0, tall+3):
			for side in [-1, 1]:
				for d in range(-hz-4, -hz+1):
					v[x+side*(wide//2+1), y, d] = 'beam'
		box(v, x-wide//2-2, x+wide//2+3, tall, tall+3, -hz-4, -hz+1, 'beam')
		box(v, x-wide//2-1, x+wide//2+2, 0, 1, -hz-6, -hz+1, 'stone_light')
		box(v, x+wide//2+3, x+wide//2+5, tall-4, tall-1, -hz-6, -hz-4, 'iron')
		box(v, x+wide//2+3, x+wide//2+5, tall-8, tall-4, -hz-6, -hz-4, 'glow_fire')

	def floor(self, hx, hz):
		for x in range(-hx+3, hx-2):
			for z in range(-hz+3, hz-2):
				self.v[x, 0, z] = 'plank_dark' if x % 6 == 0 else 'plank'

	def furnish(self, hx, hz, ceiling):
		"""A hearth on the back wall, a table with stools, a bed and a rug."""
		v = self.v
		cx = -hx//3
		box(v, cx-7, cx+7, 1, 14, hz-8, hz-3, 'stone')
		box(v, cx-4, cx+4, 1, 8, hz-9, hz-6, 'glow_fire')
		box(v, cx-5, cx+5, 8, 10, hz-9, hz-6, 'stone_light')
		for y in range(14, ceiling):
			box(v, cx-3, cx+3, y, y+1, hz-7, hz-3, 'stone')
		self.solid(cx-7, cx+7, 0, 14, hz-9, hz-3)
		tx, tz = hx//3, 0
		box(v, tx-5, tx+5, 6, 7, tz-4, tz+4, 'wood_light')
		for x in [tx-4, tx+3]:
			for z in [tz-3, tz+2]: box(v, x, x+1, 1, 6, z, z+1, 'wood_dark')
		for z in [tz-7, tz+6]: box(v, tx-2, tx+2, 1, 4, z, z+1, 'wood')
		self.solid(tx-5, tx+5, 0, 7, tz-4, tz+4)
		bx = hx-12
		box(v, bx, bx+8, 1, 4, -hz+6, -hz+20, 'wood_dark')
		box(v, bx, bx+8, 4, 5, -hz+6, -hz+20, 'linen')
		box(v, bx+1, bx+7, 5, 6, -hz+6, -hz+10, 'linen')
		box(v, bx, bx+8, 4, 6, -hz+18, -hz+20, 'cloth')
		for x in range(-hx//2, hx//4):
			for z in range(-4, 4): v[x, 1, z] = 'rug' if (x+z) % 7 else 'flower2'


def cottage(name, hx, hz, storeys, roof, walls='log', upper='timber', along_x=True, rise=None, porch=False, dormer=False, turret=False, chimney=True):
	"""A walk-in house: `hx`/`hz` half sizes in voxels (outer wall faces)."""
	b = House()
	v = b.v
	eave = 26 if storeys == 1 else 48
	# Stone footing, ground floor walls (thickness 3), the upper storey.
	b.wall(-hx-1, hx+2, -1, 2, -hz-1, hz+2, 'stone', solid=False)
	g = 'stone' if walls == 'stone' else walls
	ground = min(eave, 26)
	b.wall(-hx, hx+1, 2, ground, -hz, -hz+3, g, solid=False)
	b.wall(-hx, hx+1, 2, ground, hz-2, hz+1, g, solid=False)
	b.wall(-hx, -hx+3, 2, ground, -hz, hz+1, g, solid=False)
	b.wall(hx-2, hx+1, 2, ground, -hz, hz+1, g, solid=False)
	if storeys > 1:
		# The upper storey juts out a little over the street, timber framed.
		j = 2
		for y in range(ground, eave):
			for x in range(-hx-j, hx+j+1):
				for z in range(-hz-j, hz+j+1):
					if abs(x) < hx+j-2 and abs(z) < hz+j-2: continue
					if upper == 'timber':
						edge = abs(x) >= hx+j-2 and abs(z) >= hz+j-2
						diag = (x+y) % 12 == 0 or (x-y) % 12 == 0 if abs(z) >= hz+j-2 else (z+y) % 12 == 0 or (z-y) % 12 == 0
						c = 'beam' if edge or y in (ground, ground+1, eave-1) or diag else 'plaster'
					else:
						c = 'wood_light' if (y//4) % 3 == 0 else 'wood'
						if y % 4 == 3: c = 'wood_dark'
					v[x, y, z] = c
		box(v, -hx-j, hx+j+1, ground-1, ground+1, -hz-j, hz+j+1, 'beam')
		# The ceiling of the ground floor (the upper floor is not walkable).
		box(v, -hx+3, hx-2, ground-1, ground, -hz+3, hz-2, 'plank_dark')
	else:
		box(v, -hx+3, hx-2, ground-1, ground, -hz+3, hz-2, 'beam')
	# Corner posts.
	for x in [-hx, hx-2]:
		for z in [-hz, hz-2]: box(v, x, x+3, 0, ground, z, z+3, 'beam')
	# Walls as colliders (the doorway left open).
	b.solid(-hx, -6, 0, ground, -hz, -hz+3)
	b.solid(7, hx+1, 0, ground, -hz, -hz+3)
	b.solid(-hx, hx+1, 0, ground, hz-2, hz+1)
	b.solid(-hx, -hx+3, 0, ground, -hz, hz+1)
	b.solid(hx-2, hx+1, 0, ground, -hz, hz+1)
	b.floor(hx, hz)
	b.door(hz)
	b.furnish(hx, hz, ground-1)
	# Windows: front either side of the door, sides and back, upper floor too.
	for x in [-hx//2-2, hx//2+2]:
		if abs(x) > 9: b.window(x, 12, -hz, -1, 6, 8)
	for side in [-1, 1]:
		for z in ([-hz//2, hz//2] if hz > 18 else [0]):
			b.window(z, 12, side*hx, 2*side, 6, 8)
	b.window(hx//3, 12, hz, 1, 6, 8, flowers=False)
	if storeys > 1:
		for x in ([-hx//2, hx//2] if hx > 18 else [0]):
			b.window(x, ground+11, -hz-2, -1, 7, 9)
			b.window(x, ground+11, hz+2, 1, 7, 9, flowers=False)
	pal = dict(BASE)
	pal.update(ROOFS[roof])
	b.roof(hx+(2 if storeys > 1 else 0), hz+(2 if storeys > 1 else 0), eave, rise or (14 if along_x else 16), along_x)
	if chimney: b.chimney(hx//2, hz//3, eave-4, eave+(rise or 14)+6)
	if porch:
		for x in [-9, 9]: box(v, x, x+2, 0, 22, -hz-14, -hz-12, 'beam')
		for z in range(-hz-15, -hz):
			for x in range(-11, 12):
				v[x, 22+(z+hz+15)//5, z] = 'roof' if (x+z) % 5 else 'roof_light'
	if dormer:
		for x in range(-7, 8):
			for y in range(eave, eave+9): v[x, y, -hz-1] = 'plaster'
		b.window(0, eave+5, -hz-1, -1, 6, 5, flowers=False)
		for x in range(-9, 10):
			for z in range(-hz-4, -hz+8): v[x, eave+10+round((1-abs(x)/10)*5), z] = 'roof_light'
	if turret:
		tx, tz, r = hx-1, -hz+1, 7
		top = eave+(rise or 14)+6
		for y in range(0, top):
			for x in range(-r, r+1):
				for z in range(-r, r+1):
					d = math.hypot(x, z)
					if r-1.5 < d <= r: v[tx+x, y, tz+z] = 'stone_light' if y % 6 else 'mortar'
		for y in range(top, top+16):
			rr = r+1-(y-top)*0.5
			for x in range(-r-1, r+2):
				for z in range(-r-1, r+2):
					if rr-1.3 < math.hypot(x, z) <= rr: v[tx+x, y, tz+z] = 'roof_dark' if y % 3 == 0 else 'roof'
		b.window(tx, eave+6, tz-r, -1, 4, 6, flowers=False)
	return b, pal


def hall(name, roof, neon=None, walls='log'):
	"""A venue hall round CityDistrict's 16 x 12 x 5.2 m room (centred on the
	origin, door side -Z): side and back walls, a loft roof and an open front
	framed by beams. Bars get three neon tubes round the eaves."""
	b = House()
	v = b.v
	hx, hz, top = 67, 51, 44  # just outside the room
	b.wall(-hx-1, hx+2, -1, 1, -hz-1, hz+2, 'stone', solid=False)
	b.wall(-hx, -hx+3, 1, top, -hz, hz+1, walls)
	b.wall(hx-2, hx+1, 1, top, -hz, hz+1, walls)
	b.wall(-hx, hx+1, 1, top, hz-2, hz+1, walls)
	# Front: a timber frame round the room's own front (posts, a lintel band),
	# a gable wall above it.
	for x in [-hx, -26, 26, hx-3]: box(v, x, x+4, 0, top+2, -hz-1, -hz+2, 'beam')
	box(v, -hx, hx+1, top-4, top+2, -hz-1, -hz+2, 'beam')
	for x in range(-hx+4, hx-3):
		for y in range(top-12, top-4):
			if -26 <= x < 30 and y < top-8: continue
			v[x, y, -hz] = 'plaster' if (x+y) % 13 else 'beam'
	for x in [-hx, hx-2]:
		for z in [-hz, hz-2]: box(v, x, x+3, 0, top+2, z, z+3, 'beam')
	pal = dict(BASE)
	pal.update(ROOFS[roof])
	b.roof(hx+2, hz+2, top+1, 26, True, over=6)
	b.chimney(hx-18, hz-14, top-6, top+34)
	for side in [-1, 1]:
		for z in [-24, 0, 24]: b.window(z, 22, side*hx, 2*side, 8, 12)
	# Two dormers looking out over the street.
	for cx in [-34, 34]:
		for x in range(cx-8, cx+9):
			for y in range(top+2, top+13): v[x, y, -hz-2] = 'plaster'
		b.window(cx, top+7, -hz-2, -1, 7, 6, flowers=False)
		for x in range(cx-10, cx+11):
			for z in range(-hz-6, -hz+8): v[x, top+14+round((1-abs(x-cx)/11)*5), z] = 'roof_light'
	if neon:
		pal['glow_neon'] = NEON[neon]
		pal['glow_neon2'] = tuple(min(255, int(c*0.7+80)) for c in NEON[neon])
		# Three tubes following the eaves round the whole hall, a hand apart.
		for k, lift in enumerate([0, 3, 6]):
			c = 'glow_neon' if k != 1 else 'glow_neon2'
			y = top-2-lift
			for x in range(-hx-3, hx+4):
				v[x, y, -hz-3] = c
				v[x, y, hz+3] = c
			for z in range(-hz-3, hz+4):
				v[-hx-3, y, z] = c
				v[hx+3, y, z] = c
		# A neon star on the gable.
		for a in range(0, 360, 6):
			r = 7+3*math.cos(math.radians(a*5))
			x, y = round(math.cos(math.radians(a))*r), round(math.sin(math.radians(a))*r)
			v[x, top+24+y, -hz-6] = 'glow_neon'
	else:
		# Lantern brackets either side of the room's door.
		for x in [-30, 30]:
			box(v, x-1, x+2, 30, 32, -hz-6, -hz-1, 'iron')
			box(v, x-2, x+3, 23, 30, -hz-7, -hz-4, 'glow_fire')
	return b, pal


def spire_hall():
	"""The round hall at the foot of the Lantern Spire, its door at -Z and
	the spire's shaft rising through its middle."""
	b = House()
	v = b.v
	r, top = 80, 34
	for y in range(-1, top):
		for x in range(-r-2, r+3):
			for z in range(-r-2, r+3):
				d = math.hypot(x, z)
				if y < 1 and d <= r+1: v[x, y, z] = 'stone_light' if y < 0 else ('plank' if (x//6+z//6) % 2 else 'plank_dark') if d < r-3 else 'stone'
				elif r-3 < d <= r: v[x, y, z] = 'mortar' if y % 5 == 0 or (round(math.atan2(z, x)*40)+y//5) % 7 == 0 else 'stone_light' if h(x, y, z) < 5 else 'stone'
	# Ring colliders, the doorway (-Z) open.
	for k in range(24):
		a = (k+0.5)/24*math.tau
		if abs(math.atan2(math.sin(a), math.cos(a))+math.pi/2) < 0.2: continue  # the doorway
		x, z = math.cos(a)*(r-1.5), math.sin(a)*(r-1.5)
		b.colliders.append({'size': [2.0*math.pi*r*U/24+0.4, top*U, 3*U], 'offset': [x*U, top*U/2, z*U], 'yaw': -a+math.pi/2})
	b.carve(-10, 10, 1, 24, -r-3, -r+4)
	for x in [-12, 11]: box(v, x, x+2, 0, 27, -r-4, -r+3, 'beam')
	box(v, -12, 13, 24, 27, -r-4, -r+3, 'beam')
	# Windows round the wall: carved openings with lit panes.
	for k in range(14):
		a = (k+0.5)/14*math.tau
		if abs(math.atan2(math.sin(a), math.cos(a))+math.pi/2) < 0.35: continue
		cx, cz = math.cos(a), math.sin(a)
		for t in range(-5, 6):
			for y in range(10, 24):
				x, z = round(cx*(r-1)-cz*t), round(cz*(r-1)+cx*t)
				for d in range(-2, 2): v.pop((round(cx*(r-1+d)-cz*t), y, round(cz*(r-1+d)+cx*t)), None)
				v[round(cx*r-cz*t), y, round(cz*r+cx*t)] = 'beam' if abs(t) == 5 or y in (10, 23) else 'wood_light' if t == 0 else 'glow_window'
	# A conical roof of red shingles up to the shaft.
	for y in range(top, top+30):
		rr = r+4-(y-top)*2.4
		if rr < 30: break
		for x in range(-r-5, r+6):
			for z in range(-r-5, r+6):
				d = math.hypot(x, z)
				if rr-2.5 < d <= rr: v[x, y, z] = 'roof_dark' if y % 3 == 0 else 'roof' if h(x, y, z) > 3 else 'roof_light'
	# Benches round the inside wall.
	for k in range(10):
		a = (k+0.5)/10*math.tau
		if abs(math.atan2(math.sin(a), math.cos(a))+math.pi/2) < 0.5: continue
		cx, cz = math.cos(a)*(r-9), math.sin(a)*(r-9)
		for t in range(-6, 7):
			x, z = round(cx-math.sin(a)*t), round(cz+math.cos(a)*t)
			box(v, x, x+1, 1, 4, z, z+1, 'wood_dark')
			v[x, 4, z] = 'wood_light'
	pal = dict(BASE)
	pal.update(ROOFS['red'])
	return b, pal


SPIRE_U = 0.5
ORB_FLOOR = 89.0  # metres: the orb's floor, where the attendant brings you
ORB_CENTER = 92.0
ORB_RADIUS = 14.0
WINDOW = (1.0, 3.5)  # the window band, metres above the orb's floor (glass from CityDistrict)


def spire():
	"""The Lantern Spire above its hall (50 cm grid): a tapering stone shaft
	with timber bands and brass lift doors at its foot, a copper collar, the
	orb (a hollow shell, see ORB_*) with open windows all round above its
	floor and a brass lift column in its middle, a lantern and a mast on top."""
	v = {}
	cy, cr = round(ORB_CENTER/SPIRE_U), round(ORB_RADIUS/SPIRE_U)
	floor = round(ORB_FLOOR/SPIRE_U)
	top = cy-cr+2
	for y in range(0, top):
		r = 9-3*y/top
		for x in range(-11, 12):
			for z in range(-11, 12):
				d = math.hypot(x, z)
				if r-1.2 < d <= r:
					a = math.atan2(z, x)
					rib = (round(a/(math.tau/8)*1000)) % 1000 < 90
					v[x, y, z] = 'beam' if y % 24 in (0, 1) else 'brass' if rib else 'stone_light' if (y//3+round(a*6)) % 5 else 'stone'
					if y % 24 == 12 and abs(math.sin(a*4)) < 0.2: v[x, y, z] = 'glow_window'
	# Collar flaring out under the orb.
	for y in range(top-10, top+2):
		rr = 6+(y-top+10)*0.9
		for x in range(-17, 18):
			for z in range(-17, 18):
				if rr-1.2 < math.hypot(x, z) <= rr: v[x, y, z] = 'copper' if y % 2 else 'copper_light'
	# The orb: copper panels on a brass lattice; above its floor a band of
	# open windows between brass mullions (the glass is CityDistrict's).
	w0, w1 = floor+round(WINDOW[0]/SPIRE_U), floor+round(WINDOW[1]/SPIRE_U)
	for x in range(-cr-1, cr+2):
		for y in range(cy-cr-1, cy+cr+2):
			for z in range(-cr-1, cr+2):
				d = math.sqrt(x*x+(y-cy)**2+z*z)
				if cr-1.1 < d <= cr:
					lat = math.degrees(math.asin(max(-1, min(1, (y-cy)/cr))))
					lon = math.degrees(math.atan2(z, x))
					c = 'brass' if abs(lat % 15) < 2.2 or abs(lon % 20) < 2.2 else 'copper' if h(x, y, z) > 5 else 'copper_light'
					if w0 <= y < w1:
						if abs((lon+7.5) % 15-7.5) > 1.6: continue  # a window
						c = 'brass'
					elif y in (w0-1, w1): c = 'brass'
					v[x, y, z] = c
	# The lift column in the orb's middle: a brass cage, its doors to -Z.
	for y in range(floor, floor+8):
		for x in range(-3, 4):
			for z in range(-3, 4):
				dd = math.hypot(x, z)
				if 2.2 < dd <= 3.2:
					if z < -1 and abs(x) <= 1 and y < floor+6: v[x, y, z] = 'glow_window' if y == floor+5 else 'iron' if x == 0 else 'brass'
					else: v[x, y, z] = 'brass' if (y-floor) % 3 == 0 or abs(x) == 3 or abs(z) == 3 else 'iron'
	for x in range(-4, 5):
		for z in range(-4, 5):
			if math.hypot(x, z) <= 4: v[x, floor+8, z] = 'brass'
	# Brass lift doors at the shaft's foot, inside the hall.
	for x in range(-3, 4):
		for y in range(0, 8):
			v[x, y, -9] = 'brass' if abs(x) == 3 or y in (0, 7) else 'glow_window' if y == 6 else 'iron' if x == 0 else 'copper'
	# Lantern room and mast.
	ty = cy+cr
	for y in range(ty, ty+8):
		for x in range(-4, 5):
			for z in range(-4, 5):
				if 3 < math.hypot(x, z) <= 4: v[x, y, z] = 'glow_window' if 2 <= y-ty <= 5 and (x+z) % 2 else 'brass'
	for y in range(ty+8, ty+10):
		for x in range(-5, 6):
			for z in range(-5, 6):
				if math.hypot(x, z) <= 5-(y-ty-8)*2: v[x, y, z] = 'roof_dark'
	top_y = min(252, ty+40)
	for y in range(ty+10, top_y):
		v[0, y, 0] = 'brass' if (y//4) % 2 else 'iron'
	for y in range(top_y, top_y+2): v[0, y, 0] = 'glow_fire'
	pal = dict(BASE)
	pal.update(ROOFS['red'])
	return v, pal


def downsample(v, f):
	"""A coarse copy: each f^3 block takes its most common colour."""
	groups = {}
	for (x, y, z), c in v.items():
		groups.setdefault((x//f, y//f, z//f), []).append(c)
	out = {}
	for k, cs in groups.items():
		if len(cs)*3 < f**3 and f > 2: continue  # thin specks vanish far away
		out[k] = Counter(cs).most_common(1)[0][0]
	return out


def save(name, v, pal, unit=U, info=None):
	if SELECTED and name not in SELECTED: return
	folder = OUT/name
	export(folder, {'body': v}, pal, dict(voxel_size=unit, parts={}, limbs={}, hand=[0, 0, 0], waddle=0))
	# Far copies, glow folded into the body (windows read warm from afar).
	lods = []
	for k, f in [(1, 2), (2, 4)]:
		coarse = downsample(v, f)
		coarse = {p: ('lit_'+c[5:] if c.startswith('glow_') else c) for p, c in coarse.items()}
		flat = dict(pal)
		for c in list(pal):
			if c.startswith('glow_'): flat['lit_'+c[5:]] = pal[c]
		lo, size = fit_frame(coarse)
		lo = tuple(n-1 for n in lo)
		size = tuple(n+2 for n in size)
		write_vox(str(folder/f'body_lod{k}.vox'), coarse, {c: flat[c] for c in flat if c in set(coarse.values())}, lo, size)
		lods.append({'scale': f, 'frame_min': list(lo)})
	rig = json.loads((folder/'rig.json').read_text())
	rig['lods'] = lods
	(folder/'rig.json').write_text(json.dumps(rig, indent=2)+'\n')
	xs = [p[0] for p in v]
	zs = [p[2] for p in v]
	ys = [p[1] for p in v]
	meta = {'footprint': [(max(xs)-min(xs)+1)*unit, (max(zs)-min(zs)+1)*unit], 'height': (max(ys)+1)*unit,
		'center': [(max(xs)+min(xs)+1)*unit/2, (max(zs)+min(zs)+1)*unit/2]}
	meta.update(info or {})
	(folder/'building.json').write_text(json.dumps(meta, indent=2)+'\n')
	print(name, len(v), 'voxels', meta['footprint'])


def main():
	houses = [
		('cottage_moss', dict(hx=20, hz=24, storeys=1, roof='moss', along_x=False, porch=True)),
		('cottage_red', dict(hx=22, hz=20, storeys=1, roof='red', walls='plaster', dormer=True)),
		('cottage_thatch', dict(hx=22, hz=22, storeys=1, roof='thatch', walls='stone', along_x=False)),
		('house_blue', dict(hx=26, hz=24, storeys=2, roof='blue', upper='log')),
		('house_plum', dict(hx=24, hz=26, storeys=2, roof='plum', upper='timber', along_x=False, dormer=True)),
		('house_moss', dict(hx=28, hz=22, storeys=2, roof='moss', upper='timber', porch=True)),
		('lodge_slate', dict(hx=32, hz=26, storeys=2, roof='slate', walls='stone', upper='log', porch=True)),
		('townhouse_red', dict(hx=18, hz=26, storeys=2, roof='red', walls='plaster', upper='timber', along_x=False, rise=22)),
		('turret_house', dict(hx=24, hz=24, storeys=2, roof='blue', walls='stone', upper='timber', turret=True)),
		('cottage_plum', dict(hx=20, hz=20, storeys=1, roof='plum', walls='log', along_x=True, chimney=True)),
	]
	for name, spec in houses:
		b, pal = cottage(name, **spec)
		save(name, b.v, pal, info={'kind': 'house', 'colliders': b.colliders, 'door': [0, -spec['hz']*U]})
	for name, roof, neon, walls in [('hall_moss', 'moss', None, 'log'), ('hall_red', 'red', None, 'plaster'),
			('hall_neon_pink', 'plum', 'pink', 'log'), ('hall_neon_mint', 'slate', 'mint', 'log'), ('hall_neon_amber', 'red', 'amber', 'plaster')]:
		b, pal = hall(name, roof, neon, walls)
		save(name, b.v, pal, info={'kind': 'hall', 'colliders': b.colliders})
	b, pal = spire_hall()
	save('spire_hall', b.v, pal, info={'kind': 'spire_hall', 'colliders': b.colliders})
	v, pal = spire()
	# The shaft's foot inside the hall is solid (the orb is reached by the attendant).
	shaft = [{'kind': 'cyl', 'size': [9.0, 8.0, 9.0], 'offset': [0, 4.0, 0]}]
	save('spire', v, pal, unit=SPIRE_U, info={'kind': 'spire', 'orb_floor': ORB_FLOOR, 'orb_center': ORB_CENTER, 'orb_radius': ORB_RADIUS, 'colliders': shaft})


if __name__ == '__main__':
	main()
