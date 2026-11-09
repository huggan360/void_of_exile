class_name DungeonWorld
extends GameWorld
var record: Dictionary
var definition: Dictionary
var layout: DungeonLayout
## Layouts generated ahead of opening (instance id -> DungeonLayout).
static var prepared := {}
var enemy_director := EnemyDirector.new()
var server_build := false
var _biome: BiomeDef
var theme: Dictionary
var _prepared_scenery: DungeonScenery

func _init(p_record: Dictionary) -> void:
	record = p_record
	realm_id = record.id
	definition = Dungeons.definition(record.dungeon)
	display_name = definition.name
	# Made ahead on a worker thread by the server (DungeonServer), or right here.
	layout = prepared.get(str(record.id)) if prepared.has(str(record.id)) else DungeonLayout.new(definition, int(record.seed))
	prepared.erase(str(record.id))
	half_extent = layout.extent
	spawn_point = layout.spawn
	theme = Dungeons.theme(definition)
	_biome = Biomes.get_biome(theme.base).duplicate()
	_biome.biome_name = theme.name
	_biome.indoor = true
	_biome.sky_top_color = theme.sky
	_biome.sky_horizon_color = theme.horizon
	_biome.sun_color = theme.sun
	_biome.sun_energy = theme.sun_energy
	_biome.ambient_energy = theme.ambient
	_biome.volumetric_fog_density = 0.006
	_biome.reveal_radius = theme.reveal
	_biome.fog_of_war_color = theme.fog_of_war
	_biome.fog_color = theme.fog
	_biome.fog_density = 0.004
	_biome.torch_energy = theme.torch

func prepare_load() -> void:
	_prepared_scenery = DungeonScenery.new()
	_prepared_scenery.prepare(layout,str(definition.get("theme","moss_cave")))
	# Own the detached data node immediately, including cancellation paths.
	add_child(_prepared_scenery)

func _ready() -> void:
	_add_terrain(DungeonGenerator.new(layout, theme), AABB(Vector3(-half_extent, -8, -half_extent), Vector3(half_extent * 2, 24, half_extent * 2)))
	enemy_director.world = self
	enemy_director.realm_id = realm_id
	enemy_director.remote = Net.is_client()
	add_child(enemy_director)
	if not server_build and not Net.is_server():
		if is_instance_valid(_prepared_scenery):
			_prepared_scenery.publish()
		else:
			var scenery := DungeonScenery.new()
			scenery.build(layout, str(definition.get("theme", "moss_cave")))
			add_child(scenery)
		if definition.get("theme", "moss_cave") == "moss_cave":
			var fireflies := DungeonFireflies.new()
			fireflies.build(layout)
			add_child(fireflies)
	for i in layout.rooms.size():
		var room: Dictionary = layout.rooms[i]
		var at := layout.point(i)
		if not server_build and not Net.is_server():
			for side in [-1.0, 1.0]:
				var pos := at + Vector3(side * (room.radius - 2), 0, 0)
				if definition.get("theme", "moss_cave") == "moss_cave": _mushroom(pos)
				else: _brazier(pos)
		match room.kind:
			"spawn":
				if not Net.is_server(): DungeonPortal.place(self, {id = "spawn_exit", pos = at + Vector3(0, 0, 4), exit = true, dungeon = record.dungeon, destination = record.get("origin", "hall")})
			"boss": _site(i, [definition.boss])
			"miniboss": _site(i, [definition.miniboss, definition.low_enemies[0], definition.low_enemies[0]])
			"treasure": _site(i, [str(definition.get("treasure", "goblin_treasure"))])
			_:
				var rng := RandomNumberGenerator.new()
				rng.seed = int(record.seed) + i * 977
				var members: Array = []
				for k in rng.randi_range(2, 4): members.append(definition.low_enemies[rng.randi_range(0, definition.low_enemies.size() - 1)])
				if rng.randf() < 0.65: members.append(definition.mid_enemies[rng.randi_range(0, definition.mid_enemies.size() - 1)])
				_site(i, members)
	print("[dungeon] %s seed=%d rooms=%d branches=%d treasure=%d miniboss=%d boss=%s" % [realm_id, record.seed, layout.rooms.size(), layout.edges.size(), layout.treasure, layout.miniboss, layout.boss])

func _site(index: int, members: Array) -> void:
	var key := "%s_room_%d" % [realm_id, index]
	var specs: Array = []
	for member in members: specs.append({enemy = member, min = 1, max = 1})
	Enemies.pack_overrides[key] = {members = specs, respawn_time = -1.0, activate_radius = 42.0}
	enemy_director.add_quest_site({id = key, pack = key, pos = layout.point(index), seed = int(record.seed) + index * 97})

## A stone bowl of fire lighting a room (halls, volcanoes, the burning forest).
func _brazier(at: Vector3) -> void:
	_add_light(at + Vector3.UP * 2.2, theme.light, 2.2, 20.0)
	for spec: Array in [[Vector3(0, 0.45, 0), Vector3(0.35, 0.9, 0.35), Color("3a3330"), false],
			[Vector3(0, 1.0, 0), Vector3(0.8, 0.25, 0.8), Color("4a403a"), false], [Vector3(0, 1.25, 0), Vector3(0.5, 0.35, 0.5), theme.light, true]]:
		var part := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = spec[1]
		part.mesh = box
		var material := StandardMaterial3D.new()
		material.albedo_color = spec[2]
		if spec[3]:
			material.emission_enabled = true
			material.emission = spec[2]
			material.emission_energy_multiplier = 2.0
		part.material_override = material
		part.position = at + spec[0]
		add_child(part)


func _mushroom(at: Vector3) -> void:
	_add_light(at + Vector3.UP * 2.5, Color("9cdb77"), 2.0, 22.0)
	for offset: Vector3 in [Vector3.ZERO, Vector3(0.6, 0, 0.4), Vector3(-0.4, 0, 0.5)]:
		var stem := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.18, 0.65, 0.18)
		stem.mesh = box
		stem.position = at + offset + Vector3.UP * 0.3
		add_child(stem)
		var cap := MeshInstance3D.new()
		var cap_mesh := BoxMesh.new()
		cap_mesh.size = Vector3(0.65, 0.22, 0.65)
		cap.mesh = cap_mesh
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("77ad52")
		material.emission_enabled = true
		material.emission = Color("588f39")
		cap.material_override = material
		cap.position = at + offset + Vector3.UP * 0.7
		add_child(cap)

func biome_at(_pos: Vector3) -> BiomeDef:
	return _biome

func ground_height(_x: float, _z: float) -> float:
	return 1.0

func is_walkable(pos: Vector3) -> bool:
	return layout.open(floori(pos.x), floori(pos.z))

## Lava cracks apply Burning through the authoritative environment update.
func is_hazard(pos: Vector3) -> bool:
	return layout.is_crack(floori(pos.x), floori(pos.z))

func map_color(x: int, z: int) -> Color:
	if layout.is_crack(x, z):
		return Color("ff6a1a")
	return theme.map if layout.open(x, z) else Color("22232b")

func update_streaming_multi(_positions: Array, _force := false) -> void:
	pass

func cleared_packs() -> Array:
	return []

func pack_survivors() -> Dictionary:
	return {}

func obstacles_near(_pos: Vector3, _radius: float) -> Array[String]:
	return []

func remove_obstacle(_id: String) -> void:
	pass


func _exit_tree() -> void:
	for index in layout.rooms.size():
		Enemies.pack_overrides.erase("%s_room_%d" % [realm_id, index])
