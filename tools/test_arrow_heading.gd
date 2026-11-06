extends Node3D
## Regression checks for stationary frames, realm precision and vertical shots.
var checks := 0
var failures := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	GameServer.set_physics_process(false)
	var arrows := Arrows.new()
	add_child(arrows)
	arrows.set_physics_process(false)
	var weapon := Items.make("G1_bow")
	for direction in [Vector3.ZERO, Vector3(NAN, 0, 0), Vector3(INF, 0, 0)]:
		arrows.spawn(Vector3.ZERO, direction, 1, weapon)
	check(arrows._shots.is_empty(), "Invalid directions never create a projectile")
	for direction in [Vector3.FORWARD, Vector3.UP, Vector3.DOWN]:
		arrows.spawn(Vector3.ZERO, direction * 2.0, 1, weapon, 0.0, "", {size = 1.7})
		var shot: Dictionary = arrows._shots.back()
		var basis: Basis = shot.node.global_basis
		check(basis.is_finite() and (-basis.z.normalized()).is_equal_approx(direction), "Valid heading including straight up/down")
		arrows._physics_process(0.0)
		check(shot.node.global_basis.is_equal_approx(basis), "Zero-delta frame preserves heading and scale")
		arrows._physics_process(1.0 / 60.0)
		check(shot.node.global_position.dot(direction) > 0.0, "Flight resumes after stationary frame")
		check(shot.node.scale.is_equal_approx(Vector3.ONE * 1.7), "Flight preserves projectile scale")
		arrows.clear()
	# At this world position, a tiny forward step rounds to the same float.
	arrows.spawn(Vector3(100000, 100000, 100000), Vector3.RIGHT, 1, weapon)
	var far_shot: Dictionary = arrows._shots.back()
	var before: Transform3D = far_shot.node.global_transform
	arrows._physics_process(0.000001)
	check(far_shot.node.global_transform.is_equal_approx(before), "Position rounding preserves a valid heading")
	arrows._physics_process(10.0)
	check(arrows._shots.is_empty(), "Rounding does not prevent range expiry")
	arrows.queue_free()
	await get_tree().process_frame
	print("ARROW HEADING: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
