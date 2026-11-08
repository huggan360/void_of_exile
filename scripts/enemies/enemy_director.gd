class_name EnemyDirector
extends Node3D
## Brings a world's enemies to life. Pack sites come from the world seed
## (registered as their terrain chunk loads); a pack only appears when the
## player comes within its activate_radius, and goes back to sleep (keeping
## its survivors) once the player is far away and nobody is fighting.
##
## Wiped-out packs respawn after their respawn_time. Packs with
## respawn_time -1 never come back: the server remembers them, so each realm
## only ever has the ones it started with.
##
## Every player in the world counts (`players`): packs wake near any of
## them and sleep once all are far away, and each enemy goes after the one
## nearest to it. On an online client the director stays idle (`remote`):
## the server runs the enemies and Net shows them here.

const CHECK_INTERVAL := 0.25
const SLEEP_DISTANCE := 70.0

## Any enemy here died (campaign kill quests count these).
signal enemy_killed(enemy: Enemy)

var world: GameWorld
var realm_id := ""
## The local player offline (the first of `players`).
var player: Player
## Everyone enemies can see and chase here: Players, or on the server
## NetPlayerProxy stand-ins for the connected players.
var players: Array = []
var bullets: EnemyBullets
## Online client: enemies come from the server, none are spawned here.
var remote := false
## Enemy ids that may not appear in this world (a campaign holds them back).
var banned: Array = []

var _sites := {}  # site id -> site
var _sites_by_chunk := {}  # Vector2i -> Array[site id]
var _awake := {}  # site id -> EnemyPack
## site id -> {survivors: Array (null = full pack), back_at: msec or -1 forever}
var _memory := {}
var _timer := 0.0


func setup(p_player: Player, p_bullets: EnemyBullets, cleared: Array, saved_survivors: Dictionary = {}) -> void:
	player = p_player
	if p_player != null and not p_player in players:
		players.append(p_player)
	bullets = p_bullets
	# Worlds with rolling ground (planet tops) keep shots at shot height over it.
	bullets.ground_follow = world.bullet_ground if world != null and world.has_method("bullet_ground") else Callable()
	for id in saved_survivors:
		var living: Array = saved_survivors[id]
		_memory[id] = {survivors = living.duplicate(), back_at = -1 if living.is_empty() else 0, finite = true}
	for id in cleared:
		_memory[id] = {survivors = [], back_at = -1}


func add_sites(chunk: Vector2i, sites: Array[Dictionary]) -> void:
	_sites_by_chunk[chunk] = []
	for site in sites:
		_sites[site.id] = site
		_sites_by_chunk[chunk].append(site.id)


func remove_chunk(chunk: Vector2i) -> void:
	for id in _sites_by_chunk.get(chunk, []):
		if not _awake.has(id):
			_sites.erase(id)
	_sites_by_chunk.erase(chunk)


## The nearest player that can be chased from `pos` (null if nobody's here).
func target_for(pos: Vector3) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for p in players:
		if not is_instance_valid(p) or p.frozen or SpaceLayout.pocket_at(p.global_position)>=0:
			continue
		var d: float = Vector2(p.global_position.x - pos.x, p.global_position.z - pos.z).length_squared()
		if d < best_d:
			best = p
			best_d = d
	if best == null and not players.is_empty() and is_instance_valid(players[0]) and SpaceLayout.pocket_at(players[0].global_position)<0:
		return players[0]
	return best


## Flat distance from `pos` to the nearest active player.
func _nearest_distance(pos: Vector3) -> float:
	var nearest := INF
	for p in players:
		if not is_instance_valid(p) or p.frozen: continue
		var at: Vector3 = p.global_position
		var slot := SpaceLayout.pocket_at(at)
		if slot>=0:
			var fleet: SpaceWorld = world if world is SpaceWorld else world.surface_ships if world is IslandWorld else null
			var ship := fleet.ship_in_slot(slot) if fleet else null
			if ship==null or ship.mode!="landed": continue
			at = ship.xform.origin
		nearest = minf(nearest, Vector2(at.x-pos.x, at.z-pos.z).length())
	return nearest


func _process(delta: float) -> void:
	if not FrameTrace.enabled: _profile_process(delta); return
	var started := Time.get_ticks_usec()
	_profile_process(delta)
	FrameTrace.record("enemies/enemy_director",started)

func _profile_process(delta: float) -> void:
	if remote or players.all(func(p: Variant) -> bool: return not is_instance_valid(p) or p.frozen):
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = CHECK_INTERVAL
	var now := Time.get_ticks_msec()
	for id in _sites:
		if _awake.has(id):
			continue
		var site: Dictionary = _sites[id]
		var memory: Dictionary = _memory.get(id, {})
		if memory.get("back_at", 0) == -1 or now < memory.get("back_at", 0):
			continue  # wiped out (for now, or for good)
		var reach: float = _site_definition(site).activate_radius
		if _nearest_distance(site.pos) < reach:
			_wake(site, memory.get("survivors", null))
	for id in _awake.keys():
		var pack: EnemyPack = _awake[id]
		var far := _nearest_distance(pack.site.pos) > SLEEP_DISTANCE
		if far and not pack.any_fighting():
			_sleep(pack)


func _site_definition(site: Dictionary) -> Dictionary:
	var formation: Dictionary = site.get("formation", {})
	return Enemies.pack(site.pack) if formation.is_empty() else formation


## Spawns a pack: rolls its members from the site's seed (or brings back the
## survivors from last time).
func _wake(site: Dictionary, survivors: Variant) -> void:
	var def := _site_definition(site)
	var rng := RandomNumberGenerator.new()
	rng.seed = site.seed
	var ids: Array = []
	if survivors is Array:
		ids = survivors.duplicate()
	else:
		for m in def.members:
			if m.has("chance") and rng.randf() >= m.chance:
				continue
			for i in rng.randi_range(m.min, m.max):
				ids.append(m.enemy)
		if def.has("leader") and ids.size() >= def.leader.min_members:
			ids.push_front(def.leader.enemy)
	if not str(site.id).begins_with("quest_") and not banned.is_empty() and ids.any(func(id: String) -> bool: return id in banned):
		ids = ids.filter(func(id: String) -> bool: return not id in banned)
		if ids.is_empty():  # not cleared: they may come back once allowed
			_memory[site.id] = {survivors = null, back_at = Time.get_ticks_msec() + 15000}
			return
	if ids.is_empty():
		_memory[site.id] = {survivors = [], back_at = -1}
		return
	var pack := EnemyPack.new()
	pack.site = site
	pack.respawn_time = -1.0 if str(site.id).begins_with("quest_") or _memory.get(site.id,{}).get("finite",false) else float(def.get("respawn_time",120.0))
	for id: String in ids:
		if Enemies.get_def(id).is_god or Enemies.get_def(id) is BossDef:
			pack.respawn_time = -1.0
	pack.wiped_out.connect(_on_wiped_out)
	pack.members_changed.connect(_on_members_changed)
	# Plan the whole pack first. If no safe layout exists, retry later with
	# the SAME member ids; never replace a blocked spot with the unsafe center.
	var placements: Array = []
	for i in ids.size():
		var enemy_def := scaled_definition(Enemies.get_def(ids[i]))
		var offset := Vector3.FORWARD.rotated(Vector3.UP, rng.randf() * TAU) * (0.0 if i == 0 else rng.randf_range(1.5, 4.5))
		var spot := find_spawn_position(site.pos + offset, enemy_def, placements, site.pos, str(site.id).begins_with("quest_"))
		if spot.is_empty():
			_memory[site.id] = {survivors = ids.duplicate(), back_at = Time.get_ticks_msec() + 2000, finite = pack.respawn_time<0}
			return
		placements.append({pos = spot.pos, radius = enemy_def.hit_radius * enemy_def.model_scale})
	for i in ids.size():
		var enemy_def := scaled_definition(Enemies.get_def(ids[i]))
		var enemy := _make_actor(enemy_def).setup(enemy_def, pack, self)
		enemy.position = to_local(placements[i].pos)
		add_child(enemy)
		enemy.died.connect(pack._on_member_died)
		enemy.died.connect(func(e: Enemy) -> void: enemy_killed.emit(e))
		pack.members.append(enemy)
		if def.has("leader") and ids[i] == def.leader.enemy and pack.leader == null:
			pack.leader = enemy
	# A saved survivor group can predate a spawn-table rebalance. Keep its god
	# leader and finite lifecycle, rather than converting it into a respawning pack.
	if pack.leader==null and def.has("leader"):
		for member in pack.members:
			if member.def.is_god:
				pack.leader = member
				break
	if def.has("patrol_radius") and ids.all(func(id: String) -> bool: return id=="bile_bandit"):
		pack.patrol = EnemyPatrol.new(world,pack.leader.global_position,int(site.seed),float(def.patrol_radius))
	# Orbiters (a spirit's stars) spread evenly around their circle.
	var orbiters := pack.members.filter(func(e: Enemy) -> bool: return e.def.behavior == "orbit")
	for i in orbiters.size():
		orbiters[i].orbit_angle = TAU * i / orbiters.size()
	_awake[site.id] = pack


## Bosses with their own fight use its script; other bosses the shared one.
static func _make_actor(enemy_def: EnemyDef) -> Enemy:
	if enemy_def is BossDef:
		var script_path: String = (enemy_def as BossDef).actor_script
		return load(script_path).new() if script_path != "" else Boss.new()
	return Enemy.new()


## A boss's minion appears at `pos` and joins the fight right away. Minions
## don't come back when the pack wakes up again.
func spawn_minion(def_id: String, pos: Vector3, pack: EnemyPack) -> Enemy:
	var enemy_def := scaled_definition(Enemies.get_def(def_id))
	var reserved: Array = []
	for member in pack.members:
		if is_instance_valid(member) and member.is_alive():
			reserved.append({pos = member.global_position, radius = member.def.hit_radius * member.def.model_scale})
	var spot := find_spawn_position(pos, enemy_def, reserved, pack.site.pos)
	if spot.is_empty():
		return null
	var minion := Enemy.new().setup(enemy_def, pack, self)
	minion.is_minion = true
	minion.position = to_local(spot.pos)
	add_child(minion)
	minion.died.connect(pack._on_member_died)
	pack.members.append(minion)
	minion.activate.call_deferred()
	return minion


## A pack site placed by a quest (not part of the terrain's chunks): it
## wakes like any other when a player comes close, and stays gone once wiped out.
func add_quest_site(site: Dictionary) -> void:
	if _sites.has(site.id):
		return
	_sites[site.id] = site


func _on_members_changed(pack: EnemyPack) -> void:
	if pack.respawn_time >= 0.0:
		return
	var survivors := pack.survivors()
	_memory[pack.site.id] = {survivors = survivors, back_at = -1 if survivors.is_empty() else 0, finite = true}
	WorldServer.report_pack_survivors(realm_id, pack.site.id, survivors)


func _sleep(pack: EnemyPack) -> void:
	_on_members_changed(pack)
	_memory[pack.site.id] = {survivors = pack.survivors(), back_at = 0, finite = pack.respawn_time<0}
	for m in pack.members:
		if is_instance_valid(m):
			m.queue_free()
	_awake.erase(pack.site.id)


func _on_wiped_out(pack: EnemyPack) -> void:
	var respawn: float = pack.respawn_time
	_awake.erase(pack.site.id)
	if respawn < 0.0:
		_memory[pack.site.id] = {survivors = [], back_at = -1}
		WorldServer.report_pack_cleared(realm_id, pack.site.id)
	else:
		_memory[pack.site.id] = {survivors = null, back_at = Time.get_ticks_msec() + int(respawn * 1000.0)}


func _exit_tree() -> void:
	for pack: EnemyPack in _awake.values():
		_on_members_changed(pack)


## Every enemy currently awake (for debugging and future systems).
func enemies() -> Array[Enemy]:
	var out: Array[Enemy] = []
	for pack: EnemyPack in _awake.values():
		for m in pack.members:
			if is_instance_valid(m):
				out.append(m)
	return out


## Seed-independent, deterministic nearby search, shared by packs and boss summons.
func find_spawn_position(origin: Vector3, enemy_def: EnemyDef, reserved: Array = [], anchor: Vector3 = Vector3.INF, campaign_site := false) -> Dictionary:
	var radius := enemy_def.hit_radius * enemy_def.model_scale
	var height := maxf(enemy_def.body_height * enemy_def.model_scale, radius * 2.0)
	var home := origin if anchor == Vector3.INF else anchor
	var biome_id := world.biome_at(home).id
	for ring: float in [0.0, 2.0, 4.0, 7.0, 11.0, 17.0, 25.0, 36.0]:
		for i in (1 if ring == 0.0 else 16):
			var angle := TAU * i / 16.0
			var candidate := origin + Vector3(cos(angle), 0, sin(angle)) * ring
			candidate.y = world.enemy_floor(candidate) if world.has_method("enemy_floor") else world.ground_height(candidate.x, candidate.z)
			if campaign_site and Vector2(candidate.x - home.x, candidate.z - home.z).length() > 20.0:
				continue
			if world is IslandWorld and (world as IslandWorld).generator._near_town(Vector2(candidate.x,candidate.z)):
				continue
			if world.biome_at(candidate).id != biome_id or not world.enemy_spawn_clear(candidate, radius, height):
				continue
			if campaign_site and world is IslandWorld and not Campaigns.spawn_clear(candidate, world, radius, height):
				continue
			var overlaps := false
			for other: Dictionary in reserved:
				if Vector2(candidate.x - other.pos.x, candidate.z - other.pos.z).length() < radius + other.radius + 0.2:
					overlaps = true
					break
			if not overlaps:
				return {pos = candidate}
	return {}


func scaled_definition(original: EnemyDef) -> EnemyDef:
	if not world is DungeonWorld: return original
	var definition: Dictionary = world.definition
	var result: EnemyDef = original.duplicate(true)
	result.hp = roundi(result.hp * float(definition.enemy_hp_multiplier))
	if result is BossDef and result.id == definition.boss: result.dungeon_reward = true
	for attack in result.attacks:
		attack.damage_min = roundi(attack.get("damage_min", 0) * float(definition.enemy_damage_multiplier))
		attack.damage_max = roundi(attack.get("damage_max", 0) * float(definition.enemy_damage_multiplier))
	for entry in result.loot:
		if entry.has("pool"): entry.pool.tier = clampi(int(entry.pool.tier) + int(definition.loot_tier_bias), 1, 6)
	return result
