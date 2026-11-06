class_name PlayerClasses
## The playable classes: what each one looks like (characters/<id>/), which
## weapons and armor it can use, its starting stats and how they grow. Every
## class uses spells (the warp shield) and any bonus item.
##
##   Archer     Bow,     Cloak  fast, high dexterity
##   Wizard     Wand,    Robe   hard-hitting, fragile, lots of magic
##   Priest     Wand,    Robe   sturdy caster: most magic and shield
##   Alchemist  Wand,    Cloak  quick, nimble mixer of both
##   Merrow     Trident, Cloak  tough sea warrior, heavy slow hits

const ORDER := ["archer", "wizard", "priest", "alchemist", "merrow"]

const CLASSES := {
	archer = {name = "Archer", weapon = "Bow", armor = "Cloak", color = Color(0.45, 0.85, 0.4),
		about = "Keep your distance and line up arrows. Strong attack growth.",
		base = {speed = 0, attack = 0, dexterity = 0, defense = 0, magic = 0}, hp = 100, mp = 100,
		growth = {speed = 1, attack = 2, dexterity = 1, defense = 1, magic = 2},
		maximum = {speed = 60, attack = 42, dexterity = 68, defense = 86, magic = 58, hp = 850, mp = 450},
	},
	wizard = {name = "Wizard", weapon = "Wand", armor = "Robe", color = Color(0.55, 0.5, 1.0),
		about = "High attack and magic, low defense. Make every opening count.",
		base = {speed = 0, attack = 0, dexterity = 0, defense = 0, magic = 0}, hp = 90, mp = 130,
		growth = {speed = 1, attack = 2, dexterity = 1, defense = 1, magic = 2},
		maximum = {speed = 60, attack = 45, dexterity = 62, defense = 84, magic = 65, hp = 750, mp = 540},
	},
	priest = {name = "Priest", weapon = "Wand", armor = "Robe", color = Color(1.0, 0.85, 0.45),
		about = "Deep magic fuels a sturdy warp shield. Best magic growth.",
		base = {speed = 0, attack = 0, dexterity = 0, defense = 0, magic = 0}, hp = 110, mp = 140,
		growth = {speed = 1, attack = 1, dexterity = 1, defense = 1, magic = 3},
		maximum = {speed = 60, attack = 32, dexterity = 62, defense = 88, magic = 70, hp = 860, mp = 600},
	},
	alchemist = {name = "Alchemist", weapon = "Wand", armor = "Cloak", color = Color(0.3, 0.85, 0.75),
		about = "Quick feet and rapid wand fire. Strong dexterity growth.",
		base = {speed = 0, attack = 0, dexterity = 0, defense = 0, magic = 0}, hp = 100, mp = 120,
		growth = {speed = 1, attack = 1, dexterity = 2, defense = 1, magic = 2},
		maximum = {speed = 66, attack = 40, dexterity = 66, defense = 86, magic = 60, hp = 850, mp = 530},
	},
	merrow = {name = "Merrow", weapon = "Trident", armor = "Cloak", color = Color(0.35, 0.8, 0.95),
		about = "High health and defense. Trade rapid fire for heavy throws.",
		base = {speed = 0, attack = 0, dexterity = 0, defense = 0, magic = 0}, hp = 125, mp = 90,
		growth = {speed = 1, attack = 2, dexterity = 1, defense = 2, magic = 1},
		maximum = {speed = 60, attack = 45, dexterity = 60, defense = 116, magic = 55, hp = 975, mp = 440},
	},
}


## Class-specific average growth leaves about ten stat elixirs at level 50.
## Symmetric Gaussian level-up rolls produce bell-shaped final stat totals;
## combat stats vary more than HP/MP. Potion gains remain separate from rolls.
const ELIXIRS_TO_CAP := 10
const GROWTH_NORMAL_LIMIT := 2.0
const COMBAT_GROWTH_DEVIATION := 0.5
const VITAL_GROWTH_DEVIATION := 0.25

static func growth_roll(class_id: String, stat: String) -> int:
	var def := get_def(class_id)
	var start := int(def.hp) if stat == "hp" else int(def.mp) if stat == "mp" else int(def.base[stat])
	var potion_points := int(Items.STAT_ELIXIRS[stat][1])
	# The final potion can partly overflow the cap. Centre the integer potion
	# count, rather than aiming for ten full potions' worth of missing points.
	var target_gap := ELIXIRS_TO_CAP*potion_points-(potion_points-1)*0.5
	var goal := maxf(float(start),float(def.maximum[stat])-target_gap)
	var average := float(goal - start) / float(PlayerStats.MAX_LEVEL - 1)
	if average<=0.0: return 0
	var deviation := average * (VITAL_GROWTH_DEVIATION if stat in ["hp", "mp"] else COMBAT_GROWTH_DEVIATION)
	var normal := randfn(0.0,1.0)
	# Reject both tails symmetrically instead of clamping negative gains, which
	# would bias the mean upward. The lower bound is non-negative for all stats.
	while absf(normal)>GROWTH_NORMAL_LIMIT: normal = randfn(0.0,1.0)
	var rolled := average+normal*deviation
	# Stochastic rounding keeps fractional expected gains unbiased.
	return floori(rolled) + (1 if randf() < rolled - floorf(rolled) else 0)


static func get_def(class_id: String) -> Dictionary:
	return CLASSES.get(class_id, CLASSES.archer)


static func exists(class_id: String) -> bool:
	return CLASSES.has(class_id)


static func display_name(class_id: String) -> String:
	return get_def(class_id).name


## Whether a class may equip an item (consumables and bonus items: everyone).
static func allows(class_id: String, item: Item) -> bool:
	if item.is_consumable() or item.is_key() or item.is_story() or item.slot == "bonus" or item.slot == "spell":
		return true
	var def := get_def(class_id)
	return item.kind == (def.weapon if item.slot == "weapon" else def.armor)


## The grade `tier` weapon or armor this class uses.
static func gear_item(class_id: String, slot: String, tier: int) -> Item:
	var def := get_def(class_id)
	tier = clampi(tier, 1, 8)
	match slot:
		"weapon":
			match def.weapon:
				"Wand": return Items.wand(tier)
				"Trident": return Items.trident(tier)
				_: return Items.bow(tier)
		"armor":
			return Items.robe(tier) if def.armor == "Robe" else Items.cloak(tier)
		"spell":
			return Items.spell(clampi(tier, 1, 5))
		"bonus":
			return Items.bonus(tier, "talisman")
	return null


## Starting gear: grade 1 weapon, armor and spell (or better, see tiers).
static func starting_gear(class_id: String, tiers := {}) -> Dictionary:
	var gear := {weapon = null, armor = null, spell = null, bonus = null}
	for slot in ["weapon", "armor", "spell"]:
		gear[slot] = gear_item(class_id, slot, int(tiers.get(slot, 1)))
	if tiers.has("bonus"):
		gear.bonus = gear_item(class_id, "bonus", int(tiers.bonus))
	return gear


## The class's figure: the Archer's own model, or one built from the art in
## characters/<id>/ (ClassModel). Both have animate(), play_shot() and hold.
static func make_model(class_id: String) -> Node3D:
	if class_id == "archer" or not exists(class_id):
		return ArcherModel.new()
	return ClassModel.new(class_id)
