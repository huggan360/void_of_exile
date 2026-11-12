class_name SurfaceFlora
## What grows on the Surface, built per chunk by IslandWorld:
##  - trees (IslandGenerator.tree_sites): instanced voxel meshes, a coarse
##    copy beyond TREE_NEAR, and trunk colliders (also on the server);
##  - ground cover (clients only): voxel grass tufts, tall grass, flowers,
##    clover, ferns, wheat and crops in the fields, reeds and lilies by the
##    water, bushes, logs, stumps, mushrooms and small stones, chosen from
##    the ground material, forest density and biome. One MultiMesh per kind
##    and chunk, swaying in the wind and leaning away from the player
##    (surface_flora.gdshader).

const TREE_NEAR := 75.0
const TREE_FAR := 210.0
const GRASS_FAR := 46.0
const BUSH_FAR := 95.0
const STEP := 0.6  # meters between ground-cover samples

static var _kinds := {}  # kind -> {mesh, height (mesh units), sway, far, unit, offset}
static var _material: ShaderMaterial
static var _fields := {}  # Vector2i (16 m cell) -> Array of fields (baked), per map
static var _fields_ready := false


static func material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = preload("res://shaders/surface_flora.gdshader")
	return _material


## Who the grass leans away from (world positions, w = radius).
static func set_pushers(points: PackedVector4Array) -> void:
	material().set_shader_parameter("pushers", points)


# --- Trees ----------------------------------------------------------------------------

## Trees of one area: trunk colliders on `root` (server and client) and, on
## clients, near and far meshes.
static func build_trees(world: IslandWorld, root: Node3D, area: Rect2i, drawn: bool) -> void:
	var sites := world.generator.tree_sites(area, world._keep_clear, IslandWorld.KEEP_CLEAR_RADIUS)
	if sites.is_empty(): return
	var body := StaticBody3D.new()
	body.name = "Trunks"
	body.collision_layer = Player.OBSTACLE_LAYER
	body.collision_mask = 0
	var groups := {}
	for site: Dictionary in sites:
		var prefab := ObstacleLibrary.get_prefab(site.prefab)
		var s: float = site.scale
		var thin: bool = str(site.prefab).ends_with("birch") or str(site.prefab).ends_with("pine_tall") or str(site.prefab).ends_with("saguaro") or str(site.prefab).ends_with("ash_spire")
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = (0.28 if thin else 0.5) * s
		cylinder.height = 2.6
		shape.shape = cylinder
		shape.position = site.pos + Vector3.UP * 1.3
		body.add_child(shape)
		if drawn:
			var key := "%s|%d" % [site.prefab, site.biome]
			if not groups.has(key): groups[key] = []
			groups[key].append(Transform3D(Basis(Vector3.UP, site.yaw).scaled(Vector3.ONE * s), site.pos))
	root.add_child(body)
	for key: String in groups:
		var parts := key.split("|")
		var prefab := ObstacleLibrary.get_prefab(parts[0])
		var biome := Biomes.get_biome(int(parts[1]))
		var meshes := prefab.meshes_for(biome)
		var local := Transform3D(Basis.from_scale(Vector3.ONE * prefab.voxel_size), prefab.mesh_offset())
		for i in 2:
			if meshes[i] == null: continue
			root.add_child(_multi(meshes[i], groups[key], local, VoxModel.glow_material() if i == 1 else VoxModel.material(),
				0.0, TREE_NEAR, i == 0))
		var far_local := Transform3D(Basis.from_scale(Vector3.ONE * prefab.voxel_size * 2.0), prefab.mesh_offset())
		var far := _multi(prefab.lod_mesh_for(biome), groups[key], far_local, VoxModel.material(), TREE_NEAR - 6.0, TREE_FAR, true)
		far.visibility_range_begin_margin = 6.0
		far.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		root.add_child(far)


static func _multi(mesh: Mesh, transforms: Array, local: Transform3D, mat: Material, begin: float, end: float, shadow: bool) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for j in transforms.size():
		mm.set_instance_transform(j, transforms[j] * local)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_begin = begin
	mmi.visibility_range_end = end
	mmi.visibility_range_end_margin = 8.0
	mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	return mmi


# --- Ground cover -----------------------------------------------------------------------

## Adds this area's plants to `groups` ({kind: [Transform3D, Color]...}).
static func gather(world: IslandWorld, area: Rect2i, groups: Dictionary) -> void:
	var gen := world.generator
	var map := gen.map
	_index_fields(map)
	var steps := int(area.size.x / STEP)
	var x0 := float(area.position.x)
	var z0 := float(area.position.y)
	for j in steps:
		for i in steps:
			var hx := SurfaceMap.hash01(area.position.x * 7 + i, area.position.y * 7 + j, 81)
			var hz := SurfaceMap.hash01(area.position.x * 7 + i, area.position.y * 7 + j, 82)
			var h := SurfaceMap.hash01(area.position.x * 7 + i, area.position.y * 7 + j, 83)
			var h2 := SurfaceMap.hash01(area.position.x * 7 + i, area.position.y * 7 + j, 84)
			var x := x0 + (i + hx) * STEP
			var z := z0 + (j + hz) * STEP
			var mx := floori(x)
			var mz := floori(z)
			var flags := map.cell_flags(mx, mz)
			if flags & SurfaceMap.BRIDGE:
				continue
			var water := map.cell_water(mx, mz)
			if water > 0:
				if flags & SurfaceMap.LAKE and h < 0.012 and _deep(map, mx, mz, water):
					_put(groups, "vox:surface/fine_lilies", Vector3(x, water / 4.0 - 0.02, z), h2 * TAU, 0.9 + h * 8.0, Color.WHITE)
				elif _bank(map, mx, mz) and h < 0.3:
					_put(groups, "vox:surface/fine_reeds", Vector3(x, map.ground_y(x, z), z), h2 * TAU, 0.8 + h, Color.WHITE)
				continue
			if flags & (SurfaceMap.ROAD | SurfaceMap.BRIDGE):
				continue
			var mat := map.cell_ground(mx, mz)
			var y := map.ground_y(x, z)
			if y < IslandGenerator.SEA_LEVEL + 0.5: continue
			var forest := map.cell_flora(mx, mz)
			var tone := Color(0.9 + h2 * 0.2, 0.9 + hx * 0.2, 0.9 + hz * 0.15)
			var pos := Vector3(x, y, z)
			var yaw := h2 * TAU
			if flags & SurfaceMap.TRAIL:
				if mat != SurfaceMap.Mat.STAIRS and h < 0.08 and _trail_edge(map, mx, mz): _put(groups, "tuft", pos, yaw, 0.8, tone)
				continue
			match mat:
				SurfaceMap.Mat.GRASS, SurfaceMap.Mat.YARD:
					if mat == SurfaceMap.Mat.YARD and h > 0.35: continue
					if h > 0.8: continue
					if forest > 0.45 and h < 0.12: _put(groups, "fern", pos, yaw, 0.8 + h2 * 0.5, tone)
					elif h < 0.05: _put(groups, _flower(h2), pos, yaw, 0.9 + hx * 0.3, Color.WHITE)
					elif h < 0.13: _put(groups, "clover", pos, yaw, 1.0, tone)
					elif h < 0.25: _put(groups, "tall_grass", pos, yaw, 0.8 + hx * 0.5, tone)
					else: _put(groups, "tuft_%d" % (int(h2 * 3.0) % 3), pos, yaw, 0.85 + hx * 0.4, tone)
					if forest > 0.5 and h2 < 0.008: _put(groups, "vox:surface/fine_mushrooms", pos, yaw, 1.0, Color.WHITE)
				SurfaceMap.Mat.MEADOW:
					if h > 0.92: continue
					if h < 0.3: _put(groups, _flower(h2), pos, yaw, 0.9 + hx * 0.4, Color.WHITE)
					elif h < 0.55: _put(groups, "tall_grass", pos, yaw, 0.9 + hx * 0.5, tone)
					else: _put(groups, "tuft_%d" % (int(h2 * 3.0) % 3), pos, yaw, 0.9 + hx * 0.4, tone)
				SurfaceMap.Mat.FOREST:
					if h > 0.6: continue
					if h < 0.22: _put(groups, "fern", pos, yaw, 0.8 + h2 * 0.6, tone)
					elif h < 0.25: _put(groups, "vox:surface/fine_mushrooms", pos, yaw, 1.0, Color.WHITE)
					elif h < 0.27: _put(groups, "vox:surface/fine_stone_a", pos, yaw, 0.8 + h2, Color.WHITE)
					elif h < 0.45: _put(groups, "tuft_%d" % (int(h2 * 3.0) % 3), pos, yaw, 0.8 + hx * 0.4, tone.darkened(0.15))
					else: _put(groups, "tall_grass", pos, yaw, 0.8 + hx * 0.4, tone.darkened(0.1))
				SurfaceMap.Mat.JUNGLE_GRASS:
					if h > 0.85: continue
					if h < 0.2: _put(groups, "fern", pos, yaw, 1.1 + h2 * 0.7, Color(0.8, 1.0, 0.8))
					elif h < 0.25: _put(groups, "flower_pink", pos, yaw, 1.1, Color.WHITE)
					else: _put(groups, "tall_grass", pos, yaw, 1.0 + hx * 0.6, Color(0.75, 1.0, 0.75))
				SurfaceMap.Mat.TUNDRA:
					if h < 0.4: _put(groups, "tuft_%d" % (int(h2 * 3.0) % 3), pos, yaw, 0.7 + hx * 0.4, Color(0.78, 0.86, 0.85))
					elif h < 0.43: _put(groups, "flower_white", pos, yaw, 0.9, Color.WHITE)
					elif h < 0.45: _put(groups, "vox:surface/fine_stone_c", pos, yaw, 1.0 + h2, Color.WHITE)
				SurfaceMap.Mat.SNOW, SurfaceMap.Mat.ROCK, SurfaceMap.Mat.MOSS_ROCK:
					if h < 0.03: _put(groups, "vox:surface/fine_stone_b", pos, yaw, 0.8 + h2, Color.WHITE)
					elif mat == SurfaceMap.Mat.MOSS_ROCK and h < 0.25: _put(groups, "tuft_1", pos, yaw, 0.8, tone)
				SurfaceMap.Mat.BLUE_MOSS:
					if h < 0.22: _put(groups, "vox:decor_glow_sprouts", pos, yaw, 1.0 + h2, Color.WHITE)
					elif h < 0.25: _put(groups, "vox:surface/fine_mushrooms_blue", pos, yaw, 1.0, Color.WHITE)
					elif h < 0.5: _put(groups, "tuft_2", pos, yaw, 0.8, Color(0.45, 0.65, 1.0))
				SurfaceMap.Mat.DESERT_SAND, SurfaceMap.Mat.DEEP_SAND, SurfaceMap.Mat.CRACKED, SurfaceMap.Mat.SAND:
					if h < 0.035: _put(groups, "dry_grass", pos, yaw, 0.8 + hx * 0.5, Color.WHITE)
					elif h < 0.045: _put(groups, "vox:surface/fine_stone_sand", pos, yaw, 0.8 + h2, Color.WHITE)
				SurfaceMap.Mat.ASH, SurfaceMap.Mat.BASALT, SurfaceMap.Mat.BLACK_SAND, SurfaceMap.Mat.OBSIDIAN:
					if h < 0.05: _put(groups, "vox:decor_embers", pos, yaw, 1.0, Color.WHITE)
					elif h < 0.07: _put(groups, "vox:surface/fine_stone_dark", pos, yaw, 0.8 + h2, Color.WHITE)
				SurfaceMap.Mat.DEEP_STONE:
					if h < 0.04: _put(groups, "vox:surface/fine_stone_dark", pos, yaw, 0.8 + h2, Color.WHITE)
				SurfaceMap.Mat.FARM:
					var crop := _crop(mx, mz)
					match crop:
						"wheat": _put(groups, "wheat_%d" % (int(h2 * 3.0) % 3), Vector3(x, map.ground_y(x, z), z), floorf(h * 4.0) * PI * 0.5, 0.9 + hx * 0.25, Color.WHITE)
						"greens":
							if h < 0.55: _put(groups, "greens", pos, yaw, 0.9 + hx * 0.3, tone)
						"pumpkins":
							if h < 0.16: _put(groups, "pumpkin", pos, yaw, 0.8 + hx * 0.5, Color.WHITE)
							elif h < 0.5: _put(groups, "greens", pos, yaw, 0.6, tone)
						"lavender":
							if h < 0.7: _put(groups, "lavender", pos, yaw, 0.85 + hx * 0.3, Color.WHITE)
				_:
					pass
	# Bushes, logs and stumps on a coarser grid.
	for j in range(0, area.size.y, 2):
		for i in range(0, area.size.x, 2):
			var cx := area.position.x + i
			var cz := area.position.y + j
			var h := SurfaceMap.hash01(cx, cz, 91)
			var x := cx + 0.3 + SurfaceMap.hash01(cx, cz, 92) * 1.4
			var z := cz + 0.3 + SurfaceMap.hash01(cx, cz, 93) * 1.4
			var mx := floori(x)
			var mz := floori(z)
			if map.cell_flags(mx, mz) & IslandGenerator.KEEP_OPEN or map.cell_water(mx, mz) > 0:
				continue
			var b := map.cell_biome(mx, mz)
			var forest := map.cell_flora(mx, mz)
			var chance := 0.03 + forest * 0.11
			if b in [Biomes.DESERT, Biomes.DEEP_DESERT, Biomes.DOOM, Biomes.DEEP_DARK]: chance *= 0.35
			if h >= chance: continue
			var y := map.ground_y(x, z)
			if y < IslandGenerator.SEA_LEVEL + 0.5: continue
			var pick := SurfaceMap.hash01(cx, cz, 94)
			var kind := "vox:surface/bush_green"
			match b:
				Biomes.FOSEN: kind = "vox:surface/bush_snow" if pick < 0.7 else "vox:surface/rock_snow"
				Biomes.JUNGLE: kind = "vox:surface/bush_jungle"
				Biomes.DESERT, Biomes.DEEP_DESERT, Biomes.BEACH: kind = "vox:surface/bush_dry"
				Biomes.BLUELAY: kind = "vox:surface/bush_blue" if pick < 0.7 else "vox:surface/crystal_blue"
				Biomes.DOOM: kind = "vox:surface/rock_lava"
				Biomes.DEEP_DARK: kind = "vox:surface/rock_dark"
				_:
					if forest > 0.5 and pick < 0.12: kind = "vox:surface/log"
					elif forest > 0.5 and pick < 0.2: kind = "vox:surface/stump"
					elif pick < 0.45: kind = "vox:surface/bush_green"
					elif pick < 0.7: kind = "vox:surface/bush_berry"
					else: kind = "vox:surface/bush_flower"
			_put(groups, kind, Vector3(x, y - 0.05, z), SurfaceMap.hash01(cx, cz, 95) * TAU, 0.75 + SurfaceMap.hash01(cx, cz, 96) * 0.5, Color.WHITE)


static func _flower(h: float) -> String:
	return ["flower_yellow", "flower_white", "flower_pink", "flower_blue", "flower_red", "flower_purple"][int(h * 6.0) % 6]


static func _put(groups: Dictionary, kind: String, pos: Vector3, yaw: float, size: float, tint: Color) -> void:
	if not groups.has(kind): groups[kind] = []
	groups[kind].append([pos, yaw, size, tint])


static func _deep(map: SurfaceMap, mx: int, mz: int, water: int) -> bool:
	return water - map.cell_height(mx, mz) > 3


static func _bank(map: SurfaceMap, mx: int, mz: int) -> bool:
	for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if map.cell_water(mx + o.x, mz + o.y) == 0: return true
	return false


static func _trail_edge(map: SurfaceMap, mx: int, mz: int) -> bool:
	for o: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if map.cell_flags(mx + o.x, mz + o.y) & SurfaceMap.TRAIL == 0: return true
	return false


static func _index_fields(map: SurfaceMap) -> void:
	if _fields_ready: return
	_fields_ready = true
	for f: Dictionary in map.data.get("fields", []):
		var c := Vector2(f.center[0], f.center[1])
		var reach := Vector2(f.half[0], f.half[1]).length()
		for cz in range(floori((c.y - reach) / 16.0), floori((c.y + reach) / 16.0) + 1):
			for cx in range(floori((c.x - reach) / 16.0), floori((c.x + reach) / 16.0) + 1):
				var key := Vector2i(cx, cz)
				if not _fields.has(key): _fields[key] = []
				_fields[key].append(f)


static func _crop(mx: int, mz: int) -> String:
	for f: Dictionary in _fields.get(Vector2i(floori(mx / 16.0), floori(mz / 16.0)), []):
		var d := Vector2(mx + 0.5 - float(f.center[0]), mz + 0.5 - float(f.center[1]))
		var yaw := float(f.yaw)
		var lx := d.x * cos(yaw) - d.y * sin(yaw)
		var lz := d.x * sin(yaw) + d.y * cos(yaw)
		if absf(lx) <= float(f.half[0]) + 0.5 and absf(lz) <= float(f.half[1]) + 0.5:
			return str(f.crop)
	return "wheat"


## Turns gathered plants into one MultiMesh per kind under `root`.
static func build(root: Node3D, groups: Dictionary) -> void:
	for kind: String in groups:
		build_kind(root, kind, groups[kind])


## One kind's MultiMesh.
static func build_kind(root: Node3D, kind: String, list: Array) -> void:
	if not is_instance_valid(root): return
	var spec := _kind(kind)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = spec.mesh
	mm.instance_count = list.size()
	var unit: float = spec.unit
	var offset: Vector3 = spec.offset
	for k in list.size():
		var e: Array = list[k]
		var basis := Basis(Vector3.UP, e[1]).scaled(Vector3.ONE * float(e[2]) * unit)
		mm.set_instance_transform(k, Transform3D(basis, e[0] + basis * offset))
		mm.set_instance_custom_data(k, e[3])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if spec.shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = spec.far
	mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mmi.set_instance_shader_parameter("sway", spec.sway)
	mmi.set_instance_shader_parameter("height", spec.height)
	mmi.set_instance_shader_parameter("fade_end", spec.far)
	mmi.set_instance_shader_parameter("glow", spec.glow)
	root.add_child(mmi)


# --- Plant meshes -----------------------------------------------------------------------

static func _kind(kind: String) -> Dictionary:
	if _kinds.has(kind): return _kinds[kind]
	var spec := {unit = 1.0, offset = Vector3.ZERO, sway = 0.5, far = GRASS_FAR, shadow = false, glow = 0.0}
	if kind.begins_with("vox:"):
		var prefab := ObstacleLibrary.get_prefab(kind.trim_prefix("vox:"))
		var meshes := prefab.meshes_for(Biomes.get_biome(Biomes.BLUELAY if prefab.has_glow else Biomes.WOODS))
		spec.mesh = meshes[1] if meshes[0] == null else meshes[0]
		if meshes[0] == null: spec.glow = 2.5
		spec.unit = prefab.voxel_size
		spec.offset = prefab.mesh_offset() / prefab.voxel_size
		spec.height = float(prefab.size.y)
		var name := kind.get_file()
		var rigid := name.begins_with("rock") or name.begins_with("fine_stone") or name in ["log", "stump", "crystal_blue", "fine_lilies"]
		spec.sway = 0.0 if rigid else 0.12 if name.begins_with("bush") else 0.35
		spec.far = BUSH_FAR if not name.begins_with("fine") and not name.begins_with("decor") else GRASS_FAR + 10.0
		spec.shadow = name.begins_with("bush") or name in ["log", "stump"] or name.begins_with("rock")
		if name in ["decor_glow_sprouts", "decor_embers", "fine_mushrooms_blue"]: spec.glow = 2.0
	else:
		var built := _plant(kind)
		spec.mesh = built[0]
		spec.height = built[1]
		spec.sway = built[2]
	_kinds[kind] = spec
	return spec


## [mesh in meters (base at the origin), height, sway] for the generated plants.
static func _plant(kind: String) -> Array:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var v := 0.0625  # a blade voxel
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var height := 0.4
	var sway := 0.6
	if kind.begins_with("tuft_") or kind == "tall_grass" or kind == "dry_grass" or kind == "clover":
		var blades: int = {"tuft_0": 6, "tuft_1": 7, "tuft_2": 5, "tall_grass": 9, "dry_grass": 6, "clover": 0}[kind]
		var tall := 0.62 if kind == "tall_grass" else 0.3
		var base := Color("4c7f32")
		var tip := Color("9cc85a")
		if kind == "dry_grass":
			base = Color("9a8a50")
			tip = Color("d8c47a")
		elif kind == "tuft_1":
			base = Color("467a2e")
			tip = Color("86b84e")
		elif kind == "tuft_2":
			base = Color("55883a")
			tip = Color("b2d468")
		for b in blades:
			var at := Vector2(rng.randf_range(-0.14, 0.14), rng.randf_range(-0.14, 0.14))
			var h := tall * rng.randf_range(0.55, 1.0)
			var segments := maxi(2, roundi(h / (v * 1.5)))
			var lean := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * rng.randf_range(0.02, 0.09)
			for s in segments:
				var t0 := float(s) / segments
				var t1 := float(s + 1) / segments
				var c := base.lerp(tip, t1)
				var off := lean * t0 * t0
				var w := v * (1.0 - t0 * 0.45)
				_box(st, Vector3(at.x + off.x - w * 0.5, h * t0, at.y + off.y - w * 0.5), Vector3(at.x + off.x + w * 0.5, h * t1, at.y + off.y + w * 0.5), c)
		if kind == "clover":
			# Each leaf a hair higher than the last: overlapping leaves never
			# share a plane (they flickered against each other).
			for k in 7:
				var at := Vector2(rng.randf_range(-0.16, 0.16), rng.randf_range(-0.16, 0.16))
				var top := v * 1.2 + k * 0.006
				_box(st, Vector3(at.x - v, 0, at.y - v), Vector3(at.x + v, top, at.y + v), Color("5f9a3a") if k % 3 else Color("6eaa44"))
			_box(st, Vector3(-v * 0.5, v * 1.2 + 0.05, -v * 0.5), Vector3(v * 0.5, v * 2.2 + 0.05, v * 0.5), Color("f4f0f6"))
		height = tall
		sway = 0.9 if kind == "tall_grass" else 0.6
	elif kind.begins_with("flower_"):
		var petal: Color = {"flower_yellow": Color("f4d24a"), "flower_white": Color("f6f2ea"), "flower_pink": Color("ee8ab4"),
			"flower_blue": Color("6a94ee"), "flower_red": Color("d8443c"), "flower_purple": Color("a46ad8")}[kind]
		for k in 3:
			var at := Vector2(rng.randf_range(-0.12, 0.12), rng.randf_range(-0.12, 0.12))
			var h := rng.randf_range(0.22, 0.4)
			_box(st, Vector3(at.x - v * 0.4, 0, at.y - v * 0.4), Vector3(at.x + v * 0.4, h, at.y + v * 0.4), Color("4f8a34"))
			_box(st, Vector3(at.x - v * 1.5, h, at.y - v * 0.5), Vector3(at.x + v * 1.5, h + v, at.y + v * 0.5), petal)
			_box(st, Vector3(at.x - v * 0.5, h, at.y - v * 1.5), Vector3(at.x + v * 0.5, h + v, at.y + v * 1.5), petal)
			_box(st, Vector3(at.x - v * 0.5, h + v, at.y - v * 0.5), Vector3(at.x + v * 0.5, h + v * 1.6, at.y + v * 0.5), Color("f8d040"))
			_box(st, Vector3(at.x - v * 1.5, h * 0.4, at.y - v * 0.4), Vector3(at.x, h * 0.4 + v * 0.6, at.y + v * 0.4), Color("5a9a3c"))
		height = 0.45
		sway = 0.7
	elif kind == "fern":
		for k in 7:
			var a := k * TAU / 7.0 + rng.randf_range(-0.2, 0.2)
			var length := rng.randf_range(0.3, 0.5)
			var steps := 6
			for s in steps:
				var t := float(s) / steps
				var p := Vector2.from_angle(a) * length * t
				var y := sin(t * PI * 0.8) * 0.35
				var w := v * (1.6 - t)
				_box(st, Vector3(p.x - w, y, p.y - w), Vector3(p.x + w, y + v, p.y + w), Color("3e7a30").lerp(Color("6aa84a"), t))
		height = 0.4
		sway = 0.45
	elif kind.begins_with("wheat_"):
		var variant := int(kind.trim_prefix("wheat_"))
		var stalk: Color = [Color("a8853a"), Color("b8923f"), Color("9c7a34")][variant]
		var ear: Color = [Color("f0cf6a"), Color("e6bc52"), Color("f5d97c")][variant]
		for k in 5:
			var at := Vector2(rng.randf_range(-0.22, 0.22), rng.randf_range(-0.22, 0.22))
			var tall := rng.randf_range(0.7, 0.95)
			_box(st, Vector3(at.x - v * 0.5, 0, at.y - v * 0.5), Vector3(at.x + v * 0.5, tall, at.y + v * 0.5), stalk)
			_box(st, Vector3(at.x - v, tall, at.y - v), Vector3(at.x + v, tall + v * 4.0, at.y + v), ear if k % 2 else ear.darkened(0.08))
			_box(st, Vector3(at.x - v * 0.5, tall + v * 4.0, at.y - v * 0.5), Vector3(at.x + v * 0.5, tall + v * 5.5, at.y + v * 0.5), ear.lightened(0.1))
		height = 1.0
		sway = 0.9
	elif kind == "greens":
		for k in 6:
			var a := k * TAU / 6.0
			var p := Vector2.from_angle(a) * 0.08
			_box(st, Vector3(p.x - v * 1.5, 0, p.y - v * 1.5), Vector3(p.x + v * 1.5, v * 3 + k * 0.006, p.y + v * 1.5), Color("5ea844") if k % 2 else Color("72bc54"))
		_box(st, Vector3(-v * 1.5, 0, -v * 1.5), Vector3(v * 1.5, v * 4, v * 1.5), Color("8ad06a"))
		height = 0.25
		sway = 0.2
	elif kind == "pumpkin":
		var orange := Color("e07a28")
		for y in 4:
			var r: int = [3, 4, 4, 3][y]
			for z in range(-r, r + 1):
				for x in range(-r, r + 1):
					if x * x + z * z <= r * r and (absi(x) == r or absi(z) == r or y == 3 or x * x + z * z >= (r - 1) * (r - 1)):
						_box(st, Vector3(x * v, y * v, z * v), Vector3((x + 1) * v, (y + 1) * v, (z + 1) * v), orange if (x + 8) % 3 else orange.darkened(0.12))
		_box(st, Vector3(0, 4 * v, 0), Vector3(v, 6 * v, v), Color("5a7a2a"))
		height = 0.4
		sway = 0.0
	elif kind == "lavender":
		for k in 6:
			var at := Vector2(rng.randf_range(-0.16, 0.16), rng.randf_range(-0.16, 0.16))
			var h := rng.randf_range(0.35, 0.55)
			_box(st, Vector3(at.x - v * 0.4, 0, at.y - v * 0.4), Vector3(at.x + v * 0.4, h, at.y + v * 0.4), Color("6a8a5a"))
			_box(st, Vector3(at.x - v * 0.7, h, at.y - v * 0.7), Vector3(at.x + v * 0.7, h + v * 3, at.y + v * 0.7), Color("9a72d8"))
		height = 0.7
		sway = 0.7
	st.generate_normals()
	return [st.commit(), height, sway]


## An axis box from `lo` to `hi`, one colour (no bottom face).
static func _box(st: SurfaceTool, lo: Vector3, hi: Vector3, color: Color) -> void:
	var c := [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z),
		Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]
	st.set_color(color)
	for quad: Array in [[4, 7, 6, 5], [0, 4, 5, 1], [1, 5, 6, 2], [2, 6, 7, 3], [3, 7, 4, 0]]:
		var a: Vector3 = c[quad[0]]
		var b: Vector3 = c[quad[1]]
		var d: Vector3 = c[quad[2]]
		var e: Vector3 = c[quad[3]]
		for p: Vector3 in [a, b, d, a, d, e]: st.add_vertex(p)
