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
##
## Private rolls follow damage: the top contributor (or a lone player) rolls
## each item's full chance, someone just over the threshold only
## EnemyDef.loot_share_floor of it (0.9: a 5% item rolls 4.5%), and everyone
## between them slides along with what they dealt. A drop never holds two items
## of the same kind (two bows): only the rarest stays, Divine or Legendary before any grade.

## Every boss's two stat elixirs: each player over its damage threshold always
## gets one of them, 50/50. These replace any elixir_of_ entry in a boss's
## table (and dungeon boss potions). Regeneration (vitality) took one stat from six
## realm bosses and Mother Mycora.
const BOSS_POTIONS := {
	vharok = ["attack", "defense"], goblin_king = ["attack", "speed"], magma_warden = ["attack", "dexterity"],
	stormeye_tyrant = ["attack", "magic"], hollow_king = ["attack", "hp"], pyre_ent = ["attack", "vitality"],
	amber_colossus = ["defense", "speed"], veil_herald = ["defense", "dexterity"], gilded_vizier = ["defense", "magic"],
	scarab_regent = ["defense", "vitality"], abyssal_siren = ["defense", "mp"],
	mad_farmer = ["speed", "dexterity"], selenarch = ["speed", "magic"], thornmaw_bloom = ["speed", "vitality"],
	hollow_crown = ["speed", "mp"],
	rimeheart_prism = ["dexterity", "magic"], void_empress = ["dexterity", "hp"], drowned_cantor = ["dexterity", "vitality"],
	queen_briarrose = ["magic", "vitality"], blue_dragon = ["magic", "mp"],
	brood_matriarch = ["hp", "vitality"],
	# The Surface dungeons (Oblivara rolls one to three of any stat instead: EnemyDef.dungeon_potions).
	mother_mycora = ["vitality", "mp"], captain_saltmourn = ["attack", "dexterity"], ixalith = ["magic", "speed"],
	lantern_shepherd = ["speed", "dexterity"], jarl_hrimvald = ["defense", "attack"], solenne = ["magic", "mp"],
	choirless_seraph = ["attack", "mp"],
}

## The harder bosses roll extra high grades on top of their own table (each
## roll on its own, so a lucky chest holds two G6 and a G7): grade 7 bosses
## G6 30% and G7 15%, grade 8 bosses G6 40%, G7 30% and G8 15%. Every other
## boss tops out at G6.
const BOSS_GRADES := {
	stormeye_tyrant = 8, brood_matriarch = 8, selenarch = 8, hollow_king = 8,
	amber_colossus = 7, veil_herald = 7, vharok = 7, pyre_ent = 7, hollow_crown = 7, rimeheart_prism = 7,
	drowned_cantor = 7, scarab_regent = 7, blue_dragon = 7, void_empress = 7,
	# The Surface dungeons, by rating.
	mother_mycora = 4, captain_saltmourn = 5, ixalith = 6, lantern_shepherd = 6, jarl_hrimvald = 7, solenne = 8,
	choirless_seraph = 9, oblivara = 10,
}
const GRADE_ROLLS := {
	7: [{pool = {tier = 6}, chance = 0.30}, {pool = {tier = 7}, chance = 0.15}],
	8: [{pool = {tier = 6}, chance = 0.40}, {pool = {tier = 7}, chance = 0.30}, {pool = {tier = 8}, chance = 0.15}],
	# The Surface dungeons' own: 3.5 and 4.5 rated bosses top out at G5/G6, the 9/10 and 10/10 at G8 twice.
	4: [{pool = {tier = 4}, chance = 0.60}, {pool = {tier = 5}, chance = 0.15}],
	5: [{pool = {tier = 5}, chance = 0.40}, {pool = {tier = 6}, chance = 0.08}],
	6: [{pool = {tier = 5}, chance = 0.40}, {pool = {tier = 6}, chance = 0.25}],
	9: [{pool = {tier = 6}, chance = 0.50}, {pool = {tier = 7}, chance = 0.40}, {pool = {tier = 8}, chance = 0.25}],
	10: [{pool = {tier = 7}, chance = 0.60}, {pool = {tier = 8}, chance = 0.45}, {pool = {tier = 8}, chance = 0.25}],
}


## [{items: Array[Item], viewer: player id or GameServer.PUBLIC}] - one entry
## per bag. damage_by: player id -> damage dealt.
## max_hp: the health this kill really had (bosses scale theirs with the
## players present); 0 = the def's base health. Eligibility is a share of it.
static func roll(def: EnemyDef, damage_by: Dictionary, rng: RandomNumberGenerator, biome_stat: Variant = "magic",
		max_hp := 0, modifiers: Dictionary = {}) -> Array[Dictionary]:
	var bags: Array[Dictionary] = []
	if damage_by.is_empty():
		return bags
	var health := max_hp if max_hp > 0 else def.hp
	var eligible := damage_by.keys().filter(func(p: int) -> bool:
		return damage_by[p] >= health * def.loot_threshold)
	var top := 0
	for p in eligible:
		if top == 0 or damage_by[p] > damage_by[top]:
			top = p
	var share := {}  # player id -> share of each chance they roll with
	for p in eligible:
		share[p] = share_factor(def.loot_share_floor, float(damage_by[p]), health * def.loot_threshold, float(damage_by[top]))

	# Public rolls use the highest contributor's bonus once, never once per player.
	var public_owner := 0
	for pid in damage_by:
		if public_owner == 0 or damage_by[pid]>damage_by[public_owner]: public_owner = pid
	var public_mod: Dictionary = modifiers.get(public_owner,{})
	var public: Array[Item] = []
	var personal := {}  # player id -> Array[Item]
	var pair: Array = BOSS_POTIONS.get(def.id, []) if def is BossDef else []
	for entry: Dictionary in _with_special(def):
		if not pair.is_empty() and str(entry.get("item", "")).begins_with("elixir_of_"):
			continue
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
			var base_chance := Items.signature_chance(sample) if sample.is_legendary() or sample.is_artifact() else Items.divine_chance(sample, def.id) if sample.is_divine() else float(entry.chance)
			var chance: float = base_chance * float(share[p])
			var bonus: Dictionary = modifiers.get(p,{})
			chance = minf(1.0,chance*(1.0+float(bonus.get("chance",0.0))))
			if rng.randf() < chance:
				if not personal.has(p):
					personal[p] = []
				personal[p].append(upgrade(_make(entry, rng, biome_stat),float(bonus.get("tier",0.0)),rng))
	for p in eligible:
		if pair.is_empty(): break
		if not personal.has(p): personal[p] = []
		personal[p].append(Items.stat_elixir(str(pair[rng.randi_range(0, 1)])))
	if def.dungeon_reward and pair.is_empty():
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
	# Eggs always belong to the top damage dealer, without loot bonuses.
	if public_owner != 0 and rng.randf() < (0.02 if def is BossDef else 0.0015):
		if not personal.has(public_owner): personal[public_owner] = []
		personal[public_owner].append(Items.make("pet_egg"))
	# Story items never compete with ordinary loot for a chest or tier.
	var story := public.filter(func(item: Item) -> bool: return item.is_story())
	public = public.filter(func(item: Item) -> bool: return not item.is_story())
	_pack(bags, story, GameServer.PUBLIC)
	if not personal.is_empty() and not public.is_empty():
		if not personal.has(public_owner): personal[public_owner] = []
		personal[public_owner].append_array(public)
		public.clear()
	_pack(bags, rarest_per_kind(public), GameServer.PUBLIC)
	for p in personal:
		_pack(bags, rarest_per_kind(personal[p]), p)
	return bags


## The share of an item's chance a contributor rolls with: `floor` just over
## the loot threshold, 1.0 for the top damage dealer, linear in between.
static func share_factor(floor_share: float, dealt: float, threshold: float, top_dealt: float) -> float:
	if top_dealt <= threshold: return 1.0
	return lerpf(clampf(floor_share, 0.0, 1.0), 1.0, clampf((dealt - threshold) / (top_dealt - threshold), 0.0, 1.0))


## Preserve every distinct special item. For regular gear, only the best
## grade per kind survives, and special gear displaces that graded kind.
static func rarest_per_kind(items: Array) -> Array:
	# Every distinct special reward survives. A Legendary bow must never erase
	# a Divine bow (or an Artifact) rolled alongside it in the same black chest.
	var specials := {}
	var special_kinds := {}
	var unique: Array = []
	for item: Item in items:
		if item == null or not item.is_special(): continue
		# A showpiece may be weak in combat; keep useful graded gear beside it.
		if not item.is_artifact(): special_kinds[item.slot + ":" + item.kind] = true
		if specials.has(item.id): continue
		specials[item.id] = true
		unique.append(item)
	var best := {}  # kind -> index of the kept item
	var kept: Array = unique
	for item: Item in items:
		if item != null and (item.is_special() or special_kinds.has(item.slot + ":" + item.kind)): continue
		if item == null or not item.slot in PlayerStats.GEAR_SLOTS:
			kept.append(item)
			continue
		var kind := item.slot + ":" + (item.kind if item.kind != "" else item.id.trim_prefix("G%d_" % item.tier))
		if not best.has(kind):
			best[kind] = kept.size()
			kept.append(item)
		elif _rarity(item) > _rarity(kept[best[kind]]):
			kept[best[kind]] = item
	return kept


static func _rarity(item: Item) -> int:
	return 200 if item.is_legendary() or item.is_artifact() else 100 if item.is_divine() else item.tier


## The loot table plus a harder boss's grade rolls (BOSS_GRADES) and every
## piece of the enemy's Divine set, listed cross-set relics and Legendary gear that the
## table doesn't name. Divine chances come from
## Items.divine_chance, not from the table.
static func _with_special(def: EnemyDef) -> Array:
	var table: Array = []
	var named := {}
	for original: Dictionary in def.loot:
		var entry := original
		if entry.has("item"):
			var id := str(entry.item)
			# Old server overrides must not turn four retired relics into four
			# extra rolls for the surviving one. Save migration is separate.
			if Items.RETIRED_ITEM_IDS.has(id) and id != "D_wand_thewandofash": continue
			id = Items.canonical_id(id)
			if id.begins_with("D_") or id.begins_with("L_") or id.begins_with("A_"):
				if named.has(id): continue
				entry = entry.duplicate()
				entry.item = id
			named[id] = true
		table.append(entry)
	if def is BossDef: table.append_array(GRADE_ROLLS.get(BOSS_GRADES.get(def.id, 0), []))
	for id in Items.loot_ids_for(def.id) + Items.BOSS_DIVINE_EXTRAS.get(def.id, []):
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
	if item.is_artifact():
		return def is BossDef and item.id in Items.artifact_ids_for(def.id)
	if item.is_legendary():
		return def is BossDef and item.id in Items.legendary_ids_for(def.id)
	if item.is_divine():
		# Assigned full set plus explicitly listed cross-set boss relics.
		return item.id in Items.divine_ids_for(def.id) or item.id in Items.BOSS_DIVINE_EXTRAS.get(def.id, [])
	if item.is_consumable():
		return true
	# Grades below 7 (the gentler Surface dungeons) only name their own roll table; bosses cap at G6 or more.
	var cap: int = maxi(BOSS_GRADES.get(def.id, 6), 6) if def is BossDef else 5 if def.is_god else 4
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


## Upgrade already-dropped graded gear one step. Never Divine, Legendary or consumables.
static func upgrade(item: Item, chance: float, rng: RandomNumberGenerator) -> Item:
	if item == null or item.is_consumable() or item.is_special() or item.tier>=8 or chance<=0.0:
		return item
	if rng.randf()>=clampf(chance,0.0,1.0): return item
	var prefix := "G%d_" % item.tier
	if not item.id.begins_with(prefix): return item
	var next_id := "G%d_" % (item.tier+1)+item.id.substr(prefix.length())
	if not Items.exists(next_id): return item
	var higher := Items.make(next_id)
	higher.count = item.count
	return higher
