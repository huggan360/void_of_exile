class_name Portal
extends Area3D
## A carved stone arch (props/portal/*.vox) with a swirling surface. Walking
## into the opening emits `entered` with the destination world id.

signal entered(destination: String)

const VOXEL_SIZE := 0.25
const DIR := "res://props/portal/"
# Opening, in meters (matches tools/make_portal.py).
const OPENING_WIDTH := 3.0
const OPENING_BOTTOM := 0.5
const ARCH_START := 4.5
const ARCH_RADIUS := 1.5
## Ignore the player for this long after the portal appears.
const ARM_DELAY := 1.0

var destination := ""
var color_a := Color(0.45, 0.25, 1.0)
var color_b := Color(0.2, 0.85, 1.0)
var _armed_in := ARM_DELAY
## Off: no swirl, no light, and walking in does nothing (the campaign gate
## outside a campaign).
var active := true
var _swirl: MeshInstance3D
var _light: OmniLight3D


func setup(p_destination: String, p_color_a: Color, p_color_b: Color) -> Portal:
	destination = p_destination
	color_a = p_color_a
	color_b = p_color_b
	return self


func _ready() -> void:
	for part in ["frame", "runes"]:
		var data := VoxModel.load_vox(DIR + part + ".vox")
		var size: Vector3i = data[0].get_size()
		var mi := MeshInstance3D.new()
		mi.mesh = VoxModel.mesh_from_buffer(data[0], data[1])
		mi.material_override = VoxModel.glow_material() if part == "runes" else VoxModel.material()
		mi.position = Vector3(-size.x * 0.5, 0, -size.z * 0.5) * VOXEL_SIZE
		mi.scale = Vector3.ONE * VOXEL_SIZE
		add_child(mi)

	var height := ARCH_START + ARCH_RADIUS - OPENING_BOTTOM
	var quad := QuadMesh.new()
	quad.size = Vector2(OPENING_WIDTH, height)
	var swirl := MeshInstance3D.new()
	swirl.mesh = quad
	swirl.position.y = OPENING_BOTTOM + height * 0.5
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/portal_swirl.gdshader")
	mat.set_shader_parameter("color_a", color_a)
	mat.set_shader_parameter("color_b", color_b)
	mat.set_shader_parameter("size", quad.size)
	mat.set_shader_parameter("arch_start", (ARCH_START - OPENING_BOTTOM) / height)
	mat.set_shader_parameter("arch_radius", ARCH_RADIUS / OPENING_WIDTH)
	swirl.material_override = mat
	swirl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(swirl)
	_swirl = swirl

	var light := OmniLight3D.new()
	_light = light
	light.light_color = color_a.lerp(color_b, 0.5)
	light.light_energy = 2.5
	light.omni_range = 9.0
	light.position = Vector3(0, 3.0, -1.0)
	add_child(light)

	# Trigger inside the opening.
	var trigger := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(OPENING_WIDTH - 0.4, 3.5, 0.8)
	trigger.shape = box
	trigger.position.y = OPENING_BOTTOM + 1.75
	add_child(trigger)

	# Solid pillars so you can't walk through the stone.
	var body := StaticBody3D.new()
	for side in [-1.0, 1.0]:
		var pillar := CollisionShape3D.new()
		var pillar_box := BoxShape3D.new()
		pillar_box.size = Vector3(1.5, 6.0, 1.2)
		pillar.shape = pillar_box
		pillar.position = Vector3(side * 2.3, 3.0, 0)
		body.add_child(pillar)
	add_child(body)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_armed_in -= delta


func set_active(value: bool) -> void:
	active = value
	if _swirl:
		_swirl.visible = value
		_light.visible = value


func _on_body_entered(body: Node3D) -> void:
	if body is Player and _armed_in <= 0.0 and active:
		entered.emit(destination)
