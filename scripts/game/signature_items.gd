class_name SignatureItems
## Standalone Legendary equipment and collectible Artifacts. One catalog
## drives gameplay, boss assignments, icon palettes and worn appearances.
const PATH := "res://items/signatures.json"
static var _definitions: Array[Dictionary] = []

static func definitions() -> Array[Dictionary]:
	if _definitions.is_empty():
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		for row: Dictionary in data.items: _definitions.append(row)
	return _definitions

static func sources(rarity: String) -> Dictionary:
	var out := {}
	for row: Dictionary in definitions():
		if row.rarity != rarity: continue
		if not out.has(row.boss): out[row.boss] = []
		out[row.boss].append(row.id)
	return out

static func drop_chance(id: String) -> float:
	for row: Dictionary in definitions():
		if row.id == id: return float(row.chance)
	return 0.0

static func build(rarity: String) -> Array[Item]:
	var out: Array[Item] = []
	for row: Dictionary in definitions():
		if row.rarity != rarity: continue
		var color := Color(str(row.colors[0]))
		var accent := Color(str(row.colors[1]))
		var abilities: Array = []
		if row.slot == "weapon":
			abilities.append("Charged: " + str(row.charge.name))
			if rarity == "L": abilities.append("Cut crystal projectiles with a luminous trail")
			elif row.projectile.get("pattern", "") != "": abilities.append("Fires a display around and above you")
			elif row.projectile.get("burst", "") != "": abilities.append("A huge, slow firework that scatters sparks on impact")
		if row.effects.has("showoff"): abilities.append("A luminous garment with a crown of drifting lights")
		var item := Items._divine(str(row.id), str(row.name), str(row.slot), str(row.kind),
			str(row.lore), row.bonuses.duplicate(true), abilities, row.effects.duplicate(true), color,
			2.4 if row.effects.has("showoff") else 0.55)
		item.tier = Item.ARTIFACT if rarity == "A" else Item.LEGENDARY
		if row.slot == "weapon":
			item.damage_min = int(row.damage[0])
			item.damage_max = int(row.damage[1])
			item.fire_rate = float(row.rate)
			item.shots = int(row.shots)
			item.projectile_shares.assign(row.shares)
			item.spread_deg = float(row.spread)
			item.projectile = row.projectile.duplicate(true)
			item.projectile.merge({color = color, color2 = accent, glow = true, trail = true, magic = true}, true)
			item.charge = row.charge.duplicate(true)
			item.primary_effects.assign(row.primary_effects)
			item.secondary_effects.assign(row.secondary_effects)
		out.append(ItemBalance.apply(item))
	return out
