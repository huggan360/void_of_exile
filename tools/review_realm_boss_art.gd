extends Node3D
## Art showroom only. No Enemy, Boss, loot or realm registration.
## F6 to inspect; 1-4 selects bosses, 0 returns to the lineup. Use --crystal for the conduit diorama.
const ART := "staging/realm_bosses_01/"
const IDS := ["rimeheart_prism", "vharok_cinder_tyrant", "aureate_scarab_regent", "hollow_crown"]
var _camera := Camera3D.new()
var _models: Array[CreatureModel] = []
var _spinning: CreatureModel
var _args := {}
var _focus := Vector3.ZERO
var _time := 0.0
var _cycle: CreatureModel
var _last_phase := -1

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1] if kv.size() == 2 else "true"
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("#131c2b")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("#c5d7ec")
	settings.ambient_light_energy = .65
	settings.glow_enabled = true
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = settings
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-47, -31, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)
	add_child(_camera)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.current = true
	if _args.has("reference"):
		_add_model("blue_dragon", Vector3.ZERO, "Blue Dragon · existing reference")
		_set_view(Vector3(0,3,0), 22)
	elif _args.has("model"):
		var id: String = str(_args.model)
		var form: String = str(_args.get("form", ""))
		var model := _add_model(ART + id, Vector3.ZERO, id.replace("_", " ").capitalize())
		if form != "": model.set_variant(form)
		if form == "tempest": _spinning = model
		if _args.has("cycle"): _cycle = model
		_set_view(Vector3(0,4.3,0), 14.5 if id in IDS else 6)
	elif _args.has("crystal"):
		_crystal_diorama()
		_set_view(Vector3(0,4,0), 34)
	else:
		for i in IDS.size():
			_add_model(ART + IDS[i], Vector3((1.5-i)*13,0,0), ["Fosen · Rimeheart Prism", "Lava · Vharok", "Desert · Scarab Regent", "Dark · Hollow Crown"][i])
		_set_view(Vector3(0,4,0), 31)
		_camera.position = _focus + Vector3(0,8,-30)
		_camera.look_at(_focus)
	if _args.has("shot"):
		await get_tree().create_timer(.7).timeout
		if _args.has("time"): _time = float(_args.time)
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(str(_args.shot))
		get_tree().quit()

func _add_model(id: String, at: Vector3, title: String) -> CreatureModel:
	var model := CreatureModel.new(id)
	model.position = at
	add_child(model)
	_models.append(model)
	var pad := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 5.9 if not id.contains("conduit") and not id.contains("shardling") else 1.0
	mesh.bottom_radius = mesh.top_radius
	mesh.height = .16
	mesh.radial_segments = 6
	pad.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("#26374b")
	material.roughness = .9
	pad.material_override = material
	pad.position = at + Vector3(0,-.15,0)
	add_child(pad)
	if not title.is_empty():
		var label := Label3D.new()
		label.text = title
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size = 42
		label.pixel_size = .009
		label.position = at + Vector3(0,-.7,-5)
		label.no_depth_test = true
		add_child(label)
	return model

func _crystal_diorama() -> void:
	var base := _add_model(ART + "rimeheart_prism", Vector3.ZERO, "Conduit form · six healing pylons")
	base.set_variant("conduit")
	for i in 6:
		var a := float(i)*TAU/6.0
		var at := Vector3(sin(a)*6.2,0,cos(a)*6.2)
		_add_model(ART + "rimeheart_conduit", at, "")
		var next := Vector3(sin(a+TAU/6)*6.2,2.72,cos(a+TAU/6)*6.2)
		_beam(at+Vector3.UP*2.72, next)
		_beam(at+Vector3.UP*2.72, Vector3(0,5.05,0))
	for i in 4:
		_add_model(ART + "rimeheart_shardling", Vector3(-6+i*4,0,-9), "")
	_add_model(ART + "rimeheart_prism", Vector3(14,0,0), "I · Sealed")
	_spinning = _add_model(ART + "rimeheart_prism", Vector3(-14,0,0), "III · Tempest / fast rotation")
	_spinning.set_variant("tempest")

func _beam(a: Vector3, b: Vector3) -> void:
	# Voxel chain is a visual mock-up. It does no healing or combat.
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(.4,.88,1)
	material.emission_enabled = true
	material.emission = Color(.3,.8,1)
	material.emission_energy_multiplier = 2
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE*.07
	cube.material = material
	var count := ceili(a.distance_to(b)/.12)+1
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = cube
	multi.instance_count = count
	for i in count:
		multi.set_instance_transform(i,Transform3D(Basis.IDENTITY, a.lerp(b,float(i)/maxi(1,count-1))))
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)

func _set_view(focus: Vector3, size: float) -> void:
	_focus = focus
	_camera.size = size
	_camera.position = focus + Vector3(10,10,-24)
	_camera.look_at(focus)

func _process(delta: float) -> void:
	_time += delta
	for model in _models:
		model.animate(0, delta)
	if is_instance_valid(_spinning): _spinning.rotation.y += delta * 8
	if is_instance_valid(_cycle):
		var phase := int(_time / 4) % 3
		if phase != _last_phase:
			_cycle.set_variant(["", "conduit", "tempest"][phase])
			_last_phase = phase
		if phase == 2: _cycle.rotation.y += delta*8
		else: _cycle.rotation.y = lerp_angle(_cycle.rotation.y,0.0,delta*5)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode >= KEY_1 and event.keycode <= KEY_4:
			_set_view(Vector3((1.5-event.keycode+KEY_1)*13,4,0), 15)
		elif event.keycode == KEY_0: _set_view(Vector3(0,4,0),31)
		elif event.keycode == KEY_ESCAPE: get_tree().quit()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: _camera.size = maxf(6,_camera.size*.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: _camera.size = minf(80,_camera.size*1.1)
