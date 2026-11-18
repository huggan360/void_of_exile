extends Node3D
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _ready() -> void: run.call_deferred()
func run() -> void:
	GameAudio._disabled = true
	GameServer.set_physics_process(false)
	WorldServer.set_process(false)
	var arrows := Arrows.new()
	add_child(arrows)
	arrows.set_physics_process(false)
	var meshes_seen := {}
	var primary_seen := {}
	var charged_seen := {}
	var count := 0
	for row: Dictionary in SignatureItems.definitions():
		if row.rarity != "L" or row.slot != "weapon": continue
		var item := Items.make(row.id)
		count += 1
		var meshes := arrows._meshes_for(item, str(item.projectile.style))
		var vertices := []
		for mesh: ArrayMesh in meshes:
			if mesh: vertices.append(var_to_str(mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]))
		var mesh_key := str(vertices).sha256_text()
		check(not meshes_seen.has(mesh_key), "Individual geometry, independent of color: " + item.id)
		meshes_seen[mesh_key] = item.id
		for secondary in [false, true]:
			var entries := SignaturePatterns.charged(Vector3.FORWARD, Vector3.UP, item, 2.7) if secondary else SignaturePatterns.primary(Vector3.FORWARD, Vector3.UP, item)
			if entries.is_empty():
				check(item.id == "L_wand_thewandofash" and item.charge.style == "inferno", "Only Ash preserves its existing special inferno")
				continue
			var budget := 0.0
			var fingerprint := []
			for entry: Dictionary in entries:
				budget += float(entry.share)
				arrows.spawn(Vector3(0, 10, 0), entry.direction, 0, item, entry.phase, "", entry.mods)
				var shot: Dictionary = arrows._shots.back()
				for d in [0.0, 2.0, 4.0, 7.0, 10.0, 14.0]:
					var at := arrows._position_at(shot, d)
					check(at.is_finite(), "Valid real flight sample: " + item.id)
					fingerprint.append(at.snapped(Vector3.ONE * 0.01))
				fingerprint.append(float(entry.mods.get("delay", 0)))
				fingerprint.append(float(entry.mods.get("speed", 1)))
			check(is_equal_approx(budget, 2.7 if secondary else 1.0), "Patterns share a fixed total damage budget: " + item.id)
			var key := str(fingerprint).sha256_text()
			var seen := charged_seen if secondary else primary_seen
			check(not seen.has(key), "Individual flight formation and timing: " + item.id)
			seen[key] = item.id
			arrows.clear()
		var sideways := SignaturePatterns.primary(Vector3.RIGHT, Vector3.RIGHT, item)
		check(sideways.all(func(s: Dictionary) -> bool: return s.direction.is_finite() and is_equal_approx(s.direction.length(), 1.0)), "Aiming parallel to planet gravity is valid: " + item.id)
	check(count == 29 and meshes_seen.size() == 29 and primary_seen.size() == 29 and charged_seen.size() == 28, "All Legendary weapon identities are covered")
	var delayed := Items.make("L_wand_wakeful")
	arrows.spawn(Vector3(0, 10, 0), Vector3.FORWARD, 0, delayed, 0, "", {delay = 0.1, visual = true})
	check(not arrows._shots[0].node.visible, "A queued shot is hidden before its launch")
	arrows._physics_step(0.05)
	check(arrows._shots[0].travelled == 0 and not arrows._shots[0].node.visible, "Delayed shot does not travel or collide early")
	arrows._physics_step(0.06)
	check(arrows._shots[0].node.visible and arrows._shots[0].travelled > 0, "Delayed shot becomes visible and starts travelling")
	arrows.clear()
	arrows.queue_free()
	await get_tree().process_frame
	print("LEGENDARY IDENTITIES: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
