#!/usr/bin/env python3
"""The Pet Store on the Pet Yard island: a walk-in shop in the Vesperis
buildings' cosy voxel style (make_vesperis_houses.py), on a 12.5 cm grid.

Outside: a stone footing, pastel plaster walls in a timber frame, two big
lit shop windows either side of an open double door, a striped awning, PETS
in warm glowing letters over the door, a hanging paw sign, flower boxes and a
round gable window. Inside: a planked floor with a round rug, the counter at
the back (the storekeeper stands behind it, PetYardWorld.STORE_POS), shelves
of speckled eggs in straw along the left wall, a glowing fish tank, pet beds
and a cat tree on the right, potted plants, hanging lanterns.

The roof is its own model (pet_store_roof) so the yard can hide it while you
are inside. Front is -Z; the floor's top is y = 0 (its planks lie just under).
Run: python3 tools/make_pet_store.py, then bake with
tools/bake_vesperis_houses.tscn (both models land in its catalogue).
"""
import math
from make_creatures import box, line
from make_vesperis_houses import House, BASE, h, save

U = 0.125
PAL = dict(BASE)
PAL.update({
	'roof': (70, 140, 136), 'roof_light': (98, 170, 160), 'roof_dark': (44, 98, 100),
	'plaster': (240, 222, 196), 'plaster_pink': (236, 196, 190), 'awning': (232, 120, 132), 'awning2': (250, 236, 214),
	'egg_cream': (246, 232, 200), 'egg_mint': (156, 222, 190), 'egg_pink': (240, 170, 186), 'egg_sky': (150, 196, 236),
	'egg_gold': (240, 204, 110), 'speck': (120, 96, 80), 'straw': (222, 186, 102), 'straw_dark': (180, 142, 72),
	'cushion': (120, 150, 210), 'cushion2': (226, 134, 120), 'rug2': (238, 206, 150), 'pot': (176, 98, 66),
	'tank': (60, 70, 82), 'glow_aqua': (90, 200, 236), 'glow_fish': (255, 160, 60), 'glow_sign': (255, 214, 140),
	'paw': (96, 60, 40),
})
FONT = {
	'P': ['11110', '10001', '10001', '11110', '10000', '10000', '10000'],
	'E': ['11111', '10000', '10000', '11110', '10000', '10000', '11111'],
	'T': ['11111', '00100', '00100', '00100', '00100', '00100', '00100'],
	'S': ['01111', '10000', '10000', '01110', '00001', '00001', '11110'],
}
HX, HZ = 52, 40  # outer wall faces (voxels): 13 m x 10 m
TOP = 30  # wall height: 3.75 m
DOOR = 12  # half width of the double door


def egg(v, x, y, z, c):
	"""A speckled egg, 2x3x2 with a rounded top."""
	box(v, x, x+2, y, y+2, z, z+2, c)
	v[x, y+2, z] = c
	v[x+1, y+2, z+1] = c
	v[x+(h(x, y, z) % 2), y+1, z+(h(z, y, x) % 2)] = 'speck'


def shell(b):
	v = b.v
	# Footing and the planked floor (just under y = 0).
	# The footing spans 13.5 x 10.5 m exactly, on the yard's 0.25 m terrain grid.
	box(v, -HX-2, HX+2, -3, 0, -HZ-2, HZ+2, 'stone')
	for x in range(-HX+3, HX-2):
		for z in range(-HZ+3, HZ-2):
			v[x, -1, z] = 'plank_dark' if x % 7 == 0 else 'plank'
	# Walls: pastel plaster with a timber frame (3 thick).
	for x in range(-HX, HX+1):
		for z in range(-HZ, HZ+1):
			if abs(x) < HX-2 and abs(z) < HZ-2: continue
			for y in range(0, TOP):
				beam = y < 2 or y >= TOP-2 or (abs(x) >= HX-2 and abs(z) >= HZ-2) or y == 15
				if not beam and abs(z) >= HZ-2 and x % 26 == 0: beam = True
				if not beam and abs(x) >= HX-2 and z % 20 == 0: beam = True
				v[x, y, z] = 'beam' if beam else ('plaster_pink' if y < 15 else 'plaster')
	# Colliders: front wall either side of the door, back and sides, the floor slab.
	b.solid(-HX, -DOOR-1, 0, TOP, -HZ, -HZ+3)
	b.solid(DOOR+1, HX+1, 0, TOP, -HZ, -HZ+3)
	b.solid(-HX, HX+1, 0, TOP, HZ-2, HZ+1)
	b.solid(-HX, -HX+3, 0, TOP, -HZ, HZ+1)
	b.solid(HX-2, HX+1, 0, TOP, -HZ, HZ+1)
	# Ceiling beams across the room (the roof sits above, hidden when inside).
	for x in range(-HX+8, HX-6, 16):
		box(v, x, x+2, TOP-2, TOP, -HZ+3, HZ-2, 'beam')


def front(b):
	v = b.v
	# The open double door: frame, step, two doors swung open against the wall.
	b.carve(-DOOR, DOOR+1, 0, 22, -HZ-1, -HZ+4)
	for side in [-1, 1]:
		box(v, side*(DOOR+1)-(1 if side < 0 else 0), side*(DOOR+1)+(1 if side > 0 else 0)+1, 0, 24, -HZ-2, -HZ+3, 'beam')
		# The door leaf, open outward against the facade.
		x0 = side*(DOOR+2)
		for x in range(min(x0, x0+side*10), max(x0, x0+side*10)+1):
			for y in range(1, 21):
				v[x, y, -HZ-2] = 'wood_dark' if y in (1, 20) or x in (x0, x0+side*10) else 'wood' if (x+y) % 5 else 'wood_light'
			v[x, 12, -HZ-3] = 'brass' if x == x0+side*8 else v.get((x, 12, -HZ-3), None) or 'wood_dark'
	box(v, -DOOR-2, DOOR+3, 22, 24, -HZ-2, -HZ+3, 'beam')
	box(v, -DOOR-1, DOOR+2, 0, 1, -HZ-6, -HZ+1, 'stone_light')
	# Shop windows either side: wide lit panes with mullions and flower boxes.
	for cx in [-34, 34]:
		b.window(cx, 12, -HZ, -1, 18, 12)
	# Side and back windows.
	for side in [-1, 1]:
		for z in [-16, 16]: b.window(z, 13, side*HX, 2*side, 8, 8)
	b.window(-26, 13, HZ, 1, 8, 8, flowers=False)
	b.window(26, 13, HZ, 1, 8, 8, flowers=False)
	# A striped awning over the windows and door.
	for x in range(-HX+2, HX-1):
		for d in range(0, 9):
			y = 25-d//2
			c = 'awning' if (x//4) % 2 else 'awning2'
			v[x, y, -HZ-1-d] = c
		v[x, 20, -HZ-10] = 'awning' if (x//4) % 2 else 'awning2'
	for x in [-HX+2, HX-2]:
		for y in range(20, 26): v[x, y, -HZ-9] = 'wood_dark'
	# PETS over the door in glowing block letters, on a dark board.
	box(v, -17, 18, 26, 37, -HZ-3, -HZ, 'wood_dark')
	box(v, -18, 19, 25, 26, -HZ-3, -HZ, 'beam')
	box(v, -18, 19, 37, 38, -HZ-3, -HZ, 'beam')
	x = -14
	for ch in 'PETS':
		for r, row in enumerate(FONT[ch]):
			for k, bit in enumerate(row):
				if bit == '1':
					# Seen from -Z, so letters run from +x to -x.
					v[-(x+k), 28+(6-r), -HZ-4] = 'glow_sign'
		x += 7
	# A hanging paw sign on an iron bracket by the door.
	box(v, DOOR+4, DOOR+14, 27, 28, -HZ-8, -HZ-7, 'iron')
	box(v, DOOR+6, DOOR+13, 17, 26, -HZ-8, -HZ-7, 'wood_light')
	for p in [(9, 19), (8, 21), (10, 22), (12, 21), (11, 19), (10, 20)]:
		v[DOOR+p[0]-1, p[1], -HZ-9] = 'paw'
	box(v, DOOR+8, DOOR+11, 18, 20, -HZ-9, -HZ-8, 'paw')
	# Lanterns either side of the door.
	for x in [-DOOR-5, DOOR+4]:
		box(v, x, x+2, 17, 19, -HZ-4, -HZ, 'iron')
		box(v, x, x+2, 13, 17, -HZ-5, -HZ-3, 'glow_window')
	# Planters along the front, flowers spilling.
	for cx in [-46, 46]:
		box(v, cx-4, cx+5, 0, 4, -HZ-6, -HZ-2, 'pot')
		for x in range(cx-4, cx+5):
			for z in range(-HZ-6, -HZ-2):
				v[x, 4, z] = 'leaf'
				if h(x, 5, z) < 6: v[x, 5, z] = 'flower' if h(x, z, 3) % 2 else 'flower2'


def interior(b):
	v = b.v
	# A round rug in the middle.
	for x in range(-18, 19):
		for z in range(-14, 12):
			d = math.hypot(x/1.3, z+1)
			if d < 13: v[x, 0, z] = 'rug' if d > 10.5 or (int(d) % 4 == 0) else 'rug2'
	# The counter across the back, the storekeeper behind it (z ~ +3.6 m).
	cz0, cz1 = HZ-18, HZ-13
	box(v, -20, 21, 0, 8, cz0, cz1, 'wood')
	for x in range(-20, 21, 5): box(v, x, x+1, 0, 8, cz0-1, cz0, 'wood_dark')
	box(v, -21, 22, 8, 9, cz0-1, cz1+1, 'wood_light')
	b.solid(-21, 22, 0, 9, cz0-1, cz1+1)
	# On the counter: a brass till, a basket of eggs, a jar of treats.
	box(v, 10, 15, 9, 13, cz0+1, cz1-1, 'brass')
	box(v, 11, 14, 13, 14, cz0+2, cz1-2, 'glow_window')
	box(v, -14, -6, 9, 11, cz0, cz1, 'straw_dark')
	for i, c in enumerate(['egg_mint', 'egg_pink', 'egg_sky', 'egg_cream']):
		egg(v, -13+i*2, 11, cz0+1+(i % 2), c)
	box(v, -2, 2, 9, 14, cz0+1, cz0+4, 'glass')
	box(v, -2, 2, 14, 15, cz0+1, cz0+4, 'brass')
	# Back wall shelves behind the keeper with jars and egg crates.
	for y in [10, 17, 24]:
		box(v, -26, 27, y, y+1, HZ-6, HZ-2, 'wood_dark')
		for x in range(-24, 25, 4):
			c = ['egg_gold', 'jar', 'egg_sky', 'jar', 'egg_pink', 'leaf'][(x//4+y) % 6]
			if c == 'jar':
				box(v, x, x+2, y+1, y+4, HZ-5, HZ-3, 'glass')
				v[x, y+4, HZ-5] = 'brass'
			elif c == 'leaf':
				box(v, x, x+2, y+1, y+3, HZ-5, HZ-3, 'pot')
				box(v, x-1, x+3, y+3, y+5, HZ-5, HZ-3, 'leaf')
			else:
				egg(v, x, y+1, HZ-5, c)
	# Left wall: three long shelves of eggs nested in straw.
	colours = ['egg_cream', 'egg_mint', 'egg_pink', 'egg_sky', 'egg_gold']
	for k, y in enumerate([4, 11, 18]):
		box(v, -HX+3, -HX+9, y, y+1, -HZ+8, HZ-8, 'wood_dark')
		box(v, -HX+3, -HX+9, y+1, y+2, -HZ+8, HZ-8, 'straw')
		for z in range(-HZ+9, HZ-9, 4):
			egg(v, -HX+5, y+2, z, colours[(z//4+k) % 5])
	for z in [-HZ+7, HZ-8]:
		box(v, -HX+3, -HX+10, 0, 22, z, z+1, 'wood_dark')
	b.solid(-HX+3, -HX+10, 0, 22, -HZ+7, HZ-7)
	# Right wall: a glowing fish tank on a cabinet.
	box(v, HX-10, HX-2, 0, 8, -HZ+8, -HZ+26, 'wood_dark')
	box(v, HX-10, HX-2, 8, 18, -HZ+8, -HZ+26, 'glow_aqua')
	box(v, HX-9, HX-3, 9, 10, -HZ+9, -HZ+25, 'straw')
	for z, y in [(-HZ+12, 13), (-HZ+18, 15), (-HZ+22, 12)]:
		box(v, HX-11, HX-10, y, y+2, z, z+3, 'glow_fish')
	box(v, HX-11, HX-1, 18, 19, -HZ+7, -HZ+27, 'tank')
	b.solid(HX-11, HX-1, 0, 19, -HZ+7, -HZ+27)
	# Pet beds: round cushions in a row.
	for k, cz in enumerate([4, 16]):
		for x in range(HX-14, HX-3):
			for z in range(cz-5, cz+6):
				d = math.hypot(x-(HX-8.5), z-cz)
				if d < 5.5: v[x, 0, z] = 'wood_dark' if d > 4.5 else ('cushion' if k == 0 else 'cushion2')
				if 4.2 < d < 5.5: v[x, 1, z] = 'cushion' if k == 0 else 'cushion2'
				if 4.6 < d < 5.5 and z > cz: v[x, 2, z] = 'cushion' if k == 0 else 'cushion2'
	# A cat tree in the back right corner: a post with platforms.
	cx, cz = HX-10, HZ-12
	box(v, cx-1, cx+2, 0, 26, cz-1, cz+2, 'straw_dark')
	for y, s in [(8, 5), (16, 4), (25, 5)]:
		box(v, cx-s, cx+s+1, y, y+2, cz-s, cz+s+1, 'cushion2' if y != 16 else 'cushion')
	b.solid(cx-5, cx+6, 0, 27, cz-5, cz+6)
	# Potted plants in the front corners inside.
	for x in [-HX+16, HX-16]:
		box(v, x-2, x+3, 0, 4, -HZ+5, -HZ+10, 'pot')
		for y in range(4, 12):
			r = 3 if y < 9 else 2
			box(v, x-r, x+r+1, y, y+1, -HZ+7-r, -HZ+8+r, 'leaf' if (y+x) % 3 else 'roof_light')
	# Two round display tables by the windows, eggs in straw on top.
	for tx in [-28, 26]:
		tz = -HZ+18
		for x in range(tx-5, tx+6):
			for z in range(tz-5, tz+6):
				d = math.hypot(x-tx, z-tz)
				if d <= 5: v[x, 7, z] = 'wood_light' if d > 4 else 'straw'
		box(v, tx-1, tx+2, 0, 7, tz-1, tz+2, 'wood_dark')
		box(v, tx-3, tx+4, 0, 1, tz-3, tz+4, 'wood_dark')
		for i, (ex, ez) in enumerate([(-3, -1), (0, -3), (1, 1), (-2, 2), (2, -1)]):
			egg(v, tx+ex, 8, tz+ez, colours[(i+tx) % 5])
		b.solid(tx-5, tx+6, 0, 8, tz-5, tz+6)
	# Hanging lanterns from the ceiling beams.
	for x in [-24, 0, 24]:
		for z in [-14, 8]:
			line(v, (x, TOP-2, z), (x, TOP-7, z), 'iron')
			box(v, x-1, x+2, TOP-10, TOP-7, z-1, z+2, 'glow_window')
			box(v, x-2, x+3, TOP-7, TOP-6, z-2, z+3, 'iron')


def roof():
	"""Gabled teal shingles from side to side (ridge along x), a round
	window in each gable, a stone chimney."""
	v = {}
	span, rise, over = HZ+5, 22, 6
	base = TOP
	for a in range(-span, span+1):
		y = base+round((1-abs(a)/span)*rise)
		for x in range(-HX-over, HX+over+1):
			for t in [0, 1]:
				c = 'roof_dark' if (abs(a)//3) % 2 else 'roof'
				if (x+(abs(a)//3 % 2)*2) % 6 == 0: c = 'roof_dark'
				elif h(x, y, a) < 3: c = 'roof_light'
				v[x, y+t, a] = c
			if abs(x) == HX+over: v[x, y-1, a] = 'beam'
	for x in range(-HX-over, HX+over+1): v[x, base+rise+2, 0] = 'beam'
	# Gable ends: plaster between beams, a round lit window in each.
	for end in [-1, 1]:
		for a in range(-HZ, HZ+1):
			top = base+round((1-abs(a)/span)*rise)
			for y in range(base, top):
				d = math.hypot(a, y-(base+9))
				c = 'plaster' if (y-base+abs(a)) % 13 else 'beam'
				if d < 5: c = 'glow_window' if d < 4 else 'beam'
				v[end*(HX-1), y, a] = c
	for y in range(base+8, base+rise+12):
		for x in range(20, 27):
			for z in range(10, 17):
				if x in (20, 26) or z in (10, 16): v[x, y, z] = 'mortar' if y % 4 == 0 else 'stone'
	box(v, 19, 28, base+rise+12, base+rise+14, 9, 18, 'stone_light')
	return v


def main():
	b = House()
	shell(b)
	front(b)
	interior(b)
	PAL['jar'] = (150, 200, 210)
	save('pet_store_house', b.v, PAL, unit=U, info={'kind': 'pet_store', 'colliders': b.colliders})
	save('pet_store_roof', roof(), PAL, unit=U, info={'kind': 'pet_store_roof', 'colliders': []})


if __name__ == '__main__':
	main()
