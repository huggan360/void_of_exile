class_name PetDefs
extends RefCounted
## Shared pet rules. XP is the progress within the current level.
const BITE_DOTS := 10
const BITE_XP := 10
const MAX_LEVEL := 50
const MAX_PETS := 60
const SPECIES := {
	"duck": {name = "Puddle Duck", height = 0.55, gait = "waddle"},
	"puffbun": {name = "Puffbun", height = 0.5, gait = "hop"},
	"gloop": {name = "Gloop", height = 0.45, gait = "squash"},
	"ember_kit": {name = "Ember Kit", height = 0.6, gait = "trot"},
	"cinderling": {name = "Cinderling", height = 0.7, gait = "flap"},
	"hoot": {name = "Hoot", height = 0.5, gait = "glide"},
	"lilyhop": {name = "Lilyhop", height = 0.45, gait = "leap"},
	"mossback": {name = "Mossback", height = 0.45, gait = "plod"},
	"wisp": {name = "Wisp", height = 0.6, gait = "float"},
	"shardling": {name = "Shardling", height = 0.75, gait = "stomp"},
	"moonpaw": {name = "Moonpaw", height = 0.5, gait = "trot"},
	"axie": {name = "Axie", height = 0.4, gait = "wiggle"},
	"capling": {name = "Capling", height = 0.5, gait = "hop"},
	"nebula_jelly": {name = "Nebula Jelly", height = 0.8, gait = "pulse"},
	"skywhale": {name = "Skywhale", height = 0.7, gait = "swim"},
}
const RARITY_MULTIPLIERS := {common = 1.0, rare = 1.5, divine = 2.25}
const RARITY_COLORS := {common = Color("d1dbe4"), rare = Color("b48aff"), divine = Color("ffd16a")}
const ABILITIES := {
	regen = {name = "Regeneration", color = Color.WHITE, low = 2.0, high = 30.0},
	mana = {name = "Magic Regeneration", color = Color("4aa8ff"), low = 3.0, high = 36.0},
	attack = {name = "Attack", color = Color("ff3a3a"), low = 15.0, high = 260.0},
	chain = {name = "Chain Lightning", color = Color("b06bff"), low = 8.25, high = 143.0},
	ward = {name = "Ward", color = Color("ffc94a"), low = 2.0, high = 12.0},
	swift = {name = "Swiftness", color = Color("5cff8a"), low = 2.0, high = 10.0},
}

static func xp_to_next(level: int) -> int:
	return roundi(20.0 + 6.0 * level + 0.9 * level * level)

static func interval(level: int) -> float:
	return lerpf(10.0, 5.0, float(clampi(level, 1, MAX_LEVEL) - 1) / 49.0)

static func ability_value(id: String, level: int, rarity := "common") -> float:
	if not ABILITIES.has(id): return 0.0
	var a: Dictionary = ABILITIES[id]
	return lerpf(a.low, a.high, float(clampi(level, 1, MAX_LEVEL) - 1) / 49.0) * float(RARITY_MULTIPLIERS.get(rarity, 1.0))

static func random_pet(rng: RandomNumberGenerator) -> Dictionary:
	var species: String = SPECIES.keys()[rng.randi_range(0, SPECIES.size() - 1)]
	var ids := ABILITIES.keys()
	return {id = 0, species = species, rarity = "common", level = 1, xp = 0,
		abilities = [ids[rng.randi_range(0, ids.size() - 1)], ids[rng.randi_range(0, ids.size() - 1)]],
		name = SPECIES[species].name, born = int(Time.get_unix_time_from_system())}

## An empty result means the pair cannot merge. The server assigns the new id.
static func merge(a: Dictionary, b: Dictionary) -> Dictionary:
	if a.is_empty() or b.is_empty() or int(a.get("id", 0)) == int(b.get("id", 0)): return {}
	if a.get("species") != b.get("species") or a.get("rarity") != b.get("rarity"): return {}
	if not a.get("rarity") in ["common", "rare"]: return {}
	if not SPECIES.has(a.get("species")) or a.get("abilities", []).size() != 2 or b.get("abilities", []).size() != 2: return {}
	return {id = 0, species = a.species, rarity = "rare" if a.rarity == "common" else "divine",
		level = mini(int(a.level), int(b.level)), xp = 0, abilities = [a.abilities[0], b.abilities[0]],
		name = SPECIES[a.species].name, born = int(Time.get_unix_time_from_system())}

static func empty_state() -> Dictionary:
	return {next_id = 1, equipped = 0, pets = []}

static func find(state: Dictionary, id: int) -> Dictionary:
	for pet: Dictionary in state.get("pets", []):
		if int(pet.id) == id: return pet
	return {}

static func bites_to_next(pet: Dictionary) -> int:
	return 0 if int(pet.level) >= MAX_LEVEL else ceili(float(xp_to_next(int(pet.level)) - int(pet.xp)) / BITE_XP)

static func bites_to_cap(pet: Dictionary) -> int:
	var xp := -int(pet.xp)
	for level in range(int(pet.level), MAX_LEVEL): xp += xp_to_next(level)
	return maxi(0, ceili(float(xp) / BITE_XP))

static func feed(pet: Dictionary, bites: int) -> void:
	pet.xp = int(pet.xp) + bites * BITE_XP
	while int(pet.level) < MAX_LEVEL and int(pet.xp) >= xp_to_next(int(pet.level)):
		pet.xp -= xp_to_next(int(pet.level))
		pet.level = int(pet.level) + 1
	if int(pet.level) >= MAX_LEVEL: pet.xp = 0

static func ability_text(id: String, level: int, rarity: String) -> String:
	var value := String.num(ability_value(id, level, rarity), 1).trim_suffix(".0")
	var effect: String = {regen = "Heals %s HP", mana = "Restores %s MP", attack = "Deals %s damage", chain = "Deals %s damage to 3 enemies", ward = "+%s defence for 6 s", swift = "+%s speed for 6 s"}.get(id, "%s")
	return (effect % value) + " every %.1f s" % interval(level)
