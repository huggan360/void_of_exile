class_name DivineSetBonuses
extends RefCounted
## Derived from worn equipment only. Stages add together and never enter saves.
const PATH := "res://items/divine_set_bonuses.json"
static var _sets: Dictionary = {}
static var _membership: Dictionary = {}

static func definitions() -> Dictionary:
	if _sets.is_empty():
		_sets = JSON.parse_string(FileAccess.get_file_as_string(PATH)).sets
	return _sets

static func set_id(item: Item) -> String:
	if item == null or not item.is_divine(): return ""
	if _membership.is_empty():
		for name: String in Items.DIVINE_SETS:
			for id: String in Items.DIVINE_SETS[name]: _membership[id] = name
	return str(_membership.get(Items.canonical_id(item.id), ""))

static func definition(item: Item) -> Dictionary:
	return definitions().get(set_id(item), {})

static func equipped_counts(gear: Dictionary) -> Dictionary:
	var counts := {}
	var seen := {}
	for slot: String in PlayerStats.GEAR_SLOTS:
		var item: Item = gear.get(slot)
		var name := set_id(item)
		if name.is_empty() or item.slot != slot or seen.has(item.id): continue
		seen[item.id] = true
		counts[name] = int(counts.get(name, 0)) + 1
	return counts

static func bonuses_for(gear: Dictionary) -> Dictionary:
	var out := {}
	var counts := equipped_counts(gear)
	for name: String in counts:
		for stage: Dictionary in definitions()[name].stages:
			if int(counts[name]) < int(stage.pieces): continue
			for stat: String in stage.bonuses:
				out[stat] = int(out.get(stat, 0)) + int(stage.bonuses[stat])
	return out
