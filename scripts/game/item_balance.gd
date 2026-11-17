class_name ItemBalance
## Applied once at each catalog factory, including direct graded constructors.
## Defense and existing penalties stay intact. Attack gets the largest cut.
static func apply(item: Item) -> Item:
	item.bonuses = item.bonuses.duplicate()
	for stat: String in item.bonuses:
		var value := int(item.bonuses[stat])
		if value <= 0: continue
		match stat:
			"attack": value = mini(7, maxi(1, roundi(value * 0.4)))
			"magic": value = mini(32, maxi(1, roundi(value * 0.8)))
			"dexterity": value = mini(12, maxi(1, roundi(value * 0.75)))
			"speed": value = mini(8, maxi(1, roundi(value * 0.8)))
			"hp", "mp": value = maxi(1, roundi(value * 0.9))
		item.bonuses[stat] = value
	return item
