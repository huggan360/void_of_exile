extends Node3D
func _ready() -> void:
	call_deferred("_check")
func _check() -> void:
	var castle := CastleWorld.stage() as CastleWorld
	add_child(castle)
	var biome := castle.biome_at(Vector3.ZERO)
	assert(biome.fog_density == 0 and biome.volumetric_fog_density == 0 and not biome.fog_of_war_enabled)
	assert(Biomes.get_biome(Biomes.HALL).volumetric_fog_density > 0)
	var env := load("res://scenes/castle/castle_environment.tres") as Environment
	assert(not env.fog_enabled and not env.volumetric_fog_enabled)
	for z in range(84, 147): assert(castle.is_walkable(Vector3(0.5, 0, z + 0.5)), "Road blocked at %s" % z)
	for point in [Vector3(0, 0, 151), Vector3(40, 0, 100), Vector3(190, 0, 0), Vector3(0, 0, -190), Vector3(0, 0, 194)]:
		assert(not castle.is_walkable(point), "Exterior boundary open at %s" % point)
	var fire_lights := 0
	for light in castle.get_node("Lights").get_children():
		if str(light.name).begins_with("ForestFireLight"):
			fire_lights += 1
			assert(not light.shadow_enabled)
	assert(fire_lights == 6)
	var emitters := 0
	for prop in castle.get_node("Props").get_children():
		if prop.kind in ["burning_tree", "embers"] and prop.ember_particles: emitters += 1
	assert(emitters <= 32)
	print("[castle] Fog-free biome, road, exterior boundaries, six lights / 32 emitters passed")
	get_tree().quit()
