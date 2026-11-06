class_name DungeonPortal
extends Node3D
## A visual hole above the intact floor; travel and lifetime stay server-owned.
const CLOSE_TIME := 1.2
const SUCKED := 40  # black voxels drawn into the hole, so it reads from afar
var data: Dictionary
var remaining := -1.0
var target: InteractionTarget
var _surface: ShaderMaterial
var _rim: MultiMeshInstance3D
var _growth: MultiMeshInstance3D
var _rim_points := PackedVector3Array()
var _growth_points := PackedVector3Array()
var _growth_sizes := PackedVector3Array()
var _growth_colors := PackedColorArray()
var _age := 0.0
var _closing := false
var _close_age := 0.0
var _seal_burst := false
var _close_opening := 1.0
var _style: Dictionary
var _suction: MultiMeshInstance3D
var _motes: Array[Vector3] = []  # per mote: start angle, start radius, progress 0..1

func _init(p_data: Dictionary = {}) -> void:
	data = p_data
	remaining = float(data.get("remaining", -1.0))

func _ready() -> void:
	add_to_group("dungeon_portals")
	position = data.get("pos", Vector3.ZERO)
	var definition := Dungeons.definition(str(data.get("dungeon", "goblins_cave")))
	_style = definition.portal_hole
	_build_hole()
	_build_suction()
	target = InteractionTarget.new()
	target.title = "Return to the Realm" if data.get("exit", false) else definition.name
	target.description = "Return to the realm this cave opened from." if data.get("exit", false) else "Difficulty [b]%.1f/10[/b] - %s - common loot up to G%d" % [definition.rating, definition.get("damage_hint", "enemies hit hard" if definition.rating >= 7.0 else "enemies hit moderately"), definition.common_tier]
	if str(data.get("dungeon",""))=="theory_of_everything" and not data.get("exit",false):
		target.description = "Cross two vessels and a gravity-bent expanse. Decipher the locks and reach the Convergence chamber."
	target.action_text = "Enter"
	target.difficulty = -1.0 if data.get("exit", false) else float(definition.rating)
	target.reach = 3.5
	target.activated.connect(func(_player: Node3D) -> void:
		if Net.is_client(): Net.client.send_action("dungeon", [str(data.id)])
		else: get_parent().portal_entered.emit(str(data.get("destination", "hall"))))
	add_child(target)
	_process(0.0)

## Small black voxels that rain down from above the hole and are pulled into
## it, swirling and speeding up as they fall.
func _build_suction() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color(0.02, 0.015, 0.03)
	mesh.material = black
	_suction = MultiMeshInstance3D.new()
	_suction.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_suction.multimesh = MultiMesh.new()
	_suction.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_suction.multimesh.mesh = mesh
	_suction.multimesh.instance_count = SUCKED
	add_child(_suction)
	for i in SUCKED:
		_motes.append(Vector3(randf() * TAU, randf_range(0.2, 1.3), randf()))


func _update_suction(delta: float, opening: float) -> void:
	var r := float(_style.radius)
	for i in SUCKED:
		var m := _motes[i]
		m.z += delta * lerpf(0.3, 0.8, m.z)  # speeds up as it falls in
		if m.z >= 1.0:
			m = Vector3(randf() * TAU, randf_range(0.2, 1.3), 0.0)
		_motes[i] = m
		var k := m.z * m.z
		var angle := m.x + k * 1.6  # a gentle swirl on the way down
		var dist := lerpf(r * m.y, r * 0.05, smoothstep(0.2, 1.0, m.z))
		var height := lerpf(3.6 + m.y * 0.8, -0.4, k)
		var size: float = float(_style.voxel) * lerpf(0.55, 0.25, k) * opening
		_suction.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * maxf(0.001, size)),
				Vector3(cos(angle) * dist, height, sin(angle) * dist / 1.08)))


func _batch() -> MultiMeshInstance3D:
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = MultiMesh.new()
	batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	batch.multimesh.use_colors = true
	batch.multimesh.mesh = BoxMesh.new()
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/dungeon_voxel.gdshader")
	batch.material_override = material
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(batch)
	return batch

func _build_hole() -> void:
	var disc := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * float(_style.radius) * 2.2
	disc.mesh = plane
	disc.position.y = 0.025
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_surface = ShaderMaterial.new()
	_surface.shader = preload("res://shaders/dungeon_hole.gdshader")
	_surface.set_shader_parameter("earth", _style.earth)
	disc.material_override = _surface
	add_child(disc)
	_rim = _batch()
	_growth = _batch()
	var rng := RandomNumberGenerator.new()
	# The definition owns this seed: drops and both exit variants are identical.
	rng.seed = int(_style.seed)
	var rim_colors := PackedColorArray()
	var growth_colors := PackedColorArray()
	var voxel: float = _style.voxel
	for z in range(-9, 10):
		for x in range(-9, 10):
			var p := Vector3(x * voxel, 0, z * voxel)
			var radius := Vector2(p.x, p.z * 1.08).length()
			if radius < float(_style.radius) - 0.19 or radius > float(_style.radius) + rng.randf_range(0.04, 0.23): continue
			p.y = rng.randf_range(0.06, 0.19)
			_rim_points.append(p)
			rim_colors.append(_style.earth if rng.randf() < 0.45 else _style.stone)
			if rng.randf() < 0.5:
				for k in rng.randi_range(2, 5):
					_growth_points.append(p * Vector3(1, 0, 1) + Vector3(-p.x, 0, -p.z).normalized() * k * 0.09 + Vector3.UP * (0.08 + k * 0.055))
					_growth_sizes.append(Vector3(0.13, 0.11, 0.13))
					growth_colors.append(_style.moss if k % 3 else _style.leaf)
	# Roots lie on the dark inner shelves, descending visually into the pit.
	for i in 7:
		var angle := rng.randf() * TAU
		for k in rng.randi_range(4, 8):
			var radius := float(_style.radius) - 0.16 - k * 0.08
			_growth_points.append(Vector3(cos(angle) * radius, 0.045 + (7 - k) * 0.008, sin(angle) * radius / 1.08))
			_growth_sizes.append(Vector3(0.055, 0.045, 0.12))
			growth_colors.append(_style.root)
	_rim.multimesh.instance_count = _rim_points.size()
	_growth.multimesh.instance_count = _growth_points.size()
	for i in rim_colors.size(): _rim.multimesh.set_instance_color(i, rim_colors[i])
	_growth_colors = growth_colors
	for i in growth_colors.size(): _growth.multimesh.set_instance_color(i, growth_colors[i])
	_burst()

func _burst() -> void:
	if Net.is_server(): return
	var points := PackedVector3Array()
	var colors := PackedColorArray()
	for i in range(0, _rim_points.size(), 3):
		points.append(global_transform * _rim_points[i])
		colors.append(Color.WHITE)
	Debris.burst_flash(get_parent(), points, colors, float(_style.voxel) * 0.65, 48,
		global_position, global_position.y, 0.35)

func despawn() -> void:
	if _closing: return
	_closing = true
	_close_opening = smoothstep(0.08, 0.65, _age)
	if is_instance_valid(target): target.enabled = false
	remove_from_group("dungeon_portals")

func _process(delta: float) -> void:
	_age += delta
	if remaining >= 0.0 and not _closing:
		remaining = maxf(0.0, remaining - delta)
		if remaining <= 0.0: despawn()
	var opening := smoothstep(0.08, 0.65, _age)
	var growth := smoothstep(0.45, 1.5, _age)
	var flash := (1.0 - smoothstep(0.0, 0.18, _age)) * 0.9
	if _closing:
		_close_age += delta
		growth *= 1.0 - smoothstep(0.0, 0.45, _close_age)
		opening = _close_opening * (1.0 - smoothstep(0.3, 1.05, _close_age))
		flash = smoothstep(0.85, 1.0, _close_age) * (1.0 - smoothstep(1.0, CLOSE_TIME, _close_age))
		if _close_age >= 0.95 and not _seal_burst:
			_seal_burst = true
			_burst()
		if _close_age >= CLOSE_TIME:
			hide()
			queue_free()
			return
	_update_suction(delta, opening)
	_surface.set_shader_parameter("opening", opening)
	_surface.set_shader_parameter("flash", flash)
	var voxel: float = _style.voxel
	for i in _rim_points.size():
		var p := _rim_points[i] * Vector3(opening, 1, opening)
		p.y = _rim_points[i].y * opening + sin(opening * PI) * (-0.25 if _closing else 0.35)
		_rim.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * voxel * maxf(0.001, opening)), p))
	for i in _growth_points.size():
		if _closing:
			_growth.multimesh.set_instance_color(i, _growth_colors[i].lerp(_style.root, 1.0 - growth))
		var p := _growth_points[i] * Vector3(opening, growth, opening)
		_growth.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(_growth_sizes[i] * maxf(0.001, growth)), p))

static func place(world: GameWorld, record: Dictionary) -> DungeonPortal:
	for child in world.get_children():
		if child is DungeonPortal and child.data.id == record.id: return child
	var portal := DungeonPortal.new(record)
	world.add_child(portal)
	return portal
