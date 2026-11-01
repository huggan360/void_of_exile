class_name XpOrbs
extends Node3D
## Glowing experience voxels dropped by defeated enemies and broken objects.
## They burst out, bounce, then drift toward the player once they're close
## and give XP when collected. The orbs are the server's (GameServer.drop_xp):
## this draws the ones in the local player's realm, and collecting one asks
## the server for its XP.

const GRAVITY := 14.0
const MAGNET_RADIUS := 4.5
const COLLECT_RADIUS := 0.7
const MAGNET_DELAY := 0.5  # seconds before a new orb can be pulled in
const LIFETIME := 45.0
const COLOR := Color(0.45, 1.0, 0.6)

var player: Player
## The realm shown (orbs dropped elsewhere aren't drawn).
var realm_id := ""
## func(x, z) -> ground height; set for the current world.
var ground_height := Callable()

var _orbs: Array[Dictionary] = []
var _mesh: Mesh


func _ready() -> void:
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 0.13
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/fire_voxel.gdshader")
	mat.set_shader_parameter("brightness", 3.0)
	cube.material = mat
	var arrays := cube.get_mesh_arrays()
	var colors := PackedColorArray()
	colors.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	colors.fill(COLOR)
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, mat)
	_mesh = mesh
	GameServer.xp_dropped.connect(_on_xp_dropped)


## The server dropped orbs ([{id, value}]) at `pos`.
func _on_xp_dropped(p_realm_id: String, pos: Vector3, orbs: Array) -> void:
	if p_realm_id != realm_id:
		return
	for orb: Dictionary in orbs:
		var mi := MeshInstance3D.new()
		mi.mesh = _mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		mi.global_position = pos
		var out := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU) * randf_range(1.0, 3.5)
		_orbs.append({node = mi, vel = out + Vector3.UP * randf_range(3.0, 6.0), id = orb.id, age = 0.0})


func clear() -> void:
	for o in _orbs:
		o.node.queue_free()
	_orbs.clear()


func _physics_process(delta: float) -> void:
	if player == null:
		return
	var target := player.global_position + Vector3.UP * 0.9
	for o in _orbs:
		o.age += delta
		var node: MeshInstance3D = o.node
		var pos := node.global_position
		var to := target - pos
		var dist := to.length()
		if dist < COLLECT_RADIUS and o.age > 0.25:
			GameServer.collect_xp(player.player_id, o.id)
			o.age = LIFETIME + 1.0  # collected
			continue
		if o.age > MAGNET_DELAY and dist < MAGNET_RADIUS and not player.frozen:
			# Pulled in, harder the closer it gets.
			var pull := lerpf(6.0, 26.0, 1.0 - dist / MAGNET_RADIUS)
			o.vel = o.vel.lerp(to.normalized() * pull, minf(1.0, delta * 6.0))
		else:
			o.vel.y -= GRAVITY * delta
			o.vel.x *= 1.0 - delta * 1.5
			o.vel.z *= 1.0 - delta * 1.5
		pos += o.vel * delta
		var floor_y: float = (ground_height.call(pos.x, pos.z) if ground_height.is_valid() else pos.y - 1.0) + 0.15
		if pos.y < floor_y and dist >= MAGNET_RADIUS:
			pos.y = floor_y
			o.vel.y = absf(o.vel.y) * 0.35 if absf(o.vel.y) > 1.0 else 0.0
		node.global_position = pos + Vector3.UP * sin(o.age * 4.0) * 0.05
		node.rotate_y(delta * 3.0)
		node.scale = Vector3.ONE * clampf((LIFETIME - o.age) / 1.5, 0.0, 1.0)
	for i in range(_orbs.size() - 1, -1, -1):
		if _orbs[i].age > LIFETIME:
			_orbs[i].node.queue_free()
			_orbs.remove_at(i)
