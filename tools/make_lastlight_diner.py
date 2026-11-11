#!/usr/bin/env python3
"""The Last Light Diner, out in the Gloam: a 1950s roadside diner in the
Vesperis buildings' voxel style (make_vesperis_houses.py), on a 25 cm grid.

A rock floats under a steel deck; on it a long diner with an upswept Googie
roof, chrome trim and three neon tubes round the fascia like the Vesperis
bars, big front windows, LAST LIGHT in neon over the door, a DINER pylon with
a starburst, and a chrome rocket on the deck. Inside: a black and cream
checker floor, the counter with its chrome top (the taps, stools and cups are
LastLightDiner's), red booths along both sides, a jukebox, a back bar of
glowing bottles, the menu boards, a neon clock and the kitchen behind the
pass window. The two docking walks are their own model (lastlight_walk).

Front is +Z. Metres = voxels / 4; the deck's top is y = 0.
Run: python3 tools/make_lastlight_diner.py, then bake with
tools/bake_vesperis_houses.tscn (both models land in its catalogue).
"""
import math
from make_creatures import box, line
from make_vesperis_houses import save, h

U = 0.25
PAL = {
	'chrome': (196, 210, 218), 'chrome_dark': (124, 139, 152), 'steel': (86, 93, 106), 'steel_dark': (60, 66, 78),
	'red': (178, 46, 70), 'red_dark': (122, 30, 50), 'cream': (255, 238, 204), 'cream_dark': (222, 200, 160),
	'black': (36, 37, 50), 'teal': (64, 168, 170), 'teal_dark': (40, 118, 124), 'tile': (232, 232, 226), 'tile_dark': (178, 182, 186),
	'stone': (66, 72, 89), 'stone_dark': (46, 50, 64), 'stone_light': (92, 99, 118), 'wood': (122, 80, 50),
	'menu': (30, 30, 42), 'pie': (226, 164, 84), 'glass_case': (150, 210, 220),
	'glow_pink': (255, 83, 170), 'glow_mint': (86, 255, 226), 'glow_amber': (255, 190, 88), 'glow_window': (255, 214, 154),
	'glow_lamp': (255, 238, 205), 'glow_crystal': (110, 255, 230), 'glow_fire': (246, 141, 53), 'glow_red': (255, 70, 70),
	'glow_bottle': (120, 230, 140), 'glow_bottle2': (255, 150, 60),
}
FONT = {
	'A': ['01110', '10001', '10001', '11111', '10001', '10001', '10001'],
	'D': ['11110', '10001', '10001', '10001', '10001', '10001', '11110'],
	'E': ['11111', '10000', '10000', '11110', '10000', '10000', '11111'],
	'G': ['01111', '10000', '10000', '10011', '10001', '10001', '01111'],
	'H': ['10001', '10001', '10001', '11111', '10001', '10001', '10001'],
	'I': ['11111', '00100', '00100', '00100', '00100', '00100', '11111'],
	'L': ['10000', '10000', '10000', '10000', '10000', '10000', '11111'],
	'N': ['10001', '11001', '11001', '10101', '10011', '10011', '10001'],
	'R': ['11110', '10001', '10001', '11110', '10100', '10010', '10001'],
	'S': ['01111', '10000', '10000', '01110', '00001', '00001', '11110'],
	'T': ['11111', '00100', '00100', '00100', '00100', '00100', '00100'],
	' ': ['00000'] * 7,
}

# Building outline (voxels): x -72..72, z -96..48; walls 28 high; roof rises to the front.
X0, X1, Z0, Z1 = -72, 72, -96, 48
DECK_X, DECK_Z = 96, 124
WALL_TOP = 28
ROOF_BACK, ROOF_FRONT, ROOF_Z1 = 28, 40, 60  # the roof's height at the back and front edge, and how far it overhangs


def M(m):
	return int(round(m/U))


class Diner:
	def __init__(self):
		self.v = {}
		self.colliders = []

	def solid(self, x0, x1, y0, y1, z0, z1):
		self.colliders.append({'size': [(x1-x0)*U, (y1-y0)*U, (z1-z0)*U], 'offset': [(x0+x1)*U/2, (y0+y1)*U/2, (z0+z1)*U/2]})

	def text(self, word, x0, y0, z, c, step=1, face=1):
		"""Block letters left to right (as seen from +Z when face=1)."""
		x = x0
		for ch in word:
			rows = FONT[ch]
			for r, row in enumerate(rows):
				for k, bit in enumerate(row):
					if bit == '1':
						px = x+k*step if face > 0 else x-k*step
						box(self.v, px, px+step, y0+(6-r)*step, y0+(7-r)*step, z, z+1, c)
			x += 6*step*face


def roof_y(z):
	return ROOF_BACK+round((z-Z0)/(ROOF_Z1-Z0)*(ROOF_FRONT-ROOF_BACK))


def rock(d):
	"""The floating rock under the deck: a shell over its rounded underside."""
	v = d.v
	depth = {}
	for x in range(-DECK_X, DECK_X):
		for z in range(-DECK_Z, DECK_Z):
			r = ((abs(x)/DECK_X)**4+(abs(z)/DECK_Z)**4)**0.25
			if r > 1.0: continue
			bump = (h(x//6, 0, z//6)-8)*0.5
			depth[x, z] = -3-int((1.0-r)**0.7*104+bump*(1.0-r))
	for (x, z), y0 in depth.items():
		k = 3
		for nx, nz in [(x+1, z), (x-1, z), (x, z+1), (x, z-1)]:
			k = max(k, depth.get((nx, nz), -2)-y0+1)
		for y in range(y0, min(y0+k, -2)):
			c = 'stone_dark' if (y//5) % 3 == 0 else 'stone_light' if h(x, y, z) < 3 else 'stone'
			if y == y0 and h(x, y, z) == 0: c = 'glow_crystal'
			v[x, y, z] = c
	# A crystal spike hanging under the middle.
	low = min(depth.values())
	for y in range(low-20, low+2):
		r = max(1, (y-(low-20))//4)
		box(v, -r, r+1, y, y+1, -r, r+1, 'glow_crystal' if (y % 5) else 'stone_dark')


def deck(d):
	v = d.v
	for x in range(-DECK_X, DECK_X):
		for z in range(-DECK_Z, DECK_Z):
			edge = x in (-DECK_X, DECK_X-1) or z in (-DECK_Z, DECK_Z-1)
			c = 'chrome' if edge else 'steel_dark' if x % 8 == 0 or z % 8 == 0 else 'steel'
			v[x, -1, z] = c
			v[x, -2, z] = 'steel_dark'
	d.solid(-DECK_X, DECK_X, -2, 0, -DECK_Z, DECK_Z)
	# Mint lights along the deck edge.
	for x in range(-DECK_X, DECK_X, 8):
		for z in [-DECK_Z, DECK_Z-1]: v[x, 0, z] = 'glow_mint'
	for z in range(-DECK_Z, DECK_Z, 8):
		for x in [-DECK_X, DECK_X-1]:
			if abs(z) > 12: v[x, 0, z] = 'glow_mint'
	# Railings round the edge, open where the walks come in (x = +-24 m, |z| < 3 m).
	for x in range(-DECK_X, DECK_X, 8):
		for z in [-DECK_Z, DECK_Z-1]: box(v, x, x+1, 0, 5, z, z+1, 'chrome')
	for z in [-DECK_Z, DECK_Z-1]: box(v, -DECK_X, DECK_X, 4, 5, z, z+1, 'chrome')
	for x in [-DECK_X, DECK_X-1]:
		for z in range(-DECK_Z, DECK_Z, 8):
			if abs(z) > 12: box(v, x, x+1, 0, 5, z, z+1, 'chrome')
		for z0, z1 in [(-DECK_Z, -12), (13, DECK_Z)]:
			box(v, x, x+1, 4, 5, z0, z1, 'chrome')
			d.solid(x, x+1, 0, 5, z0, z1)
	for z in [-DECK_Z, DECK_Z-1]: d.solid(-DECK_X, DECK_X, 0, 5, z, z+1)
	# Glowing bollards from each walk to the side doors.
	for side in [-1, 1]:
		for x in range(76, 96, 6):
			for z in [-10, 10]:
				box(v, side*x, side*x+1, 0, 3, z, z+1, 'chrome_dark')
				v[side*x, 3, z] = 'glow_amber'


def building(d):
	v = d.v
	# Floor: one metre black and cream squares, white tiles in the kitchen,
	# a pink and mint star in the middle.
	for x in range(X0, X1):
		for z in range(Z0, Z1):
			if z < -76: c = 'tile' if (x//2+z//2) % 2 else 'tile_dark'
			else: c = 'cream' if (x//4+z//4) % 2 else 'black'
			r = math.hypot(x, z+8)
			a = math.atan2(z+8, x)
			if r < 14+5*math.cos(a*5): c = 'glow_pink' if r < 5 else 'teal' if r < 9+3*math.cos(a*5) else 'cream'
			v[x, -1, z] = c
	# Walls: chrome kick, red band with a cream stripe, windows, cream above.
	def wall_column(x, z, top, window, door):
		for y in range(0, top):
			if door and y < 16: continue
			if window and 6 <= y < 19 and not door: continue
			if y == 0: c = 'chrome'
			elif y < 5: c = 'red'
			elif y == 5: c = 'cream'
			elif y in (19, 23): c = 'chrome'
			elif 24 <= y <= 25: c = 'red'
			else: c = 'cream'
			v[x, y, z] = c
	for z in range(Z0, Z1):
		top = roof_y(z)
		for x, t in [(X0, X0+2), (X1-2, X1)]:
			for xx in range(x, t):
				door = -8 <= z < 8
				window = z > Z0+3 and z < Z1-3 and (z-Z0) % 16 != 0 and z > -74
				wall_column(xx, z, top, window, door)
			# Chrome mullions between the panes, and the door frame.
			if (z-Z0) % 16 == 0 or z in (-9, 8): box(v, x, t, 1, 19, z, z+1, 'chrome')
	for x in range(X0, X1):
		for z in range(Z1-2, Z1):
			door = -12 <= x < 12
			window = abs(x) < 68 and (x+72) % 12 != 0
			wall_column(x, z, roof_y(z), window, door)
			if (x+72) % 12 == 0 or x in (-13, 12): box(v, x, x+1, 1, 20, z, z+1, 'chrome')
		for z in range(Z0, Z0+2):
			wall_column(x, z, roof_y(z), False, False)
	# Door canopies over the side doors, and the chrome door frames.
	for side in [-1, 1]:
		x = X0-1 if side < 0 else X1
		box(v, min(x, x+side*6), max(x, x+side*6)+1, 17, 18, -12, 12, 'chrome')
		box(v, min(x, x+side*6), max(x, x+side*6)+1, 16, 17, -12, 12, 'glow_mint')
	# Colliders: side walls (door gaps), the front (door gap), the back.
	for x0, x1 in [(X0, X0+2), (X1-2, X1)]:
		d.solid(x0, x1, 0, WALL_TOP, Z0, -8)
		d.solid(x0, x1, 0, WALL_TOP, 8, Z1)
		d.solid(x0, x1, 16, WALL_TOP, -8, 8)
	d.solid(X0, -12, 0, WALL_TOP+8, Z1-2, Z1)
	d.solid(12, X1, 0, WALL_TOP+8, Z1-2, Z1)
	d.solid(-12, 12, 16, WALL_TOP+8, Z1-2, Z1)
	d.solid(X0, X1, 0, WALL_TOP, Z0, Z0+2)
	# The kitchen wall with its pass window and door.
	for x in range(X0+2, X1-2):
		for y in range(0, roof_y(-76)):
			if -24 <= x < 24 and 6 <= y < 12: continue
			if 56 <= x < 64 and y < 15: continue
			v[x, y, -77] = 'tile' if (x//2+y//2) % 2 else 'tile_dark'
			v[x, y, -76] = 'red' if 1 <= y < 5 else 'chrome' if y in (0, 5) else 'cream'
	box(v, -25, 25, 5, 6, -79, -74, 'chrome')
	d.solid(X0+2, -24, 0, WALL_TOP, -77, -75)
	d.solid(-24, 24, 0, 6, -77, -75)
	d.solid(-24, 24, 12, WALL_TOP, -77, -75)
	d.solid(24, 56, 0, WALL_TOP, -77, -75)
	d.solid(56, 64, 15, WALL_TOP, -77, -75)
	d.solid(64, X1-2, 0, WALL_TOP, -77, -75)


def roof(d):
	v = d.v
	for z in range(Z0-2, ROOF_Z1):
		y = roof_y(z)
		for x in range(X0-8, X1+8):
			edge = x in (X0-8, X1+7) or z in (Z0-2, ROOF_Z1-1)
			v[x, y, z] = 'chrome' if edge else 'cream_dark'
			v[x, y+1, z] = 'chrome' if edge else 'teal_dark' if (x//6) % 2 else 'teal'
	# Three neon tubes along the fascia (front edge and the sloping sides).
	for k, (lift, c) in enumerate([(0, 'glow_pink'), (2, 'glow_mint'), (4, 'glow_pink')]):
		for x in range(X0-9, X1+9): v[x, roof_y(ROOF_Z1)-1-lift, ROOF_Z1] = c
		for z in range(Z0-2, ROOF_Z1+1):
			for x in [X0-9, X1+8]: v[x, roof_y(z)-1-lift, z] = c
	# The canopy over the front walk rests on two raked chrome posts.
	for side in [-1, 1]:
		line(v, (side*60, 0, 58), (side*52, roof_y(58), 50), 'chrome', 2)
		box(v, side*60-2, side*60+2, 0, 1, 56, 60, 'chrome_dark')
		d.solid(side*60-1, side*60+1, 0, roof_y(58), 54, 58)
		# Atomic starbursts on the roof.
		cx, cz = side*44, -10
		base = roof_y(cz)+2
		box(v, cx, cx+1, base, base+18, cz, cz+1, 'chrome')
		for a in range(0, 360, 30):
			r = 8 if (a//30) % 2 else 5
			for t in range(1, r+1):
				v[cx+round(math.cos(math.radians(a))*t), base+18+round(math.sin(math.radians(a))*t), cz] = 'glow_amber'
	# LAST LIGHT over the door, a chrome bar under it, and a pink underline.
	d.text('LAST LIGHT', -29, 26, Z1, 'glow_pink')
	box(v, -32, 32, 24, 25, Z1, Z1+1, 'glow_mint')
	# Ceiling lamps hanging from the roof (LastLightDiner adds their light).
	for lx in [-40, 0, 40]:
		for lz in [-60, -30, 0, 30]:
			top = roof_y(lz)
			box(v, lx, lx+1, 22, top, lz, lz+1, 'chrome')
			box(v, lx-2, lx+3, 20, 22, lz-2, lz+3, 'glow_lamp')
			box(v, lx-3, lx+4, 22, 23, lz-3, lz+4, 'chrome')


def interior(d):
	v = d.v
	# The counter: red front, chrome bands and top (top at 1.25 m), at z -15 m.
	box(v, -48, 48, 0, 4, -63, -57, 'red')
	box(v, -48, 48, 0, 1, -57, -56, 'chrome')
	box(v, -48, 48, 2, 3, -57, -56, 'chrome')
	box(v, -49, 49, 4, 5, -64, -56, 'chrome')
	d.solid(-48, 48, 0, 5, -64, -56)
	# A pie case on the counter's end, napkin dispensers.
	box(v, 30, 42, 5, 9, -62, -58, 'glass_case')
	for x in range(31, 41, 3): box(v, x, x+2, 5, 6, -61, -59, 'pie')
	for x in [-36, -12, 12]: box(v, x, x+1, 5, 7, -61, -59, 'chrome')
	# Back bar on the kitchen wall: shelves of glowing bottles and coffee urns.
	box(v, -48, 48, 0, 4, -75, -72, 'red_dark')
	box(v, -48, 48, 4, 5, -75, -71, 'chrome')
	for y in [10, 15]:
		box(v, -48, -24, y, y+1, -75, -73, 'chrome')
		box(v, 24, 48, y, y+1, -75, -73, 'chrome')
		for x in list(range(-46, -25, 2))+list(range(26, 47, 2)):
			box(v, x, x+1, y+1, y+3, -75, -74, 'glow_bottle' if (x+y) % 4 else 'glow_bottle2')
	for x in [-20, -14, 14, 20]:
		box(v, x-2, x+2, 5, 10, -75, -72, 'chrome')
		box(v, x-1, x+1, 10, 11, -75, -73, 'chrome_dark')
	d.solid(-48, 48, 0, 5, -75, -71)
	# Menu boards over the pass window, a neon clock and a neon coffee cup.
	box(v, -24, 24, 13, 19, -75, -74, 'menu')
	for row in range(14, 19, 2):
		for x in range(-22, 22, 4):
			box(v, x, x+3 if h(x, row, 0) % 3 else x+2, row, row+1, -74, -73, 'cream')
	for a in range(0, 360, 8):
		v[-40+round(math.cos(math.radians(a))*6), 20+round(math.sin(math.radians(a))*6), -75] = 'glow_mint'
	line(v, (-40, 20, -75), (-40, 24, -75), 'glow_pink')
	line(v, (-40, 20, -75), (-37, 20, -75), 'glow_pink')
	for y in range(16, 22):
		w = 4 if y < 21 else 5
		for x in [40-w, 40+w]: v[x, y, -75] = 'glow_amber'
	box(v, 36, 45, 15, 16, -75, -74, 'glow_amber')
	for k in range(3): line(v, (38+k*2, 22, -75), (38+k*2+(k % 2), 25, -75), 'glow_window')
	# Booths along both side walls: red benches with cream piping, cream tables.
	for side in [-1, 1]:
		for cz in [-40, -20, 18, 36]:
			tx0, tx1 = (56, 68) if side > 0 else (-68, -56)
			box(v, tx0, tx1, 3, 4, cz-3, cz+4, 'cream')
			box(v, tx0, tx1, 3, 4, cz-4, cz-3, 'chrome')
			box(v, tx0, tx1, 3, 4, cz+4, cz+5, 'chrome')
			px = (tx0+tx1)//2
			box(v, px, px+1, 0, 3, cz, cz+1, 'chrome')
			d.solid(tx0, tx1, 0, 4, cz-4, cz+5)
			for end in [-1, 1]:
				bz = cz+end*6
				z0, z1 = (bz-1, bz+2) if end < 0 else (bz-1, bz+2)
				box(v, tx0, tx1, 0, 2, z0, z1, 'red_dark')
				box(v, tx0, tx1, 2, 3, z0, z1, 'red')
				back = bz+end*2
				box(v, tx0, tx1, 0, 6, back, back+1, 'red')
				box(v, tx0, tx1, 6, 7, back, back+1, 'cream')
				d.solid(tx0, tx1, 0, 3, z0, z1)
				d.solid(tx0, tx1, 0, 7, back, back+1)
	# The jukebox in the corner by the counter, facing the room.
	jx, jz = -64, -62
	box(v, jx-3, jx+4, 0, 8, jz-2, jz+2, 'chrome')
	for k, c in enumerate(['glow_pink', 'glow_mint', 'glow_amber', 'glow_pink', 'glow_mint']):
		box(v, jx-2, jx+3, 1+k, 2+k, jz+2, jz+3, c)
	for x in range(jx-3, jx+4):
		top = 8+round(math.sqrt(max(0, 12-(x-jx-0.5)**2)))
		box(v, x, x+1, 8, top, jz-2, jz+2, 'red' if abs(x-jx) < 2 else 'chrome')
	box(v, jx-1, jx+2, 9, 10, jz+2, jz+3, 'glow_window')
	d.solid(jx-3, jx+4, 0, 11, jz-2, jz+3)
	# Kitchen: the grill, its hood and a big chrome fridge.
	box(v, -40, -8, 0, 4, -94, -88, 'steel')
	box(v, -40, -8, 4, 5, -94, -88, 'glow_fire')
	box(v, -42, -6, 14, 18, -95, -86, 'chrome')
	box(v, 30, 46, 0, 14, -94, -88, 'chrome')
	box(v, 37, 39, 4, 11, -88, -87, 'chrome_dark')
	box(v, 0, 20, 0, 4, -94, -88, 'steel_dark')
	box(v, 0, 20, 4, 5, -94, -88, 'chrome')
	d.solid(-40, -8, 0, 5, -94, -88)
	d.solid(0, 20, 0, 5, -94, -88)
	d.solid(30, 46, 0, 14, -94, -88)


def pylon(d):
	"""DINER down a tall pylon at the front left, a starburst on top."""
	v = d.v
	px, pz = -84, 100
	box(v, px-2, px+3, 0, 60, pz-2, pz+3, 'chrome')
	box(v, px-6, px+7, 0, 2, pz-6, pz+7, 'chrome_dark')
	d.solid(px-3, px+4, 0, 60, pz-3, pz+4)
	# The sign panel: cream with a red border, letters on both faces.
	box(v, px-6, px+7, 14, 56, pz-2, pz+3, 'red')
	box(v, px-5, px+6, 15, 55, pz-2, pz+3, 'cream')
	for k, ch in enumerate('DINER'):
		y = 47-k*8
		for face, z in [(1, pz+3), (-1, pz-3)]:
			d.text(ch, px-2 if face > 0 else px+2, y, z, 'glow_pink', 1, face)
	for y in [13, 57]:
		for z in [pz-3, pz+3]: box(v, px-7, px+8, y, y+1, z, z+1, 'glow_mint')
	for a in range(0, 360, 20):
		r = 10 if (a//20) % 2 else 6
		for t in range(2, r+1):
			v[px+round(math.cos(math.radians(a))*t), 66+round(math.sin(math.radians(a))*t), pz] = 'glow_amber'
	box(v, px-1, px+2, 60, 72, pz, pz+1, 'chrome')
	# A neon arrow from the pylon toward the door.
	line(v, (px+8, 10, pz), (px+40, 10, pz), 'glow_mint')
	line(v, (px+40, 10, pz), (px+35, 15, pz), 'glow_mint')
	line(v, (px+40, 10, pz), (px+35, 5, pz), 'glow_mint')
	box(v, px+8, px+9, 0, 10, pz, pz+1, 'chrome')


def rocket(d):
	"""A chrome rocket on the deck at the front right: red fins, a porthole."""
	v = d.v
	cx, cz = 72, 100
	for y in range(4, 46):
		r = 5 if y < 30 else max(0, round(5*(1-((y-30)/16)**1.6)))
		for x in range(-r, r+1):
			for z in range(-r, r+1):
				if x*x+z*z <= r*r and x*x+z*z > (r-2)**2: v[cx+x, y, cz+z] = 'red' if 14 <= y < 16 or y >= 42 else 'chrome'
	for a in [0, 120, 240]:
		ox, oz = math.cos(math.radians(a)), math.sin(math.radians(a))
		for t in range(4, 10):
			top = 18-round((t-4)*1.6)
			for y in range(0, top): v[cx+round(ox*t), y, cz+round(oz*t)] = 'red'
	for a in range(0, 360, 20): v[cx+round(math.cos(math.radians(a))*2), 30+round(math.sin(math.radians(a))*2), cz+5] = 'chrome_dark'
	box(v, cx-1, cx+2, 29, 32, cz+5, cz+6, 'glow_window')
	box(v, cx-2, cx+3, 0, 4, cz-2, cz+3, 'glow_fire')
	d.solid(cx-6, cx+7, 0, 46, cz-6, cz+7)


def walk():
	"""A docking walk (14 x 5 m) from the deck's side out to a ship's hatch."""
	d = Diner()
	v = d.v
	for x in range(-28, 28):
		for z in range(-10, 10):
			v[x, -1, z] = 'chrome' if z in (-10, 9) else 'steel_dark' if x % 8 == 0 else 'steel'
			v[x, -2, z] = 'steel_dark'
			v[x, -3, z] = 'chrome_dark' if z in (-10, 9) else 'steel_dark'
	d.solid(-28, 28, -3, 0, -10, 10)
	for z in [-10, 9]:
		for x in range(-28, 28, 6): box(v, x, x+1, 0, 4, z, z+1, 'chrome')
		box(v, -28, 28, 3, 4, z, z+1, 'glow_mint')
		box(v, -28, 28, 0, 1, z, z+1, 'glow_pink')
		d.solid(-28, 28, 0, 4, z, z+1)
	return d


def main():
	d = Diner()
	rock(d)
	deck(d)
	building(d)
	roof(d)
	interior(d)
	pylon(d)
	rocket(d)
	save('lastlight_diner', d.v, PAL, unit=U, info={'kind': 'diner', 'colliders': d.colliders})
	w = walk()
	save('lastlight_walk', w.v, PAL, unit=U, info={'kind': 'diner_walk', 'colliders': w.colliders})


if __name__ == '__main__':
	main()
