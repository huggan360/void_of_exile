extends Node3D
## Fast runtime smoke check, without world generation or account persistence.
const IDS := ["blue_dragon","rimeheart_prism","vharok","scarab_regent","hollow_crown",
	"thornmaw_bloom","goblin_king","abyssal_siren","drowned_cantor","gilded_vizier","magma_warden","pyre_ent","hollow_king"]
var checks := 0
var failures := 0

class FloorWorld:
	extends GameWorld
	var wet := false
	func ground_height(_x: float, _z: float) -> float: return 0.0
	func is_water(_pos: Vector3) -> bool: return wet

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _ready() -> void: _run.call_deferred()

func _run() -> void:
	GameServer.set_physics_process(false)
	var world := FloorWorld.new()
	world.realm_id = "burning_smoke_fixture"
	add_child(world)
	var ground := StaticBody3D.new()
	ground.collision_layer = Player.TERRAIN_LAYER
	var collider := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(200,1,200)
	collider.shape = slab
	collider.position.y = -0.5
	ground.add_child(collider)
	world.add_child(ground)
	GameServer.set_environment(world)
	var pid := GameServer.join(false)
	var stats := GameServer.character(pid)
	stats.base_hp = 1000
	stats.hp = stats.max_hp
	stats.base.defense = 100
	GameServer.report_position(pid,world.realm_id,Vector3(0,0,12))
	check(GameServer.apply_buff(pid,"burning",10),"Burning applies to a player")
	var expires: float = stats.buffs.entries["burning:fire"].expires
	GameServer.apply_buff(pid,"burning",3)
	check(stats.buffs.active().size()==1 and stats.buffs.entries["burning:fire"].expires==expires,"Burns do not stack or shorten a heavy burn")
	GameServer.set_shield(pid,false)
	var hp := stats.hp
	GameServer._tick_vitals(GameServer._players[pid],1.0)
	check(hp-stats.hp>=10 and hp-stats.hp<=15,"Burning player loses 10-15 HP through 100 defence")
	world.wet = true
	GameServer._players[pid].environment_timer = 0.0
	GameServer._tick_vitals(GameServer._players[pid],0.02)
	check(not stats.buffs.has_effect("burning"),"Water extinguishes the player")
	check(not GameServer.apply_buff(pid,"burning",10),"Fire cannot ignite a player already in water")
	world.wet = false
	check(BuffArt.badge({id="burning",amount=1})!=null,"Burning icon loads")
	var fire := VoxelFire.new()
	world.add_child(fire)
	await get_tree().process_frame
	world.update_burning_contact(stats.buffs,Vector3.ZERO)
	check(stats.buffs.has_effect("burning") and stats.buffs.entries["burning:fire"].duration==3.5,"Firepit contact ignites for 3.5 seconds")
	fire.free()
	stats.buffs.clear()
	var heavy := Burning.projectile(Boss.shot("flame_shard",Color.ORANGE,Vector2i(50,60),7,0.2,20),"vharok")
	check(heavy.effects.any(func(e: Dictionary) -> bool: return e.id=="burning" and e.duration==10.0),"Vharok shard burns for ten seconds")
	check(Items.make("D_bow_dragon").attack_effects().any(func(e: Dictionary) -> bool: return e.id=="burning"),"Player fire weapon carries Burning")
	var player := Player.new()
	player.player_id = pid
	player.stats = stats
	world.add_child(player)
	player.set_physics_process(false)
	player.set_process(false)
	player.global_position = Vector3(0,0,12)
	player.frozen = false
	var bullets := EnemyBullets.new()
	bullets.players = [player]
	world.add_child(bullets)
	bullets.set_physics_process(false)
	var director := EnemyDirector.new()
	director.world = world
	director.realm_id = world.realm_id
	world.add_child(director)
	director.setup(player,bullets,[])
	director.set_process(false)
	director.set_physics_process(false)
	var enemy_pack := EnemyPack.new()
	enemy_pack.site = {id="smoke_enemy",pos=Vector3(20,0,0),seed=1,pack=""}
	var enemy := Enemy.new().setup(Enemies.get_def("magma_imp"),enemy_pack,director)
	enemy.position = Vector3(20,0,0)
	director.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.state = Enemy.State.ACTIVE
	enemy.defense = 100
	enemy.buffs.add("burning",10)
	var enemy_hp := enemy.hp
	enemy._tick_burning(1.0)
	check(enemy_hp-enemy.hp>=10 and enemy_hp-enemy.hp<=15,"Enemy Burning bypasses 100 defence")
	world.wet = true
	enemy._environment_timer = 0.0
	enemy._tick_burning(0.02)
	check(not enemy.buffs.has_effect("burning"),"Water extinguishes an enemy")
	world.wet = false
	enemy.queue_free()
	GameServer.debug_godmode = true
	for id: String in IDS:
		var def := Enemies.get_def(id)
		var pack := EnemyPack.new()
		pack.site = {id="smoke_"+id,pos=Vector3.ZERO,seed=123,pack=""}
		var boss := EnemyDirector._make_actor(def).setup(def,pack,director) as Boss
		pack.members.append(boss)
		pack.leader = boss
		director.add_child(boss)
		boss.set_physics_process(false)
		# Ordinary near-waking bosses first complete their normal spawn tween.
		if boss.state==Enemy.State.SPAWNING: await get_tree().create_timer(1.2).timeout
		check(not boss.buffs.add("burning",10),id+": immune to Burning")
		if boss.is_sealed(): boss._hit_shell(boss.shell_max,pid)
		else: boss.activate()
		check(boss.state==Enemy.State.INTRO,id+": intro activates")
		boss._physics_process(boss.intro_duration+0.01)
		check(boss.state==Enemy.State.ACTIVE,id+": intro reaches combat")
		for phase in def.phases.size():
			if phase>0: boss._enter_phase(phase)
			boss._combat(0.1)
			boss._run_cycle(2.0)
			boss._update_scheduled(2.0)
			boss.model.animate(0.5,0.1)
			check(boss.model.hand_position().is_finite(),id+": phase %d has valid joints" % phase)
			boss.hazards.clear()
			boss.despawn_support()
		boss._start_dying()
		boss._update_dying(0.05)
		check(boss.state==Enemy.State.DYING,id+": death starts")
		boss._release_encounter()
		boss.queue_free()
		bullets.clear()
		await get_tree().process_frame
		print("BOSS SMOKE: ",id," completed")
	print("BOSS/BURNING SMOKE: %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
