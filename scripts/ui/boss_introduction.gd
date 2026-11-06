class_name BossIntroduction
extends ResponsiveUILayer
## Local presentation of an authoritative boss intro, never the combat clock.
var _boss: Boss
var _player: Player
var _camera := Camera3D.new()
var _previous: Camera3D
var _start := Transform3D.IDENTITY
var _duration := 0.0
var _elapsed := 0.0
var _angle := 0.0
var _seen := {}
var _name: Label
var _place: Label
var _active := false
var _was_locked := false
var _hidden_layers: Array[CanvasLayer] = []
var _intro_audio := {}

func _ready() -> void:
	layer = 72
	var root := make_ui_root()
	root.theme = UIStyle.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for bottom in [false,true]:
		var bar := ColorRect.new()
		bar.color = Color(0,0,0,.94)
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE if bottom else Control.PRESET_TOP_WIDE)
		bar.offset_top = -64 if bottom else 0
		bar.offset_bottom = 0 if bottom else 64
		root.add_child(bar)
	_name = UIStyle.heading("",38)
	_place = UIStyle.label("",18,UIStyle.TEXT_DIM)
	for label in [_name,_place]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.anchor_left = .10
		label.anchor_right = .90
		label.anchor_top = .79
		label.anchor_bottom = .79
		root.add_child(label)
	_name.offset_top = -24
	_name.offset_bottom = 28
	_place.offset_top = 32
	_place.offset_bottom = 62
	_name.add_theme_color_override("font_color",UIStyle.GOLD)
	add_child(_camera)
	hide()

func update(player: Player, world: GameWorld, delta: float, allowed: bool) -> void:
	if not allowed or not is_instance_valid(world) or player.frozen:
		cancel()
		return
	if is_instance_valid(_boss):
		if _boss.state!=Enemy.State.INTRO or not is_instance_valid(_boss.director) or _boss.director.world!=world:
			cancel()
			return
	else:
		_boss = null
		for boss: Boss in Boss.all:
			if boss.state!=Enemy.State.INTRO or not player.player_id in boss.intro_players: continue
			if not is_instance_valid(boss.director) or boss.director.world!=world: continue
			var key := "%d/%d" % [boss.get_instance_id(),boss.intro_serial]
			if _seen.has(key): continue
			_seen[key] = true
			_begin(boss,player)
			break
	if not is_instance_valid(_boss): return
	_hide_ui(get_tree().root)
	_elapsed += delta
	var left := maxf(0,minf(_boss._intro_left,_duration-_elapsed))
	if left<=0:
		cancel()
		return
	var progress := clampf(_elapsed/maxf(.01,_duration),0,1)
	var focus := _boss.global_position+Vector3.UP*_boss.height()*.48
	var radius := clampf(_boss.height()*1.5+_boss.boss_def.hit_radius,12,22)
	var angle := _angle+lerpf(-.3,.3,smoothstep(0,1,progress))
	_camera.global_position = focus+Vector3(sin(angle)*radius,_boss.height()*.45+3,cos(angle)*radius)
	_camera.look_at(focus)
	var shot := _camera.global_transform
	shot = _start.interpolate_with(shot,smoothstep(0,1,clampf(_elapsed/1.2,0,1)))
	if left<1.2:
		shot = shot.interpolate_with(player.camera.global_transform,smoothstep(0,1,1-left/1.2))
	_camera.global_transform = shot
	_ui_root.modulate.a = minf(clampf(_elapsed/.9,0,1),clampf(left/.9,0,1))

func _begin(boss: Boss, player: Player) -> void:
	_player = player
	_active = true
	_was_locked = player.cinematic_locked
	_boss = boss
	_duration = maxf(.01,boss._intro_left)
	_elapsed = 0
	_previous = get_viewport().get_camera_3d()
	_start = _previous.global_transform if is_instance_valid(_previous) else player.camera.global_transform
	var direction := player.global_position-boss.global_position
	_angle = atan2(direction.x,direction.z)
	_camera.fov = player.camera.fov
	_camera.global_transform = _start
	_camera.make_current()
	player.cinematic_locked = true
	player._cancel_weapon_actions()
	GameServer.begin_boss_intro(boss.encounter_id,GameServer.player_realm(player.player_id),[player.player_id],_duration)
	_name.text = boss.def.enemy_name
	_place.text = {"blue_dragon":"THE AZURE CRUCIBLE","rimeheart_prism":"CROWN OF THE RIME","vharok":"THE CINDER BASTION","scarab_regent":"COURT OF THE SUN","hollow_crown":"THE HOLLOW THRONE"}.get(boss.def.id,"AWAKENING")
	_ui_root.modulate.a = 0
	_intro_audio = GameAudio.play("boss_intro", Vector3.INF, {bus="SFX", priority=3, duration=_duration})
	_hide_ui(get_tree().root)
	show()

func _hide_ui(node: Node) -> void:
	if node == self: return
	if node is CanvasLayer and node.get_viewport() == get_viewport() and node.visible:
		if not node in _hidden_layers: _hidden_layers.append(node)
		node.hide()
	for child in node.get_children(): _hide_ui(child)

func cancel() -> void:
	if _active and is_instance_valid(_player): _player.cinematic_locked = _was_locked
	if is_instance_valid(_previous) and _camera.current: _previous.make_current()
	elif is_instance_valid(_player) and is_instance_valid(_player.camera) and _camera.current: _player.camera.make_current()
	_previous = null
	_boss = null
	_active = false
	GameAudio.stop(_intro_audio, .12)
	_intro_audio = {}
	for ui in _hidden_layers:
		if is_instance_valid(ui): ui.show()
	_hidden_layers.clear()
	hide()

func clear_world() -> void:
	cancel()
	_seen.clear()

func _exit_tree() -> void: cancel()
