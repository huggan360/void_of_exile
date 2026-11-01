extends Node
## Stand-in for the game server (autoloaded as GameServer; WorldServer keeps
## the realm records). It runs inside the game while we develop, but
## everything talks to it the way a client will talk to a real server:
##
##   * The server owns the state: characters (health, magic, XP, gear,
##     backpack, quickslots), loot bags (what's in them, who may see them,
##     where they are, how long they last), XP orbs, loot rolls and kill
##     rewards.
##   * Clients only ask. The HUD, the Player and Main never change any of
##     that themselves: they send a request with plain data (player id, slot
##     places, bag and orb ids, numbers, positions) and the server checks it
##     (can you see that bag, are you standing on it, is that orb near you,
##     do you have the magic) before applying it. Views update from the
##     server's signals.
##   * Requests and signals only carry ids, numbers, strings and positions,
##     so they can become network messages without changing the callers.
##     (Item objects are still shared in memory; over a network the server
##     sends item ids and counts instead.)
##   * Nothing pauses. The server ticks every frame whatever menus are open,
##     and un-pauses the tree if anything ever pauses it. The game menu only
##     locks the local player's input.
##
## Still simulated by the client for now, the way Realm of the Mad God does
## it: movement, enemy AI and projectiles, and hit detection. Hits are
## reported here (hit_player, report_hit_landed, enemy_killed) and the server
## applies what follows from them.
##
## Online the same code runs in two places (see Net):
##   * on the dedicated server it is the real thing, for every connected
##     player (and the enemies run there too);
##   * on a client (Net.is_client()) it only mirrors the local character:
##     requests go to the server, a few are predicted so combat feels
##     instant (a hit you took, raising the shield, a ring), and the
##     server's answers (character, vitals, bags, orbs) come back through
##     Net and replace the prediction.
## Dying is for good: the character and everything it carried is gone
## (online it moves to the account service's dead table).

## items_lost: how many items went with the backpack (-1 = had no backpack).
signal player_died(player_id: int, items_lost: int)
signal bag_added(bag: Dictionary)
signal bag_changed(bag_id: int)
signal bag_removed(bag_id: int)
signal xp_dropped(realm_id: String, pos: Vector3, orbs: Array)

var HP_REGEN := 1.5  # per second, once you haven't been hurt for a while
var HP_REGEN_DELAY := 4.0
var MP_REGEN := 7.0
var MP_REGEN_DELAY := 0.8
var SHIELD_DRAIN := 16.0  # magic per second while the shield is up
var SHIELD_MIN_MP := 5.0  # needed to raise it
var SHIELD_DAMAGE_TAKEN := 0.4  # share of a normal hit that still gets through the shield
var RING_COOLDOWN := 0.6
const BAG_REACH := 1.5  # how far from a bag you can still use it (a little slack for lag)
var BAG_LIFETIME := 90.0
var PERSONAL_BAG_LIFETIME := 180.0
var XP_PER_ORB := 3
var MAX_ORBS_PER_DROP := 14
const XP_REACH := 12.0  # orbs fly to you; collecting one this far from where it dropped is fine
var XP_ORB_LIFETIME := 45.0
const PUBLIC := 0  # a bag's viewer when everyone can see it

## Development: players take no damage.
var debug_godmode := false
## Server config: XP from kills and orbs is multiplied by this.
var xp_multiplier := 1.0
## Offline only: what a fresh character starts with after dying.
var _demo := false

var _next_id := 1
## player id -> {stats, realm, pos, since_hurt, since_magic, shield, ring_ready}
var _players := {}
## bag id -> {id, realm, type, viewer (player id, or PUBLIC), items, pos, expires}
var _bags := {}
## orb id -> {realm, pos, value, expires}
var _orbs := {}
## realm id -> func(origin: Vector3, taken: Array) -> Vector3: where a bag fits
## (the server's view of that world's ground, walls and obstacles).
var _spot_finders := {}
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		push_warning("The game can't be paused (it's an online world); un-pausing.")
		get_tree().paused = false
	if Net.is_client():
		for p: Dictionary in _players.values():
			(p.stats as PlayerStats).buffs.tick()
		return  # vitals, bag and orb lifetimes are the server's
	for id in _players:
		_tick_vitals(_players[id], delta)
	var now := _now()
	for bag_id in _bags.keys():
		if now >= _bags[bag_id].expires:
			_remove_bag(bag_id)
	for orb_id in _orbs.keys():
		if now >= _orbs[orb_id].expires:
			_orbs.erase(orb_id)


# --- Characters ---------------------------------------------------------------------

## A player connects; returns their id. demo: the demo character's kit (a
## Backpack on, one of every gear item, a few elixirs on the quickslots).
func join(demo := false) -> int:
	_demo = demo
	var stats := PlayerStats.new()
	if demo:
		give_demo_kit(stats)
	return add_player(stats)


## Server: a connected player's character (loaded from the account service).
func add_player(stats: PlayerStats) -> int:
	var id := _new_id()
	stats.player_id = id
	stats.bag_lookup = bag
	_players[id] = {stats = stats, realm = "", pos = Vector3.ZERO, since_hurt = 99.0, since_magic = 99.0,
			shield = false, ring_ready = 0}
	return id


var _intro_locks := {}

## One authoritative safety window for every player admitted to a boss intro.
func begin_boss_intro(encounter: int, realm: String, ids: Array, duration: float) -> Array:
	var admitted: Array = []
	for id: int in ids:
		if not _players.has(id) or player_realm(id)!=realm or character(id).hp<=0: continue
		admitted.append(id)
		var current: Dictionary = _intro_locks.get(id,{})
		if current.get("encounter",-1)==encounter and intro_locked(id): continue
		var rate := maxf(.01,Engine.time_scale)
		var until := Time.get_ticks_msec()+int(duration*1000/rate)
		_intro_locks[id] = {encounter=encounter,realm=realm,until=until,safe_until=until+int(1000/rate)}
		_players[id].shield = false
	return admitted

func intro_locked(player_id: int) -> bool:
	var entry: Dictionary = _intro_locks.get(player_id,{})
	return not entry.is_empty() and entry.realm==player_realm(player_id) and Time.get_ticks_msec()<int(entry.until)

func intro_protected(player_id: int) -> bool:
	var entry: Dictionary = _intro_locks.get(player_id,{})
	return not entry.is_empty() and entry.realm==player_realm(player_id) and Time.get_ticks_msec()<int(entry.safe_until)

func cancel_boss_intro(encounter: int) -> void:
	for id in _intro_locks.keys():
		if int(_intro_locks[id].encounter)==encounter: _intro_locks.erase(id)


func remove_player(player_id: int) -> void:
	_intro_locks.erase(player_id)
	_players.erase(player_id)


## Server: a player continues with another character (fresh vitals and timers).
func revive(player_id: int) -> void:
	if _players.has(player_id):
		var p: Dictionary = _players[player_id]
		p.shield = false
		(p.stats as PlayerStats).buffs.clear()
		p.since_hurt = 99.0
		p.since_magic = 99.0
		p.ring_ready = 0


## Client: the local character goes by the id the server gave it.
func adopt(old_id: int, new_id: int) -> void:
	if not _players.has(old_id) or old_id == new_id:
		return
	_players[new_id] = _players[old_id]
	_players.erase(old_id)
	(_players[new_id].stats as PlayerStats).player_id = new_id
	_bags.clear()
	_orbs.clear()


## Development kit: a Backpack on, one of every gear item, a few elixirs.
func give_demo_kit(stats: PlayerStats) -> void:
	var equipped_ids: Array = stats.gear.values().filter(func(i: Item) -> bool: return i != null).map(
			func(i: Item) -> String: return i.id)
	stats.add_backpack()
	# One of every stronghold key first, so they're never crowded out.
	stats.give(Items.GATE_KEYS.keys().map(func(id: String) -> Item: return Items.gate_key(id)))
	stats.give(Items.all().filter(func(i: Item) -> bool:
		return not i.id in equipped_ids and not i.is_consumable() and not i.is_key() and not i.is_story()))
	for k in PlayerStats.QUICKSLOTS:
		stats.quick[k] = Items.make(["elixir_hp", "elixir_mp"][k])
		stats.quick[k].count = 3


## A player's character, to read (never to change: ask the server).
func character(player_id: int) -> PlayerStats:
	return _players[player_id].stats if _players.has(player_id) else null


## Where a player is (clients send this as they move).
func report_position(player_id: int, realm_id: String, pos: Vector3) -> void:
	if Net.is_client():
		Net.client.send_position(pos)
	if _players.has(player_id):
		_players[player_id].realm = realm_id
		_players[player_id].pos = pos


## A player goes to another place. Returns that realm's record ({} for the
## Tavern).
func enter_realm(player_id: int, realm_id: String) -> Dictionary:
	_intro_locks.erase(player_id)
	grant_arrival_protection(player_id)
	if _players.has(player_id):
		_players[player_id].realm = realm_id
	return {} if realm_id == "hall" or Dungeons.is_dungeon(realm_id) else WorldServer.get_or_create_realm(realm_id)


## A hit on a player (detected by their client). shielded: their warp shield
## was up, which soaks most of a normal hit. Returns {landed, soaked}.
func hit_player(player_id: int, amount: float, armor_piercing := false, shielded := false) -> Dictionary:
	var p: Dictionary = _players.get(player_id, {})
	if p.is_empty():
		return {landed = 0.0, soaked = 0.0}
	var stats: PlayerStats = p.stats
	if debug_godmode or intro_protected(player_id) or stats.buffs.has_effect("invincible"):
		amount = 0.0
	var landed := stats.mitigate(amount, armor_piercing) if amount > 0.0 else 0.0
	var soaked := landed * (1.0 - SHIELD_DAMAGE_TAKEN) if shielded and p.shield else 0.0
	landed -= soaked
	stats.hp = maxf(0.0, stats.hp - landed)
	p.since_hurt = 0.0
	stats.damaged.emit(int(round(landed)))
	if Net.is_client():
		# Predicted; the server applies the same hit and decides if we die.
		Net.client.report_self_hit(amount, armor_piercing, shielded and p.shield, landed)
		return {landed = landed, soaked = soaked}
	if stats.hp <= 0.0:
		_die(player_id)
	return {landed = landed, soaked = soaked}


## The player raises or lowers the warp shield. Returns whether it's up.
func set_shield(player_id: int, up: bool) -> bool:
	if up and intro_locked(player_id): return false
	var p: Dictionary = _players.get(player_id, {})
	if p.is_empty():
		return false
	var stats: PlayerStats = p.stats
	if up and not p.shield and (stats.gear.spell == null or stats.mp < SHIELD_MIN_MP):
		return false
	if Net.is_client() and p.shield != up:
		Net.client.send_shield(up)
	p.shield = up
	return up


## Double-tapped Space: pays for the spell's warp ring. Returns whether it goes.
func request_ring(player_id: int) -> bool:
	if intro_locked(player_id): return false
	var p: Dictionary = _players.get(player_id, {})
	if p.is_empty():
		return false
	var stats: PlayerStats = p.stats
	var spell: Item = stats.gear.spell
	if spell == null or spell.ring.is_empty() or Time.get_ticks_msec() < p.ring_ready or stats.mp < spell.ring.cost:
		return false
	stats.mp -= spell.ring.cost
	stats.hp = minf(stats.max_hp, stats.hp + spell.ring.get("heal", 0))
	if Net.is_client():
		Net.client.send_ring(spell.ring.cost)
	p.since_magic = 0.0
	p.ring_ready = Time.get_ticks_msec() + int(maxf(RING_COOLDOWN, spell.ring.get("cooldown", RING_COOLDOWN)) * 1000.0)
	return true


## One of the player's shots or rings hit an enemy: lifesteal from gear.
func report_hit_landed(player_id: int) -> void:
	if Net.is_client():
		return  # the server applies lifesteal when it gets the hit
	var stats := character(player_id)
	if stats:
		stats.hp = minf(stats.max_hp, stats.hp + stats.effect("lifesteal"))


## Health and magic come back on their own; the shield drains magic (and
## some gear heals while it's up).
func _tick_vitals(p: Dictionary, delta: float) -> void:
	var stats: PlayerStats = p.stats
	stats.buffs.tick()
	p.since_hurt += delta
	if p.since_hurt > HP_REGEN_DELAY or (stats.buffs.has_effect("regeneration") and stats.buffs.multiplier("regeneration")>=1.0):
		stats.hp = minf(stats.max_hp, stats.hp + HP_REGEN * stats.buffs.multiplier("regeneration") * delta)
	if p.shield:
		stats.mp = maxf(0.0, stats.mp - SHIELD_DRAIN * stats.effect("shield_drain", 1.0) * delta)
		stats.hp = minf(stats.max_hp, stats.hp + stats.effect("shield_heal") * delta)
		p.since_magic = 0.0
		if stats.mp <= 0.0:
			p.shield = false
	else:
		p.since_magic += delta
		if p.since_magic > MP_REGEN_DELAY:
			stats.mp = minf(stats.max_mp, stats.mp + MP_REGEN * stats.effect("mp_regen", 1.0) * stats.buffs.multiplier("mana_regeneration") * delta)


## Dying is permanent: the character, its level, stats and everything it
## carried are gone. Online the server's Net moves it to the dead table and
## the player makes a new one; offline a fresh character starts in the
## Tavern (with the development kit again when the game runs with one).
func _die(player_id: int) -> void:
	var p: Dictionary = _players[player_id]
	var stats: PlayerStats = p.stats
	var lost := stats.carried_count()
	stats.buffs.clear()
	p.shield = false
	if Net.is_server():
		player_died.emit(player_id, lost)
		return
	stats.reset()
	if _demo:
		give_demo_kit(stats)
	player_died.emit(player_id, lost)


func debug_grant_xp(player_id: int, amount: int) -> void:
	if Net.is_client():
		return
	var stats := character(player_id)
	if stats:
		stats.add_xp(amount)


# --- Inventory ----------------------------------------------------------------------
# Places are plain data: {kind = "gear", key = "weapon"}, {kind = "pack",
# key = 12}, {kind = "quick", key = 0} or {kind = "bag", key = 3, bag = bag id}.

## Drag and drop between two places (stacking or swapping).
func request_move(player_id: int, from: Dictionary, to: Dictionary) -> bool:
	if Net.is_client():
		return Net.client.send_inventory("move", [from, to])
	var stats := character(player_id)
	if stats == null or not _may_touch(player_id, from) or not _may_touch(player_id, to) or not stats.can_move(from, to):
		return false
	stats.move(from, to)
	_bags_touched([from, to])
	return true


## Double-click: take from a bag, drink, equip, unequip.
func request_activate(player_id: int, place: Dictionary) -> bool:
	if Net.is_client():
		return Net.client.send_inventory("activate", [place])
	var stats := character(player_id)
	if stats == null or not _may_touch(player_id, place):
		return false
	var done := stats.activate(place)
	_bags_touched([place])
	return done


## F / G, or drinking from the backpack.
func request_use(player_id: int, place: Dictionary) -> bool:
	if Net.is_client():
		return Net.client.send_inventory("use", [place])
	var stats := character(player_id)
	if stats == null or place.kind == "bag":
		return false
	return stats.use(place)


## The steward of a realm town makes it the character's home.
func request_set_home(player_id: int, village: String) -> void:
	if Net.is_client():
		Net.client.send_action("home", [village])
	var stats := character(player_id)
	if stats and village.length() < 40:
		stats.home = village
		stats.changed.emit()


## Throws an item out of the inventory: into the bag you're standing on if
## it has room and may hold it, otherwise into a new bag at your feet (gray
## for anyone to take, or your own personal bag for soulbound items).
func request_drop(player_id: int, place: Dictionary) -> bool:
	if Net.is_client():
		return Net.client.send_inventory("drop", [place])
	var stats := character(player_id)
	if stats == null or place.kind == "bag" or stats.item_at(place) == null or stats.item_at(place).is_story():
		return false
	var p: Dictionary = _players[player_id]
	var item := stats.take(place)
	var under := _bag_under(player_id)
	if not under.is_empty() and under.items.find(null) >= 0 \
			and LootBag.can_hold(under.type, under.viewer == PUBLIC, item) \
			and (under.viewer == PUBLIC) != item.soulbound():
		under.items[under.items.find(null)] = item
		bag_changed.emit(under.id)
	elif item.soulbound():
		spawn_bag(p.realm, [item], p.pos, player_id, item.bag_type())
	else:
		spawn_bag(p.realm, [item], p.pos, PUBLIC, "gray")
	return true


## Bag places must be bags you can see, in your realm, and that you're
## standing on.
func _may_touch(player_id: int, place: Dictionary) -> bool:
	if place.kind != "bag":
		return true
	var b := bag(place.bag)
	var p: Dictionary = _players[player_id]
	return not b.is_empty() and _visible_to(b, player_id) and b.realm == p.realm \
			and _flat_distance(b.pos, p.pos) <= BAG_REACH


func _bags_touched(places: Array) -> void:
	for place: Dictionary in places:
		if place.kind == "bag" and _bags.has(place.bag):
			# Empty chests remain as an opened landmark until their usual expiry.
			_bags[place.bag].opened = true
			bag_changed.emit(place.bag)


# --- Loot bags ----------------------------------------------------------------------

## A bag's record, to read ({} if it's gone).
func bag(bag_id: int) -> Dictionary:
	return _bags.get(bag_id, {})


## The bags in a realm that a player can see.
func bags_in(realm_id: String, player_id: int) -> Array:
	return _bags.values().filter(func(b: Dictionary) -> bool:
		return b.realm == realm_id and _visible_to(b, player_id))


## Opening is lasting state on the loot record, shared by public chests
## and restored if the player leaves and returns before the chest expires.
func request_open_chest(player_id: int, chest_id: int) -> bool:
	var record := bag(chest_id)
	if record.is_empty() or not _players.has(player_id): return false
	if not _may_touch(player_id, {kind="bag", bag=chest_id}): return false
	if bool(record.get("opened", false)): return true
	if Net.is_client(): Net.s_action.rpc_id(1, "open_chest", [chest_id])
	record.opened = true
	bag_changed.emit(chest_id)
	return true


## How a realm finds room for a bag (see LootBags.find_spot).
func set_spot_finder(realm_id: String, finder: Callable) -> void:
	_spot_finders[realm_id] = finder


## Puts a bag of items on the ground near `origin`. viewer: the only player
## who sees it, or PUBLIC. bag_type: "" = the color of the best item.
func spawn_bag(realm_id: String, items: Array, origin: Vector3, viewer := PUBLIC, bag_type := "") -> int:
	if items.is_empty() or Net.is_client():
		return 0
	var taken: Array = _bags.values().filter(func(b: Dictionary) -> bool: return b.realm == realm_id).map(
			func(b: Dictionary) -> Vector3: return b.pos)
	var finder: Callable = _spot_finders.get(realm_id, Callable())
	var pos: Vector3 = finder.call(origin, taken) if finder.is_valid() else origin
	var contents := items.duplicate()
	contents.resize(LootBag.SLOTS)
	var t := bag_type if bag_type != "" else LootBag.type_for(items)
	var record := {
		id = _new_id(), realm = realm_id, type = t, viewer = viewer, items = contents, pos = pos, opened = false,
		# Story chests wait until they're emptied.
		expires = 1 << 62 if t == "story" else _now() + int((PERSONAL_BAG_LIFETIME if LootBag.is_personal(t) else BAG_LIFETIME) * 1000.0),
	}
	_bags[record.id] = record
	bag_added.emit(record)
	return record.id


func _remove_bag(bag_id: int) -> void:
	_bags.erase(bag_id)
	bag_removed.emit(bag_id)


func _visible_to(b: Dictionary, player_id: int) -> bool:
	return b.viewer == PUBLIC or b.viewer == player_id


## The closest bag the player can see and is standing on, or {}.
func _bag_under(player_id: int) -> Dictionary:
	var p: Dictionary = _players[player_id]
	var best := {}
	for b: Dictionary in bags_in(p.realm, player_id):
		var d := _flat_distance(b.pos, p.pos)
		if d <= LootBags.STAND_RADIUS and (best.is_empty() or d < _flat_distance(best.pos, p.pos)):
			best = b
	return best


# --- Kills and rewards ----------------------------------------------------------------

## An enemy died. damage_by: player id -> damage dealt. Rolls its loot
## (see Loot) and drops its XP as orbs; a boss's XP goes straight to every
## player close by instead.
## max_hp: the health this kill actually had (a boss's scaled health); loot
## eligibility is judged against it. 0 = the def's base health.
func enemy_killed(realm_id: String, def: EnemyDef, pos: Vector3, damage_by: Dictionary, biome_stat: Variant = "magic", max_hp := 0) -> void:
	if Net.is_client():
		return
	if Net.is_server():
		Net.server.dungeons.enemy_killed(realm_id, def, pos)
		Net.server.campaigns.enemy_died(realm_id, def, pos)
	var modifiers := {}
	for pid in damage_by:
		var stats := character(pid)
		if stats:
			modifiers[pid] = {chance=stats.buffs.probability("loot_chance"),tier=stats.buffs.probability("loot_tier")}
	for drop in Loot.roll(def, damage_by, _rng, biome_stat, max_hp, modifiers):
		spawn_bag(realm_id, drop.items, pos, drop.viewer)
	if def is BossDef:
		for id in _players:
			var p: Dictionary = _players[id]
			if p.realm == realm_id and _flat_distance(p.pos, pos) <= (def as BossDef).bar_radius:
				(p.stats as PlayerStats).add_xp(roundi(def.xp * xp_multiplier))
	else:
		drop_xp(realm_id, pos + Vector3.UP * 0.6, roundi(def.xp * xp_multiplier))


## How many players are within `radius` of `pos` (a boss counts them for its
## health when the fight starts).
func players_near(realm_id: String, pos: Vector3, radius: float) -> int:
	var count := 0
	for p: Dictionary in _players.values():
		if p.realm == realm_id and _flat_distance(p.pos, pos) <= radius:
			count += 1
	return count


## Drops XP at `pos` as a handful of orbs for players to collect.
func drop_xp(realm_id: String, pos: Vector3, amount: int) -> void:
	if amount <= 0 or Net.is_client():
		return
	var count := clampi(ceili(float(amount) / XP_PER_ORB), 1, MAX_ORBS_PER_DROP)
	var left := amount
	var orbs := []
	for i in count:
		var value := left / (count - i)
		left -= value
		var id := _new_id()
		_orbs[id] = {realm = realm_id, pos = pos, value = value, expires = _now() + int(XP_ORB_LIFETIME * 1000.0)}
		orbs.append({id = id, value = value})
	xp_dropped.emit(realm_id, pos, orbs)


## A player picked up an XP orb. Each orb counts once, for whoever gets it.
func collect_xp(player_id: int, orb_id: int) -> bool:
	if Net.is_client():
		Net.client.send_collect(orb_id)
		return true
	var orb: Dictionary = _orbs.get(orb_id, {})
	var p: Dictionary = _players.get(player_id, {})
	if orb.is_empty() or p.is_empty() or orb.realm != p.realm or _flat_distance(orb.pos, p.pos) > XP_REACH:
		return false
	_orbs.erase(orb_id)
	(p.stats as PlayerStats).add_xp(orb.value)
	return true


# --- Online client mirror (fed by Net) ------------------------------------------------

## Client: drops what the last server showed us (bags, orbs).
func forget_world() -> void:
	for bag_id in _bags.keys():
		_remove_bag(bag_id)
	_orbs.clear()


func net_bag_added(record: Dictionary) -> void:
	_bags[record.id] = record
	bag_added.emit(record)


func net_bag_changed(bag_id: int, items: Array, opened := false) -> void:
	if _bags.has(bag_id):
		_bags[bag_id].items = items
		_bags[bag_id].opened = opened
		bag_changed.emit(bag_id)


func net_bag_removed(bag_id: int) -> void:
	if _bags.has(bag_id):
		_remove_bag(bag_id)


func net_xp_dropped(realm_id: String, pos: Vector3, orbs: Array) -> void:
	xp_dropped.emit(realm_id, pos, orbs)


## Server: the realm and position of a player ("" if not connected).
func player_realm(player_id: int) -> String:
	return _players[player_id].realm if _players.has(player_id) else ""


func player_position(player_id: int) -> Vector3:
	return _players[player_id].pos if _players.has(player_id) else Vector3.ZERO


func shield_up(player_id: int) -> bool:
	return _players.has(player_id) and _players[player_id].shield


# --- Helpers ------------------------------------------------------------------------

func _new_id() -> int:
	_next_id += 1
	return _next_id - 1


func _now() -> int:
	return Time.get_ticks_msec()


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Server-only grant API. Numeric durations are seconds; strings accept ms/s/m/h.
func apply_buff(player_id: int, effect: String, duration: Variant, amount: Variant = 1, source := "default") -> bool:
	if Net.is_client(): return false
	var stats := character(player_id)
	if stats == null or stats.hp<=0.0 or intro_protected(player_id): return false
	return stats.buffs.add(effect,duration,amount,source)

func remove_buff(player_id: int, effect: String, source := "") -> void:
	if Net.is_client(): return
	var stats := character(player_id)
	if stats: stats.buffs.remove(effect,source)

## Attack metadata: effects=[{id="stasis",duration="3s",amount=1}].
func apply_effects(player_id: int, effects: Array, source := "projectile") -> void:
	if Net.is_client(): return
	for e: Variant in effects:
		if e is Dictionary:
			apply_buff(player_id,str(e.get("id","")),e.get("duration",0),e.get("amount",1),str(e.get("source",source)))


## Also used for local prediction. The online server grants the same window
## once on realm entry and once when that entry finishes loading.
func grant_arrival_protection(player_id: int) -> void:
	var stats := character(player_id)
	if stats == null: return
	stats.buffs.add("immune", 3.0, 1, "realm_arrival")
	stats.buffs.add("invincible", 3.0, 1, "realm_arrival")
