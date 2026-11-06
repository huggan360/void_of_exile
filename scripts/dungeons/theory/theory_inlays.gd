class_name TheoryInlays
extends RefCounted
## Batched native faces: ventilation, gauges, safety plates and lamp diffusers.
static var _quad: QuadMesh

static func attach(owner: Node3D,details: Array,material: ShaderMaterial) -> void:
	if details.is_empty(): return
	if _quad==null:
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.use_custom_data = true
	multi.mesh = _quad
	multi.instance_count = details.size()
	for i in details.size():
		var spec: Dictionary = details[i]
		multi.set_instance_transform(i,spec.frame)
		multi.set_instance_color(i,spec.color)
		multi.set_instance_custom_data(i,Color(float(spec.mode),float(spec.seed),float(spec.get("fault",0)),1))
	var node := MultiMeshInstance3D.new()
	node.name = "SurfaceInlays"
	node.multimesh = multi
	node.material_override = material
	node.visibility_range_end = 90
	owner.add_child(node)
