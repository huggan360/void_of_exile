extends Node3D
## Three visible voxel cascades and an arcing crown. Cubes recycle continuously.
@export var water_color := Color(0.32, 0.77, 0.91)
@export_range(0.1, 3.0) var flow_speed := 1.0
var _water := MultiMeshInstance3D.new()
var _time := 0.0
const COUNT := 256

func _ready() -> void:
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 0.125
	var material := StandardMaterial3D.new()
	material.albedo_color = water_color
	material.emission_enabled = true
	material.emission = water_color
	material.emission_energy_multiplier = 0.45
	cube.material = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = cube
	multi.instance_count = COUNT
	_water.multimesh = multi
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_water)
	_process(0)

func _process(delta: float) -> void:
	_time += delta * flow_speed
	for i in COUNT:
		_water.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, drop_position(i)))

func drop_position(i: int) -> Vector3:
	var tier := i % 4
	var angle := float((i / 4) % 16) / 16.0 * TAU
	var t := fposmod(_time * 0.7 + float(i / 64) * .25 + float(i % 7) * .017, 1.0)
	var r: float
	var y: float
	if tier == 0:
		r = t * 1.8
		y = 6.0 + 2.4 * t - 4.0 * t * t
	elif tier == 1:
		r = 1.65 + t * 1.2
		y = 4.65 + .6 * t - 2.5 * t * t
	elif tier == 2:
		r = 3.05 + t * 1.1
		y = 2.75 + .3 * t - 2.1 * t * t
	else:
		r = 4.3 + t * .6
		y = .82 + sin(t * PI) * .25
	var p := Vector3(cos(angle) * r, y, sin(angle) * r)
	p = (p * 8).round() / 8
	return p
