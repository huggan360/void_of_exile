class_name NetClient
extends Node
## The game's side of a connection (Net.client). Main attaches the world
## and the local player; this then
##
##   * keeps a clock in step with the server's and shows everything
##     Net.INTERP_DELAY in the past: enemies and other players move smoothly
##     between snapshots, and events play at the moment they happened
##   * builds a mirror of every enemy near you (the real Enemy/Boss class
##     with mirror = true) and a RemotePlayer for every other player
##   * replays the server's events: enemy shots and ripples (flown here, so
##     this client decides whether you were hit), hazards, voxel bursts,
##     damage numbers, loot bags, XP, other players' shots...
##   * sends what you do, predicting a few things so they feel instant
##     (a hit you take, a ring's magic): the server's numbers replace the
##     prediction once it has seen the same thing

signal welcomed(info: Dictionary)
signal refused(reason: String)
signal lost(reason: String)
signal entered(record: Dictionary)
signal died(info: Dictionary)
## The account's total XP changed (a character earned some).
signal account_xp(total: int)
## Now playing another character (character id, class).
signal switched(character_id: int, class_id: String)
signal switch_failed(reason: String)
## A chat, party, campaign or teleport event (see SocialServer).
signal social_event(ev: Array)

const CONNECT_TIMEOUT := 8.0
const SEND_RATE := 20.0
const KEEP_SNAPSHOTS := 8
const PLAYER_PREDICTION_LIMIT := 0.10
const PLAYER_MAX_PREDICT_SPEED := 20.0
const PLAYER_TELEPORT_DISTANCE := 6.0

var address := ""
var port := Net.DEFAULT_PORT
var token := ""
var character_id := 0
var account_name := ""
var info := {}
var connected := false
## Round trip to the server in seconds (from its pings).
var rtt := 0.0

# What Main attaches for the current place.
var world: GameWorld
var director: EnemyDirector
var bullets: EnemyBullets
var arrows: Arrows
var player: Player
var stats: PlayerStats

var _peer := ENetMultiplayerPeer.new()
var _connect_left := CONNECT_TIMEOUT
var _offset := 0.0  # server time - local time
var _have_clock := false
var _events: Array = []
var _enemy_snaps := {}  # net id -> [[t, PackedFloat32Array], ...]
var _player_snaps := {}  # player id -> [[t, PackedFloat32Array], ...]
var _bosses := {}  # net id -> boss bar state
var _mirrors := {}  # net id -> Enemy
var _remote := {}  # player id -> RemotePlayer
var _attacks := {}  # key -> attack
var _shared := {}  # share id -> Array (hit list shared by pieces of one attack)
var _weapons := {}  # item id -> Item (other players' shots)
var _state_cache := {}
var _cache_frame := -1
var _send_timer := 0.0
var _seq := 0
var _pending: Array = []  # [{seq, hp, mp}] predicted changes the server hasn't confirmed


func start(p_address: String, p_port: int, p_token: String, p_character_id: int, p_name: String) -> void:
	address = p_address
	port = p_port
	token = p_token
	character_id = p_character_id
	account_name = p_name
	var err := _peer.create_client(address, port)
	if err != OK:
		_fail.call_deferred("Couldn't start a connection (%s)." % error_string(err))
		return
	multiplayer.multiplayer_peer = _peer
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func() -> void: _fail("Couldn't reach %s:%d." % [address, port]))
	multiplayer.server_disconnected.connect(func() -> void: _drop("The server closed the connection."))


func stop() -> void:
	clear_world()
	if _peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		_peer.close()
	connected = false


func _on_connected() -> void:
	Net.s_hello.rpc_id(1, Net.PROTOCOL, token, character_id, account_name)


func _fail(reason: String) -> void:
	if not connected:
		refused.emit(reason)


func _drop(reason: String) -> void:
	var was := connected
	connected = false
	if was:
		lost.emit(reason)
	else:
		refused.emit(reason)


func on_welcome(p_info: Dictionary) -> void:
	info = p_info
	connected = true
	welcomed.emit(info)


func on_refused(reason: String) -> void:
	connected = false
	refused.emit(reason)


## Everything we had is from the place we left; what comes next (the
## reliable channel keeps the order) belongs to the new one, and waits until
## Main has built it (attach_world).
func on_entered(record: Dictionary) -> void:
	if not record.has("error"):
		clear_world()
	entered.emit(record)


func on_died(p_info: Dictionary) -> void:
	if stats: stats.buffs.clear()
	died.emit(p_info)


func on_character(data: Dictionary) -> void:
	if stats:
		var hp := stats.hp
		var mp := stats.mp
		var effects := stats.buffs.wire()
		stats.load_data(data)
		stats.buffs.replace_wire(effects)
		stats.hp = minf(hp, stats.max_hp)  # vitals come with snapshots
		stats.mp = minf(mp, stats.max_mp)


func on_correct(pos: Vector3) -> void:
	if player:
		player.global_position = pos
		player.velocity = Vector3.ZERO


func on_ping(t: float, server_rtt: float) -> void:
	Net.s_pong.rpc_id(1, t)
	if server_rtt > 0.0:
		rtt = server_rtt


## Asks to go to `destination` ("hall", "realm_1"...): returns the record of
## the place we got (with `error` if we can't go).
func enter(destination: String) -> Dictionary:
	Net.s_enter.rpc_id(1, destination)
	var record: Dictionary = await entered
	return record


# --- The world we're in ------------------------------------------------------------

func attach_world(p_world: GameWorld, p_bullets: EnemyBullets, p_arrows: Arrows, p_player: Player) -> void:
	world = p_world
	bullets = p_bullets
	arrows = p_arrows
	player = p_player
	director = world.enemy_director if world is IslandWorld or world is DungeonWorld else null
	if director:
		director.remote = true


func clear_world() -> void:
	for m in _mirrors.values():
		if is_instance_valid(m):
			m.queue_free()
	for r in _remote.values():
		if is_instance_valid(r):
			r.queue_free()
	_mirrors.clear()
	_remote.clear()
	_enemy_snaps.clear()
	_player_snaps.clear()
	_bosses.clear()
	_events.clear()
	_shared.clear()
	world = null
	director = null


func render_time() -> float:
	return Net.now() + _offset - Net.INTERP_DELAY

func server_time() -> float:
	return Net.now()+_offset


func _process(delta: float) -> void:
	if not connected:
		_connect_left -= delta
		if _connect_left <= 0.0 and _peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
			_connect_left = INF
			_fail("No answer from %s:%d." % [address, port])
			stop()
		return
	_send_timer -= delta
	var rt := render_time()
	var budget := 4000
	while not _events.is_empty() and budget > 0:
		var ev: Array = _events[0]
		var kind := str(ev[1])
		if not is_instance_valid(world) and not kind in ["acct", "switched", "switch_fail", "lvl", "use"]:
			break  # events about a place wait until it's built
		if ev[0] > rt and _events.size() <= 3000 and not kind in ["acct", "switched", "switch_fail"]:
			break
		budget -= 1
		_apply(_events.pop_front())


func on_snapshot(t: float, enemies: PackedFloat32Array, bosses: Array, players: PackedFloat32Array, me: Array) -> void:
	_sync_clock(t)
	for i in range(0, enemies.size(), Net.ENEMY_STRIDE):
		var id := int(enemies[i])
		if not _enemy_snaps.has(id):
			_enemy_snaps[id] = []
		_push(_enemy_snaps[id], [t, enemies.slice(i, i + Net.ENEMY_STRIDE)])
	for b: Array in bosses:
		_bosses[int(b[0])] = {max_hp = int(b[1]), shell_hp = int(b[2]), shell_max = int(b[3]), phase = int(b[4]),
			intro_left = float(b[5]), shielded = b[6], immune = b[7], status = str(b[8]), pips = b[9], rays = b[10],
			extra = b[11] if b.size() > 11 else [], intro_players = b[12] if b.size()>12 else [],
			intro_serial = b[13] if b.size()>13 else 0, intro_duration = b[14] if b.size()>14 else 10.0}
	for i in range(0, players.size(), Net.PLAYER_STRIDE):
		var pid := int(players[i])
		if not _player_snaps.has(pid):
			_player_snaps[pid] = []
		_push(_player_snaps[pid], [t, players.slice(i, i + Net.PLAYER_STRIDE)])
	if not me.is_empty() and stats:
		var ack := int(me[2])
		_pending = _pending.filter(func(c: Dictionary) -> bool: return c.seq > ack)
		var hp := float(me[0])
		var mp := float(me[1])
		for c: Dictionary in _pending:
			hp += c.hp
			mp += c.mp
		stats.hp = clampf(hp, 0.0, stats.max_hp)
		stats.mp = clampf(mp, 0.0, stats.max_mp)


func on_events(events: Array) -> void:
	_events.append_array(events)


func _sync_clock(t: float) -> void:
	var sample := t - Net.now()
	if not _have_clock or absf(sample - _offset) > 0.5:
		_offset = sample
		_have_clock = true
	else:
		# Packets that arrive quickly say more about the true offset than slow ones.
		_offset = lerpf(_offset, sample, 0.3 if sample > _offset else 0.03)


static func _push(buffer: Array, entry: Array) -> void:
	# Ignore duplicate/late unreliable packets instead of reversing time.
	if not buffer.is_empty() and float(entry[0]) <= float(buffer[-1][0]): return
	buffer.append(entry)
	if buffer.size() > KEEP_SNAPSHOTS:
		buffer.pop_front()


## Where an enemy is right now on our (delayed) clock: {} if unknown.
func enemy_state(net_id: int) -> Dictionary:
	var frame := Engine.get_process_frames()
	if frame != _cache_frame:
		_cache_frame = frame
		_state_cache.clear()
	if _state_cache.has(net_id):
		return _state_cache[net_id]
	var s := {}
	var pair := _sample(_enemy_snaps.get(net_id, []))
	if not pair.is_empty():
		var a: PackedFloat32Array = pair[0]
		var b: PackedFloat32Array = pair[1]
		var k: float = pair[2]
		s = {
			pos = Vector3(a[1], a[2], a[3]).lerp(Vector3(b[1], b[2], b[3]), k),
			rot = lerp_angle(a[4], b[4], k),
			scale = Vector3(a[5], a[6], a[7]).lerp(Vector3(b[5], b[6], b[7]), k),
			model_y = lerpf(a[8], b[8], k), glow = lerpf(a[9], b[9], k),
			state = int(b[10]), hp = int(b[11]), flags = int(b[12]),
			visible = (int(b[12]) & 1) != 0, solid = (int(b[12]) & 2) != 0,
		}
	_state_cache[net_id] = s
	return s


func boss_state(net_id: int) -> Dictionary:
	return _bosses.get(net_id, {})


func enemy_node(net_id: int) -> Enemy:
	return _mirrors.get(net_id)


## [position, facing, speed share, flags] of another player now, or [].
func player_state(player_id: int) -> Array:
	return _sample_player(_player_snaps.get(player_id, []), render_time())


static func _sample_player(buffer: Array, rt: float) -> Array:
	if buffer.is_empty(): return []
	var latest: PackedFloat32Array = buffer[-1][1]
	var pos := Vector3(latest[1], latest[2], latest[3])
	var facing := float(latest[4])
	var speed := float(latest[5])
	if rt < float(buffer[-1][0]):
		var first: PackedFloat32Array = buffer[0][1]
		pos = Vector3(first[1], first[2], first[3])
		facing = first[4]
		for i in range(1, buffer.size()):
			if rt > float(buffer[i][0]): continue
			var a: PackedFloat32Array = buffer[i - 1][1]
			var b: PackedFloat32Array = buffer[i][1]
			var start := Vector3(a[1], a[2], a[3])
			var end := Vector3(b[1], b[2], b[3])
			var k := clampf((rt - float(buffer[i - 1][0])) / maxf(0.0001, float(buffer[i][0]) - float(buffer[i - 1][0])), 0.0, 1.0)
			# Teleports must never interpolate through the intervening world.
			pos = start.lerp(end, k) if start.distance_to(end) < PLAYER_TELEPORT_DISTANCE else start
			facing = lerp_angle(a[4], b[4], k)
			return [pos, facing, lerpf(a[5], b[5], k), int(a[6])]
	elif buffer.size() >= 2:
		var previous: PackedFloat32Array = buffer[-2][1]
		var dt := float(buffer[-1][0]) - float(buffer[-2][0])
		var displacement := pos - Vector3(previous[1], previous[2], previous[3])
		var age := maxf(0.0, rt - float(buffer[-1][0]))
		if dt > 0.001 and dt <= 0.25 and displacement.length() < PLAYER_TELEPORT_DISTANCE and speed > 0.01 and (int(latest[6]) & 2) == 0:
			# Ease velocity to zero, then hold. Even a long outage adds at most
			# half the horizon times the capped speed, never unlimited drift.
			var t := minf(age, PLAYER_PREDICTION_LIMIT)
			var travel_time := t - t * t / (2.0 * PLAYER_PREDICTION_LIMIT)
			pos += (displacement / dt).limit_length(PLAYER_MAX_PREDICT_SPEED) * travel_time
	if rt - float(buffer[-1][0]) >= PLAYER_PREDICTION_LIMIT: speed = 0.0
	return [pos, facing, speed, int(latest[6])]


## The two snapshots around our render time and how far between them.
func _sample(buffer: Array) -> Array:
	if buffer.is_empty():
		return []
	var rt := render_time()
	if rt <= buffer[0][0] or buffer.size() == 1:
		return [buffer[0][1], buffer[0][1], 0.0]
	for i in range(buffer.size() - 1, 0, -1):
		var a: Array = buffer[i - 1]
		var b: Array = buffer[i]
		if a[0] <= rt:
			if rt >= b[0]:
				return [b[1], b[1], 0.0]
			return [a[1], b[1], (rt - a[0]) / maxf(0.0001, b[0] - a[0])]
	return [buffer[0][1], buffer[0][1], 0.0]


# --- Events ---------------------------------------------------------------------

func _apply(ev: Array) -> void:
	match str(ev[1]):
		"theory":
			if world is SpatialWorld: world.handle_event(ev[2])
		"sfx":
			if is_instance_valid(world) and ev.size()>=5: GameAudio.play(str(ev[2]),ev[3],ev[4])
		"boss_defeated":
			if is_instance_valid(world): GameAudio.boss_defeated(str(ev[2]), world.realm_id)
		"dng+":
			if is_instance_valid(world): DungeonPortal.place(world, ev[2])
		"dng-":
			if is_instance_valid(world):
				for child in world.get_children():
					if child is DungeonPortal and child.data.id == ev[2]: child.despawn()
		"castle":  # the Hollow Castle's gates, walls, doors and cutscenes
			if world and world.has_method("castle_event"): world.castle_event(ev)
		"fort_gate":
			if world is IslandWorld: (world as IslandWorld).gates.apply_state(ev[2],bool(ev[3]),bool(ev[4]) if ev.size()>4 else bool(ev[3]))
		"e+": _spawn_mirror(ev)
		"enemy_buffs":
			var enemy: Enemy = _mirrors.get(int(ev[2]))
			if is_instance_valid(enemy): enemy.buffs.replace_wire(ev[3], maxf(0.0, Net.now() - float(ev[0])))
		"e-":
			var m: Enemy = _mirrors.get(int(ev[2]))
			if is_instance_valid(m):
				m.queue_free()
			_mirrors.erase(int(ev[2]))
			_enemy_snaps.erase(int(ev[2]))
			_bosses.erase(int(ev[2]))
		"m":
			var m: Enemy = _mirrors.get(int(ev[2]))
			if is_instance_valid(m):
				var target: CreatureModel = m._shell if m is Boss and ev.size()>5 and bool(ev[5]) else m.model
				if is_instance_valid(target): target.callv(ev[3], ev[4])
		"ad": _attacks[ev[2]] = ev[3]
		"b": _enemy_shot(ev)
		"bclr":
			if bullets:
				bullets.clear_owner(int(ev[2]))
		"rp":
			if bullets and is_instance_valid(world):
				EnemyRipple.spawn(bullets, ev[2], ev[3], ev[4], bullets.players, [])
		"ft":
			if is_instance_valid(world):
				FloatingText.spawn(world, ev[2], ev[3], ev[4], ev[5])
		"db":
			if is_instance_valid(world):
				Debris.burst_points(world, ev[2], ev[3], ev[4], ev[5], ev[6], ev[7], ev[8])
		"bv":
			if is_instance_valid(world):
				BlinkVoxels.spawn(world, ev[2], ev[3], ev[4], ev[5], ev[6])
		"sh": CameraShake.shake_at(ev[2], ev[3], ev[4])
		"light":
			if is_instance_valid(world):
				Boss.flash_light(world, ev[2], ev[3], ev[4], ev[5], ev[6])
		"grave":
			if is_instance_valid(world):
				var at: Vector3 = ev[2]
				at.y = world.ground_height(at.x, at.z)
				Gravestone.place(world, at, str(ev[3]), bool(ev[4]))
		"oh":
			if world is IslandWorld:
				(world as IslandWorld).hit_obstacle(str(ev[2]), int(ev[3]), ev[4])
		"hz", "hzrm", "hzclr": _hazard(ev)
		"bag+":
			var r: Dictionary = ev[2]
			r.items = Net.decode_items(r.items)
			r.expires = 1 << 62
			GameServer.net_bag_added(r)
		"bag~": GameServer.net_bag_changed(int(ev[2]), Net.decode_items(ev[3]), bool(ev[4]) if ev.size() > 4 else false)
		"bag-": GameServer.net_bag_removed(int(ev[2]))
		"xp": GameServer.net_xp_dropped(ev[2], ev[3], ev[4])
		"buffs":
			var pid := int(ev[2])
			var age := maxf(0.0,Net.now()+_offset-float(ev[0]))
			if stats and pid == stats.player_id: stats.buffs.replace_wire(ev[3],age)
			elif _remote.has(pid): (_remote[pid] as RemotePlayer).buffs.replace_wire(ev[3],age)
		"p+": _remote_player(int(ev[2]), str(ev[3]), str(ev[4]))
		"p-":
			var r: Node = _remote.get(int(ev[2]))
			if is_instance_valid(r):
				r.queue_free()
			_remote.erase(int(ev[2]))
			_player_snaps.erase(int(ev[2]))
		"shot": _remote_shot(ev)
		"ring": _remote_ring(ev)
		"obs":
			if world is IslandWorld:
				(world as IslandWorld).remove_obstacle(str(ev[2]))
		"lvl":
			if stats:
				stats.leveled_up.emit(int(ev[2]), ev[3])
		"use":
			if stats and Items.exists(str(ev[2])):
				stats.consumed.emit(Items.make(str(ev[2])))
		"acct": account_xp.emit(int(ev[2]))
		"switched":
			# Predictions and vitals belonged to the previous character. Ordinary
			# gear updates preserve them, but this is a new character's state.
			_pending.clear()
			if stats:
				stats.load_data(ev[5])
			character_id = int(ev[2])
			account_xp.emit(int(ev[4]))
			switched.emit(character_id, str(ev[3]))
		"switch_fail": switch_failed.emit(str(ev[2]))
		"hit":
			if is_instance_valid(player):
				if float(ev[2]) > 0.0:
					player.take_damage(float(ev[2]), ev[3], ev[4])
				if ev[5] != Vector3.ZERO:
					player.knockback(ev[5])


func _spawn_mirror(ev: Array) -> void:
	var id := int(ev[2])
	if director == null or _mirrors.has(id) or not Enemies.all_ids().has(ev[3]):
		return
	var def := Enemies.get_def(ev[3])
	var pack := EnemyPack.new()
	pack.site = {id = "net_%d" % id, pack = "", pos = ev[4], seed = 0}
	var enemy := EnemyDirector._make_actor(def).setup(def, pack, director)
	enemy.mirror = true
	enemy.net_id = id
	enemy.max_hp = int(ev[8])
	enemy.hp = int(ev[7])
	enemy.is_minion = ev[9]
	director.add_child(enemy)
	enemy.global_position = ev[4]
	enemy.model.rotation.y = ev[5]
	enemy.state = int(ev[6])
	_mirrors[id] = enemy


func _enemy_shot(ev: Array) -> void:
	if bullets == null or not is_instance_valid(world) or not _attacks.has(ev[4]):
		return
	var attack: Dictionary = _attacks[ev[4]]
	if ev.size()>9: attack = _bind_status_tokens(attack,ev[9])
	var share := int(ev[8])
	if share != 0:
		attack = attack.duplicate()
		if not _shared.has(share):
			_shared[share] = []
			if _shared.size() > 64:
				_shared.erase(_shared.keys()[0])
		attack.shared_hits = _shared[share]
	bullets.fire(ev[2], ev[3], attack, null, ev[6], [], int(ev[5]), str(ev[7]))


func _hazard(ev: Array) -> void:
	var boss := _mirrors.get(int(ev[2])) as Boss
	if not is_instance_valid(boss) or boss.hazards == null:
		return
	match str(ev[1]):
		"hz": boss.hazards.net_create(ev[3], ev[4], int(ev[5]))
		"hzrm": boss.hazards.net_remove(int(ev[3]))
		"hzclr": boss.hazards.clear()


func _remote_player(pid: int, player_name: String, gear: String) -> void:
	if not is_instance_valid(world):
		return
	var r: RemotePlayer = _remote.get(pid)
	if not is_instance_valid(r):
		r = RemotePlayer.new()
		r.player_id = pid
		r.solid = info.get("player_collision", false)
		world.add_child(r)
		var s := player_state(pid)
		if not s.is_empty():
			r.global_position = s[0]
		_remote[pid] = r
	r.set_look(player_name, gear)


func _weapon(id: String) -> Item:
	if not _weapons.has(id):
		_weapons[id] = Items.make(id)
	return _weapons[id]


func _remote_shot(ev: Array) -> void:
	if arrows == null or not Items.exists(str(ev[5])):
		return
	var mods: Dictionary = ev[7]
	mods.visual = true
	GameAudio.weapon_shot(_weapon(str(ev[5])),ev[3],true)
	var r: RemotePlayer = _remote.get(int(ev[2]))
	if is_instance_valid(r):
		mods.exclude = r.get_rid()
		r.shot()
	arrows.spawn(ev[3], ev[4], 0, _weapon(str(ev[5])), float(ev[6]), "", mods)


func _remote_ring(ev: Array) -> void:
	if not is_instance_valid(world) or not Items.exists(str(ev[3])):
		return
	var spell := _weapon(str(ev[3]))
	GameAudio.play("magic_ring",ev[4],{ally=true})
	for i in spell.ring.get("pulses", 1):
		var ring := MagicRing.cast(world, ev[4], spell, i * 0.18, float(ev[5]))
		ring.visual_only = true


# --- Sending --------------------------------------------------------------------

## Play another character (in the Tavern, or after dying).
func switch_character(new_character_id: int) -> void:
	if connected:
		Net.s_action.rpc_id(1, "switch", [token, new_character_id])


func send_position(pos: Vector3) -> void:
	if not connected or _send_timer > 0.0 or player == null:
		return
	_send_timer = 1.0 / SEND_RATE
	var flags := (1 if player.shield.active else 0) | (2 if player.frozen else 0)
	var speed := (player.velocity.slide(player.up_direction).length() if world is SpatialWorld else Vector2(player.velocity.x,player.velocity.z).length()) / maxf(0.1, Player.BASE_SPEED * stats.move_speed_multiplier())
	Net.s_move.rpc_id(1, pos, player.facing, speed, flags)


## A hit this client saw land on its player (already shown, see GameServer).
func report_self_hit(amount: float, armor_piercing: bool, shielded: bool, landed: float) -> void:
	if not connected:
		return
	_seq += 1
	_pending.append({seq = _seq, hp = -landed, mp = 0.0})
	Net.s_action.rpc_id(1, "hurt", [_seq, amount, armor_piercing, shielded, player.last_hit_by if player else ""])


func send_ring(cost: float) -> void:
	if not connected:
		return
	_seq += 1
	_pending.append({seq = _seq, hp = 0.0, mp = -cost})
	Net.s_action.rpc_id(1, "ring", [_seq])


func send_action(kind: String, args: Array) -> void:
	if connected:
		Net.s_action.rpc_id(1, kind, args)


func send_shield(up: bool) -> void:
	if connected:
		Net.s_action.rpc_id(1, "shield", [up])


func send_inventory(op: String, places: Array) -> bool:
	if connected:
		Net.s_action.rpc_id(1, "inv", [op] + places)
	return true


func send_collect(orb_id: int) -> void:
	if connected:
		Net.s_action.rpc_id(1, "xp", [orb_id])


func hit_enemy(enemy: Enemy, damage: int, direction: Vector3, item_id := "", secondary := false) -> void:
	if connected and enemy.is_alive():
		Net.s_action.rpc_id(1, "hit", [enemy.net_id, damage, direction, item_id, secondary])


func send_shot(origin: Vector3, direction: Vector3, weapon: Item, phase: float, mods: Dictionary) -> void:
	if connected:
		Net.s_shot.rpc_id(1, origin, direction, weapon.id, phase, mods)


func obstacle_hit(obstacle: Obstacle, damage: int, at: Vector3) -> void:
	if connected:
		Net.s_action.rpc_id(1, "obstacle_hit", [obstacle.obstacle_id, damage, at])


func obstacle_broken(obstacle: Obstacle) -> void:
	if connected:
		Net.s_action.rpc_id(1, "obstacle", [obstacle.obstacle_id, obstacle.global_position])


func _bind_status_tokens(original: Dictionary, tokens: Dictionary, path := "") -> Dictionary:
	var attack := original.duplicate()
	if tokens.has(path): attack.status_token = int(tokens[path])
	if attack.has("terminal") and attack.terminal is Dictionary and attack.terminal.get("attack") is Dictionary:
		attack.terminal = attack.terminal.duplicate()
		attack.terminal.attack = _bind_status_tokens(attack.terminal.attack,tokens,path+"t")
	return attack
