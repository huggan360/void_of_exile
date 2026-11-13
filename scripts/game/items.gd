class_name Items
## Every item in the game. Graded items (G1-G8) follow steady curves; Divine
## items (D) are hand-made with their own abilities. Projectile, shield and
## aura colors are taken from each item's icon.

## Bow damage per grade (G1 ... G8).
const BOW_DAMAGE := [[25, 35], [40, 52], [58, 72], [78, 94], [100, 118], [124, 144], [148, 170], [175, 200]]
const BOW_NAMES := ["Whisperwood Bow", "Bow of the Mossbound", "Thornstring Bow", "Bow of the Ember Dusk",
		"Bow of the Violet Hour", "Heartseeker", "Bow of the Gilded Path", "Bow of the Golden Dawn"]
const BOW_COLORS := [  # [main, accent] from the icons
	[Color("#8a5a3c"), Color("#4b2b26")], [Color("#4b692f"), Color("#243217")],
	[Color("#6f9b45"), Color("#2f4a1d")], [Color("#df7026"), Color("#b3500e")],
	[Color("#7a2ee6"), Color("#361762")], [Color("#e0409f"), Color("#651a4d")],
	[Color("#eea312"), Color("#d08b05")], [Color("#ffc962"), Color("#eea312")],
]
const BOW_LORE := [
	"Strung with a single hair from something that has never slept.",
	"Moss grows along its limbs. It doesn't seem to mind.",
	"Every arrow it looses leaves a thorn behind in the world.",
	"Warm to the touch, like a coal that remembers being a tree.",
	"Shoots best in the hour between dusk and the first star.",
	"It always knows where the heart is. Yours included.",
	"Gilded by a king who never learned to shoot.",
	"Made from the first light of a morning that hasn't happened yet.",
]

const CLOAK_NAMES := ["Mossbound Mantle", "Wanderer's Cloak", "Cloak of the Deep Pines", "Emberline Cloak",
		"Cloak of the Violet Veil", "Cloak of Starless Night", "Cloak of the Gilded Hunt", "Cloak of the Radiant Crown"]
const CLOAK_COLORS := [Color("#3e7a3a"), Color("#6b4a32"), Color("#2c5a50"), Color("#c0502a"),
		Color("#6a3ad0"), Color("#3a3f8a"), Color("#e8a830"), Color("#fff2c0")]
## Extra stats per cloak grade (on top of defence).
const CLOAK_EXTRAS := [{}, {}, {speed = 2}, {speed = 3, dexterity = 3}, {speed = 4, dexterity = 4},
		{speed = 5, dexterity = 5, attack = 2}, {speed = 6, dexterity = 6, attack = 3},
		{speed = 7, dexterity = 7, attack = 4, magic = 4}]
const CLOAK_LORE := [
	"Woven in a forest that is no longer on any map.",
	"It has walked further than you have. It remembers the way.",
	"Smells of pine resin and snow that never melts.",
	"The hem still smoulders. It never quite catches.",
	"Pull the hood up and the world goes quiet and purple.",
	"Stitched from a night sky with all the stars picked out.",
	"Worn by hunters who never missed, and never told.",
	"Too bright to look at directly. Too warm to take off.",
]

const SPELL_NAMES := ["Hollow Seal", "Seal of Dust", "Parchment Moon", "Lens of the Folded Sky", "Jade Gyre"]
## [shield tint, arc color] per spell grade.
const SPELL_COLORS := [
	[Color("#c49a52"), Color("#ffd98a")], [Color("#a8946a"), Color("#f0dfae")],
	[Color("#e8dcb8"), Color("#fffbe8")], [Color("#a2bcff"), Color("#8c71ff")],
	[Color("#a2ffa8"), Color("#2bc4b0")],
]
const SPELL_LORE := [
	"A wax seal with nothing inside. Somehow that's the point.",
	"Break it and the dust remembers what it used to be.",
	"Hold it to the light and you can read the moon.",
	"The sky folds like paper around whoever carries it.",
	"Spins on its own when nobody is watching.",
]


## Every item, graded first, then Divine, then consumables.
const BLUE_DIVINE_IDS := ["D_cloak_theblue", "D_spell_oftheblue", "D_robe_oftheblue",
        "D_trident_oftheblue", "D_bonus_crucifix_oftheblue"]
## Divine sets that are live, by set folder. Bosses set their per-item chances.
## Legacy source names: "crucefix of the blue" -> D_bonus_crucifix_oftheblue,
## "croucefix of satan" -> D_bonus_crucifix_ofsatan, "flame of the divine" ->
## D_bonus_flame_ofthedivine (see tools/import_textures.py).
const DIVINE_SETS := {
	Spirit = ["D_wand_thewandofthespitit"],
	Iron = ["D_bow_ofiron", "D_wand_ofiron", "D_trident_ofiron", "D_cloak_ofiron", "D_robe_ofiron", "D_spell_ofiron", "D_bonus_crucifix_ofiron"],
	Storm = ["D_bonus_crucifix_ofstorm", "D_bonus_crystal_ofstorm", "D_bonus_eye_ofstorm", "D_bonus_flame_ofstorm", "D_bonus_talisman_ofstorm", "D_bow_ofstorm", "D_cloak_ofstorm", "D_robe_ofstorm", "D_spell_ofstorm", "D_trident_ofstorm", "D_wand_ofstorm"],
	Silver = ["D_cloak_silvershield", "D_wand_thewandofsteel", "D_bonus_crucifix_ofthalao"],
	Dragon_Fire = ["D_bow_dragon", "D_cloak_burningman", "D_robe_ofthedragonsbreath", "D_bonus_flame_ofthebroken"],
	Fallenwood = ["D_bow_Fallenwoods", "D_trident_ofthefallenwood", "D_wand_thewandofthefallenwood"],
	The_Blue = BLUE_DIVINE_IDS,
	Frost = ["D_bow_offrost", "D_wand_offrost", "D_trident_offrost", "D_spell_offrost", "D_cloak_offrost",
		"D_robe_offrost", "D_bonus_crucifix_offrost", "D_bonus_flame_offrost", "D_bonus_eye_offrost",
		"D_bonus_crystal_offrost", "D_bonus_talisman_offrost"],
	Satan = ["D_trident_ofsatan", "D_wand_thewandofsatan", "D_bonus_crucifix_ofsatan"],
	Holy_Divine = ["D_spell_ofthedivine", "D_trident_ofthedivine", "D_wand_thewandofthedivine",
		"D_bonus_flame_ofthedivine"],
	Void = ["D_bow_Darkmatter", "D_cloak_thevoid", "D_robe_ofthegalaxy", "D_trident_ofthevoid",
		"D_wand_thewandofdarkness"],
	Venom = ["D_bow_ofvenom", "D_wand_ofvenom", "D_trident_ofvenom", "D_spell_ofvenom", "D_cloak_ofvenom",
		"D_robe_ofvenom", "D_bonus_crucifix_ofvenom", "D_bonus_flame_ofvenom", "D_bonus_eye_ofvenom",
		"D_bonus_crystal_ofvenom", "D_bonus_talisman_ofvenom"],
	Eclipse = ["D_bow_ofeclipse", "D_wand_ofeclipse", "D_trident_ofeclipse", "D_spell_ofeclipse", "D_cloak_ofeclipse",
		"D_robe_ofeclipse", "D_bonus_crucifix_ofeclipse", "D_bonus_flame_ofeclipse", "D_bonus_eye_ofeclipse",
		"D_bonus_crystal_ofeclipse", "D_bonus_talisman_ofeclipse"],
	Blood = ["D_bow_Blood", "D_trident_ofblood", "D_wand_thewandofpower", "D_cloak_blood", "D_robe_robeofpower",
		"D_bonus_crucifix_ofblood"],
	Madness = ["D_trident_ofmadness", "D_cloak_unlimitedmadness", "D_bonus_crucifix_ofmadness"],
	Cindrella = ["D_bow_Cindrella", "D_bonus_flame_ofcindrella"],
	Goldslinger = ["D_cloak_goldslinger"],
	Ash = ["D_wand_thewandofash"],
}
## Encounters assigned a Divine set; unassigned enemies cannot drop Divine items.
const BOSS_DIVINE_SET := {
	spirit_purple = "Spirit",
	hollow_king = "Iron",
	abyssal_siren = "Storm", drowned_cantor = "Storm",
	gilded_vizier = "Silver", magma_warden = "Dragon_Fire", pyre_ent = "Dragon_Fire",
	goblin_king = "Fallenwood", blue_dragon = "The_Blue", rimeheart_prism = "Frost", vharok = "Satan",
	scarab_regent = "Holy_Divine", hollow_crown = "Void",
	# Sets matched to each boss's look; stronger bosses carry stronger sets.
	thornmaw_bloom = "Cindrella", mad_farmer = "Ash", queen_briarrose = "Blood", amber_colossus = "Goldslinger",
	selenarch = "Eclipse", brood_matriarch = "Venom", stormeye_tyrant = "Madness", veil_herald = "Madness",
	void_empress = "Void",
}
## Sets two bosses share. The first boss favours even items, the second odd
## ones: a boss drops its favourites 1% more often.
const SHARED_SETS := {
	Storm = ["abyssal_siren", "drowned_cantor"], Dragon_Fire = ["magma_warden", "pyre_ent"],
	Void = ["hollow_crown", "void_empress"], Madness = ["stormeye_tyrant", "veil_herald"],
}


## Explicit cross-set relics, kept separate from each boss's full primary set.
const BOSS_DIVINE_EXTRAS := {
	abyssal_siren = ["D_spell_oftheblue", "D_trident_oftheblue", "D_bonus_crucifix_oftheblue"],
	drowned_cantor = ["D_spell_oftheblue", "D_trident_oftheblue", "D_bonus_crucifix_oftheblue"],
}


## The divine item ids a boss may drop ([] for everyone else).
static func divine_ids_for(enemy_id: String) -> Array:
	return DIVINE_SETS.get(BOSS_DIVINE_SET.get(enemy_id, ""), [])


## Each eligible player's own chance at one Divine item from this boss. The
## piece decides it: weapons and spells 5%, armour 6%, bonus relics 7%, and an
## item with a drawback 1% more; a shared set's favourites 1% more again.
## Relics from another set (BOSS_DIVINE_EXTRAS) are rarer extras at 60%.
static func divine_chance(item: Item, enemy_id: String) -> float:
	var chance := 0.05 if item.slot in ["weapon", "spell"] else 0.06 if item.slot == "armor" else 0.07
	for value in item.bonuses.values():
		if value < 0:
			chance += 0.01
			break
	var set_name: String = BOSS_DIVINE_SET.get(enemy_id, "")
	var ids: Array = DIVINE_SETS.get(set_name, [])
	if not item.id in ids:
		return chance * 0.6
	if SHARED_SETS.has(set_name):
		var bosses: Array = SHARED_SETS[set_name]
		if bosses[ids.find(item.id) % bosses.size()] == enemy_id:
			chance += 0.01
	return chance
const BONUS_KINDS := ["crucifix", "flame", "eye", "crystal", "talisman"]
static var _catalog := {}

static func all() -> Array[Item]:
	var out: Array[Item] = []
	for t in range(1, 9):
		out.append(bow(t))
	for t in range(1, 9):
		out.append(cloak(t))
	for t in range(1, 6):
		out.append(spell(t))
	for t in range(1, 9):
		out.append(wand(t))
		out.append(trident(t))
		out.append(robe(t))
		for family in BONUS_KINDS:
			out.append(bonus(t, family))
	out.append_array(divine())
	out.append(elixir("elixir_hp"))
	out.append(elixir("elixir_mp"))
	for stat in STAT_ELIXIRS:
		out.append(stat_elixir(stat))
	out.append(backpack())
	for id in GATE_KEYS:
		out.append(gate_key(id))
	for id in STORY_ITEMS:
		out.append(story_item(id))
	return out


## A fresh item by id (e.g. "G3_bow", "elixir_hp"), or null.
static func make(id: String) -> Item:
	if _catalog.is_empty():
		for item in all():
			_catalog[item.id] = item
	var source: Item = _catalog.get(id)
	return source.duplicate(true) as Item if source != null else null


## Whether an item with this id exists.
static func exists(id: String) -> bool:
	if _catalog.is_empty():
		make("G1_bow")
	return _catalog.has(id)


## Spells only go up to G5, so they have their own scale: a pool's spell is
## the one that matches its gear in strength (G5 spells only from G8 pools).
const SPELL_TIER := [1, 1, 2, 3, 3, 4, 4, 5]


## A random graded item matching `pool` ({tier, slots}), or null.
static func from_pool(pool: Dictionary, rng: RandomNumberGenerator) -> Item:
	var slots: Array = pool.get("slots", ["weapon", "armor", "spell", "bonus"])
	if _catalog.is_empty():
		make("G1_bow")
	var spell_tier: int = SPELL_TIER[clampi(int(pool.tier), 1, 8) - 1]
	var matches: Array = _catalog.values().filter(func(i: Item) -> bool:
		if i.is_consumable() or i.is_divine() or not i.slot in slots: return false
		return i.tier == (spell_tier if i.slot == "spell" else int(pool.tier)))
	return null if matches.is_empty() else (matches[rng.randi() % matches.size()] as Item).duplicate(true) as Item


## Stat elixirs: one for every stat. Drinking one raises that stat for good
## on this character (+2 speed/dexterity, +4 attack/defence/magic, +20 health/magic points). Gods and
## bosses drop them, in blue bags. [name, amount, liquid color]
const STAT_ELIXIRS := {
	attack = ["Attack", 1, Color("#e04848")], defense = ["Defence", 4, Color("#3c3c4a")],
	speed = ["Speed", 2, Color("#48c8e0")], dexterity = ["Dexterity", 2, Color("#e08a30")],
	magic = ["Magic", 4, Color("#a050e8")], hp = ["Health", 20, Color("#ff5070")],
	mp = ["Magic Points", 20, Color("#ffd040")],
}


static func stat_elixir(stat: String) -> Item:
	var info: Array = STAT_ELIXIRS[stat]
	var i := Item.new()
	i.id = "elixir_of_" + stat
	i.item_name = "Elixir of %s" % info[0]
	i.slot = "consumable"
	i.kind = "Stat Elixir"
	i.stack_max = 8
	i.consumable = {stat = stat, amount = info[1]}
	i.drop_bag = "blue"
	i.abilities = PackedStringArray(["+%d %s for good, on this character" % [info[1], info[0]],
			"Double-click to drink"])
	i.lore = "Bottled from the blood of a god. It remembers being divine."
	return i


## Stronghold keys: each opens the sealed gates of one fortress, once
## (StrongholdGates.KEYS). [name, fortress, lore]
const GATE_KEYS := {
	key_azure_crucible = ["Azure Crucible Key", "The Azure Crucible",
		"Forged from a scale the Blue Dragon shed in its sleep. It is still cold."],
	key_crown_of_the_rime = ["Rime Crown Key", "Crown of the Rime",
		"A splinter of the Prism's own facets. Your breath fogs on it, even in summer."],
	key_cinder_bastion = ["Cinder Bastion Key", "The Cinder Bastion",
		"Black iron that never cooled. Its teeth glow when Vharok stirs."],
	key_court_of_the_sun = ["Sun Court Key", "Court of the Sun",
		"A gilded scarab folds its wings around the bow. It warms toward noon."],
	key_hollow_throne = ["Hollow Throne Key", "The Hollow Throne",
		"Lighter than it should be. Holding it, you hear a crown being set down."],
	# The Astral Reach's planet strongholds (SpaceLayout.FORTS).
	key_rose_bastion = ["Rose Bastion Key", "The Rose Bastion",
		"A stem of pink crystal, thorns and all. It smells of roses when the Queen is near."],
	key_amber_ziggurat = ["Amber Ziggurat Key", "The Amber Ziggurat",
		"Honey-amber, warm as a hand. A tiny bee sleeps in the bow."],
	key_shattered_observatory = ["Observatory Key", "The Shattered Observatory",
		"A brass star-key with a moon in its bow. It points at Hollowmoon's dead sky."],
	key_rotting_hive = ["Hive Key", "The Rotting Hive",
		"Grown, not forged: violet chitin that twitches now and then."],
	key_stormeye_citadel = ["Stormeye Key", "The Stormeye Citadel",
		"Obsidian with a blue spark trapped inside. Your hair stands up holding it."],
}


static func gate_key(id: String) -> Item:
	var info: Array = GATE_KEYS[id]
	var i := Item.new()
	i.id = id
	i.item_name = info[0]
	i.slot = "key"
	i.kind = "Stronghold Key"
	i.opens = info[1]
	i.abilities = PackedStringArray(["Opens the sealed gates of %s" % info[1],
			"Walk up to its gate to use it", "Consumed when used"])
	i.lore = info[2]
	return i


## Campaign story items. [name, kind, lore, readable text ("" = not readable)]
const STORY_ITEMS := {
	story_nav_core = ["Salvaged Navigation Core", "Story item - starship component",
		"An immaculate Vesperis navigation unit, bought for 500 Dots. Starwright Fen needs its guided stars to steer his rebuild.", ""],
	story_amber_regulator = ["Amber Power Regulator", "Story item - starship component",
		"A heavy golden pressure ring once guarded by Aurum, the Amber Colossus. It holds steady even when it hums.", ""],
	story_tidal_stabilizer = ["Tidal Stabilizer", "Story item - starship component",
		"A brass device found in Tidewell's shallows. Tiny waves turn beneath its glass.", ""],
	story_wizard_starball = ["Aldren's Stolen Starball", "Story item - magical sphere",
		"A little blue star turns inside the glass. The farmer swore it could levitate his turnips; Wizard Aldren needs it back.", ""],
	story_starcoil = ["Starcoil", "Rocket part", "A copper winding that folds a spark of starlight into lift. Bring it to Orin at Starfall Launchworks.", ""],
	story_spellsteel_nozzle = ["Spellsteel Nozzle", "Rocket part", "A rune-lined engine throat, cast to survive impossible heat. Orin needs this for his magic ship.", ""],
	story_aether_heart = ["Aether Heart", "Rocket part", "A small prism holding a calm blue star. The last piece of Orin's rocket.", ""],
	story_throne_key = ["Throne Key", "Story item", "Cold iron, entrusted to the last sworn champion. The teeth fit a crown that no living king should wear.", ""],
	story_moon_lily = ["Moon-Lily", "Story item", "Gerald's last living moon-lily. It glows faintly in the dark.", ""],
	story_clue = ["Torn Map", "Story item - map pieces", "Pieces of an old map, marked with a crown.", "map"],
	story_necklace = ["Maribel's Necklace", "Story item", "Old silver and a cloudy stone, engraved with a tiny crown.", ""],
	story_heart_of_stone = ["Heart of Stone", "Story item", "The Hollow King's heart. It is still warm, and it still beats, slowly.", ""],
	story_tide_pearl = ["Siren's Pearl", "Story item", "Hold it to your ear: a whole choir, singing under the sea.", ""],
	story_candle = ["Wick's Candle", "Story item - readable", "A stub of black wax that never lights.",
		"Scratched into the wax, in a shaking hand:|[i]Don't turn around. Don't answer. Don't read the map in the dark.[/i]"],
	story_sun_seal = ["Sun Seal", "Story item", "Gold, stamped with the Scarab Regent's sign. It hums in the heat.", ""],
	story_pilgrim_page = ["Pilgrim's Page", "Story item - readable", "White vellum, left under Rosamund's wishing stones. Warm, as if someone had just been holding it.",
		"[i]Close your eyes, little king, and I will keep mine open for you.|What you cannot bear to do, I will whisper until you can.|All glory to the Eye that never closes.[/i]"],
	story_tide_chart = ["Royal Tide Chart", "Story item - readable", "A star chart of the King's old navy, washed up at Tidewell's shell shrine.",
		"The Haven, the Shardfield and the Gloam, drawn in royal blue.|One place inside the Shardfield has been scratched out, very carefully, again and again."],
	story_astrolabe_lens = ["Astrolabe Lens", "Story item", "The great lens of Hollowmoon's fallen astrolabe. Held over the Royal Tide Chart, the scratches burn away.", ""],
	story_eye_sigil = ["The Eye Sigil", "Story item - readable", "Taken from the Veiled Herald. A cold disc of pale crystal with a closed eye carved into it. Sometimes the eye moves.",
		"[enemy]Vaelith[/enemy]. The Pale One. The Eye behind the stars.|It found a kind king and whispered until he was hollow.|It waits in the [place]Stormeye Citadel[/place] on the Pale Eye. The Sigil knows the way in."],
	story_ice_card = ["Rime Card", "Story item - readable", "A card of frost that never melts.",
		"Where the frost sleeps, the [b]Crown of the Rime[/b] keeps watch.|A hidden entity waits in its stronghold, guarding a piece of what was torn.|Only the key of the peaks will open its gates."],
}
## What each map piece says, in order (the Torn Map shows the ones you hold).
const CLUE_TEXT := [
	"...beneath the crown, where lilies sleep...",
	"...north, past the frozen bell, the second edge...",
	"...sand swallowed the court that held the third...",
	"...a burning sea keeps the fourth...",
	"...beneath the drowned choir, the fifth...",
	"...and the last, in the hollow dark, where the hungry one waits.",
]


static func story_item(id: String) -> Item:
	var info: Array = STORY_ITEMS[id]
	var i := Item.new()
	i.id = id
	i.item_name = info[0]
	i.slot = "story"
	i.kind = info[1]
	i.lore = info[2]
	i.drop_bag = "story"
	if id == "story_clue":
		i.stack_max = 6
	i.abilities = PackedStringArray(["Double-click to read"] if info[3] != "" else ["Part of your party's story"])
	return i


## Two more backpack rows for this character, until it dies.
static func backpack() -> Item:
	var i := Item.new()
	i.id = "backpack"
	i.item_name = "Backpack"
	i.slot = "consumable"
	i.kind = "Backpack"
	i.consumable = {backpack = true}
	i.drop_bag = "green"
	i.abilities = PackedStringArray(["Double-click to strap it on: +2 backpack rows",
			"Lost, with everything in it, if you die"])
	i.lore = "Someone's whole life fit in here once. Now yours can."
	return i


## Health and magic elixirs: drink one to get 100 HP / MP back at once.
static func elixir(id: String) -> Item:
	var i := Item.new()
	i.id = id
	i.slot = "consumable"
	i.kind = "Elixir"
	i.stack_max = 8
	if id == "elixir_hp":
		i.item_name = "Health Elixir"
		i.consumable = {hp = 100}
		i.abilities = PackedStringArray(["Restores 100 health", "Double-click or quickslot (F / G) to drink"])
		i.lore = "Tastes of iron and wild strawberries."
	else:
		i.item_name = "Magic Elixir"
		i.consumable = {mp = 100}
		i.abilities = PackedStringArray(["Restores 100 magic", "Double-click or quickslot (F / G) to drink"])
		i.lore = "It fizzes, and the bubbles fall upward."
	return i


static func starting_gear(class_id := "archer") -> Dictionary:
	return PlayerClasses.starting_gear(class_id)


static func bow(tier: int) -> Item:
	var i := Item.new()
	i.id = "G%d_bow" % tier
	i.item_name = BOW_NAMES[tier - 1]
	i.slot = "weapon"
	i.kind = "Bow"
	i.tier = tier
	i.lore = BOW_LORE[tier - 1]
	i.damage_min = BOW_DAMAGE[tier - 1][0]
	i.damage_max = BOW_DAMAGE[tier - 1][1]
	var colors: Array = BOW_COLORS[tier - 1]
	i.projectile = {
		style = "arrow", color = colors[0], color2 = colors[1],
		glow = tier >= 3, trail = tier >= 4, size = 1.0 + (tier - 1) * 0.05,
		speed = 24.0 + tier * 0.8, range = 22.0 + tier * 0.6,
	}
	if tier >= 7:
		i.shots = 3
		i.spread_deg = 7.0
	if tier >= 3:
		i.charge = {style = "power", mult = 2.2 + (tier - 3) * 0.1}
		i.abilities.append("Hold right click: charged shot (up to x%.1f damage)" % i.charge.mult)
	if tier >= 6:
		i.aura_color = colors[0]
		i.aura_power = (tier - 5) * 0.12
	_weapon_attacks(i)
	return i


static func cloak(tier: int) -> Item:
	var i := Item.new()
	i.id = "G%d_cloak" % tier
	i.item_name = CLOAK_NAMES[tier - 1]
	i.slot = "armor"
	i.kind = "Cloak"
	i.tier = tier
	i.lore = CLOAK_LORE[tier - 1]
	i.bonuses = {defense = 4 + (tier - 1) * 3}
	i.bonuses.merge(CLOAK_EXTRAS[tier - 1])
	if tier >= 5:
		i.aura_color = CLOAK_COLORS[tier - 1]
		i.aura_power = (tier - 4) * 0.12
	return i


static func spell(tier: int) -> Item:
	var i := Item.new()
	i.id = "G%d_spell" % tier
	i.item_name = SPELL_NAMES[tier - 1]
	i.slot = "spell"
	i.kind = "Spell"
	i.tier = tier
	i.lore = SPELL_LORE[tier - 1]
	i.bonuses = {magic = 5 + (tier - 1) * 3}
	if tier >= 2:
		i.bonuses.mp = (tier - 1) * 20
	i.shield_tint = SPELL_COLORS[tier - 1][0]
	i.shield_arcs = SPELL_COLORS[tier - 1][1]
	i.shield_rainbow = 0.2
	i.warp = 0.035 + tier * 0.007
	if tier >= 2:
		i.effects.shield_drain = 1.0 - (tier - 1) * 0.05
		i.abilities.append("Shield costs %d%% less MP" % [(tier - 1) * 5])
	if tier >= 3:
		i.bonuses.magic = roundi(float(i.bonuses.magic)*(1.0+(tier-2)*0.1))
	if tier >= 4:
		i.ring = {damage = 220 + (tier - 4) * 140, range = 6.0 + (tier - 4) * 2.0, speed = 11.0, cost = 35 + (tier - 4) * 10, cooldown = 1.0 + (tier - 4) * 0.1}
		i.abilities.append("Double-tap Space: cast a warp ring")
		i.aura_color = SPELL_COLORS[tier - 1][1]
		i.aura_power = (tier - 3) * 0.12
	_ring_effects(i)
	return i


static func wand(tier: int) -> Item:
	var i := Item.new()
	i.id = "G%d_wand" % tier
	i.item_name = "Grade %d Wand" % tier
	i.slot = "weapon"
	i.kind = "Wand"
	i.tier = tier
	i.damage_min = roundi(BOW_DAMAGE[tier - 1][0] * 0.9)
	i.damage_max = roundi(BOW_DAMAGE[tier - 1][1] * 0.9)
	i.bonuses = {magic = tier * 2}
	i.projectile = {style = "bolt", color = SPELL_COLORS[mini(tier - 1, 4)][1], speed = 22.0, range = 20.0}
	_weapon_attacks(i)
	return i


static func trident(tier: int) -> Item:
	var i := Item.new()
	i.id = "G%d_trident" % tier
	i.item_name = "Grade %d Trident" % tier
	i.slot = "weapon"
	i.kind = "Trident"
	i.tier = tier
	i.damage_min = roundi(BOW_DAMAGE[tier - 1][0] * 1.25)
	i.damage_max = roundi(BOW_DAMAGE[tier - 1][1] * 1.25)
	i.fire_rate = 0.8
	i.projectile = {style = "bolt", color = BOW_COLORS[tier - 1][0], speed = 22.0, range = 16.0}
	_weapon_attacks(i)
	return i


static func robe(tier: int) -> Item:
	var i := Item.new()
	i.id = "G%d_robe" % tier
	i.item_name = "Grade %d Robe" % tier
	i.slot = "armor"
	i.kind = "Robe"
	i.tier = tier
	i.bonuses = {defense = 2 + (tier - 1) * 2, magic = tier * 3, mp = tier * 10}
	return i


static func bonus(tier: int, family: String) -> Item:
	var i := Item.new()
	i.id = "G%d_bonus_%s" % [tier, family]
	i.item_name = "Grade %d %s" % [tier, family.capitalize()]
	i.slot = "bonus"
	i.kind = family.capitalize()
	i.tier = tier
	i.lore = "A relic carried by adventurers of every class."
	match family:
		"crucifix": i.bonuses = {defense = tier + 1, hp = tier * 5}
		"flame": i.bonuses = {attack = tier * 2}
		"eye": i.bonuses = {dexterity = tier * 2}
		"crystal": i.bonuses = {magic = tier * 2, mp = tier * 5}
		"talisman": i.bonuses = {speed = tier, hp = tier * 8}
	return i


static func divine() -> Array[Item]:
	var out: Array[Item] = []

	# --- Bows -------------------------------------------------------------------
	out.append(_divine("D_bow_Blood", "Bow of the Blood Moon", "weapon", "Bow",
			"It drinks a little of whatever it hits, and shares.", {dexterity = 20},
			["+20 Dexterity: very fast, lighter shots", "Each hit heals you 2 HP"],
			{lifesteal = 2}))
	out[-1].charge = {style = "burst", count = 6, interval = 0.07, mult = 1.3}
	out[-1].abilities.append("Charged: Blood Torrent, a rapid burst of 6 arrows")
	out[-1].damage_min = 55
	out[-1].damage_max = 70
	out[-1].projectile = {style = "arrow", color = Color("#cb5757"), color2 = Color("#591515"),
			glow = true, trail = true, speed = 30.0, range = 24.0, size = 1.0}

	out.append(_divine("D_bow_Cindrella", "Cindrella's Twin Song", "weapon", "Bow",
			"Two notes that never quite agree, dancing around the same tune.", {},
			["Fires two shots that weave side to side"], {}))
	out[-1].damage_min = 95
	out[-1].damage_max = 115
	out[-1].shots = 2
	out[-1].charge = {style = "helix", mult = 2.6}
	out[-1].abilities.append("Charged: Duet, two huge shots spiralling around each other")
	out[-1].projectile = {style = "arrow", color = Color("#d85662"), color2 = Color("#56d8c5"),
			glow = true, trail = true, speed = 26.0, range = 26.0, size = 1.1,
			wave_amp = 0.7, wave_freq = 11.0}

	out.append(_divine("D_bow_Darkmatter", "Bow of Dark Matter", "weapon", "Bow",
			"Heavier than it should be. The arrows fall out of the world on purpose.", {dexterity = -15},
			["Slow, crushing shots (500-600)", "Shots pass through everything"], {}))
	out[-1].damage_min = 500
	out[-1].damage_max = 600
	out[-1].fire_rate = 0.35
	out[-1].windup = 0.35
	out[-1].projectile = {style = "arrow", color = Color("#b040e0"), color2 = Color("#2a0a36"),
			glow = true, trail = true, speed = 18.0, range = 24.0, size = 1.7, pierce = true}
	out[-1].charge = {style = "singularity", mult = 1.8, ring_damage = 260, ring_range = 7.0}
	out[-1].abilities.append("Charged: Singularity, collapses into a warp ring at the end")

	out.append(_divine("D_bow_Fallenwoods", "Bow of the Fallen Woods", "weapon", "Bow",
			"Cut from the last tree of a forest that fell in a single night.", {},
			["Fires three shots in a fan (8° apart)"], {}))
	out[-1].damage_min = 80
	out[-1].damage_max = 95
	out[-1].shots = 3
	out[-1].spread_deg = 8.0
	out[-1].charge = {style = "volley", count = 9, spread = 6.0, mult = 1.6}
	out[-1].abilities.append("Charged: Falling Leaves, a wide fan of 9 arrows")
	out[-1].projectile = {style = "arrow", color = Color("#33b23c"), color2 = Color("#d8a066"),
			glow = true, trail = true, speed = 27.0, range = 25.0, size = 1.1}

	out.append(_divine("D_bow_dragon", "Dragonbreath Longbow", "weapon", "Bow",
			"Strung with a dragon's sinew. It still breathes when it's angry.", {attack = 4},
			["Fire bolts burn through everything in their path"], {}))
	out[-1].damage_min = 140
	out[-1].damage_max = 165
	out[-1].fire_rate = 0.8
	out[-1].windup = 0.18
	out[-1].charge = {style = "inferno", mult = 2.4, ring_damage = 180, ring_range = 5.0}
	out[-1].abilities.append("Charged: Dragon's Roar, bursts into flames on impact")
	out[-1].projectile = {style = "bolt", color = Color("#fb9b21"), color2 = Color("#d02f18"),
			glow = true, trail = true, speed = 28.0, range = 28.0, size = 1.3, pierce = true}

	# --- Cloaks -----------------------------------------------------------------
	out.append(_divine("D_cloak_blood", "Mantle of the Blood Pact", "armor", "Cloak",
			"Signed in red. The terms are very generous, at first.", {defense = 12, attack = 6, hp = 20},
			["Your hits heal you 1 HP"], {lifesteal = 1}, Color("#c02020"), 0.5))
	out.append(_divine("D_cloak_burningman", "Cloak of the Burning Man", "armor", "Cloak",
			"He walked out of the fire and kept walking. This is what he wore.", {defense = 12, speed = 7},
			["Leaves burning footprints"], {trail = "embers"}, Color("#ff7a20"), 0.6))
	out.append(_divine("D_cloak_goldslinger", "The Goldslinger's Duster", "armor", "Cloak",
			"Every pocket jingles. None of them are empty, ever.", {defense = 10, dexterity = 8, attack = 4},
			["Your arrows trail gold"], {trail = "gold"}, Color("#f0b030"), 0.5))
	out.append(_divine("D_cloak_silvershield", "Silver Shield Cloak", "armor", "Cloak",
			"Heavy as a promise. Nothing gets through that hasn't asked first.", {defense = 24, speed = -3, magic = 12},
			[], {}, Color("#e0e4ec"), 0.4))
	out.append(_divine("D_cloak_theblue", "Cloak of the Blue", "armor", "Cloak",
			"The color of deep water, and just as patient.", {defense = 12, magic = 6, mp = 40},
			["Magic recovers 50% faster"], {mp_regen = 1.5}, Color("#56d8e8"), 0.5))
	out.append(_divine("D_cloak_thevoid", "Cloak of the Void", "armor", "Cloak",
			"There is nothing inside it. That's what makes it so warm.", {defense = 14, speed = 5},
			["Shield costs 30% less MP"], {shield_drain = 0.7}, Color("#5a1a8a"), 0.6))
	out.append(_divine("D_cloak_unlimitedmadness", "Cloak of Unlimited Madness", "armor", "Cloak",
			"Every color at once, all the time. You get used to it. Mostly.",
			{defense = 10, speed = 3, attack = 3, dexterity = 3, magic = 3},
			["+3 to every stat", "Rainbow aura"], {trail = "rainbow"}, Color("#c040ff"), 0.8))

	# --- Spells -----------------------------------------------------------------
	out.append(_divine("D_spell_oftheblue", "Spell of the Blue", "spell", "Spell",
			"The deep sea, folded small enough to carry. It wants to unfold.", {magic = 32, mp = 100},
			["Shield costs 30% less MP", "Warp ring rolls out three times"],
			{shield_drain = 0.7}, Color("#6cfce8"), 0.7))
	out[-1].shield_tint = Color("#14305e")  # black magic: deep navy with blue sparks
	out[-1].shield_arcs = Color("#2f6fe0")
	out[-1].shield_rainbow = 0.0
	out[-1].warp = 0.085
	out[-1].ring = {damage = 280, range = 12.0, speed = 14.0, cost = 55, cooldown = 1.5, pulses = 3}

	out.append(_divine("D_spell_ofthedivine", "Spell of the Divine", "spell", "Spell",
			"A halo that fell off something holy. It hasn't noticed yet.", {magic = 31, mp = 100},
			["Shield heals you 3 HP per second", "Warp ring heals you 20 HP"],
			{shield_heal = 3.0}, Color("#ffde46"), 0.8))
	out[-1].shield_tint = Color("#ffde46")
	out[-1].shield_arcs = Color("#fc6ce2")
	out[-1].shield_rainbow = 0.4
	out[-1].warp = 0.09
	out[-1].ring = {damage = 160, range = 14.0, speed = 15.0, cost = 40, heal = 20}

	out.append(_divine("D_robe_oftheblue", "Robe of the Blue", "armor", "Robe",
			"Deep-water silk, threaded with a dragon's cold light.", {defense = 18, magic = 16, mp = 60},
			["Magic recovers 25% faster"], {mp_regen = 1.25}, Color("#86f5f5"), 0.5))
	out.append(_divine("D_trident_oftheblue", "Trident of the Blue", "weapon", "Trident",
			"Three splinters from the heart of a frozen sea.", {attack = 5, magic = 8}, [], {}, Color("#7be6f8"), 0.5))
	out[-1].damage_min = 140
	out[-1].damage_max = 170
	out[-1].projectile = {style = "bolt", color = Color("#7be6f8"), speed = 26.0, range = 18.0}
	out.append(_divine("D_bonus_crucifix_oftheblue", "Crucifix of the Blue", "bonus", "Crucifix",
			"Cold enough to quiet the heart. Bright enough to keep it beating.", {defense = 6, magic = 8, mp = 60},
			["Magic recovers 20% faster"], {mp_regen = 1.2}, Color("#7be6f8"), 0.35))

	_frost_set(out)
	_satan_set(out)
	_holy_set(out)
	_void_set(out)
	_fallenwood_set(out)
	_court_sets(out)
	_storm_set(out)
	_iron_set(out)
	_spirit_set(out)
	DivineSets.build(out)

	for item in out:
		if item.is_weapon(): _weapon_attacks(item)
		if not item.ring.is_empty(): _ring_effects(item)
		if item.slot == "weapon":
			item.aura_color = item.projectile.color  # divine weapons glow in their shot color
		# Dark blood relics use black bags. Other explicit exceptions, such as
		# the Goblin King's rare scepter, are assigned by their set builder.
		if item.id in ["D_bow_Blood", "D_cloak_blood"]:
			item.drop_bag = "black"
	DivineSets.finish(out)
	var live := []
	for ids: Array in DIVINE_SETS.values():
		live.append_array(ids)
	return out.filter(func(i: Item) -> bool: return i.id in live)


## Rimeheart Prism's Frost set: cold, patient, magic and dexterity.
static func _frost_set(out: Array[Item]) -> void:
	var ice := Color("#53d5e4")
	out.append(_divine("D_bow_offrost", "Bow of Frost", "weapon", "Bow",
			"Strung with a thread of meltwater that never thaws.", {dexterity = 8, magic = 4},
			["Shots pierce through enemies"], {}))
	out[-1].damage_min = 120
	out[-1].damage_max = 140
	out[-1].charge = {style = "volley", count = 7, spread = 5.0, mult = 1.7}
	out[-1].abilities.append("Charged: Hailfall, a fan of 7 frozen arrows")
	out[-1].projectile = {style = "arrow", color = ice, color2 = Color("#eaffff"), glow = true, trail = true,
			speed = 27.0, range = 26.0, size = 1.1, pierce = true}
	out.append(_divine("D_wand_offrost", "Wand of Frost", "weapon", "Wand",
			"It points at things until they hold very still.", {magic = 10}, [], {}))
	out[-1].damage_min = 120
	out[-1].damage_max = 150
	out[-1].projectile = {style = "bolt", color = ice, speed = 24.0, range = 20.0}
	out.append(_divine("D_trident_offrost", "Trident of Frost", "weapon", "Trident",
			"Three icicles that grew from the same cold heart.", {attack = 5, dexterity = 5}, [], {}))
	out[-1].damage_min = 150
	out[-1].damage_max = 180
	out[-1].projectile = {style = "bolt", color = ice, speed = 25.0, range = 17.0}
	out.append(_divine("D_spell_offrost", "Spell of Frost", "spell", "Spell",
			"A six-sided silence. The air around it rings faintly.", {magic = 27, mp = 90, dexterity = 4},
			["Shield costs 20% less MP", "Warp ring rolls out twice"],
			{shield_drain = 0.8}, ice, 0.6))
	out[-1].shield_tint = Color("#9fe9f2")
	out[-1].shield_arcs = ice
	out[-1].shield_rainbow = 0.1
	out[-1].warp = 0.08
	out[-1].ring = {damage = 300, range = 11.0, speed = 13.0, cost = 50, cooldown = 1.3, pulses = 2}
	out.append(_divine("D_cloak_offrost", "Cloak of Frost", "armor", "Cloak",
			"Snow settles on it and refuses to fall off.", {defense = 13, dexterity = 6, speed = 4},
			["Magic recovers 30% faster"], {mp_regen = 1.3}, ice, 0.5))
	out.append(_divine("D_robe_offrost", "Robe of Frost", "armor", "Robe",
			"Woven from the hush that falls before a blizzard.", {defense = 16, magic = 15, mp = 50},
			["Magic recovers 25% faster"], {mp_regen = 1.25}, ice, 0.5))
	for kind in [["crucifix", "Crucifix", {defense = 7, hp = 40}, "Its cold keeps the heart steady."],
			["flame", "Flame", {attack = 8, magic = 4}, "A cold flame. It burns the other way."],
			["eye", "Eye", {dexterity = 10, magic = 4}, "It never blinks. Frost does not need to."],
			["crystal", "Crystal", {magic = 12, mp = 50}, "A shard from the Rimeheart, still faintly humming."],
			["talisman", "Talisman", {speed = 6, hp = 50}, "Lighter than snow, harder than ice."]]:
		out.append(_divine("D_bonus_%s_offrost" % kind[0], "%s of Frost" % kind[1], "bonus", kind[1],
				kind[3], kind[2], [], {}, ice, 0.35))


## Vharok's Satan set: brutal, red, attack.
static func _satan_set(out: Array[Item]) -> void:
	out.append(_divine("D_trident_ofsatan", "Trident of Satan", "weapon", "Trident",
			"Forged in the Cinder Bastion. The handle is always warm.", {attack = 10}, ["Your hits heal you 1 HP"],
			{lifesteal = 1}))
	out[-1].damage_min = 170
	out[-1].damage_max = 200
	out[-1].projectile = {style = "bolt", color = Color("#c71c00"), speed = 24.0, range = 17.0}
	out.append(_divine("D_wand_thewandofsatan", "The Wand of Satan", "weapon", "Wand",
			"It answers every question with fire.", {attack = 6, magic = 8}, [], {}))
	out[-1].damage_min = 135
	out[-1].damage_max = 165
	out[-1].projectile = {style = "bolt", color = Color("#feba29"), speed = 23.0, range = 20.0}
	out.append(_divine("D_bonus_crucifix_ofsatan", "Crucifix of Satan", "bonus", "Crucifix",
			"Hung upside down, and it likes it that way.", {attack = 8, defense = 5, hp = 30},
			["Your hits heal you 1 HP"], {lifesteal = 1}, Color("#c23a3a"), 0.4))


## The Scarab Regent's Holy Divine set: gold, ivory, healing.
static func _holy_set(out: Array[Item]) -> void:
	out.append(_divine("D_trident_ofthedivine", "Trident of the Divine", "weapon", "Trident",
			"Its three points are three promises.", {attack = 6, defense = 4}, [], {}))
	out[-1].damage_min = 155
	out[-1].damage_max = 185
	out[-1].projectile = {style = "bolt", color = Color("#fdb800"), speed = 25.0, range = 17.0}
	out.append(_divine("D_wand_thewandofthedivine", "The Wand of the Divine", "weapon", "Wand",
			"Light pours out of it like water from a cracked jar.", {magic = 10, hp = 20}, [], {}))
	out[-1].damage_min = 125
	out[-1].damage_max = 155
	out[-1].projectile = {style = "bolt", color = Color("#fdb800"), speed = 24.0, range = 20.0}
	out.append(_divine("D_bonus_flame_ofthedivine", "Flame of the Divine", "bonus", "Flame",
			"A candle lit at the Court of the Sun. It never gutters.", {attack = 6, magic = 6, hp = 30},
			["Shield heals you 2 HP per second"], {shield_heal = 2.0}, Color("#fca434"), 0.45))


## The Hollow Crown's Void set: dark matter and stolen starlight.
static func _void_set(out: Array[Item]) -> void:
	out.append(_divine("D_robe_ofthegalaxy", "Robe of the Galaxy", "armor", "Robe",
			"Every fold hides a star someone forgot to name.", {defense = 17, magic = 17, mp = 70},
			["Shield costs 20% less magic"], {shield_drain = 0.8}, Color("#ebf203"), 0.55))
	out.append(_divine("D_trident_ofthevoid", "Trident of the Void", "weapon", "Trident",
			"It goes through things. Then it goes through them again.", {attack = 6, speed = 3}, [], {}))
	out[-1].damage_min = 160
	out[-1].damage_max = 190
	out[-1].projectile = {style = "bolt", color = Color("#ff6be8"), speed = 25.0, range = 17.0, pierce = true}
	out.append(_divine("D_wand_thewandofdarkness", "The Wand of Darkness", "weapon", "Wand",
			"Where it points, the light leaves first.", {magic = 12}, [], {}))
	out[-1].damage_min = 130
	out[-1].damage_max = 160
	out[-1].projectile = {style = "bolt", color = Color("#b040e0"), speed = 23.0, range = 20.0}


## Preserve the source texture's legacy spelling as its stable runtime id.
static func _spirit_set(out: Array[Item]) -> void:
	var wand := _divine("D_wand_thewandofthespitit", "Wand of the Spirit", "weapon", "Wand",
		"The god's last breath coils around your wrist. Release it, and the fangs remember.",
		{speed = 5, dexterity = 5}, ["Twin Spirit Fangs", "Charged: Dreadcoil Trinity"], {})
	wand.damage_min = 125
	wand.damage_max = 155
	wand.projectile = {style = "serpent", color = Color("f01cde"), color2 = Color("ececec"), speed = 23.0, range = 20.0}
	wand.drop_bag = "white"
	out.append(wand)


static func _divine(id: String, item_name: String, slot: String, kind: String, lore: String,
		bonuses: Dictionary, abilities: Array, effects: Dictionary,
		aura_color := Color(0, 0, 0, 0), aura_power := 0.6) -> Item:
	var i := Item.new()
	i.id = id
	i.item_name = item_name
	i.slot = slot
	i.kind = kind
	i.tier = Item.DIVINE
	i.lore = lore
	i.bonuses = bonuses
	i.abilities = PackedStringArray(abilities)
	i.effects = effects
	if aura_color.a > 0.0:
		i.aura_color = aura_color
		i.aura_power = aura_power
	elif slot == "weapon":
		i.aura_power = 0.4  # divine bows glow in their projectile color (set below)
	return i


static func _court_sets(out: Array[Item]) -> void:
	out.append(_divine("D_wand_thewandofsteel", "Vizier's Quicksilver Rod", "weapon", "Wand",
			"A mirror of the sun, hammered thin enough to flow.", {magic = 9, dexterity = 5},
			["Twin silver needles", "Charged: Mirror Procession, six weaving silver streams"], {}))
	out[-1].damage_min = 115
	out[-1].damage_max = 145
	out[-1].projectile = {style = "orb", color = Color("c5d9ed"), speed = 28.0, range = 24.0, pierce = true}
	out[-1].drop_bag = "black"
	out.append(_divine("D_bonus_crucifix_ofthalao", "Thalao's Silver Seal", "bonus", "Crucifix",
			"The court's oath survives beneath the sand.", {defense = 7, hp = 55, magic = 5},
			["Magic recovers 15% faster"], {mp_regen = 1.15}, Color("cadbea"), 0.4))
	out.append(_divine("D_robe_ofthedragonsbreath", "Robe of the Dragon's Breath", "armor", "Robe",
			"Woven from the smoke of the first burning grove.", {defense = 16, magic = 17, mp = 65},
			["Magic recovers 20% faster"], {mp_regen = 1.2}, Color("f88432"), 0.6))
	out.append(_divine("D_bonus_flame_ofthebroken", "Flame of the Broken Grove", "bonus", "Flame",
			"Even ash remembers the shape of a tree.", {attack = 9, magic = 7, hp = 30},
			[], {}, Color("ffb34b"), 0.7))
	out[-1].drop_bag = "black"


static func _fallenwood_set(out: Array[Item]) -> void:
	for spec in [["D_trident_ofthefallenwood", "Rootkeeper's Trident", "Trident"],
		["D_wand_thewandofthefallenwood", "The King's Moss Scepter", "Wand"]]:
		out.append(_divine(spec[0], spec[1], "weapon", spec[2],
			"Stolen from the fallen woods and crowned in the mosslit court.", {magic = 6, dexterity = 4},
			["Slow, piercing moss bolts"], {}))
		var item: Item = out[-1]
		item.damage_min = 100
		item.damage_max = 130
		item.projectile = {style = "bolt", color = Color("91c36a"), speed = 20.0, range = 22.0, size = 1.0, pierce = true, glow = true}
		if spec[2] == "Wand": item.drop_bag = "black"


## Colors match the crystals / metal in the authored 8x8 icons.
const MAGIC_COLORS := [Color("e7e7e7"), Color("50cf4b"), Color("1b9adf"), Color("f4901b"),
	Color("8314c7"), Color("f41bdc"), Color("f6a802"), Color("ffe300")]

static func _weapon_attacks(item: Item) -> void:
	var divine := item.is_divine()
	var grade := 8 if divine else item.tier
	if item.kind in ["Wand", "Trident"]:
		var tint: Color = item.projectile.get("color", Color.WHITE)
		if not divine:
			tint = MAGIC_COLORS[grade - 1]
		else:
			if "frost" in item.id: tint = Color("b6f3ff")
			elif "satan" in item.id: tint = Color("e42e2e")
			elif "fallenwood" in item.id: tint = Color("1ef092")
			elif "darkness" in item.id or "void" in item.id: tint = Color("8545bb")
		item.projectile.color = tint
		item.projectile.color2 = tint.lightened(0.4)
		item.projectile.glow = true
		item.projectile.trail = grade >= 3
		if item.kind == "Wand":
			item.projectile.style = "orb"
			item.projectile.size = 0.75 + grade * 0.06
			item.charge = {style="arcane", mult=2.5, name="Arcane Spiral", angle=8.0}
			if grade >= 5:
				item.shots = 2
				item.spread_deg = 0.0
				item.projectile.wave_amp = 0.38 + grade * 0.035
				item.projectile.wave_freq = 13.0
			if divine:
				if "frost" in item.id:
					item.charge.name = "Rime Spiral"
					item.charge.streams = 6
					item.projectile.wave_amp = 0.45
				elif "storm" in item.id:
					item.charge.name = "Drowned Chorus"
					item.charge.streams = 4
					item.projectile.wave_amp = 0.55
					item.projectile.wave_freq = 10.0
				elif "steel" in item.id:
					item.charge.name = "Mirror Procession"
					item.charge.streams = 6
					item.projectile.wave_amp = 0.22
					item.projectile.wave_freq = 19.0
					item.projectile.size = 0.8
				elif "satan" in item.id:
					item.charge.name = "Hellfire Spiral"
					item.charge.streams = 3
					item.charge.mult = 2.9
				elif "darkness" in item.id:
					item.charge.name = "Eclipse Spiral"
					item.projectile.wave_amp = 0.85
					item.projectile.pierce = true
				elif "divine" in item.id:
					item.charge.name = "Sun Spiral"
					item.charge.streams = 4
					item.shots = 3
					item.spread_deg = 4.0
					item.charge.mult = 2.7
				elif "fallenwood" in item.id:
					item.charge.name = "Briar Spiral"
					item.charge.streams = 3
					item.projectile.wave_freq = 9.0
		else:
			item.projectile.style = "trident"
			item.projectile.size = 0.75 + grade * 0.04
			item.charge = {style="stream", name="Tidal Stream", count=10, interval=0.045, mult=2.4}
			if grade >= 7:
				item.shots = 3
				item.spread_deg = 5.0
			if divine:
				if "blue" in item.id:
					item.charge.name = "Dragon Tide"
					item.charge.count = 14
				elif "frost" in item.id: item.charge.name = "Glacial Torrent"
				elif "satan" in item.id:
					item.charge.name = "Cinder Torrent"
					item.charge.mult = 2.8
				elif "void" in item.id:
					item.charge.name = "Rift Torrent"
					item.projectile.wave_amp = 0.3
					item.projectile.wave_freq = 12.0
				elif "divine" in item.id: item.charge.name = "Golden Torrent"
				elif "fallenwood" in item.id: item.charge.name = "Rootwater Torrent"
				elif "storm" in item.id:
					item.charge.name = "Undertow Torrent"
					item.charge.count = 12
					item.projectile.wave_amp = 0.2
					item.projectile.wave_freq = 10.0
	if item.id == "D_wand_thewandofthespitit":
		item.projectile.style = "serpent"
		item.projectile.color2 = Color("ececec")
		item.projectile.size = 1.0
		item.projectile.wave_amp = 0.48
		item.projectile.wave_freq = 11.0
		item.shots = 2
		item.spread_deg = 0.0
		item.charge = {style = "serpent_fan", name = "Dreadcoil Trinity", count = 3, spread = 12.0, mult = 2.8}
	if item.id.ends_with("_ofiron"):
		item.projectile.style = "arrow" if item.kind == "Bow" else "trident" if item.kind == "Trident" else "orb"
		item.projectile.color = Color("aab4c9")
		item.projectile.color2 = Color("f2ebff")
		item.projectile.pierce = true
		if item.kind == "Wand":
			item.charge = {style = "arcane", name = "Crown of Iron", streams = 6, angle = 12.0, mult = 2.8}
		elif item.kind == "Trident":
			item.charge = {style = "stream", name = "Royal Procession", count = 16, interval = 0.045, mult = 2.6}
		else:
			item.charge = {style = "volley", name = "Iron Rain", count = 9, spread = 6.0, mult = 2.6}
	if item.shots == 2: item.projectile_shares = [0.5, 0.5]
	elif item.shots == 3: item.projectile_shares = [0.4, 0.7, 0.4]
	else: item.projectile_shares = [1.0]
	if divine:
		if item.id == "D_wand_thewandofthespitit":
			item.primary_effects = [{id = "speed", amount = -2, duration = 1.2}]
			item.secondary_effects = [{id = "armour_broken", duration = 3.5}]
		elif "frost" in item.id:
			item.primary_effects = [{id="static", duration=0.6}]
			item.secondary_effects = [{id="static", duration=4.4}]
		elif "satan" in item.id:
			item.primary_effects = [{id="armour_broken", duration=1.4}]
			item.secondary_effects = [{id="armour_broken", duration=4.0}]
		elif "fallenwood" in item.id or "Fallenwoods" in item.id:
			item.primary_effects = [{id="speed", amount=-3, duration=2.0}]
			item.secondary_effects = [{id="static", duration=2.4}]
		elif "darkness" in item.id or "void" in item.id or "Darkmatter" in item.id:
			item.primary_effects = [{id="quiet", duration=1.0}]
			item.secondary_effects = [{id="quiet", duration=4.0}]
		elif "blue" in item.id:
			item.primary_effects = [{id="speed", amount=-3, duration=1.5}]
			item.secondary_effects = [{id="static", duration=3.0}]
		else:
			item.secondary_effects = [{id="armour_broken", duration=3.5}]
	elif grade >= 5:
		item.secondary_effects = [{id="static" if grade >= 7 else "armour_broken", duration=1.2 + (grade-5)*0.4}]
		if grade >= 7: item.primary_effects = [{id="speed", amount=-2, duration=1.0}]

static func _ring_effects(item: Item) -> void:
	if item.ring.is_empty(): return
	# Every Divine spell's ring does its own thing.
	const DIVINE_RINGS := {
		D_spell_oftheblue = [{id = "speed", amount = -4, duration = 3.0}],
		D_spell_ofthedivine = [{id = "armour_broken", duration = 3.0}],
		D_spell_ofstorm = [{id = "static", duration = 2.0}, {id = "speed", amount = -2, duration = 2.0}],
		D_spell_ofvenom = [{id = "armour_broken", duration = 4.0}, {id = "speed", amount = -3, duration = 3.0}],
		D_spell_ofeclipse = [{id = "quiet", duration = 3.0}],
	}
	if DIVINE_RINGS.has(item.id):
		item.secondary_effects.assign(DIVINE_RINGS[item.id])
	elif "frost" in item.id:
		item.secondary_effects = [{id="static", duration=4.4}]
	elif item.is_divine():
		item.secondary_effects = [{id="armour_broken", duration=3.0}]
	elif item.tier >= 5:
		item.secondary_effects = [{id="static", duration=1.8}]
	else:
		item.secondary_effects = [{id="speed", amount=-3, duration=2.0}]


## Shared by the Abyssal Siren and Drowned Cantor; every source icon is live.
static func _storm_set(out: Array[Item]) -> void:
	var storm := Color("70bce9")
	for spec in [["D_bow_ofstorm", "Bow of Storm", "Bow", 115, 140],
		["D_wand_ofstorm", "Wand of Storm", "Wand", 125, 150],
		["D_trident_ofstorm", "Trident of Storm", "Trident", 155, 180]]:
		out.append(_divine(spec[0], spec[1], "weapon", spec[2],
			"A drowned bell's last note, caught in crystal.", {magic = 7, dexterity = 5},
			["Charged: release the storm's chorus"], {}))
		out[-1].damage_min = spec[3]
		out[-1].damage_max = spec[4]
		out[-1].projectile = {style = "arrow" if spec[2] == "Bow" else "bolt", color = storm,
			color2 = Color("e0faff"), glow = true, trail = true, speed = 27.0, range = 24.0,
			size = 1.1, wave_amp = 0.2, wave_freq = 10.0}
		if spec[2] == "Bow":
			out[-1].charge = {style = "volley", name = "Storm Chorus", count = 7, spread = 7.0, mult = 1.8}
	out.append(_divine("D_spell_ofstorm", "Spell of Storm", "spell", "Spell",
		"The tide keeps time to a distant tower.", {magic = 29, mp = 95, dexterity = 4},
		["Warp ring rolls out twice"], {}, storm, 0.6))
	out[-1].shield_tint = Color("477ab7")
	out[-1].shield_arcs = Color("bcefff")
	out[-1].warp = 0.08
	out[-1].ring = {damage = 290, range = 12.0, speed = 12.0, cost = 50, cooldown = 1.4, pulses = 2}
	out.append(_divine("D_cloak_ofstorm", "Cloak of Storm", "armor", "Cloak",
		"Wind and water cling to its hem.", {defense = 14, dexterity = 6, speed = 3},
		["Magic recovers 25% faster"], {mp_regen = 1.25}, storm, 0.5))
	out.append(_divine("D_robe_ofstorm", "Robe of Storm", "armor", "Robe",
		"Woven from rain that never reached the sea.", {defense = 17, magic = 16, mp = 60},
		["Magic recovers 20% faster"], {mp_regen = 1.2}, storm, 0.5))
	for spec in [["crucifix", "Crucifix", {defense = 7, hp = 45}],
		["flame", "Flame", {attack = 7, magic = 5}], ["eye", "Eye", {dexterity = 9, magic = 4}],
		["crystal", "Crystal", {magic = 11, mp = 55}], ["talisman", "Talisman", {speed = 6, hp = 45}]]:
		out.append(_divine("D_bonus_%s_ofstorm" % spec[0], "%s of Storm" % spec[1], "bonus", spec[1],
			"A small echo of the choir beneath Bluelay.", spec[2], [], {}, storm, 0.35))


static func _iron_set(out: Array[Item]) -> void:
	for spec in [["bow", "Bow"], ["wand", "Wand"], ["trident", "Trident"]]:
		var item := _divine("D_%s_ofiron" % spec[0], "%s of the Iron Oath" % spec[1], "weapon", spec[1],
			"The Hollow King's oath, forged into a weapon that outlived its bearer.",
			{attack = 10, magic = 8, defense = 4}, ["Piercing iron shots", "Charge to invoke the Iron Oath"], {})
		item.damage_min = 120
		item.damage_max = 155
		item.projectile = {style = "arrow" if spec[1] == "Bow" else "orb", color = Color("aab4c9"),
			color2 = Color("f2ebff"), speed = 27.0, range = 25.0, pierce = true, trail = true, glow = true}
		item.charge = {style = "volley", name = "Iron Rain", count = 9, spread = 6.0, mult = 2.6}
		out.append(item)
	out.append(_divine("D_cloak_ofiron", "Mantle of the Iron Oath", "armor", "Cloak",
		"Black links beneath a white hem.", {defense = 22, attack = 10, hp = 70}, ["Reduced shield drain"], {shield_drain = 0.85}))
	out.append(_divine("D_robe_ofiron", "Vestment of the Iron Oath", "armor", "Robe",
		"A king's funeral shroud, threaded with iron.", {defense = 18, magic = 20, mp = 80}, ["Magic recovers 20% faster"], {mp_regen = 1.2}))
	out.append(_divine("D_spell_ofiron", "Spell of the Iron Oath", "spell", "Spell",
		"The crown breaks. The oath remains.", {defense = 8, magic = 17, mp = 65}, ["Iron ward"], {}))
	out[-1].shield_tint = Color("9ea9c1")
	out[-1].shield_arcs = Color("f4eaff")
	out.append(_divine("D_bonus_crucifix_ofiron", "Seal of the Last King", "bonus", "Crucifix",
		"A pale cross hammered into black iron.", {defense = 8, attack = 8, magic = 8, hp = 60}, [], {}))
