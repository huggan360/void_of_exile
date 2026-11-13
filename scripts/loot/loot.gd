class_name Loot
## Rolls what an enemy drops when it dies (Realm of the Mad God style).
## Runs on the server (GameServer.enemy_killed).
##
## Each enemy has a loot table (EnemyDef.loot): entries of
##   {item = "elixir_hp", chance = 0.4}           a specific item
##   {pool = {tier = 2, slots = ["weapon", "armor"]}, chance = 0.1}
##                                                 any graded item that fits
## with chance 1.0 meaning a guaranteed drop.
##
## Bosses and gods roll all rewards privately for each eligible contributor.
## Ordinary public rolls remain shared unless merged into their top contributor's
## private chest. One ordinary chest per recipient uses its best item's tier;
## HP/MP elixirs are discarded above gray. Story chests always stay separate.

const OTHERS_CHANCE := 0.9


## [{items: Array[Item], viewer: player id or GameServer.PUBLIC}] - one entry
## per bag. damage_by: player id -> damage dealt.
## max_hp: the health this kill really had (bosses scale theirs with the
## players present); 0 = the def's base health. Eligibility is a share of it.
static func roll(def: EnemyDef, damage_by: Dictionary, rng: RandomNumberGenerator, biome_stat: Variant = "magic",
		max_hp := 0, modifiers: Dictionary = {}) -> Array[Dictionary]:
	var bags: Array[Dictionary] = []
	if damage_by.is_empty() or def.loot.is_empty():
		return bags
	var health := max_hp if max_hp > 0 else def.hp
	var eligible := damage_by.keys().filter(func(p: int) -> bool:
		return damage_by[p] >= health * def.loot_threshold)
	var top := 0
	for p in eligible:
		if top == 0 or damage_by[p] > damage_by[top]:
			top = p

	# Public rolls use the highest contributor's bonus once, never once per player.
	var public_owner := 0
	for pid in damage_by:
		if public_owner == 0 or damage_by[pid]>damage_by[public_owner]: public_owner = pid
	var public_mod: Dictionary = modifiers.get(public_owner,{})
	var public: Array[Item] = []
	var personal := {}  # player id -> Array[Item]
	for entry: Dictionary in _with_divine(def):
		var sample := _make(entry, rng, biome_stat)
		if sample == null or not _allowed(def, sample):
			continue
		if not sample.soulbound() and not def.is_god and not def is BossDef:
			if rng.randf() < minf(1.0,float(entry.chance)*(1.0+float(public_mod.get("chance",0.0)))):
				var upgraded := upgrade(sample,float(public_mod.get("tier",0.0)),rng)
				if upgraded.soulbound():
					if not personal.has(public_owner): personal[public_owner] = []
					personal[public_owner].append(upgraded)
				else: public.append(upgraded)
			continue
		for p in eligible:
			var chance: float = Items.divine_chance(sample, def.id) if sample.is_divine() \
					else entry.chance * (1.0 if p == top or eligible.size() == 1 else OTHERS_CHANCE)
			var bonus: Dictionary = modifiers.get(p,{})
			chance = minf(1.0,chance*(1.0+float(bonus.get("chance",0.0))))
			if rng.randf() < chance:
				if not personal.has(p):
					personal[p] = []
				personal[p].append(upgrade(_make(entry, rng, biome_stat),float(bonus.get("tier",0.0)),rng))
	if def.dungeon_reward:
		for p in eligible:
			if rng.randf() < 0.95:
				if not personal.has(p): personal[p] = []
				var count := 1
				if def.dungeon_potion_max > 1:
					var luck := clampf(0.15 * (1.0 + float(modifiers.get(p, {}).get("chance", 0.0))), 0.0, 0.75)
					for extra in def.dungeon_potion_max - 1:
						if rng.randf() < luck: count += 1
				for potion in count:
					personal[p].append(Items.stat_elixir(str(def.dungeon_potions[rng.randi_range(0, def.dungeon_potions.size() - 1)])))
	# Story items never compete with ordinary loot for a chest or tier.
	var story := public.filter(func(item: Item) -> bool: return item.is_story())
	public = public.filter(func(item: Item) -> bool: return not item.is_story())
	_pack(bags, story, GameServer.PUBLIC)
	if not personal.is_empty() and not public.is_empty():
		if not personal.has(public_owner): personal[public_owner] = []
		personal[public_owner].append_array(public)
		public.clear()
	_pack(bags, public, GameServer.PUBLIC)
	for p in personal:
		_pack(bags, personal[p], p)
	return bags


## The loot table plus every piece of the enemy's Divine set (and its listed
## cross-set relics) that the table doesn't name. Divine chances come from
## Items.divine_chance, not from the table.
static func _with_divine(def: EnemyDef) -> Array:
	var table: Array = def.loot.duplicate()
	var named := {}
	for entry: Dictionary in table:
		if entry.has("item"): named[entry.item] = true
	for id in Items.divine_ids_for(def.id) + Items.BOSS_DIVINE_EXTRAS.get(def.id, []):
		if not named.has(id): table.append({item = id, chance = 0.0})
	return table


static func _make(entry: Dictionary, rng: RandomNumberGenerator, biome_stat: Variant = "magic") -> Item:
	if entry.get("biome_stat", false):
		var stat: String = biome_stat[rng.randi_range(0, biome_stat.size() - 1)] if biome_stat is Array and not biome_stat.is_empty() else str(biome_stat)
		return Items.stat_elixir(stat)
	if entry.has("item"):
		return Items.make(entry.item)
	return Items.from_pool(entry.pool, rng)


## Realm safety rules apply even if a future loot table accidentally exceeds its cap.
static func _allowed(def: EnemyDef, item: Item) -> bool:
	if item.is_divine():
		# Assigned full set plus explicitly listed cross-set boss relics.
		return item.id in Items.divine_ids_for(def.id) or item.id in Items.BOSS_DIVINE_EXTRAS.get(def.id, [])
	if item.is_consumable():
		return true
	var cap := 8 if def.id == "hollow_king" else 6 if def is BossDef else 5 if def.is_god else 4
	return item.tier <= cap


## One ordinary chest plus an optional story chest, without truncating loot.
static func _pack(bags: Array[Dictionary], items: Array, viewer: int) -> void:
	var story: Array = items.filter(func(item: Item) -> bool: return item != null and item.is_story())
	var ordinary: Array = items.filter(func(item: Item) -> bool: return item != null and not item.is_story())
	if not story.is_empty(): bags.append({items = story, viewer = viewer, type = "story"})
	if ordinary.is_empty(): return
	var tier := LootBag.type_for(ordinary)
	if tier != "gray":
		ordinary = ordinary.filter(func(item: Item) -> bool: return not item.is_elixir())
	if not ordinary.is_empty(): bags.append({items = ordinary, viewer = viewer, type = tier})


## Upgrade only already-dropped graded gear, by exactly one step. Never divine or consumables.
static func upgrade(item: Item, chance: float, rng: RandomNumberGenerator) -> Item:
	if item == null or item.is_consumable() or item.is_divine() or item.tier>=8 or chance<=0.0:
		return item
	if rng.randf()>=clampf(chance,0.0,1.0): return item
	var prefix := "G%d_" % item.tier
	if not item.id.begins_with(prefix): return item
	var next_id := "G%d_" % (item.tier+1)+item.id.substr(prefix.length())
	if not Items.exists(next_id): return item
	var higher := Items.make(next_id)
	higher.count = item.count
	return higher
