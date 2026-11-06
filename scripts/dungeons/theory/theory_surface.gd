class_name TheorySurface
extends StaticBody3D
## Collidable, shootable industrial module. Rendering stays batched, but
## projectile impacts ripple and blink individual small voxels in world space.
static var _cube: BoxMesh
var world: TheoryWorld
var key := ""
var plan := {}
var material: ShaderMaterial
var visual: MultiMeshInstance3D
var broken := false
var opened := false
var gate_progress := 0.0
var hits := 0
var breakable := false
var _age := 10.0

func build(owner_world: TheoryWorld,data: Dictionary) -> void:
	world = owner_world
	plan = data
	key = str(data.id)
	set_meta("portal_ignore",bool(data.sky))
	name = key
	transform = data.frame
	collision_layer = Player.OBSTACLE_LAYER
	collision_mask = 0
	for spec: Dictionary in data.collision:
		var collider := CollisionShape3D.new()
		if spec.has("faces"):
			var skin := ConcavePolygonShape3D.new()
			skin.set_faces(spec.faces)
			collider.shape = skin
		else:
			var box := BoxShape3D.new()
			box.size = spec.size
			collider.shape = box
			collider.position = spec.at
		add_child(collider)
	for pane: Dictionary in data.get("glass",[]):
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = pane.size
		collider.shape = shape
		collider.position = pane.at
		collider.basis = pane.get("basis",Basis.IDENTITY)
		add_child(collider)
	if world.server_build or Net.is_server():
		set_process(false)
		return
	if _cube==null:
		_cube = BoxMesh.new()
		_cube.size = Vector3.ONE
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.use_custom_data = true
	multi.mesh = _cube
	multi.instance_count = (data.data as PackedFloat32Array).size()/20
	multi.buffer = data.data
	multi.custom_aabb = (data.bounds as AABB).grow(10.0 if data.get("unstable",false) else 0.5)
	visual = MultiMeshInstance3D.new()
	visual.multimesh = multi
	visual.visibility_range_end = float(data.far)
	visual.visibility_range_end_margin = 15.0 if data.far>0 else 0.0
	visual.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if data.sky else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	material = ShaderMaterial.new()
	material.shader = preload("res://shaders/theory_surface.gdshader")
	material.set_shader_parameter("surface_up",transform.basis.y)
	material.set_shader_parameter("sky",data.sky)
	var finish := 2.0 if key.begins_with("wreck_") else 1.0 if key.begins_with("aurora_") else 0.0
	if key.begins_with("electrical_"): finish = 2.0 if world.zone_at(data.frame.origin)=="wreck" else 1.0
	material.set_shader_parameter("ship_material",finish)
	material.set_shader_parameter("instability",1.0 if data.get("unstable",false) else 0.0)
	visual.material_override = material
	add_child(visual)
	if data.has("vertices"):
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = data.vertices
		arrays[Mesh.ARRAY_NORMAL] = data.normals
		arrays[Mesh.ARRAY_COLOR] = data.vertex_colors
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		var skin := MeshInstance3D.new()
		skin.mesh = mesh
		skin.material_override = material
		skin.visibility_range_end = float(data.far)
		add_child(skin)
	if data.has("glass"): _glass(data.glass)
	if data.has("round_pipes"): TheoryRoundDetails.attach(self,data.round_pipes)
	if data.has("fittings"): TheoryRoundDetails.attach_fittings(self,data.fittings)
	if data.has("inlays"): TheoryInlays.attach(self,data.inlays,world.inlay_material())
	set_process(false)

func _glass(panes: Array) -> void:
	var glass := StandardMaterial3D.new()
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color = Color(0.12,0.22,0.32,0.10)
	glass.roughness = 0.15
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	for pane: Dictionary in panes:
		var mesh := BoxMesh.new()
		mesh.size = pane.size
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = glass
		node.position = pane.at
		node.basis = pane.get("basis",Basis.IDENTITY)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)

func take_hit(at: Vector3,_direction: Vector3,_damage: int) -> void:
	if broken: return
	flash(at)
	if Net.is_client(): Net.client.send_action("theory",["impact",key,at])
	else: world.impact(key,at)

func flash(at: Vector3) -> void:
	if material==null: return
	_age = 0.0
	material.set_shader_parameter("impact",Vector4(at.x,at.y,at.z,0.0))
	material.set_shader_parameter("impact_age",0.0)
	set_process(true)

func _process(delta: float) -> void:
	_age += delta
	material.set_shader_parameter("impact_age",_age)
	if _age>2.5: set_process(false)

func bend_arena(factor: float) -> void:
	for child in get_children():
		if child is CollisionShape3D:
			var radius_sq := Vector2(child.position.x,child.position.z).length_squared()
			child.position.y = radius_sq*factor-0.25
	if visual==null: return
	var data: PackedFloat32Array = plan.data.duplicate()
	for i in data.size()/20:
		var offset := i*20
		var radius_sq := data[offset+3]*data[offset+3]+data[offset+11]*data[offset+11]
		data[offset+7] += radius_sq*(factor-0.006)
	visual.multimesh.buffer = data

func open_gate() -> void:
	set_gate_progress(1.0)

## The shared server clock drives every viewer's door pose, including late joins.
func set_gate_progress(value: float) -> void:
	gate_progress = clampf(value,0.0,1.0)
	opened = gate_progress>=0.999
	collision_layer = 0 if opened else Player.OBSTACLE_LAYER
	if visual!=null:
		var ease := smoothstep(0.0,1.0,gate_progress)
		visual.position.y = 5.35*ease
		visual.scale.y = lerpf(1.0,0.02,ease)

func shatter() -> void:
	if broken: return
	broken = true
	collision_layer = 0
	if visual==null: return
	var points := PackedVector3Array()
	var colors := PackedColorArray()
	for i in 24:
		points.append(global_position+Vector3(randf_range(-1.1,1.1),randf_range(0.3,2.3),randf_range(-0.1,0.1)))
		colors.append(Color("8b9eaf"))
	Debris.burst_flash(get_parent(),points,colors,0.09,5.0,global_position,global_position.y,0.7)
	visual.hide()
