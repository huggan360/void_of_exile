class_name BlinkVoxels
extends MultiMeshInstance3D
## Actual creature-colored cubes spiral apart at departure and assemble at arrival.
const DURATION := 0.32
const MAX_CUBES := 180
var _points := PackedVector3Array()
var _center := Vector3.ZERO
var _reverse := false
var _age := 0.0

static func spawn(parent: Node, points: PackedVector3Array, colors: PackedColorArray,
		center: Vector3, voxel_size: float, reverse := false) -> void:
	if points.is_empty():
		return
	if Net.is_server():
		var sent := Net.thin_points(points, colors)
		Net.server.fx(parent, center, ["bv", sent[0], sent[1], center, voxel_size, reverse])
		return
	var effect := BlinkVoxels.new()
	parent.add_child(effect)
	effect._center = center
	effect._reverse = reverse
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * voxel_size
	effect.multimesh = MultiMesh.new()
	effect.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	effect.multimesh.use_colors = true
	effect.multimesh.mesh = cube
	var count := mini(MAX_CUBES, points.size())
	effect.multimesh.instance_count = count
	effect.material_override = VoxModel.glow_material()
	effect.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in count:
		var k := mini(points.size() - 1, i * points.size() / count)
		effect._points.append(points[k])
		effect.multimesh.set_instance_color(i, colors[k].lerp(Color("#b4efff"), 0.25))
	effect._draw_cubes()

func _process(delta: float) -> void:
	_age += delta
	if _age >= DURATION:
		queue_free()
		return
	_draw_cubes()

func _draw_cubes() -> void:
	var t := clampf(_age / DURATION, 0.0, 1.0)
	var scatter := 1.0 - t if _reverse else t
	for i in _points.size():
		var offset := _points[i] - _center
		var p := _center + offset.rotated(Vector3.UP, scatter * 1.8) * (1.0 + scatter * 0.7)
		p.y += scatter * (0.3 + float(i % 7) * 0.07)
		var s := maxf(0.015, 1.0 - scatter)
		var basis := Basis.from_euler(Vector3(scatter, scatter * 2.0, scatter)).scaled(Vector3.ONE * s)
		multimesh.set_instance_transform(i, Transform3D(basis, p))
