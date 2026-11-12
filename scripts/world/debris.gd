class_name Debris
extends MultiMeshInstance3D
## A burst of loose voxels taken from an obstacle or a creature. They fly
## outward, bounce on the ground, then shrink away. One MultiMesh per burst,
## freed when done.

const GRAVITY := 20.0
const LIFETIME_MIN := 1.8
const LIFETIME_MAX := 3.0
const SHRINK_TIME := 0.8
const BOUNCE := 0.35
const GROUND_FRICTION := 0.7

var _pos := PackedVector3Array()
var _vel := PackedVector3Array()
var _rot := PackedVector3Array()
var _spin := PackedVector3Array()
var _life := PackedFloat32Array()
var _ground_y := 0.0
var _voxel_size := ObstacleLibrary.VOXEL_SIZE
var _white_flash := false
var _flash_age := 0.0
var _original_colors := PackedColorArray()


## Spawns up to `count` voxels of `obstacle`, flung away from `from`.
static func burst(parent: Node, obstacle: Obstacle, count: int, from: Vector3) -> void:
	var debris := Debris.new()
	parent.add_child(debris)
	debris._start(obstacle, count, from)


## Bursts any set of voxels (world positions and colors), e.g. a creature's
## body when it dies. life_scale shortens (or lengthens) how long they last.
static func burst_points(parent: Node, points: PackedVector3Array, colors: PackedColorArray,
		voxel_size: float, count: int, from: Vector3, ground_y: float, life_scale := 1.0) -> void:
	if points.is_empty():
		return
	if Net.is_server():
		var sent := Net.thin_points(points, colors)
		Net.server.fx(parent, from, ["db", sent[0], sent[1], voxel_size, mini(count, sent[0].size()), from, ground_y, life_scale])
		return
	var debris := Debris.new()
	parent.add_child(debris)
	debris._start_points(points, colors, voxel_size, count, from, ground_y, false, life_scale)


## Presentation-only impact burst: white-hot chips recover their source colors.
## CreatureModel.hit_voxels is recorded for clients, so no extra network event.
static func burst_flash(parent: Node, points: PackedVector3Array, colors: PackedColorArray,
		voxel_size: float, count: int, from: Vector3, ground_y: float, life_scale := .45) -> void:
	if points.is_empty(): return
	var debris := Debris.new()
	debris.top_level = true
	debris._white_flash = true
	parent.add_child(debris)
	debris.global_transform = Transform3D.IDENTITY
	debris._start_points(points,colors,voxel_size,count,from,ground_y,false,life_scale)


func _start(obstacle: Obstacle, count: int, from: Vector3) -> void:
	var prefab := obstacle.prefab
	var xform := obstacle.global_transform
	var points := PackedVector3Array()
	var colors := PackedColorArray()
	for k in prefab.voxel_positions.size():
		points.append(xform * prefab.voxel_positions[k])
		colors.append(prefab.slot_color(prefab.voxel_slots[k], obstacle.biome))
	# Chips from a hit start where the arrow struck.
	_start_points(points, colors, prefab.voxel_size, count, from, xform.origin.y, count < 20)


func _start_points(points: PackedVector3Array, colors: PackedColorArray, voxel_size: float, count: int,
		from: Vector3, ground_y: float, chips: bool, life_scale := 1.0) -> void:
	_voxel_size = voxel_size
	_ground_y = ground_y
	var total := points.size()
	count = mini(count, total)

	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * _voxel_size
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = cube
	multimesh.instance_count = count
	material_override = VoxModel.material()
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var small := chips
	for i in count:
		var k := randi() % total if small or count < total else i
		var p := points[k]
		if small:
			p = from + Vector3(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2), randf_range(-0.2, 0.2))
		var out := (p - from)
		out.y = 0.0
		out = out.normalized() if out.length() > 0.01 else Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		_pos.append(p)
		_vel.append(out * randf_range(1.5, 5.0) + Vector3.UP * randf_range(2.0, 6.5))
		_rot.append(Vector3(randf(), randf(), randf()) * TAU)
		_spin.append(Vector3(randf_range(-8, 8), randf_range(-8, 8), randf_range(-8, 8)))
		_life.append(randf_range(LIFETIME_MIN, LIFETIME_MAX) * (0.5 if small else 1.0) * life_scale)
		_original_colors.append(colors[k])
		multimesh.set_instance_color(i,Color.WHITE if _white_flash else colors[k])
	_update_instances()


func _physics_process(delta: float) -> void:
	if _white_flash:
		_flash_age += delta
		var blend := clampf(_flash_age/.22,0,1)
		for i in _original_colors.size(): multimesh.set_instance_color(i,Color.WHITE.lerp(_original_colors[i],blend))
		if blend>=1: _white_flash = false
	var alive := 0
	for i in _pos.size():
		if _life[i] <= 0.0:
			continue
		alive += 1
		_life[i] -= delta
		_vel[i].y -= GRAVITY * delta
		_pos[i] += _vel[i] * delta
		_rot[i] += _spin[i] * delta
		var floor_y := _ground_y + _voxel_size * 0.5
		if _pos[i].y < floor_y:
			_pos[i].y = floor_y
			_vel[i] = Vector3(_vel[i].x * GROUND_FRICTION, -_vel[i].y * BOUNCE, _vel[i].z * GROUND_FRICTION)
			_spin[i] *= 0.6
	if alive == 0:
		queue_free()
		return
	_update_instances()


func _update_instances() -> void:
	for i in _pos.size():
		var scale_factor := clampf(_life[i] / SHRINK_TIME, 0.0, 1.0)
		var basis := Basis.from_euler(_rot[i]).scaled(Vector3.ONE * scale_factor)
		multimesh.set_instance_transform(i, Transform3D(basis, _pos[i]))
