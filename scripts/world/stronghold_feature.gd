class_name StrongholdFeature
extends RealmFeature
## Roofless fortress ruins. All terrain and masonry are anchored to base_height.
## radius/bounds include the fourteen-block landscaped apron, not just masonry.
const WALL_INNER := 32
const WALL_OUTER := 35
const FLAT_EDGE := 38
const BLEND_WIDTH := 14
const FOOTPRINT := FLAT_EDGE + BLEND_WIDTH
const ARENA_HALF := 26

var biome_id := Biomes.BLUELAY
var floor_block := Blocks.RUNE_BLUE
var trim_block := Blocks.BLUE_ROCK
var accent_block := Blocks.BLUE_GLOW
var gate_open := true
## Quarter turns of the layout; local north faces the road/town.
var turn := 0

static func plan(at: Vector2i, biome: int, height: int, seed_value: int, toward := Vector2.ZERO) -> StrongholdFeature:
	var f := StrongholdFeature.new()
	var facing := toward - Vector2(at)
	if facing != Vector2.ZERO:
		if absf(facing.x) > absf(facing.y):
			f.turn = 1 if facing.x > 0.0 else 3
		else:
			f.turn = 0 if facing.y < 0.0 else 2
	f.type = "stronghold"
	f.required = true
	f.center = at
	f.biome_id = biome
	f.base_height = height
	f._seed = seed_value
	f.radius = FOOTPRINT
	f.bounds = Rect2i(at - Vector2i.ONE * FOOTPRINT, Vector2i.ONE * (FOOTPRINT * 2 + 1))
	var lair := "blue_dragon_lair"
	var guards := "blue_dragon_guards"
	match biome:
		Biomes.BLUELAY:
			f.display_name = "The Azure Crucible"
		Biomes.FOSEN:
			f.display_name = "Crown of the Rime"
			lair = "rimeheart_lair"
			guards = "rimeheart_guards"
			f.floor_block = Blocks.RUNE_FROST
			f.trim_block = Blocks.FOSEN_ROCK
			f.accent_block = Blocks.ICE
		Biomes.DESERT:
			f.display_name = "Court of the Sun"
			lair = "scarab_lair"
			guards = "scarab_guards"
			f.floor_block = Blocks.RUNE_SAND
			f.trim_block = Blocks.SANDSTONE
			f.accent_block = Blocks.BRASS
		Biomes.DEEP_DARK:
			f.display_name = "The Hollow Throne"
			lair = "hollow_crown_lair"
			guards = "hollow_crown_guards"
			f.floor_block = Blocks.RUNE_DARK
			f.trim_block = Blocks.DEEP_SLATE
			f.accent_block = Blocks.RUNE_DARK
		Biomes.DOOM:
			f.display_name = "The Cinder Bastion"
			lair = "vharok_lair"
			guards = "vharok_guards"
			f.floor_block = Blocks.RUNE_FIRE
			f.trim_block = Blocks.OBSIDIAN
			f.accent_block = Blocks.EMBER
	# Guard activation stays entirely inside the walls: 30 radius + 0 offset < 32.
	# Guaranteed entries become separate sites, with independent wake distances.
	f.packs = [{pack = lair, chance = 1.0, offset = 0.0},
		{pack = guards, chance = 1.0, offset = 0.0}]
	return f

func shape(x: int, z: int, col: Array) -> bool:
	if not bounds.has_point(Vector2i(x, z)):
		return false
	var local := to_local(Vector2i(x, z) - center)
	var lx := local.x
	var lz := local.y
	var ax := absi(lx)
	var az := absi(lz)
	var r := maxi(ax, az)
	if r > FLAT_EDGE:
		# Zero derivative at both ends: cuts into mountains and fills low ground
		# with solid terrain rather than putting walls on floating segments.
		var t := float(r - FLAT_EDGE) / BLEND_WIDTH
		var smooth := t * t * (3.0 - 2.0 * t)
		col[0] = roundi(lerpf(base_height, col[0], smooth))
		return true
	# Remove older feature segments when cutting the fortress plot flat.
	col.resize(3)
	col[0] = base_height
	col[1] = _paving(lx, lz)
	col[2] = trim_block
	# The entire central 53x53 is level and clear, including the boss's home.
	if r <= ARENA_HALF:
		return true
	# Main gate is eleven blocks wide; rear postern is five blocks wide.
	var main_gate := lz <= -WALL_INNER and ax <= 5
	var back_gate := lz >= WALL_INNER and ax <= 2
	if main_gate or back_gate:
		var opening := 5 if main_gate else 2
		var lintel := 7 if main_gate else 5
		if az <= WALL_OUTER:
			if not gate_open:
				col.append_array([base_height + 1, base_height + lintel, trim_block])
			col.append_array([base_height + lintel, base_height + lintel + 1, accent_block])
		# Stepped arch shoulders leave generous headroom even for the boss.
		if ax == opening and az <= WALL_OUTER:
			col.append_array([base_height + lintel - 1, base_height + lintel, trim_block])
		return true
	if az >= WALL_INNER and az <= WALL_OUTER and (ax in [6, 7] and lz < 0 or ax in [3, 4] and lz > 0):
		col.append_array([base_height + 1, base_height + (9 if lz < 0 else 7), trim_block])
		return true
	# Hollow, roofless corner towers, eight blocks across, with shattered crowns.
	var tx := absi(ax - 34)
	var tz := absi(az - 34)
	if tx <= 4 and tz <= 4:
		if maxi(tx, tz) >= 3:
			var top := 8 + int(_hash(lx / 2, lz / 2, 71) * 4.0)
			col.append_array([base_height + 1, base_height + top, trim_block,
				base_height + top, base_height + top + 1, accent_block])
		return true
	# Four-block-thick curtain walls. Damage is shared across their thickness,
	# producing actual breaches instead of isolated pinholes in the masonry.
	if r >= WALL_INNER and r <= WALL_OUTER:
		var along := lx if az >= ax else lz
		var side := 1 if az >= ax else 2
		var damage := _hash(floori(float(along) / 5.0), side, 73)
		if damage >= 0.17:
			var wall_height := 3 + int(damage * 4.0)
			if r == WALL_OUTER and posmod(along, 4) == 0:
				wall_height += 1
			col.append_array([base_height + 1, base_height + 1 + wall_height, trim_block])
		else:
			# A breach, choked with rubble two blocks high: it looks broken but
			# can't be stepped over, so the sealed gates are the only way in.
			col.append_array([base_height + 1, base_height + 3, trim_block])
		return true
	# Biome silhouettes along the courtyard perimeter, outside the battle square.
	if ax > 9 and r >= 28 and r <= 30:
		var along := mini(ax, az)
		var ruin := false
		var top := 3
		match biome_id:
			Biomes.DOOM: # Squat furnace buttresses, crowned with embers.
				ruin = along % 12 <= 2 and r <= 29
				top = 3 if r == 29 else 2
			Biomes.FOSEN: # Uneven needles of ice on the rock foundations.
				ruin = ax % 10 == 0 and az % 10 == 0
				top = 4 + int(_hash(lx, lz, 74) * 3.0)
			Biomes.DESERT: # Remnants of a brass-capped processional colonnade.
				ruin = along % 8 <= 1 and r >= 29
				top = 4
			Biomes.DEEP_DARK: # Paired, narrow monoliths.
				ruin = along % 12 in [0, 3] and r == 29
				top = 5
			_: # Broken azure crystal pedestals.
				ruin = ax % 10 <= 1 and az % 10 <= 1
				top = 2 + int(_hash(lx, lz, 74) * 3.0)
		if ruin:
			col.append_array([base_height + 1, base_height + top, trim_block,
				base_height + top, base_height + top + 1, accent_block])
	return true


func _paving(x: int, z: int) -> int:
	var ax := absi(x)
	var az := absi(z)
	var r := maxi(ax, az)
	var mark := false
	match biome_id:
		Biomes.DOOM: # Ember spokes in a dark basalt parade ground.
			mark = (ax == az or ax <= 1 or az <= 1) and r <= 24
		Biomes.FOSEN: # Frost cross and concentric glacial squares.
			mark = ax <= 1 or az <= 1 or r in [12, 24]
		Biomes.DESERT: # A sun disc with eight rays and a processional avenue.
			var d := Vector2(x, z).length()
			mark = absf(d - 18.0) < 0.7 or ((ax == az or ax <= 1 or az <= 1) and d < 22.0)
		Biomes.DEEP_DARK: # Nested void diamonds.
			mark = ax + az in [12, 24, 36] or (ax <= 1 and az < 24)
		_: # Azure woven grid and central dragon sigil.
			mark = (ax % 12 == 0 or az % 12 == 0) or (ax == az and r < 18)
	if r == 26 or (az > 26 and ax <= 5):
		return floor_block
	return floor_block if mark else trim_block


## World offset -> layout offset (gate at local -Z), centered on the boss.
func to_local(offset: Vector2i) -> Vector2i:
	var o := offset
	for i in turn:
		o = Vector2i(o.y, -o.x)
	return o


func to_world(offset: Vector2i) -> Vector2i:
	var o := offset
	for i in turn:
		o = Vector2i(-o.y, o.x)
	return o


func gate_point(distance: float) -> Vector2:
	return Vector2(center) + Vector2(to_world(Vector2i(0, -int(distance))))
