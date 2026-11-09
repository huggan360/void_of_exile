class_name HallWorld
extends GameWorld
## Fixed, editor-authored home island. Never builds or randomizes its layout.
## Open res://scenes/home/tavern.tscn to move buildings, roads, the coastline
## and resident markers; the voxel ground is baked from that scene on load.
const DECOR_DENSITY := 0.2
const DECOR := {decor_tuft = 6, decor_flowers = 4, decor_fern = 2, decor_mushrooms = 0.6, decor_pebbles = 0.8}
const BEACH_DECOR := {decor_pebbles = 3, decor_dry_grass = 1}
var navigation: TownNavigation
var residents: Array[TownNPC] = []
var home_terrain: HomeTerrain
var _footprints := PackedByteArray()  # per column: 0 open, 1 prop or tree, 2 building
var _map_fountain := Vector2.ZERO
## A party's private copy for its campaign: both gates lead into its realm.
var campaign_tavern := false
## The Chronicle Gate south of the fountain: lit only while your party plays a campaign.
var campaign_portal: Portal
## The chapel market (ShopKeeper): red and white stalls either side of the chapel
## yard, facing it, and two keepers by the chapel door. [shop, x, z].
const MARKET_STALLS := [["priest", -11.5, 74.5], ["wizard", -17.0, 74.5], ["bowyer", 11.5, 74.5], ["alchemist", 17.0, 74.5]]
const MARKET_KEEPERS := [["relic", -5.5, 75.5], ["curio", 5.5, 75.5]]
const MARKET_CENTER := Vector2(0, 70)
var _prepared_decor := {}
var _prepared_load := false

## Detached data only: terrain rasterization, navigation and decoration plans.
func prepare_load() -> void:
	home_terrain = HomeTerrain.from_scene(self)
	_prepare_navigation()
	_prepared_decor = _gather_decor()
	for key: String in _prepared_decor:
		var parts := key.split("/")
		ObstacleLibrary.get_prefab(parts[2]).meshes_for(Biomes.get_biome(int(parts[3])))
	_prepared_load = true

func _init() -> void:
	display_name = "The Tavern"
	realm_id = "hall"
	half_extent = 120

func is_water(pos: Vector3) -> bool:
	return pos.y<=IslandGenerator.SEA_LEVEL+0.7

func _ready() -> void:
	if home_terrain==null: home_terrain = HomeTerrain.from_scene(self)
	var e := HomeTerrain.EXTENT
	# Only the playable plateau and shallow lagoon need terrain.
	_add_terrain(HallGenerator.new(home_terrain), AABB(Vector3(-e, 0, -e), Vector3(e * 2 + 1, 40, e * 2 + 1)), "tavern", [scene_file_path])
	if not has_node("CoastWater"): _add_water(IslandGenerator.SEA_LEVEL + 0.6, 400.0)
	_heaven()
	if has_node("Spawn"): spawn_point = $Spawn.position
	var gate_position: Vector3 = $RealmGate.position if has_node("RealmGate") else Vector3(0, 10, -60)
	var gate_facing: Vector3 = -$RealmGate.basis.z if has_node("RealmGate") else Vector3.BACK
	_add_portal(gate_position, gate_facing, "realm_1", Color(0.45, 0.25, 1.0), Color(0.2, 0.85, 1.0))
	# The Chronicle Gate: into your party's own realm, while it plays a campaign.
	if has_node("CampaignGate"):
		campaign_portal = _add_portal($CampaignGate.position, -$CampaignGate.basis.z, "campaign", Color(1.0, 0.7, 0.2), Color(1.0, 0.35, 0.6))
		campaign_portal.set_active(false)
	# The Chambers Gate: into the account's own vault hall.
	if has_node("ChambersGate"):
		var gate := _add_portal($ChambersGate.position, -$ChambersGate.basis.z, "chambers", Color(0.85, 0.2, 0.25), Color(1.0, 0.75, 0.35))
		# A brass plaque over the gate, on both faces.
		for k in 2:
			var sign := SignBoard.make("Chambers", "brass", "door", Color(0, 0, 0, 0), 0.8)
			sign.position = Vector3(0, 4.6, 0.06 if k==0 else -0.06)
			sign.rotation.y = k*PI
			gate.add_child(sign)
	_build_market()
	if navigation==null: _prepare_navigation()
	if has_node("Residents"):
		var index := 0
		for marker in $Residents.get_children():
			index += 1
			var spec := {role = marker.role, pos = marker.position, stationary = marker.stationary, seed = index * 191, route = [marker.position], yaw = marker.rotation.y}
			if marker.interaction_enabled:
				spec.title = marker.resident_name  # named people wear their name, not their trade
			var npc := TownNPC.new().setup(spec, navigation)
			npc.name = marker.name + "Actor"
			add_child(npc)
			residents.append(npc)
			if marker.interaction_enabled:
				var target := InteractionTarget.new()
				target.title = marker.resident_name
				target.description = "Visit the forge" if marker.role == "smith" else "Visit the magician's stall" if marker.role == "magician" \
						else str(marker.get_meta("description", "Speak with %s" % marker.resident_name))
				target.action_text = "Talk"
				target.response = marker.greeting
				target.portrait = load("res://creatures/npc_%s/portrait.png" % marker.role)
				npc.add_child(target)
				if marker.role == "smith":
					target.response = marker.greeting + "|Lay anything on the anvil and the forge turns it into Dots."
					var mouth: Node3D = get_node_or_null("Buildings/ForgeHouse/ForgeMouth")
					target.activated.connect(func(_player: Node3D) -> void:
						get_tree().call_group("forge_panels", "open_for", target, mouth))
	if has_node("StreetFurniture"):
		for prop in $StreetFurniture.get_children():
			if str(prop.name).begins_with("Lantern"):
				_add_light(prop.position + Vector3(0, 3.3, 0), Color(1, .74, .42), .65, 5.5)
	if has_node("Fountain"):
		_map_fountain = Vector2($Fountain.position.x, $Fountain.position.z)
		_add_light($Fountain.position + Vector3(0, 5, 0), Color(.35, .8, 1), 1.2, 12)
	_scatter_decor()

func _prepare_navigation() -> void:
	var plan := VillageFeature.new()
	plan.center = Vector2i.ZERO
	plan.radius = 104
	plan.base_height = HomeTerrain.FLOOR
	_footprints.resize(HomeTerrain.SIDE*HomeTerrain.SIDE)
	_footprints.fill(0)
	for collider in find_children("*","CollisionShape3D",true,false):
		if not collider.shape is BoxShape3D: continue
		var local := HomeTerrain._transform_to(collider,self)
		var bounds: AABB = local*AABB(-collider.shape.size/2,collider.shape.size)
		plan.props.append({pos=bounds.get_center(),solid_size=bounds.size})
		_mark_footprint(bounds,2 if has_node("Buildings") and $Buildings.is_ancestor_of(collider) else 1)
	navigation = TownNavigation.new(plan,self)

func _mark_footprint(bounds: AABB, value: int) -> void:
	for z in range(floori(bounds.position.z), ceili(bounds.end.z)):
		for x in range(floori(bounds.position.x), ceili(bounds.end.x)):
			var i := home_terrain.index(x, z)
			if i >= 0 and _footprints[i] < value:
				_footprints[i] = value

## Grass tufts, flowers and beach pebbles on open ground (never on paving
## or under buildings). Fixed hash placement, small spatial MultiMesh batches per prefab.
func _gather_decor() -> Dictionary:
	var groups := {}
	var e := HomeTerrain.EXTENT
	for z in range(-e, e + 1):
		for x in range(-e, e + 1):
			var i := home_terrain.index(x, z)
			if _footprints[i] != 0 or home_terrain.deck[i] > 0:
				continue
			var block := home_terrain.top[i]
			var weights: Dictionary
			var biome := Biomes.WOODS
			var density := DECOR_DENSITY
			if block == Blocks.GRASS:
				weights = DECOR
				density *= 1.6 if home_terrain.shore_distance(x, z) < 14.0 else 1.0
			elif block == Blocks.SAND and home_terrain.height[i] >= HomeTerrain.BEACH:
				weights = BEACH_DECOR
				biome = Biomes.BEACH
				density *= 0.3
			else:
				continue
			if HomeTerrain._hash(x, z, 31) >= density:
				continue
			var chunk := Vector2i(floori(float(x) / 32.0), floori(float(z) / 32.0))
			var key := "%d/%d/%s/%d" % [chunk.x, chunk.y, _pick(weights, HomeTerrain._hash(x, z, 34)), biome]
			var offset := Vector2(HomeTerrain._hash(x, z, 35), HomeTerrain._hash(x, z, 36)) * 0.8 + Vector2(0.1, 0.1)
			var basis := Basis(Vector3.UP, HomeTerrain._hash(x, z, 37) * TAU).scaled(Vector3.ONE * (0.8 + HomeTerrain._hash(x, z, 38) * 0.5))
			if not groups.has(key):
				groups[key] = []
			groups[key].append(Transform3D(basis, Vector3(x + offset.x, home_terrain.height[i] + 1, z + offset.y)))
	return groups

func _scatter_decor() -> void:
	var groups := _prepared_decor if _prepared_load else _gather_decor()
	for key: String in groups:
		if get_meta("asynchronous_load",false): queue_load_step(_scatter_group.bind(key,groups[key]))
		else: _scatter_group(key,groups[key])
	_prepared_decor = {}

func _scatter_group(key: String, placements: Array) -> void:
	var parts := key.split("/")
	var origin := Vector3(int(parts[0]) * 32, 0, int(parts[1]) * 32)
	var prefab := ObstacleLibrary.get_prefab(parts[2])
	var meshes := prefab.meshes_for(Biomes.get_biome(int(parts[3])))
	var local := Transform3D(Basis.from_scale(Vector3.ONE * prefab.voxel_size), prefab.mesh_offset())
	for k in 2:
		if meshes[k] == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[k]
		mm.instance_count = placements.size()
		var bounds := AABB()
		for j in mm.instance_count:
			var placement: Transform3D = placements[j]
			placement.origin -= origin
			var placed := placement * local
			mm.set_instance_transform(j, placed)
			var piece: AABB = placed * meshes[k].get_aabb()
			bounds = piece if j==0 else bounds.merge(piece)
		mm.custom_aabb = bounds.grow(.1)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = VoxModel.glow_material() if k == 1 else VoxModel.material()
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.name = "GroundDecor_%s_%d" % [key.replace("/", "_"), k]
		mmi.position = origin
		# Small spatial batches use normal frustum culling, not one cutoff
		# measured from the center of the entire island.
		mmi.visibility_range_end = 0.0
		mmi.add_to_group("home_ground_decor")
		add_child(mmi)

func _pick(weights: Dictionary, r: float) -> String:
	var total := 0.0
	for w in weights.values():
		total += w
	r *= total
	for key in weights:
		r -= weights[key]
		if r <= 0.0:
			return key
	return weights.keys()[-1]

func is_walkable(pos: Vector3) -> bool:
	return home_terrain.is_land(floori(pos.x), floori(pos.z))

func map_color(x: int, z: int) -> Color:
	var i := home_terrain.index(x, z)
	if i < 0: return WATER_COLOR
	if _footprints[i] == 2: return Color(.47, .32, .23)
	if Vector2(x - _map_fountain.x, z - _map_fountain.y).length() < 6: return Color(.3, .7, .85)
	return home_terrain.map_color(x, z)

func ground_height(x: float, z: float) -> float:
	return home_terrain.stand_height(floori(x), floori(z))


## Stalls from the village market prefab, a shopkeeper behind each counter.
# --- Heaven: the Tavern floats on clouds -----------------------------------------------------

## Water stays in the lagoon, with short spills into a shallow voxel cloud rim.
const CLOUD_FLOOR := 4.0

func _heaven() -> void:
	var e := HomeTerrain.EXTENT
	var mask := Image.create(HomeTerrain.SIDE, HomeTerrain.SIDE, false, Image.FORMAT_L8)
	for z in HomeTerrain.SIDE:
		for x in HomeTerrain.SIDE:
			var d := home_terrain.shore_distance(x - e, z - e)
			mask.set_pixel(x, z, Color.WHITE if d >= -HomeTerrain.RIM - 0.5 else Color.BLACK)
	if has_node("CoastWater"):
		var water: MeshInstance3D = $CoastWater
		var material := (water.mesh.surface_get_material(0) as ShaderMaterial).duplicate() as ShaderMaterial
		material.set_shader_parameter("use_mask", true)
		material.set_shader_parameter("island_mask", ImageTexture.create_from_image(mask))
		material.set_shader_parameter("mask_rect", Vector4(-e, -e, HomeTerrain.SIDE, HomeTerrain.SIDE))
		water.material_override = material
	_waterfalls()
	_cloud_rim()

## Short water curtains spill into the clouds at the lagoon edge.
func _waterfalls() -> void:
	var e := HomeTerrain.EXTENT
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var segments := 10
	for z in range(-e, e + 1):
		for x in range(-e, e + 1):
			var d := home_terrain.shore_distance(x, z)
			if d >= -HomeTerrain.RIM + 0.5 or d < -HomeTerrain.RIM - 1.5 or not HomeTerrain.is_fall(x, z): continue
			var out := Vector3(x, 0, z).normalized()
			var side := out.cross(Vector3.UP)
			var top := Vector3(x + 0.5, IslandGenerator.SEA_LEVEL + 0.6, z + 0.5) + out * 0.8
			for k in segments:
				var t0 := float(k) / segments
				var t1 := float(k + 1) / segments
				var p0 := top + Vector3.DOWN * t0 * (top.y - CLOUD_FLOOR) + out * t0 * t0 * 9.0
				var p1 := top + Vector3.DOWN * t1 * (top.y - CLOUD_FLOOR) + out * t1 * t1 * 9.0
				var w0 := 0.6 + t0 * 0.5
				var w1 := 0.6 + t1 * 0.5
				for v: Vector3 in [p0 - side * w0, p1 - side * w1, p1 + side * w1, p0 - side * w0, p1 + side * w1, p0 + side * w0]:
					verts.append(v)
				var u := float(x * 7 + z * 3) * 0.13
				for uv: Vector2 in [Vector2(u, t0), Vector2(u, t1), Vector2(u + 1.0, t1), Vector2(u, t0), Vector2(u + 1.0, t1), Vector2(u + 1.0, t0)]:
					uvs.append(uv)
	if verts.is_empty(): return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var falls := MeshInstance3D.new()
	falls.name = "Waterfalls"
	falls.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/waterfall.gdshader")
	falls.material_override = material
	falls.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(falls)

## Static box clusters follow the authored coastline. One draw batch, no
## distant cloud plane, animated nodes, collisions or hidden deep geometry.
func _cloud_rim() -> void:
	var transforms: Array[Transform3D] = []
	var e := HomeTerrain.EXTENT
	for z in range(-e, e, 3):
		for x in range(-e, e, 3):
			var d := home_terrain.shore_distance(x, z)
			var ripple := sin(x * 0.13) * 2.0 + cos(z * 0.17) * 2.0
			if d > -HomeTerrain.RIM + 2.0 or d < -HomeTerrain.RIM - 12.0 - ripple:
				continue
			var crest := int((sin(x * 0.21) + cos(z * 0.19) + 2.0) * 0.75)
			var top := 9.0 + crest
			# Small channels let the lagoon spill into the clouds.
			if HomeTerrain.is_fall(x, z) and d > -HomeTerrain.RIM - 3.0:
				top = 6.0
			var size := Vector3(3, top - CLOUD_FLOOR, 3)
			transforms.append(Transform3D(Basis.from_scale(size), Vector3(x + 1.5, CLOUD_FLOOR + size.y * 0.5, z + 1.5)))
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.97, 0.98, 1.0)
	material.roughness = 1.0
	material.emission_enabled = true
	material.emission = Color(0.78, 0.85, 1.0)
	material.emission_energy_multiplier = 0.18
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE
	cube.material = material
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = cube
	batch.instance_count = transforms.size()
	for i in transforms.size():
		batch.set_instance_transform(i, transforms[i])
	var clouds := MultiMeshInstance3D.new()
	clouds.name = "VoxelCloudRim"
	clouds.multimesh = batch
	clouds.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(clouds)

func _build_market() -> void:
	var stall_scene: PackedScene = load("res://scenes/home/prefabs/market.tscn")
	for spec: Array in MARKET_STALLS:
		var at := Vector3(float(spec[1]), 10, float(spec[2]))
		var to_center := Vector2(MARKET_CENTER.x-at.x, MARKET_CENTER.y-at.z)
		var yaw := atan2(-to_center.x, -to_center.y)  # the stall's front (-Z) faces the yard
		var stall: Node3D = stall_scene.instantiate()
		stall.name = "MarketStall_"+str(spec[0])
		stall.position = at
		stall.rotation.y = yaw
		add_child(stall)
		var behind := Basis(Vector3.UP, yaw)*Vector3(0, 0, 2.1)
		var keeper := ShopKeeper.place(self, str(spec[0]), Transform3D(Basis(Vector3.UP, yaw), at+behind))
		keeper.target.reach = 5.5  # over the counter
		_add_light(at+Vector3(0, 3.6, 0), Color(1, .78, .5), .55, 6.0)
	for spec: Array in MARKET_KEEPERS:
		var at := Vector3(float(spec[1]), 10, float(spec[2]))
		var to_center := Vector2(MARKET_CENTER.x-at.x, MARKET_CENTER.y-at.z)
		ShopKeeper.place(self, str(spec[0]), Transform3D(Basis(Vector3.UP, atan2(-to_center.x, -to_center.y)), at))
