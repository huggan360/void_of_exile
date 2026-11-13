class_name DivineSets
## The Divine sets of the planet bosses, the farm and the glade (Venom, Eclipse,
## Blood, Stormeye, Madness, Cindrella, Goldslinger, Ash), extra pieces for
## Silver and Satan, each set's own stat leaning,
## and the shot patterns, charged attacks, particles and magic of their gear.
##
## Items.divine() calls build() with the other sets, then finish() after the
## shared weapon setup, so the looks set here are the ones that stay.
##
## Every set leans its own way: Iron and Silver hold the line, Storm and
## Venom are quick, Blood and Satan pay health for power, Madness gives a
## little of everything and takes some defence, Eclipse and the Void are magic,
## Stormeye freezes and is magic and speed at once.

const VENOM := Color("7fe02a")
const VENOM_DARK := Color("2f5a12")
const ECLIPSE := Color("ffb347")
const ECLIPSE_DARK := Color("4a1430")
const BLOOD := Color("d4202c")
const BLOOD_DARK := Color("3a0608")
const MADNESS := Color("ff4fd8")
const MADNESS_ALT := Color("6cff6a")
const ASH := Color("ff7a2e")
const ASH_DARK := Color("2c2a28")
const STORMEYE := Color("9ab0ff")
const STORMEYE_FROST := Color("a0e8ff")
const STORMEYE_INK := Color("8c5adc")
const STORMEYE_RED := Color("ff4a5a")
const GOLD := Color("f0b030")
const GOLD_DARK := Color("7a4a10")
const SATAN := Color("e42e2e")
const SATAN_DARK := Color("3a0a06")


static func build(out: Array[Item]) -> void:
	_venom(out)
	_eclipse(out)
	_blood(out)
	_stormeye(out)
	_madness(out)
	_cindrella(out)
	_ash(out)
	_extras(out)


## Runs after Items._weapon_attacks: new shot looks, patterns and charges,
## then every set's armour and relics get their own leaning.
static func finish(out: Array[Item]) -> void:
	for item in out:
		_signature(item)
		_restat(item)
		if item.slot == "weapon":
			item.aura_color = item.projectile.color
		if item.shots == 2: item.projectile_shares = [0.5, 0.5]
		elif item.shots == 3: item.projectile_shares = [0.4, 0.7, 0.4]
		else: item.projectile_shares = [1.0]


static func _weapon(out: Array[Item], id: String, item_name: String, kind: String, lore: String,
		bonuses: Dictionary, abilities: Array, damage: Vector2i, effects := {}) -> Item:
	var item := Items._divine(id, item_name, "weapon", kind, lore, bonuses, abilities, effects)
	item.damage_min = damage.x
	item.damage_max = damage.y
	item.projectile = {style = "arrow" if kind == "Bow" else "bolt", color = Color.WHITE, speed = 26.0, range = 24.0}
	out.append(item)
	return item


static func _spell(out: Array[Item], id: String, item_name: String, lore: String, bonuses: Dictionary,
		abilities: Array, effects: Dictionary, aura: Color) -> Item:
	var item := Items._divine(id, item_name, "spell", "Spell", lore, bonuses, abilities, effects, aura, 0.7)
	out.append(item)
	return item


## A set's relics (bonus items), named in RELICS and statted in STATS.
static func _relics(out: Array[Item], set_suffix: String, aura: Color) -> void:
	for id: String in RELICS:
		if id.ends_with("_" + set_suffix):
			var kind := id.trim_prefix("D_bonus_").get_slice("_", 0)
			out.append(Items._divine(id, RELICS[id][0], "bonus", kind.capitalize(), RELICS[id][1], {}, [], {}, aura, 0.35))


# --- Venom: the Brood Matriarch. Quick, precise, armour-eating. -------------------

static func _venom(out: Array[Item]) -> void:
	_weapon(out, "D_bow_ofvenom", "Stinger of the Brood", "Bow", "Strung with silk from the hive's deepest cell. It hums.",
		{dexterity = 10, speed = 3}, ["Two fangs that weave across each other", "Hits corrode armour",
		"Charged: Spitting Brood, a woven lattice of 8 venom darts"], Vector2i(118, 138))
	_weapon(out, "D_wand_ofvenom", "Wand of the Hive", "Wand", "Something inside it is still laying eggs.",
		{magic = 10, dexterity = 6}, ["A spread of three venom globs", "Charged: Hive Burst, 12 globs in every direction"],
		Vector2i(120, 145))
	_weapon(out, "D_trident_ofvenom", "Matriarch's Ovipositor", "Trident", "Three barbed prongs. They were never meant for fishing.",
		{attack = 8, dexterity = 5}, ["Piercing prongs that corrode armour", "Charged: Brood Torrent, 14 stinging darts"],
		Vector2i(158, 184))
	_spell(out, "D_spell_ofvenom", "Spell of Venom", "A seed of the hive. The shield it grows is alive.",
		{magic = 26, mp = 80, dexterity = 6}, ["Warp ring rolls out four times, slow and wide", "Ring corrodes armour and slows"],
		{}, VENOM)
	out[-1].shield_tint = Color("17330a")
	out[-1].shield_arcs = VENOM
	out[-1].shield_rainbow = 0.0
	out[-1].warp = 0.07
	out[-1].ring = {damage = 210, range = 15.0, speed = 9.0, cost = 45, cooldown = 1.2, pulses = 4}
	out.append(Items._divine("D_cloak_ofvenom", "Brood Carapace", "armor", "Cloak",
		"Shed by something that grew too big for it.", {}, ["Leaves a trail of venom"], {trail = "venom"}, VENOM, 0.5))
	out.append(Items._divine("D_robe_ofvenom", "Robe of the Hive Queen", "armor", "Robe",
		"Woven wax and silk, warm as a living hive.", {}, [], {}, VENOM, 0.5))
	_relics(out, "ofvenom", VENOM)


# --- Eclipse: Selenarch, the Moon-Eater. Magic and patience; the sun and moon at once. --

static func _eclipse(out: Array[Item]) -> void:
	_weapon(out, "D_bow_ofeclipse", "Bow of the Total Eclipse", "Bow", "Drawn once in a hundred years. Every draw is that once.",
		{dexterity = 6, magic = 6}, ["Slow, heavy crescents that pierce everything and silence",
		"Charged: Total Eclipse, the crescent collapses into a ring of dark"], Vector2i(205, 240))
	_weapon(out, "D_wand_ofeclipse", "Wand of Sun and Moon", "Wand", "The two never meet. Except here, briefly, at the tip.",
		{magic = 12, attack = 4}, ["A sun and a moon that circle each other", "Charged: Corona, 10 crescents in every direction"],
		Vector2i(132, 160))
	_weapon(out, "D_trident_ofeclipse", "Trident of the Umbra", "Trident", "Its shadow points the other way.",
		{attack = 6, magic = 6}, ["Three crescents that silence", "Charged: Twin Eclipse, two huge crescents spiralling together"],
		Vector2i(160, 190))
	_spell(out, "D_spell_ofeclipse", "Spell of the Eclipse", "A coin with the moon on both sides.",
		{magic = 30, mp = 90, speed = -3}, ["Shield costs 15% less MP", "Two wide rings that silence"],
		{shield_drain = 0.85}, ECLIPSE)
	out[-1].shield_tint = Color("2a0a20")
	out[-1].shield_arcs = ECLIPSE
	out[-1].shield_rainbow = 0.12
	out[-1].warp = 0.1
	out[-1].ring = {damage = 320, range = 13.0, speed = 11.0, cost = 60, cooldown = 1.8, pulses = 2}
	out.append(Items._divine("D_cloak_ofeclipse", "Mantle of the Corona", "armor", "Cloak",
		"Dark at the heart, burning at the hem.", {}, ["Leaves a trail of dawn and dusk"], {trail = "eclipse"}, ECLIPSE, 0.55))
	out.append(Items._divine("D_robe_ofeclipse", "Robe of the Moon-Eater", "armor", "Robe",
		"Selenarch wore it while it ate. The stains are moonlight.", {}, [], {}, ECLIPSE, 0.55))
	_relics(out, "ofeclipse", ECLIPSE)


# --- Blood: Queen Briarrose. Strong and hungry; health is the price. ---------------

static func _blood(out: Array[Item]) -> void:
	_weapon(out, "D_trident_ofblood", "Trident of the Blood Rose", "Trident", "Every prong is a thorn. Every thorn remembers.",
		{attack = 8}, ["Thorned prongs that break armour", "Each hit heals you 2 HP",
		"Charged: Crimson Barrage, 8 thorns in quick succession"], Vector2i(150, 176), {lifesteal = 2})
	_weapon(out, "D_wand_thewandofpower", "Wand of Power", "Wand", "It gives what you ask. It takes what you didn't think to keep.",
		{magic = 14, attack = 6, hp = -30}, ["One great crimson heart, slow and heavy", "Each hit heals you 2 HP",
		"Charged: Heart Rupture, bursts into a ring of blood"], Vector2i(240, 285), {lifesteal = 2})
	out.append(Items._divine("D_robe_robeofpower", "Robe of Power", "armor", "Robe",
		"Rose-red velvet. It fits better every time you bleed in it.", {}, ["Your hits heal you 1 HP"], {lifesteal = 1},
		BLOOD, 0.55))
	_relics(out, "ofblood", BLOOD)


# --- Stormeye: Vaelith, the Pale One. Frost, storm magic and the deep. --------------

static func _stormeye(out: Array[Item]) -> void:
	_weapon(out, "D_bow_ofthestormeye", "Bow of the Stormeye", "Bow", "Strung with a thread of lightning that never finished falling.",
		{dexterity = 8, speed = 4, magic = 4}, ["Two freezing lances that cross", "Hits freeze for a moment and slow",
		"Charged: Eye Lances, a lattice of 8 storm lances"], Vector2i(150, 175))
	_weapon(out, "D_wand_ofthestormeye", "Wand of the Pale Eye", "Wand", "It looks back at whatever you point it at.",
		{magic = 12, dexterity = 4}, ["One heavy magic sphere that pierces everything",
		"Charged: The Stormeye, the sphere collapses into a ring of storm"], Vector2i(195, 230))
	_weapon(out, "D_trident_ofthestormeye", "Trident of the Deep Arms", "Trident", "Pulled from one of the eight. It still flexes.",
		{attack = 8, defense = 4}, ["Three ink-dark prongs that pierce and slow",
		"Charged: Eight Arms, 8 prongs lashing out in every direction"], Vector2i(172, 202))
	_spell(out, "D_spell_ofthestormeye", "Spell of the Stormeye", "A storm that has learned to sit still. For now.",
		{magic = 28, mp = 90, speed = 3}, ["Warp ring rolls out three times", "Ring freezes and slows", "Shield costs 10% less MP"],
		{shield_drain = 0.9}, STORMEYE)
	out[-1].shield_tint = Color("101830")
	out[-1].shield_arcs = STORMEYE
	out[-1].shield_rainbow = 0.0
	out[-1].warp = 0.09
	out[-1].ring = {damage = 260, range = 14.0, speed = 10.0, cost = 55, cooldown = 1.5, pulses = 3}
	out.append(Items._divine("D_cloak_ofthestormeye", "Cloak of the Pale One", "armor", "Cloak",
		"White as the Eye, and just as hard to look at.", {}, ["Leaves a trail of storm sparks"], {trail = "stormeye"}, STORMEYE, 0.55))
	out.append(Items._divine("D_robe_ofthestormeye", "Robe of the Stormeye", "armor", "Robe",
		"The storm's quiet middle, woven into cloth.", {}, ["Magic recovers 20% faster"], {mp_regen = 1.2}, STORMEYE, 0.55))
	_relics(out, "ofthestormeye", STORMEYE)


# --- Extra pieces: Goldslinger (Aurum), Silver (the Gilded Vizier), Satan (Vharok). --

static func _extras(out: Array[Item]) -> void:
	_weapon(out, "D_bow_goldslinger", "Goldslinger's Repeater", "Bow", "Three strings, three coins, never a miss worth counting.",
		{dexterity = 10, attack = 4}, ["Three quick golden shots", "Charged: Gold Rush, a burst of 10 shots"], Vector2i(64, 78))
	out.append(Items._divine("D_robe_ofsilver", "Robe of the Silver Court", "armor", "Robe",
		"Quicksilver thread. It pools back into shape after every blow.", {}, ["Magic recovers 15% faster"],
		{mp_regen = 1.15}, Color("cadbea"), 0.45))
	_weapon(out, "D_bow_ofsatan", "Hellstring", "Bow", "Strung with something that screams when drawn.",
		{attack = 8, hp = -30}, ["Burning arrows", "Each hit heals you 1 HP",
		"Charged: Brimstone, a burning ring that sets the ground alight"], Vector2i(140, 165), {lifesteal = 1})


# --- Madness: the Veiled Herald. Everything, at a cost. --------------------------------

static func _madness(out: Array[Item]) -> void:
	_weapon(out, "D_trident_ofmadness", "Trident of Unlimited Madness", "Trident", "It laughs when it hits. You'll start laughing too.",
		{attack = 5, dexterity = 5, speed = 5, magic = 5, defense = -6},
		["Three prongs that never fly the same way twice", "Hits stun and slow",
		"Charged: Unlimited Madness, 16 prongs in every direction"], Vector2i(168, 198))
	_relics(out, "ofmadness", MADNESS)


# --- Cindrella: the Thornmaw Bloom. Light and quick. -----------------------------------

static func _cindrella(out: Array[Item]) -> void:
	_relics(out, "ofcindrella", Color("e45aa0"))


# --- Ash: the Mad Farmer. ---------------------------------------------------------------

static func _ash(out: Array[Item]) -> void:
	_weapon(out, "D_wand_thewandofash", "Wand of Ash", "Wand", "Carved from the last scarecrow. It remembers the fire.",
		{magic = 8, defense = 4}, ["Three short-range embers that set enemies alight",
		"Charged: Ashfall, a burning ring that leaves the ground on fire"], Vector2i(105, 128))


# --- Looks and patterns ---------------------------------------------------------------

## Projectile shape and particles, normal shot pattern, charged attack and hit
## effects for every Divine weapon that has its own (set by item id).
static func _signature(item: Item) -> void:
	var p := item.projectile
	match item.id:
		"D_bow_ofvenom":
			_look(p, "fang", VENOM, VENOM_DARK, "venom", 28.0, 25.0, 1.1)
			item.shots = 2
			item.spread_deg = 0.0
			p.wave_amp = 0.55
			p.wave_freq = 12.0
			item.charge = {style = "volley", name = "Spitting Brood", count = 8, spread = 6.0, wave = 0.6, mult = 2.4}
			_hits(item, [{id = "armour_broken", duration = 1.2}], [{id = "armour_broken", duration = 4.0}, {id = "speed", amount = -3, duration = 2.5}])
		"D_wand_ofvenom":
			_look(p, "fang", VENOM, VENOM_DARK, "venom", 22.0, 20.0, 0.95)
			item.shots = 3
			item.spread_deg = 10.0
			p.wave_amp = 0.3
			p.wave_freq = 9.0
			item.charge = {style = "nova", name = "Hive Burst", count = 12, range = 0.85, mult = 3.0}
			_hits(item, [{id = "armour_broken", duration = 1.0}], [{id = "armour_broken", duration = 3.5}])
		"D_trident_ofvenom":
			_look(p, "fang", VENOM, VENOM_DARK, "venom", 24.0, 17.0, 1.0)
			p.pierce = true
			item.charge = {style = "stream", name = "Brood Torrent", count = 14, interval = 0.04, mult = 2.6}
			_hits(item, [{id = "armour_broken", duration = 1.4}], [{id = "armour_broken", duration = 4.0}])
		"D_bow_ofeclipse":
			_look(p, "crescent", ECLIPSE, ECLIPSE_DARK, "eclipse", 20.0, 26.0, 1.5)
			p.pierce = true
			item.fire_rate = 0.7
			item.windup = 0.2
			item.charge = {style = "singularity", name = "Total Eclipse", mult = 2.2, ring_damage = 300, ring_range = 7.5}
			_hits(item, [{id = "quiet", duration = 0.6}], [{id = "quiet", duration = 3.5}])
		"D_wand_ofeclipse":
			_look(p, "crescent", ECLIPSE, ECLIPSE_DARK, "eclipse", 22.0, 21.0, 1.0)
			item.shots = 2
			item.spread_deg = 0.0
			p.wave_amp = 0.9
			p.wave_freq = 8.0
			item.charge = {style = "nova", name = "Corona", count = 10, range = 1.0, wave = 0.35, mult = 2.8}
			_hits(item, [{id = "quiet", duration = 0.5}], [{id = "quiet", duration = 3.0}])
		"D_trident_ofeclipse":
			_look(p, "crescent", ECLIPSE, ECLIPSE_DARK, "eclipse", 24.0, 18.0, 1.05)
			item.charge = {style = "helix", name = "Twin Eclipse", mult = 2.8}
			_hits(item, [{id = "quiet", duration = 0.5}], [{id = "quiet", duration = 3.0}])
		"D_trident_ofblood":
			_look(p, "thorn", BLOOD, BLOOD_DARK, "blood", 25.0, 17.0, 1.0)
			p.wave_amp = 0.15
			p.wave_freq = 14.0
			item.charge = {style = "burst", name = "Crimson Barrage", count = 8, interval = 0.06, mult = 2.5}
			_hits(item, [{id = "armour_broken", duration = 1.0}], [{id = "armour_broken", duration = 3.5}])
		"D_wand_thewandofpower":
			_look(p, "heart", BLOOD, BLOOD_DARK, "blood", 18.0, 21.0, 1.5)
			item.shots = 1
			item.fire_rate = 0.75
			p.wave_amp = 0.0
			p.pierce = true
			item.charge = {style = "singularity", name = "Heart Rupture", mult = 2.0, ring_damage = 240, ring_range = 6.5}
			_hits(item, [], [{id = "armour_broken", duration = 4.0}])
		"D_bow_Blood":
			_look(p, "thorn", BLOOD, BLOOD_DARK, "blood", 30.0, 24.0, 0.9)
		"D_trident_ofmadness":
			_look(p, "shard", MADNESS, MADNESS_ALT, "madness", 24.0, 18.0, 1.05)
			p.wave_amp = 0.7
			p.wave_freq = 16.0
			item.charge = {style = "nova", name = "Unlimited Madness", count = 16, range = 0.95, wave = 0.6, mult = 3.2}
			_hits(item, [{id = "static", duration = 0.4}, {id = "speed", amount = -2, duration = 1.0}],
				[{id = "static", duration = 2.5}, {id = "speed", amount = -4, duration = 3.0}])
		"D_bow_ofthestormeye":
			_look(p, "shard", STORMEYE_FROST, STORMEYE, "stormeye", 30.0, 25.0, 1.0)
			item.shots = 2
			item.spread_deg = 0.0
			p.wave_amp = 0.4
			p.wave_freq = 11.0
			item.charge = {style = "volley", name = "Eye Lances", count = 8, spread = 5.0, wave = 0.5, mult = 2.5}
			_hits(item, [{id = "static", duration = 0.3}, {id = "speed", amount = -2, duration = 1.0}],
				[{id = "static", duration = 1.5}, {id = "speed", amount = -4, duration = 3.0}])
		"D_wand_ofthestormeye":
			_look(p, "orb", STORMEYE, STORMEYE_FROST, "stormeye", 19.0, 22.0, 1.5)
			item.shots = 1
			item.fire_rate = 0.8
			p.wave_amp = 0.0
			p.pierce = true
			item.charge = {style = "singularity", name = "The Stormeye", mult = 2.2, ring_damage = 280, ring_range = 7.0}
			_hits(item, [{id = "speed", amount = -2, duration = 1.0}], [{id = "static", duration = 2.0}])
		"D_trident_ofthestormeye":
			_look(p, "shard", STORMEYE_INK, STORMEYE_RED, "stormeye", 24.0, 18.0, 1.05)
			p.pierce = true
			item.charge = {style = "nova", name = "Eight Arms", count = 8, range = 0.9, wave = 0.3, mult = 3.0}
			_hits(item, [{id = "speed", amount = -3, duration = 1.2}], [{id = "speed", amount = -5, duration = 3.0}])
		"D_bow_goldslinger":
			_look(p, "shard", GOLD, GOLD_DARK, "gold", 32.0, 24.0, 0.8)
			item.shots = 3
			item.spread_deg = 8.0
			p.magic = false
			item.charge = {style = "burst", name = "Gold Rush", count = 10, interval = 0.05, mult = 1.8}
		"D_bow_ofsatan":
			_look(p, "cinder", SATAN, SATAN_DARK, "embers", 28.0, 23.0, 1.1)
			p.magic = false
			item.charge = {style = "inferno", name = "Brimstone", mult = 2.6, ring_damage = 220, ring_range = 6.5}
			_hits(item, [{id = "burning", duration = 2.0}], [{id = "burning", duration = 5.0}])
		"D_bow_Cindrella":
			p.particles = "petals"
		"D_wand_thewandofash":
			_look(p, "cinder", ASH, ASH_DARK, "ash", 20.0, 13.0, 0.9)
			item.shots = 3
			item.spread_deg = 14.0
			p.wave_amp = 0.0
			item.charge = {style = "inferno", name = "Ashfall", mult = 2.6, ring_damage = 170, ring_range = 6.0}
			_hits(item, [{id = "burning", duration = 2.0}], [{id = "burning", duration = 4.0}])


static func _look(p: Dictionary, style: String, color: Color, color2: Color, particles: String, speed: float,
		range_m: float, size: float) -> void:
	p.style = style
	p.color = color
	p.color2 = color2
	p.particles = particles
	p.glow = true
	p.trail = true
	p.speed = speed
	p.range = range_m
	p.size = size
	p.magic = style != "fang" and style != "thorn"


static func _hits(item: Item, primary: Array, secondary: Array) -> void:
	item.primary_effects.assign(primary)
	item.secondary_effects.assign(secondary)


## Defence stays in each slot's usual band; the rest leans the set's own way.
## Some Divine pieces carry a drawback paid back in other stats.
const STATS := {
	# Robes
	D_robe_offrost = {defense = 16, magic = 12, dexterity = 8, mp = 40},
	D_robe_ofiron = {defense = 22, magic = 10, hp = 80, speed = -2},
	D_robe_ofstorm = {defense = 16, magic = 13, speed = 6, mp = 45},
	D_robe_oftheblue = {defense = 17, magic = 18, mp = 90},
	D_robe_ofthedragonsbreath = {defense = 16, magic = 14, attack = 8, hp = 30},
	D_robe_ofthegalaxy = {defense = 14, magic = 28, mp = 120, hp = -40},
	D_robe_ofeclipse = {defense = 17, magic = 16, attack = 6, dexterity = 6},
	D_robe_ofvenom = {defense = 16, magic = 12, dexterity = 10, speed = 3},
	D_robe_robeofpower = {defense = 15, magic = 24, attack = 6, hp = -30},
	D_robe_ofthestormeye = {defense = 17, magic = 16, speed = 5, mp = 50},
	D_robe_ofsilver = {defense = 20, magic = 12, mp = 50, speed = -2},
	# Cloaks
	D_cloak_blood = {defense = 12, attack = 8, hp = 20},
	D_cloak_burningman = {defense = 12, speed = 7, attack = 4},
	D_cloak_goldslinger = {defense = 12, dexterity = 10, attack = 6, speed = 3},
	D_cloak_ofiron = {defense = 22, attack = 10, hp = 70, speed = -3},
	D_cloak_ofstorm = {defense = 13, speed = 7, dexterity = 5},
	D_cloak_theblue = {defense = 12, magic = 8, mp = 60},
	D_cloak_thevoid = {defense = 14, speed = 5, magic = 6},
	D_cloak_unlimitedmadness = {defense = 8, attack = 6, dexterity = 6, speed = 6, magic = 6, hp = -30},
	D_cloak_ofeclipse = {defense = 14, attack = 6, dexterity = 6},
	D_cloak_ofvenom = {defense = 13, dexterity = 8, speed = 5},
	D_cloak_ofthestormeye = {defense = 14, speed = 6, dexterity = 6, magic = 4},
	# Crucifixes
	D_bonus_crucifix_ofsatan = {hp = -60, attack = 14, dexterity = 8, speed = 4},
	D_bonus_crucifix_offrost = {defense = 8, hp = 40, dexterity = 4},
	D_bonus_crucifix_ofstorm = {defense = 6, hp = 40, speed = 4},
	D_bonus_crucifix_ofblood = {hp = 40, attack = 8, defense = -4},
	D_bonus_crucifix_ofmadness = {attack = 4, dexterity = 4, speed = 4, magic = 4, hp = 20, defense = -8},
	D_bonus_crucifix_ofeclipse = {defense = 6, hp = 30, magic = 6, attack = 4},
	D_bonus_crucifix_ofvenom = {defense = 6, hp = 30, dexterity = 6},
	D_bonus_crucifix_ofthestormeye = {defense = 6, hp = 30, magic = 5, speed = 3},
	# Crystals
	D_bonus_crystal_ofstorm = {magic = 9, mp = 40, speed = 3},
	D_bonus_crystal_ofeclipse = {magic = 16, mp = 60, hp = -20},
	D_bonus_crystal_ofvenom = {magic = 10, mp = 40, dexterity = 4},
	D_bonus_crystal_ofthestormeye = {magic = 14, mp = 50, speed = 3, defense = -3},
	# Eyes
	D_bonus_eye_ofstorm = {dexterity = 8, speed = 3},
	D_bonus_eye_ofeclipse = {dexterity = 10, attack = 4},
	D_bonus_eye_ofvenom = {dexterity = 12, attack = 3, defense = -3},
	D_bonus_eye_ofthestormeye = {dexterity = 9, magic = 5, speed = 4, hp = -20},
	# Flames
	D_bonus_flame_ofstorm = {attack = 6, speed = 3},
	D_bonus_flame_ofeclipse = {attack = 10, magic = 6, hp = -20},
	D_bonus_flame_ofvenom = {attack = 8, dexterity = 4},
	D_bonus_flame_ofcindrella = {attack = 6, speed = 4, hp = 20},
	# Talismans
	D_bonus_talisman_ofstorm = {hp = 40, speed = 8},
	D_bonus_talisman_ofeclipse = {hp = 50, speed = 4, magic = 4},
	D_bonus_talisman_ofvenom = {hp = 40, speed = 6, dexterity = 3},
}

## Names, lore and effects of the new relics (stats are in STATS).
const RELICS := {
	D_bonus_crucifix_ofvenom = ["Crucifix of the Brood", "A cross of black chitin. Things move under it."],
	D_bonus_crystal_ofvenom = ["Venom Crystal", "Clear green, with a single egg frozen inside."],
	D_bonus_eye_ofvenom = ["Eye of the Swarm", "It sees in a thousand pieces and misses nothing."],
	D_bonus_flame_ofvenom = ["Venom Flame", "It burns without heat and eats without fire."],
	D_bonus_talisman_ofvenom = ["Hive Talisman", "A ring of wax that is always faintly warm."],
	D_bonus_crucifix_ofeclipse = ["Crucifix of the Eclipse", "Gold on one arm, night on the other."],
	D_bonus_crystal_ofeclipse = ["Eclipse Crystal", "It holds the moment the sun went out, and won't let go of it."],
	D_bonus_eye_ofeclipse = ["Eye of the Corona", "Look into it and you see the edge of the sun."],
	D_bonus_flame_ofeclipse = ["Flame of the Dark Sun", "A black fire with a golden rim. It burns its bearer a little."],
	D_bonus_talisman_ofeclipse = ["Eclipse Talisman", "Moonstone set in sunstone. They don't get along."],
	D_bonus_crucifix_ofblood = ["Crucifix of Blood", "Thorned rose-iron. It drinks a little from the hand that holds it."],
	D_bonus_crucifix_ofmadness = ["Crucifix of Madness", "It is the wrong shape, and it changes when you look away."],
	D_bonus_flame_ofcindrella = ["Flame of Cindrella", "A pink flame that dances to a song only it can hear."],
	D_bonus_crucifix_ofthestormeye = ["Crucifix of the Pale Eye", "Cold iron round a sliver of the Eye. It blinks."],
	D_bonus_crystal_ofthestormeye = ["Frozen Storm Crystal", "A thunderhead caught mid-roll. Your fingers go numb."],
	D_bonus_eye_ofthestormeye = ["The Stormeye", "Vaelith's own, or one of them. It still looks for you."],
}


static func _restat(item: Item) -> void:
	if STATS.has(item.id):
		item.bonuses = STATS[item.id].duplicate()
	if RELICS.has(item.id):
		item.item_name = RELICS[item.id][0]
		item.lore = RELICS[item.id][1]
	match item.id:
		"D_bonus_crucifix_ofsatan":
			item.effects = {lifesteal = 2}
			item.abilities = PackedStringArray(["Each hit heals you 2 HP"])
		"D_bonus_crucifix_ofblood":
			item.effects = {lifesteal = 1}
			item.abilities = PackedStringArray(["Your hits heal you 1 HP"])
		"D_bonus_crucifix_ofmadness":
			item.effects = {trail = "rainbow"}
		"D_robe_ofthegalaxy":
			item.abilities = PackedStringArray(["Shield costs 20% less MP"])
