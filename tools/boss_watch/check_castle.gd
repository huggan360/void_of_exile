extends Node3D
## Small offline integration check: real waves, key validation and replicated event shape.
var world: CastleWorld
var player := Player.new()
var bullets := EnemyBullets.new()
func _ready() -> void:
	# Exercise the exact server world factory, in an isolated physics viewport.
	var realm := RealmInstance.new({id = "cst_factory_check", castle = true, name = "Factory Check"})
	add_child(realm)
	assert(realm.world is CastleWorld)
	assert(realm.world.realm_id == "cst_factory_check")
	assert(realm.world.server_build)
	assert(realm.world.gates.states().is_empty())
	realm.queue_free()
	GameServer.debug_godmode = true
	world = load("res://scenes/castle/hollow_castle.tscn").instantiate()
	world.realm_id = "cst_check_king"
	add_child(world)
	add_child(bullets)
	player.player_id = GameServer.join(false)
	player.stats = GameServer.character(player.player_id)
	GameServer.enter_realm(player.player_id, world.realm_id)
	add_child(player)
	player.set_physics_process(false)
	player.frozen = false
	player.position = Vector3(0, 0, 7)
	bullets.players = [player]
	world.enemy_director.setup(player, bullets, [], {})
	await get_tree().create_timer(5.5).timeout
	assert(world.encounter.stage == 1)
	assert(world.encounter._living.size() == 2)
	for guard in world.encounter._living.duplicate(): guard.take_hit(guard.global_position, Vector3.ZERO, 999999, player)
	await get_tree().create_timer(3.0).timeout
	assert(world.encounter.stage == 2)
	assert(world.encounter._living.size() == 2)
	for guard in world.encounter._living.duplicate(): guard.take_hit(guard.global_position, Vector3.ZERO, 999999, player)
	assert(world.encounter.stage == 3)
	var bags := GameServer.bags_in(world.realm_id, player.player_id)
	assert(bags.any(func(b: Dictionary) -> bool: return b.type == "story"))
	var peer := {player_id = player.player_id, realm = world.realm_id, pos = Vector3(0, 0, -25)}
	world.encounter.on_action(peer, ["door"])
	assert(world.encounter.stage == 3, "Door opened without key")
	player.stats.give([Items.make("story_throne_key")])
	peer.pos = Vector3.ZERO
	world.encounter.on_action(peer, ["door"])
	assert(world.encounter.stage == 3, "Door opened at a distance")
	peer.pos = Vector3(0, 0, -25)
	world.encounter.on_action(peer, ["door"])
	assert(world.encounter.stage == 4)
	assert(player.stats.find_item("story_throne_key").is_empty())
	world.castle_event([0.0, "castle", "state", 4])
	await get_tree().create_timer(9.5).timeout
	assert(world.encounter.stage == 5)
	assert(is_instance_valid(world.encounter.king))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2701
	var found7 := false
	var found8 := false
	for roll in 30:
		for bag in Loot.roll(Enemies.get_def("hollow_king"), {player.player_id:72000}, rng):
			for item in bag.items:
				if item.tier == 7: found7 = true
				if item.tier == 8: found8 = true
	assert(found7 and found8, "King grade loot was capped")
	var arrows := Arrows.new()
	add_child(arrows)
	for id in Items.DIVINE_SETS.Iron:
		var item := Items.make(id)
		if item.is_weapon():
			assert(not item.charge.is_empty())
			assert(arrows._meshes_for(item, item.projectile.style).size() == 2)
	print("[castle-check] Guardians, champions, story chest, key/range checks, key consumption, timestamp events, king spawn and G7/G8/Iron loot passed")
	get_tree().quit()
