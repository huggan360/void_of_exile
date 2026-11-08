class_name SpaceHelmet
extends Node
## Space gear for everyone in a space world (the Astral Reach and the Theory
## of Everything): while floating in open space, a jetpack on the back (fitted
## to the head's size, from the body voxels) whose nozzles burn when thrusting. Added to the world; dresses the local player and every remote
## player it finds, and undresses them when the world goes.
const HELMET := "space_helmet"
const JETPACK := "space_jetpack"
## Body rows from here up are the head (arms attach at row 9 on every class).
const NECK_ROW := 9
var world: Node3D
static var _heads := {}  # body.vox path -> AABB (voxel units)
static var _brass: StandardMaterial3D
static var _tank: StandardMaterial3D
static var _bulb: StandardMaterial3D
static var _fire: ShaderMaterial

func _process(delta: float) -> void:
	var actors: Array = []
	var local: Node3D = world.get("local_player") if is_instance_valid(world) else null
	if is_instance_valid(local): actors.append(local)
	actors.append_array(get_tree().get_nodes_in_group("remote_players"))
	for actor: Node3D in actors:
		var model: Node3D = actor.get("model")
		if not is_instance_valid(model): continue
		# The jetpack shows out in open space; the nozzles burn while thrusting.
		var out := world is SpaceWorld and (world as SpaceWorld).zone_at(actor.global_position)=="void"
		var pack := _jetpack(model, out)
		if pack:
			var thrust: bool = bool(actor.get_meta("jet_on", false)) if actor==local else actor.get_meta("jet_speed", 0.0)>0.5
			if actor!=local:
				var last: Vector3 = actor.get_meta("jet_last", actor.global_position)
				actor.set_meta("jet_speed", last.distance_to(actor.global_position)/maxf(delta, 0.001))
				actor.set_meta("jet_last", actor.global_position)
			for flame: Node3D in pack.get_meta("flames"):
				flame.visible = thrust
				flame.scale = Vector3(1, 1, 1)*(0.85+0.3*sin(Time.get_ticks_msec()/40.0+flame.position.x*9.0))

func _exit_tree() -> void:
	var local: Node3D = world.get("local_player") if is_instance_valid(world) else null
	if is_instance_valid(local): undress(local.get("model"))
	for remote in get_tree().get_nodes_in_group("remote_players"):
		undress(remote.get("model"))

static func undress(model: Variant) -> void:
	if not model is Node3D or not is_instance_valid(model): return
	var body := _body(model as Node3D)
	if body==null: return
	for name in [HELMET, JETPACK]:
		var node := body.get_node_or_null(name)
		if node: node.queue_free()

## The node the body voxels live under (voxel units), or null.
static func _body(model: Node3D) -> Node3D:
	var rig := model.get_node_or_null("Rig")
	if rig==null: rig = model.find_child("Rig", true, false)
	return rig.get_node_or_null("Body") as Node3D if rig else null

## The head's box in body voxel units, from the class's body.vox.
static func _head_box(model: Node3D) -> AABB:
	var folder := model.scene_file_path.get_base_dir()
	if folder=="" and model.get_child_count()>0: folder = model.get_child(0).scene_file_path.get_base_dir()
	var path := folder+"/body.vox"
	if _heads.has(path): return _heads[path]
	var box := AABB(Vector3(4, NECK_ROW, 5), Vector3(8, 7, 6))
	if ResourceLoader.exists(path) or FileAccess.file_exists(path):
		var data := VoxModel.load_vox(path)
		if not data.is_empty():
			var buf: VoxelBuffer = data[0]
			var size := buf.get_size()
			var lo := Vector3(INF, INF, INF)
			var hi := -lo
			for y in range(NECK_ROW, size.y):
				for z in size.z:
					for x in size.x:
						if buf.get_voxel(x, y, z, VoxelBuffer.CHANNEL_COLOR)==0: continue
						lo = lo.min(Vector3(x, y, z))
						hi = hi.max(Vector3(x+1, y+1, z+1))
			if lo.x<INF: box = AABB(lo, hi-lo)
	_heads[path] = box
	return box

## The jetpack on the back (+Z, the character faces -Z), shown or hidden.
static func _jetpack(model: Node3D, show: bool) -> Node3D:
	var body := _body(model)
	if body==null: return null
	var pack := body.get_node_or_null(JETPACK) as Node3D
	if pack==null:
		if not show: return null
		_materials()
		pack = Node3D.new()
		pack.name = JETPACK
		body.add_child(pack)
		var head := _head_box(model)
		var back := head.end.z+0.2
		var flames: Array[Node3D] = []
		for side in [-1.0, 1.0]:
			var x: float = 8.0+side*2.1
			_add_box(pack, Vector3(x, 7.0, back+1.6), Vector3(2.6, 6.5, 2.6), _tank)
			for y in [5.0, 9.0]: _add_box(pack, Vector3(x, y, back+1.6), Vector3(2.9, 0.6, 2.9), _brass)
			_add_box(pack, Vector3(x, 10.6, back+1.6), Vector3(1.6, 0.8, 1.6), _brass)
			_add_box(pack, Vector3(x, 3.3, back+1.6), Vector3(1.8, 1.0, 1.8), _brass)
			var flame := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.8
			cone.height = 4.0
			flame.mesh = cone
			flame.material_override = _fire
			flame.position = Vector3(x, 0.8, back+1.6)
			flame.rotation.x = PI
			flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			flame.visible = false
			pack.add_child(flame)
			flames.append(flame)
		_add_box(pack, Vector3(8.0, 7.5, back+0.4), Vector3(6.0, 4.0, 0.6), _brass)
		_add_box(pack, Vector3(8.0, 8.4, back+2.95), Vector3(0.7, 0.7, 0.2), _bulb)
		pack.set_meta("flames", flames)
	pack.visible = show
	return pack if show else null

static func _add_box(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)

static func _materials() -> void:
	if _brass!=null: return
	_brass = StandardMaterial3D.new()
	_brass.albedo_color = Color("d3a34e")
	_brass.metallic = 0.6
	_brass.roughness = 0.35
	_tank = StandardMaterial3D.new()
	_tank.albedo_color = Color("6a8a7a")
	_tank.metallic = 0.4
	_tank.roughness = 0.45
	_bulb = StandardMaterial3D.new()
	_bulb.albedo_color = Color("85efac")
	_bulb.emission_enabled = true
	_bulb.emission = Color("85efac")
	_bulb.emission_energy_multiplier = 3.0
	_fire = ShaderMaterial.new()
	_fire.shader = preload("res://shaders/space_magic.gdshader")
	_fire.set_shader_parameter("strength", 0.4)
