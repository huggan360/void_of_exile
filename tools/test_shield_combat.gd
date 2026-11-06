extends Node3D
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
class WaveProbe:
	extends WarpWave
	var damage := 200.0
	func power() -> float: return damage
func _ready() -> void: _run.call_deferred()
func _run() -> void:
	AppSettings.reset_bindings()
	var player := Player.new()
	player.player_id = GameServer.join(false)
	player.stats = GameServer.character(player.player_id)
	add_child(player)
	add_child(player.aim_marker)
	GameAudio.set_context(player, null)
	player.set_physics_process(false)
	player.frozen = false
	player.stats.gear.spell = Items.make("G4_spell")
	player.refresh_gear()
	var shots := EnemyBullets.new()
	add_child(shots)
	shots.set_physics_process(false)
	shots.players.assign([player])
	var fired: Array = []
	player.shot.connect(func(_a,_b,_c,_d,_e,_f): fired.append(true))
	Input.action_press("move_forward")
	player._physics_process(.016)
	var normal := Vector2(player.velocity.x,player.velocity.z).length()
	player._charging = true
	player._charge = .8
	player._winding = .5
	player._burst_left = 3
	Input.action_press("shoot")
	Input.action_press("charge")
	Input.action_press("magic")
	player._physics_process(.016)
	check(player.shield.active,"Magic raises shield before movement/shooting in the same frame")
	var shield_loop: Dictionary = GameAudio._shield
	var shield_raise: Dictionary = GameAudio._shield_cast
	check(not shield_loop.is_empty() and shield_loop.get("loop", false), "Pressing magic starts the sustained shield sound")
	check(is_equal_approx(Vector2(player.velocity.x,player.velocity.z).length(),normal*.15),"Shield movement is exactly 15% of normal stat-scaled speed")
	check(not player._charging and player._winding==0 and player._burst_left==0,"Shield cancels charge, windup and queued burst")
	player.shoot()
	player._fire()
	player._release_charge(Items.make("G4_bow"),1.0)
	player._update_burst(1)
	check(fired.is_empty(),"Every weapon path refuses to emit while shielding")
	for action in ["shoot","charge","magic","move_forward"]: Input.action_release(action)
	player._physics_process(.016)
	check(not player.shield.active,"Releasing magic immediately restores normal stance")
	check(shield_loop.get("stopping", false) and shield_raise.get("stopping", false), "Releasing Space immediately retires both shield sounds")
	player.shoot()
	check(not fired.is_empty(),"Weapons work again after releasing shield")
	player.position = Vector3.ZERO
	player._set_shield(true)
	var base_hp := player.stats.hp
	for style in ["pellet","orb","fireball","needle","disc","crescent","shard","comet"]:
		var attack := {style=style,magic=true,speed=60.0,range=20.0,damage_min=30,damage_max=30,size=1.0,pierce_players=true,returns=2.0,ripple={radius=4},terminal={delay=.01,count=6,attack={}}}
		shots.fire(Vector3(3,.95,0),Vector3.LEFT,attack)
		shots._physics_process(.05)
		check(shots._shots.is_empty(),"Shield consumes even piercing/returning/terminal projectiles: "+style)
		check(player.stats.hp==base_hp,"Shield blocks magic damage completely: "+style)
		check(player.shield._brace_target==1 and player.shield._pulse==1,"Every projectile triggers directional brace and flash: "+style)
	check(shots.find_children("*","EnemyRipple",false,false).is_empty(),"Blocked projectiles cannot spawn secondary waves")
	check(shots.find_children("*","Debris",false,false).size()>=8,"Blocked projectiles scatter actual mesh fragments")
	var physical := {style="pellet",speed=100.0,range=20.0,damage_min=30,damage_max=30}
	shots.fire(Vector3(3,.95,0),Vector3.LEFT,physical)
	shots._physics_process(.05)
	check(shots._shots.is_empty() and player.stats.hp<base_hp,"Physical shots stop at shield and preserve existing partial damage policy")
	check(GameAudio.voices.any(func(v: Dictionary) -> bool: return v.event == "magic_shield_hit"), "Shield collisions play a supplied magic shield-hit variation")
	check(shots._shield_contact(player,Vector3(3,5,0),Vector3(-3,5,0),.2)<0,"High projectiles do not hit shield")
	check(shots._shield_contact(player,Vector3(3,.95,0),Vector3(-3,.95,0),.2)>0,"Swept shield collision catches high-speed crossing shots")
	player._set_shield(false)
	player.stats.hp = player.stats.max_hp
	shots.fire(Vector3(3,.95,0),Vector3.LEFT,{magic=true,speed=60.0,range=20.0,damage_min=30,damage_max=30})
	shots._physics_process(.05)
	check(player.stats.hp<player.stats.max_hp,"Without shield the same magic shot damages player")
	shots.clear()
	shots.players.clear()
	var wave := WaveProbe.new()
	wave.team = "players"
	wave.radius = 3
	wave.previous_radius = 2
	wave.band = 1
	add_child(wave)
	wave.set_physics_process(true)
	var magic := {magic=true,style="orb",damage_min=40,damage_max=40,speed=20.0,range=20.0}
	shots.fire(Vector3(4,.95,0),Vector3.LEFT,magic)
	shots._physics_process(.1)
	check(shots._shots.is_empty(),"Stronger player ring destroys incoming magic ball")
	check(wave.strength_toward(Vector3(3,0,0))<1,"Intercept spends power from contacted ring arc")
	wave.segments.fill(1)
	wave.damage = 10
	shots.fire(Vector3(4,.95,0),Vector3.LEFT,magic)
	shots._physics_process(.1)
	check(shots._shots.size()==1 and shots._shots[0].damage==30,"Stronger magic ball survives with reduced damage")
	shots._physics_process(.01)
	check(shots._shots[0].damage==30,"One ring cannot repeatedly drain the same projectile")
	shots.clear()
	wave.segments.fill(1)
	wave.damage = 40
	shots.fire(Vector3(4,.95,0),Vector3.LEFT,magic)
	shots._physics_process(.1)
	check(shots._shots.is_empty() and wave.strength_toward(Vector3(3,0,0))==0,"Equal powers cancel both the ball and local ring arc")
	wave.segments.fill(1)
	shots.fire(Vector3(4,.95,0),Vector3.LEFT,physical)
	shots._physics_process(.01)
	check(shots._shots.size()==1,"Physical projectiles do not clash with magic ring")
	shots.clear()
	wave.segments.fill(1)
	var opposing := WaveProbe.new()
	opposing.team = "enemies"
	opposing.damage = wave.damage
	opposing.radius = wave.radius
	opposing.band = wave.band
	add_child(opposing)
	GameAudio._cooldowns.erase("magic_shield_hit:" + str(wave.get_instance_id()))
	var before_clash := GameAudio.voices.filter(func(v: Dictionary) -> bool: return v.event == "magic_shield_hit").size()
	wave._clash_with(opposing)
	check(GameAudio.voices.filter(func(v: Dictionary) -> bool: return v.event == "magic_shield_hit").size() > before_clash, "Two opposing rings play shield contact audio where they collide")
	opposing.queue_free()
	wave.queue_free()
	for attack in Enemies.get_def("ruin_watcher").attacks: check(attack.magic,"Both Ruin Watcher orb patterns remain true magic")
	check(is_equal_approx(Biomes.SPIRIT_PACKS[0].chance,.135) and is_equal_approx(Biomes.SPIRIT_PACKS_BLUELAY[1].chance,.06),"Ruin spirits reduced to 30% of previous chances")
	# Check every wandering spirit density against the previous authored biome values.
	var count := 0
	for biome_id in Biomes.COUNT:
		var biome := Biomes.get_biome(biome_id)
		for entry in biome.enemy_packs:
			if str(entry.pack).begins_with("spirit_"): count += 1; check(entry.density<=.0721,"Wandering spirits use reduced densities")
	check(count==6,"All six wandering spirit entries are covered")
	GameAudio.set_context(null, null)
	for voice in GameAudio.voices: GameAudio.stop(voice, .01)
	GameServer.remove_player(player.player_id)
	player.free()
	shots.queue_free()
	await get_tree().create_timer(.2).timeout
	print("SHIELD COMBAT: %d checks; %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
