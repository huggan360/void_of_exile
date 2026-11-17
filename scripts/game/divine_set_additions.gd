class_name DivineSetAdditions
## Completes the equipment slots of the smaller sets. Each remains tied to
## its original encounter, colors and tradeoffs; no automatic set bonuses.

static func build(out: Array[Item]) -> void:
	_spirit(out)
	_court(out)
	_fallenwood(out)
	_dark(out)
	_glade(out)
	_dungeons(out)


static func _spirit(out: Array[Item]) -> void:
	var color := Color("f01cde")
	_armor(out, "D_robe_ofspirit", "Vestment of the Unquiet", "Robe",
		"A breath held long enough to become cloth.", {defense = 12, magic = 16, speed = 5, mp = 50}, color)
	_relic(out, "D_bonus_talisman_ofspirit", "Spirit Knot", "Talisman",
		"Three fangs tied together with the wind between them.", {dexterity = 8, speed = 5, mp = 40}, color)
	_spell(out, "D_spell_ofspirit", "Spell of the Unquiet", "Its seal whispers in three voices.",
		{magic = 22, mp = 70, speed = 3}, {shield_drain = 0.9}, color,
		{damage = 190, range = 12.0, speed = 17.0, cost = 40, cooldown = 1.2, pulses = 2},
		[{id = "speed", amount = -4, duration = 2.5}])


static func _court(out: Array[Item]) -> void:
	_spell(out, "D_spell_ofsilver", "Seal of the Silver Court", "The Vizier's last promise, polished until it shines.",
		{magic = 22, defense = 6, mp = 75, speed = -2}, {shield_drain = 0.85}, Color("cadbea"),
		{damage = 240, range = 12.0, speed = 15.0, cost = 45, cooldown = 1.4, pulses = 2},
		[{id = "armour_broken", duration = 2.5}])
	_spell(out, "D_spell_ofdragonfire", "Spell of the First Flame", "A dragon's first breath, kept warm in a broken seed.",
		{magic = 25, attack = 6, mp = 75}, {shield_heal = 2.0}, Color("ff9a36"),
		{damage = 275, range = 11.0, speed = 12.0, cost = 50, cooldown = 1.5, pulses = 2},
		[{id = "burning", duration = 5.0}])
	_armor(out, "D_cloak_ofthedivine", "Mantle of the Dawn", "Cloak",
		"The sun's first warmth, folded around a mortal heart.", {defense = 16, attack = 6, hp = 60, magic = 6}, Color("ffda68"))
	_armor(out, "D_robe_ofthedivine", "Vestment of the Sun", "Robe",
		"Ivory thread that remembers every sunrise.", {defense = 18, magic = 20, mp = 80, hp = 35}, Color("fff0bd"))


static func _fallenwood(out: Array[Item]) -> void:
	var color := Color("91c36a")
	_armor(out, "D_cloak_offallenwood", "Rootkeeper's Mantle", "Cloak",
		"Roots at the hem, leaves at the shoulder. It is still growing.", {defense = 12, dexterity = 5, hp = 45, speed = 3}, color)
	_armor(out, "D_robe_offallenwood", "Mosslit Vestment", "Robe",
		"Stolen from the king and returned to the woods.", {defense = 14, magic = 13, mp = 55, hp = 30}, color)
	_relic(out, "D_bonus_talisman_offallenwood", "Heartwood Knot", "Talisman",
		"The last living knot of the first fallen tree.", {hp = 55, dexterity = 5, magic = 5}, color)
	_spell(out, "D_spell_offallenwood", "Spell of the Rootbound", "The forest closes its hand around you.",
		{magic = 20, mp = 65, defense = 4}, {shield_heal = 2.0}, color,
		{damage = 215, range = 11.0, speed = 10.0, cost = 40, cooldown = 1.5, pulses = 2},
		[{id = "speed", amount = -5, duration = 3.0}])


static func _dark(out: Array[Item]) -> void:
	var red := Color("e42e2e")
	_armor(out, "D_cloak_ofsatan", "Mantle of the Cinder Pact", "Cloak",
		"A bargain written on the inside. You cannot read it while wearing it.",
		{defense = 15, attack = 10, dexterity = 5, hp = -40}, red)
	_armor(out, "D_robe_ofsatan", "Vestment of Brimstone", "Robe",
		"Warm enough to forget what the bargain cost.", {defense = 17, magic = 23, mp = 80, hp = -45}, red)
	_spell(out, "D_spell_ofsatan", "Spell of the Cinder Pact", "It asks for a little of you every time you hold it.",
		{magic = 30, attack = 8, mp = 85, hp = -45}, {shield_drain = 1.1}, red,
		{damage = 340, range = 12.0, speed = 13.0, cost = 55, cooldown = 1.6, pulses = 2},
		[{id = "burning", duration = 5.0}, {id = "armour_broken", duration = 2.5}])
	var violet := Color("8545bb")
	_relic(out, "D_bonus_crystal_ofthevoid", "Shard of the Hollow Throne", "Crystal",
		"The throne was empty. This is a piece of what sat there.", {magic = 15, mp = 75, hp = -25}, violet)
	_spell(out, "D_spell_ofthevoid", "Spell of the Hollow Throne", "The space inside the seal is larger than the sky.",
		{magic = 31, mp = 100, hp = -35}, {shield_drain = 0.85}, violet,
		{damage = 310, range = 14.0, speed = 10.0, cost = 55, cooldown = 1.7, pulses = 2},
		[{id = "quiet", duration = 3.0}])
	_spell(out, "D_spell_ofblood", "Spell of the Blood Rose", "Its petals open only when something bleeds.",
		{magic = 28, attack = 8, mp = 75, hp = -35}, {shield_heal = 3.0}, Color("d4202c"),
		{damage = 280, range = 12.0, speed = 13.0, cost = 50, cooldown = 1.5, pulses = 2, heal = 15},
		[{id = "armour_broken", duration = 3.0}])
	_spell(out, "D_spell_ofmadness", "Spell of Unlimited Madness", "The writing changes whenever you almost understand it.",
		{magic = 26, attack = 5, dexterity = 5, speed = 4, defense = -5}, {}, Color("ff4fd8"),
		{damage = 210, range = 13.0, speed = 15.0, cost = 50, cooldown = 1.6, pulses = 3},
		[{id = "static", duration = 1.2}, {id = "speed", amount = -4, duration = 3.0}])
	out[-1].shield_arcs = Color("6cff6a")
	out[-1].shield_rainbow = 0.7


static func _glade(out: Array[Item]) -> void:
	var pink := Color("e45aa0")
	_armor(out, "D_cloak_ofcindrella", "Mantle of the Twin Bloom", "Cloak",
		"Two flowers share one stem. Neither will let go.", {defense = 11, dexterity = 7, speed = 5, hp = 25}, pink)
	_spell(out, "D_spell_ofcindrella", "Spell of the Twin Bloom", "It blooms once for you, and once for whoever stands too close.",
		{magic = 20, mp = 65, speed = 4}, {shield_heal = 1.5}, pink,
		{damage = 185, range = 11.0, speed = 14.0, cost = 35, cooldown = 1.2, pulses = 2},
		[{id = "speed", amount = -4, duration = 2.5}])
	var gold := Color("f0b030")
	_relic(out, "D_bonus_talisman_ofgoldslinger", "Aurum's Lucky Coin", "Talisman",
		"It always lands on its edge. The house has stopped accepting it.", {dexterity = 10, attack = 5, speed = 3}, gold)
	_spell(out, "D_spell_ofgoldslinger", "Spell of the Golden Draw", "A wager against the next thing that tries to hit you.",
		{magic = 22, dexterity = 6, mp = 70}, {shield_drain = 0.9}, gold,
		{damage = 220, range = 13.0, speed = 18.0, cost = 40, cooldown = 1.2, pulses = 2},
		[{id = "armour_broken", duration = 2.0}])


static func _dungeons(out: Array[Item]) -> void:
	_armor(out, "D_robe_ofmycelium", "Vestment of the Sporewomb", "Robe",
		"Soft threads that share the warmth you give them.", {defense = 10, magic = 9, hp = 40, mp = 40, speed = -2}, Color("73d6bc"))
	_spell(out, "D_spell_ofmycelium", "Spell of the Spore Bloom", "A whole quiet forest sleeps beneath the wax.",
		{magic = 16, hp = 35, mp = 55, speed = -2}, {shield_heal = 1.5}, Color("e9a942"),
		{damage = 130, range = 10.0, speed = 8.0, cost = 30, cooldown = 1.5, pulses = 2},
		[{id = "speed", amount = -4, duration = 3.0}])
	_relic(out, "D_bonus_crucifix_ofsaltmourn", "Saltmourn's Anchor", "Crucifix",
		"Small enough to carry. Heavy enough to remember the ship.", {attack = 7, defense = 5, hp = 45, speed = -2}, Color("60bcb9"))
	_spell(out, "D_spell_ofsaltmourn", "Spell of the Riptide", "A drowned command. The sea still obeys.",
		{magic = 20, defense = 5, mp = 60, dexterity = -3}, {}, Color("3fd8c8"),
		{damage = 285, range = 12.0, speed = 9.0, cost = 45, cooldown = 1.7, pulses = 1},
		[{id = "armour_broken", duration = 3.0}, {id = "speed", amount = -3, duration = 2.0}])
	_spell(out, "D_spell_ofjade", "Spell of the Feathered Coil", "A feather folded into the shape of a sleeping serpent.",
		{magic = 23, speed = 5, dexterity = 4, mp = 70}, {shield_drain = 0.9}, Color("4fd88a"),
		{damage = 205, range = 13.0, speed = 17.0, cost = 40, cooldown = 1.1, pulses = 2},
		[{id = "speed", amount = -4, duration = 3.0}])
	_spell(out, "D_spell_oftheafterlife", "Spell of the Last Crossing", "The way across is written in the light it leaves behind.",
		{magic = 19, dexterity = 8, speed = 5, mp = 70, attack = -5}, {shield_drain = 0.85}, Color("5ff0ff"),
		{damage = 125, range = 14.0, speed = 19.0, cost = 40, cooldown = 1.0, pulses = 3},
		[{id = "quiet", duration = 1.5}])
	_spell(out, "D_spell_ofthebarrow", "Spell of the Winter Oath", "The king swore that winter would outlive him. It did.",
		{magic = 24, defense = 8, hp = 50, mp = 80, speed = -3}, {shield_drain = 0.8}, Color("8ad8ff"),
		{damage = 310, range = 12.0, speed = 10.0, cost = 50, cooldown = 1.6, pulses = 2},
		[{id = "static", duration = 2.2}, {id = "speed", amount = -3, duration = 3.0}])
	_armor(out, "D_cloak_ofprism", "Mantle of Refracted Light", "Cloak",
		"Every fold catches a different morning.", {defense = 17, dexterity = 9, magic = 9, speed = 5}, Color("b4e8f4"))
	_armor(out, "D_cloak_ofrequiem", "Mantle of the Last Hymn", "Cloak",
		"The last note rests on your shoulders.", {defense = 20, attack = 8, dexterity = 8, hp = 40}, Color("c070ff"))
	_spell(out, "D_spell_oftheunmade", "Spell of the Golden Seam", "The world broke. This seal remembers how to mend it.",
		{magic = 36, mp = 120, hp = 50, defense = 5}, {shield_drain = 0.8}, Color("ffc24a"),
		{damage = 360, range = 15.0, speed = 14.0, cost = 60, cooldown = 1.5, pulses = 3},
		[{id = "quiet", duration = 2.5}, {id = "armour_broken", duration = 3.0}])


static func _armor(out: Array[Item], id: String, title: String, kind: String,
		lore: String, stats: Dictionary, color: Color) -> void:
	out.append(Items._divine(id, title, "armor", kind, lore, stats, [], {}, color, 0.5))


static func _relic(out: Array[Item], id: String, title: String, kind: String,
		lore: String, stats: Dictionary, color: Color) -> void:
	out.append(Items._divine(id, title, "bonus", kind, lore, stats, [], {}, color, 0.4))


static func _spell(out: Array[Item], id: String, title: String, lore: String,
		stats: Dictionary, effects: Dictionary, color: Color, ring: Dictionary, hits: Array) -> void:
	var abilities: Array = ["Warp ring rolls out %d time%s" % [int(ring.pulses), "s" if int(ring.pulses) != 1 else ""]]
	if effects.has("shield_drain"):
		var drain := float(effects.shield_drain)
		abilities.append("Shield costs %d%% %s MP" % [roundi(absf(1.0 - drain) * 100), "less" if drain < 1.0 else "more"])
	if effects.has("shield_heal"):
		abilities.append("Shield restores %s HP per second" % str(effects.shield_heal))
	var spell := Items._divine(id, title, "spell", "Spell", lore, stats, abilities, effects, color, 0.65)
	spell.shield_tint = color.darkened(0.6)
	spell.shield_arcs = color
	spell.shield_rainbow = 0.05
	spell.warp = 0.08
	spell.ring = ring
	spell.secondary_effects.assign(hits)
	out.append(spell)
