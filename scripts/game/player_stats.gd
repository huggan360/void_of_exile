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
##   speed      +1% movement speed per point
##   dexterity  +1.5% shots per second per point (negative slows you down)
##   attack     +2% weapon damage per point
##   defense    subtracted from each normal hit (at least 15% still gets through);
##              armor-piercing hits ignore it
##   magic      how much damage the warp shield can soak up (3 per point)
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
const BASE := {speed = 8, attack = 8, dexterity = 12, defense = 12, magic = 10}
const BASE_HP := 100
## Levels 2-25 also raise max health by 10, 20 or 30.
const HP_GROWTH_LEVELS := 25
const BASE_MP := 100
## Stats only grow up to this level; levelling continues after it.
const STAT_GROWTH_LEVELS := 50
## Typical growth per level (1-3); some levels give one more (see _gain).
const GROWTH := {speed = 1, attack = 2, dexterity = 1, defense = 1, magic = 2}
const MIN_DAMAGE_TAKEN := 0.15
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


func xp_to_next() -> int:
	return 40 + level * 20


func add_xp(amount: int) -> void:
	xp += amount
	if amount > 0:
		xp_gained.emit(amount)
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		var gains := {}
		if level <= STAT_GROWTH_LEVELS:
			for stat in STATS:
				gains[stat] = _gain(stat, level)
				base[stat] += gains[stat]
		if level <= HP_GROWTH_LEVELS:
			gains.hp = [10, 20, 30][(level * 7) % 3]
			base_hp += gains.hp
			hp += gains.hp
		leveled_up.emit(level, gains)
	changed.emit()


## 1, 2 or 3 points: the stat's usual amount, sometimes one more or less
## depending on the level (fixed, so every Archer grows the same way).
func _gain(stat: String, at_level: int) -> int:
	var roll := (at_level * 7 + STATS.find(stat) * 5) % 6
	var bonus := 1 if roll == 0 else (-1 if roll == 5 else 0)
	return clampi(PlayerClasses.get_def(class_id).growth[stat] + bonus, 1, 3)


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


## A special effect from equipped gear. Multipliers (mp_regen, shield_drain,
## shield_absorb) multiply together; amounts (lifesteal, shield_heal) add up.
func effect(name: String, default: Variant = 0.0) -> Variant:
	var result: Variant = default
	for item: Item in gear.values():
		if item and item.effects.has(name):
			var v: Variant = item.effects[name]
			if v is String:
				return v
			if name in ["mp_regen", "shield_drain", "shield_absorb"]:
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
	return fits(moving, to) and fits(item_at(to), from)


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


## Moves a bag's item into the backpack (double-click). False if it's full.
func loot(place: Dictionary) -> bool:
	var item := item_at(place)
	if item == null or not _add(item):
		changed.emit()  # a stack may still have been topped up
		return false
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


## A stat elixir: the stat goes up for good.
func _raise(stat: String, amount: int) -> void:
	match stat:
		"hp":
			base_hp += amount
			hp += amount
		"mp":
			base_mp += amount
			mp += amount
		_:
			base[stat] += amount


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
		_raise(item.consumable.stat, item.consumable.amount)
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
	return maxf(0.5, 1.0 + total("speed") * 0.01)


## Shots per second relative to the weapon's base rate (dexterity and the
## weapon's own fire rate).
func shots_per_second_multiplier() -> float:
	var weapon: Item = gear.weapon
	var rate := weapon.fire_rate if weapon else 1.0
	return maxf(0.25, 1.0 + total("dexterity") * 0.015) * rate


## One projectile's damage from the equipped weapon, including attack.
func roll_damage() -> int:
	var weapon: Item = gear.weapon
	if weapon == null:
		return 0
	return int(round(randi_range(weapon.damage_min, weapon.damage_max) * (1.0 + total("attack") * 0.02)))


## How much of a hit actually lands, before any shield.
func mitigate(amount: float, armor_piercing := false) -> float:
	if armor_piercing:
		return amount
	return maxf(amount * MIN_DAMAGE_TAKEN, amount - total("defense"))


func shield_capacity() -> float:
	return maxf(0.0, total("magic") * 3.0) * effect("shield_absorb", 1.0)


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
		base[stat] = int(data.get("base", {}).get(stat, base[stat]))
	base_hp = int(data.get("base_hp", base_hp))
	base_mp = int(data.get("base_mp", base_mp))
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
