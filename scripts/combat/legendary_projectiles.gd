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

## Reuse the existing voxel/crystal primitives, but author each outline separately.
static func build(a, body: SurfaceTool, lit: SurfaceTool, id: String, main: Color, accent: Color) -> void:
	match id:
		"kingfisher":
			a._crystal(body, Vector3.ZERO, 0.045, 0.9, main)
			for i in 4:
				var p := Vector3(0.06 + i * 0.04, 0, 0.02 + i * 0.12)
				a._crystal(lit, p, 0.035, 0.22, accent)
				a._crystal(lit, Vector3(-p.x, 0, p.z), 0.035, 0.22, accent)
		"ash":
			a._crystal(body, Vector3.ZERO, 0.12, 0.32, main.darkened(0.4))
			for i in 3: a._crystal(lit, Vector3((i - 1) * 0.12, 0, i * 0.08), 0.06, 0.5 - i * 0.08, accent)
		"thornclock":
			for i in 6:
				var angle := (i - 2.5) * 0.55
				a._crystal(lit if i % 2 else body, Vector3(sin(angle) * 0.23, 0, cos(angle) * 0.23), 0.045, 0.23, main if i % 2 else accent)
			a._box(body, Vector3(0.05, 0, 0.24), Vector3(0.16, 0.04, 0.05), main)
		"tideglass":
			for x in [-0.18, 0.0, 0.18]: a._crystal(lit, Vector3(x, 0, absf(x) * 0.65), 0.055, 0.65, main)
			a._box(body, Vector3(0, 0, 0.22), Vector3(0.42, 0.045, 0.07), accent)
		"sunsplinter":
			for i in 6:
				var angle := TAU * i / 6.0
				for j in 3: a._box(lit, Vector3(cos(angle), sin(angle), 0) * (0.05 + j * 0.07), Vector3.ONE * 0.055, accent if j == 2 else main)
		"blackcomet":
			a._crystal(body, Vector3(0, 0, -0.1), 0.16, 0.48, main.darkened(0.7))
			a._crystal(lit, Vector3(0.08, 0.02, -0.16), 0.035, 0.35, accent)
			for i in 3: a._box(lit, Vector3(sin(i * 2.1) * 0.09, 0, 0.2 + i * 0.13), Vector3.ONE * (0.08 - i * 0.018), main)
		"mirage":
			_ring(a, lit, 4, 0.25, 0.045, 0.06, main, PI / 4)
			_ring(a, body, 4, 0.14, 0.03, 0.04, accent, PI / 4)
		"crownbreaker":
			a._box(body, Vector3(0, 0, 0.15), Vector3(0.44, 0.06, 0.1), main)
			for i in 3: a._crystal(lit, Vector3((i - 1) * 0.18, 0, -0.08 if i == 1 else 0.02), 0.045, 0.38 if i == 1 else 0.26, accent)
		"secondhand":
			_ring(a, body, 12, 0.22, 0.035, 0.04, main)
			a._box(lit, Vector3(0.08, 0, -0.03), Vector3(0.24, 0.025, 0.025), accent)
			a._box(lit, Vector3(0, 0.06, -0.03), Vector3(0.025, 0.18, 0.025), accent)
		"silentbell":
			_ring(a, lit, 8, 0.21, 0.05, 0.22, main)
			a._box(body, Vector3(0, 0.21, -0.12), Vector3(0.2, 0.045, 0.11), accent)
			a._crystal(lit, Vector3(0, -0.03, 0.08), 0.04, 0.15, accent)
		"bellwether":
			for x in [-0.13, 0.13]: a._box(lit, Vector3(x, 0, -0.08), Vector3(0.05, 0.06, 0.53), main)
			a._box(body, Vector3(0, 0, 0.18), Vector3(0.31, 0.06, 0.06), accent)
			a._crystal(lit, Vector3(0, 0, 0.32), 0.04, 0.24, accent)
		"falsepromise":
			_ring(a, lit, 10, 0.22, 0.07, 0.045, accent)
			a._box(body, Vector3(0, 0, -0.02), Vector3(0.055, 0.3, 0.035), main)
		"coldverdict":
			a._box(body, Vector3.ZERO, Vector3(0.48, 0.06, 0.32), main.darkened(0.4))
			for i in 5: a._box(lit, Vector3((i - 2) * 0.09, 0, -0.18 + i * 0.025), Vector3(0.085, 0.04, 0.045), accent)
		"seed":
			a._crystal(body, Vector3.ZERO, 0.13, 0.42, main)
			for x in [-0.15, 0.15]: a._crystal(lit, Vector3(x, 0, 0.06), 0.06, 0.28, accent)
		"heartwood":
			a._crystal(body, Vector3.ZERO, 0.04, 0.7, accent)
			for i in 3:
				var x := (1.0 if i % 2 == 0 else -1.0) * 0.11
				a._crystal(lit, Vector3(x, 0, (i - 1) * 0.15), 0.08, 0.28, main)
		"timesunder":
			for z in [-0.25, 0.25]: a._box(body, Vector3(0, 0, z), Vector3(0.32, 0.08, 0.04), main)
			for i in 5:
				var z := (i - 2) * 0.1
				for hand in [-1.0, 1.0]: a._box(lit, Vector3(hand * absf(z) * 0.55, 0, z), Vector3.ONE * 0.045, accent)
		"daybreaker":
			a._crystal(lit, Vector3.ZERO, 0.055, 1.1, accent)
			for x in [-0.13, 0.13]: a._crystal(body, Vector3(x, 0, 0.05), 0.04, 0.46, main)
			a._box(lit, Vector3(0, 0, 0.24), Vector3(0.4, 0.035, 0.035), accent)
		"threadcutter":
			for side in [-1.0, 1.0]:
				for i in 5: a._box(lit, Vector3(side * (0.04 + i * 0.045), 0, -0.27 + i * 0.11), Vector3(0.055, 0.035, 0.13), main)
			_ring(a, body, 6, 0.1, 0.03, 0.035, accent)
		"eyeless":
			for i in 8:
				var angle := TAU * i / 8.0
				a._crystal(lit, Vector3(cos(angle) * 0.3, sin(angle) * 0.11, 0), 0.035, 0.19, main)
		"stillpoint":
			for x in [-0.16, 0.16]:
				for y in [-0.16, 0.16]: a._box(lit, Vector3(x, y, 0), Vector3(0.025, 0.025, 0.34), accent)
			for y in [-0.16, 0.16]: a._box(body, Vector3(0, y, 0), Vector3(0.34, 0.025, 0.025), main)
			for x in [-0.16, 0.16]: a._box(body, Vector3(x, 0, 0), Vector3(0.025, 0.34, 0.025), main)
			a._box(lit, Vector3.ZERO, Vector3.ONE * 0.055, accent)
		"eventhorizon":
			a._crystal(body, Vector3.ZERO, 0.12, 0.24, Color("101222"))
			_ring(a, lit, 12, 0.27, 0.04, 0.08, main)
			for x in [-0.34, 0.34]: a._crystal(lit, Vector3(x, 0, 0.08), 0.03, 0.25, accent)
		"dewglass":
			a._crystal(lit, Vector3(0, 0.04, 0), 0.13, 0.32, main)
			a._crystal(body, Vector3(0, -0.13, -0.03), 0.055, 0.2, accent)
		"landfall":
			a._box(body, Vector3.ZERO, Vector3(0.045, 0.045, 0.72), main)
			a._crystal(lit, Vector3(0, 0, -0.39), 0.07, 0.22, accent)
			for x in [-0.16, 0.16]:
				a._box(lit, Vector3(x, 0, 0.18), Vector3(0.05, 0.05, 0.18), accent)
				a._box(body, Vector3(x / 2, 0, 0.28), Vector3(0.18, 0.05, 0.045), main)
		"sunfeather":
			a._crystal(lit, Vector3.ZERO, 0.04, 0.82, accent)
			for i in 5: a._crystal(body if i % 2 else lit, Vector3(0.07 + i * 0.04, 0, -0.2 + i * 0.11), 0.04, 0.26, main)
		"wakeful":
			for x in [-0.13, 0.13]:
				for y in [-0.13, 0.13]: a._box(body, Vector3(x, y, 0), Vector3(0.035, 0.035, 0.4), main)
			for z in [-0.2, 0.2]: _ring(a, body, 4, 0.18, 0.045, 0.045, main, PI / 4, z)
			a._crystal(lit, Vector3.ZERO, 0.06, 0.23, accent)
		"ninthsun":
			a._crystal(lit, Vector3.ZERO, 0.04, 0.62, accent)
			_ring(a, body, 9, 0.23, 0.045, 0.05, main)
		"kaleidoscope":
			for i in 3:
				var angle := TAU * i / 3.0
				a._crystal(lit, Vector3(cos(angle) * 0.16, sin(angle) * 0.16, i * 0.08), 0.08, 0.42, main if i % 2 else accent)
		"counterhymn":
			for x in [-0.15, 0.05]:
				a._box(body, Vector3(x, 0.02, 0), Vector3(0.035, 0.035, 0.45), main)
				a._crystal(lit, Vector3(x - 0.04, 0, 0.22), 0.07, 0.08, accent)
			a._box(lit, Vector3(-0.05, 0, -0.2), Vector3(0.25, 0.035, 0.035), accent)
		"worldneedle":
			a._crystal(lit, Vector3(0, 0, -0.15), 0.025, 1.05, accent)
			_ring(a, body, 6, 0.085, 0.025, 0.04, main, 0, 0.38)

static func _ring(a, tool: SurfaceTool, count: int, radius: float, width: float, length: float, color: Color, phase := 0.0, z := 0.0) -> void:
	for i in count:
		var angle := TAU * i / count + phase
		a._box(tool, Vector3(cos(angle) * radius, sin(angle) * radius, z), Vector3(width, width, length), color)

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
