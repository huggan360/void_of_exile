class_name BlueDungeonEnemies
## Bluelay's flooded crystal grotto (5.5/10) and sunken bell tower (6.5/10).

static func build(defs: Dictionary) -> void:
	# id, hp, defense, damage, behavior, height, speed, fan count.
	for spec in [
		["grotto_crab", 680, 10, 34, "dart", 1.0, 2.8, 3],
		["tide_wisp", 430, 4, 30, "orbit", 1.7, 3.4, 3],
		["coral_skitter", 560, 7, 32, "dart", 0.9, 3.5, 2],
		["deep_angler", 1600, 12, 48, "skirmish", 2.6, 2.1, 5],
		["reef_guardian", 2100, 18, 52, "chase", 2.9, 1.8, 3],
		["brine_matron", 6200, 21, 60, "stationary", 3.8, 0.0, 7],
		["drowned_acolyte", 760, 8, 40, "skirmish", 2.1, 2.6, 3],
		["spire_eel", 620, 6, 36, "strafe", 1.3, 3.8, 3],
		["bubble_jelly", 540, 4, 34, "orbit", 1.9, 2.8, 4],
		["tide_knight", 2500, 20, 60, "chase", 3.1, 2.0, 5],
		["choir_wraith", 1800, 12, 54, "spirit", 2.7, 2.7, 5],
		["bell_warden", 7800, 24, 68, "stationary", 4.1, 0.0, 9],
	]:
		var d := EnemyDef.new()
		d.id = spec[0]
		d.enemy_name = d.id.replace("_", " ").capitalize()
		d.model = d.id
		d.hp = spec[1]
		d.defense = spec[2]
		d.xp = int(d.hp / 10)
		d.behavior = spec[4]
		d.body_height = spec[5]
		d.move_speed = spec[6]
		d.hit_radius = 0.5 if d.hp < 1000 else 0.85
		d.keep_distance = 6.5
		d.aggro_radius = 16.0
		d.wander_radius = 2.0
		d.spawn_anim = "rise"
		d.dust_color = Color("315c83")
		var tower: bool = d.id in ["drowned_acolyte", "spire_eel", "bubble_jelly", "tide_knight", "choir_wraith", "bell_warden"]
		var tint := Color("94d8ef") if tower else Color("40ddce")
		d.attacks.assign([{style = "orb", color = tint, voxel_model = "boss_projectiles/bell_note" if tower else "boss_projectiles/tide_shard",
			authored_projectile = true, pixel_projectile = true, projectile_glow = 0.8,
			damage_min = spec[3], damage_max = spec[3] + 10, speed = 6.5, range = 16.0,
			pattern = "spread", count = spec[7], spread_deg = 17.0, size = 0.8, radius = 0.18,
			cooldown = 2.8, windup = 0.8, root = true, recover = 0.4}])
		if d.id in ["brine_matron", "bell_warden"]:
			d.attacks.append({style = "orb", color = tint, pattern = "ring", count = 16, speed = 4.0, range = 14.0,
				voxel_model = "boss_projectiles/bell_note" if tower else "boss_projectiles/tide_shard",
				authored_projectile = true, pixel_projectile = true,
				damage_min = spec[3] - 12, damage_max = spec[3], cooldown = 6.5, windup = 1.2})
		d.loot.assign([{item = "elixir_hp", chance = 0.25}, {pool = {tier = 3}, chance = 0.15}, {pool = {tier = 4}, chance = 0.05}])
		defs[d.id] = d
	for spec in [["abyssal_siren", "Abyssal Siren", 34000, 18, 6.5],
		["drowned_cantor", "Drowned Cantor", 43000, 22, 7.2]]:
		var b := RealmBosses._boss(spec[0], spec[1], spec[0], "", spec[0])
		b.wake_on = "near"
		b.hp = spec[2]
		b.defense = spec[3]
		b.body_height = spec[4]
		b.model_scale = 1.0
		b.hit_radius = 1.6
		b.xp = int(b.hp / 10)
		b.intro_time = 5.0
		b.bar_radius = 40.0
		b.abandon_radius = 36.0
		b.dungeon_reward = true
		b.dungeon_potions = ["mp"] # Blue Dragon / Bluelay signature.
		b.burst_color = Color("55e4ef")
		b.phases.assign([{until = 0.68, defense = b.defense}, {until = 0.32, defense = b.defense - 3, variant = "resonant"},
			{until = 0.0, defense = 10, variant = "unbound"}])
		b.loot.assign([{item = "elixir_hp", chance = 1.0}, {item = "elixir_mp", chance = 1.0}, {item = "backpack", chance = 0.03}])
		var ids := Items.divine_ids_for(b.id)
		for i in ids.size():
			var favored: bool = i % 2 == 0 if b.id == "abyssal_siren" else i % 2 == 1
			b.loot.append({item = ids[i], chance = 0.025 if favored else 0.012})
		for relic in [Items.BLUE_DIVINE_IDS[1], Items.BLUE_DIVINE_IDS[3], Items.BLUE_DIVINE_IDS[4]]:
			b.loot.append({item = relic, chance = 0.004})
		defs[b.id] = b
	# Campaign leader has its own identity; retain the authored Blue Genie's rig.
	var keeper: EnemyDef = defs["blue_genie"].duplicate(true)
	keeper.id = "spire_keeper"
	keeper.enemy_name = "The Spire Keeper"
	keeper.hp = 9500
	keeper.defense = 24
	keeper.xp = 950
	keeper.portal_drop = {}
	defs[keeper.id] = keeper
	defs["blue_genie"].portal_drop = {dungeon = "azure_grotto", chance = 0.15}
	defs["azure_medusa"].portal_drop = {dungeon = "drowned_spire", chance = 0.15}
