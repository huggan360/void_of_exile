class_name SurfaceBoss
extends Boss
## The Surface dungeons' bosses (docs/dungeons/SURFACE_DUNGEONS.md) share the
## glow framework (GlowRipples): every new stage sends rings of light from the
## middle of the room out over its walls, their big attacks pulse the walls,
## and when they fall the whole dungeon lights up and stays lit.

## The boss's own light: the walls ripple in it.
var glow_color := Color.WHITE
var glow_alt := Color.WHITE


## The boss room's radius (its clear core), for rings that reach its walls.
func room_radius() -> float:
	var world := director.world as DungeonWorld
	if world and world.layout.rooms.size() > 1:
		return float(world.layout.rooms[1].radius)
	return 16.0


## A ring of light from the room's middle over its walls.
func glow_wave(color := glow_color, opts := {}) -> void:
	var o := {speed = 10.0, width = 2.4, range = room_radius() + 10.0, strength = 2.2, flat = true}
	o.merge(opts, true)
	GlowRipples.emit(self, encounter_center, color, o)


## A small burst of light from a point (an impact, a lantern raised).
func glow_burst(at: Vector3, color := glow_color, opts := {}) -> void:
	var o := {speed = 7.0, width = 1.4, range = 9.0, strength = 1.8}
	o.merge(opts, true)
	GlowRipples.emit(self, at, color, o)


func _enter_phase(index: int) -> void:
	super._enter_phase(index)
	if index > 0:
		glow_wave(glow_color, {rings = 3, gap = 0.45})
		glow_wave(glow_alt, {delay = 0.25, rings = 2, gap = 0.6})


func _threshold_reached(next: int) -> void:
	if not resting: begin_rest(func() -> void: _enter_phase(next), _rest_line(next))


## What the boss bar says while it gathers itself for stage `next`.
func _rest_line(_next: int) -> String:
	return "It gathers itself"


func _death_started() -> void:
	model.boss_pose("death", boss_def.death_time + 1.0)
	# The dungeon remembers it can shine: everything lights up and stays lit.
	glow_wave(glow_color, {rings = 4, gap = 0.35, strength = 3.0, range = room_radius() + 60.0, speed = 14.0})
	GlowRipples.flood(self, 1.0, 3.5)


func _dying_update(_k: float) -> void:
	model.scale = Vector3.ONE * def.model_scale


func _reset_hook() -> void:
	model.boss_pose("idle", 0.1)
	GlowRipples.flood(self, 0.0, 1.0)


## A shot of one of the boss's authored projectiles.
func bolt(model_id: String, color: Color, damage: Vector2i, speed: float, extra := {}) -> Dictionary:
	var a := Boss.shot("orb", color, damage, speed, 0.2, 26.0,
		{voxel_model = "boss_projectiles/" + model_id, authored_projectile = true, pixel_projectile = true,
			projectile_glow = 1.0, size = 0.95})
	a.merge(extra, true)
	return a


## The players' positions, at most `count`, snapped to the floor.
func targets(count := 4) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for player in players():
		if out.size() >= count: break
		out.append(player.global_position)
	return out


## A direction a little away from the player's, for a safe gap.
func gap_angle() -> float:
	var d := aim_dir()
	return atan2(-d.x, -d.z)
