class_name CourtEnemies
## Desert court, volcanic prison and the burning grove beyond it.

static func build(defs: Dictionary) -> void:
	# id, hp, defense, damage, behavior, height, speed, fan count.
	for spec in [
		["tomb_scarab", 480, 7, 32, "dart", 0.85, 3.1, 1],
		["sand_imp", 380, 4, 30, "skirmish", 1.65, 3.0, 2],
		["dust_wisp", 300, 2, 28, "orbit", 1.4, 3.6, 3],
		["mummy_guard", 1300, 13, 46, "chase", 2.4, 2.0, 3],
		["sun_priest", 1000, 8, 42, "skirmish", 2.3, 2.3, 5],
		["gilded_sentinel", 4200, 18, 55, "stationary", 3.5, 0.0, 7],
		["magma_imp", 560, 6, 36, "skirmish", 1.65, 3.2, 3],
		["ash_crawler", 640, 10, 38, "dart", 0.9, 2.8, 2],
		["ember_bat", 380, 3, 30, "strafe", 1.3, 4.0, 2],
		["lava_golem", 1900, 18, 54, "chase", 2.8, 1.7, 3],
		["cinder_cultist", 1200, 9, 48, "skirmish", 2.3, 2.6, 5],
		["obsidian_brute", 5600, 22, 66, "chase", 3.8, 1.9, 5],
		["cinder_sapling", 900, 8, 45, "stationary", 2.0, 0.0, 5],
		["flame_dryad", 2200, 14, 62, "strafe", 2.8, 2.7, 7],
	]:
		var d := EnemyDef.new()
		d.id = spec[0]
		d.enemy_name = d.id.replace("_", " ").capitalize()
		d.model = d.id
		d.hp = spec[1]
		d.defense = spec[2]
		d.xp = int(spec[1] / 10)
		d.behavior = spec[4]
		d.body_height = spec[5]
		d.move_speed = spec[6]
		d.hit_radius = 0.5 if d.hp < 1000 else 0.8
		d.keep_distance = 6.0
		d.aggro_radius = 15.0
		d.wander_radius = 2.0
		d.spawn_anim = "rise"
		var sand: bool = d.id in ["tomb_scarab", "sand_imp", "dust_wisp", "mummy_guard", "sun_priest", "gilded_sentinel"]
		var tint := Color("e8b84e") if sand else Color("f96524")
		d.dust_color = tint.darkened(0.4)
		d.attacks.assign([{style = "bolt", color = tint, voxel_model = "boss_projectiles/sand_needle" if sand else "boss_projectiles/magma_seed",
			authored_projectile = true, pixel_projectile = true, projectile_glow = 0.8, light_energy = 0.0 if sand else 0.4,
			damage_min = spec[3], damage_max = spec[3] + 10, speed = 7.0, range = 14.0,
			pattern = "spread", count = spec[7], spread_deg = 16.0, size = 0.7, radius = 0.16,
			cooldown = 2.6, windup = 0.7, root = true, recover = 0.4}])
		if d.id in ["gilded_sentinel", "obsidian_brute"]:
			d.attacks.append({style = "orb", color = tint, pattern = "ring", count = 12, speed = 4.5, range = 12.0,
				damage_min = spec[3] - 10, damage_max = spec[3], cooldown = 6.0, windup = 1.1})
		d.loot.assign([{item = "elixir_hp", chance = 0.25}, {pool = {tier = 3}, chance = 0.12}, {pool = {tier = 4}, chance = 0.03}])
		defs[d.id] = d
	for spec in [["gilded_vizier", "Gilded Vizier", 22000, 16, 5.8, ["defense", "hp"]],
		["magma_warden", "Magma Warden", 30000, 20, 6.4, ["attack", "defense"]],
		["pyre_ent", "Pyre Ent", 46000, 22, 9.0, ["attack", "defense"]]]:
		var b := RealmBosses._boss(spec[0], spec[1], spec[0], "", spec[0])
		b.wake_on = "near"
		b.hp = spec[2]
		b.defense = spec[3]
		b.body_height = spec[4]
		b.model_scale = 1.0
		b.hit_radius = 2.2 if b.id == "pyre_ent" else 1.4
		b.xp = int(b.hp / 10)
		b.intro_time = 5.0
		b.bar_radius = 38.0
		b.abandon_radius = 35.0
		b.dungeon_reward = true
		b.dungeon_potions = spec[5]
		b.burst_color = Color("f6cc63") if b.id == "gilded_vizier" else Color("ff802c")
		b.phases.assign([{until = 0.68, defense = b.defense}, {until = 0.33, defense = b.defense - 3, variant = "kindled"},
			{until = 0.0, defense = 8, variant = "unbound"}])
		b.loot.assign([{item = "elixir_hp", chance = 1.0}, {item = "elixir_mp", chance = 1.0}, {item = "backpack", chance = 0.03}])
		var ids := Items.divine_ids_for(b.id)
		for i in ids.size():
			var favored := i < 2 if b.id == "magma_warden" else i >= 2
			var chance := 0.025 if favored else 0.012
			if b.id == "gilded_vizier": chance = 0.018 if i == 1 else 0.025
			b.loot.append({item = ids[i], chance = chance})
		if b.id == "magma_warden": b.follow_up = {dungeon = "cinder_depths_encore", chance = 0.5}
		if b.id == "pyre_ent": b.dungeon_potion_max = 3
		defs[b.id] = b
