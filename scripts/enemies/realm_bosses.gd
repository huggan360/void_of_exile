class_name RealmBosses
## The four stronghold bosses beyond the Blue Dragon, their shells and their
## encounter-only helpers. Their fights live in scripts/enemies/bosses/.
## Helpers never drop loot or XP: they exist for the encounter only.

const SUPPORT_AGGRO := 60.0


static func build(defs: Dictionary) -> void:
	for d in [_tower(), _shardling(), _sentinel(), _pact_mite(), _dawn_scarab(), _mirror_shade(), _thornmaw(),
			_rimeheart(), _vharok(), _scarab(), _hollow_crown()]:
		defs[d.id] = d


## Personal and public rewards shared by the four new bosses (per kill):
## both refill elixirs, G4 30% (public), G5 15% and G6 50% (personal, 90%
## for non-top contributors), backpack 5%, the boss's stat potions, and each
## item of its divine set at 3% on its own.
static func boss_loot(boss_id: String, potions: Dictionary) -> Array:
	var loot: Array = [
		{item = "elixir_hp", chance = 1.0}, {item = "elixir_mp", chance = 1.0},
		{pool = {tier = 4}, chance = 0.30}, {pool = {tier = 5}, chance = 0.15, personal = true},
		{pool = {tier = 6}, chance = 0.50}, {item = "backpack", chance = 0.05},
	]
	for stat in potions:
		loot.append({item = "elixir_of_" + stat, chance = potions[stat]})
	for item_id in Items.divine_ids_for(boss_id):
		loot.append({item = item_id, chance = 0.03})
	return loot


## The Lily Thief's miniboss: a carnivorous bloom in the meadow (no shell:
## it wakes as you come near, with its boss camera).
static func _thornmaw() -> BossDef:
	var b := _boss("thornmaw_bloom", "Thornmaw Bloom", "thornmaw_bloom", "", "thornmaw_bloom")
	b.wake_on = "near"
	b.aggro_radius = 14.0
	b.model_scale = 0.9
	b.body_height = 5.5
	b.hit_radius = 1.6
	b.hp = 6000
	b.defense = 6
	b.xp = 600
	b.intro_time = 6.0
	b.bar_radius = 30.0
	b.abandon_radius = 30.0
	b.burst_color = Color(1.0, 0.55, 0.25)
	b.phases.assign([{until = 0.5, defense = 6}, {until = 0.0, defense = 4}])
	b.loot.assign([{item = "elixir_hp", chance = 1.0}, {pool = {tier = 2}, chance = 0.6}])
	return b


static func _support(id: String, name: String, model: String, hp: int, defense: int) -> EnemyDef:
	var d := EnemyDef.new()
	d.id = id
	d.enemy_name = name
	d.model = model
	d.hp = hp
	d.defense = defense
	d.xp = 0
	d.aggro_radius = SUPPORT_AGGRO
	d.lose_radius = 200.0
	d.lose_time = 9999.0
	d.loot.assign([])
	return d


static func _tower() -> EnemyDef:
	var d := _support("rimeheart_conduit", "Rimeheart Conduit", "rimeheart_conduit", 1200, 10)
	d.behavior = "stationary"
	d.body_height = 3.6
	d.hit_radius = 0.6
	d.sheds = false
	d.spawn_anim = "rise"
	d.dust_color = Color(0.8, 0.9, 1.0)
	return d


static func _shardling() -> EnemyDef:
	var d := _support("rimeheart_shardling", "Rimeheart Shardling", "rimeheart_shardling", 1300, 8)
	d.behavior = "dart"
	d.spawn_anim = "summon"
	d.dust_color = Color(0.7, 0.95, 1.0)
	d.move_speed = 3.0
	d.body_height = 1.5
	d.hit_radius = 0.5
	d.leash = 10.0
	d.attacks.assign([{damage_min = 35, damage_max = 45, style = "shard", color = Color(0.55, 0.9, 1.0),
		size = 0.8, radius = 0.14, speed = 7.0, range = 14.0, cooldown = 2.5, windup = 0.4}])
	return d


static func _sentinel() -> EnemyDef:
	var d := _support("cinder_sentinel", "Cinder Sentinel", "cinder_sentinel", 2000, 14)
	d.spawn_anim = "summon"
	d.dust_color = Color(1.0,0.35,0.08)
	d.behavior = "stationary"
	d.model_scale = 0.9
	d.body_height = 3.0
	d.hit_radius = 0.9
	d.sheds = false
	d.attacks.assign([{damage_min = 45, damage_max = 60, style = "fireball", color = Color(1.0, 0.42, 0.15),
		size = 1.0, radius = 0.2, speed = 7.0, range = 16.0, pattern = "spread", count = 3, spread_deg = 14.0,
		cooldown = 2.8, windup = 0.8}])
	return d


static func _pact_mite() -> EnemyDef:
	var d := _support("pact_ember_mite", "Pact Ember Mite", "ember_mite", 300, 3)
	d.spawn_anim = "summon"
	d.dust_color = Color(1.0,0.5,0.12)
	d.behavior = "chase"
	d.move_speed = 3.5
	d.body_height = 0.8
	d.hit_radius = 0.4
	d.leash = 12.0
	d.attacks.assign([{damage_min = 35, damage_max = 45, style = "fireball", color = Color(1.0, 0.5, 0.15),
		size = 0.6, radius = 0.16, speed = 7.0, range = 4.5, cooldown = 2.0, windup = 0.55, root = true, recover = 0.3}])
	return d


static func _dawn_scarab() -> EnemyDef:
	var d := _support("dawn_scarab", "Dawn Scarab", "dawn_scarab", 1600, 10)
	d.behavior = "skirmish"
	d.spawn_anim = "summon"
	d.dust_color = Color(1.0, 0.8, 0.4)
	d.move_speed = 2.5
	d.keep_distance = 7.0
	d.model_scale = 1.4
	d.body_height = 0.9
	d.hit_radius = 0.45
	d.leash = 11.0
	d.attacks.assign([{damage_min = 40, damage_max = 50, style = "needle", color = Color(1.0, 0.86, 0.45),
		size = 0.8, radius = 0.12, speed = 9.0, range = 15.0, cooldown = 2.4, windup = 0.6}])
	return d


static func _mirror_shade() -> EnemyDef:
	var d := _support("mirror_shade", "Mirror Shade", "mirror_shade", 1800, 10)
	d.behavior = "stationary"
	d.spawn_anim = "summon"
	d.dust_color = Color(0.7, 0.3, 0.95)
	d.model_scale = 0.75
	d.body_height = 4.4
	d.hit_radius = 0.7
	d.sheds = false
	d.attacks.assign([{damage_min = 40, damage_max = 55, style = "bolt", color = Color(0.72, 0.36, 0.9),
		size = 0.9, radius = 0.15, speed = 6.5, range = 16.0, pattern = "spread", count = 2, spread_deg = 10.0,
		cooldown = 2.8, windup = 0.5}])
	return d


static func _boss(id: String, name: String, model: String, shell: String, actor: String) -> BossDef:
	var b := BossDef.new()
	b.id = id
	b.enemy_name = name
	b.model = model
	b.wake_on = "shell"
	b.shell_model = shell
	b.actor_script = "res://scripts/enemies/bosses/%s.gd" % actor
	b.behavior = "stationary"
	b.aggro_radius = 30.0
	b.lose_radius = 200.0
	b.lose_time = 9999.0
	b.wander_radius = 0.0
	b.sheds = false
	b.loot_threshold = 0.04
	return b


static func _rimeheart() -> BossDef:
	var b := _boss("rimeheart_prism", "Rimeheart Prism", "rimeheart_prism", "egg_rimeheart", "rimeheart_prism")
	b.model_scale = 0.72
	b.body_height = 7.0
	b.hit_radius = 1.9
	b.hp = 44000
	b.defense = 24
	b.xp = 4500
	b.shell_hp = 1500
	b.intro_time = 10.0
	b.shell_height = 2.8
	b.shell_radius = 2.0
	b.burst_color = Color(0.5, 0.9, 1.0)
	b.phases.assign([
		{until = 0.7, defense = 24},
		{until = 0.35, defense = 26, variant = "conduit"},
		{until = 0.0, defense = 8, variant = "tempest"},
	])
	b.loot.assign(boss_loot(b.id, {attack = 0.15, defense = 0.15, speed = 0.15, dexterity = 0.75,
			magic = 0.75, hp = 0.15, mp = 0.15}))
	return b


static func _vharok() -> BossDef:
	var b := _boss("vharok", "Vharok, the Cinder Tyrant", "vharok_cinder_tyrant", "egg_vharok", "vharok")
	b.model_scale = 0.68
	b.body_height = 9.0
	b.hit_radius = 1.8
	b.hp = 48000
	b.defense = 24
	b.xp = 5000
	b.shell_hp = 2200
	b.intro_time = 10.0
	b.lock_gates = true
	b.shell_scale = 0.85
	b.shell_height = 5.0
	b.shell_radius = 1.6
	b.burst_color = Color(1.0, 0.5, 0.25)
	b.phases.assign([
		{until = 0.65, defense = 24},
		{until = 0.3, defense = 24, variant = "infernal"},
		{until = 0.0, defense = 8, variant = "heart_unbound"},
	])
	b.loot.assign(boss_loot(b.id, {attack = 0.75, defense = 0.75, speed = 0.15, dexterity = 0.15,
			magic = 0.15, hp = 0.15, mp = 0.15}))
	return b


static func _scarab() -> BossDef:
	var b := _boss("scarab_regent", "Aureate Scarab Regent", "aureate_scarab_regent", "egg_scarab", "scarab_regent")
	b.model_scale = 0.68
	b.body_height = 7.5
	b.hit_radius = 2.4
	b.hp = 42000
	b.defense = 28
	b.xp = 4500
	b.shell_hp = 1800
	b.intro_time = 10.0
	b.lock_gates = true
	b.shell_height = 3.6
	b.shell_radius = 2.0
	b.burst_color = Color(1.0, 0.85, 0.55)
	b.phases.assign([
		{until = 0.7, defense = 28},
		{until = 0.35, defense = 20, variant = "sunwings"},
		{until = 0.0, defense = 15, variant = "sunheart"},
	])
	b.loot.assign(boss_loot(b.id, {attack = 0.15, defense = 0.75, speed = 0.25, dexterity = 0.15,
			magic = 0.15, hp = 0.35, mp = 0.15}))
	return b


static func _hollow_crown() -> BossDef:
	var b := _boss("hollow_crown", "The Hollow Crown", "hollow_crown", "egg_hollow_crown", "hollow_crown")
	b.model_scale = 0.68
	b.body_height = 8.0
	b.hit_radius = 1.7
	b.hp = 46000
	b.defense = 18
	b.xp = 4800
	b.shell_hp = 1600
	b.intro_time = 10.0
	b.lock_gates = true
	b.shell_height = 5.6
	b.shell_radius = 1.4
	b.burst_color = Color(0.9, 0.4, 1.0)
	b.phases.assign([
		{until = 0.72, defense = 18},
		{until = 0.35, defense = 16, variant = "fractured_court"},
		{until = 0.0, defense = 6, variant = "unbound"},
	])
	b.loot.assign(boss_loot(b.id, {attack = 0.15, defense = 0.15, speed = 0.5, dexterity = 0.15,
			magic = 0.25, hp = 0.15, mp = 0.75}))
	return b
