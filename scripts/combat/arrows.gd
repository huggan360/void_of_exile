class_name Arrows
extends Node3D
## Flying projectiles. Each weapon's shots look different, built from little
## voxel boxes in the weapon's colors (Item.projectile): plain arrows at low
## grades, glowing tips from G3, voxel trails from G4, and Divine shapes such
## as fire bolts and dark orbs. Shots can weave side to side (wave_amp) or
## pierce through what they hit.
##
## Each step casts a ray along the path: obstacles take a hit, anything else
## (terrain) makes the projectile stick for a moment (or vanish, for magic).
##
## Charged shots pass `mods`: {speed, size, range} multipliers, `spiral`
## (two voxel streams corkscrewing behind the shot), `pierce` (override) and
## `burst` (a name reported through `ended` when the shot stops, e.g. to
## explode).
##
## Shots from other players online are `visual` (mods.visual): they fly and
## stop the same way but hurt nothing here (their own client reports their
## hits). mods.exclude: one more body they pass through (their shooter).

signal hit(target: Node, damage: int, weapon: Item)
## A shot with a `burst` mod stopped (hit something or ran out of range).
signal ended(position: Vector3, burst: String, weapon: Item)

const SPIRAL_RADIUS := 0.28
const SPIRAL_SPIN := 70.0  # radians per second (about one turn per 2-3 m of flight)

const STUCK_TIME := 1.2

## Bodies the projectiles pass through (the shooter).
var exclude: Array[RID] = []

var _meshes := {}  # weapon id -> [body mesh, glow mesh]
var _shots: Array[Dictionary] = []


## Fires one projectile. `phase` sets which way a weaving shot starts.
func spawn(origin: Vector3, direction: Vector3, damage: int, weapon: Item, phase := 0.0,
		trail_override := "", mods := {}) -> void:
	var p: Dictionary = weapon.projectile.duplicate()
	if mods.has("style"): p.style = mods.style
	var node := Node3D.new()
	var meshes := _meshes_for(weapon, str(p.get("style", "arrow")))
	for i in 2:
		if meshes[i] == null:
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = meshes[i]
		mi.material_override = VoxModel.glow_material() if i == 1 else VoxModel.material()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mi)
	node.scale = Vector3.ONE * p.get("size", 1.0) * mods.get("size", 1.0)
	add_child(node)
	node.global_transform = Transform3D(Basis.looking_at(direction), origin).scaled_local(node.scale)
	if p.get("trail", false) or trail_override != "":
		node.add_child(_make_trail(weapon, trail_override))
	var spinner: Node3D = null
	if mods.get("spiral", false):
		spinner = _make_spiral(weapon)
		node.add_child(spinner)
	var speed: float = p.get("speed", 24.0) * mods.get("speed", 1.0)
	_shots.append({
		node = node, origin = origin, direction = direction, speed = speed,
		travelled = 0.0, range = p.get("range", 22.0) * mods.get("range", 1.0), stuck = false, life = 0.0,
		damage = damage, weapon = weapon, phase = phase, hit = {},
		wave_amp = mods.get("wave_amp", p.get("wave_amp", 0.0)), wave_freq = p.get("wave_freq", 0.0),
		pierce = mods.get("pierce", p.get("pierce", false)), magic = p.get("style", "arrow") not in ["arrow", "trident"],
		secondary = mods.get("secondary", false), cone_deg = mods.get("cone_deg", 0.0),
		base_scale = node.scale,
		spinner = spinner, burst = mods.get("burst", ""), done = false, visual = mods.get("visual", false),
		exclude = mods.get("exclude", RID()),
	})


func clear() -> void:
	for s in _shots:
		s.node.queue_free()
	_shots.clear()


func _physics_process(delta: float) -> void:
	var space := get_world_3d().direct_space_state
	for s in _shots:
		if s.stuck:
			s.life -= delta
			s.node.scale = Vector3.ONE * clampf(s.life / 0.3, 0.01, 1.0)
			continue
		if s.spinner:
			s.spinner.rotate_object_local(Vector3.FORWARD, SPIRAL_SPIN * delta)
		var from: Vector3 = s.node.global_position
		s.travelled = minf(s.range, s.travelled + s.speed * delta)
		var to := _position_at(s, s.travelled)
		var cone_radius := 0.0
		if s.cone_deg > 0.0:
			cone_radius = maxf(0.15, s.travelled * tan(deg_to_rad(s.cone_deg * 0.5)))
			s.node.scale = Vector3(cone_radius * 2.0, cone_radius * 2.0, s.base_scale.z)
			if s.spinner: s.spinner.scale = Vector3.ONE * (0.5 / SPIRAL_RADIUS)
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = exclude if not s.exclude.is_valid() else exclude + [s.exclude]
		var result := space.intersect_ray(query)
		while not result.is_empty() and result.collider.has_method("take_hit") and s.pierce and not s.visual:
			# Piercing: hit it, remember it, and keep going.
			var id: int = result.collider.get_instance_id()
			if not s.hit.has(id):
				s.hit[id] = true
				_deal_hit(s, result.collider, result.position)
				hit.emit(result.collider, s.damage, s.weapon)
			query.exclude = query.exclude + [result.rid]
			result = space.intersect_ray(query)
		if result.is_empty():
			if cone_radius > 0.0: _cone_hits(s, from, to, cone_radius)
			s.node.global_transform = Transform3D(Basis.looking_at(to - from), to).scaled_local(s.node.scale)
		elif result.collider.has_method("take_hit"):
			s.node.global_position = result.position
			if not s.visual:
				_deal_hit(s, result.collider, result.position)
				hit.emit(result.collider, s.damage, s.weapon)
			s.travelled = s.range  # done
		elif s.magic:
			s.node.global_position = result.position
			s.travelled = s.range  # magic shots fizzle on walls
		else:
			s.node.global_position = result.position
			s.stuck = true
			s.life = STUCK_TIME
		if s.travelled >= s.range and not s.stuck:
			s.life = 0.0
			s.stuck = true
		if s.stuck and not s.done:
			s.done = true
			if s.magic: _splash(s)
			if s.burst != "" and not s.visual:
				ended.emit(s.node.global_position, s.burst, s.weapon)
				s.life = 0.0  # bursting shots don't stay stuck in the wall

	for i in range(_shots.size() - 1, -1, -1):
		if _shots[i].stuck and _shots[i].life <= 0.0:
			_shots[i].node.queue_free()
			_shots.remove_at(i)


func _deal_hit(s: Dictionary, target: Node, at: Vector3) -> void:
	if target is Enemy:
		(target as Enemy).receive_weapon_hit(at, s.direction, s.damage, s.weapon, s.secondary)
	else:
		target.take_hit(at, s.direction, s.damage)


## A moving eight-degree wave front. Width grows with distance, and the
## terrain ray clips its front; walls also block each off-center target.
func _cone_hits(s: Dictionary, from: Vector3, to: Vector3, radius: float) -> void:
	if s.visual: return
	var shape := CapsuleShape3D.new()
	shape.radius = radius
	shape.height = from.distance_to(to) + radius * 2.0
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	# Capsule's long axis is local Y; align it with flight direction.
	var basis := Basis(Quaternion(Vector3.UP, s.direction))
	query.transform = Transform3D(basis, (from + to) * 0.5)
	query.collision_mask = Player.ENEMY_LAYER | Player.OBSTACLE_LAYER
	for result in get_world_3d().direct_space_state.intersect_shape(query, 64):
		var target: Node3D = result.collider
		var id := target.get_instance_id()
		if s.hit.has(id) or not target.has_method("take_hit"): continue
		var target_pos: Vector3 = target.global_position + Vector3.UP * (target.height() * 0.5 if target is Enemy else 0.8)
		var along: float = (target_pos - s.origin).dot(s.direction)
		if along <= 0.0: continue
		var lateral: float = (target_pos - s.origin - s.direction * along).length()
		var tolerance: float = target.def.hit_radius * target.def.model_scale if target is Enemy else 0.5
		if lateral > along * tan(deg_to_rad(4.0)) + tolerance: continue
		var wall := PhysicsRayQueryParameters3D.create(s.origin, target_pos, Player.TERRAIN_LAYER | Player.OBSTACLE_LAYER)
		wall.exclude = [target.get_rid()] if target is CollisionObject3D else []
		if not get_world_3d().direct_space_state.intersect_ray(wall).is_empty(): continue
		s.hit[id] = true
		_deal_hit(s, target, target_pos)
		hit.emit(target, s.damage, s.weapon)


func _splash(s: Dictionary) -> void:
	var points := PackedVector3Array()
	var colors := PackedColorArray()
	var tint: Color = s.weapon.projectile.get("color", Color.WHITE)
	for i in 14:
		points.append(s.node.global_position + Vector3(randf_range(-0.12, 0.12), randf_range(-0.12, 0.12), randf_range(-0.12, 0.12)))
		colors.append(tint.lightened(randf_range(0.0, 0.4)))
	Debris.burst_flash(self, points, colors, 0.075, 14, s.node.global_position - s.direction * 0.1, s.node.global_position.y - 0.8, 0.45)


## Where a shot is after flying `distance` meters (weaving shots swing side
## to side around their straight line).
func _position_at(s: Dictionary, distance: float) -> Vector3:
	var pos: Vector3 = s.origin + s.direction * distance
	if s.wave_amp > 0.0:
		var side: Vector3 = s.direction.cross(Vector3.UP).normalized()
		# Ramps in over the first meter so both shots leave the bow together.
		var ramp := clampf(distance, 0.0, 1.0)
		pos += side * sin(distance / s.speed * s.wave_freq + s.phase) * s.wave_amp * ramp
	return pos


# --- Looks --------------------------------------------------------------------------

func _meshes_for(weapon: Item, style: String) -> Array:
	var key := weapon.id + ":" + style
	if _meshes.has(key):
		return _meshes[key]
	var p: Dictionary = weapon.projectile
	var c1: Color = p.get("color", Color.WHITE)
	var c2: Color = p.get("color2", Color.GRAY)
	var glow: bool = p.get("glow", false)
	var body := SurfaceTool.new()
	var lit := SurfaceTool.new()
	body.begin(Mesh.PRIMITIVE_TRIANGLES)
	lit.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tip_tool := lit if glow else body
	if weapon.id.ends_with("_ofiron"):
		_iron_mesh(body, lit, weapon.kind)
	match "iron" if weapon.id.ends_with("_ofiron") else style:
		"arrow":
			_box(body, Vector3(0, 0, 0.05), Vector3(0.05, 0.05, 0.7), c2)  # shaft
			_box(tip_tool, Vector3(0, 0, -0.34), Vector3(0.11, 0.11, 0.14), c1)  # head
			_box(body, Vector3(0.06, 0, 0.36), Vector3(0.08, 0.03, 0.14), c1)  # fletching
			_box(body, Vector3(-0.06, 0, 0.36), Vector3(0.08, 0.03, 0.14), c1)
			_box(body, Vector3(0, 0.06, 0.36), Vector3(0.03, 0.08, 0.14), c1)
		"trident":
			_box(body, Vector3(0, 0, 0.12), Vector3(0.055, 0.055, 0.9), c2.darkened(0.3))
			_box(tip_tool, Vector3(0, 0, -0.32), Vector3(0.4, 0.07, 0.08), c1)
			for x in [-0.18, 0.0, 0.18]:
				_box(tip_tool, Vector3(x, 0, -0.48), Vector3(0.07, 0.07, 0.3), c1)
		"water":
			for i in 4:
				_box(lit, Vector3(0, 0, i * 0.11), Vector3.ONE * (0.15 - i * 0.02), c1.lerp(c2, i / 4.0))
		"bolt":
			_box(lit, Vector3(0, 0, -0.2), Vector3(0.14, 0.14, 0.3), c1)
			_box(lit, Vector3(0, 0, 0.12), Vector3(0.1, 0.1, 0.3), c2)
			_box(lit, Vector3(0, 0, 0.38), Vector3(0.06, 0.06, 0.2), c2.darkened(0.2))
		"orb":
			for x: int in [-1, 0, 1]:
				for y: int in [-1, 0, 1]:
					for z: int in [-1, 0, 1]:
						if absi(x) + absi(y) + absi(z) <= 2:
							var core := x == 0 and y == 0 and z == 0
							_box(lit if core or (x + y + z) % 2 == 0 else body,
									Vector3(x, y, z) * 0.1, Vector3.ONE * 0.1, c1 if core else c2)
	var meshes := [body.commit(), lit.commit()]
	for i in 2:
		if (meshes[i] as ArrayMesh).get_surface_count() == 0:
			meshes[i] = null
	_meshes[key] = meshes
	return meshes


## Adds a box (center, size) with a vertex color to a mesh being built.
func _box(st: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	var h := size * 0.5
	var faces := [
		[Vector3(0, 0, -1), [Vector3(-1, -1, -1), Vector3(1, -1, -1), Vector3(1, 1, -1), Vector3(-1, 1, -1)]],
		[Vector3(0, 0, 1), [Vector3(1, -1, 1), Vector3(-1, -1, 1), Vector3(-1, 1, 1), Vector3(1, 1, 1)]],
		[Vector3(-1, 0, 0), [Vector3(-1, -1, 1), Vector3(-1, -1, -1), Vector3(-1, 1, -1), Vector3(-1, 1, 1)]],
		[Vector3(1, 0, 0), [Vector3(1, -1, -1), Vector3(1, -1, 1), Vector3(1, 1, 1), Vector3(1, 1, -1)]],
		[Vector3(0, 1, 0), [Vector3(-1, 1, -1), Vector3(1, 1, -1), Vector3(1, 1, 1), Vector3(-1, 1, 1)]],
		[Vector3(0, -1, 0), [Vector3(-1, -1, 1), Vector3(1, -1, 1), Vector3(1, -1, -1), Vector3(-1, -1, -1)]],
	]
	st.set_color(color)
	for face in faces:
		var n: Vector3 = face[0]
		var v: Array = face[1]
		st.set_normal(n)
		for idx in [0, 2, 1, 0, 3, 2]:
			st.add_vertex(center + (v[idx] as Vector3) * h)


## Two voxel streams on opposite sides of a spinning pivot: as the shot flies
## they leave a corkscrew behind it.
func _make_spiral(weapon: Item) -> Node3D:
	var spinner := Node3D.new()
	var color: Color = weapon.projectile.get("color", Color.WHITE)
	var streams: int = weapon.charge.get("streams", 2)
	for i in streams:
		var angle := TAU * i / streams
		var pm := ParticleProcessMaterial.new()
		pm.direction = Vector3.ZERO
		pm.spread = 0.0
		pm.initial_velocity_min = 0.0
		pm.initial_velocity_max = 0.0
		pm.gravity = Vector3.ZERO
		pm.color = color.lightened(0.25) if i % 2 else color
		var shrink := Curve.new()
		shrink.add_point(Vector2(0, 1))
		shrink.add_point(Vector2(1, 0))
		var shrink_tex := CurveTexture.new()
		shrink_tex.curve = shrink
		pm.scale_curve = shrink_tex
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE * 0.08
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/fire_voxel.gdshader")
		mat.set_shader_parameter("brightness", 3.0)
		cube.material = mat
		var p := GPUParticles3D.new()
		p.process_material = pm
		p.draw_pass_1 = cube
		p.amount = 160
		p.lifetime = 0.4
		p.local_coords = false  # left hanging in the air: a corkscrew
		p.position = Vector3(cos(angle) * SPIRAL_RADIUS, sin(angle) * SPIRAL_RADIUS, 0.1)
		p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 40))
		spinner.add_child(p)
	return spinner


func _make_trail(weapon: Item, trail_override: String) -> GPUParticles3D:
	var p: Dictionary = weapon.projectile
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 20.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.8
	pm.gravity = Vector3.ZERO
	pm.color = p.get("color", Color.WHITE)
	match trail_override:
		"gold":
			pm.color = Color(1.0, 0.82, 0.35)
		"rainbow":
			pm.hue_variation_min = -1.0
			pm.hue_variation_max = 1.0
		"embers":
			pm.color = Color(1.0, 0.5, 0.15)
	var shrink := Curve.new()
	shrink.add_point(Vector2(0, 1))
	shrink.add_point(Vector2(1, 0))
	var shrink_tex := CurveTexture.new()
	shrink_tex.curve = shrink
	pm.scale_curve = shrink_tex
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE * 0.07
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/fire_voxel.gdshader")
	mat.set_shader_parameter("brightness", 2.5)
	cube.material = mat
	var particles := GPUParticles3D.new()
	particles.process_material = pm
	particles.draw_pass_1 = cube
	particles.amount = 24 if weapon.is_divine() else 14
	particles.lifetime = 0.35
	particles.local_coords = false  # stays behind in the air
	particles.position = Vector3(0, 0, 0.3)
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 30))
	return particles


## Black iron shafts with white edges; charged shots reuse the authored silhouette.
func _iron_mesh(body: SurfaceTool, lit: SurfaceTool, kind: String) -> void:
	var iron := Color("303746")
	var edge := Color("dce3ef")
	var core := Color("c8a5ed")
	if kind == "Wand":
		_box(body, Vector3.ZERO, Vector3(0.26, 0.26, 0.44), iron)
		for axis in [Vector3.RIGHT, Vector3.UP]:
			_box(lit, axis * 0.16, Vector3(0.08, 0.08, 0.48), edge)
			_box(lit, -axis * 0.16, Vector3(0.08, 0.08, 0.48), edge)
		_box(lit, Vector3(0, 0, -0.28), Vector3(0.14, 0.14, 0.16), core)
	else:
		_box(body, Vector3(0, 0, 0.12), Vector3(0.08, 0.08, 0.95), iron)
		_box(body, Vector3(0, 0, -0.35), Vector3(0.32 if kind == "Trident" else 0.2, 0.06, 0.15), edge)
		for x in ([-0.16, 0.0, 0.16] if kind == "Trident" else [0.0]):
			_box(body, Vector3(x, 0, -0.5), Vector3(0.1, 0.08, 0.35), iron)
			_box(lit, Vector3(x, 0.04, -0.54), Vector3(0.04, 0.025, 0.32), edge)
		_box(lit, Vector3(0, 0, 0.5), Vector3(0.22, 0.05, 0.16), core)
