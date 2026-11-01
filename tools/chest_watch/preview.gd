extends Node3D
## Live showcase of the actual loot chests. Each loop creates fresh closed
## chests; gameplay chests themselves never close after being opened.
var _chests: Array[LootBag] = []
var _clock := 0.0
var _cycle := 12.0
var _automatic := true
var _dark := true
var _environment := Environment.new()
var _sun := DirectionalLight3D.new()
var _status := Label.new()


func _ready() -> void:
	get_window().title = "Void Realms — Live Chest Preview"
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(8.5, 8.5, 13)
	camera.look_at(Vector3(0, 0.6, -0.4))
	camera.fov = 40.0
	camera.current = true
	var world_environment := WorldEnvironment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color(0.018, 0.023, 0.04)
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.45, 0.54, 0.72)
	_environment.glow_enabled = true
	world_environment.environment = _environment
	add_child(world_environment)
	_sun.rotation_degrees = Vector3(-55, -25, 0)
	_sun.light_color = Color(0.65, 0.75, 1.0)
	_sun.shadow_enabled = true
	add_child(_sun)
	_lighting()
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.23, 0.25, 0.29)
	stone.roughness = 0.95
	var other_stone := StandardMaterial3D.new()
	other_stone.albedo_color = Color(0.18, 0.20, 0.24)
	other_stone.roughness = 0.95
	for x in range(-6, 6):
		for z in range(-4, 4):
			_block(Vector3(x * 1.5 + 0.75, -0.13, z * 1.5 + 0.75), Vector3(1.47, 0.25, 1.47), stone if (x + z) % 2 else other_stone)
	for x in range(-6, 6):
		for y in 3:
			_block(Vector3(x * 1.5 + 0.75, 0.4 + y * 0.8, -5.5), Vector3(1.47, 0.77, 0.55), stone if (x + y) % 2 else other_stone)
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(20, 20)
	panel.add_theme_stylebox_override("panel", UIStyle.panel())
	layer.add_child(panel)
	var labels := VBoxContainer.new()
	panel.add_child(labels)
	labels.add_child(UIStyle.label("LIVE CHEST PREVIEW", 22, UIStyle.GOLD))
	labels.add_child(UIStyle.label("Space: open all   R: replay   A: auto loop   D: dungeon / daylight   Esc: exit", 16))
	labels.add_child(_status)
	UIStyle.text(_status, 16)
	_reset()


func _block(at: Vector3, size: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	add_child(instance)


func _reset() -> void:
	for chest in _chests:
		remove_child(chest)
		chest.queue_free()
	_chests.clear()
	_clock = 0.0
	for i in LootBag.TYPES.size():
		var kind: String = LootBag.TYPES[i]
		var at := Vector3((i - 1.5) * 2.3, 0, 1.8) if i < 4 else Vector3((i - 5) * 3.0, 0, -1.8)
		var chest := LootBag.new({id=i + 1, type=kind, pos=at, expires=Time.get_ticks_msec() + 86400000, opened=false})
		add_child(chest)
		# Face every latch toward the viewer for a clear view of the hinges.
		chest._model.rotation.y = PI
		_chests.append(chest)
		var nameplate := Label3D.new()
		nameplate.text = LootBag.display_name(kind)
		nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		nameplate.font_size = 32
		nameplate.pixel_size = 0.009
		nameplate.outline_size = 8
		nameplate.modulate = Color(1.0, 0.83, 0.4) if kind in ["white", "black"] else LootBag.COLORS[kind][0].lightened(0.3)
		nameplate.position = Vector3(0, 0.15, 1.0)
		chest.add_child(nameplate)


func _lighting() -> void:
	_environment.ambient_light_energy = 0.12 if _dark else 0.7
	_sun.light_energy = 0.18 if _dark else 1.3


func _process(delta: float) -> void:
	_clock += delta
	for i in _chests.size():
		if _clock >= 1.8 + i * 0.45: _chests[i].open_chest()
	if _automatic and _clock >= _cycle: _reset()
	_status.text = ("Dark dungeon" if _dark else "Daylight") + (" · New chests every 12 seconds" if _automatic else " · Auto loop paused")


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.keycode:
		KEY_SPACE:
			for chest in _chests: chest.open_chest()
		KEY_R: _reset()
		KEY_A: _automatic = not _automatic
		KEY_D:
			_dark = not _dark
			_lighting()
		KEY_ESCAPE: get_tree().quit()
