extends Node
var checks := 0
var failures := 0
const OLD_GODS := ["basalt_bulwark","furnace_maw","cinder_oracle","rime_stag","glacier_hermit","hail_harrier"]
class PatrolWorld:
	extends GameWorld
	func ground_height(_x: float,_z: float) -> float: return 0.0
	func biome_at(_pos: Vector3) -> BiomeDef: return Biomes.get_biome(Biomes.DEEP_DARK)
	func is_walkable(pos: Vector3) -> bool: return absf(pos.x)<50 and absf(pos.z)<50
func check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(text)
func _ready() -> void: _run.call_deferred()
func _run() -> void:
	var stats := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 8303
	var shots := EnemyBullets.new()
	add_child(shots)
	for spec: Dictionary in RealmEnemyExpansion.GODS:
		var e := Enemies.get_def(spec.id)
		check(e.is_god and not e is BossDef,"New world god is not a boss: "+e.id)
		check(Enemies.PACKS[e.id+"_pack"].respawn_time<0,"New god is finite: "+e.id)
		CreatureModel.preload_creature(e.model)
		for attack in e.attacks: check(shots._mesh_for(attack)!=null,"Authored projectile loads: "+e.id)
		var actor := Enemy.new()
		actor.def = e
		for stat in e.god_potion_stats: stats[stat] = true
		for i in 30:
			var potion := Loot._make({biome_stat=true},rng,actor._potion_stats())
			check(potion.consumable.stat in spec.stats and potion.bag_type()=="blue","Actual god death potion resolves its own signature")
		actor.free()
		for i in 25:
			for bag in Loot.roll(e,{1:e.hp},rng,e.god_potion_stats):
				for item in bag.items:
					check(not item.is_divine() and (item.is_consumable() or item.tier<=5),"God loot cannot exceed G5 or drop divine")
	check(stats.size()==7,"Every permanent stat potion has a new realm god source")
	for spec: Dictionary in RealmEnemyExpansion.COMMON:
		var e := Enemies.get_def(spec.id)
		check(not e.is_god,"Lesser creature stays regular")
		CreatureModel.preload_creature(e.model)
	for id in OLD_GODS:
		check(Enemies.get_def(id).is_god,"Batch 2 remains registered")
		check(Enemies.PACKS[id+"_pack"].respawn_time<0,"Batch 2 remains finite")
	var all_seen := {}
	for seed_value in [20261031,17,99123]:
		var gen := IslandGenerator.new(seed_value)
		var big := gen.pack_sites(Rect2i(-448,-448,896,896),[])
		var streamed := {}
		for z in range(-448,448,32):
			for x in range(-448,448,32):
				for site in gen.pack_sites(Rect2i(x,z,32,32),[]):
					check(not streamed.has(site.id),"Streaming never duplicates a pack across a chunk edge")
					streamed[site.id] = site
		check(streamed.size()==big.size(),"Chunk streaming preserves every planned site for seed "+str(seed_value))
		for site in big:
			check(streamed.has(site.id) and streamed[site.id]==site,"Chunk/world site definitions match exactly")
			all_seen[site.pack] = true
			check(not gen._near_town(Vector2(site.pos.x,site.pos.z)),"No pack site enters a town safety area")
			var biome := gen.column(floori(site.pos.x),floori(site.pos.z)).y
			for spec: Dictionary in RealmEnemyExpansion.GODS:
				if site.pack==spec.id+"_pack": check(biome==spec.biome,"God is in its assigned biome")
			if site.pack=="bile_bandit_patrol": check(biome==Biomes.DEEP_DARK,"Bile patrol only lives in Deep Dark")
		for biome in [Biomes.DOOM,Biomes.FOSEN,Biomes.BLUELAY,Biomes.DESERT,Biomes.DEEP_DARK]:
			var found := 0
			var density := 0.0
			for entry in Biomes.get_biome(biome).enemy_packs:
				density += entry.density
				for spec: Dictionary in RealmEnemyExpansion.GODS:
					if spec.biome==biome and entry.pack==spec.id+"_pack": found += 1
			check(found==3 and density<=.86 and density>=.65,"Three new gods per boss biome, with bounded encounter density")
	for spec: Dictionary in RealmEnemyExpansion.GODS:
		check(all_seen.has(spec.id+"_pack"),"Every new god actually occurs in the fixture realms")
	for id in OLD_GODS: check(all_seen.has(id+"_pack"),"Every batch 2 god actually occurs in the fixture realms")
	await _test_patrol(shots)
	shots.free()
	print("REALM EXPANSION 03: ",checks," checks; ",failures," failures")
	get_tree().quit(1 if failures else 0)

func _test_patrol(shots: EnemyBullets) -> void:
	var world := PatrolWorld.new()
	add_child(world)
	var floor := StaticBody3D.new()
	floor.collision_layer = Player.TERRAIN_LAYER
	var collider := CollisionShape3D.new()
	var slab := BoxShape3D.new()
	slab.size = Vector3(110,1,110)
	collider.shape = slab
	collider.position.y = -.5
	floor.add_child(collider)
	world.add_child(floor)
	var wall := StaticBody3D.new()
	wall.collision_layer = Player.OBSTACLE_LAYER
	var wall_collider := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(2,4,12)
	wall_collider.shape = wall_box
	wall_collider.position = Vector3(5,2,0)
	wall.add_child(wall_collider)
	world.add_child(wall)
	var player := Player.new()
	player.stats = PlayerStats.new()
	world.add_child(player)
	player.set_physics_process(false)
	player.frozen = false
	player.position = Vector3(40,0,40)
	var director := EnemyDirector.new()
	director.world = world
	director.realm_id = "expansion03_fixture"
	world.add_child(director)
	director.setup(player,shots,[])
	director.set_process(false)
	await get_tree().physics_frame
	# Exercise real actor construction and attack execution for every god,
	# including all six batch-2 types, rather than only inspecting registries.
	var production_ids: Array = RealmEnemyExpansion.GODS.map(func(spec: Dictionary) -> String: return spec.id)
	production_ids.append_array(OLD_GODS)
	for index in production_ids.size():
		var id: String = production_ids[index]
		var god_site := {id="god_"+id,pack=id+"_pack",pos=Vector3(-28+(index%7)*8,0,-28+(index/7)*12),seed=918+index}
		director._wake(god_site,null)
		check(director._awake.has(god_site.id),"Production god pack instantiates through director: "+id)
		if director._awake.has(god_site.id):
			var live: EnemyPack = director._awake[god_site.id]
			check(live.respawn_time<0,"Production pack captures finite lifecycle")
			for member in live.members:
				member.set_physics_process(false)
				if member.def.is_god:
					member._fire(member.def.attacks[0])
					member._update_volleys(.1)
					check(not shots._shots.is_empty(),"Production god executes its actual attack")
					shots.clear()
	await get_tree().process_frame
	var site := {id="torch_patrol",pack="bile_bandit_patrol",pos=Vector3.ZERO,seed=611}
	director._wake(site,null)
	check(director._awake.has(site.id),"Bile patrol wakes through actual director")
	var pack: EnemyPack = director._awake[site.id]
	check(pack.members.size()==3 and pack.patrol!=null,"Exactly three bandits share one patrol navigator")
	for member in pack.members:
		check(member._torch!=null and member._torch.omni_range>=6,"Each bandit has a real environment light")
	var nav := pack.patrol
	var first := nav._id(Vector3(-10,0,0))
	var last := nav._id(Vector3(10,0,0))
	var detour := nav.grid.get_point_path(first,last)
	check(detour.size()>20,"Patrol grid can route around a wall rather than through it")
	for point in detour:
		check(not (point.x>3.5 and point.x<6.5 and absf(point.y)<6.5),"Patrol navigation path clears the wall capsule margin")
	var before: Vector3 = pack.leader.global_position
	await get_tree().create_timer(5).timeout
	check(pack.leader.global_position.distance_to(before)>2,"Idle patrol actually roams rather than standing around its spawn")
	for member in pack.members:
		check(member.global_position.distance_to(pack.leader.global_position)<9,"Patrol companions stay with their leader")
		check(not member.global_position.x>4 or absf(member.global_position.z)>5.8,"Patrol avoids the solid test wall")
	player.position = pack.leader.global_position+Vector3(0,0,-8)
	await get_tree().create_timer(.35).timeout
	for member in pack.members: check(member.state==Enemy.State.ACTIVE,"Patrol alerts together on seeing an invader")
	pack.leader._fire(Enemies.get_def("bile_bandit").attacks[0])
	check(not shots._shots.is_empty(),"Bandit casts an actual fire projectile")
	if not shots._shots.is_empty():
		check(shots._shots[-1].node.get_node_or_null("ProjectileLight") is OmniLight3D,"Fire projectile carries a real moving light")
	for i in 20: shots.fire(Vector3(0,1,0),Vector3.FORWARD,Enemies.get_def("bile_bandit").attacks[0])
	check(get_tree().get_nodes_in_group("enemy_projectile_lights").size()<=12,"Fire lighting has a bounded live-light budget")
	shots.clear()
	await get_tree().process_frame
	check(get_tree().get_nodes_in_group("enemy_projectile_lights").is_empty(),"Projectile lights are freed with the shots")
	# Existing finite survivor records stay finite even when a rebalanced site
	# now selects an ordinary pack. The dead god is not reconstructed.
	director._memory["migrated_finite"] = {survivors=["star","genie_brown"],back_at=0,finite=true}
	var legacy_site := {id="migrated_finite",pack="dune_crawler_pack",pos=Vector3(-35,0,0),seed=61}
	director._wake(legacy_site,["star","genie_brown"])
	var legacy: EnemyPack = director._awake[legacy_site.id]
	check(legacy.respawn_time<0 and legacy.members.size()==2,"Old finite survivor records retain their lifecycle after table changes")
	check(not legacy.members.any(func(e: Enemy) -> bool: return e.def.is_god),"Dead saved god is never resurrected by the rebalance")
	world.queue_free()
	await get_tree().process_frame
	WorldServer.reset_realm("expansion03_fixture")
