class_name DungeonDivineSets
## The Divine sets of the Surface dungeons (docs/dungeons/SURFACE_DUNGEONS.md).
## Their power follows the dungeon's rating: the Sporewomb's pieces are fun
## more than strong, the Starless Sepulchre's are the best gear in the game.
## Each set leans the way its boss does and pays for it somewhere (the
## Afterlife's spirits are fast and dextrous but strike softly).
##
## Items.divine() calls build() with the other sets, and finish() last of all,
## so the shot looks, patterns and charges set here are the ones that stay.

## The sets live in Items.DIVINE_SETS (with their bosses in BOSS_DIVINE_SET and
## their rarity in DIVINE_SOURCE_SCALE: the harder the dungeon, the rarer each piece).
const SET_NAMES := ["Mycelium", "Saltmourn", "Jade", "Afterlife", "Barrow", "Prism", "Requiem", "Unmade"]

const SPORE := Color("ffb347")
const SPORE_TEAL := Color("6fe8d6")
const BRONZE := Color("d0903a")
const SEA := Color("3fd8c8")
const JADE := Color("4fd88a")
const JADE_GOLD := Color("ffd060")
const SOUL := Color("5ff0ff")
const SOUL_PINK := Color("e070ff")
const ICE := Color("8ad8ff")
const ICE_WHITE := Color("e8f8ff")
const PRISM := Color("fff6d8")
const PRISM_PINK := Color("ff8af0")
const HYMN := Color("c070ff")
const CANDLE := Color("ffcf8a")
const GOLD := Color("ffc24a")
const NIGHT := Color("18161e")


static func build(out: Array[Item]) -> void:
	# --- Mycelium (Mother Mycora, 3.5): soft, slow spores; health over power.
	_weapon(out, "D_wand_ofmycelium", "Puffcap Scepter", "Wand", "It sneezes when it's happy. It is always happy.",
		{hp = 30, mp = 20}, ["Two slow spore puffs that slow what they touch",
		"Charged: Spore Bloom, ten drifting puffs all around you"], Vector2i(85, 105))
	_relic(out, "D_bonus_talisman_ofmycelium", "Mycelium Heart", "Talisman",
		"A knot of threads that beats, very slowly, in time with the woods.", {hp = 30, regeneration = 6, defense = 4, speed = -2}, SPORE_TEAL)
	# --- Saltmourn (Captain Saltmourn, 4.5): heavy, slow, loud.
	_weapon(out, "D_bow_ofsaltmourn", "Broadside Longbow", "Bow", "Every shot is a cannon going off below decks.",
		{attack = 4, dexterity = -4}, ["Slow, heavy iron shots that crack armour",
		"Charged: Full Broadside, six shots across a wide arc"], Vector2i(190, 220))
	_weapon(out, "D_trident_ofsaltmourn", "Saltmourn's Harpoon", "Trident", "Barbed for whales. It has never met one it liked.",
		{attack = 5, dexterity = 3}, ["Piercing harpoons", "Charged: Riptide, twelve harpoons in a rush"], Vector2i(150, 175))
	_armor(out, "D_cloak_ofsaltmourn", "Captain's Stormcoat", "Cloak", "Salt in every seam. It still smells of the last storm.",
		{defense = 13, attack = 5, dexterity = 5, speed = -2}, SEA)
	# --- Jade (Ixalith, 5.5): quick feathered magic.
	_weapon(out, "D_wand_ofjade", "Coil of Ixalith", "Wand", "A jade serpent sleeps around the rod. It is not asleep.",
		{magic = 7, speed = 3}, ["Twin feathers that weave and slow", "Charged: Plumed Spiral, four feathered streams"],
		Vector2i(115, 140))
	_armor(out, "D_cloak_ofjade", "Quetzal Mantle", "Cloak", "Every plume was given, never taken.",
		{defense = 12, speed = 6, magic = 4, dexterity = 3}, JADE)
	_relic(out, "D_bonus_eye_ofjade", "Eye of the Coil", "Eye", "It watches the way a serpent waits.",
		{dexterity = 8, magic = 4, speed = 2}, JADE_GOLD)
	# --- Afterlife (Elegy, 6.0): speed and dexterity, paid for in attack.
	_weapon(out, "D_wand_oftheafterlife", "Wand of the Last Breath", "Wand",
		"The last breath of a thousand souls, let go all at once.",
		{dexterity = 16, speed = 4, attack = -8}, ["A near-endless beam of tiny soul wisps: light hits, very fast",
		"Charged: Requiem of Souls, a sweeping torrent of 24 wisps"], Vector2i(44, 52))
	_armor(out, "D_cloak_oftheafterlife", "Shroud of the Ferryman", "Cloak",
		"Worn by the one who carries the dead across. It weighs nothing at all.",
		{defense = 11, speed = 8, dexterity = 7, attack = -4}, SOUL)
	_relic(out, "D_bonus_talisman_oftheafterlife", "Lantern of the Shepherd", "Talisman",
		"A soul sleeps in it. It lights the way, and only the way.", {speed = 5, dexterity = 6, mp = 30, attack = -3}, SOUL)
	# --- Barrow (Jarl Hrimvald, 7.0): an old king's iron and ice; tough and slow.
	_weapon(out, "D_trident_ofthebarrow", "Hrimvald's Oathspear", "Trident", "Sworn on, bled on, buried with. Now it is yours to keep.",
		{attack = 5, defense = 6, speed = -3}, ["Piercing ice spears that slow", "Charged: Wintermarch, fourteen spears that freeze"],
		Vector2i(210, 240))
	_armor(out, "D_cloak_ofthebarrow", "Wolfpelt of the Jarl", "Cloak", "The wolf was a king too, once.",
		{defense = 24, hp = 70, attack = 6, speed = -3}, ICE)
	_armor(out, "D_robe_ofthebarrow", "Shroud of the Barrow-Seer", "Robe", "Its runes speak only in winter.",
		{defense = 19, magic = 18, mp = 70, hp = 40, speed = -2}, ICE)
	_relic(out, "D_bonus_crucifix_ofthebarrow", "Barrow Rune", "Crucifix", "Cut into the king's own cairn.",
		{defense = 9, hp = 75, attack = 3}, ICE)
	# --- Prism (Solenne, 8.0): light split into every color; magic and precision.
	_weapon(out, "D_bow_ofprism", "Refraction", "Bow", "Strung with light. The arrow is whatever color it pleases.",
		{dexterity = 6, magic = 6}, ["Three prismatic shards in a fan",
		"Charged: Spectrum, a prism that bursts into a ring of ten shards"], Vector2i(135, 155))
	_spell(out, "D_spell_ofprism", "Spell of the Prism", "The shield it raises is every color you have never seen.",
		{magic = 30, mp = 100, dexterity = 5}, ["Warp ring rolls out three times", "Ring freezes for a moment"], PRISM_PINK)
	_armor(out, "D_robe_ofprism", "Robe of Refracted Light", "Robe", "It casts a rainbow on everything but you.",
		{defense = 18, magic = 21, mp = 90, dexterity = 5}, PRISM)
	_relic(out, "D_bonus_crystal_ofprism", "Heart of the Labyrinth", "Crystal", "The maze grew around it, to keep it in.",
		{magic = 15, mp = 75, dexterity = 3}, PRISM_PINK)
	# --- Requiem (the Choirless Seraph, 9.0): silence, candles and stained glass.
	_weapon(out, "D_wand_ofrequiem", "Scepter of the Last Hymn", "Wand", "An organ pipe that remembers the final note.",
		{magic = 10, attack = 6}, ["Twin candle flames that weave and silence",
		"Charged: Requiem Chord, fourteen piercing flames all around"], Vector2i(160, 190))
	_weapon(out, "D_bow_ofrequiem", "Bow of Stained Glass", "Bow", "Saints in every pane. None of them are smiling.",
		{dexterity = 8, attack = 6}, ["Piercing panes of glass", "Charged: Rose Window, nine weaving panes"], Vector2i(200, 230))
	_armor(out, "D_robe_ofrequiem", "Vestment of the Choirless", "Robe", "Sewn for a choir that stopped singing.",
		{defense = 21, magic = 23, mp = 100, hp = 30}, HYMN)
	_spell(out, "D_spell_ofrequiem", "Hymn of Silence", "Hold it up and the world forgets how to make a sound.",
		{magic = 34, mp = 110}, ["Shield costs 20% less MP", "Warp ring silences for 3 seconds"], HYMN)
	_relic(out, "D_bonus_flame_ofrequiem", "The Unlit Candle", "Flame", "It burns dark. It burns anyway.",
		{attack = 12, magic = 8, hp = -25}, HYMN)
	# --- The Unmade (Oblivara, 10.0): the best there is, mended with gold.
	_weapon(out, "D_bow_oftheunmade", "Bow of the Mended Sky", "Bow", "The sky broke once. This is where they glued it back.",
		{dexterity = 10, attack = 8}, ["Two piercing gold-seamed arrows that weave", "Charged: Starfall, eleven falling stars"],
		Vector2i(230, 260))
	_weapon(out, "D_wand_oftheunmade", "Wand of the Golden Seam", "Wand", "Where it points, the world cracks and is mended better.",
		{magic = 14, attack = 6}, ["Two piercing stars", "Charged: Unmaking, a star that collapses into a ring of gold"],
		Vector2i(185, 215))
	_weapon(out, "D_trident_oftheunmade", "Trident of Broken Stars", "Trident", "Three stars fell. Someone caught them.",
		{attack = 10, defense = 6}, ["Piercing star prongs", "Charged: Constellation, eighteen stars in a rush"],
		Vector2i(270, 310))
	_armor(out, "D_cloak_oftheunmade", "Mantle of Kintsugi", "Cloak", "Broken more times than it can count. Stronger every time.",
		{defense = 26, speed = 7, attack = 7, dexterity = 7, hp = 40}, GOLD)
	_armor(out, "D_robe_oftheunmade", "Robe of the Unmade", "Robe", "Its hem has already become the night sky.",
		{defense = 22, magic = 26, mp = 120, hp = 40}, GOLD)
	_relic(out, "D_bonus_eye_oftheunmade", "Eye of Oblivara", "Eye", "Closed. Please let it stay closed.",
		{attack = 6, dexterity = 12, magic = 6}, GOLD)


## After Items._weapon_attacks and DivineSets.finish: each piece's own shots.
static func finish(out: Array[Item]) -> void:
	for item in out:
		if not _ours(item.id): continue
		_signature(item)
		if item.slot == "weapon":
			item.aura_color = item.projectile.color
		if item.shots == 2: item.projectile_shares = [0.5, 0.5]
		elif item.shots == 3: item.projectile_shares = [0.4, 0.7, 0.4]
		else: item.projectile_shares = [1.0]


static func _ours(id: String) -> bool:
	for set_name in SET_NAMES:
		if id in Items.DIVINE_SETS[set_name]: return true
	return false


static func _signature(item: Item) -> void:
	var p := item.projectile
	match item.id:
		"D_wand_ofmycelium":
			_look(p, "spore", SPORE, SPORE_TEAL, "spores", 13.0, 17.0, 1.35)
			item.shots = 2
			item.spread_deg = 14.0
			p.wave_amp = 0.25
			p.wave_freq = 5.0
			item.charge = {style = "nova", name = "Spore Bloom", count = 10, range = 0.7, wave = 0.3, pierce = false, mult = 2.4}
			_hits(item, [{id = "speed", amount = -2, duration = 1.5}], [{id = "speed", amount = -4, duration = 3.0}])
		"D_bow_ofsaltmourn":
			_look(p, "cannonball", Color("3a3c40"), BRONZE, "brine", 20.0, 22.0, 1.3)
			p.magic = false
			item.fire_rate = 0.55
			item.windup = 0.12
			item.charge = {style = "volley", name = "Full Broadside", count = 6, spread = 9.0, mult = 2.2}
			_hits(item, [{id = "armour_broken", duration = 0.8}], [{id = "armour_broken", duration = 3.0}])
		"D_trident_ofsaltmourn":
			_look(p, "trident", BRONZE, SEA, "brine", 23.0, 17.0, 1.05)
			p.pierce = true
			p.magic = false
			item.charge = {style = "stream", name = "Riptide", count = 12, interval = 0.05, mult = 2.4}
			_hits(item, [], [{id = "speed", amount = -3, duration = 2.0}])
		"D_wand_ofjade":
			_look(p, "feather", JADE, JADE_GOLD, "jade", 23.0, 21.0, 1.05)
			item.shots = 2
			item.spread_deg = 0.0
			p.wave_amp = 0.6
			p.wave_freq = 10.0
			item.charge = {style = "arcane", name = "Plumed Spiral", streams = 4, angle = 10.0, mult = 2.6}
			_hits(item, [{id = "speed", amount = -2, duration = 1.2}], [{id = "speed", amount = -4, duration = 3.0}])
		"D_wand_oftheafterlife":
			# The beam: tiny wisps, three times as many as any wand fires.
			_look(p, "wisp", SOUL, SOUL_PINK, "souls", 34.0, 17.0, 0.62)
			p.trail = false  # a beam of a hundred trails would be noise
			item.shots = 1
			item.fire_rate = 3.0
			p.wave_amp = 0.06
			p.wave_freq = 20.0
			item.charge = {style = "beam", name = "Requiem of Souls", count = 24, interval = 0.025, sweep = 7.0, mult = 3.0}
			_hits(item, [], [{id = "speed", amount = -3, duration = 2.5}])
		"D_trident_ofthebarrow":
			_look(p, "icespear", ICE, ICE_WHITE, "frost", 24.0, 18.0, 1.1)
			p.pierce = true
			p.magic = false
			item.charge = {style = "stream", name = "Wintermarch", count = 14, interval = 0.045, mult = 2.6}
			_hits(item, [{id = "speed", amount = -3, duration = 1.5}], [{id = "static", duration = 2.5}])
		"D_bow_ofprism":
			_look(p, "shard", PRISM, PRISM_PINK, "prism", 28.0, 25.0, 1.0)
			item.shots = 3
			item.spread_deg = 6.0
			item.charge = {style = "refract", name = "Spectrum", count = 10, mult = 2.4, shard_mult = 0.55}
			_hits(item, [{id = "static", duration = 0.25}], [{id = "static", duration = 1.5}])
		"D_wand_ofrequiem":
			_look(p, "candle", CANDLE, HYMN, "wax", 21.0, 21.0, 1.1)
			item.shots = 2
			item.spread_deg = 0.0
			p.wave_amp = 0.55
			p.wave_freq = 9.0
			item.charge = {style = "nova", name = "Requiem Chord", count = 14, range = 0.95, pierce = true, mult = 3.2}
			_hits(item, [{id = "quiet", duration = 0.4}], [{id = "quiet", duration = 3.0}])
		"D_bow_ofrequiem":
			_look(p, "pane", Color("e04a8a"), HYMN, "wax", 29.0, 26.0, 1.05)
			p.pierce = true
			item.charge = {style = "volley", name = "Rose Window", count = 9, spread = 5.0, wave = 0.4, mult = 2.6}
			_hits(item, [{id = "quiet", duration = 0.3}], [{id = "quiet", duration = 2.5}])
		"D_bow_oftheunmade":
			_look(p, "star", GOLD, NIGHT, "stardust", 31.0, 27.0, 1.1)
			item.shots = 2
			item.spread_deg = 0.0
			p.pierce = true
			p.wave_amp = 0.45
			p.wave_freq = 10.0
			item.charge = {style = "volley", name = "Starfall", count = 11, spread = 5.0, wave = 0.5, mult = 3.0}
			_hits(item, [{id = "armour_broken", duration = 1.0}],
				[{id = "armour_broken", duration = 4.0}, {id = "speed", amount = -4, duration = 3.0}])
		"D_wand_oftheunmade":
			_look(p, "star", GOLD, NIGHT, "stardust", 25.0, 22.0, 1.2)
			item.shots = 2
			item.spread_deg = 5.0
			p.pierce = true
			p.wave_amp = 0.0
			item.charge = {style = "singularity", name = "Unmaking", mult = 2.6, ring_damage = 420, ring_range = 8.0}
			_hits(item, [{id = "quiet", duration = 0.4}], [{id = "quiet", duration = 3.0}, {id = "armour_broken", duration = 3.0}])
		"D_trident_oftheunmade":
			_look(p, "star", GOLD, NIGHT, "stardust", 26.0, 19.0, 1.25)
			p.pierce = true
			item.charge = {style = "stream", name = "Constellation", count = 18, interval = 0.04, mult = 3.0}
			_hits(item, [{id = "armour_broken", duration = 1.2}], [{id = "armour_broken", duration = 4.0}])
		"D_spell_ofprism":
			item.shield_tint = Color("e8f0ff")
			item.shield_arcs = PRISM_PINK
			item.shield_rainbow = 1.0
			item.warp = 0.09
			item.ring = {damage = 300, range = 13.0, speed = 15.0, cost = 50, cooldown = 1.4, pulses = 3}
			item.secondary_effects.assign([{id = "static", duration = 1.5}])
		"D_spell_ofrequiem":
			item.effects = {shield_drain = 0.8}
			item.shield_tint = Color("1a0f24")
			item.shield_arcs = HYMN
			item.shield_rainbow = 0.0
			item.warp = 0.1
			item.ring = {damage = 360, range = 14.0, speed = 13.0, cost = 55, cooldown = 1.5, pulses = 2}
			item.secondary_effects.assign([{id = "quiet", duration = 3.0}])


static func _weapon(out: Array[Item], id: String, item_name: String, kind: String, lore: String,
		bonuses: Dictionary, abilities: Array, damage: Vector2i) -> void:
	var item := Items._divine(id, item_name, "weapon", kind, lore, bonuses, abilities, {})
	item.damage_min = damage.x
	item.damage_max = damage.y
	item.projectile = {style = "arrow" if kind == "Bow" else "bolt", color = Color.WHITE, speed = 26.0, range = 22.0}
	out.append(item)


static func _armor(out: Array[Item], id: String, item_name: String, kind: String, lore: String, bonuses: Dictionary, aura: Color) -> void:
	out.append(Items._divine(id, item_name, "armor", kind, lore, bonuses, [], {}, aura, 0.5))


static func _relic(out: Array[Item], id: String, item_name: String, kind: String, lore: String, bonuses: Dictionary, aura: Color) -> void:
	out.append(Items._divine(id, item_name, "bonus", kind, lore, bonuses, [], {}, aura, 0.35))


static func _spell(out: Array[Item], id: String, item_name: String, lore: String, bonuses: Dictionary, abilities: Array, aura: Color) -> void:
	out.append(Items._divine(id, item_name, "spell", "Spell", lore, bonuses, abilities, {}, aura, 0.7))


static func _look(p: Dictionary, style: String, color: Color, color2: Color, particles: String, speed: float,
		range_m: float, size: float) -> void:
	DivineSets._look(p, style, color, color2, particles, speed, range_m, size)


static func _hits(item: Item, primary: Array, secondary: Array) -> void:
	item.primary_effects.assign(primary)
	item.secondary_effects.assign(secondary)
