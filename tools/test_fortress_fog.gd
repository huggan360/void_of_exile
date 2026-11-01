extends Node3D
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(message)
func _ready() -> void:
	var generator := IslandGenerator.new(WorldServer.MAP_SEED,RealmLayout.data())
	var fog := FogOfWar.new()
	add_child(fog)
	fog.setup(688)
	fog.set_strongholds(generator.strongholds)
	for fort in generator.strongholds:
		var before := Vector3(fort.center.x,fort.base_height+1,fort.center.y-40)
		fog.reveal_around(before)
		check(not fog._revealed_forts.has(fort.center),"Approaching a fortress does not reveal from outside its walls")
		fog.reveal_around(Vector3(fort.center.x,fort.base_height+1,fort.center.y-35))
		check(fog._revealed_forts.has(fort.center),"Entering each fortress reveals it")
		for z in range(fort.bounds.position.y,fort.bounds.end.y):
			for x in range(fort.bounds.position.x,fort.bounds.end.x):
				check(fog._image.get_pixel(x+688,z+688).r==1,"Every arena/wall/entrance/apron texel is fully explored")
		fog.reveal_around(Vector3.ZERO)
		check(fog._image.get_pixel(fort.center.x+688,fort.center.y+688).r==1,"Stronghold stays clear after leaving")
	check(fog._image.get_pixel(688,688+600).r==0,"Distant unexplored wilderness keeps its fog")
	fog.setup(688)
	check(fog._revealed_forts.is_empty() and fog._image.get_pixel(688,688).r==0,"Travel resets discovery normally")
	fog.free()
	print("FORTRESS FOG: %d checks; %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
