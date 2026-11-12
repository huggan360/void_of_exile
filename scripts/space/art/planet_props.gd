class_name PlanetProps
extends RefCounted
## Standing the planets' voxel buildings and props on round ground: every
## piece gets its own frame, centred on its own spot with up straight out from
## the planet's centre, lowered to the lowest ground under its footprint and
## sunk by its stone plinth (props/planet/catalog.json, made by
## tools/space/make_planet_models.py), so no side ever floats.

## Per planet: houses, the big building of large villages, market stalls,
## well, lamp, plaza and landing pad (props/planet/<name>, or a realm prop
## folder starting with res://).
const STYLES := {
	verdance = {houses = ["planet/moss_cottage", "planet/moss_cottage_blue", "planet/mushroom_house", "planet/mushroom_house_teal", "res://props/houses/woodland_0", "res://props/houses/woodland_1", "res://props/home/rose_cottage"],
		big = "planet/treehouse", stalls = ["planet/market_stall_green", "planet/market_stall_red"], well = "planet/well", lamp = "planet/lamp_warm", plaza = "planet/plaza_stone", pad = "planet/pad_timber",
		folk = ["npc_villager", "npc_gardener", "npc_baker", "moss_tortoise"]},
	rosamund = {houses = ["planet/petal_cottage", "planet/petal_cottage_lilac", "planet/fairy_tower", "res://props/home/rose_cottage", "res://props/home/magicians_house", "planet/petal_cottage"],
		big = "planet/rose_shrine", stalls = ["planet/market_stall_violet", "planet/market_stall_red"], well = "planet/well", lamp = "planet/lamp_pink", plaza = "planet/plaza_rose", pad = "planet/pad_rose",
		folk = ["npc_magician", "spirit_purple", "npc_villager", "spirit_spark"]},
	amberfall = {houses = ["planet/adobe_house", "planet/adobe_house_rose", "planet/sand_dome", "res://props/houses/desert_0", "res://props/houses/desert_1", "res://props/houses/desert_2"],
		big = "planet/lantern_tower", stalls = ["planet/market_stall_red", "planet/market_stall_blue", "planet/market_stall_green"], well = "planet/well_sand", lamp = "planet/lamp_warm", plaza = "planet/plaza_sand", pad = "planet/pad_sand",
		folk = ["npc_traveler", "sun_priest", "genie_brown", "npc_baker"]},
	tidewell = {houses = ["planet/stilt_hut", "planet/stilt_hut_blue", "planet/fisher_house", "res://props/houses/fosen_0", "res://props/houses/fosen_1", "planet/stilt_hut"],
		big = "planet/lighthouse", stalls = ["planet/market_stall_blue", "planet/market_stall_green"], well = "planet/well", lamp = "planet/lamp_warm", plaza = "planet/plaza_stone", pad = "planet/pad_timber",
		folk = ["npc_villager", "tide_snail", "crab", "npc_traveler"]},
	shardheart = {houses = ["planet/crystal_hut", "planet/crystal_hut_pink"], big = "planet/crystal_hall", stalls = ["planet/market_stall_blue", "planet/market_stall_violet"],
		well = "planet/well_dark", lamp = "planet/lamp_teal", plaza = "planet/plaza_crystal", pad = "planet/pad_crystal",
		folk = ["genie_blue", "spirit_blue", "runic_archivist", "prism_ray"]},
	hollowmoon = {houses = ["planet/ruin_cottage", "planet/crypt", "planet/ruin_cottage"], big = "planet/observatory", stalls = ["planet/market_stall_green"],
		well = "planet/well_dark", lamp = "planet/lamp_green", plaza = "planet/plaza_moon", pad = "planet/pad_stone",
		folk = ["spirit_brown", "glacier_hermit", "spirit_blue", "nightbell_idol"]},
	mawgrave = {houses = ["planet/spore_hut", "planet/hive_house"], big = "planet/hive_spire", stalls = ["planet/market_stall_violet"],
		well = "planet/well_dark", lamp = "planet/lamp_violet", plaza = "planet/plaza_violet", pad = "planet/pad_fungal",
		folk = ["genie_purple", "cave_shaman", "sporeback", "spirit_purple"]},
	pale_eye = {houses = ["planet/obsidian_hut", "planet/obsidian_hall"], big = "planet/storm_tower", stalls = ["planet/market_stall_blue"],
		well = "planet/well_dark", lamp = "planet/lamp_storm", plaza = "planet/plaza_dark", pad = "planet/pad_obsidian",
		folk = ["runic_archivist", "genie_purple", "sun_priest", "spirit_spark"]},
}

## The four story places per planet (SpaceLayout.PLACES order): what stands
## just beyond each search spot. [asset, x, z (m from the landmark's middle),
## size]; "o:<prefab>" is a single voxel obstacle grown to `size`.
const PLACE_ART := {
	verdance = [
		[["planet/treehouse", 0, 0, 1], ["planet/moss_cottage", 15, 7, 1], ["planet/moss_cottage_blue", -15, 6, 1], ["lamp", 7, -9, 1], ["lamp", -7, -9, 1]],
		[["planet/mushroom_house", 0, 0, 1], ["o:planet/glow_cap", 11, 3, 1.3], ["o:planet/glow_cap_blue", -10, 5, 1.2], ["o:planet/glow_cap", 4, 12, 1.0], ["o:planet/glow_cap_blue", -6, -11, 0.9], ["o:planet/glow_cap", 9, -9, 0.8]],
		[["o:planet/fairy_stone", 0, 0, 1.4], ["ring:o:planet/firefly_bush", 9, 6, 1.0], ["lamp", 0, -10, 1]],
		[["o:planet/moss_oak", 0, 0, 2.2], ["o:planet/glow_cap_blue", 9, 6, 1.0], ["o:planet/glow_cap", -8, 7, 0.9], ["o:planet/mossy_boulder", 3, -9, 1.2]]],
	rosamund = [
		[["planet/rose_shrine", 0, 0, 1], ["o:planet/rose_bush", 9, 6, 1], ["o:planet/rose_bush", -9, 6, 1]],
		[["ring:o:planet/rose_crystal", 8, 7, 1.5], ["o:planet/giant_flower", 0, 0, 1.4], ["o:planet/rose_bush", 13, -4, 1], ["o:planet/rose_bush", -13, -4, 1]],
		[["planet/fairy_tower", 0, 0, 1], ["ring:o:planet/fairy_stone", 11, 6, 1.0]],
		[["planet/well", 0, 0, 1], ["ring:o:planet/fairy_stone", 9, 8, 1.1]]],
	amberfall = [
		[["planet/market_stall_red", -6, 4, 1], ["planet/market_stall_blue", 6, 4, 1], ["planet/market_stall_green", 0, -6, 1], ["planet/adobe_house", 15, -6, 1], ["planet/adobe_house_rose", -15, -6, 1]],
		[["planet/lantern_tower", 0, 0, 1], ["o:planet/date_palm", 9, 7, 1.1], ["o:planet/date_palm", -9, 7, 1.0]],
		[["planet/well_sand", 0, 0, 1], ["o:planet/honeycomb_rock", 9, 4, 1.2], ["o:planet/honeycomb_rock", -8, 6, 1.0], ["o:planet/date_palm", 4, -9, 1.1]],
		[["res://props/surface/tent_red", -7, 0, 1], ["res://props/surface/tent_canvas", 7, 1, 1], ["planet/sand_dome", 0, -11, 1], ["o:planet/barrel_cactus", 12, 9, 1.2]]],
	tidewell = [
		[["planet/stilt_hut", -10, 0, 1], ["planet/stilt_hut_blue", 10, 2, 1], ["planet/fisher_house", 0, -12, 1]],
		[["planet/lighthouse", 0, 0, 1], ["o:planet/sea_rock", 10, 6, 1.2], ["o:planet/driftwood", -9, 7, 1.0]],
		[["planet/fisher_house", -7, 0, 1], ["planet/stilt_hut_blue", 9, -3, 1], ["o:planet/driftwood", 3, 10, 1.1], ["o:planet/driftwood", -10, 9, 0.9]],
		[["planet/well", 0, 0, 1], ["ring:o:planet/conch", 9, 5, 1.4]]],
	shardheart = [
		[["ring:o:planet/shard_spire", 9, 6, 1.4], ["o:planet/shard_spire_pink", 0, 0, 1.6]],
		[["planet/crystal_hall", 0, 0, 1], ["o:planet/geode", 10, 6, 1.0]],
		[["ring:o:planet/shard_spire_pink", 8, 8, 0.9], ["lamp", 0, 0, 1]],
		[["planet/crystal_hut", -7, 0, 1], ["planet/crystal_hut_pink", 7, 2, 1], ["o:planet/geode", 0, -10, 1.2]]],
	hollowmoon = [
		[["planet/observatory", 0, 0, 1]],
		[["ring:o:planet/bone_tree", 10, 7, 1.3], ["o:planet/ribcage", 0, 0, 1.0]],
		[["ring:o:planet/ghost_lamp", 9, 8, 1.0], ["o:planet/tombstones", 0, 0, 1.2]],
		[["planet/ruin_cottage", -8, 0, 1], ["planet/crypt", 9, -2, 1], ["o:planet/moon_rock", 0, 10, 1.2]]],
	mawgrave = [
		[["planet/hive_spire", 0, 0, 1], ["planet/hive_house", 13, 5, 1]],
		[["ring:o:planet/spore_pod", 9, 6, 1.3], ["o:planet/fungal_stack", 0, 0, 1.6]],
		[["planet/spore_hut", 0, 0, 1], ["ring:o:planet/tendrils", 12, 5, 1.0]],
		[["ring:o:planet/hive_mound", 10, 4, 1.4], ["planet/hive_house", 0, 0, 1]]],
	pale_eye = [
		[["ring:o:planet/obsidian_spire", 11, 7, 1.6], ["planet/obsidian_hall", 0, 0, 1]],
		[["planet/storm_tower", 0, 0, 1], ["o:planet/storm_crystal", 9, 7, 1.0]],
		[["planet/obsidian_hut", 0, 0, 1], ["ring:o:planet/storm_crystal", 11, 4, 0.9]],
		[["ring:o:planet/storm_rod", 8, 3, 1.4], ["planet/obsidian_hut", 0, -10, 1], ["lamp", 0, 0, 1]]],
}

static var _catalog := {}

static func catalog() -> Dictionary:
	if _catalog.is_empty():
		var text := FileAccess.get_file_as_string("res://props/planet/catalog.json")
		var data: Variant = JSON.parse_string(text) if text!="" else null
		_catalog = data if data is Dictionary else {"_": {}}
	return _catalog

static func style(p: Dictionary) -> Dictionary:
	return STYLES.get(p.id, STYLES.verdance)

## The unit direction `local` metres (right, forward) from `center` across
## planet `p`'s ground (in `center`'s own tangent frame).
static func offset_dir(p: Dictionary, center: Vector3, local: Vector2) -> Vector3:
	if local.length()<0.001: return center
	var right := center.cross(Vector3.FORWARD if absf(center.dot(Vector3.FORWARD))<0.95 else Vector3.RIGHT).normalized()
	var forward := right.cross(center)
	var tangent := (right*local.x+forward*local.y).normalized()
	var angle := local.length()/float(p.radius)
	return (center*cos(angle)+tangent*sin(angle)).normalized()

## A ground frame at `dir` whose -Z (doors, fronts) faces `toward` (a unit
## direction from the centre), or turned by `yaw` when there is none.
static func frame_at(p: Dictionary, dir: Vector3, toward: Vector3, half: float, yaw := 0.0) -> Transform3D:
	var frame := SpaceLayout.ground_frame(p, dir, yaw, half)
	if toward.is_finite() and toward.distance_to(dir)>0.0001:
		var t := toward-dir*toward.dot(dir)
		if t.length()>0.0001: frame.basis = Basis.looking_at(t.normalized(), dir)
	return frame

## A voxel building (VillageHouse) at `dir` facing `toward`, with its solid
## footprint as collision. Returns its holder.
static func building(parent: Node3D, p: Dictionary, asset: String, dir: Vector3, toward: Vector3, yaw := 0.0, size := 1.0) -> Node3D:
	var folder := asset if asset.begins_with("res://") else "res://props/"+asset
	var info: Dictionary = catalog().get(asset, {})
	var foot: Array = info.get("foot", [8.5, 8.5])
	var tall: float = (info.get("size", [0, 8.5, 0]) as Array)[1]
	var sink: float = info.get("sink", 0.1)
	var half := maxf(float(foot[0]), float(foot[1]))*0.5*size
	var frame := frame_at(p, dir, toward, half*0.8, yaw)
	var kind := str(info.get("kind", "house"))
	var floor := kind in ["pad", "plaza", "deck"]
	var holder := Node3D.new()
	# Floors sit a hair above the levelled ground so the two never share a plane.
	holder.transform = Transform3D(frame.basis.scaled_local(Vector3.ONE*size), frame.origin-frame.basis.y*(sink*size-(0.05 if floor else 0.0)))
	parent.add_child(holder)
	var solid := Vector3.ZERO if floor else Vector3(float(foot[0])*0.9, maxf(1.0, tall-sink), float(foot[1])*0.9)
	var house := VillageHouse.new().setup({asset = folder, pos = Vector3.ZERO, yaw = 0.0, solid_size = solid, solid_offset = Vector3(0, sink+solid.y*0.5, 0)})
	holder.add_child(house)
	return holder

## One of the voxel obstacles ("planet/...", "surface/..." or the realm's),
## coloured for planet `p`, standing at `dir` with its collision.
static func obstacle(parent: Node3D, p: Dictionary, name: String, dir: Vector3, yaw: float, size: float) -> Node3D:
	var prefab := ObstacleLibrary.get_prefab(name)
	var frame := SpaceLayout.ground_frame(p, dir, yaw, maxf(prefab.footprint.x, prefab.footprint.y)*0.32*size)
	frame.origin -= frame.basis.y*0.12
	var holder := Node3D.new()
	holder.transform = frame
	parent.add_child(holder)
	var meshes := prefab.meshes_for(PlanetFlora.biome_for(p))
	for slot in 2:
		if meshes[slot]==null: continue
		var mesh := MeshInstance3D.new()
		mesh.mesh = meshes[slot]
		mesh.material_override = VoxModel.glow_material() if slot==1 else VoxModel.material()
		mesh.position = prefab.mesh_offset()*size
		mesh.scale = Vector3.ONE*prefab.voxel_size*size
		mesh.visibility_range_end = 700.0
		holder.add_child(mesh)
	if not prefab.is_fine() and not prefab.collision_boxes.is_empty():
		var body := StaticBody3D.new()
		body.collision_layer = Player.OBSTACLE_LAYER
		body.collision_mask = 0
		holder.add_child(body)
		for box: AABB in prefab.collision_boxes:
			var shape := CollisionShape3D.new()
			var solid := BoxShape3D.new()
			solid.size = box.size*size
			shape.shape = solid
			shape.position = box.get_center()*size
			body.add_child(shape)
	return holder

## A warm light at `dir`, `lift` metres up (lamps, windows of a square).
static func light(parent: Node3D, p: Dictionary, dir: Vector3, lift: float, color: Color, energy := 1.0, reach := 12.0) -> void:
	var omni := OmniLight3D.new()
	omni.light_color = color
	omni.light_energy = energy
	omni.omni_range = reach
	omni.shadow_enabled = false
	omni.distance_fade_enabled = true
	omni.distance_fade_begin = 160.0
	omni.distance_fade_length = 40.0
	omni.position = dir*(float(p.radius)+SpaceLayout.surface_height(p, dir)+lift)
	parent.add_child(omni)

## The colour of the light from a planet's lamps.
static func lamp_color(p: Dictionary) -> Color:
	return {"planet/lamp_green": Color("8cff96"), "planet/lamp_pink": Color("ff96dc"), "planet/lamp_violet": Color("ff6ee6"),
		"planet/lamp_storm": Color("96b4ff"), "planet/lamp_teal": Color("8cffe6")}.get(str(style(p).lamp), Color("ffc46e"))

## The art of story place `index` on `p`, round its landmark middle `center`.
static func place_art(parent: Node3D, p: Dictionary, index: int, center: Vector3, toward: Vector3) -> void:
	var list: Array = PLACE_ART.get(p.id, [])
	if index>=list.size(): return
	var lamp := str(style(p).lamp)
	for entry: Array in list[index]:
		var asset := str(entry[0])
		var local := Vector2(float(entry[1]), float(entry[2]))
		var size := float(entry[3])
		if asset.begins_with("ring:"):
			# A ring of them round the middle: radius x, count z.
			var count := int(local.y)
			for k in count:
				var a := TAU*k/count
				var at := offset_dir(p, center, Vector2.from_angle(a)*local.x)
				_one(parent, p, asset.trim_prefix("ring:"), at, center, size*(0.85+0.3*fposmod(k*0.618, 1.0)), a)
			continue
		if asset=="lamp": asset = lamp
		_one(parent, p, asset, offset_dir(p, center, local), toward if local.length()<1.0 else center, size, 0.0)
	light(parent, p, center, 5.0, lamp_color(p), 1.2, 16.0)

static func _one(parent: Node3D, p: Dictionary, asset: String, dir: Vector3, toward: Vector3, size: float, yaw: float) -> void:
	if asset.begins_with("o:"): obstacle(parent, p, asset.trim_prefix("o:"), dir, yaw, size)
	else: building(parent, p, asset, dir, toward, 0.0, size)
