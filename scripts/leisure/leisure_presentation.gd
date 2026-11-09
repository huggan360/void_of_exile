class_name LeisurePresentation
extends Node
## The same mug/cigar appears in the camera hand or on the character's hand.
## This changes presentation only: the equipped weapon stays in its slot.
const ArmRig = preload("res://scripts/player_arm_rig.gd")
var actor: Node3D
var _first: Node3D
var _third: Node3D
var _kind := ""
var _model: Node3D
var _weapons := {}
var _time := 0.0

func _ready() -> void:
	process_priority = 60  # after locomotion, seated poses and the render camera

func _rebuild(kind: String) -> void:
	if is_instance_valid(_first): _first.queue_free()
	if is_instance_valid(_third): _third.queue_free()
	_kind = kind
	if kind=="": return
	if actor is Player:
		actor._cancel_weapon_actions()
		actor._set_shield(false)
	_third = LeisureProps.cigar() if kind=="cigar" else LeisureProps.cup(kind)
	actor.add_child(_third)
	if actor is Player:
		_first = Node3D.new()
		(actor as Player).camera.add_child(_first)
		var item := LeisureProps.cigar() if kind=="cigar" else LeisureProps.cup(kind)
		item.scale = Vector3.ONE*0.75
		item.name = "Item"
		_first.add_child(item)
		var skin := Color("8dc5bd") if actor.class_id=="merrow" else Color("caa477")
		var grip := Vector3(0.135, 0.115, 0.025) if kind!="cigar" else Vector3(0, -0.035, 0.02)
		LeisureProps.box(_first, grip, Vector3(0.1, 0.1, 0.11), skin)
		LeisureProps.box(_first, grip+Vector3(0.02, -0.15, 0.07), Vector3(0.11, 0.22, 0.12), PlayerClasses.get_def(actor.class_id).color.darkened(0.35))
		if kind=="cigar": _smoke(item)
	if kind=="cigar": _smoke(_third)

func _smoke(parent: Node3D) -> void:
	var puffs := GPUParticles3D.new()
	puffs.position = Vector3(0, 0.015, -0.17)
	puffs.amount = 10
	puffs.lifetime = 1.2
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0, 1, -0.3)
	process.spread = 9.0
	process.gravity = Vector3(0, 0.06, 0)
	process.initial_velocity_min = 0.04
	process.initial_velocity_max = 0.1
	process.scale_min = 0.4
	process.scale_max = 1.3
	var fade := Gradient.new()
	fade.set_color(0, Color(0.72, 0.74, 0.76, 0.2))
	fade.set_color(1, Color(0.72, 0.74, 0.76, 0))
	var texture := GradientTexture1D.new()
	texture.gradient = fade
	process.color_ramp = texture
	puffs.process_material = process
	var mesh := SphereMesh.new()
	mesh.radius = 0.014
	mesh.height = 0.028
	mesh.radial_segments = 6
	mesh.rings = 3
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = mat
	puffs.draw_pass_1 = mesh
	parent.add_child(puffs)

func _bind(model: Node3D) -> void:
	for weapon in _weapons:
		if is_instance_valid(weapon): weapon.visible = _weapons[weapon]
	_weapons.clear()
	_model = model
	for name in ["Bow", "Staff"]:
		var weapon := model.find_child(name, true, false) as Node3D
		if weapon: _weapons[weapon] = weapon.visible

func _process(delta: float) -> void:
	if not is_instance_valid(actor) or not actor.is_inside_tree(): return
	var model := actor.get("model") as Node3D
	if not is_instance_valid(model): return
	if model!=_model: _bind(model)
	var pid := int(actor.get("player_id"))
	var s := Leisure.state(pid)
	var cup: Dictionary = s.get("cup", {})
	var kind := "cigar" if Leisure.smoking(pid) else str(cup.get("kind", ""))
	if kind!=_kind: _rebuild(kind)
	for weapon in _weapons:
		if is_instance_valid(weapon): weapon.visible = bool(_weapons[weapon]) and kind==""
	if kind=="": return
	_time += delta
	var age := Leisure.now()-float(s.get("use_at", -10.0))
	var progress := pow(maxf(0.0, sin(PI*clampf(age/Leisure.SIP_TIME, 0, 1))), 1.5) if age>=0.0 and age<Leisure.SIP_TIME else 0.0
	var first_person := false
	if actor is Player:
		var player := actor as Player
		first_person = not model.visible
		_third.visible = not first_person
		_first.visible = first_person and not player.input_locked and not player.cinematic_locked
		var rest := Vector3(0.25, -0.34, -0.55)
		var raised := Vector3(0.08, -0.14, -0.24) if kind=="cigar" else Vector3(0.08, -0.13, -0.34)
		_first.position = rest.lerp(raised, progress)+Vector3(0.006*sin(_time*1.6), 0.004*cos(_time*2.0), 0)
		_first.rotation = Vector3(0.0 if kind=="cigar" else 0.9*progress, 0, -0.08*progress)
		if kind!="cigar": LeisureProps.fill(_first.get_node("Item"), int(cup.get("sips", 0)))
	if not first_person:
		var arm := model.find_child("ArmR", true, false) as Node3D
		var left := model.find_child("ArmL", true, false) as Node3D
		ArmRig.pose(arm, lerpf(0.7, 1.35, progress), lerpf(0.8, 1.7, progress), 0.0)
		ArmRig.pose(left, 0.0, 0.15, 0.0)
		var hand := model.find_child("RightHand", true, false) as Node3D
		if hand:
			_third.global_transform = Transform3D(actor.global_basis*model.basis, hand.global_position)
			if kind!="cigar":
				_third.global_position -= _third.global_basis.y*0.14
				_third.rotate_object_local(Vector3.RIGHT, 0.8*progress)
				LeisureProps.fill(_third, int(cup.get("sips", 0)))

func _exit_tree() -> void:
	for weapon in _weapons:
		if is_instance_valid(weapon): weapon.visible = _weapons[weapon]
	if is_instance_valid(_first): _first.queue_free()
	if is_instance_valid(_third): _third.queue_free()
