class_name PlayerStats
extends RefCounted
## The character's numbers: level and XP, health and magic, the five stats,
## the equipped gear that adds to them, and the backpack. Everything that
## reads a stat goes through total() so gear bonuses are always included.
##
## Owned by the server (GameServer): clients read it to draw the HUD and to
## predict what a drag will do, but only the server calls the methods that
## change it, after checking the request.
##
## What the stats do:
##   speed      +1.5% movement speed per point
##   dexterity  +2% shots per second per point (negative slows you down)
##   attack     +1.4% weapon damage per point
##   defense    subtracted from each normal hit (at least 15% still gets through);
##              armor-piercing hits ignore it
##   magic      shield reduction on a shared diminishing-returns curve, plus spell damage
## Gear can also raise max health ("hp") and max magic points ("mp").

signal changed
signal leveled_up(level: int, gains: Dictionary)
signal damaged(amount: int)
signal consumed(item: Item)
## XP earned (the account earns it too, see NetServer).
signal xp_gained(amount: int)

const STATS := ["speed", "attack", "dexterity", "defense", "magic"]
const STAT_NAMES := {speed = "Speed", attack = "Attack", dexterity = "Dexterity",
		defense = "Defence", magic = "Magic", hp = "Health", mp = "Magic points"}
const BASE := {speed = 0, attack = 0, dexterity = 0, defense = 0, magic = 0}
const BASE_HP := 100
const BASE_MP := 100
const MAX_LEVEL := 50
const STAT_GROWTH_LEVELS := MAX_LEVEL
const MIN_DAMAGE_TAKEN := 0.15
const SPEED_PER_POINT := 0.015
const DEXTERITY_PER_POINT := 0.02
const ATTACK_PER_POINT := 0.014
## One exponential curve for every class: 20 MAG = 35%, 70 ~= 80%, 110 = 93%.
const SHIELD_MAGIC_LINEAR := 0.020953380151240326
const SHIELD_MAGIC_QUADRATIC := 0.000029288282669119175
const MIN_SHIELDED_DAMAGE_SHARE := 0.000001
const GEAR_SLOTS := ["weapon", "armor", "spell", "bonus"]
const BACKPACK_SIZE := 16  # two rows to start with
const BACKPACK_UPGRADE := 16  # two more rows from a Backpack item
const QUICKSLOTS := 2

## Who this character belongs to on the server.
var buffs := StatusEffects.new()
var player_id := 0
## Its class (PlayerClasses): set it, then reset() for a fresh character.
var class_id := "archer"
## The realm town it calls home (it arrives there), "" = the capital.
var home := ""
## func(bag id) -> the bag's record ({} if gone), for bag places.
var bag_lookup := Callable()
var level := 1
var xp := 0
var hp := 100.0
var mp := 100.0
var base := BASE.duplicate()
var base_hp := BASE_HP
var base_mp := BASE_MP
## slot -> Item (or null)
var gear := Items.starting_gear()
## BACKPACK_SIZE entries (more with a backpack), each an Item or null.
var backpack: Array = []
## Strapped on a Backpack: the extra rows last until the character dies.
var has_backpack := false
## Consumables ready to use with F and G.
var quick: Array = [null, null]

var max_hp: int:
	get:
		var raw := base_hp + gear_bonus("hp")
		return maxi(1,raw + roundi(buffs.additive("hp",raw)))
var max_mp: int:
	get:
		var raw := base_mp + gear_bonus("mp")
		return maxi(0,raw + roundi(buffs.additive("mp",raw)))


func _init() -> void:
	backpack.resize(BACKPACK_SIZE)
	buffs.changed.connect(_buffs_changed)


func _buffs_changed() -> void:
	hp = minf(hp,max_hp)
	mp = minf(mp,max_mp)
	changed.emit()


## Shared by the HUD and XP ring; mirrored in character_total_xp in the account service.
## Quick to level 8, then a cubic ramp: ~70k XP in all to reach 26, ~2.3M to 50.
const LATE_XP := 3
static func xp_for_level(at_level: int) -> int:
	var late := maxi(0, at_level - 8)
	return 40 + at_level * 20 + LATE_XP * late * late * late


func xp_to_next() -> int:
	return xp_for_level(level)


func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	xp_gained.emit(amount)
	while level < MAX_LEVEL and xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		var gains := {}
		for stat in STAT_NAMES:
			var gain := _raise(stat, _gain(stat))
			if gain > 0:
				gains[stat] = gain
		leveled_up.emit(level, gains)
	changed.emit()


## Developer command: apply the same class-specific random growth as earned
## levels, without awarding account XP. Repeating it never rerolls past levels.
## Lowering a testing level keeps permanent stats (including potion gains).
func developer_set_level(target: int) -> void:
	target = clampi(target, 1, MAX_LEVEL)
	var previous := level
	var gains := {}
	while level < target:
		level += 1
		for stat in STAT_NAMES:
			var gain := _raise(stat, _gain(stat))
			if gain > 0: gains[stat] = int(gains.get(stat, 0)) + gain
	level = target
	xp = 0
	hp = max_hp
	mp = max_mp
	if target > previous: leveled_up.emit(level, gains)
	changed.emit()


## Fully trained permanent stats, excluding equipment and temporary buffs.
func developer_max_stats() -> void:
	for stat in STAT_NAMES: _raise(stat, stat_max(stat) - stat_base(stat))
	hp = max_hp
	mp = max_mp
	changed.emit()


## Called only by the authoritative XP path; clients load the resulting stats.
func _gain(stat: String) -> int:
	return PlayerClasses.growth_roll(class_id, stat)


## Permanent caps exclude equipment and temporary effects.
func stat_max(stat: String) -> int:
	return int(PlayerClasses.get_def(class_id).maximum.get(stat, 0))


func stat_base(stat: String) -> int:
	return base_hp if stat == "hp" else (base_mp if stat == "mp" else int(base.get(stat, 0)))


## Shared panel value: permanent progress, equipment bonus and effective buffed total.
func stat_display(stat: String) -> String:
	var value := "%d / %d" % [stat_base(stat), stat_max(stat)]
	if stat_base(stat) >= stat_max(stat):
		value = "[color=#ffd56b]%s[/color]" % value
	var bonus := gear_bonus(stat)
	if bonus != 0:
		value += " (%+d gear)" % bonus
	var effective := max_hp if stat == "hp" else (max_mp if stat == "mp" else total(stat))
	if effective != stat_base(stat) + bonus:
		value += " [%d effective]" % effective
	return value


func gear_bonus(stat: String) -> int:
	var total := 0
	for item: Item in gear.values():
		if item:
			total += item.bonuses.get(stat, 0)
	return total


func total(stat: String) -> int:
	var gear_stat := 0 if stat == "defense" and buffs.has_effect("armour_broken") else gear_bonus(stat)
	var raw: int = base[stat] + gear_stat
	return maxi(0,raw + roundi(buffs.additive(stat,raw)))


## A special effect from equipped gear. Multipliers (mp_regen, shield_drain)
## multiply together; amounts (lifesteal, shield_heal) add up.
func effect(name: String, default: Variant = 0.0) -> Variant:
	var result: Variant = default
	for item: Item in gear.values():
		if item and item.effects.has(name):
			var v: Variant = item.effects[name]
			if v is String:
				return v
			if name in ["mp_regen", "shield_drain"]:
				result = (result if result != 0.0 else 1.0) * v
			else:
				result += v
	return result


# --- Inventory --------------------------------------------------------------------
# A place is {kind = "gear", key = "weapon"}, {kind = "pack", key = 12},
# {kind = "quick", key = 0} or {kind = "bag", key = 3, bag = bag id}.

func item_at(place: Dictionary) -> Item:
	match place.kind:
		"gear":
			return gear.get(place.key)
		"quick":
			return quick[place.key]
		"bag":
			var b := _bag(place)
			return b.items[place.key] if not b.is_empty() else null
	return backpack[place.key]


## Where this character carries an item with this id (backpack first,
## then the quickslots), or {} when it doesn't.
func find_item(id: String) -> Dictionary:
	for i in backpack.size():
		if backpack[i] != null and (backpack[i] as Item).id == id:
			return {kind = "pack", key = i}
	for i in quick.size():
		if quick[i] != null and (quick[i] as Item).id == id:
			return {kind = "quick", key = i}
	return {}


func _put(place: Dictionary, item: Item) -> void:
	match place.kind:
		"gear":
			gear[place.key] = item
		"quick":
			quick[place.key] = item
		"bag":
			_bag(place).items[place.key] = item
		_:
			backpack[place.key] = item


## Whether `item` may go into `place`: gear slots only take their own kind,
## quickslots only consumables, and soulbound items never go in bags.
func fits(item: Item, place: Dictionary) -> bool:
	if item == null:
		return true
	match place.kind:
		"gear":
			return item.slot == place.key and item.usable_by(class_id)
		"quick":
			return item.is_consumable()
		"bag":
			var b := _bag(place)
			return not b.is_empty() and LootBag.can_hold(b.type, b.viewer == GameServer.PUBLIC, item)
	return true


## Can the item at `from` move to `to` (stacking onto or swapping with
## whatever is there)?
func can_move(from: Dictionary, to: Dictionary) -> bool:
	var moving := item_at(from)
	if moving == null:
		return false
	if _stacks(moving, item_at(to)):
		return true
	return fits(moving, to) and (fits(item_at(to), from) or _displace_slot(from, to) >= 0)


## Taking from a bag onto a taken slot whose item may not go in that bag
## (an elixir, a soulbound item in a public chest): the displaced item goes
## to a free backpack slot instead. -1 = no such way.
func _displace_slot(from: Dictionary, to: Dictionary) -> int:
	if from.kind != "bag" or to.kind == "bag" or item_at(to) == null:
		return -1
	var free := backpack.find(null)
	return free if fits(item_at(to), {kind = "pack", key = free}) else -1


func move(from: Dictionary, to: Dictionary) -> void:
	if not can_move(from, to) or from == to:
		return
	var moving := item_at(from)
	var there := item_at(to)
	if _stacks(moving, there):
		var take := mini(moving.count, there.stack_max - there.count)
		there.count += take
		moving.count -= take
		if moving.count <= 0:
			_put(from, null)
	elif not fits(there, from):
		backpack[_displace_slot(from, to)] = there
		_put(from, null)
		_put(to, moving)
	else:
		_put(from, there)
		_put(to, moving)
	hp = minf(hp, max_hp)
	mp = minf(mp, max_mp)
	changed.emit()


## Same consumable with room left: dropping one onto the other merges them.
func _stacks(item: Item, onto: Item) -> bool:
	return item != null and onto != null and item != onto and item.id == onto.id \
			and onto.stack_max > 1 and onto.count < onto.stack_max


func _bag(place: Dictionary) -> Dictionary:
	return bag_lookup.call(place.bag) if bag_lookup.is_valid() else {}


## Puts items into the backpack, topping up stacks first (returns how many
## fit; partly stacked items count as given once all of them fit).
func give(items: Array) -> int:
	var given := 0
	for item: Item in items:
		if _add(item):
			given += 1
	changed.emit()
	return given


## Elixirs top up a matching quickslot stack first, then backpack stacks;
## everything else goes in the first free backpack slot.
func _add(item: Item) -> bool:
	if item.stack_max > 1:
		for other in quick + backpack:
			if _stacks(item, other):
				var take := mini(item.count, other.stack_max - other.count)
				other.count += take
				item.count -= take
				if item.count <= 0:
					return true
	var free := backpack.find(null)
	if free < 0:
		return false
	backpack[free] = item
	return true


## Moves a bag's item into the backpack (double-click): consumables top up
## quickslot and backpack stacks first, then take a free slot. With no room
## left, a consumable is drunk right away instead. False if nothing happened.
func loot(place: Dictionary) -> bool:
	var item := item_at(place)
	if item == null:
		return false
	var before := item.count
	if not _add(item):
		if item.is_consumable() and use(place):
			return true
		changed.emit()  # a stack may still have been topped up
		return item.count < before
	_put(place, null)
	changed.emit()
	return true


## Takes an item out of the inventory (to drop it on the ground).
func take(place: Dictionary) -> Item:
	var item := item_at(place)
	if item:
		_put(place, null)
		hp = minf(hp, max_hp)
		mp = minf(mp, max_mp)
		changed.emit()
	return item


## Raises a permanent stat up to its cap; returns the actual gain.
func _raise(stat: String, amount: int) -> int:
	var gain := clampi(amount, 0, maxi(0, stat_max(stat) - stat_base(stat)))
	match stat:
		"hp":
			base_hp += gain
			hp += gain
		"mp":
			base_mp += gain
			mp += gain
		_:
			if base.has(stat):
				base[stat] += gain
	return gain


## The extra backpack rows.
func add_backpack() -> void:
	has_backpack = true
	backpack.resize(BACKPACK_SIZE + BACKPACK_UPGRADE)
	changed.emit()


## Dying loses the backpack and everything in its rows. Returns how many
## items were lost.
func lose_backpack() -> int:
	if not has_backpack:
		return 0
	var lost := backpack.slice(BACKPACK_SIZE).filter(func(i: Variant) -> bool: return i != null).size()
	has_backpack = false
	backpack.resize(BACKPACK_SIZE)
	changed.emit()
	return lost


## A double-click on a slot: take from a bag, drink or use a consumable,
## equip gear from the backpack, or take gear off into the backpack.
func activate(place: Dictionary) -> bool:
	var item := item_at(place)
	if item == null:
		return false
	if place.kind == "bag":
		return loot(place)
	if item.is_consumable():
		return use(place)
	if item.is_key() or item.is_story():
		return false  # used at its fortress gate / read on this screen, never worn
	if place.kind == "pack":
		var gear_place := {kind = "gear", key = item.slot}
		if can_move(place, gear_place):
			move(place, gear_place)
			return true
	elif place.kind == "gear":
		var free := backpack.find(null)
		if free >= 0:
			move(place, {kind = "pack", key = free})
			return true
	return false


## Drinks one of the consumable at `place` (a quickslot or the backpack).
func use(place: Dictionary) -> bool:
	var item := item_at(place)
	if item == null or not item.is_consumable():
		return false
	if item.consumable.has("backpack"):
		if has_backpack:
			return false  # one is all you can carry
		add_backpack()
	elif item.consumable.has("stat"):
		if _raise(item.consumable.stat, item.consumable.amount) == 0:
			return false
	elif item.consumable.has("hp") and hp >= max_hp and not item.consumable.has("mp"):
		return false  # already full: don't waste it
	if item.consumable.has("mp") and mp >= max_mp and not item.consumable.has("hp"):
		return false
	hp = minf(max_hp, hp + item.consumable.get("hp", 0))
	mp = minf(max_mp, mp + item.consumable.get("mp", 0))
	item.count -= 1
	if item.count <= 0:
		_put(place, null)
	consumed.emit(item)
	changed.emit()
	return true


# --- What stats do ----------------------------------------------------------------

func move_speed_multiplier() -> float:
	return maxf(0.5, 1.0 + total("speed") * SPEED_PER_POINT)


func dexterity_multiplier() -> float:
	return maxf(0.25, 1.0 + total("dexterity") * DEXTERITY_PER_POINT)


func weapon_damage_multiplier() -> float:
	return 1.0 + total("attack") * ATTACK_PER_POINT


## Shots per second relative to the weapon's base rate (dexterity and the
## weapon's own fire rate).
func shots_per_second_multiplier() -> float:
	var weapon: Item = gear.weapon
	var rate := weapon.fire_rate if weapon else 1.0
	return dexterity_multiplier() * rate


## One projectile's damage from the equipped weapon, including attack.
func roll_damage() -> int:
	var weapon: Item = gear.weapon
	if weapon == null:
		return 0
	return int(round(randi_range(weapon.damage_min, weapon.damage_max) * weapon_damage_multiplier()))


## How much of a hit actually lands, before any shield.
func mitigate(amount: float, armor_piercing := false) -> float:
	if armor_piercing:
		return amount
	return maxf(amount * MIN_DAMAGE_TAKEN, amount - total("defense"))


## Remaining fraction of a regular hit, before Defence. Even extremely high
## MAG leaves a positive fraction; equipment contributes through visible MAG.
func shield_damage_multiplier() -> float:
	var magic := float(maxi(0,total("magic")))
	return maxf(MIN_SHIELDED_DAMAGE_SHARE,exp(-SHIELD_MAGIC_LINEAR*magic-SHIELD_MAGIC_QUADRATIC*magic*magic))


func shield_reduction() -> float:
	return 1.0-shield_damage_multiplier()


## Spell damage grows with Magic, independently of bow Attack. When hovering
## a different spell, predict Magic with that spell equipped rather than double-counting it.
func spell_multiplier(spell: Item) -> float:
	var magic := total("magic")
	var equipped: Item = gear.spell
	if equipped:
		magic -= equipped.bonuses.get("magic", 0)
	magic += spell.bonuses.get("magic", 0)
	return 1.0 + maxf(0.0, magic) * 0.015


# --- Saving (the account service keeps this, see Net) ------------------------------

## Everything about the character as plain data (JSON-safe).
func to_data() -> Dictionary:
	var gear_data := {}
	for slot in gear:
		gear_data[slot] = _item_data(gear[slot])
	return {
		version = 1, class_id = class_id, home = home, level = level, xp = xp, hp = hp, mp = mp,
		base = base.duplicate(), base_hp = base_hp, base_mp = base_mp, has_backpack = has_backpack,
		gear = gear_data, backpack = backpack.map(_item_data), quick = quick.map(_item_data),
	}


## Replaces the character with saved data (a new character if it's empty).
func load_data(data: Dictionary) -> void:
	# A network inventory/stat update must never publish reset's level 1 / 0 XP
	# state. Observers receive exactly one complete replacement.
	var blocked := is_blocking_signals()
	set_block_signals(true)
	_load_data(data)
	set_block_signals(blocked)
	changed.emit()


func _load_data(data: Dictionary) -> void:
	reset()
	if data.is_empty():
		return
	var saved_class := str(data.get("class_id", class_id))
	if PlayerClasses.exists(saved_class) and saved_class != class_id:
		class_id = saved_class
		reset()
	level = int(data.get("level", 1))
	xp = int(data.get("xp", 0))
	home = str(data.get("home", ""))
	for stat in STATS:
		base[stat] = clampi(int(data.get("base", {}).get(stat, base[stat])), 0, stat_max(stat))
	base_hp = clampi(int(data.get("base_hp", base_hp)), 1, stat_max("hp"))
	base_mp = clampi(int(data.get("base_mp", base_mp)), 0, stat_max("mp"))
	has_backpack = bool(data.get("has_backpack", false))
	backpack.resize(BACKPACK_SIZE + (BACKPACK_UPGRADE if has_backpack else 0))
	backpack.fill(null)
	var saved_gear: Dictionary = data.get("gear", {})
	for slot in GEAR_SLOTS:
		gear[slot] = _item_from(saved_gear.get(slot)) if saved_gear.has(slot) else gear.get(slot)
	var saved_pack: Array = data.get("backpack", [])
	for i in mini(saved_pack.size(), backpack.size()):
		backpack[i] = _item_from(saved_pack[i])
	var saved_quick: Array = data.get("quick", [])
	for i in mini(saved_quick.size(), QUICKSLOTS):
		quick[i] = _item_from(saved_quick[i])
	hp = clampf(float(data.get("hp", max_hp)), 1.0, max_hp)
	mp = clampf(float(data.get("mp", max_mp)), 0.0, max_mp)
	changed.emit()


## Campaign inventory is owned by its book, never by an unrelated character.
## Include keys only at explicit campaign boundaries; ordinary realm keys remain valid.
func purge_story_items(include_keys := false) -> Array[Item]:
	var removed: Array[Item] = []
	for inventory: Array in [backpack, quick]:
		for i in inventory.size():
			var item: Item = inventory[i]
			if item and (item.is_story() or include_keys and item.is_key()):
				removed.append(item)
				inventory[i] = null
	for slot: String in gear:
		var item: Item = gear[slot]
		if item and (item.is_story() or include_keys and item.is_key()):
			removed.append(item)
			gear[slot] = null
	if not removed.is_empty(): changed.emit()
	return removed


## A brand new character of its class: level 1, starting gear, nothing carried.
func reset() -> void:
	buffs.clear()
	var def := PlayerClasses.get_def(class_id)
	level = 1
	xp = 0
	home = ""
	base = def.base.duplicate()
	base_hp = def.hp
	base_mp = def.mp
	gear = PlayerClasses.starting_gear(class_id)
	has_backpack = false
	backpack = []
	backpack.resize(BACKPACK_SIZE)
	quick = [null, null]
	hp = max_hp
	mp = max_mp
	changed.emit()


## How many items the character carries (gear, backpack, quickslots).
func carried_count() -> int:
	return (gear.values() + backpack + quick).filter(func(i: Variant) -> bool: return i != null).size()


static func _item_data(item: Variant) -> Variant:
	return {id = item.id, count = item.count} if item != null else null


static func _item_from(data: Variant) -> Item:
	if not data is Dictionary or not Items.exists(str(data.get("id", ""))):
		return null
	var item := Items.make(str(data.id))
	item.count = clampi(int(data.get("count", 1)), 1, maxi(1, item.stack_max))
	return item
