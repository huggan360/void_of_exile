class_name Burning
extends RefCounted
## Shared fire metadata. Damage and extinguishing are resolved by the authority.
const MIN_DAMAGE := 10
const MAX_DAMAGE := 15
const CONTACT_DURATION := 3.5
const FIRE_MODELS := ["magma_seed", "pyre_leaf", "burning_branch", "white_ember"]
const FIRE_SOURCES := ["vharok", "vharok_cinder_tyrant", "cinder_oracle", "ember_mite"]

static func projectile(original: Dictionary, source_id := "") -> Dictionary:
	var attack := original.duplicate()
	var model := str(attack.get("voxel_model", "")).get_file()
	var style := str(attack.get("style", ""))
	var fiery := str(attack.get("element", "")) == "fire" or style in ["fireball", "flame_shard"] \
		or model in FIRE_MODELS or model.begins_with("fire_") or source_id in FIRE_SOURCES
	if attack.has("burn_duration"): fiery = float(attack.burn_duration)>0.0
	if fiery and float(attack.get("damage_max", 1))>0.0:
		var size := float(attack.get("size", 1.0))
		var duration := clampf(3.0+floorf(maxf(0.0,size-0.7)*4.0),3.0,6.0)
		if size>=1.6 or float(attack.get("radius",0.0))>=0.35: duration = 10.0
		if source_id in ["vharok", "vharok_cinder_tyrant"] and style in ["crescent", "flame_shard"]: duration = 10.0
		duration = clampf(float(attack.get("burn_duration",duration)),0.0,10.0)
		attack.effects = with_effect(attack.get("effects",[]),duration)
	if attack.get("terminal") is Dictionary and attack.terminal.get("attack") is Dictionary:
		attack.terminal = attack.terminal.duplicate()
		attack.terminal.attack = projectile(attack.terminal.attack,source_id)
	return attack

static func with_effect(original: Array, duration: float) -> Array[Dictionary]:
	var effects := effects_from(original)
	for effect: Dictionary in effects:
		if StatusEffects.canonical(str(effect.get("id",""))) == "burning": return effects
	if duration>0.0: effects.append({id="burning",duration=duration,amount=1})
	return effects

static func effects_from(original: Array) -> Array[Dictionary]:
	var effects: Array[Dictionary] = []
	for effect: Dictionary in original: effects.append(effect.duplicate(true))
	return effects

static func weapon_duration(item: Item, secondary: bool) -> float:
	if item.projectile.has("burn_duration") and float(item.projectile.burn_duration)<=0.0: return 0.0
	if secondary and str(item.charge.get("style","")) == "inferno": return 10.0
	var fiery := str(item.projectile.get("element","")) == "fire" \
		or str(item.projectile.get("style","")) in ["fireball", "flame_shard"] \
		or item.id in ["D_bow_dragon", "D_trident_ofsatan", "D_wand_thewandofsatan"]
	if not fiery: return 0.0
	return clampf(float(item.projectile.get("burn_duration",6.0 if item.is_divine() else 4.0)),3.0,10.0)
