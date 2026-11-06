class_name QuestTrail
extends MeshInstance3D
## Thin ground-following, forward-flowing streaks. No particles or lights are
## spawned, and passed segments disappear when QuestGuide consumes the path.
const VISIBLE_DISTANCE := 58.0
const SAMPLE_SPACING := 0.35
const HALF_WIDTH := 0.09
const HEIGHT := 0.11
const OVERLAP_DISTANCE := 0.48

var _main := PackedVector3Array()
var _side := PackedVector3Array()
var _player := Vector3.ZERO
var _ground := Callable()
var _mesh := ImmediateMesh.new()
var _building := false
var main_color := Color("f3cb58")
var side_color := Color("7dde88")


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh = _mesh
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/quest_trail.gdshader")
	material_override = mat
	if get_parent() is GameWorld: _ground = get_parent().ground_height


func set_routes(main: PackedVector3Array, side: PackedVector3Array, player: Vector3) -> void:
	_main = main
	_side = side
	_player = player
	_mesh.clear_surfaces()
	_building = false
	if main.size() < 2 and side.size() < 2: return
	_add_route(side, side_color, true)
	_add_route(main, main_color, false)
	if _building: _mesh.surface_end()


static func overlaps_main(point: Vector3, main: PackedVector3Array) -> bool:
	var p := Vector2(point.x, point.z)
	var distance := 0.0
	for i in range(main.size() - 1):
		distance += main[i].distance_to(main[i + 1])
		if distance > VISIBLE_DISTANCE + 4.0: break
		var a := Vector2(main[i].x, main[i].z)
		var b := Vector2(main[i + 1].x, main[i + 1].z)
		if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) < OVERLAP_DISTANCE:
			return true
	return false


func _add_route(path: PackedVector3Array, tint: Color, side: bool) -> void:
	var distance := 0.0
	for i in range(path.size() - 1):
		var a := path[i]
		var b := path[i + 1]
		var length := a.distance_to(b)
		if length < 0.001: continue
		var count := maxi(1, ceili(length / SAMPLE_SPACING))
		for step in count:
			var from := a.lerp(b, float(step) / count)
			var to := a.lerp(b, float(step + 1) / count)
			var mid := (from + to) * 0.5
			var along := distance + length * step / count
			if along > VISIBLE_DISTANCE: return
			if mid.distance_to(_player) < 0.9: continue
			if side and overlaps_main(mid, _main): continue
			var alpha := 0.22 * (1.0 - smoothstep(VISIBLE_DISTANCE * 0.55, VISIBLE_DISTANCE, along))
			_emit_segment(from, to, along, along + length / count, Color(tint, alpha))
		distance += length


func _emit_segment(a: Vector3, b: Vector3, start: float, end: float, tint: Color) -> void:
	if not _building:
		_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		_building = true
	var direction := Vector2(b.x - a.x, b.z - a.z).normalized()
	var side := Vector3(-direction.y, 0, direction.x) * HALF_WIDTH
	var points: Array[Vector3] = [a - side, a + side, b - side, b + side]
	for i in points.size():
		var p := points[i]
		p.y = (_ground.call(p.x, p.z) if _ground.is_valid() else p.y) + HEIGHT
		points[i] = p
	var uv := [Vector2(start, 0), Vector2(start, 1), Vector2(end, 0), Vector2(end, 1)]
	for i in [0, 1, 2, 2, 1, 3]:
		_mesh.surface_set_color(tint)
		_mesh.surface_set_normal(Vector3.UP)
		_mesh.surface_set_uv(uv[i])
		_mesh.surface_add_vertex(points[i])
