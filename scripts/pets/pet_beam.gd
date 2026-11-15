class_name PetBeam
extends Node3D
## One short additive ribbon and two tiny voxel flashes. No lights or collision.
const LIFE := 0.35
var _left := LIFE
var _material: StandardMaterial3D

static func spawn(parent: Node3D, start: Vector3, end: Vector3, ability: String) -> PetBeam:
	var beam := PetBeam.new()
	parent.add_child(beam)
	beam.global_position = start
	beam._build(end - start, PetDefs.ABILITIES.get(ability, PetDefs.ABILITIES.regen).color)
	return beam

func _build(end: Vector3, color: Color) -> void:
	_material = PetFollower.light_material(color)
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.no_depth_test = false
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _material)
	var direction := end.normalized()
	var side := direction.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.1: side = Vector3.RIGHT
	var up := direction.cross(side).normalized()
	var points: Array[Vector3] = [Vector3.ZERO]
	for i in range(1, 7):
		points.append(end * float(i) / 7.0 + side * randf_range(-0.13, 0.13) + up * randf_range(-0.1, 0.1))
	points.append(end)
	for i in points.size() - 1:
		for width in [side * 0.025, up * 0.025]:
			for vertex: Vector3 in [points[i]-width, points[i]+width, points[i+1]+width,
				points[i]-width, points[i+1]+width, points[i+1]-width]: mesh.surface_add_vertex(vertex)
	mesh.surface_end()
	var ribbon := MeshInstance3D.new()
	ribbon.mesh = mesh
	add_child(ribbon)
	for point in [Vector3.ZERO, end]:
		var flash := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE * 0.12
		flash.mesh = cube
		flash.material_override = _material
		flash.position = point
		add_child(flash)

func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	if _material:
		var color := _material.albedo_color
		color.a = _left / LIFE
		_material.albedo_color = color
