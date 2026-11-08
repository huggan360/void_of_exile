class_name PortalFracture
extends Node3D
## Geometry-derived voxels with real world positions, dimensions and lighting.
## No screen capture, depth quad, or screen-aligned particle lattice.
const FRAGMENT_LAYER := 1 << 18
var _camera: Camera3D
var _saved_mask := 0
var _saved_environment: Environment
var _saved_transform := Transform3D.IDENTITY
var _material := ShaderMaterial.new()
var _pieces: MultiMeshInstance3D
var _key: DirectionalLight3D
var _void: Environment
var _builder := PortalVoxelBuilder.new()
var _thread: Thread
var _progress := 0.0
var _assembling := false
var _focus := Vector3.ZERO
var _released := false
var _paused: Array[Dictionary] = []

func _ready() -> void:
	process_priority = 1000
	_material.shader = preload("res://shaders/portal_voxel_fracture.gdshader")
	set_process(false)

func capture(camera: Camera3D, assembling: bool) -> bool:
	clear()
	if not is_instance_valid(camera) or DisplayServer.get_name()=="headless": return false
	_camera = camera
	_saved_mask = camera.cull_mask
	_saved_environment = camera.environment
	_saved_transform = camera.global_transform
	_assembling = assembling
	_progress = 0.0
	_released = false
	_focus = _saved_transform.origin-_saved_transform.basis.z*30.0
	var ancestor: Node = camera.get_parent()
	while ancestor!=null:
		if ancestor is Player:
			_focus = ancestor.global_position+Vector3.UP
			break
		ancestor = ancestor.get_parent()
	set_process(true)
	var sources: Array = []
	var terrain := {}
	var pending: Array[Node] = [get_tree().current_scene]
	var deadline := Time.get_ticks_usec()+1800
	while not pending.is_empty():
		var next: Variant = pending.pop_back()
		if not is_instance_valid(next): continue  # freed while we walked the tree
		var node: Node = next
		if node==self or node is CanvasLayer or node is SubViewport or node.get_meta("portal_ignore",false): continue
		if node is GameWorld or node is Player:
			_paused.append({node=node,mode=node.process_mode})
			node.process_mode = Node.PROCESS_MODE_DISABLED
		if node is VoxelTerrain and node.get_parent() is GameWorld:
			terrain = _copy_terrain(node)
		elif node is MeshInstance3D and node.is_visible_in_tree() and (node.layers&_saved_mask)!=0:
			_append_source(sources,node,node.mesh,node.global_transform,Color.WHITE)
		elif node is MultiMeshInstance3D and node.is_visible_in_tree() and (node.layers&_saved_mask)!=0 and node.multimesh!=null:
			var multi: MultiMesh = node.multimesh
			var bounds := multi.custom_aabb
			if bounds.has_volume():
				var center: Vector3 = node.global_transform*bounds.get_center()
				var radius: float = (bounds.size*node.global_basis.get_scale().abs()).length()*0.5
				if center.distance_to(_focus)>85.0+radius: continue
			var count := multi.instance_count if multi.visible_instance_count<0 else multi.visible_instance_count
			for i in count:
				_append_source(sources,node,multi.mesh,node.global_transform*multi.get_instance_transform(i),multi.get_instance_color(i) if multi.use_colors else Color.WHITE)
				if i%64==63 and Time.get_ticks_usec()>deadline:
					await get_tree().process_frame
					deadline = Time.get_ticks_usec()+1800
		for child in node.get_children(): pending.append(child)
		if Time.get_ticks_usec()>deadline:
			await get_tree().process_frame
			deadline = Time.get_ticks_usec()+1800
	sources.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if a.actor!=b.actor: return a.actor
		return a.transform.origin.distance_squared_to(_focus)<b.transform.origin.distance_squared_to(_focus))
	_thread = Thread.new()
	if _thread.start(_builder.build.bind(sources,terrain,camera.get_camera_projection(),_saved_transform,_focus))!=OK:
		_thread = null
		clear()
		return false
	while _thread.is_alive(): await get_tree().process_frame
	var data: PackedFloat32Array = _thread.wait_to_finish()
	_thread = null
	if data.is_empty() or not is_instance_valid(_camera):
		clear()
		return false
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.use_custom_data = true
	multi.mesh = mesh
	multi.instance_count = data.size()/20
	multi.buffer = data
	multi.custom_aabb = AABB(_focus-Vector3.ONE*300.0,Vector3.ONE*600.0)
	_material.set_shader_parameter("capture_camera",_saved_transform)
	_material.set_shader_parameter("focus",_focus)
	_material.set_shader_parameter("assembling",assembling)
	_material.set_shader_parameter("progress",0.0)
	_material.set_shader_parameter("handoff",0.0)
	_pieces = MultiMeshInstance3D.new()
	_pieces.layers = FRAGMENT_LAYER
	_pieces.multimesh = multi
	_pieces.material_override = _material
	_pieces.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_pieces)
	var original := _saved_environment if _saved_environment!=null else camera.get_world_3d().environment
	_void = original.duplicate() as Environment if original!=null else Environment.new()
	_void.background_mode = Environment.BG_COLOR
	_void.background_color = Color("010207")
	_void.fog_enabled = false
	_void.volumetric_fog_enabled = false
	_void.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_void.ambient_light_color = Color("a3b6df")
	_void.ambient_light_energy = 0.65
	_void.glow_enabled = true
	_void.glow_intensity = 0.4
	_key = DirectionalLight3D.new()
	_key.light_cull_mask = FRAGMENT_LAYER
	_key.light_color = Color("c7dfff")
	_key.light_energy = 1.25
	_key.rotation_degrees = Vector3(-38,-30,0)
	add_child(_key)
	_camera.cull_mask = FRAGMENT_LAYER
	_camera.environment = _void
	return true

func _append_source(sources: Array,node: GeometryInstance3D,mesh: Mesh,t: Transform3D,tint: Color) -> void:
	if mesh==null or not (mesh is ArrayMesh or mesh is BoxMesh): return
	var center := t*mesh.get_aabb().get_center()
	var radius := (mesh.get_aabb().size*t.basis.get_scale().abs()).length()*0.5
	if center.distance_to(_focus)>85.0+radius or _camera.is_position_behind(center) and radius<2.0: return
	var mat: Material = node.material_override
	var glow := 0.0
	if mat is BaseMaterial3D:
		if mat.transparency!=BaseMaterial3D.TRANSPARENCY_DISABLED: return
		tint *= mat.albedo_color
		glow = 1.0 if mat.emission_enabled else 0.0
	elif mat is ShaderMaterial and mat.shader!=null:
		var shader_path: String = mat.shader.resource_path
		if "water" in shader_path or "portal" in shader_path or "glitch" in shader_path or "flame" in shader_path or "fire" in shader_path: return
		if "voxel_model" in shader_path:
			var strength: Variant = mat.get_shader_parameter("glow_strength")
			glow = float(strength) if strength is float or strength is int else 0.0
	var actor := false
	var parent: Node = node
	while parent!=null and parent!=get_tree().current_scene:
		if parent is CreatureModel or parent is ArcherModel or parent is ClassModel:
			actor = true
			break
		parent = parent.get_parent()
	sources.append({mesh=mesh,transform=t,tint=tint,glow=glow,actor=actor})

func _copy_terrain(terrain: VoxelTerrain) -> Dictionary:
	# Copy occupied blocks once on the main thread; the worker only scans its
	# private buffer. Include side walls and soil, not a flat height-map sheet.
	var world: GameWorld = terrain.get_parent()
	var center := _focus
	center.y = world.ground_height(center.x,center.z)
	var half := clampi(ceili(_camera.size*1.8),28,62) if _camera.projection==Camera3D.PROJECTION_ORTHOGONAL else 48
	var origin := Vector3i(floori(center.x)-half,maxi(-8,floori(center.y)-24),floori(center.z)-half)
	var height := mini(104,ceili(terrain.bounds.end.y)-origin.y)
	if height<4: return {}
	var buffer := VoxelBuffer.new()
	buffer.create(half*2+2,height,half*2+2)
	terrain.get_voxel_tool().copy(origin,buffer,1<<VoxelBuffer.CHANNEL_TYPE,false)
	return {buffer=buffer,origin=Vector3(origin)}

func set_progress(value: float) -> void:
	_progress = value
	_material.set_shader_parameter("progress",value)
	if _assembling and value>=0.9:
		# All cubes have settled before revealing live geometry. There are no
		# capture-only meshes in the world to accidentally reveal at handoff.
		_restore_camera(false)
		_material.set_shader_parameter("handoff",smoothstep(0.9,1.0,value))

func _process(_delta: float) -> void:
	if not is_instance_valid(_camera): return
	var orbit := (1.0-smoothstep(0.2,0.88,_progress))*0.10 if _assembling else smoothstep(0.05,0.85,_progress)*-0.12
	if _pieces==null: orbit = 0.0
	var turn := Basis(Vector3.UP,orbit)
	_camera.global_transform = Transform3D(turn*_saved_transform.basis,_focus+turn*(_saved_transform.origin-_focus))

func _restore_camera(final: bool = true) -> void:
	if is_instance_valid(_camera):
		_camera.cull_mask = _saved_mask | (FRAGMENT_LAYER if not final else 0)
		_camera.environment = _saved_environment
		if final: _camera.global_transform = _saved_transform
	_released = true

func clear() -> void:
	_restore_camera()
	_resume_actors()
	set_process(false)
	for node in [_pieces,_key]:
		if is_instance_valid(node):
			node.visible = false
			node.queue_free()
	_pieces = null
	_key = null
	_camera = null

func _resume_actors() -> void:
	for saved in _paused:
		if is_instance_valid(saved.node): saved.node.process_mode = saved.mode
	_paused.clear()

func _exit_tree() -> void:
	if _thread!=null:
		_thread.wait_to_finish()
		_thread = null
	_restore_camera()
	_resume_actors()
