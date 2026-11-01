class_name DungeonFireflies
extends MultiMeshInstance3D
## Client-only, single-voxel flies. Twelve nearby lights at most, no shadows.
const LIMIT := 12
var _homes := PackedVector3Array()
var _phases := PackedFloat32Array()
var _lights: Array[OmniLight3D] = []
var _age := 0.0
var _selection_age := 1.0
var _near: Array[int] = []

func build(layout: DungeonLayout) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = layout.seed_value + 9017
	for i in layout.rooms.size():
		for k in 3:
			_homes.append(layout.point(i) + Vector3(rng.randf_range(-5, 5), rng.randf_range(0.8, 3.0), rng.randf_range(-5, 5)))
			_phases.append(rng.randf() * TAU)
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 0.065
	multimesh.mesh = cube
	multimesh.instance_count = LIMIT
	multimesh.visible_instance_count = 0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("d3f289")
	material.emission_enabled = true
	material.emission = Color("b7ee69")
	material.emission_energy_multiplier = 2.0
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in LIMIT:
		var light := OmniLight3D.new()
		light.light_color = Color("c6ed86")
		light.omni_range = 2.8
		light.omni_attenuation = 1.7
		light.shadow_enabled = false
		light.visible = false
		add_child(light)
		_lights.append(light)

func _process(delta: float) -> void:
	_age += delta
	_selection_age += delta
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	if _selection_age >= 0.5:
		_selection_age = 0.0
		_near.clear()
		var eye := to_local(camera.global_position)
		for i in _homes.size():
			if eye.distance_squared_to(_homes[i]) < 30.0 * 30.0: _near.append(i)
		_near.sort_custom(func(a: int, b: int) -> bool: return eye.distance_squared_to(_homes[a]) < eye.distance_squared_to(_homes[b]))
		_near.resize(mini(LIMIT, _near.size()))
		multimesh.visible_instance_count = _near.size()
		for i in LIMIT: _lights[i].visible = i < _near.size()
	for slot in _near.size():
		var index := _near[slot]
		var phase := _phases[index]
		var t := _age * 0.35 + phase
		var p := _homes[index] + Vector3(sin(t) * 1.8, sin(t * 1.7 + phase) * 0.4, cos(t * 0.8) * 1.4)
		multimesh.set_instance_transform(slot, Transform3D(Basis.IDENTITY, p))
		_lights[slot].position = p
		_lights[slot].light_energy = 0.45 + sin(_age * 1.8 + phase) * 0.12
