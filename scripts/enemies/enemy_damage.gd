class_name EnemyDamage
extends RefCounted
## Applied only when a hostile hit is rolled, never to replicated ranges.
const ENEMY_DAMAGE_MULTIPLIER := 1.2

## Unlisted encounters ranked by health, phases and position in progression.
const ENCOUNTER_GRADES := {
	goblin_king = 3, mother_mycora = 4, mad_farmer = 5, thornmaw_bloom = 5,
	gilded_vizier = 6, magma_warden = 6, abyssal_siren = 6, queen_briarrose = 6,
}
## At most two negative status kinds per boss, excluding armour break.
const DEBUFFS := {
	goblin_king = ["dexterity"], mother_mycora = [], captain_saltmourn = ["drunk"],
	mad_farmer = ["drunk"], thornmaw_bloom = ["speed"],
	gilded_vizier = ["dexterity", "quiet"], magma_warden = ["defense", "burning"],
	abyssal_siren = ["quiet", "speed"], queen_briarrose = ["speed", "attack"],
	ixalith = ["defense", "speed"], lantern_shepherd = ["quiet", "speed"],
	jarl_hrimvald = ["static", "speed"], solenne = ["dexterity", "quiet"],
	choirless_seraph = ["quiet", "attack"], oblivara = ["defense", "quiet"],
	blue_dragon = ["defense", "burning"], pyre_ent = ["speed", "burning"],
	vharok = ["defense", "burning"], rimeheart_prism = ["static", "speed"],
	scarab_regent = ["dexterity", "defense"], hollow_crown = ["quiet", "attack"],
	drowned_cantor = ["quiet", "dexterity"], void_empress = ["defense", "quiet"],
	amber_colossus = ["speed", "dexterity"], veil_herald = ["quiet", "dexterity"],
	selenarch = ["quiet", "attack"], brood_matriarch = ["speed", "defense"],
	stormeye_tyrant = ["static", "drunk"], hollow_king = ["attack", "quiet"],
}


static func roll(minimum: int, maximum: int) -> int:
	return roundi(randi_range(minimum, maximum) * ENEMY_DAMAGE_MULTIPLIER)


static func grade(boss_id: String) -> int:
	return int(Loot.BOSS_GRADES.get(boss_id, ENCOUNTER_GRADES.get(boss_id, 6)))


## Magic budgets are raw ranges: the global multiplier makes grade 10 120-130.
static func boss_magic(original: Dictionary, boss_id: String) -> Dictionary:
	var out := original.duplicate()
	var budget := roundi(lerpf(25.0, 100.0, clampf((grade(boss_id) - 3) / 7.0, 0.0, 1.0)))
	out.damage_min = budget
	out.damage_max = budget + 8
	return out


## Run on the authority before replication, after fire metadata is attached.
## Existing heavy hits retain their damage; weak main shots follow the grade floor.
static func boss_attack(original: Dictionary, boss_id: String) -> Dictionary:
	var out := original.duplicate()
	out.burn_duration = 0.0
	var rating := grade(boss_id)
	var magic: bool = out.get("magic", false)
	var damaging := int(out.get("damage_max", 0)) > 0
	var heavy: bool = damaging and (magic or float(out.get("size", 1.0)) >= 1.2 or not out.get("effects", []).is_empty() or int(out.get("damage_min", 0)) >= (90 if rating >= 8 else 110))
	if damaging:
		if magic:
			out = boss_magic(out, boss_id)
		else:
			var floor_damage := 42 + (rating - 3) * 10
			out.damage_min = maxi(int(out.get("damage_min", 0)), floor_damage)
			out.damage_max = maxi(int(out.get("damage_max", 0)), int(out.damage_min) + 8)
	var allowed: Array = DEBUFFS.get(boss_id, [])
	var effects: Array[Dictionary] = []
	for effect: Dictionary in out.get("effects", []):
		var id := StatusEffects.canonical(str(effect.get("id", "")))
		if id != "armour_broken" and not id in allowed: continue
		var entry := effect.duplicate()
		entry.duration = clampf(float(entry.get("duration", 2.0)), 1.5, 3.0) if id != "static" else 1.0
		effects.append(entry)
	if heavy and rating >= 5 and not allowed.is_empty() and effects.is_empty():
		var id: String = allowed[1] if magic and allowed.size() > 1 else allowed[0]
		effects.append({id = id, duration = 1.0 if id == "static" else 2.0, amount = -6 if id in ["speed", "attack", "dexterity", "defense"] else 1})
	if heavy and rating >= 6 and not magic:
		if not effects.any(func(e: Dictionary) -> bool: return e.id == "armour_broken"):
			effects.append({id = "armour_broken", duration = 2.0})
		out.armor_piercing = true
	if not effects.is_empty():
		out.effects = effects
		out.effect_source = out.get("effect_source", boss_id)
	else:
		out.erase("effects")
	if out.get("ripple") is Dictionary: out.ripple = boss_magic(out.ripple, boss_id)
	if out.get("terminal") is Dictionary:
		out.terminal = out.terminal.duplicate()
		out.terminal.attack = boss_attack(out.terminal.attack, boss_id)
	return out


## Bright effect trails distinguish control and armour-breaking shots in flight.
static func effect_look(original: Dictionary) -> Dictionary:
	if original.get("effects", []).is_empty(): return original
	var out := original.duplicate()
	var id: String = str(out.effects[0].id)
	out.color = {"static": Color("9cecff"), "speed": Color("9edb77"), "quiet": Color("bc8cff"),
		"burning": Color("ff883e"), "drunk": Color("f2a3e6"), "attack": Color("d58cff"),
		"dexterity": Color("ffd875"), "defense": Color("ff7989"), "armour_broken": Color("ff7989")}.get(id, Color("ff7989"))
	out.projectile_glow = 1.3
	return out
