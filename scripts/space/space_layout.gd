class_name SpaceLayout
extends RefCounted
## The Astral Reach: one large round space world shared by art, gravity, the
## server and the map. The Nexus station is at the origin in the peaceful
## Haven; the Shardfield (an asteroid wall with crystals) separates it from
## the dark Gloam behind it (+Z). Ship interiors are rooms far below everything.
## Planets are whole worlds: `surface_height` is their deterministic terrain,
## used by the server (gravity, hull collisions) and the art (terrain meshes).

const NEXUS := Vector3.ZERO
## Station deck: flat gravity inside this cylinder, deck at y = 0.
const STATION_RADIUS := 62.0
const STATION_HALF_HEIGHT := 14.0
## Ships wait at these berths around the station (ship origin, facing outward).
const BERTH_RADIUS := 170.0
const BERTHS := 6
## Region borders along +Z.
const SHARDFIELD_START := 16200.0
const GLOAM_START := 21000.0
const SHARDFIELD := {center = Vector3(0, 0, 18600), extents = Vector3(20000, 2600, 2000), seed = 6271}
## Walkable ship interiors: one room per ship slot, deck at the slot's y.
const POCKET_ORIGIN := Vector3(0, -60000, 0)
const POCKET_SPACING := 220.0
const POCKET_SLOTS := 24
## The playable sphere. Inside BOUNDARY_WARN of its edge ships are steered
## back toward the Nexus; the red barrier is drawn on the sphere itself.
const WORLD_RADIUS := 42000.0
## The Reach's burning sun, out toward the light (SpaceBackdrop.SUN_DIR).
const SUN_CENTER := Vector3(-16900, 11500, -29800)
const SUN_RADIUS := 3000.0
## Ships closer than this to the sun's surface start to burn.
const SUN_BURN := 1600.0
const BOUNDARY_WARN := 2500.0

## Planets. `pad` is the unit direction (from the centre) of the landing pad;
## ships land there and the crew steps out onto it. `palette` drives the art
## (earth, bright, shade, magic, accent, sky); `danger` 0..3 sets how hostile
## it is. `terrain` shapes the ground: style, height (m), feature size (m).
const PLANETS := [
	{id = "verdance", name = "Verdance", region = "haven", center = Vector3(4200, 400, -3200), radius = 650.0,
		pad = Vector3.UP, danger = 0, palette = ["3f9d4a", "8fd16a", "2c5d36", "f2d27a", "7fe8c7", "8fe0c0"],
		terrain = {style = "hills", height = 46.0, size = 260.0},
		about = "Mossy forest world: giant glowing mushrooms, treehouse villages, rope bridges, fireflies."},
	{id = "rosamund", name = "Rosamund", region = "haven", center = Vector3(-4600, -700, 2200), radius = 520.0,
		pad = Vector3.UP, danger = 0, palette = ["e07fb5", "ffc6e2", "8a3f78", "8de0ff", "fff3b0", "ffb8de"],
		terrain = {style = "terraces", height = 38.0, size = 210.0},
		about = "Pink crystal meadows, candy-coloured trees, fairy shrines and floating petals."},
	{id = "amberfall", name = "Amberfall", region = "haven", center = Vector3(2800, 900, 7400), radius = 760.0,
		pad = Vector3.UP, danger = 1, palette = ["b07a34", "d9a85a", "6a3e18", "5fd18a", "fff0c8", "ffc27a"],
		terrain = {style = "dunes", height = 42.0, size = 170.0},
		about = "Amber dunes, honey lakes, lantern towers and a sleepy desert market."},
	{id = "tidewell", name = "Tidewell", region = "haven", center = Vector3(-7400, 500, 8600), radius = 900.0,
		pad = Vector3.UP, danger = 1, palette = ["2f86c9", "7fd6e8", "e8d6a0", "3f9d6a", "ffffff", "8ad2ff"],
		terrain = {style = "islands", height = 34.0, size = 240.0, sea = true},
		about = "Ocean world: an archipelago of small islands, a lighthouse and a fishing village on stilts."},
	{id = "shardheart", name = "Shardheart", region = "shardfield", center = Vector3(3600, 0, 18800), radius = 300.0,
		pad = Vector3.UP, danger = 2, palette = ["3a8a7a", "8af0d8", "1a2a34", "ff8ae0", "1a2030", "6af0c8"],
		terrain = {style = "crystal", height = 30.0, size = 90.0},
		about = "A hollow crystal planetoid hidden inside the Shardfield, humming and half-alive."},
	{id = "hollowmoon", name = "Hollowmoon", region = "gloam", center = Vector3(-4200, 800, 26000), radius = 640.0,
		pad = Vector3.UP, danger = 2, palette = ["7d818e", "b8b4a8", "3a3d48", "7dff6a", "1a1a22", "4a5a52"],
		terrain = {style = "craters", height = 44.0, size = 150.0},
		about = "A dead grey moon: bone forests, a ruined observatory, cold green ghost-lights."},
	{id = "mawgrave", name = "Mawgrave", region = "gloam", center = Vector3(5600, -900, 30500), radius = 950.0,
		pad = Vector3.UP, danger = 3, palette = ["4a2a5a", "8a4aa0", "1a0f22", "ff5fd2", "7dff6a", "6a3a7a"],
		terrain = {style = "fungal", height = 46.0, size = 260.0},
		about = "Rotting violet fungal planet; the brood's hives swell out of the ground."},
	{id = "pale_eye", name = "The Pale Eye", region = "gloam", center = Vector3(-600, 1800, 35500), radius = 1300.0,
		pad = Vector3.UP, danger = 3, palette = ["4a5266", "a8b0c4", "14161e", "9ab0ff", "ff4a5a", "8090b8"],
		terrain = {style = "spires", height = 110.0, size = 230.0},
		about = "Storm planet with a vast eye-shaped storm; obsidian spires and the end of the map."},
	{id = "vesperis", name = "Vesperis", region = "haven", center = Vector3(-2400, 700, -6600), radius = 1000.0,
		pad = Vector3.UP, danger = 0, palette = ["2c2638", "ffb86a", "1a1626", "ff6eb4", "6af0e0", "594362"],
		terrain = {style = "city", height = 0.0, size = 200.0}, city = true,
		about = "The Lantern City: one city around the whole world, at eternal dusk. Three spaceports, peaceful."},
]

## Named story places on each planet (campaign search spots and npcs), as
## offsets in metres from the pad along its right and forward axes.
const PLACES := {
	"verdance": ["treehouse_village", "mushroom_grove", "firefly_shrine", "elder_tree"],
	"rosamund": ["petal_shrine", "rose_crystal_garden", "fairy_court", "wishing_stones"],
	"amberfall": ["sleepy_market", "lantern_tower", "honey_well", "dune_caravan"],
	"tidewell": ["stilt_village", "lighthouse", "fishing_jetty", "shell_shrine"],
	"shardheart": ["singing_spires", "heart_shrine", "resonance_circle", "crystal_nest"],
	"hollowmoon": ["observatory_ruin", "bone_forest", "ghost_lanterns", "fallen_astrolabe"],
	"mawgrave": ["brood_hive", "spore_garden", "fungal_altar", "hollow_nest"],
	"pale_eye": ["obsidian_crown", "storm_observatory", "eye_shrine", "last_beacon"],
	"vesperis": [],
}
const PLACE_OFFSETS: Array[Vector2] = [Vector2(-46, -36), Vector2(56, -34), Vector2(-60, 62), Vector2(50, 92)]
## Each planet's town (offsets from the pad like the places): its plaza, the
## smith and the shipwright by a small shipyard pad where bought ships wait.
## `style` village uses the realm's voxel houses, the others are alien and
## built from the realm's voxel obstacles.
const TOWNS := {
	verdance = {name = "Mossbrook", style = "village", houses = ["res://props/houses/woodland_0", "res://props/houses/woodland_1", "res://props/houses/woodland_2", "res://props/home/rose_cottage", "res://props/home/blue_bakery", "res://props/home/tall_townhouse"],
		folk = ["npc_villager", "npc_gardener", "npc_baker", "moss_tortoise"], smith = "npc_smith", wright = "npc_traveler"},
	rosamund = {name = "Petalgate", style = "village", houses = ["res://props/home/rose_cottage", "res://props/home/chapel", "res://props/home/magicians_house", "res://props/home/blossom_tree", "res://props/home/rose_cottage", "res://props/home/garden_bed"],
		folk = ["npc_magician", "spirit_purple", "npc_villager", "spirit_spark"], smith = "npc_smith", wright = "npc_magician"},
	amberfall = {name = "Honeymarket", style = "village", houses = ["res://props/houses/desert_0", "res://props/houses/desert_1", "res://props/houses/desert_2", "res://props/houses/desert_0", "res://props/town/market", "res://props/town/market"],
		folk = ["npc_traveler", "sun_priest", "genie_brown", "npc_baker"], smith = "npc_smith", wright = "genie_brown"},
	tidewell = {name = "Saltstilts", style = "village", houses = ["res://props/houses/fosen_0", "res://props/houses/fosen_1", "res://props/houses/fosen_2", "res://props/houses/fosen_1", "res://props/town/well", "res://props/home/broad_lodge"],
		folk = ["npc_villager", "tide_snail", "crab", "npc_traveler"], smith = "npc_smith", wright = "npc_traveler"},
	shardheart = {name = "Lumen Spire", style = "crystal", houses = ["crystal_cluster", "ice_spike", "crystal_cluster", "obelisk"],
		folk = ["genie_blue", "spirit_blue", "runic_archivist", "prism_ray"], smith = "runic_archivist", wright = "genie_blue"},
	hollowmoon = {name = "Ashveil", style = "ruins", houses = ["ruin_house", "ruin_wall", "ruin_house", "obelisk"],
		folk = ["spirit_brown", "glacier_hermit", "spirit_blue", "nightbell_idol"], smith = "glacier_hermit", wright = "spirit_brown"},
	mawgrave = {name = "Sporehollow", style = "fungal", houses = ["glowshroom", "glowshroom", "burnt_tree", "glowshroom"],
		folk = ["genie_purple", "cave_shaman", "sporeback", "spirit_purple"], smith = "cave_shaman", wright = "genie_purple"},
	pale_eye = {name = "The Obsidian Court", style = "obsidian", houses = ["obelisk", "pillar", "obelisk", "boulder"],
		folk = ["runic_archivist", "genie_purple", "sun_priest", "spirit_spark"], smith = "runic_archivist", wright = "sun_priest"},
}
const TOWN_OFFSET := Vector2(0, 180)
const TOWN_RADIUS := 44.0
const DOCK_OFFSET := Vector2(0, 268)
const TOWN_SPOTS := {smith = Vector2(-13, 9), wright = Vector2(-20, 0), center = Vector2.ZERO}
## The boss strongholds (PlanetStrongholds): a walled fortress on a level
## terrace cut into the planet's top, FORT_OFFSET from the pad (opposite the
## town), sealed until its key is turned; the boss waits inside.
const FORTS := {
	rosamund = {name = "The Rose Bastion", key = "key_rose_bastion", boss = "queen_briarrose", style = "rose"},
	amberfall = {name = "The Amber Ziggurat", key = "key_amber_ziggurat", boss = "amber_colossus", style = "amber"},
	hollowmoon = {name = "The Shattered Observatory", key = "key_shattered_observatory", boss = "selenarch", style = "moon"},
	mawgrave = {name = "The Rotting Hive", key = "key_rotting_hive", boss = "brood_matriarch", style = "hive"},
	pale_eye = {name = "The Stormeye Citadel", key = "key_stormeye_citadel", boss = "stormeye_tyrant", style = "storm"},
}
const FORT_OFFSET := Vector2(0, -125)
const FORT_FLAT := 56.0  # level ground around the fortress centre (m, past the corner towers), then FORT_BLEND
const FORT_BLEND := 40.0
## Flat ground kept around the pad and each place (arc metres), then a blend.
const PAD_FLAT := 34.0
const PLACE_FLAT := 22.0
const FLAT_BLEND := 60.0

static var _noises := {}
static var _flats := {}

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

## Every pad sits on top of its world, so the ground around it faces up and
## realm combat (enemies, bullets, arrows: all "up is +Y") works there. The
## cap within this angle of the top is where planet enemies live.
const COMBAT_CAP := 0.42

## The planet whose top cap lies under x/z (world), or {}.
static func cap_planet(x: float, z: float) -> Dictionary:
	for p: Dictionary in PLANETS:
		var c: Vector3 = p.center
		var d := Vector2(x-c.x, z-c.z).length()
		if d<float(p.radius)*0.75: return p
	return {}

## Ground height (world y) on a planet's top cap at x/z.
static func cap_height(p: Dictionary, x: float, z: float) -> float:
	var c: Vector3 = p.center
	var r := float(p.radius)
	var flat := Vector2(x-c.x, z-c.z)
	var dir := Vector3(flat.x, sqrt(maxf(r*r-flat.length_squared(), 0.0)), flat.y).normalized()
	var top := r+surface_height(p, dir)
	# Again from the sphere at that height, closing in on the ground straight below x/z.
	for i in 3:
		dir = Vector3(flat.x, sqrt(maxf(top*top-flat.length_squared(), 0.0)), flat.y).normalized()
		top = r+surface_height(p, dir)
	return c.y+sqrt(maxf(top*top-flat.length_squared(), 0.0))

## Highest ground above the base radius, for broad checks.
static func max_height(p: Dictionary) -> float:
	return float(p.terrain.height)*1.25

## Height of a planet's air above its base radius (its sky starts below it).
static func air_height(p: Dictionary) -> float:
	return 320.0 if p.get("city", false) else float(p.radius)*0.12+max_height(p)

## The planet whose gravity holds `position` (within `margin` of its highest ground).
static func planet_near(position: Vector3, margin := 60.0) -> Dictionary:
	for p: Dictionary in PLANETS:
		if position.distance_to(p.center)<float(p.radius)+maxf(max_height(p), 260.0 if p.get("city", false) else 0.0)+margin: return p
	return {}

## Ground frame on a planet's pad (origin on the surface, basis.y = up).
static func pad_frame(p: Dictionary) -> Transform3D:
	var up: Vector3 = (p.pad as Vector3).normalized()
	var right := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD))<0.95 else Vector3.RIGHT).normalized()
	return Transform3D(Basis(right, up, right.cross(up)), p.center+up*float(p.radius))

## A frame on the (flattened) ground `offset` metres from the pad, relative to
## the planet centre: walking the arc along the pad's right/forward axes.
static func place_frame(p: Dictionary, offset: Vector2) -> Transform3D:
	var pad := pad_frame(p)
	var radius := float(p.radius)
	var distance := offset.length()
	var tangent := (pad.basis.x*offset.x+pad.basis.z*offset.y).normalized()
	var normal := pad.basis.y if distance<0.001 else pad.basis.y*cos(distance/radius)+tangent*sin(distance/radius)
	var right := (pad.basis.x-normal*normal.dot(pad.basis.x)).normalized()
	return Transform3D(Basis(right, normal, right.cross(normal)), normal*(radius+surface_height(p, normal)))

## Unit directions (from the centre) that stay flat, with their flat radius.
static func _flat_spots(p: Dictionary) -> Array:
	var id: String = p.id
	if _flats.has(id): return _flats[id]
	var pad := pad_frame(p)
	var radius := float(p.radius)
	var out: Array = [[pad.basis.y, PAD_FLAT]]
	var offsets: Array[Vector2] = PLACE_OFFSETS.duplicate()
	offsets.append_array([TOWN_OFFSET, DOCK_OFFSET])
	for offset in offsets:
		var distance := offset.length()
		var tangent := (pad.basis.x*offset.x+pad.basis.z*offset.y).normalized()
		var flat := TOWN_RADIUS+8.0 if offset==TOWN_OFFSET else PAD_FLAT if offset==DOCK_OFFSET else PLACE_FLAT
		out.append([pad.basis.y*cos(distance/radius)+tangent*sin(distance/radius), flat])
	if FORTS.has(id):
		# Level (not following the sphere): [direction, radius, plane height above the centre].
		var fort := place_frame_raw(p, FORT_OFFSET)
		out.append([fort, FORT_FLAT, radius*fort.y])
	_flats[id] = out
	return out

## The unit direction `offset` arc metres from the pad (no terrain needed).
static func place_frame_raw(p: Dictionary, offset: Vector2) -> Vector3:
	var pad := pad_frame(p)
	var radius := float(p.radius)
	var distance := offset.length()
	if distance<0.001: return pad.basis.y
	var tangent := (pad.basis.x*offset.x+pad.basis.z*offset.y).normalized()
	return pad.basis.y*cos(distance/radius)+tangent*sin(distance/radius)

## The planet's fortress frame (relative to the planet centre): level, Y up,
## its main gate (-Z) facing the pad. Identity when it has none.
static func fort_frame(p: Dictionary) -> Transform3D:
	if not FORTS.has(p.id): return Transform3D()
	var dir := place_frame_raw(p, FORT_OFFSET)
	var toward := -Vector3(dir.x, 0, dir.z)
	if toward.length()<0.001: toward = Vector3.FORWARD
	return Transform3D(Basis.looking_at(toward.normalized(), Vector3.UP), dir*float(p.radius))

static func _noise(p: Dictionary, layer: int) -> FastNoiseLite:
	var key := "%s:%d" % [p.id, layer]
	if _noises.has(key): return _noises[key]
	var noise := FastNoiseLite.new()
	noise.seed = absi(String(p.id).hash())+layer*7919
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 5
	noise.frequency = 1.0/float(p.terrain.size)
	if layer==1:
		# Ridges and cells for mountains, spires and craters.
		noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
		noise.fractal_octaves = 4
		noise.frequency = 1.0/(float(p.terrain.size)*1.7)
	elif layer==2:
		noise.noise_type = FastNoiseLite.TYPE_CELLULAR
		noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
		noise.fractal_type = FastNoiseLite.FRACTAL_NONE
		noise.frequency = 1.0/(float(p.terrain.size)*0.8)
	_noises[key] = noise
	return noise

## Raw terrain shape in metres before flattening.
static func _shape(p: Dictionary, at: Vector3) -> float:
	var t: Dictionary = p.terrain
	if str(t.style)=="city": return 0.0  # streets: a perfect sphere
	var height := float(t.height)
	var fbm := _noise(p, 0).get_noise_3dv(at)
	match str(t.style):
		"hills":
			var ridge := _noise(p, 1).get_noise_3dv(at)
			return height*(fbm*0.55+maxf(0.0, ridge)*0.75)
		"terraces":
			var level := (fbm*0.5+0.5)*5.0
			return height*((floorf(level)+smoothstep(0.75, 1.0, fposmod(level, 1.0)))/5.0-0.35)
		"dunes":
			var swirl := at.normalized().dot(Vector3(0.6, 0.2, 0.77))*float(p.radius)/float(t.size)*6.0
			return height*(absf(sin(swirl+fbm*4.0))*0.7+fbm*0.4-0.25)
		"islands":
			return maxf(-6.0, height*(fbm*1.6-0.12))
		"crystal":
			var ridge := _noise(p, 1).get_noise_3dv(at)
			return height*(pow(maxf(0.0, ridge), 2.0)*1.3+fbm*0.3)
		"craters":
			var cell := _noise(p, 2).get_noise_3dv(at)
			var bowl := smoothstep(0.0, 0.55, cell+1.0)
			var rim := exp(-pow((cell+0.45)*7.0, 2.0))
			return height*(fbm*0.4+(bowl-1.0)*0.9+rim*0.45)
		"fungal":
			var domes := pow(maxf(0.0, _noise(p, 1).get_noise_3dv(at)), 1.5)
			return height*(fbm*0.5+domes*0.9)
		"spires":
			var ridge := maxf(0.0, _noise(p, 1).get_noise_3dv(at))
			return height*(fbm*0.35+pow(ridge, 3.0)*1.6)
	return height*fbm

## Terrain height above the base radius along unit direction `dir` (metres).
## Zero on the pad and the story places, blending out to full terrain.
static func surface_height(p: Dictionary, dir: Vector3) -> float:
	if p.get("city", false): return 0.0
	var radius := float(p.radius)
	var raw := _shape(p, dir*radius)
	var mask := 1.0
	for flat: Array in _flat_spots(p):
		if flat.size()>2: continue
		var arc := acos(clampf(dir.dot(flat[0]), -1.0, 1.0))*radius
		mask = minf(mask, smoothstep(float(flat[1]), float(flat[1])+FLAT_BLEND, arc))
	var h := raw*mask
	for flat: Array in _flat_spots(p):
		if flat.size()<3: continue
		# A fortress terrace: a level plane, cut into the slope and built up below it.
		var arc := acos(clampf(dir.dot(flat[0]), -1.0, 1.0))*radius
		if arc>=float(flat[1])+FORT_BLEND or dir.y<0.2: continue
		var level := float(flat[2])/dir.y-radius
		h = lerpf(level, h, smoothstep(float(flat[1]), float(flat[1])+FORT_BLEND, arc))
	return h

## World-space ground point below or above `position` on planet `p`.
static func surface_point(p: Dictionary, position: Vector3) -> Vector3:
	var dir: Vector3 = (position-p.center).normalized()
	return p.center+dir*(float(p.radius)+surface_height(p, dir))

## A frame (planet space) in planet `p`'s town: "center", "smith", "wright"
## (relative to the plaza) or "dock" (the shipyard pad).
static func town_frame(p: Dictionary, which: String) -> Transform3D:
	if which=="dock": return place_frame(p, DOCK_OFFSET)
	if which=="wright": return place_frame(p, DOCK_OFFSET+TOWN_SPOTS.wright)
	return place_frame(p, TOWN_OFFSET+(TOWN_SPOTS.get(which, Vector2.ZERO) as Vector2))

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
## The wall has three passes (gaps) the campaigns fly through; a few giants
## anchor the field.
static func asteroids() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = SHARDFIELD.seed
	var out: Array = []
	var c: Vector3 = SHARDFIELD.center
	var e: Vector3 = SHARDFIELD.extents
	var gaps := passes()
	while out.size()<3200:
		# Denser toward the middle plane of the wall.
		var at := c+Vector3(rng.randf_range(-e.x, e.x), rng.randf_range(-e.y, e.y)*rng.randf(), rng.randf_range(-e.z, e.z))
		var open := false
		for gap: Vector3 in gaps:
			if Vector2(at.x-gap.x, at.y-gap.y).length()<PASS_RADIUS: open = true
		if open or at.distance_to(planet("shardheart").center)<560.0: continue
		var giant := rng.randf()<0.025
		var radius := rng.randf_range(160.0, 320.0) if giant else rng.randf_range(10.0, 70.0)
		out.append([at, radius, rng.randf()<0.22])
	return out

const PASS_RADIUS := 480.0

static func passes() -> Array:
	var c: Vector3 = SHARDFIELD.center
	return [c+Vector3(-7800, 360, 0), c+Vector3(900, -240, 0), c+Vector3(9300, 600, 0)]
