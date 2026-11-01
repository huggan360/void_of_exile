class_name Gravestone
extends StaticBody3D
## Where a character died: a voxel headstone with a cross and its name. It's
## solid (for players and enemies). On the dedicated server it breaks the
## breakable things it lands on and pushes players out of the way (see
## NetServer._grave); clients see it burst up out of the ground.

const VOXEL := 0.1125
const STONE := Color(0.46, 0.46, 0.5)
const STONE_DARK := Color(0.3, 0.3, 0.34)
const MOSS := Color(0.32, 0.42, 0.24)
const BLOOD := Color(0.6, 0.03, 0.05)
const RADIUS := 0.55  # its footprint
const CLEAR_RADIUS := 1.6  # breakable things this close break when it lands
const PUSH_RADIUS := 2.0  # players this close get pushed out of the way

var title := ""
var _rise: Node3D


static func place(parent: Node, pos: Vector3, p_title: String, fresh: bool) -> Gravestone:
	var g := Gravestone.new()
	g.title = p_title
	parent.add_child(g)
	g.global_position = pos
	g.rotation.y = randf_range(-0.25, 0.25) + PI
	if fresh:
		g._burst()
	return g


func _ready() -> void:
	collision_layer = Player.OBSTACLE_LAYER
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(RADIUS * 2.0, 1.2, 0.5)
	shape.shape = box
	shape.position.y = 0.6
	add_child(shape)
	_rise = Node3D.new()
	add_child(_rise)
	# Plinth, the upright stone with a rounded top, and a cross carved in.
	_box(Vector3(10, 2, 6), Vector3(0, 1, 0), STONE_DARK)
	_box(Vector3(8, 9, 3), Vector3(0, 6.5, 0), STONE)
	_box(Vector3(6, 1, 3), Vector3(0, 11.5, 0), STONE)
	_box(Vector3(4, 1, 3), Vector3(0, 12.5, 0), STONE)
	_box(Vector3(1, 5, 0.6), Vector3(0, 7.5, -1.6), STONE_DARK)
	_box(Vector3(3, 1, 0.6), Vector3(0, 8.5, -1.6), STONE_DARK)
	_box(Vector3(3, 1, 3.2), Vector3(-2.5, 2.5, 0), MOSS)
	_box(Vector3(2, 1, 1), Vector3(3.5, 2.2, -2), BLOOD)
	if title != "" and not Net.is_server():
		var label := Label3D.new()
		label.text = title
		label.font = UIStyle.bold()
		label.font_size = 30
		label.pixel_size = 0.006
		label.outline_size = 8
		label.modulate = Color(0.9, 0.86, 0.8)
		label.position = Vector3(0, 1.75, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_rise.add_child(label)


func _box(size_vox: Vector3, center_vox: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_vox * VOXEL
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	mesh.material = mat
	mi.mesh = mesh
	mi.position = center_vox * VOXEL
	_rise.add_child(mi)


## Fresh: red voxels scatter where the character fell, then the stone bursts
## up out of the ground in a puff of dust.
func _burst() -> void:
	var pts := PackedVector3Array()
	var cols := PackedColorArray()
	for i in 140:
		pts.append(global_position + Vector3(randf_range(-0.35, 0.35), randf_range(0.2, 1.6), randf_range(-0.35, 0.35)))
		cols.append(BLOOD.lerp(Color(0.85, 0.1, 0.1), randf()).darkened(randf() * 0.3))
	Debris.burst_points(get_parent(), pts, cols, 0.1, 140, global_position + Vector3.UP * 0.9, global_position.y, 1.2)
	var dust := PackedVector3Array()
	var dust_cols := PackedColorArray()
	for i in 60:
		var r := Vector2.from_angle(randf() * TAU) * randf_range(0.2, 1.2)
		dust.append(global_position + Vector3(r.x, 0.1, r.y))
		dust_cols.append(STONE.lerp(Color(0.55, 0.45, 0.35), randf()))
	Debris.burst_points(get_parent(), dust, dust_cols, 0.09, 60, global_position, global_position.y, 0.8)
	CameraShake.shake_at(global_position, 0.3, 14.0)
	var flash := OmniLight3D.new()
	flash.light_color = Color(1.0, 0.35, 0.3)
	flash.light_energy = 5.0
	flash.omni_range = 5.0
	flash.position.y = 1.0
	add_child(flash)
	var tw := create_tween().set_parallel()
	tw.tween_property(flash, "light_energy", 0.0, 0.8)
	_rise.position.y = -1.6
	_rise.scale = Vector3(0.8, 0.6, 0.8)
	tw.tween_property(_rise, "position:y", 0.0, 0.45).set_delay(0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_rise, "scale", Vector3.ONE, 0.45).set_delay(0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
