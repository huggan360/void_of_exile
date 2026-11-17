class_name DivineBalance
## Preserve shot patterns and drawbacks while leaving room for set synergies.
const WEAPON_DAMAGE := 0.9
const OFFENSE_STATS := 0.85
const SURVIVAL_STATS := 0.9

static func apply(items: Array[Item]) -> void:
	for item: Item in items:
		if not item.is_divine(): continue
		item.bonuses = item.bonuses.duplicate()
		for stat: String in item.bonuses:
			var value := int(item.bonuses[stat])
			if value <= 0: continue
			var scale := OFFENSE_STATS if stat in ["attack", "magic", "dexterity", "speed"] else SURVIVAL_STATS
			item.bonuses[stat] = maxi(1, roundi(value * scale))
		if item.is_weapon():
			item.damage_min = maxi(1, roundi(item.damage_min * WEAPON_DAMAGE))
			item.damage_max = maxi(item.damage_min, roundi(item.damage_max * WEAPON_DAMAGE))
		ItemBalance.apply(item)
