class_name RealmEnemyExpansion
extends RefCounted
## Batch 03: three new gods per stronghold biome, lesser fauna and torch patrols.
const GODS := [
	{id="slag_seraph", title="Slag Seraph", biome=Biomes.DOOM, stats=["attack"], hp=3900, armor=14, speed=3.5, behavior="strafe", pattern="spread", count=5, low=165, high=185, cooldown=2.8, style="fireball"},
	{id="obsidian_ram", title="Obsidian Ram", biome=Biomes.DOOM, stats=["defense"], hp=5200, armor=24, speed=3.5, behavior="chase", pattern="burst", count=2, low=185, high=205, cooldown=2.7, style="bolt"},
	{id="ember_lich", title="Ember Lich", biome=Biomes.DOOM, stats=["magic"], hp=3600, armor=12, speed=3.2, behavior="spirit", pattern="sweep", count=4, low=160, high=180, cooldown=2.9, style="fireball", magic=true},
	{id="aurora_sentinel", title="Aurora Sentinel", biome=Biomes.FOSEN, stats=["magic"], hp=4100, armor=20, speed=2.8, behavior="skirmish", pattern="spread", count=3, low=150, high=170, cooldown=2.4, style="shard"},
	{id="hoarfrost_owl", title="Hoarfrost Owl", biome=Biomes.FOSEN, stats=["dexterity"], hp=3100, armor=10, speed=4.3, behavior="strafe", pattern="sweep", count=3, low=145, high=165, cooldown=2.3, style="shard"},
	{id="icebound_colossus", title="Icebound Colossus", biome=Biomes.FOSEN, stats=["hp"], hp=5400, armor=25, speed=2.1, behavior="chase", pattern="burst", count=2, low=175, high=195, cooldown=2.9, style="comet"},
	{id="prism_ray", title="Prism Ray", biome=Biomes.BLUELAY, stats=["dexterity"], hp=3000, armor=10, speed=4.4, behavior="strafe", pattern="spread", count=3, low=145, high=165, cooldown=2.2, style="shard"},
	{id="runic_archivist", title="Runic Archivist", biome=Biomes.BLUELAY, stats=["magic"], hp=3800, armor=16, speed=2.6, behavior="skirmish", pattern="cross", count=4, low=155, high=175, cooldown=2.5, style="bolt", magic=true},
	{id="azure_medusa", title="Azure Medusa", biome=Biomes.BLUELAY, stats=["mp"], hp=3500, armor=12, speed=2.8, behavior="spirit", pattern="ring", count=8, low=140, high=160, cooldown=3.4, style="orb", magic=true},
	{id="sun_jackal", title="Sun Jackal", biome=Biomes.DESERT, stats=["speed"], hp=2900, armor=10, speed=4.6, behavior="dart", pattern="burst", count=2, low=135, high=155, cooldown=2.2, style="needle"},
	{id="dune_monolith", title="Dune Monolith", biome=Biomes.DESERT, stats=["hp"], hp=4500, armor=24, speed=1.7, behavior="skirmish", pattern="aimed", count=1, low=155, high=175, cooldown=2.6, style="comet"},
	{id="glass_scorpion", title="Glass Scorpion", biome=Biomes.DESERT, stats=["defense"], hp=3700, armor=18, speed=3.4, behavior="skirmish", pattern="spread", count=3, low=145, high=165, cooldown=2.5, style="shard"},
	{id="umbral_reaper", title="Umbral Reaper", biome=Biomes.DEEP_DARK, stats=["speed"], hp=4200, armor=16, speed=3.8, behavior="spirit", pattern="sweep", count=4, low=165, high=185, cooldown=2.8, style="crescent"},
	{id="amethyst_widow", title="Amethyst Widow", biome=Biomes.DEEP_DARK, stats=["defense"], hp=3900, armor=18, speed=4.1, behavior="dart", pattern="burst", count=3, low=155, high=175, cooldown=2.6, style="bolt"},
	{id="nightbell_idol", title="Nightbell Idol", biome=Biomes.DEEP_DARK, stats=["mp"], hp=4400, armor=20, speed=2.1, behavior="skirmish", pattern="ring", count=8, low=150, high=170, cooldown=3.6, style="orb", magic=true},
]
const COMMON := [
	{id="bramble_fox", title="Bramble Fox", hp=240, armor=3, speed=4.0, behavior="dart", damage=24, count=2, cooldown=2.1},
	{id="moss_tortoise", title="Moss Tortoise", hp=460, armor=12, speed=1.8, behavior="skirmish", damage=30, count=3, cooldown=2.6},
	{id="vine_mantis", title="Vine Mantis", hp=380, armor=6, speed=3.8, behavior="dart", damage=32, count=2, cooldown=2.2},
	{id="tide_snail", title="Tide Snail", hp=190, armor=7, speed=1.5, behavior="skirmish", damage=18, count=1, cooldown=2.4},
	{id="dune_crawler", title="Dune Crawler", hp=300, armor=5, speed=3.2, behavior="chase", damage=28, count=1, cooldown=2.0},
	{id="gloam_bat", title="Gloam Bat", hp=150, armor=2, speed=4.4, behavior="strafe", damage=22, count=1, cooldown=2.0},
	{id="bile_bandit", title="Bile Bandit", hp=600, armor=8, speed=3.6, behavior="skirmish", damage=48, count=1, cooldown=2.7},
]

static func build(out: Dictionary, god_loot: Array, lesser_loot: Array) -> void:
	for spec: Dictionary in GODS:
		var e := EnemyDef.new()
		e.id = spec.id
		e.enemy_name = spec.title
		e.model = spec.id
		e.is_god = true
		e.god_potion_stats.assign(spec.stats)
		e.hp = spec.hp
		e.defense = spec.armor
		e.xp = 400 if spec.biome != Biomes.DOOM else 500
		e.body_height = 2.35
		e.hit_radius = .7
		e.behavior = spec.behavior
		e.move_speed = spec.speed
		e.keep_distance = 8
		e.aggro_radius = 15
		e.lose_radius = 26
		e.spawn_anim = "rise" if spec.biome == Biomes.DEEP_DARK else "pop"
		var color := Color("#c370ec") if spec.biome == Biomes.DEEP_DARK else Color("#ff9d4b") if spec.biome == Biomes.DOOM else Color("#a0e5f3") if spec.biome == Biomes.FOSEN else Color("#64dce5") if spec.biome == Biomes.BLUELAY else Color("#f6cf84")
		var attack := {style=spec.style, color=color, pattern=spec.pattern, count=spec.count,
			damage_min=spec.low, damage_max=spec.high, speed=8.5 if spec.biome==Biomes.DOOM else 9.5,
			range=14.0, size=.85, radius=.17, spread_deg=18.0, arc_deg=65.0, interval=.28,
			cooldown=spec.cooldown, windup=.85 if spec.pattern=="ring" else .7, root=true, recover=.55,
			from_hand=true, magic=spec.get("magic",false)}
		if spec.biome == Biomes.DOOM: attack.element = "fire"
		if spec.style != "fireball": attack.voxel_model = e.model+"/projectile"
		else:
			attack.light_energy = .55
			attack.light_range = 3.0
		if spec.id in ["slag_seraph","hoarfrost_owl","prism_ray"]: attack.anim = "flap"
		e.attacks.assign([attack])
		e.loot.assign(god_loot.duplicate(true))
		out[e.id] = e
	for spec: Dictionary in COMMON:
		var e := EnemyDef.new()
		e.id = spec.id
		e.enemy_name = spec.title
		e.model = spec.id
		e.hp = spec.hp
		e.defense = spec.armor
		e.xp = 65 if spec.id=="bile_bandit" else 30
		e.body_height = 1.85 if spec.id=="bile_bandit" else 1.65 if spec.id=="vine_mantis" else 1.15
		e.hit_radius = .4 if spec.id in ["bile_bandit","gloam_bat"] else .6
		e.move_speed = spec.speed
		e.behavior = spec.behavior
		e.keep_distance = 7.0 if spec.id=="bile_bandit" else 5.5
		e.aggro_radius = 16.0 if spec.id=="bile_bandit" else 12.0
		e.lose_radius = 27
		var bandit: bool = spec.id=="bile_bandit"
		e.follows_leader = bandit
		e.carries_torch = bandit
		e.wander_radius = 3 if bandit else 5
		var attack := {style="fireball" if bandit else "bolt", pattern="spread" if spec.count>1 else "aimed",
			count=spec.count, damage_min=spec.damage, damage_max=spec.damage+10, speed=7.5 if bandit else 9.0,
			range=12.5 if bandit else 10.0, size=.65, radius=.13, color=Color("#ffab53") if bandit else Color("#b8d985"),
			spread_deg=16.0, cooldown=spec.cooldown, windup=.65, root=true, recover=.3, from_hand=true}
		if bandit:
			attack.light_energy = 1.3
			attack.light_range = 4.0
		else: attack.voxel_model = e.model+"/projectile"
		e.attacks.assign([attack])
		e.loot.assign(lesser_loot.duplicate(true))
		out[e.id] = e
