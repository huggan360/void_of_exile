class_name BossDef
extends EnemyDef
## A boss: an enemy with a big health pool, an intro and phases (see Boss).
##
## Each phase is a Dictionary:
##   until            share of health where the next phase starts (0.7 =
##                    at 70%); the last phase has 0
##   defense, behavior, move_speed   how it fights in this phase
##   attacks          attacks on their own timers (like any enemy), or
##   sequence         a script it repeats: [{attack = {...}}, {wait = s}, ...]
##   summon           {enemies = [ids], radius, orbit (bool)}: minions that
##                    appear when the phase starts (orbiters circle the boss)
##   shielded         it can't be hurt while its summons live
##   attacks_shielded what it does while shielded ([] = it waits)
##   after            {behavior, move_speed, attacks}: once the summons die
##   variant          the model's look for this phase (CreatureModel variants)
##
## Health: hp is for one player. Every other player close by when the fight
## starts adds hp_per_extra_player of it (people who join later don't).

## Players near it can wake it ("near"), only shooting it does ("hit"), or it
## sleeps inside a shell that must be broken first ("shell", see shell_model).
@export var wake_on := "near"
## Seconds between waking and the fight starting (its bar fills up).
@export var intro_time := 10.0
## Close the fortress portcullises while this encounter is running.
@export var lock_gates := false
@export var hp_per_extra_player := 0.2
## Its health bar shows for players this close; they count for its health,
## and share its XP when it dies.
@export var bar_radius := 45.0
@export var phases: Array[Dictionary] = []
## How long it glows before bursting apart at the end.
@export var death_time := 3.0

@export_group("Encounter")
## Script with the boss's own fight (extends Boss); "" uses the phase list.
@export var actor_script := ""
## Dormant look: a creature folder whose variants crack1..crack3 show damage.
@export var shell_model := ""
@export var shell_scale := 1.0
## Shell health for one player (defense 0); scaled like boss health.
@export var shell_hp := 0
## Height/radius of the dormant shell's hit box.
@export var shell_height := 4.0
@export var shell_radius := 2.0
## Objectives and guards get this much more health per extra player.
@export var support_hp_per_extra_player := 0.35
## No living player this close for abandon_time: the attempt resets to its shell.
@export var abandon_radius := 28.0
@export var abandon_time := 15.0
## Light and voxel colors of its hatch and death bursts.
@export var burst_color := Color(0.7, 0.85, 1.0)

## Optional portal to the next encounter, rolled by the dungeon server.
@export var follow_up := {}
