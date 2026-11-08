class_name PlanetBosses
## The five stronghold bosses of the Astral Reach (SpaceLayout.FORTS), one per
## fortress, tougher further out, and the thralls they call in (planet
## creatures that drop nothing). Their fights live in scripts/enemies/bosses/.

## id: [name, planet, height m, hp, defense, xp, burst colour, phase variants, stat potion]
const BOSSES := {
	queen_briarrose = ["Queen Briarrose", "rosamund", 7.5, 16000, 10, 1600, "ff6eb4", ["bloom", "wilted"], "magic"],
	amber_colossus = ["Aurum, the Amber Colossus", "amberfall", 9.0, 24000, 14, 2400, "ffb84a", ["molten", "hive"], "defense"],
	selenarch = ["Selenarch, the Moon-Eater", "hollowmoon", 8.0, 32000, 18, 3200, "7dff6a", ["eclipse", "void"], "speed"],
	brood_matriarch = ["The Brood Matriarch", "mawgrave", 8.5, 40000, 22, 4000, "ff5fd2", ["swarm", "rot"], "hp"],
	stormeye_tyrant = ["The Stormeye Tyrant", "pale_eye", 9.5, 48000, 26, 4800, "9ab0ff", ["tempest", "cataclysm"], "attack"],
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
		b.phases.assign([{until = 0.65, defense = b.defense}, {until = 0.3, defense = b.defense, variant = variants[0]},
			{until = 0.0, defense = maxi(4, b.defense-8), variant = variants[1]}])
		b.loot.assign([{item = "elixir_hp", chance = 1.0}, {item = "elixir_mp", chance = 1.0},
			{pool = {tier = tiers[1]}, chance = 0.6}, {pool = {tier = tiers[2]}, chance = 0.3, personal = true},
			{pool = {tier = mini(6, int(tiers[2])+1)}, chance = 0.08, personal = true},
			{item = "elixir_of_"+str(spec[8]), chance = 0.6}, {item = "backpack", chance = 0.05}])
		defs[id] = b

## A boss projectile with its authored model (creatures/boss_projectiles/<model>).
static func shot(model: String, style: String, color: Color, damage: Vector2i, speed: float, range_m: float,
		size := 1.0, extra := {}) -> Dictionary:
	var a := Boss.shot(style, color, damage, speed, 0.18*size, range_m, {size = size, voxel_model = "boss_projectiles/"+model,
		authored_projectile = true, pixel_projectile = true, projectile_glow = 0.9})
	a.merge(extra, true)
	return a
