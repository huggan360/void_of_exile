extends Node3D
## Headless layout and construction check; no networking or screenshots.
## Run: godot_voxel_editor --headless --path . tools/check_chambers.tscn

var _failures := 0


func _ready() -> void:
	var world := ChambersWorld.new({id = "chm_1", chests = 120})
	var slots := ChambersWorld.chest_layout(120)
	_check(slots.size() == 120, "120 vault slots")
	_check(world.realm_id == "chm_1" and ChambersWorld.id_for(1) == "chm_1", "account realm identity")
	_check(world.is_walkable(world.spawn_point), "spawn is clear")
	_check(not world.is_walkable(Vector3(0, 0, 23)), "entrance cannot leave the church")
	_check(not world.is_walkable(Vector3(26, 0, -10)), "chapels cannot leave the church")
	_check(not world.is_walkable(Vector3(0, 0, -32)), "apse cannot leave the church")
	for entry: Array in ChambersWorld.furnishing_layout():
		_check(not world.is_walkable(entry[1]), "%s blocks walking" % entry[0])
	var reachable := _flood(world)
	var minimum_spacing := INF
	for i in slots.size():
		var at: Vector3 = slots[i][0]
		_check(world.is_walkable(at), "chest %d is walkable" % (i + 1))
		var can_reach := false
		for dx in range(-2, 3):
			for dz in range(-2, 3):
				var cell := Vector2i(roundi(at.x * 2) + dx, roundi(at.z * 2) + dz)
				var stand := Vector3(cell.x * 0.5, 0, cell.y * 0.5)
				var distance := stand.distance_to(at)
				if distance >= 0.85 and distance <= 1.15 and reachable.has(cell):
					can_reach = true
		_check(can_reach, "chest %d has a reachable interaction position" % (i + 1))
		for furnishing: Array in ChambersWorld.furnishing_layout():
			var center: Vector3 = furnishing[1]
			var size: Vector3 = furnishing[2]
			_check(absf(at.x - center.x) >= size.x * 0.5 + 0.85 or absf(at.z - center.z) >= size.z * 0.5 + 0.85,
					"chest %d clears %s" % [i + 1, furnishing[0]])
		for j in range(i):
			minimum_spacing = minf(minimum_spacing, at.distance_to(slots[j][0]))
	_check(minimum_spacing >= 2.39, "chests have at least 2.4 m spacing")
	for count in [4, 32, 120]:
		var other := ChambersWorld.new({id = "chm_1", chests = count})
		_check(ChambersWorld.chest_layout(count) == slots.slice(0, count), "%d chests preserve slot order" % count)
		_check(other.half_extent == world.half_extent, "%d chests preserve world size" % count)
		other.free()
	var buffer := VoxelBuffer.new()
	buffer.create(128, 16, 128)
	var generator := ChambersWorld.ChambersGenerator.new()
	generator._generate_block(buffer, Vector3i(-64, -8, -64), 0)
	for slot: Array in slots:
		var at: Vector3 = slot[0]
		_check(buffer.get_voxel(floori(at.x) + 64, 7, floori(at.z) + 64, VoxelBuffer.CHANNEL_TYPE) != Blocks.AIR,
				"chest has a terrain floor")
		_check(buffer.get_voxel(floori(at.x) + 64, 8, floori(at.z) + 64, VoxelBuffer.CHANNEL_TYPE) == Blocks.AIR,
				"chest has no terrain obstruction")
	var mesh := Blocks.mesher().build_mesh(buffer, [], {})
	_check(mesh != null and mesh.get_surface_count() > 0, "cathedral terrain meshes")
	add_child(world)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var lights := world.find_children("*", "OmniLight3D", true, false)
	_check(lights.size() <= 20, "at most 20 lights")
	for light: OmniLight3D in lights:
		_check(light.distance_fade_enabled, "lights fade with distance")
	_check(world.find_children("*", "MultiMeshInstance3D", true, false).size() >= 12, "repeated scenery is batched")
	var portal: Portal = world.get_node("ReturnToTavern")
	_check(portal.destination == "hall", "return portal leads to Tavern")
	_check(world.spawn_point.distance_to(portal.position) > 3.5, "spawn is outside the portal")
	print("Chambers check: %d failures; %d reachable cells; 120 slots; %.2f m minimum spacing; %d lights." % [
			_failures, reachable.size(), minimum_spacing, lights.size()])
	world.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if _failures == 0 else 1)


func _flood(world: ChambersWorld) -> Dictionary:
	var start := Vector2i(roundi(world.spawn_point.x * 2), roundi(world.spawn_point.z * 2))
	var queue: Array[Vector2i] = [start]
	var visited := {start: true}
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + offset
			if visited.has(next) or not world.is_walkable(Vector3(next.x * 0.5, 0, next.y * 0.5)):
				continue
			visited[next] = true
			queue.append(next)
	return visited


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
