extends Node
## Preview driver only. Uses the real fights; never changes their definitions.
var game: Node3D
var key := "blue"
var boss: Boss
var fort: StrongholdFeature
var clock := 0.0
var pulse := 0.0
var finished := false
var auto_damage := true
var _status: Label
var _last_phase := -1
const BOSS_IDS := {blue="blue_dragon",frost="rimeheart_prism",lava="vharok",desert="scarab_regent",dark="hollow_crown"}
const BIOMES := {blue=Biomes.BLUELAY,frost=Biomes.FOSEN,lava=Biomes.DOOM,desert=Biomes.DESERT,dark=Biomes.DEEP_DARK}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_start.call_deferred()

func _start() -> void:
	GameServer.debug_godmode = true
	game.menus.hide_all()
	game.hud.show()
	game.player.input_locked = true
	_overlay()
	var world := game.world as IslandWorld
	for candidate in world.generator.strongholds:
		if candidate.biome_id==BIOMES[key]: fort = candidate; break
	if fort==null:
		_status.text = "Stronghold not found. Escape to close."
		return
	var at := Vector3(fort.center.x+.5,fort.base_height+1,fort.center.y+12.5)
	game._place_player(at)
	await game._wait_for_ground()
	# The target is moved by this driver, so it can never get stuck on helpers.
	game.player.set_physics_process(false)
	game.player.frozen = false
	while not is_instance_valid(boss):
		for candidate: Boss in Boss.all:
			if candidate.def.id==BOSS_IDS[key]: boss = candidate; break
		if not is_instance_valid(boss): await get_tree().create_timer(.1).timeout
	# Keep the encounter's own helpers, without unrelated wilderness packs.
	world.enemy_director.set_physics_process(false)
	for enemy: Enemy in world.enemy_director.enemies():
		if enemy!=boss: enemy.queue_free()
	game.enemy_bullets.clear()
	game.player.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	game.player.camera.size = 64.0
	_camera()
	boss.died.connect(func(_actor: Enemy) -> void: finished = true)
	await get_tree().create_timer(3).timeout
	pulse = 0

func _process(delta: float) -> void:
	if not is_instance_valid(game) or fort==null: return
	_camera()
	if get_tree().paused: return
	if finished or not is_instance_valid(boss):
		if finished: _status.text = "Fight complete — R to replay - Escape to close"
		return
	clock += delta
	if boss.state==Enemy.State.ACTIVE:
		# A slow invulnerable target makes aimed attacks and chasing helpers visible.
		var angle := clock*.14
		var center := Vector3(fort.center.x+.5,fort.base_height+1,fort.center.y+.5)
		game.player.global_position = center+Vector3(sin(angle)*14,0,cos(angle)*12)
		var toward: Vector3 = boss.global_position-game.player.global_position
		game.player.model.rotation.y = atan2(-toward.x,-toward.z)
		game.player.model.animate(.4,delta)
	pulse -= delta
	if auto_damage and clock>3 and pulse<=0:
		pulse = .5
		_damage_encounter()
	var stage := "Shell / hatching" if boss.phase<0 else "Phase %d" % (boss.phase+1)
	if boss.phase!=_last_phase: _last_phase = boss.phase
	_status.text = "%s  -  %s  -  %ds\nP: pause   D: auto damage %s   R: replay   Esc: close" % [boss.def.enemy_name,stage,int(clock),"ON" if auto_damage else "OFF"]

func _damage_encounter() -> void:
	if not is_instance_valid(boss): return
	if boss.is_sealed():
		boss.take_hit(boss.global_position+Vector3.UP,Vector3.ZERO,maxi(1,ceili(boss.shell_max/10.0)),game.player)
		return
	if boss.state!=Enemy.State.ACTIVE: return
	# Roughly 90 seconds of vulnerable boss HP, plus objective/guard interludes.
	# Apply through normal damage handling: immunity, floors and phase caps stay real.
	var amount := maxi(1,ceili(boss.max_hp*.5/90.0)+boss.defense)
	boss.take_hit(boss.global_position+Vector3.UP,Vector3.ZERO,amount,game.player)
	for role in boss._support.keys():
		for helper: Enemy in boss.support(str(role)).duplicate():
			if not is_instance_valid(helper) or not helper.is_alive(): continue
			var hit := maxi(1,ceili(helper.max_hp*.5/18.0)+helper.defense)
			helper.take_hit(helper.global_position+Vector3.UP,Vector3.ZERO,hit,game.player)

func _camera() -> void:
	if not is_instance_valid(game.player.camera): return
	var center := Vector3(fort.center.x+.5,fort.base_height+2,fort.center.y+.5)
	game.player.camera.global_position = center+Vector3(0,65,36)
	game.player.camera.look_at(center)

func _overlay() -> void:
	var layer := ResponsiveUILayer.new()
	layer.layer = 75
	add_child(layer)
	var root := layer.make_ui_root()
	root.theme = UIStyle.theme()
	_status = UIStyle.label("Loading boss fight…",17,UIStyle.TEXT)
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_status.offset_left = 22
	_status.offset_right = 620
	_status.offset_top = -110
	_status.offset_bottom = -50
	root.add_child(_status)

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo): return
	match event.keycode:
		KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			get_tree().quit()
		KEY_P, KEY_SPACE:
			get_tree().paused = not get_tree().paused
			get_viewport().set_input_as_handled()
		KEY_D:
			auto_damage = not auto_damage
			get_viewport().set_input_as_handled()
		KEY_R:
			get_tree().paused = false
			get_viewport().set_input_as_handled()
			get_tree().reload_current_scene()

func _exit_tree() -> void:
	get_tree().paused = false
	if is_instance_valid(game) and is_instance_valid(game.player): GameServer.remove_player(game.player.player_id)
