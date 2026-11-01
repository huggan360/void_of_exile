extends Node3D
## Isolated buff viewer: numbers select examples, 0 clears. Real HUD and character art.
var player := Player.new()
var remote := RemotePlayer.new()
var stats: PlayerStats
var _shot_path := ""
var _shot_left := 1.5
var _last_key := 5

func _ready() -> void:
	player.player_id = GameServer.join(false)
	stats = GameServer.character(player.player_id)
	player.stats = stats
	add_child(player)
	player.set_physics_process(false)
	player.frozen = false
	player.position = Vector3(-1.8,0,0)
	player.camera.global_position = Vector3(0,11,16)
	player.camera.look_at(Vector3(0,1,0))
	player.camera.fov = 36
	remote.player_id = -100
	add_child(remote)
	remote.position = Vector3(1.8,0,-.2)
	remote.set_look("Another adventurer","archer|G1_bow,G1_cloak,G1_spell,")
	stats.buffs.changed.connect(func(): remote.buffs.replace_wire(stats.buffs.wire()))
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(60,.2,60)
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(.14,.2,.22)
	floor_mesh.material = floor_material
	var ground := MeshInstance3D.new()
	ground.mesh = floor_mesh
	ground.position.y = -.1
	add_child(ground)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-25,0)
	sun.light_energy = 1.4
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(.055,.075,.12)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(.6,.7,.9)
	env.environment.ambient_light_energy = .7
	add_child(env)
	var hud := Hud.new(stats,player)
	add_child(hud)
	var controls := Label.new()
	controls.position = Vector2(24,250)
	controls.text = "BUFF PREVIEW\n\n1  Positive stats\n2  Negative stats\n3  Static + Quiet + Armour broken\n4  Loot buffs\n5  All effects\n0  Clear / watch exit animation\nR  Refresh timers"
	UIStyle.text(controls,18)
	controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud._ui_root.add_child(controls)
	var top := Label.new()
	top.position = Vector2(570,180)
	top.text = "Local + remote character presentation"
	UIStyle.text(top,18)
	hud._ui_root.add_child(top)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="): _shot_path = arg.trim_prefix("--shot=")
	_examples(5)

func _examples(which: int) -> void:
	_last_key = which
	stats.buffs.clear()
	if which == 0: return
	if which in [1,2,5]:
		for id in PlayerStats.STATS+["hp","mp"]:
			GameServer.apply_buff(player.player_id,id,20,(-3 if which == 2 else 3),"preview")
		GameServer.apply_buff(player.player_id,"regeneration",15,.5 if which==2 else 2.3,"preview")
	if which in [3,5]:
		GameServer.apply_buff(player.player_id,"stasis",8,1,"preview")
		GameServer.apply_buff(player.player_id,"quiet",12,1,"preview")
		GameServer.apply_buff(player.player_id,"armour_broken",18,1,"preview")
	if which in [4,5]:
		GameServer.apply_buff(player.player_id,"loot_chance","2m",.25,"preview")
		GameServer.apply_buff(player.player_id,"loot_tier","2m",.5,"preview")

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode>=KEY_0 and event.keycode<=KEY_5: _examples(event.keycode-KEY_0)
	elif event.keycode==KEY_R: _examples(_last_key)

func _process(delta: float) -> void:
	if _shot_path == "": return
	_shot_left -= delta
	if _shot_left>0: return
	set_process(false)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_shot_path)
	print("Buff preview saved: ",_shot_path)
	get_tree().quit()
