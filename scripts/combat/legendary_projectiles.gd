class_name LegendaryProjectiles
## Individual silhouettes and deterministic paths, shared by local shots,
## network visuals and the review renderer. Offsets use the shot's local frame.

static func offset(s: Dictionary, distance: float) -> Vector3:
	var t := distance
	var u := clampf(distance / maxf(float(s.range), 0.01), 0.0, 1.0)
	var index := roundi(float(s.phase))
	var weapon: Item = s.weapon
	var count := int(weapon.charge.get("count", 1)) if s.secondary else weapon.shots
	var lane := float(index) - float(count - 1) * 0.5
	var hand := -1.0 if index % 2 == 0 else 1.0
	var phase := float(index) * TAU / maxi(count, 1)
	var ramp := smoothstep(0.0, 0.8, distance)
	var out := Vector3.ZERO
	match str(s.motion):
		"kingfisher": out = Vector3(hand * (sin(u * PI * 2.0) * 0.42 + u * 0.28), 0.1 * sin(u * PI), 0)
		"ash": out = Vector3(hand * sin(t * 2.3) * 0.2, (1.0 - cos(t * 2.3)) * 0.13, 0)
		"thornclock": out.x = hand * (2.0 / PI * asin(sin(t * 2.7 + phase))) * 0.3
		"tideglass": out = Vector3(lane * sin(u * PI) * 0.48, sin(u * TAU) * 0.08, 0)
		"sunsplinter": out = Vector3(hand * (2.0 / PI * asin(sin(t * 1.7))) * 0.34, 0.04 * sin(t * 3.4), 0)
		"blackcomet": out = Vector3(sin(u * TAU) * 0.5, sin(u * PI) * 0.16, 0)
		"mirage": out = Vector3(sin(t * 1.2 + phase) * (0.12 + u * 0.55), sin(t * 0.7 + phase) * 0.1, 0)
		"crownbreaker": out = Vector3(sin(t * 1.8 + phase) * 0.33, cos(t * 1.8 + phase) * 0.12, 0)
		"secondhand": out = Vector3(cos(t * 1.45 + phase) * 0.24, sin(t * 1.45 + phase) * 0.22, 0.15 * sin(t * 0.7))
		"silentbell": out = Vector3(sin(t * 2.0 + phase) * u * 0.48, cos(t * 2.0 + phase) * u * 0.22, 0)
		"bellwether": out = Vector3(sin(t * 1.1 + phase) * 0.18, (1.0 - cos(t * 1.1 + phase)) * 0.12, 0)
		"falsepromise": out = Vector3(hand * sin(u * PI * 2.7) * (0.12 + u * 0.48), 0, 0)
		"coldverdict": out = Vector3(hand * sin(u * PI) * 0.12, 0.42 * sin(u * PI) - 0.2 * u, 0)
		"seed": out = Vector3(sin(t * 1.8) * (0.2 + 0.12 * cos(t * 5.4)), (1.0 - cos(t * 1.8)) * 0.15, 0)
		"heartwood": out = Vector3(sin(t * 1.6 + phase) * sin(u * PI) * 0.65, 0.1 * cos(t * 1.6 + phase), 0)
		"timesunder": out = Vector3(hand * sin(t * 0.85) * 0.26, 0, sin(t * 1.4 + phase) * 0.32)
		"daybreaker": out = Vector3(0, 0.34 * sin(u * PI * 0.8), 0)
		"threadcutter": out = Vector3(hand * sin(t * 2.0) * 0.45, 0, 0)
		"eyeless": out = Vector3((2.0 / PI * asin(sin(t * 2.4 + phase))) * 0.25, sin(t * 4.8 + phase) * 0.07, 0)
		"stillpoint": out = Vector3.ZERO
		"eventhorizon": out = Vector3(sin(t * 2.2 + phase) * sin(u * PI) * 0.65, cos(t * 2.2 + phase) * sin(u * PI) * 0.22, 0)
		"dewglass": out = Vector3(0.04 * sin(t), sin(t * 0.9) * 0.23, 0)
		"landfall": out = Vector3(sin(u * PI) * 0.06, 0.65 * u * (1.0 - u) - 0.28 * u * u, 0)
		"sunfeather": out = Vector3(hand * (1.0 - cos(u * PI)) * 0.26, sin(u * PI) * (0.15 + absf(lane) * 0.06), 0)
		"wakeful": out = Vector3(sin(t * 0.8) * 0.13, (1.0 - cos(t * 1.8)) * 0.16, 0)
		"ninthsun": out = Vector3(sin(t * 1.35 + phase) * 0.42, cos(t * 1.35 + phase) * 0.08, 0)
		"kaleidoscope": out = Vector3((2.0 / PI * asin(sin(t * 1.5 + phase))) * 0.38, (2.0 / PI * asin(sin(t * 1.5 + phase + PI / 2))) * 0.12, 0)
		"counterhymn": out = Vector3(0, hand * sin(t * 1.8) * 0.3, 0)
		"worldneedle": out = Vector3((2.0 / PI * asin(sin(t * 4.2 + phase))) * 0.13, sin(t * 2.1) * 0.045, 0)
	return out * ramp * (1.25 if s.secondary else 1.0)

## Each signature is a small voxel figure on a 0.075 m grid, mirrored left to
## right around its flight line (-Z is forward, +Y up). Most lie flat so they
## read from the game camera; `lit` parts glow, `body` parts are matte, and
## how much of each figure glows is part of its identity.
const V := 0.075

static func build(a, body: SurfaceTool, lit: SurfaceTool, id: String, main: Color, accent: Color) -> void:
	match id:
		"kingfisher":
			# A diving kingfisher: blue back, warm belly, long bright beak.
			_fill(a, body, Vector3i(-1, 0, -1), Vector3i(1, 1, 2), main)
			_fill(a, body, Vector3i(-1, 0, -3), Vector3i(1, 1, -2), main.darkened(0.15))
			_fill(a, lit, Vector3i(-1, -1, -2), Vector3i(1, -1, 1), accent)
			_fill(a, lit, Vector3i(0, 0, -6), Vector3i(0, 0, -4), accent.lightened(0.3))
			for x in [2, 3]: _mirror(a, body, x, 1, x - 2, main.lightened(0.1))
			_mirror(a, lit, 4, 1, 2, main.lightened(0.35))
			_fill(a, body, Vector3i(0, 1, 3), Vector3i(0, 1, 4), main)
			_mirror(a, body, 1, 1, 5, main)
			for side in [-1.0, 1.0]: a._box(lit, Vector3(side * 0.08, 0.1, -0.19), Vector3.ONE * 0.035, Color.WHITE)
		"ash":
			# An ember bud: a charcoal heart split by glowing seams, blue flame on top.
			for x in range(-2, 3):
				for y in range(-2, 3):
					for z in range(-2, 3):
						if absi(x) + absi(y) + absi(z) > 2: continue
						var seam := x == 0 and (y + z) % 2 == 0 or absi(x) + absi(y) + absi(z) == 0
						_cell(a, lit if seam else body, x, y, z, main if seam else main.darkened(0.5))
			_cell(a, lit, 0, 3, 0, accent)
			_mirror(a, lit, 1, 3, 1, accent.darkened(0.1), 0.8)
			_cell(a, lit, 0, 4, 1, accent.lightened(0.35), 0.8)
		"thornclock":
			# A thorn arrow carrying a little toothed clock wheel.
			_fill(a, body, Vector3i(0, 0, -2), Vector3i(0, 0, 5), accent.darkened(0.5))
			_fill(a, lit, Vector3i(0, 0, -5), Vector3i(0, 0, -3), main)
			_mirror(a, lit, 1, 0, -3, main.darkened(0.1))
			for c in [Vector2i(2, 0), Vector2i(1, -1), Vector2i(0, -2), Vector2i(1, 1), Vector2i(0, 2)]:
				_mirror(a, lit if (c.x + c.y) % 2 == 0 else body, c.x, 0, 2 + c.y, accent)
			_cell(a, lit, 0, 1, 2, main.lightened(0.3))
			_mirror(a, body, 1, 0, 5, main.darkened(0.2))
		"tideglass":
			# A glass trident, foam curling at the crossbar.
			_fill(a, body, Vector3i(0, 0, 1), Vector3i(0, 0, 6), main.darkened(0.35))
			_fill(a, lit, Vector3i(-2, 0, 0), Vector3i(2, 0, 0), main)
			_fill(a, lit, Vector3i(0, 0, -4), Vector3i(0, 0, -1), main)
			for z in range(-3, 0): _mirror(a, lit, 2, 0, z, main)
			_cell(a, lit, 0, 0, -5, accent)
			_mirror(a, lit, 2, 0, -4, accent)
			_mirror(a, lit, 3, 1, 0, accent, 0.8)
			_mirror(a, lit, 3, 0, 1, accent.darkened(0.1), 0.8)
		"sunsplinter":
			# A flat snowflake of sunlight with a violet heart.
			_cell(a, lit, 0, 0, 0, accent, 1.3)
			for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
				for k in range(1, 4): _cell(a, lit, d.x * k, 0, d.y * k, main.lightened(0.15 * k))
				_cell(a, lit, d.x * 4, 0, d.y * 4, accent, 0.8)
				_cell(a, lit, d.x * 2 + d.y, 0, d.y * 2 + d.x, main, 0.7)
				_cell(a, lit, d.x * 2 - d.y, 0, d.y * 2 - d.x, main, 0.7)
			for d in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
				_cell(a, lit, d.x * 2, 0, d.y * 2, main.lightened(0.3), 0.8)
		"blackcomet":
			# An obsidian rock with glowing cracks and a tapering tail.
			for x in range(-2, 3):
				for y in range(-2, 3):
					for z in range(-2, 3):
						if absi(x) + absi(y) + absi(z) > 2: continue
						var crack := absi(x) == 1 and z == -1 or y == 1 and x == 0
						_cell(a, lit if crack else body, x, y, z - 1, main if crack else main.darkened(0.8))
			for k in 5:
				var t := k / 4.0
				a._box(lit, Vector3(0, 0, (2.2 + k * 1.1) * V), Vector3.ONE * V * (1.6 - t * 1.1), main.lerp(accent, t))
		"mirage":
			# A hollow diamond with a pink diamond floating inside it.
			for x in range(-3, 4):
				for z in range(-3, 4):
					var r := absi(x) + absi(z)
					if r == 3: _cell(a, lit, x, 0, z, main)
					elif r == 1: _cell(a, lit, x, 0, z, accent, 0.8)
			_cell(a, lit, 0, 0, 0, accent.lightened(0.4), 0.8)
		"crownbreaker":
			# A flying crown, points forward, cracked down the middle.
			_fill(a, body, Vector3i(-3, 0, 1), Vector3i(3, 1, 2), main.darkened(0.25))
			for x in [-3, 3]:
				for z in range(-2, 1): _cell(a, body, x, 0, z, main)
				_cell(a, lit, x, 0, -3, accent)
			for x in [-1, 1]:
				_cell(a, body, x, 0, 0, main)
				_cell(a, lit, x, 0, -1, accent)
			_mirror(a, lit, 2, 1, 1, accent.lightened(0.2), 0.7)
			_cell(a, lit, 0, 2, 1, Color("ff5d6c"), 0.8)
		"secondhand":
			# A flat clock face: gold rim, teal dial, bright hands.
			for x in range(-3, 4):
				for z in range(-3, 4):
					var d := x * x + z * z
					if d > 10: continue
					if d >= 7: _cell(a, body, x, 0, z, accent)
					else: _cell(a, body, x, 0, z, main.darkened(0.45))
			_fill(a, lit, Vector3i(0, 1, -2), Vector3i(0, 1, 0), Color("fff6e0"))
			_cell(a, lit, 0, 1, 1, main.lightened(0.3), 0.8)
			for c in [Vector2i(0, -3), Vector2i(0, 3), Vector2i(3, 0), Vector2i(-3, 0)]: _cell(a, lit, c.x, 1, c.y, accent.lightened(0.3), 0.6)
		"silentbell":
			# A bell flying crown first, its mouth glowing, the clapper swinging out.
			_cell(a, body, 0, 0, -4, accent)
			_fill(a, body, Vector3i(-1, -1, -3), Vector3i(1, 1, -3), main)
			for z in range(-2, 2):
				var r := 1 if z < 0 else 2
				for x in range(-r, r + 1):
					for y in range(-r, r + 1):
						if absi(x) == r or absi(y) == r: _cell(a, body, x, y, z, main.darkened(0.1 * (z + 2)))
			for x in range(-2, 3):
				for y in range(-2, 3):
					if absi(x) == 2 or absi(y) == 2: _cell(a, lit if absi(x) == absi(y) else body, x, y, 2, accent if absi(x) == absi(y) else main.darkened(0.3))
			_fill(a, lit, Vector3i(0, 0, 0), Vector3i(0, 0, 2), accent.lightened(0.2))
			_cell(a, lit, 0, 0, 3, main.lightened(0.4), 1.2)
		"bellwether":
			# A tuning fork, tines ringing.
			_fill(a, body, Vector3i(0, 0, 1), Vector3i(0, 0, 5), accent)
			_cell(a, lit, 0, 0, 6, accent.lightened(0.3), 1.2)
			_fill(a, body, Vector3i(-2, 0, 0), Vector3i(2, 0, 0), main.darkened(0.2))
			for z in range(-5, 0): _mirror(a, lit, 2, 0, z, main)
			_cell(a, lit, 0, 0, -3, main.lightened(0.4), 0.6)
			_mirror(a, lit, 1, 0, -6, main.lightened(0.4), 0.6)
		"falsepromise":
			# A gold coin with a square hole, pierced by a blue arrow.
			for x in range(-3, 4):
				for z in range(-3, 4):
					var d := x * x + z * z
					if d > 10 or absi(x) <= 0 and absi(z) <= 0: continue
					_cell(a, lit if d < 7 else body, x, 0, z, accent if d < 7 else accent.darkened(0.3))
			a._box(body, Vector3(0, 0, 0), Vector3(0.05, 0.05, 0.72), main)
			_fill(a, lit, Vector3i(0, 0, -6), Vector3i(0, 0, -5), main.lightened(0.3))
			_mirror(a, lit, 1, 0, -4, main.lightened(0.15))
			_mirror(a, body, 1, 0, 5, main)
		"coldverdict":
			# A guillotine blade: a frosted wedge, edge forward, an iron bar behind.
			for x in range(-3, 4):
				var edge := -3 + absi(x)
				for z in range(edge, 2):
					_cell(a, lit if z == edge else body, x, 0, z, main.lightened(0.35) if z == edge else main.darkened(0.15))
			_fill(a, body, Vector3i(-4, 0, 2), Vector3i(4, 1, 2), accent)
			_mirror(a, body, 4, 1, 1, accent.darkened(0.2))
		"seed":
			# A plump seed split open, a sprout reaching out of the seam.
			for x in range(-1, 2):
				for y in range(-1, 2):
					for z in range(-2, 3):
						if absi(x) + absi(y) == 2 and absi(z) == 2: continue
						var seam := x == 0 and y == 1
						_cell(a, lit if seam else body, x, y, z, accent if seam else main.darkened(0.3))
			_fill(a, lit, Vector3i(0, 2, -1), Vector3i(0, 3, -1), main)
			_mirror(a, lit, 1, 4, -1, main.lightened(0.25))
			_mirror(a, lit, 2, 4, -2, main.lightened(0.4), 0.8)
		"heartwood":
			# A living arrow: wooden shaft, glowing sap leaf head and leaf fletching.
			_fill(a, body, Vector3i(0, 0, -2), Vector3i(0, 0, 5), accent)
			_fill(a, lit, Vector3i(0, 0, -6), Vector3i(0, 0, -3), main)
			_mirror(a, lit, 1, 0, -4, main.darkened(0.1))
			_mirror(a, lit, 1, 0, -3, main.darkened(0.2))
			_cell(a, lit, 0, 1, 1, main.lightened(0.35), 0.8)
			_mirror(a, body, 1, 0, 4, accent.darkened(0.25))
			_mirror(a, lit, 2, 0, 5, main.darkened(0.15), 0.8)
		"timesunder":
			# An hourglass lying along its flight: gold frame, violet glass, falling sand.
			_fill(a, body, Vector3i(-2, 0, -3), Vector3i(2, 1, -3), accent.darkened(0.2))
			_fill(a, body, Vector3i(-2, 0, 3), Vector3i(2, 1, 3), accent.darkened(0.2))
			for z in range(-2, 3): _mirror(a, body, 2, 1, z, accent)
			for z in range(-2, 3):
				var r := 1 if absi(z) >= 1 else 0
				for x in range(-r, r + 1):
					var sand := z == 2 or z == -2 and x == 0 or z == 0
					_cell(a, lit, x, 0, z, accent.lightened(0.2) if sand else main)
		"daybreaker":
			# A spear of light with a small sun burning at its back.
			a._box(lit, Vector3(0, 0, -1.5 * V), Vector3(0.05, 0.05, 9 * V), main)
			_fill(a, lit, Vector3i(0, 0, -8), Vector3i(0, 0, -7), Color.WHITE)
			_mirror(a, lit, 1, 0, -6, main)
			for x in range(-1, 2):
				for z in range(2, 5): _cell(a, lit, x, 0, z, accent)
			for c in [Vector2i(3, 3), Vector2i(2, 1), Vector2i(2, 5)]: _mirror(a, lit, c.x, 0, c.y, accent.lightened(0.25), 0.7)
			_cell(a, lit, 0, 0, 6, accent.lightened(0.25), 0.7)
		"threadcutter":
			# Open scissors: two straight blades crossing at a bright pivot, ring handles behind.
			for k in range(-3, 3):
				if k == 0: continue
				_mirror(a, lit if k <= -2 else body, k, 0, k, accent.lightened(0.35) if k <= -2 else accent)
			_cell(a, lit, 0, 0, 0, main, 1.2)
			for c in [Vector2i(2, 4), Vector2i(4, 4), Vector2i(3, 3), Vector2i(3, 5)]: _mirror(a, body, c.x, 0, c.y, main)
		"eyeless":
			# A wide almond eye with no pupil, only a dark hollow.
			for x in range(-4, 5):
				var h: int = [0, 1, 2, 2, 2][4 - absi(x)]
				for z in range(-h, h + 1):
					var rim := absi(z) == h
					_cell(a, lit if rim else body, x, 0, z, main if rim else accent.darkened(0.55))
			_cell(a, body, 0, 1, 0, Color("0c0814"), 1.2)
			_mirror(a, lit, 5, 0, 0, main.lightened(0.4), 0.7)
		"stillpoint":
			# A wire cube holding one perfectly still bright cube.
			for i in range(-2, 3):
				for e in [Vector2i(-2, -2), Vector2i(-2, 2), Vector2i(2, -2), Vector2i(2, 2)]:
					_cell(a, body, i, e.x, e.y, accent, 0.6)
					_cell(a, body, e.x, i, e.y, accent, 0.6)
					_cell(a, body, e.x, e.y, i, accent, 0.6)
			_cell(a, lit, 0, 0, 0, main, 2.0)
		"eventhorizon":
			# A black hole: a dark core inside a bright, flat accretion disc.
			for x in range(-1, 2):
				for y in range(-1, 2):
					for z in range(-1, 2):
						if absi(x) + absi(y) + absi(z) <= 2: _cell(a, body, x, y, z, Color("0b0c18"))
			for x in range(-4, 5):
				for z in range(-4, 5):
					var d := x * x + z * z
					if d >= 5 and d <= 10: _cell(a, lit, x, 0, z, main)
					elif d > 10 and d <= 17 and (x + z) % 2 == 0: _cell(a, lit, x, 0, z, accent, 0.7)
		"dewglass":
			# A single dewdrop, point forward, with a white glint.
			_cell(a, lit, 0, 0, -3, main.lightened(0.2), 0.8)
			for z in range(-2, 3):
				var r := 0 if z == -2 or z == 2 else 1
				for x in range(-r, r + 1):
					for y in range(-r, r + 1):
						if r == 1 and absi(x) + absi(y) == 2 and z != 0: continue
						_cell(a, lit, x, y, z, main)
			_cell(a, lit, 0, 2, -1, accent.lightened(0.3), 0.6)
		"landfall":
			# An anchor-harpoon: iron shank and arms, bright fluke tips.
			_fill(a, body, Vector3i(0, 0, -3), Vector3i(0, 0, 4), main.darkened(0.35))
			_fill(a, body, Vector3i(-2, 0, 3), Vector3i(2, 0, 3), main.darkened(0.2))
			_mirror(a, body, 1, 0, 5, main.darkened(0.2))
			_cell(a, body, 0, 0, 6, main.darkened(0.2))
			for c in [Vector2i(1, -3), Vector2i(2, -2), Vector2i(3, -1)]: _mirror(a, body, c.x, 0, c.y, main.darkened(0.3))
			_mirror(a, lit, 3, 0, 0, accent)
			_mirror(a, lit, 4, 0, -1, accent.lightened(0.2))
			_fill(a, lit, Vector3i(0, 0, -5), Vector3i(0, 0, -4), accent.lightened(0.3))
		"sunfeather":
			# A flat feather whose vane edges burn.
			_fill(a, lit, Vector3i(0, 0, -5), Vector3i(0, 0, 5), accent)
			for z in range(-4, 4):
				var w := 2 if z > -3 and z < 2 else 1
				for x in range(1, w + 1): _mirror(a, lit if x == w else body, x, 0, z, accent.lightened(0.2) if x == w else main)
		"wakeful":
			# A little lantern: dark cage, warm flame inside.
			for c in [Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1)]:
				for y in range(-1, 2): _cell(a, body, c.x, y, c.y, accent, 0.4)
			_fill(a, body, Vector3i(-1, 2, -1), Vector3i(1, 2, 1), accent.darkened(0.2))
			_fill(a, body, Vector3i(-1, -2, -1), Vector3i(1, -2, 1), accent.darkened(0.2))
			_cell(a, body, 0, 3, 0, accent)
			_cell(a, lit, 0, 0, 0, main, 1.7)
			_cell(a, lit, 0, 1, 0, main.lightened(0.4), 1.0)
		"ninthsun":
			# An arrow wearing a cold halo around its head.
			_fill(a, body, Vector3i(0, 0, -2), Vector3i(0, 0, 5), accent.darkened(0.3))
			_fill(a, lit, Vector3i(0, 0, -5), Vector3i(0, 0, -3), accent)
			for c in [Vector2i(2, -3), Vector2i(2, -2), Vector2i(1, -1), Vector2i(1, -5), Vector2i(2, -4)]: _mirror(a, lit, c.x, 0, c.y, main)
			_mirror(a, lit, 1, 0, 5, main.darkened(0.15))
			_mirror(a, body, 1, 0, 4, main.darkened(0.3))
		"kaleidoscope":
			# A stained-glass kite with dark leading and a ribbon tail.
			var panes := [main, accent, Color("ffe28a"), Color("9fb4ff")]
			for x in range(-3, 4):
				for z in range(-4, 3):
					if absi(x) * 4 + absi(z + 1) * 3 > 12: continue
					var lead := x == 0 or z == -1
					_cell(a, body if lead else lit, x, 0, z, Color("1c1822") if lead else panes[(0 if z < -1 else 2) + (0 if absi(x) == 1 else 1)])
			for c in [Vector2i(0, 3), Vector2i(0, 5)]: _cell(a, lit, c.x, 0, c.y, main, 0.8)
			_mirror(a, lit, 1, 0, 4, accent, 0.8)
		"counterhymn":
			# A lyre glyph: two curved arms, bright strings between them.
			for c in [Vector2i(2, 3), Vector2i(3, 2), Vector2i(3, 1), Vector2i(3, 0), Vector2i(2, -1), Vector2i(2, -2), Vector2i(3, -3)]:
				_mirror(a, body, c.x, 0, c.y, main)
			_fill(a, body, Vector3i(-2, 0, 4), Vector3i(2, 0, 4), main.darkened(0.2))
			_fill(a, body, Vector3i(-2, 0, -2), Vector3i(2, 0, -2), main.darkened(0.2))
			for x in [-1, 0, 1]:
				a._box(lit, Vector3(x * V, 0, 1 * V), Vector3(0.022, 0.022, 5 * V), accent.lightened(0.2))
			_mirror(a, lit, 3, 0, -4, accent, 0.7)
		"worldneedle":
			# A long needle trailing a loop of pink thread through its eye.
			a._box(lit, Vector3(0, 0, -1 * V), Vector3(0.045, 0.045, 10 * V), main)
			_cell(a, lit, 0, 0, -7, main.lightened(0.4), 0.6)
			_mirror(a, lit, 1, 0, 4, main)
			_cell(a, lit, 0, 0, 5, main)
			for c in [Vector2i(1, 6), Vector2i(2, 7), Vector2i(1, 8), Vector2i(2, 9)]: _mirror(a, lit, c.x, 0, c.y, accent, 0.7)

## One cube on the grid (scale < 1 leaves a gap, > 1 makes a chunky core).
static func _cell(a, tool: SurfaceTool, x: int, y: int, z: int, color: Color, scale := 1.0) -> void:
	a._box(tool, Vector3(x, y, z) * V, Vector3.ONE * V * scale, color)

## The same cube on both sides of the flight line (once on it).
static func _mirror(a, tool: SurfaceTool, x: int, y: int, z: int, color: Color, scale := 1.0) -> void:
	_cell(a, tool, x, y, z, color, scale)
	if x != 0: _cell(a, tool, -x, y, z, color, scale)

static func _fill(a, tool: SurfaceTool, from: Vector3i, to: Vector3i, color: Color) -> void:
	for x in range(mini(from.x, to.x), maxi(from.x, to.x) + 1):
		for y in range(mini(from.y, to.y), maxi(from.y, to.y) + 1):
			for z in range(mini(from.z, to.z), maxi(from.z, to.z) + 1): _cell(a, tool, x, y, z, color)

static func trail(pm: ParticleProcessMaterial, id: String) -> Dictionary:
	var size := Vector3.ONE * 0.04
	var amount := 18
	var life := 0.3
	pm.spread = 8.0
	pm.initial_velocity_min = 0.05
	pm.initial_velocity_max = 0.25
	match id:
		"feathers", "sunfeathers": size = Vector3(0.025, 0.025, 0.12); pm.gravity = Vector3(0, 0.3, 0); life = 0.42
		"embers", "cinders": pm.gravity = Vector3(0, 1.3, 0); pm.spread = 25; life = 0.45
		"thorns": size = Vector3(0.025, 0.025, 0.13); pm.spread = 3
		"spray", "brine": pm.gravity = Vector3(0, -1.8, 0); pm.spread = 26; size = Vector3(0.025, 0.06, 0.025)
		"snow": pm.gravity = Vector3(0, -0.3, 0); pm.spread = 35; life = 0.5
		"glass", "metal", "shavings": size = Vector3(0.025, 0.025, 0.1); pm.spread = 15
		"ticks", "notes", "sound", "chimes": size = Vector3(0.018, 0.08, 0.018); life = 0.25; pm.spread = 2
		"coins": size = Vector3(0.065, 0.065, 0.015); pm.gravity = Vector3(0, -0.8, 0)
		"seeds", "sand": size = Vector3.ONE * 0.025; pm.gravity = Vector3(0, -0.4, 0); amount = 22
		"leaves": size = Vector3(0.07, 0.018, 0.1); pm.gravity = Vector3(0, 0.4, 0); life = 0.45
		"rays", "sundust": size = Vector3(0.02, 0.02, 0.15); pm.spread = 4; life = 0.38
		"threads", "stitches": size = Vector3.ONE * 0.016; pm.initial_velocity_min = 0; pm.initial_velocity_max = 0; pm.spread = 0; amount = 32; life = 0.4
		"silence": size = Vector3.ONE * 0.018; life = 0.12; amount = 6
		"void": pm.initial_velocity_max = 0.08; pm.spread = 45; life = 0.6; amount = 16
		"drops": size = Vector3(0.03, 0.07, 0.03); pm.gravity = Vector3(0, -1.1, 0)
		"wisps": pm.gravity = Vector3(0, 0.65, 0); pm.spread = 18; life = 0.55
		"prism": size = Vector3(0.04, 0.04, 0.07); pm.hue_variation_min = -1; pm.hue_variation_max = 1; life = 0.4
	return {size = size, amount = amount, life = life}
