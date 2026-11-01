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

func _init() -> void:
	display_name = "Hearthhaven · The Tavern"
	realm_id = "hall"
	half_extent = 120

func _ready() -> void:
	home_terrain = HomeTerrain.from_scene(self)
	var e := HomeTerrain.EXTENT
	_add_terrain(HallGenerator.new(home_terrain), AABB(Vector3(-e, -8, -e), Vector3(e * 2 + 1, 48, e * 2 + 1)))
	if not has_node("CoastWater"): _add_water(IslandGenerator.SEA_LEVEL + 0.6, 400.0)
	if has_node("Spawn"): spawn_point = $Spawn.position
	var gate_position: Vector3 = $RealmGate.position if has_node("RealmGate") else Vector3(0, 10, -60)
	var gate_facing: Vector3 = -$RealmGate.basis.z if has_node("RealmGate") else Vector3.BACK
	_add_portal(gate_position, gate_facing, "campaign" if campaign_tavern else "realm_1", Color(0.45, 0.25, 1.0), Color(0.2, 0.85, 1.0))
	# The Chronicle Gate: into your party's own realm, while it plays a campaign.
	if has_node("CampaignGate") and not campaign_tavern:
		campaign_portal = _add_portal($CampaignGate.position, -$CampaignGate.basis.z, "campaign", Color(1.0, 0.7, 0.2), Color(1.0, 0.35, 0.6))
		campaign_portal.set_active(false)
	# Navigation derives its obstacles from the edited scene, never a second layout.
	var plan := VillageFeature.new()
	plan.center = Vector2i.ZERO
	plan.radius = 104
	plan.base_height = HomeTerrain.FLOOR
	_footprints.resize(HomeTerrain.SIDE * HomeTerrain.SIDE)
	_footprints.fill(0)
	for collider in find_children("*", "CollisionShape3D", true, false):
		if not collider.shape is BoxShape3D: continue
		var bounds: AABB = collider.global_transform * AABB(-collider.shape.size / 2, collider.shape.size)
		plan.props.append({pos = bounds.get_center(), solid_size = bounds.size})
		var building := has_node("Buildings") and $Buildings.is_ancestor_of(collider)
		_mark_footprint(bounds, 2 if building else 1)
	navigation = TownNavigation.new(plan, self)
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
	if has_node("StreetFurniture"):
		for prop in $StreetFurniture.get_children():
			if str(prop.name).begins_with("Lantern"):
				_add_light(prop.position + Vector3(0, 3.3, 0), Color(1, .74, .42), .65, 5.5)
	if has_node("Fountain"):
		_map_fountain = Vector2($Fountain.position.x, $Fountain.position.z)
		_add_light($Fountain.position + Vector3(0, 5, 0), Color(.35, .8, 1), 1.2, 12)
	_scatter_decor()

func _mark_footprint(bounds: AABB, value: int) -> void:
	for z in range(floori(bounds.position.z), ceili(bounds.end.z)):
		for x in range(floori(bounds.position.x), ceili(bounds.end.x)):
			var i := home_terrain.index(x, z)
			if i >= 0 and _footprints[i] < value:
				_footprints[i] = value

## Grass tufts, flowers and beach pebbles on open ground (never on paving
## or under buildings). Fixed hash placement, small spatial MultiMesh batches per prefab.
func _scatter_decor() -> void:
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
	for key: String in groups:
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
			mm.instance_count = groups[key].size()
			var bounds := AABB()
			for j in mm.instance_count:
				var placement: Transform3D = groups[key][j]
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
