class_name EnemyDef
extends Resource
## Everything that makes an enemy type: its look, toughness, how it moves and
## how it attacks. Enemies are built from these (see Enemies for the list),
## so adding a new monster is mostly filling one of these in.

@export var id := ""
@export var enemy_name := ""
## Folder in creatures/ (made by tools/make_creatures.py).
@export var model := ""
@export var model_scale := 1.0
## Gods are finite realm encounters; their loot is capped separately from bosses.
@export var is_god := false
## Optional fixed potion signature; older gods use their origin biome.
@export var god_potion_stats: Array[String] = []
## Real torch attached to the authored hand (bandit patrols).
@export var carries_torch := false
## Size of its hit box (before model_scale): height and radius in meters.
## Wide creatures (scorpions) need a bigger radius so arrows hit their sides.
@export var body_height := 1.5
@export var hit_radius := 0.4

@export_group("Toughness")
@export var hp := 50
## Subtracted from each hit (at least 15% always gets through).
@export var defense := 0
@export var xp := 10

@export_group("Movement")
## "skirmish": keeps its distance and circles you while shooting.
## "spirit": like skirmish but darting hard from side to side.
## "strafe": sweeps from side to side in front of you.
## "orbit": circles its pack leader (orbit_radius, orbit_speed).
## "chase": runs straight at you.  "dart": quick random dashes.
## "stationary": doesn't move at all (turrets, totems...).
@export var behavior := "skirmish"
@export var move_speed := 4.0
## Preferred distance to the player while fighting (skirmish).
@export var keep_distance := 6.0
## How far it strolls from its pack (or leader) while idle.
@export var wander_radius := 5.0
## Stays close to its pack's leader, if it has one.
@export var follows_leader := false
@export var orbit_radius := 3.0
@export var orbit_speed := 1.2  # radians per second
## Never strays further than this from where it spawned (0 = no limit).
@export var leash := 0.0
## Blinks sideways now and then: {every = [min s, max s], distance = m}.
@export var blink := {}

@export_group("Awareness")
## Notices the player within this distance (and alerts its whole pack).
@export var aggro_radius := 14.0
## Loses the player after they've been further than this for `lose_time`.
@export var lose_radius := 22.0
@export var lose_time := 1.5

@export_group("Attacks")
## Each attack: {damage_min, damage_max, armor_piercing, pierce_players,
## style ("pellet", "bolt", "orb"), color, size, speed, range,
## pattern ("aimed", "spread", "ring"), count, spread_deg, cooldown, windup}.
## Projectiles from different attacks fire on their own timers.
## Optional:
##   root = true      stands still while winding up and for `recover` seconds
##                    after firing (walk, stop, shoot, walk...)
##   from_hand = true  leaves from the hand's real height (a scorpion's
##                    stinger) and drops to shot height as it flies
##   magic = true     magic shot: wrapped in warped space, fully blocked by
##                    the warp shield
##   ripple = {radius, speed, damage_min, damage_max}: where a magic shot
##                    lands it sends out a small warp ripple that hits
##                    players it passes (see EnemyRipple)
##   anim = "flap"    beats its wings as it attacks
## More patterns: "cross" (two shots to the sides, two forward),
## "burst" (count shots, `interval` apart, each aimed), "sweep" (count shots
## fanned across arc_deg from one side to the other, `interval` apart: a
## line of fire), "shockwave" (an EnemyRipple from itself: `ripple`).
@export var attacks: Array[Dictionary] = []

## Bits of its shell fly off as it's worn down (off for huge creatures).
@export var sheds := true

@export_group("Loot")
## What it can drop (see Loot): {item = "elixir_hp", chance = 0.4} or
## {pool = {tier = 2, slots = ["weapon", "armor"]}, chance = 0.1};
## chance 1.0 = always. Elixirs and G1-G4 drop in public bags; better items
## in personal bags, rolled for each player who did enough damage.
@export var loot: Array[Dictionary] = []
## Share of its health a player must deal to roll for personal loot.
@export var loot_threshold := 0.1
## Optional server-side portal roll.
@export var portal_drop := {}
@export var dungeon_reward := false
## Eligible dungeon rewards: realm potion stats and optional lucky extra potions.
@export var dungeon_potions := ["speed", "dexterity"]
@export var dungeon_potion_max := 1

@export_group("Spawning")
## "pop": jumps into existence in a puff.  "rise": climbs up out of the
## ground (for dark places and dungeons).  "burrow": waits hidden under the
## ground (a little dust now and then gives it away) and bursts out when a
## player comes within aggro_radius.
@export var spawn_anim := "pop"
## Color of the dirt/sand kicked up when it rises or bursts out.
@export var dust_color := Color(0.35, 0.26, 0.18)
