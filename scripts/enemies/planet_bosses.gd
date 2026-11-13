class_name PlanetBosses
## The stronghold bosses of the Astral Reach (SpaceLayout.FORTS), one per
## fortress, tougher further out (the Veiled Herald's shrine on Shardheart is
## built in _herald), and the thralls they call in (planet creatures that drop nothing). Their fights live in scripts/enemies/bosses/.

## id: [name, planet, height m, hp (solo), defense, xp, burst colour, phase variants]
## Four stages each (100-75-50-25-0%); stat elixirs come from Loot.BOSS_POTIONS.
## The Stormeye Tyrant is the Pale One itself, the god behind the King (mission 6).
const BOSSES := {
	queen_briarrose = ["Queen Briarrose", "rosamund", 7.5, 36000, 10, 1600, "ff6eb4", ["bloom", "wilted"]],
	amber_colossus = ["Aurum, the Amber Colossus", "amberfall", 9.0, 52000, 14, 2400, "ffb84a", ["molten", "hive"]],
	selenarch = ["Selenarch, the Moon-Eater", "hollowmoon", 8.0, 68000, 18, 3200, "7dff6a", ["eclipse", "void"]],
	brood_matriarch = ["The Brood Matriarch", "mawgrave", 8.5, 84000, 22, 4000, "ff5fd2", ["swarm", "rot"]],
	stormeye_tyrant = ["Vaelith, the Stormeye Tyrant", "pale_eye", 9.5, 100000, 26, 4800, "9ab0ff", ["tempest", "cataclysm"]],
}
## Planet creatures that come when a boss calls (copies without loot or XP).
const THRALLS := ["petal_sprite", "quartz_hopper", "honey_mite", "amber_scarab", "lantern_ghost", "bone_crawler",
	"spore_drone", "hive_tender", "storm_shard", "eye_watcher"]

static func build(defs: Dictionary) -> void:
	for id: String in THRALLS:
		if not defs.has(id): continue
		var d: EnemyDef = (defs[id] as EnemyDef).duplicate(true)
		d.id = id+"_thrall"
		d.xp = 0
		d.loot.assign([])
		d.is_god = false
		d.aggro_radius = RealmBosses.SUPPORT_AGGRO
		d.lose_radius = 200.0
		d.lose_time = 9999.0
		d.leash = 14.0
		d.spawn_anim = "summon"
		defs[d.id] = d
	for id: String in BOSSES:
		var spec: Array = BOSSES[id]
		var planet := SpaceLayout.planet(str(spec[1]))
		var tiers: Array = SpaceEnemies.TIERS[int(planet.get("danger", 0))].tiers
		var b := RealmBosses._boss(id, spec[0], id, "", id)
		b.wake_on = "near"
		b.aggro_radius = 20.0
		b.lock_gates = true
		b.body_height = float(spec[2])
		b.hit_radius = float(spec[2])*0.24
		b.hp = int(spec[3])
		b.defense = int(spec[4])
		b.xp = int(spec[5])
		b.intro_time = 8.0
		b.bar_radius = 40.0
		b.abandon_radius = 40.0
		b.burst_color = Color(str(spec[6]))
		var variants: Array = spec[7]
		b.phases.assign([{until = 0.75, defense = b.defense}, {until = 0.5, defense = b.defense, variant = variants[0]},
			{until = 0.25, defense = b.defense-4, variant = variants[0]}, {until = 0.0, defense = maxi(4, b.defense-8), variant = variants[1]}])
		b.loot.assign([{item = "elixir_hp", chance = 1.0}, {item = "elixir_mp", chance = 1.0},
			{pool = {tier = tiers[1]}, chance = 0.6}, {pool = {tier = tiers[2]}, chance = 0.3, personal = true},
			{pool = {tier = mini(6, int(tiers[2])+1)}, chance = 0.08, personal = true},
			{item = "backpack", chance = 0.05}])
		defs[id] = b
	defs["veil_herald"] = _herald()
	defs["vaelith_arm"] = _vaelith_arm()

## One of Vaelith's eight squid arms (stage 2): an invisible body where the
## arm lies; the boss draws the arm, moves it and passes its hits on.
static func _vaelith_arm() -> EnemyDef:
	var d := RealmBosses._support("vaelith_arm", "Vaelith's Arm", "storm_shard", 1000000, 26)
	d.behavior = "stationary"
	d.body_height = 2.4
	d.hit_radius = 2.0
	d.sheds = false
	d.spawn_anim = "rise"
	d.dust_color = Color("8c5adc")
	return d

## Mission 6's mini boss (The Eye Behind the Stars), in the Veiled Shrine on
## Shardheart (a stronghold like the others: sealed until its key is turned,
## barred while it fights); 50000 hp plus a share for every extra player.
static func _herald() -> BossDef:
	var b := RealmBosses._boss("veil_herald", "The Veiled Herald", "veil_herald", "", "veil_herald")
	b.wake_on = "near"
	b.lock_gates = true
	b.hp = 50000
	b.defense = 14
	b.xp = 2500
	b.body_height = 7.0
	b.hit_radius = 1.7
	b.aggro_radius = 20.0
	b.bar_radius = 40.0
	b.abandon_radius = 40.0
	b.keep_distance = 9.0
	b.leash = 22.0
	b.intro_time = 7.0
	b.burst_color = Color("96beff")
	b.phases.assign([{until = 0.65, defense = 14}, {until = 0.3, defense = 12, variant = "unveiled"},
		{until = 0.0, defense = 8, variant = "shattered"}])
	b.loot.assign([{item = "elixir_hp", chance = 1.0}, {item = "elixir_mp", chance = 1.0},
		{pool = {tier = 5}, chance = 0.5}, {pool = {tier = 6}, chance = 0.12, personal = true},
		{item = "backpack", chance = 0.04}])
	return b

## A boss projectile with its authored model (creatures/boss_projectiles/<model>).
static func shot(model: String, style: String, color: Color, damage: Vector2i, speed: float, range_m: float,
		size := 1.0, extra := {}) -> Dictionary:
	var a := Boss.shot(style, color, damage, speed, 0.18*size, range_m, {size = size, voxel_model = "boss_projectiles/"+model,
		authored_projectile = true, pixel_projectile = true, projectile_glow = 0.9})
	a.merge(extra, true)
	return a
