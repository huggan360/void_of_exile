class_name SpaceLayout
extends RefCounted
## The Astral Reach: one large space world shared by art, gravity, the server
## and the map. The Nexus station is at the origin in the peaceful Haven;
## the Shardfield (an asteroid wall with crystals) separates it from the
## dark Gloam behind it (+Z). Ship interiors are rooms far below everything.

const NEXUS := Vector3.ZERO
## Station deck: flat gravity inside this cylinder, deck at y = 0.
const STATION_RADIUS := 62.0
const STATION_HALF_HEIGHT := 14.0
## Ships wait at these berths around the station (ship origin, facing outward).
const BERTH_RADIUS := 150.0
const BERTHS := 6
## Region borders along +Z.
const SHARDFIELD_START := 5400.0
const GLOAM_START := 7000.0
const SHARDFIELD := {center = Vector3(0, 0, 6200), extents = Vector3(5200, 900, 650), seed = 6271}
## Walkable ship interiors: one room per ship slot, deck at the slot's y.
const POCKET_ORIGIN := Vector3(0, -4000, 0)
const POCKET_SPACING := 220.0
const POCKET_SLOTS := 24
## The playable sphere; beyond it ships are turned back.
const WORLD_RADIUS := 14000.0

## Planets. `pad` is the unit direction (from the centre) of the landing
## pad; ships land there and the crew steps out onto it. `palette` drives
## the art; `danger` 0..3 sets how hostile it is.
const PLANETS := [
	{id = "verdance", name = "Verdance", region = "haven", center = Vector3(1600, 120, -900), radius = 150.0,
		pad = Vector3(-0.72, 0.3, 0.62), danger = 0, palette = ["3f9d4a", "8fd16a", "2c5d36", "f2d27a", "7fe8c7"],
		about = "Mossy forest world: giant glowing mushrooms, treehouse villages, rope bridges, fireflies."},
	{id = "rosamund", name = "Rosamund", region = "haven", center = Vector3(-1500, -200, 600), radius = 120.0,
		pad = Vector3(0.8, 0.25, -0.55), danger = 0, palette = ["f29ac9", "ffd1e8", "b65a9a", "8de0ff", "fff3b0"],
		about = "Pink crystal meadows, candy-coloured trees, fairy shrines and floating petals."},
	{id = "amberfall", name = "Amberfall", region = "haven", center = Vector3(900, 300, 2500), radius = 170.0,
		pad = Vector3(-0.3, 0.2, -0.93), danger = 1, palette = ["e0a046", "ffd27a", "9a5a22", "5fd18a", "fff0c8"],
		about = "Amber dunes, honey lakes, lantern towers and a sleepy desert market."},
	{id = "tidewell", name = "Tidewell", region = "haven", center = Vector3(-2400, 150, 2900), radius = 200.0,
		pad = Vector3(0.62, 0.3, -0.72), danger = 1, palette = ["2f86c9", "7fd6e8", "e8d6a0", "3f9d6a", "ffffff"],
		about = "Ocean world: an archipelago of small islands, a lighthouse and a fishing village on stilts."},
	{id = "shardheart", name = "Shardheart", region = "shardfield", center = Vector3(1200, 0, 6300), radius = 70.0,
		pad = Vector3(-0.5, 0.4, -0.77), danger = 2, palette = ["6af0c8", "b8fff0", "2a4a5a", "ff8ae0", "1a2030"],
		about = "A hollow crystal planetoid hidden inside the Shardfield, humming and half-alive."},
	{id = "hollowmoon", name = "Hollowmoon", region = "gloam", center = Vector3(-1300, 250, 8600), radius = 140.0,
		pad = Vector3(0.4, 0.3, -0.87), danger = 2, palette = ["8a8f9e", "d8d4c8", "3a3d48", "7dff6a", "1a1a22"],
		about = "A dead grey moon: bone forests, a ruined observatory, cold green ghost-lights."},
	{id = "mawgrave", name = "Mawgrave", region = "gloam", center = Vector3(1800, -300, 9800), radius = 210.0,
		pad = Vector3(-0.55, 0.35, -0.76), danger = 3, palette = ["4a2a5a", "8a4aa0", "1a0f22", "ff5fd2", "7dff6a"],
		about = "Rotting violet fungal planet; the brood's hives swell out of the ground."},
	{id = "pale_eye", name = "The Pale Eye", region = "gloam", center = Vector3(-200, 600, 11200), radius = 260.0,
		pad = Vector3(0.1, 0.3, -0.95), danger = 3, palette = ["c8d0e0", "5a6478", "14161e", "9ab0ff", "ff4a5a"],
		about = "Storm planet with a vast eye-shaped storm; obsidian spires and the end of the map."},
]

static func planet(id: String) -> Dictionary:
	for p: Dictionary in PLANETS:
		if p.id==id: return p
	return {}

static func region_at(position: Vector3) -> String:
	if position.z>=GLOAM_START: return "gloam"
	if position.z>=SHARDFIELD_START: return "shardfield"
	return "haven"

static func region_name(id: String) -> String:
	return {haven = "The Haven", shardfield = "The Shardfield", gloam = "The Gloam"}.get(id, "Deep space")

## The planet whose gravity holds `position` (within 60 m of its surface).
static func planet_near(position: Vector3, margin := 60.0) -> Dictionary:
	for p: Dictionary in PLANETS:
		if position.distance_to(p.center)<float(p.radius)+margin: return p
	return {}

## Ground frame on a planet's pad (origin on the surface, basis.y = up).
static func pad_frame(p: Dictionary) -> Transform3D:
	var up: Vector3 = (p.pad as Vector3).normalized()
	var right := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD))<0.95 else Vector3.RIGHT).normalized()
	return Transform3D(Basis(right, up, right.cross(up)), p.center+up*float(p.radius))

static func berth_frame(index: int) -> Transform3D:
	var angle := TAU*index/BERTHS
	var out := Vector3(sin(angle), 0, cos(angle))
	return Transform3D(Basis.looking_at(out, Vector3.UP), NEXUS+out*BERTH_RADIUS+Vector3.UP*-6.0)

static func pocket_origin(slot: int) -> Vector3:
	return POCKET_ORIGIN+Vector3(slot*POCKET_SPACING, 0, 0)

## Pocket slot of a position inside an interior room, or -1.
static func pocket_at(position: Vector3) -> int:
	if absf(position.y-POCKET_ORIGIN.y)>20.0: return -1
	var slot := roundi((position.x-POCKET_ORIGIN.x)/POCKET_SPACING)
	if slot<0 or slot>=POCKET_SLOTS: return -1
	return slot if absf(position.z)<40.0 and absf(position.x-pocket_origin(slot).x)<40.0 else -1

## Deterministic asteroids of the Shardfield: [position, radius, crystal (bool)].
## The wall has three passes (gaps) the campaigns fly through.
static func asteroids() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = SHARDFIELD.seed
	var out: Array = []
	var c: Vector3 = SHARDFIELD.center
	var e: Vector3 = SHARDFIELD.extents
	var passes := [Vector2(-2600, 120), Vector2(300, -80), Vector2(3100, 200)]
	while out.size()<900:
		var at := c+Vector3(rng.randf_range(-e.x, e.x), rng.randf_range(-e.y, e.y), rng.randf_range(-e.z, e.z))
		var open := false
		for gap: Vector2 in passes:
			if Vector2(at.x-gap.x, at.y-gap.y).length()<170.0: open = true
		if open or at.distance_to(planet("shardheart").center)<160.0: continue
		var radius := rng.randf_range(6.0, 34.0)*(1.8 if rng.randf()<0.06 else 1.0)
		out.append([at, radius, rng.randf()<0.22])
	return out

static func passes() -> Array:
	var c: Vector3 = SHARDFIELD.center
	return [c+Vector3(-2600, 120, 0), c+Vector3(300, -80, 0), c+Vector3(3100, 200, 0)]
