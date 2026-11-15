class_name PetFollower
extends Node3D
## Noncolliding client visual. Yard residents can set follow_target to null,
## move this node themselves, and call animate_gait(speed, delta).
var pet := {}
var follow_target: Node3D
var world: GameWorld
var model: Node3D
var _pose := Node3D.new()
var _time := randf() * TAU
var _idle_left := 4.0 + randf() * 6.0
var _cute := 0.0
var _heading := 0.0
static var _shimmer_shader: Shader
var _motes: Array[MeshInstance3D] = []
var _halo: MeshInstance3D

func _init(data: Dictionary = {}, target: Node3D = null, place: GameWorld = null) -> void:
	pet = data.duplicate(true)
	follow_target = target
	world = place

func _ready() -> void:
	add_child(_pose)
	model = make_model(str(pet.get("species", "duck")))
	_pose.add_child(model)
	var rarity := str(pet.get("rarity", "common"))
	if rarity != "common":
		var color: Color = PetDefs.RARITY_COLORS.get(rarity, Color.WHITE)
		if model is CreatureModel: (model as CreatureModel).set_glow(0.12 if rarity == "rare" else 0.2)
		var shimmer := ShaderMaterial.new()
		if _shimmer_shader == null:
			_shimmer_shader = Shader.new()
			_shimmer_shader.code = "shader_type spatial; render_mode unshaded, blend_add, depth_draw_never; uniform vec4 tint : source_color; void fragment() { ALBEDO = tint.rgb; ALPHA = 0.045 + 0.025 * sin(TIME * 2.0 + VERTEX.y * 5.0); }"
		shimmer.shader = _shimmer_shader
		shimmer.set_shader_parameter("tint", color)
		for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false): part.material_overlay = shimmer
		for i in 5:
			var mote := MeshInstance3D.new()
			var cube := BoxMesh.new()
			cube.size = Vector3.ONE * 0.035
			mote.mesh = cube
			mote.material_override = light_material(color)
			add_child(mote)
			_motes.append(mote)
		if rarity == "divine":
			_halo = MeshInstance3D.new()
			var ring := TorusMesh.new()
			ring.inner_radius = 0.21
			ring.outer_radius = 0.25
			ring.rings = 16
			ring.ring_segments = 6
			_halo.mesh = ring
			_halo.material_override = light_material(color)
			add_child(_halo)
	if is_instance_valid(follow_target): global_position = follow_target.global_position

static func light_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	return material

## Use the authored voxel rig when available. Missing art is a small voxel friend.
static func make_model(species: String) -> Node3D:
	if FileAccess.file_exists("res://creatures/pet_%s/rig.json" % species):
		return CreatureModel.new("pet_" + species)
	var root := Node3D.new()
	var h := float(PetDefs.SPECIES.get(species, {}).get("height", 0.5))
	for entry in [[Vector3(0, h * 0.4, 0), Vector3(h * 0.7, h * 0.8, h * 0.65), Color("dec78b")],
		[Vector3(-h * 0.17, h * 0.58, -h * 0.34), Vector3.ONE * h * 0.09, Color("302d40")],
		[Vector3(h * 0.17, h * 0.58, -h * 0.34), Vector3.ONE * h * 0.09, Color("302d40")]]:
		var mesh := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = entry[1]
		mesh.mesh = cube
		mesh.position = entry[0]
		var material := StandardMaterial3D.new()
		material.albedo_color = entry[2]
		mesh.material_override = material
		root.add_child(mesh)
	return root

func _process(delta: float) -> void:
	var speed := 0.0
	if is_instance_valid(follow_target) and is_instance_valid(world):
		var facing := follow_target.global_basis
		var actor_model: Variant = follow_target.get("model")
		if actor_model is Node3D: facing = actor_model.global_basis
		var goal := follow_target.global_position + facing.z * 1.45 + facing.x * 0.7
		var offset := goal - global_position
		var distance := offset.length()
		if distance > 25.0:
			global_position = goal
		elif distance > 0.12:
			var step := minf(distance, (3.0 + distance * 2.8) * delta)
			if pet.get("species") == "lilyhop" and distance < 5.0 and sin(_time * 4.95) < 0.0: step = 0.0
			global_position += offset.normalized() * step
			speed = minf(1.0, step / maxf(delta, 0.001) / 5.0)
		var frame := Transform3D.IDENTITY
		if world is SpatialWorld: frame = (world as SpatialWorld).surface_frame(global_position)
		var local_offset := frame.basis.inverse() * offset
		if Vector2(local_offset.x, local_offset.z).length_squared() > 0.005:
			_heading = lerp_angle(_heading, atan2(-local_offset.x, -local_offset.z), minf(1.0, delta * 9.0))
		global_basis = frame.basis * Basis(Vector3.UP, _heading)
		if world is SpatialWorld: global_position = frame.origin
		else: global_position.y = world.ground_height(global_position.x, global_position.z)
	animate_gait(speed, delta)

func animate_gait(speed: float, delta: float) -> void:
	if not is_instance_valid(model): return
	_time += delta
	_idle_left -= delta
	if _idle_left <= 0.0 and speed < 0.1:
		_cute = 0.65
		_idle_left = 5.0 + randf() * 7.0
	_cute = maxf(0.0, _cute - delta)
	var gait := str(PetDefs.SPECIES.get(pet.get("species", "duck"), {}).get("gait", "waddle"))
	var moving := clampf(speed, 0.0, 1.0)
	var phase := _time * (9.0 if gait != "plod" else 5.0)
	var bob := sin(_time * 2.3) * 0.012
	var rock := 0.0
	var pitch := 0.0
	var stretch := 0.0
	match gait:
		"waddle":
			rock = sin(phase) * 0.16 * moving
			bob += absf(sin(phase)) * 0.035 * moving
		"hop": bob += absf(sin(phase * 0.75)) * 0.25 * moving
		"leap":
			var leap := maxf(0.0, sin(phase * 0.55))
			bob += leap * 0.48 * moving
			pitch = cos(phase * 0.55) * leap * 0.2 * moving
		"squash":
			bob += absf(sin(phase * 0.7)) * 0.19 * moving
			stretch = cos(phase * 1.4) * 0.18 * moving
		"trot": bob += absf(sin(phase * 1.4)) * 0.055 * moving
		"flap":
			bob += 0.9 + sin(_time * 5.0) * 0.1
			rock = sin(_time * 5.0) * 0.06
		"glide":
			bob += 1.05 + sin(_time * 2.0) * 0.12
			rock = sin(_time * 1.7) * 0.09
		"float": bob += 0.55 + sin(_time * 2.0) * 0.14
		"pulse":
			bob += 0.8 + sin(_time * 2.6) * 0.13
			stretch = sin(_time * 2.6) * 0.1
		"swim":
			bob += 0.8 + sin(_time * 1.8) * 0.13
			pitch = sin(_time * 1.8) * 0.12
		"plod":
			bob += absf(sin(phase)) * 0.018 * moving
			rock = sin(phase) * 0.055 * moving
		"stomp":
			bob += absf(sin(phase * 0.8)) * 0.065 * moving
			rock = sin(phase * 0.8) * 0.1 * moving
		"wiggle": rock = sin(phase) * 0.12 * moving
	_pose.position.y = bob + sin(_cute / 0.65 * PI) * 0.16
	_pose.rotation = Vector3(pitch, sin(_cute / 0.65 * TAU) * 0.22, rock)
	_pose.scale = Vector3(1.0 - stretch * 0.5, 1.0 + stretch, 1.0 - stretch * 0.5)
	if model is CreatureModel: (model as CreatureModel).animate(moving, delta)
	var height := float(PetDefs.SPECIES.get(pet.get("species", "duck"), {}).get("height", 0.5))
	for i in _motes.size():
		var phase_mote := _time * 1.4 + float(i) * TAU / _motes.size()
		_motes[i].position = Vector3(cos(phase_mote) * 0.38, bob + height * 0.4 + sin(phase_mote * 1.6) * 0.3, sin(phase_mote) * 0.38)
		_motes[i].scale = Vector3.ONE * (0.4 + 0.6 * absf(sin(phase_mote * 2.0)))
	if _halo:
		_halo.position.y = bob + height + 0.16
		_halo.rotation = Vector3(0.08, _time * 0.4, 0.12)

func beam_origin() -> Vector3:
	return _pose.global_position + global_basis.y * float(PetDefs.SPECIES.get(pet.get("species", "duck"), {}).get("height", 0.5)) * 0.6
