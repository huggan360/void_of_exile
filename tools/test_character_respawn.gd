extends Node

var failures := 0
var checks := 0


func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	GameServer.set_physics_process(false)
	var config := ServerConfig.new()
	var rewards: Array = [{type = "start_tier", slot = "armor", tier = 8}]
	for class_id: String in PlayerClasses.CLASSES:
		var fresh := config.new_character(class_id, rewards)
		check(fresh.hp == fresh.max_hp and fresh.mp == fresh.max_mp,
			"New %s starts with full vitals including reward gear" % class_id)

	var stats := config.new_character("archer")
	var pid := GameServer.add_player(stats)
	# Reuse the player's object, as the real death/switch path does, and load
	# a different character that was previously saved while injured.
	stats.hp = 0
	stats.mp = 0
	var replacement := config.new_character("wizard")
	replacement.hp = 12
	replacement.mp = 3
	stats.load_data(replacement.to_data())
	GameServer.apply_buff(pid, "hp", 10, 0.5)
	GameServer.revive(pid)
	check(stats.hp == stats.max_hp and stats.mp == stats.max_mp,
		"Switching to an existing injured character restores its own full vitals")
	check(stats.buffs.wire().is_empty(), "Revive removes the previous combat effects")
	var authoritative := stats.to_data()
	stats.hp = 0
	stats.mp = 0
	GameServer.revive(pid)
	check(stats.hp == stats.max_hp and stats.mp == stats.max_mp,
		"Reviving a depleted character fills vitals")

	var client := NetClient.new()
	client.stats = PlayerStats.new()
	client.stats.hp = 0
	client.stats.mp = 0
	client.stats.buffs.add("speed", 10, 5)
	client._pending.append({seq = 1, hp = -40.0, mp = -20.0})
	var observed: Array = []
	client.switched.connect(func(_id: int, _class: String) -> void:
		observed.append(client.stats.hp == client.stats.max_hp and client.stats.mp == client.stats.max_mp))
	client._apply([Net.now(), "switched", 42, "wizard", 0, authoritative])
	check(client.character_id == 42 and client.stats.class_id == "wizard",
		"Switch installs the replacement character identity")
	check(observed == [true], "Fresh vitals reach the HUD before the switch signal")
	check(client._pending.is_empty() and client.stats.buffs.wire().is_empty(),
		"Old predictions and effects cannot carry across character IDs")
	client.on_snapshot(Net.now(), PackedFloat32Array(), [], PackedFloat32Array(),
		[stats.hp, stats.mp, 0, false])
	check(client.stats.hp == stats.max_hp and client.stats.mp == stats.max_mp,
		"First snapshot does not replay the dead character's predicted damage")
	client.stats.hp = 20
	client.stats.mp = 10
	client.on_character(authoritative)
	check(client.stats.hp == 20 and client.stats.mp == 10,
		"Ordinary character updates still preserve current combat vitals")
	# The dead ID stays on the connection while Account.character_id() falls
	# back to the only survivor. That fallback must not disable the survivor.
	var saved_data := Account.data
	var saved_mode := Net.mode
	var saved_client := Net.client
	Account.data = {characters = [{id = 43, "class" = "archer", level = 1, gear = {}}]}
	client.character_id = 42
	Net.client = client
	Net.mode = Net.Mode.CLIENT
	var picker := CharacterPicker.new(stats)
	add_child(picker)
	picker._fill_alive()
	check(not (picker._alive.get_child(0).get_child(0) as Button).disabled,
		"Only survivor remains selectable while the connected character is dead")
	picker.free()
	Account.data = saved_data
	Net.mode = saved_mode
	Net.client = saved_client
	AppSettings.install_bindings()
	for action in ["ui_focus_next", "ui_focus_prev"]:
		var tab := InputEventKey.new()
		tab.keycode = KEY_TAB
		tab.physical_keycode = KEY_TAB
		tab.shift_pressed = action == "ui_focus_prev"
		check(not InputMap.event_is_action(tab, action), "Tab is reserved for gameplay instead of " + action)
	client.free()
	GameServer.remove_player(pid)
	print("Character respawn: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
