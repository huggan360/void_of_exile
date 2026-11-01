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
		about = "Quick and precise. Fires arrows that can be charged into a powerful shot.",
		base = {speed = 8, attack = 8, dexterity = 12, defense = 12, magic = 10}, hp = 100, mp = 100,
		growth = {speed = 1, attack = 2, dexterity = 1, defense = 1, magic = 2}},
	wizard = {name = "Wizard", weapon = "Wand", armor = "Robe", color = Color(0.55, 0.5, 1.0),
		about = "Hits hardest of all with crystal bolts, but can't take many blows.",
		base = {speed = 8, attack = 12, dexterity = 10, defense = 6, magic = 14}, hp = 90, mp = 130,
		growth = {speed = 1, attack = 2, dexterity = 1, defense = 1, magic = 2}},
	priest = {name = "Priest", weapon = "Wand", armor = "Robe", color = Color(1.0, 0.85, 0.45),
		about = "A sturdy caster with the deepest magic: the strongest warp shield.",
		base = {speed = 9, attack = 6, dexterity = 10, defense = 10, magic = 16}, hp = 110, mp = 140,
		growth = {speed = 1, attack = 1, dexterity = 1, defense = 1, magic = 3}},
	alchemist = {name = "Alchemist", weapon = "Wand", armor = "Cloak", color = Color(0.3, 0.85, 0.75),
		about = "Light on its feet and fast with a wand, mixing speed and magic.",
		base = {speed = 10, attack = 9, dexterity = 13, defense = 9, magic = 12}, hp = 100, mp = 120,
		growth = {speed = 1, attack = 1, dexterity = 2, defense = 1, magic = 2}},
	merrow = {name = "Merrow", weapon = "Trident", armor = "Cloak", color = Color(0.35, 0.8, 0.95),
		about = "A tough warrior of the sea. Slow, heavy trident throws and thick hide.",
		base = {speed = 9, attack = 10, dexterity = 8, defense = 15, magic = 8}, hp = 125, mp = 90,
		growth = {speed = 1, attack = 2, dexterity = 1, defense = 2, magic = 1}},
}


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
