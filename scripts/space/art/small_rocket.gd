class_name SmallRocket
extends Node3D
## Seven-metre timber rocket. Origin is the landing-fin floor contact.

const Art = preload("res://scripts/space/art/ship_hull.gd").ArtBatch
var _root: Node3D
var _flame: Node3D
var _sparkles: MultiMeshInstance3D
var _fire: ShaderMaterial
var _gold: ShaderMaterial
var _spark_material: ShaderMaterial

func build() -> void:
	_root = ShipHull.content(self, _root)
	var art := Art.new(_root)
	art.part("cylinder", Vector3(0, 3.25, 0), Vector3(2.13, 4.1, 2.13), Art.DARK)
	# Individual warm planks form a round wooden pressure hull.
	for i in 20:
		var angle := i * TAU / 20
		var basis := Basis(Vector3.UP, angle)
		var radial := Vector3(sin(angle), 0, cos(angle))
		art.box(radial * 1.055 + Vector3.UP * 3.25, Vector3(0.33, 4.1, 0.21), Art.WOOD.lightened(i % 4 * 0.045), 0, basis)
		for y: float in [1.45, 2.15, 4.65, 5.24]:
			art.part("sphere", radial * 1.19 + Vector3.UP * y, Vector3.ONE * 0.09, Art.AMBER)
	for y: float in [1.42, 2.13, 4.64, 5.25]:
		art.part("cylinder", Vector3.UP * y, Vector3(2.35, 0.14, 2.35), Art.BRASS)
	# A stepped, shingled cap supports a faceted pink crystal.
	for tier in 7:
		var diameter := 2.42 - tier * 0.28
		art.part("cylinder", Vector3(0, 5.36 + tier * 0.14, 0), Vector3(diameter, 0.17, diameter), Color("518b76").lightened(tier * 0.018))
	art.part("cylinder", Vector3(0, 6.25, 0), Vector3(0.65, 0.15, 0.65), Art.BRASS)
	art.crystal(Vector3(0, 6.5, 0), Vector3(0.68, 1.0, 0.68), Art.PINK)
	# Round front porthole, with a dark green, glowing lens.
	var face := Basis(Vector3.RIGHT, PI * 0.5)
	art.part("cylinder", Vector3(0, 3.66, 1.15), Vector3(1.08, 0.18, 1.08), Art.DARK, 0, face)
	art.part("sphere", Vector3(0, 3.66, 1.28), Vector3(0.78, 0.78, 0.1), Color("8ed7b6"), 1.4)
	art.part("ring", Vector3(0, 3.66, 1.32), Vector3.ONE * 1.22, Art.BRASS, 0, face)
	for i in 8:
		var angle := i * TAU / 8
		art.part("sphere", Vector3(sin(angle) * 0.53, 3.66 + cos(angle) * 0.53, 1.39), Vector3.ONE * 0.09, Art.AMBER)
	art.box(Vector3(-0.15, 3.8, 1.345), Vector3(0.08, 0.24, 0.025), Art.AMBER, 1.5, Basis(Vector3.FORWARD, -0.4))
	# Four thick fins have flat feet at y = 0.
	for i in 4:
		var angle := i * PI * 0.5 + PI * 0.25
		var basis := Basis(Vector3.UP, angle)
		var radial := Vector3(sin(angle), 0, cos(angle))
		for step in 5:
			var height := 2.1 - step * 0.32
			art.box(radial * (1.0 + step * 0.2) + Vector3.UP * height * 0.5, Vector3(0.32, height, 0.24), Color("5e9a78"), 0, basis)
		art.box(radial * 1.65 + Vector3.UP * 0.09, Vector3(0.5, 0.18, 0.72), Art.BRASS, 0, basis)
		art.beam(radial * 1.03 + Vector3.UP * 2.2, radial * 1.92 + Vector3.UP * 0.4, 0.1, Art.BRASS)
	art.part("cylinder", Vector3(0, 1.05, 0), Vector3(0.95, 0.8, 0.95), Art.DARK)
	art.part("ring", Vector3(0, 0.7, 0), Vector3.ONE * 1.35, Art.BRASS)
	art.part("cylinder", Vector3(0, 0.71, 0), Vector3(0.9, 0.04, 0.9), Art.GREEN, 1.5)
	art.finish()
	_flame = Node3D.new()
	_flame.name = "MagicFlame"
	_flame.position.y = 0.69
	_root.add_child(_flame)
	_fire = _fire_material(Art.GREEN)
	_gold = _fire_material(Art.AMBER)
	for core in 2:
		var cone := MeshInstance3D.new()
		cone.mesh = Art.mesh("crystal")
		cone.material_override = _gold if core == 1 else _fire
		cone.rotation.z = PI
		cone.position.y = -0.5 if core == 0 else -0.32
		cone.scale = Vector3(0.95, 1, 0.95) if core == 0 else Vector3(0.45, 0.65, 0.45)
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_flame.add_child(cone)
	# Shader-driven flecks need no CPU particles or per-frame GDScript.
	_spark_material = _fire_material(Art.AMBER)
	_spark_material.set_shader_parameter("sparkle", true)
	var sparks := MultiMesh.new()
	sparks.transform_format = MultiMesh.TRANSFORM_3D
	sparks.mesh = Art.mesh("box")
	sparks.instance_count = 24
	for i in 24:
		var angle := i * 2.4
		var pos := Vector3(sin(angle) * (0.3 + i % 4 * 0.13), -0.1 - i % 7 * 0.16, cos(angle) * (0.3 + i % 4 * 0.13))
		sparks.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * 0.065), pos))
	_sparkles = MultiMeshInstance3D.new()
	_sparkles.name = "GoldSparks"
	_sparkles.multimesh = sparks
	_sparkles.material_override = _spark_material
	_sparkles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_sparkles.custom_aabb = AABB(Vector3(-1, -4, -1), Vector3(2, 5, 2))
	_flame.add_child(_sparkles)
	set_flame(0.0)

func _fire_material(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/space_magic.gdshader")
	mat.set_shader_parameter("fire_color", color)
	return mat

## Off hides the entire exhaust, including its green-gold flecks.
func set_flame(strength: float) -> void:
	if not is_instance_valid(_flame): return
	var power := clampf(strength, 0.0, 1.0)
	_flame.visible = power > 0.001
	_flame.scale = Vector3(0.65 + power * 0.45, 0.3 + power * 3.7, 0.65 + power * 0.45)
	for mat: ShaderMaterial in [_fire, _gold, _spark_material]: mat.set_shader_parameter("strength", power)
