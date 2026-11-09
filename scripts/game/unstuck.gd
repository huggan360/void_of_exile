class_name Unstuck
extends RefCounted
## The game menu's Unstuck: the nearest free spot around the player where the
## whole body fits on walkable, level ground. The spot it stands on now is
## skipped (that is where it got stuck). The server allows the same hop
## (NetServer, "unstuck") once per COOLDOWN.

const MIN_DISTANCE := 1.5
const MAX_DISTANCE := 16.0
const RING_STEP := 1.0
const CLIMB := 2.5  # look for ground up to this far above the feet...
const DROP := 6.0   # ...and this far below
const COOLDOWN := 5.0

## Where a player who just arrived should stand instead, when their body is
## inside something (ground, a wall, a prop): the nearest free spot, or if
## there is none, straight up until clear (they then fall onto what is
## below). Vector3.INF when they already stand free.
static func spawn_spot(player: Player, world: GameWorld) -> Vector3:
	if not blocked(player, player.global_position): return Vector3.INF
	var spot := find_spot(player, world)
	if spot.is_finite(): return spot
	var up := player.global_basis.orthonormalized().y
	for height: float in [1.0, 2.0, 3.0, 4.5, 6.0, 8.0, 11.0]:
		var at := player.global_position+up*height
		if not blocked(player, at): return at
	return Vector3.INF

## Whether the player's body would overlap something standing at `at` (feet).
## Lifted a little, so resting on the ground does not count.
static func blocked(player: Player, at: Vector3) -> bool:
	var basis := player.global_basis.orthonormalized()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.36
	shape.height = 1.6
	var body := PhysicsShapeQueryParameters3D.new()
	body.shape = shape
	body.collision_mask = Player.TERRAIN_LAYER | Player.OBSTACLE_LAYER
	body.exclude = [player.get_rid()]
	body.transform = Transform3D(basis, at+basis.y*(shape.height*0.5+0.25))
	return not player.get_world_3d().direct_space_state.intersect_shape(body, 1).is_empty()

## A free spot near the player (local up = the player's up), or Vector3.INF.
## `world` may be null (the player's own walkable check is used then).
static func find_spot(player: Player, world: GameWorld) -> Vector3:
	var space := player.get_world_3d().direct_space_state
	var basis := player.global_basis.orthonormalized()
	var up := basis.y
	var from := player.global_position
	var shape := CapsuleShape3D.new()
	shape.radius = 0.45
	shape.height = 1.9
	var body := PhysicsShapeQueryParameters3D.new()
	body.shape = shape
	body.collision_mask = Player.TERRAIN_LAYER | Player.OBSTACLE_LAYER
	body.exclude = [player.get_rid()]
	var distance := MIN_DISTANCE
	while distance<=MAX_DISTANCE:
		var count := maxi(8, ceili(TAU*distance/1.2))
		for i in count:
			var angle := TAU*i/count+distance  # rings start at different angles
			var at := from+basis*Vector3(cos(angle), 0, sin(angle))*distance
			var ray := PhysicsRayQueryParameters3D.create(at+up*CLIMB, at-up*DROP, body.collision_mask)
			ray.exclude = body.exclude
			var hit := space.intersect_ray(ray)
			if hit.is_empty() or (hit.normal as Vector3).dot(up)<0.7: continue
			var spot: Vector3 = (hit.position as Vector3)+up*0.05
			if world!=null and (not world.is_walkable(spot) or world.is_hazard(spot)): continue
			if world==null and player.walkable.is_valid() and not player.walkable.call(spot): continue
			body.transform = Transform3D(basis, spot+up*(shape.height*0.5+0.1))
			if space.intersect_shape(body, 1).is_empty(): return spot
		distance += RING_STEP
	return Vector3.INF
