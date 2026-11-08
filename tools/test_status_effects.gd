extends Node3D
var checks := 0
var failures := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func _ready() -> void: _run.call_deferred()
func _run() -> void:
	GameServer.set_physics_process(false)
	var pid := GameServer.join(false)
	var stats := GameServer.character(pid)
	stats.base.speed = 10  # Signed modifiers need a positive baseline; classes now start at zero.
	var speed := stats.total("speed")
	check(GameServer.apply_buff(pid,"speed","3s",1,"test"),"Server grants timed stats")
	check(stats.total("speed")==speed+1,"Positive stat affects actual movement calculation")
	GameServer.apply_buff(pid,"speed",10,-3,"enemy")
	check(stats.total("speed")==speed-3,"Longer effect replaces the type across sources")
	GameServer.apply_buff(pid,"speed",20,5,"test")
	check(stats.buffs.active().size()==1 and stats.total("speed")==speed+5,"One effect per type")
	stats.buffs.entries["speed"].expires = Net.now()-1
	stats.buffs.tick()
	check(stats.total("speed")==speed,"Expiry restores underlying values")
	stats.buffs.clear()
	for stat in PlayerStats.STATS:
		var base := stats.total(stat)
		GameServer.apply_buff(pid,stat,10,"-max")
		check(stats.total(stat)==0,"-max removes the unbuffed "+stat)
		stats.buffs.clear()
		GameServer.apply_buff(pid,stat,10,"+max")
		check(stats.total(stat)==base*2,"+max adds the unbuffed "+stat)
		stats.buffs.clear()
	stats.gear.armor = Items.make("G6_cloak")
	var raw_def: int = stats.base.defense
	var armored := stats.total("defense")
	GameServer.apply_buff(pid,"armour_broken",3)
	check(stats.total("defense")==raw_def and armored>raw_def,"Armour Broken removes gear defence, keeps base defence")
	GameServer.apply_buff(pid,"defense",3,4)
	check(stats.total("defense")==raw_def+4,"Armour Broken preserves direct defence buffs")
	check(StatusEffects.banner(stats.buffs.entries["armour_broken"])=="purple","Armour break is purple")
	stats.buffs.clear()
	var base_hp := stats.max_hp
	GameServer.apply_buff(pid,"health",10,40)
	check(stats.max_hp==base_hp+40,"Health effect changes maximum health")
	stats.hp = stats.max_hp
	stats.buffs.clear()
	check(stats.max_hp==base_hp and stats.hp==base_hp,"Expiry clamps health to restored maximum")
	GameServer.apply_buff(pid,"hp",10,"-max")
	check(stats.max_hp==1,"Health cannot become a zero-sized resource bar")
	stats.buffs.clear()
	stats.hp = 10.0
	GameServer.apply_buff(pid,"regeneration",10,2.3)
	GameServer._players[pid].since_hurt = 0
	GameServer._tick_vitals(GameServer._players[pid],1.0)
	check(is_equal_approx(stats.hp,13.45),"2.3 regeneration gives 230% base healing even in combat")
	check(StatusEffects.banner(stats.buffs.entries["regeneration"])=="green","Beneficial regeneration is green")
	stats.buffs.clear()
	GameServer.apply_buff(pid,"regeneration",10,.5)
	check(StatusEffects.banner(stats.buffs.entries["regeneration"])=="red","Reduced regeneration is red")
	check(not GameServer.apply_buff(pid,"speed","bad",1),"Malformed duration rejected")
	check(not GameServer.apply_buff(pid,"speed",0,1),"Zero duration rejected")
	check(not GameServer.apply_buff(pid,"speed",3,"banana"),"Malformed magnitude rejected")
	check(not GameServer.apply_buff(pid,"speed",3,NAN),"Nonfinite magnitude rejected")
	check(not GameServer.apply_buff(pid,"unknown",3,1),"Unknown effects rejected")
	check(StatusEffects.seconds("2m")==120 and StatusEffects.seconds("250ms")==.25,"Duration units parse")
	check(StatusEffects.time_text(2)=="2s" and StatusEffects.time_text(120)=="2m","Compact timer units")
	stats.buffs.clear()
	GameServer.apply_buff(pid,"stasis","3s")
	check(stats.buffs.has_effect("frozen") and StatusEffects.banner(stats.buffs.active()[0])=="blue","Stasis/frozen aliases share the blue status")
	var mirror := PlayerStats.new()
	mirror.buffs.replace_wire(stats.buffs.wire(),1.0)
	check(mirror.buffs.has_effect("static") and float(mirror.buffs.active()[0].expires)-Net.now()<2.1,"Replication compensates elapsed time")
	var data := stats.to_data()
	check(not data.has("buffs"),"Temporary effects are not persisted in account saves")
	stats.buffs.clear()
	# Real local-player controls, including queued charged shots.
	var player := Player.new()
	player.player_id = pid
	player.stats = stats
	add_child(player)
	player.set_physics_process(false)
	player.frozen = false
	var fired: Array = []
	player.shot.connect(func(_a,_b,_c,_d,_e,_f): fired.append(true))
	GameServer.apply_buff(pid,"quiet",3)
	player._charging = true
	player._winding = .5
	player._burst_left = 3
	player._physics_process(.016)
	player.shoot()
	player._fire()
	check(fired.is_empty() and not player._charging and player._winding==0 and player._burst_left==0,"Quiet prevents shooting and cancels queued shots")
	stats.buffs.clear()
	GameServer.apply_buff(pid,"static",3)
	player.debug_input = Vector2.ONE
	player._knock = Vector3(4,0,4)
	player._physics_process(.016)
	check(Vector2(player.velocity.x,player.velocity.z).length()<.001,"Static stops input and knockback movement")
	stats.buffs.clear()
	player.shoot()
	check(not fired.is_empty(),"Shooting returns after Quiet expires")
	# Server-issued projectile reports do not accept arbitrary effects or repeated claims.
	var server := NetServer.new()
	var tokens := server._authorize_status_shots({effects=[{id="quiet",duration="3s"}],range=10,speed=5},"test",Vector3.ZERO,"test_enemy")
	var token := int(tokens[""])
	var record := {realm="test",pos=Vector3.ZERO,player_id=pid}
	server._status_hit(record,token+999)
	check(not stats.buffs.has_effect("quiet"),"Unknown projectile token rejected")
	record.realm = "other"
	server._status_hit(record,token)
	check(not stats.buffs.has_effect("quiet"),"Projectile claim in another realm rejected")
	record.realm = "test"
	server._status_hit(record,token)
	check(stats.buffs.has_effect("quiet"),"Authorized projectile applies its server-authored effects")
	var revision := stats.buffs.revision
	server._status_hit(record,token)
	check(stats.buffs.revision==revision,"Duplicate projectile claim cannot refresh a buff")
	var children := server._authorize_status_shots({range=10,speed=5,terminal={attack={range=5,speed=4,effects=[{id="static",duration=2}]}}},"test",Vector3.ZERO,"orb")
	check(children.has("t"),"Terminal projectile children receive independent authorization")
	server.api.free()
	server.free()
	stats.buffs.clear()
	# Client mirrors preserve effects across unrelated gear/character updates.
	var client := NetClient.new()
	client.stats = mirror
	mirror.player_id = 77
	mirror.buffs.add("attack",10,4)
	client.on_character(mirror.to_data())
	check(mirror.buffs.has_effect("attack"),"Inventory replication preserves active effects")
	client._apply([Net.now(),"buffs",77,[]])
	check(mirror.buffs.active().is_empty(),"Reliable removal event clears local effects")
	client.free()
	# Loot effects operate on real rolls and preserve item families.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1298
	check(Loot.upgrade(Items.make("G3_bow"),1.0,rng).id=="G4_bow","100% tier effect promotes one tier")
	check(Loot.upgrade(Items.make("G8_bow"),1.0,rng).id=="G8_bow","Tier upgrades respect G8 cap")
	check(Loot.upgrade(Items.make("elixir_hp"),1.0,rng).id=="elixir_hp","Consumables never upgrade")
	check(Loot.upgrade(Items.make("G5_spell"),1.0,rng).id=="G5_spell","Missing next tier leaves original item")
	var def := EnemyDef.new()
	def.hp = 100
	def.loot = [{item="G2_bow",chance=.2}]
	var baseline := 0
	var boosted := 0
	for i in 4000:
		baseline += Loot.roll(def,{pid:100},rng).size()
		boosted += Loot.roll(def,{pid:100},rng,"magic",0,{pid:{chance=.5,tier=0.0}}).size()
	check(baseline>650 and baseline<950 and boosted>1050 and boosted<1350,"50% loot chance bonus changes 20% drops to 30%")
	def.loot = [{item="G4_bow",chance=1.0}]
	var upgraded := Loot.roll(def,{pid:100},rng,"magic",0,{pid:{chance=0.0,tier=1.0}})
	check(upgraded.size()==1 and upgraded[0].items[0].id=="G5_bow" and upgraded[0].viewer==pid,"Upgrade across soulbound boundary gets a personal bag")
	# HUD wrap, banner colors and centered authored icons.
	var simultaneous: Array = StatusEffects.IDS.filter(func(id: String) -> bool: return id not in ["immune", "invincible"])
	for id in simultaneous:
		GameServer.apply_buff(pid,id,120,1)
	var strip := BuffStrip.new()
	strip.effects = stats.buffs
	add_child(strip)
	strip._process(0)
	check(strip._badges.size()==simultaneous.size(),"Every supported effect has a HUD banner")
	var cards: Array = strip._badges.values()
	check(cards[4].position.y<cards[0].position.y and cards[4].position.x==cards[0].position.x,"Fifth banner wraps into a row above")
	for e: Dictionary in stats.buffs.active():
		var badge := BuffArt.badge(e)
		check(badge!=null and badge.get_width()==18 and badge.get_height()==18,"Outlined 18x18 composite exists for "+str(e.id))
	player.status_visuals._process(.3)
	check(player.status_visuals._ice.visible and player.status_visuals._quiet.visible,"Ice and Quiet voxel effects show on character")
	check(player.status_visuals._flags.size()==simultaneous.size(),"Every active effect has an overhead icon")
	check(not player.status_visuals.nameplate.text.is_empty(),"Local player has an overhead name")
	stats.buffs.clear()
	strip._process(0)
	check(strip._badges.is_empty(),"Expired effects leave HUD and play exit animations")
	for protection in ["immune", "invincible"]:
		GameServer.apply_buff(pid,"quiet",10)
		GameServer.apply_buff(pid,"speed",10,-3,"negative")
		check(GameServer.apply_buff(pid,protection,3),"Protection can be applied: " + protection)
		check(not stats.buffs.has_effect("quiet") and not stats.buffs.has_effect("speed"),"Protection clears negative effects")
		check(not GameServer.apply_buff(pid,"static",10),"Protection rejects control effects")
		check(BuffArt.badge(stats.buffs.active()[0]) != null,"Protection has a visible badge")
		stats.buffs.clear()
	GameServer.apply_buff(pid,"attack",10,1)
	GameServer.revive(pid)
	check(stats.buffs.active().is_empty(),"Changing character clears previous effects")
	stats.hp = 1.0
	var survived := player.take_damage(50000,true)
	if survived: player.receive_attack_effects({effects=[{id="quiet",duration=3}]})
	check(not survived and not stats.buffs.has_effect("quiet"),"A lethal projectile cannot apply statuses to the new offline character")
	print("STATUS EFFECTS: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
