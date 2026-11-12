extends Node
## Builds every planet's town, first village, landmarks, one flora patch and
## one ground-cover tile, to catch script errors (no rendering):
## godot --headless --path . res://tools/space/check_planet_art.tscn
func _ready() -> void:
	var root3d := Node3D.new()
	add_child(root3d)
	await get_tree().process_frame
	for p: Dictionary in SpaceLayout.PLANETS:
		if p.get("city", false): continue
		var t := Time.get_ticks_msec()
		var holder := Node3D.new()
		holder.position = p.center
		root3d.add_child(holder)
		var town := PlanetTown.new()
		holder.add_child(town)
		town.build_town(p)
		var villages := SpaceLayout.settlements(p)
		if not villages.is_empty():
			var village := PlanetTown.new()
			holder.add_child(village)
			village.build_village(p, villages[0])
		for i in 4:
			var place := Node3D.new()
			holder.add_child(place)
			var offset := SpaceLayout.place_offset(p, i)
			PlanetProps.place_art(place, p, i, SpaceLayout.place_frame_raw(p, offset*1.1), SpaceLayout.place_frame_raw(p, offset))
		var flora := PlanetFlora.new()
		holder.add_child(flora)
		flora.build(p)
		flora._build_patch(flora._patches.values()[0])
		var cover := PlanetGroundCover.new()
		holder.add_child(cover)
		cover.setup(p)
		var out := {}
		cover._work(Vector4i(0, 2, 7, 3), out)
		for kind: String in out: cover._batch(kind, out[kind]).free()
		var pad := Node3D.new()
		holder.add_child(pad)
		SpacePlanet.build_pad(pad, p, null, "test")
		print("%s: town %d nodes, cover kinds %d, %d ms" % [p.id, town.get_child_count(), out.size(), Time.get_ticks_msec()-t])
		holder.queue_free()
		await get_tree().process_frame
	get_tree().quit()
