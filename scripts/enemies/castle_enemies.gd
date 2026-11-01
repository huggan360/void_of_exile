class_name CastleEnemies
## Final campaign encounter: 8/10, with deliberate tells and safe ring sectors.
static func build(defs: Dictionary) -> void:
	for champion in [false, true]:
		var d := EnemyDef.new()
		d.id = "castle_champion" if champion else "castle_knight"
		d.enemy_name = "Castle Champion" if champion else "Castle Knight"
		d.model = d.id
		d.hp = 6800 if champion else 3600
		d.xp = 0
		d.defense = 24 if champion else 18
		d.body_height = 5.8 if champion else 4.0
		d.model_scale = 0.8 if champion else 0.58
		d.hit_radius = 1.0
		d.behavior = "chase"
		d.move_speed = 3.2 if champion else 2.7
		d.aggro_radius = 70.0
		d.lose_radius = 200.0
		d.lose_time = 9999.0
		d.sheds = false
		d.spawn_anim = "summon"
		d.loot.assign([])
		d.attacks.assign([{style = "crescent", color = Color("b7bbc5"), damage_min = 55 if champion else 35,
			damage_max = 75 if champion else 50, speed = 10.0, range = 28.0 if champion else 5.0,
			cooldown = 2.5, windup = 0.85, recover = 0.55, root = true, pattern = "spread",
			count = 7 if champion else 3, spread_deg = 12.0, radius = 0.22,
			voxel_model = "boss_projectiles/iron_bolt", authored_projectile = true, pixel_projectile = true}])
		defs[d.id] = d
	var b := BossDef.new()
	b.id = "hollow_king"
	b.enemy_name = "The Hollow King"
	b.model = "hollow_king"
	b.actor_script = "res://scripts/enemies/bosses/hollow_king.gd"
	b.wake_on = "hit"
	b.behavior = "stationary"
	b.hp = 72000
	b.hp_per_extra_player = 0.2
	b.support_hp_per_extra_player = 0.2
	b.defense = 28
	b.xp = 7500
	b.model_scale = 0.85
	b.body_height = 8.5
	b.hit_radius = 1.6
	b.aggro_radius = 70.0
	b.lose_radius = 200.0
	b.bar_radius = 65.0
	b.abandon_radius = 75.0
	b.abandon_time = 30.0
	b.intro_time = 9.0
	b.death_time = 5.0
	b.sheds = false
	b.loot_threshold = 0.025
	b.burst_color = Color("e3d9ff")
	b.phases.assign([{until = 0.75, defense = 28}, {until = 0.5, defense = 24},
		{until = 0.25, defense = 22}, {until = 0.0, defense = 16}])
	b.loot.assign([{item = "elixir_hp", chance = 1.0}, {item = "elixir_mp", chance = 1.0},
		{pool = {tier = 7}, chance = 0.55}, {pool = {tier = 8}, chance = 0.3}])
	b.dungeon_reward = true
	b.dungeon_potions = ["attack", "defense", "magic", "hp", "mp"]
	for id in Items.divine_ids_for(b.id): b.loot.append({item = id, chance = 0.04})
	defs[b.id] = b
