extends Node3D
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _ready() -> void: _run.call_deferred()

func _run() -> void:
	GameServer.set_physics_process(false)
	GameServer.debug_godmode = false
	var pid := GameServer.join(false)
	var stats := GameServer.character(pid)
	var spell := Item.new()
	spell.slot = "spell"
	spell.kind = "Spell"
	stats.gear = {weapon=null,armor=null,spell=spell,bonus=null}
	stats.base.magic = 0
	check(stats.shield_reduction()==0.0,"Zero MAG has zero regular-projectile protection")
	stats.base.magic = 20
	check(is_equal_approx(stats.shield_reduction(),0.35),"20 MAG blocks 35 percent")
	stats.base.magic = 70
	check(absf(stats.shield_reduction()-0.80)<0.001,"70 MAG blocks about 80 percent")
	stats.base.magic = 110
	check(is_equal_approx(stats.shield_reduction(),0.93),"110 MAG blocks 93 percent")
	var prior := 0.0
	var prior_gain := 1.0
	var diminishing := true
	for magic in range(1,501):
		stats.base.magic = magic
		var reduction := stats.shield_reduction()
		var gain := reduction-prior
		if reduction>=1.0 or gain<0.0 or gain>prior_gain+0.0000001: diminishing = false
		prior = reduction
		prior_gain = gain
	check(diminishing,"Curve has diminishing returns and never reaches full protection")
	for id: String in PlayerClasses.ORDER:
		stats.class_id = id
		stats.base.magic = 20
		check(is_equal_approx(stats.shield_reduction(),0.35),id+": same shared curve")
		var saved := stats.to_data()
		saved.base.magic = 168
		var loaded := PlayerStats.new()
		loaded.load_data(saved)
		check(loaded.base.magic==int(PlayerClasses.get_def(id).maximum.magic),id+": saved MAG respects new class cap")
		check(loaded.stat_max("magic")>=55 and loaded.stat_max("magic")<=70,id+": base cap is in 55-70 range")
	stats.class_id = "archer"
	stats.base.magic = 20
	stats.base.defense = 10
	stats.base_hp = 10000
	stats.hp = stats.max_hp
	stats.mp = stats.max_mp
	check(GameServer.set_shield(pid,true),"Shield raises with a spell and MP")
	var result := GameServer.hit_player(pid,100.0,false,true)
	check(is_equal_approx(float(result.soaked),35.0) and is_equal_approx(float(result.landed),55.0),"MAG reduces raw damage before Defence")
	stats.base.defense = 100
	result = GameServer.hit_player(pid,100.0,false,true)
	check(is_equal_approx(float(result.landed),9.75),"Defence minimum uses the post-shield remainder")
	result = GameServer.hit_player(pid,100.0,true,true)
	check(is_equal_approx(float(result.landed),65.0),"Armour piercing skips Defence, retains shield reduction")
	result = GameServer.hit_player(pid,100.0,true,false,"Burning")
	check(float(result.landed)==100.0,"Burning bypasses shield and Defence")
	stats.base.magic = 0
	stats.base.defense = 0
	var player := Player.new()
	player.player_id = pid
	player.stats = stats
	add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player._set_shield(true)
	for hit in 5: player.take_damage(100.0)
	check(player.shield.active and GameServer._players[pid].shield,"Repeated hits never break a zero-MAG shield")
	var hp := stats.hp
	player.take_damage(100.0,false,true)
	check(stats.hp==hp,"Existing full magic-projectile block remains")
	stats.mp = 1.0
	GameServer._tick_vitals(GameServer._players[pid],0.2)
	player._update_magic(0.0)
	check(stats.mp==0.0 and not player.shield.active,"MP depletion lowers the shield")
	check(not GameServer.set_shield(pid,true),"Empty MP cannot raise shield again")
	var boosted := Items.make("D_spell_oftheblue")
	stats.gear.spell = boosted
	stats.base.magic = 0
	var other := PlayerStats.new()
	other.gear = {weapon=null,armor=null,spell=null,bonus=null}
	other.base.magic = stats.total("magic")
	check(is_equal_approx(other.shield_reduction(),stats.shield_reduction()),"Protection depends only on displayed MAG, including item bonuses")
	check(not boosted.effects.has("shield_absorb"),"Legacy capacity multipliers are removed")
	player.queue_free()
	GameServer.remove_player(pid)
	await get_tree().process_frame
	print("MAG SHIELD: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
