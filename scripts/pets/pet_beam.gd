class_name PetBeam
extends Node3D
## A jagged bolt of light from a pet: a bright core inside a soft glow, that
## re-jags once while it fades, a pop of light at both ends, and (on the owner)
## a few sparks rising. Unshaded additive meshes only: no lights or collision.
const LIFE := 0.55
const SPARKS := 7
var _left := LIFE
var _end := Vector3.ZERO
var _color := Color.WHITE
var _core: MeshInstance3D
var _glow: MeshInstance3D
var _materials: Array[StandardMaterial3D] = []
var _pops: Array[MeshInstance3D] = []
var _sparks: Array[MeshInstance3D] = []
var _rejagged := false

static func spawn(parent: Node3D, start: Vector3, end: Vector3, ability: String) -> PetBeam:
	var beam := PetBeam.new()
	parent.add_child(beam)
	beam.global_position = start
	beam._build(end - start, PetDefs.ABILITIES.get(ability, PetDefs.ABILITIES.regen).color,
		ability in ["regen", "mana", "ward", "swift"])
	return beam

func _material(color: Color, strength: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(color.r * strength, color.g * strength, color.b * strength, 1.0)
	_materials.append(material)
	return material

func _build(end: Vector3, color: Color, on_owner: bool) -> void:
	_end = end
	_color = color
	_core = MeshInstance3D.new()
	_core.material_override = _material(color.lerp(Color.WHITE, 0.55), 1.6)
	add_child(_core)
	_glow = MeshInstance3D.new()
	_glow.material_override = _material(color, 0.55)
	add_child(_glow)
	_jag()
	var pop_material := _material(color.lerp(Color.WHITE, 0.3), 1.3)
	for point: Vector3 in [Vector3.ZERO, end]:
		var pop := MeshInstance3D.new()
		var cube := BoxMesh.new()
		cube.size = Vector3.ONE * 0.2
		pop.mesh = cube
		pop.material_override = pop_material
		pop.position = point
		pop.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
		add_child(pop)
		_pops.append(pop)
	if on_owner:
		for i in SPARKS:
			var spark := MeshInstance3D.new()
			var cube := BoxMesh.new()
			cube.size = Vector3.ONE * 0.07
			spark.mesh = cube
			spark.material_override = pop_material
			var angle := TAU * i / SPARKS + randf() * 0.4
			spark.position = end + Vector3(cos(angle) * 0.35, randf_range(-0.5, 0.1), sin(angle) * 0.35)
			add_child(spark)
			_sparks.append(spark)

## A new random zig-zag path for both ribbons.
func _jag() -> void:
	var direction := _end.normalized()
	var side := direction.cross(Vector3.UP).normalized()
	if side.length_squared() < 0.1: side = Vector3.RIGHT
	var up := direction.cross(side).normalized()
	var segments := clampi(int(_end.length() / 0.3), 4, 14)
	var points: Array[Vector3] = [Vector3.ZERO]
	for i in range(1, segments):
		points.append(_end * float(i) / segments + side * randf_range(-0.16, 0.16) + up * randf_range(-0.12, 0.12))
	points.append(_end)
	_core.mesh = _ribbon(points, side, up, 0.045)
	_glow.mesh = _ribbon(points, side, up, 0.16)

static func _ribbon(points: Array[Vector3], side: Vector3, up: Vector3, width: float) -> ImmediateMesh:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in points.size() - 1:
		# Two crossed strips, so it reads from above and from the side.
		for offset: Vector3 in [side * width, up * width]:
			for vertex: Vector3 in [points[i] - offset, points[i] + offset, points[i + 1] + offset,
				points[i] - offset, points[i + 1] + offset, points[i + 1] - offset]: mesh.surface_add_vertex(vertex)
	mesh.surface_end()
	return mesh

func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		queue_free()
		return
	var age := 1.0 - _left / LIFE
	if not _rejagged and age > 0.3:
		_rejagged = true
		_jag()
	var fade := 1.0 - smoothstep(0.35, 1.0, age)
	for material in _materials: material.albedo_color.a = fade
	for pop in _pops:
		pop.scale = Vector3.ONE * (0.5 + 1.2 * sin(minf(1.0, age * 2.5) * PI * 0.5)) * fade
		pop.rotation.y += delta * 6.0
	for spark in _sparks:
		spark.position.y += delta * 1.6
		spark.scale = Vector3.ONE * fade
