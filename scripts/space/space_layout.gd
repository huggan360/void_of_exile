class_name SpaceLayout
extends RefCounted
## The Astral Reach: one large round space world shared by art, gravity, the
## server and the map. The Nexus station is at the origin in the peaceful
## Haven; past the Shardfield lies the dark Gloam (+Z). Asteroids drift
## everywhere, thickening toward the Gloam (see asteroids()). Ship interiors are rooms far below everything.
## Planets are whole worlds: `surface_height` is their deterministic terrain,
## used by the server (gravity, hull collisions) and the art (terrain meshes).

const NEXUS := Vector3.ZERO
## Hidden outer-Gloam restaurant, safely inside the boundary steering zone.
const DINER := Vector3(16000, 0, 34500)
const DINER_RADIUS := 44.0
## Station deck: flat gravity inside this cylinder, deck at y = 0.
const STATION_RADIUS := 62.0
const STATION_HALF_HEIGHT := 14.0
## Ships wait at these berths around the station: moored alongside the end of
## a boarding walk (NexusStation), starboard hatch against it.
const GANGWAY_END := 59.4
const BERTHS := 6
## Region borders along +Z.
const SHARDFIELD_START := 16200.0
const GLOAM_START := 21000.0
const SHARDFIELD := {center = Vector3(0, 0, 18600), extents = Vector3(20000, 2600, 2000), seed = 6271}
## Walkable ship interiors: one room per ship slot, deck at the slot's y.
const POCKET_ORIGIN := Vector3(0, -14100, 0)
const POCKET_SPACING := 220.0
const POCKET_SLOTS := 24
## The playable sphere. Inside BOUNDARY_WARN of its edge ships are steered
## back toward the Nexus; the red barrier is drawn on the sphere itself.
const WORLD_RADIUS := 42000.0
const BOUNDARY_WARN := 2500.0
## The Surface (the realm) lies under all of Space: a world so large it reads
## as a flat blue-green floor far below (SpaceBackdrop draws it). Ships can't
## sink below SURFACE_FLOOR; under DESCEND_HEIGHT a pilot may take them down.
## The sun is only light in the sky now (SpaceBackdrop.SUN_DIR), far away.
const SURFACE_Y := -14000.0
const SURFACE_FLOOR := SURFACE_Y+700.0
const DESCEND_HEIGHT := SURFACE_Y+3000.0
## Where ships launched from the Surface rise into Space, facing the Nexus.
const ASCENT := Vector3(0, -9000, 1600)

static func can_descend(at: Vector3) -> bool:
	return at.y<DESCEND_HEIGHT

## Planets. `pad` is the unit direction (from the centre) of the landing pad;
## ships land there and the crew steps out onto it. `palette` drives the art
## (earth, bright, shade, magic, accent, sky); `danger` 0..3 sets how hostile
## it is. `terrain` shapes the ground: style, height (m), feature size (m).
const PLANETS := [
	{id = "verdance", name = "Verdance", region = "haven", center = Vector3(4200, 400, -3200), radius = 650.0,
		pad = Vector3.UP, danger = 0, palette = ["3f9d4a", "8fd16a", "2c5d36", "f2d27a", "7fe8c7", "8fe0c0"],
		terrain = {style = "hills", height = 46.0, size = 260.0, water = -9.0},
		about = "Mossy forest world: giant glowing mushrooms, treehouse villages, rope bridges, fireflies."},
	{id = "rosamund", name = "Rosamund", region = "haven", center = Vector3(-4600, -700, 2200), radius = 520.0,
		pad = Vector3.UP, danger = 0, palette = ["e07fb5", "ffc6e2", "8a3f78", "8de0ff", "fff3b0", "ffb8de"],
		terrain = {style = "terraces", height = 38.0, size = 210.0, water = -8.0},
		about = "Pink crystal meadows, candy-coloured trees, fairy shrines and floating petals."},
	{id = "amberfall", name = "Amberfall", region = "haven", center = Vector3(2800, 900, 7400), radius = 760.0,
		pad = Vector3.UP, danger = 1, palette = ["b07a34", "d9a85a", "6a3e18", "5fd18a", "fff0c8", "ffc27a"],
		terrain = {style = "dunes", height = 42.0, size = 170.0, water = -15.0}, air = {storm = 2.2},
		about = "Amber dunes, honey lakes, lantern towers and a sleepy desert market."},
	{id = "tidewell", name = "Tidewell", region = "haven", center = Vector3(-7400, 500, 8600), radius = 900.0,
		pad = Vector3.UP, danger = 1, palette = ["2f86c9", "7fd6e8", "e8d6a0", "3f9d6a", "ffffff", "8ad2ff"],
		terrain = {style = "islands", height = 34.0, size = 240.0, sea = true, water = 0.0},
		about = "Ocean world: an archipelago of small islands, a lighthouse and a fishing village on stilts."},
	{id = "shardheart", name = "Shardheart", region = "shardfield", center = Vector3(3600, 0, 18800), radius = 300.0,
		pad = Vector3.UP, danger = 2, palette = ["3a8a7a", "8af0d8", "1a2a34", "ff8ae0", "1a2030", "6af0c8"],
		terrain = {style = "crystal", height = 30.0, size = 90.0},
		about = "A hollow crystal planetoid hidden inside the Shardfield, humming and half-alive."},
	{id = "hollowmoon", name = "Hollowmoon", region = "gloam", center = Vector3(-4200, 800, 26000), radius = 640.0,
		pad = Vector3.UP, danger = 2, palette = ["7d818e", "b8b4a8", "3a3d48", "7dff6a", "1a1a22", "4a5a52"],
		terrain = {style = "craters", height = 44.0, size = 150.0, water = -22.0},
		about = "A dead grey moon: bone forests, a ruined observatory, cold green ghost-lights."},
	{id = "mawgrave", name = "Mawgrave", region = "gloam", center = Vector3(5600, -900, 30500), radius = 950.0,
		pad = Vector3.UP, danger = 3, palette = ["4a2a5a", "8a4aa0", "1a0f22", "ff5fd2", "7dff6a", "6a3a7a"],
		terrain = {style = "fungal", height = 46.0, size = 260.0, water = -11.0},
		about = "Rotting violet fungal planet; the brood's hives swell out of the ground."},
	{id = "pale_eye", name = "The Pale Eye", region = "gloam", center = Vector3(-600, 1800, 35500), radius = 1300.0,
		pad = Vector3.UP, danger = 3, palette = ["4a5266", "a8b0c4", "14161e", "9ab0ff", "ff4a5a", "8090b8"],
		terrain = {style = "spires", height = 110.0, size = 230.0, water = -18.0},
		about = "Storm planet with a vast eye-shaped storm; obsidian spires and the end of the map."},
	{id = "vesperis", name = "Vesperis", region = "haven", center = Vector3(-2400, 700, -6600), radius = 1000.0,
		pad = Vector3.UP, danger = 0, palette = ["2c2638", "ffb86a", "1a1626", "ff6eb4", "6af0e0", "e8954a"],
		terrain = {style = "city", height = 0.0, size = 200.0}, city = true,
		air = {dusk = "ff6a3a", thick = 1.8, strength = 1.5, haze = 0.5, storm = 2.6},  # a thick amber sunset, streaming out
		about = "The Lantern City: three city cores with spaceports, set in farmland of wheat fields, red barns and grazing cows."},
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
## The four places lie scattered over each world's top (place_offset).
const PLACE_REACH := Vector2(95.0, 300.0)
## Each planet's town (`at`: arc metres from the pad, right and forward): its
## plaza, the smith and the shipwright by a small shipyard pad where bought
## ships wait, DOCK_GAP further out. PlanetSettlements builds it (and the
## villages, settlements()) from the planet's own voxel houses.
const TOWNS := {
	verdance = {at = Vector2(-170, 150), name = "Mossbrook", style = "village", houses = ["res://props/houses/woodland_0", "res://props/houses/woodland_1", "res://props/houses/woodland_2", "res://props/home/rose_cottage", "res://props/home/blue_bakery", "res://props/home/tall_townhouse"],
		folk = ["npc_villager", "npc_gardener", "npc_baker", "moss_tortoise"], smith = "npc_smith", wright = "npc_traveler"},
	rosamund = {at = Vector2(165, 115), name = "Petalgate", style = "village", houses = ["res://props/home/rose_cottage", "res://props/home/chapel", "res://props/home/magicians_house", "res://props/home/blossom_tree", "res://props/home/rose_cottage", "res://props/home/garden_bed"],
		folk = ["npc_magician", "spirit_purple", "npc_villager", "spirit_spark"], smith = "npc_smith", wright = "npc_magician"},
	amberfall = {at = Vector2(-150, -205), name = "Honeymarket", style = "village", houses = ["res://props/houses/desert_0", "res://props/houses/desert_1", "res://props/houses/desert_2", "res://props/houses/desert_0", "res://props/town/market", "res://props/town/market"],
		folk = ["npc_traveler", "sun_priest", "genie_brown", "npc_baker"], smith = "npc_smith", wright = "genie_brown"},
	tidewell = {at = Vector2(215, 70), name = "Saltstilts", style = "village", houses = ["res://props/houses/fosen_0", "res://props/houses/fosen_1", "res://props/houses/fosen_2", "res://props/houses/fosen_1", "res://props/town/well", "res://props/home/broad_lodge"],
		folk = ["npc_villager", "tide_snail", "crab", "npc_traveler"], smith = "npc_smith", wright = "npc_traveler"},
	shardheart = {at = Vector2(95, 85), name = "Lumen Spire", style = "crystal", houses = ["crystal_cluster", "ice_spike", "crystal_cluster", "obelisk"],
		folk = ["genie_blue", "spirit_blue", "runic_archivist", "prism_ray"], smith = "runic_archivist", wright = "genie_blue"},
	hollowmoon = {at = Vector2(150, -150), name = "Ashveil", style = "ruins", houses = ["ruin_house", "ruin_wall", "ruin_house", "obelisk"],
		folk = ["spirit_brown", "glacier_hermit", "spirit_blue", "nightbell_idol"], smith = "glacier_hermit", wright = "spirit_brown"},
	mawgrave = {at = Vector2(-205, 165), name = "Sporehollow", style = "fungal", houses = ["glowshroom", "glowshroom", "burnt_tree", "glowshroom"],
		folk = ["genie_purple", "cave_shaman", "sporeback", "spirit_purple"], smith = "cave_shaman", wright = "genie_purple"},
	pale_eye = {at = Vector2(265, 215), name = "The Obsidian Court", style = "obsidian", houses = ["obelisk", "pillar", "obelisk", "boulder"],
		folk = ["runic_archivist", "genie_purple", "sun_priest", "spirit_spark"], smith = "runic_archivist", wright = "sun_priest"},
}
const TOWN_RADIUS := 58.0
const DOCK_GAP := 104.0
const TOWN_SPOTS := {smith = Vector2(-13, 9), wright = Vector2(-20, 0), center = Vector2.ZERO}
## The boss strongholds (PlanetStrongholds): a walled fortress on a level
## terrace cut into the planet's top, `at` arc metres from the pad (away from
## the town, each world its own way), sealed until its key is turned; the
## boss waits inside. Kept within ~0.3 rad of the top, where realm combat works.
const FORTS := {
	rosamund = {at = Vector2(-120, -95), name = "The Rose Bastion", key = "key_rose_bastion", boss = "queen_briarrose", style = "rose"},
	amberfall = {at = Vector2(190, 90), name = "The Amber Ziggurat", key = "key_amber_ziggurat", boss = "amber_colossus", style = "amber"},
	hollowmoon = {at = Vector2(-170, 60), name = "The Shattered Observatory", key = "key_shattered_observatory", boss = "selenarch", style = "moon"},
	mawgrave = {at = Vector2(230, -150), name = "The Rotting Hive", key = "key_rotting_hive", boss = "brood_matriarch", style = "hive"},
	pale_eye = {at = Vector2(-300, -230), name = "The Stormeye Citadel", key = "key_stormeye_citadel", boss = "stormeye_tyrant", style = "storm"},
}
const FORT_FLAT := 56.0  # level ground around the fortress centre (m, past the corner towers), then FORT_BLEND
const FORT_BLEND := 40.0
## Flat ground kept around the pad and each place (arc metres), then a blend.
const PAD_FLAT := 34.0
const PLACE_FLAT := 26.0
const FLAT_BLEND := 60.0
## Villages by kind: [flat radius (m), houses]; the bigger ones get a plaza.
const VILLAGE_KINDS := {hamlet = [22.0, 4], village = [32.0, 8], large = [44.0, 13]}
const VILLAGE_BLEND := 50.0
const VILLAGE_NAMES := {
	verdance = ["Fernhollow", "Glimmerdell", "Mosswick", "Lanternroot", "Dewbrook", "Thistledown", "Brambleford"],
	rosamund = ["Rosewhistle", "Candlebloom", "Sugarvale", "Petalford", "Lilacmere", "Honeysuckle"],
	amberfall = ["Dunewell", "Saffron Rest", "Goldwind", "Emberdune", "Honeycomb Hollow", "Sandglass", "Ochre Gate"],
	tidewell = ["Gullrock", "Pearlcove", "Driftwood Bay", "Kelpstead", "Saltmarsh", "Coralreach", "Wavecrest", "Shellby"],
	shardheart = ["Prismhold", "Echo Nook", "Facet Rise", "Glasswhisper"],
	hollowmoon = ["Gravelight", "Dustveil", "Cindermoor", "Paleford", "Hush", "Ashcombe"],
	mawgrave = ["Rotmire", "Sporewick", "Gloomcap", "Velvetrot", "Mirebloom", "Fester Hollow", "Cankerdell", "Moldwater"],
	pale_eye = ["Thunderhold", "Ravenspire", "Glasshallow", "Stormwatch", "Blackrain", "Shardholt", "Ironveil", "Gale Rest", "Duskanvil", "Cinderglass", "Hollowpeak"],
}

static var _noises := {}
static var _flats := {}
static var _settlements := {}
static var _place_offsets := {}
static var _ports := {}

## Where ships set down on a planet: every world has its landing pad and its
## town's shipyard pad; the Lantern City has the pads of its spaceports.
## Each {key, name, pose (a landed ship's pose, world space)}.
static func ports(p: Dictionary) -> Array:
	var id := str(p.id)
	if _ports.has(id): return _ports[id]
	var out: Array = []
	var lift := 6.5  # SpaceShip.LANDED_HEIGHT
	var center: Vector3 = p.center
	if p.get("city", false):
		for pad: Dictionary in CityLayout.all_pads():
			var frame: Transform3D = pad.frame
			var district: Dictionary = CityLayout.DISTRICTS.filter(func(d: Dictionary) -> bool: return d.id==pad.district)[0]
			out.append({key = "%s:%s:%d" % [id, pad.district, pad.index], name = "%s, pad %d" % [district.port, int(pad.index)+1],
				pose = Transform3D(frame.basis, center+frame.origin+frame.basis.y*lift)})
	else:
		var pad := pad_frame(p)
		out.append({key = id+":pad", name = "%s landing pad" % p.name, pose = Transform3D(pad.basis, pad.origin+pad.basis.y*lift)})
		var dock := town_frame(p, "dock")
		out.append({key = id+":dock", name = "%s shipyard" % TOWNS.get(id, {}).get("name", p.name), pose = Transform3D(dock.basis, center+dock.origin+dock.basis.y*lift)})
	_ports[id] = out
	return out

## A port by its key: {planet, port}, or {}.
static func port(key: String) -> Dictionary:
	var p := planet(key.get_slice(":", 0))
	if p.is_empty(): return {}
	for entry: Dictionary in ports(p):
		if entry.key==key: return {planet = p, port = entry}
	return {}

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

## The landing pad's crystal (pad space): the shipwright's terminal there.
const PAD_CRYSTAL := Vector3(0, 0, -21)

## Where planet `p`'s landing pad crystal stands (world space).
static func pad_crystal(p: Dictionary) -> Vector3:
	return pad_frame(p)*PAD_CRYSTAL

## Where the crystal on the town's shipyard pad stands (world space).
static func dock_crystal(p: Dictionary) -> Vector3:
	return (p.center as Vector3)+town_frame(p, "dock")*PAD_CRYSTAL

## Ground frame on a planet's pad (origin on the surface, basis.y = up).
static func pad_frame(p: Dictionary) -> Transform3D:
	var up: Vector3 = (p.pad as Vector3).normalized()
	var right := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD))<0.95 else Vector3.RIGHT).normalized()
	# On its levelled ground (a few metres up on a sea world, base_level).
	return Transform3D(Basis(right, up, right.cross(up)), p.center+up*(float(p.radius)+base_level(p)))

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

## Water on a planet: the height (m above the base radius) of its sea and
## lakes, or NAN where it has none.
static func water_level(p: Dictionary) -> float:
	return float(p.terrain.get("water", NAN))

## Whether the ground along `dir` is under water (or within `margin` m of it).
static func underwater(p: Dictionary, dir: Vector3, margin := 0.0) -> bool:
	var water := water_level(p)
	return not is_nan(water) and surface_height(p, dir)<water+margin

## The height the pad, town and places are levelled to: on a sea world a few
## metres above the waves, so each settlement makes its own island.
static func base_level(p: Dictionary) -> float:
	var water := water_level(p)
	return 0.0 if is_nan(water) else maxf(0.0, water+2.5)

## The arc offset of planet `p`'s story place `index` (0..3): spread round
## the top at their own angles and distances, clear of the town and fortress.
static func place_offset(p: Dictionary, index: int) -> Vector2:
	var id := str(p.id)
	if not _place_offsets.has(id):
		var rng := RandomNumberGenerator.new()
		rng.seed = absi(id.hash())+1777
		var taken: Array = [[Vector2.ZERO, PAD_FLAT+30.0], [town_offset(p), TOWN_RADIUS+30.0], [dock_offset(p), PAD_FLAT+26.0]]
		if FORTS.has(id): taken.append([fort_offset(p), FORT_FLAT+30.0])
		var reach := Vector2(PLACE_REACH.x, minf(PLACE_REACH.y, float(p.radius)*0.55))
		var out: Array[Vector2] = []
		var turn := rng.randf()*TAU
		for i in 4:
			var best := Vector2.ZERO
			var best_gap := -INF
			for attempt in 40:
				var a := turn+TAU*(i+rng.randf_range(-0.3, 0.3))/4.0
				var at := Vector2.from_angle(a)*rng.randf_range(reach.x, reach.y)
				var gap := INF
				for t: Array in taken: gap = minf(gap, at.distance_to(t[0])-float(t[1]))
				if gap>best_gap:
					best_gap = gap
					best = at
				if gap>0.0: break
			out.append(best)
			taken.append([best, PLACE_FLAT+30.0])
		_place_offsets[id] = out
	return (_place_offsets[id] as Array)[clampi(index, 0, 3)]

static func town_offset(p: Dictionary) -> Vector2:
	return TOWNS.get(p.id, {}).get("at", Vector2(0, 180))

## The shipyard pad: further out from the town, away from the landing pad.
static func dock_offset(p: Dictionary) -> Vector2:
	var town := town_offset(p)
	return town+town.normalized()*DOCK_GAP

static func fort_offset(p: Dictionary) -> Vector2:
	return FORTS.get(p.id, {}).get("at", Vector2(0, -125))

## Villages on planet `p` (not the main town): [{name, kind, dir, radius,
## level, houses, index}], scattered over the whole world, deterministic, on
## dry ground and well apart from the pad, town, places and fortress.
static func settlements(p: Dictionary) -> Array:
	var id := str(p.id)
	if _settlements.has(id): return _settlements[id]
	var out: Array = []
	if p.get("city", false) or not TOWNS.has(id):
		_settlements[id] = out
		return out
	var radius := float(p.radius)
	var water := water_level(p)
	var taken: Array = [[pad_frame(p).basis.y, PAD_FLAT], [place_frame_raw(p, town_offset(p)), TOWN_RADIUS], [place_frame_raw(p, dock_offset(p)), PAD_FLAT]]
	for i in 4: taken.append([place_frame_raw(p, place_offset(p, i)), PLACE_FLAT])
	if FORTS.has(id): taken.append([place_frame_raw(p, fort_offset(p)), FORT_FLAT])
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(id.hash())+4421
	var names: Array = VILLAGE_NAMES.get(id, [])
	var count := mini(names.size(), clampi(roundi(radius/120.0), 3, 11))
	var cycle := ["large", "village", "hamlet", "village", "hamlet", "large", "hamlet", "village"]
	for i in count:
		var kind: String = cycle[i % cycle.size()]
		var flat: float = VILLAGE_KINDS[kind][0]
		for attempt in 200:
			var dir := _random_dir(rng)
			# Half of them on the side of the world the crew lands on.
			if i % 2==0 and dir.y<0.1: dir.y = absf(dir.y)+0.1
			dir = dir.normalized()
			var ok := true
			for t: Array in taken:
				if acos(clampf(dir.dot(t[0]), -1.0, 1.0))*radius<flat+float(t[1])+VILLAGE_BLEND+20.0:
					ok = false
					break
			if not ok: continue
			var raw := _shape(p, dir*radius)
			if not is_nan(water) and raw<water+(4.0 if str(p.terrain.style)=="islands" else 2.0): continue
			var level := raw if is_nan(water) else maxf(raw, water+2.0)
			out.append({name = str(names[i]), kind = kind, dir = dir, radius = flat, level = level, houses = int(VILLAGE_KINDS[kind][1]), index = i})
			taken.append([dir, flat])
			break
	_settlements[id] = out
	return out

static func _random_dir(rng: RandomNumberGenerator) -> Vector3:
	var z := rng.randf_range(-1.0, 1.0)
	var a := rng.randf()*TAU
	var r := sqrt(1.0-z*z)
	return Vector3(cos(a)*r, sin(a)*r, z)

## Ground kept level on planet `p`: [direction, flat radius, kind (0 a level
## height, 1 the fortress plane), level (m) or plane distance, cos of the
## whole reach (a quick reject), blend].
static func _flat_spots(p: Dictionary) -> Array:
	var id: String = p.id
	if _flats.has(id): return _flats[id]
	var radius := float(p.radius)
	var base := base_level(p)
	var out: Array = []
	var add := func(dir: Vector3, flat: float, kind: int, level: float, blend: float) -> void:
		out.append([dir, flat, kind, level, cos(minf((flat+blend)/radius, PI)), blend])
	add.call(pad_frame(p).basis.y, PAD_FLAT, 0, base, FLAT_BLEND)
	for i in 4: add.call(place_frame_raw(p, place_offset(p, i)), PLACE_FLAT, 0, base, FLAT_BLEND)
	add.call(place_frame_raw(p, town_offset(p)), TOWN_RADIUS+8.0, 0, base, FLAT_BLEND)
	add.call(place_frame_raw(p, dock_offset(p)), PAD_FLAT, 0, base, FLAT_BLEND)
	for v: Dictionary in settlements(p): add.call(v.dir, float(v.radius), 0, float(v.level), VILLAGE_BLEND)
	if FORTS.has(id):
		# Level (not following the sphere): the plane at the base radius.
		add.call(place_frame_raw(p, fort_offset(p)), FORT_FLAT, 1, radius, FORT_BLEND)
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

## The planet's fortress frame: tangent to the sphere at its own centre,
## its main gate (-Z) facing the pad. Identity when it has none.
static func fort_frame(p: Dictionary) -> Transform3D:
	if not FORTS.has(p.id): return Transform3D()
	var dir := place_frame_raw(p, fort_offset(p))
	var to_pad: Vector3 = pad_frame(p).basis.y-dir
	var toward: Vector3 = to_pad-dir*to_pad.dot(dir)
	if toward.length()<0.001: toward = place_frame(p, fort_offset(p)).basis.z
	return Transform3D(Basis.looking_at(toward.normalized(), dir), dir*float(p.radius))

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

## Terrain shape in metres before flattening. Lakes (not seas) keep a
## shallow bed, no deeper than about 1.6 m, so the crew wades through them.
static func _shape(p: Dictionary, at: Vector3) -> float:
	var h := _raw_shape(p, at)
	var water := float(p.terrain.get("water", NAN))
	if is_nan(water) or p.terrain.get("sea", false) or h>water-0.6: return h
	return water-0.6-(1.0-exp(-(water-0.6-h)/2.5))*1.0

static func _raw_shape(p: Dictionary, at: Vector3) -> float:
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
## Level on the pad, the places, the towns and villages, blending out to the
## full terrain; the fortress terrace is a plane cut into the slope.
static func surface_height(p: Dictionary, dir: Vector3) -> float:
	if p.get("city", false): return 0.0
	var radius := float(p.radius)
	var h := _shape(p, dir*radius)
	for flat: Array in _flat_spots(p):
		var along: float = dir.dot(flat[0])
		if along<float(flat[4]): continue
		var arc := acos(clampf(along, -1.0, 1.0))*radius
		var keep := smoothstep(float(flat[1]), float(flat[1])+float(flat[5]), arc)
		if int(flat[2])==1:
			if along<0.2: continue
			h = lerpf(float(flat[3])/along-radius, h, keep)
		else:
			h = lerpf(float(flat[3]), h, keep)
	return h

## A frame on the ground of planet `p` (planet space) centred on unit
## direction `dir`, up along it, turned `yaw`: lowered to the lowest ground
## under a footprint of `half` metres, so no side of what stands there floats.
static func ground_frame(p: Dictionary, dir: Vector3, yaw := 0.0, half := 0.0) -> Transform3D:
	var radius := float(p.radius)
	var right := dir.cross(Vector3.FORWARD if absf(dir.dot(Vector3.FORWARD))<0.95 else Vector3.RIGHT).normalized()
	var forward := right.cross(dir)
	var h := surface_height(p, dir)
	if half>0.5:
		for k in 4:
			var t := (right if k<2 else forward)*(half if k % 2==0 else -half)
			h = minf(h, surface_height(p, (dir*radius+t).normalized()))
	return Transform3D(Basis(right, dir, right.cross(dir)).rotated(dir, yaw), dir*(radius+h))

## World-space ground point below or above `position` on planet `p`.
static func surface_point(p: Dictionary, position: Vector3) -> Vector3:
	var dir: Vector3 = (position-p.center).normalized()
	return p.center+dir*(float(p.radius)+surface_height(p, dir))

## A frame (planet space) in planet `p`'s town: "center", "smith", "wright"
## (relative to the plaza) or "dock" (the shipyard pad).
static func town_frame(p: Dictionary, which: String) -> Transform3D:
	if which=="dock": return place_frame(p, dock_offset(p))
	if which=="wright": return place_frame(p, dock_offset(p)+TOWN_SPOTS.wright)
	return place_frame(p, town_offset(p)+(TOWN_SPOTS.get(which, Vector2.ZERO) as Vector2))

static func berth_frame(index: int) -> Transform3D:
	if index>=BERTHS:
		var out := Vector3.LEFT if index==BERTHS else Vector3.RIGHT
		var side := -out
		var basis := Basis(side, Vector3.UP, side.cross(Vector3.UP))
		return Transform3D(basis, DINER+out*36.6-basis*Vector3(11.5, -5.6, 6.0))
	var angle := TAU*index/BERTHS
	var out := Vector3(sin(angle), 0, cos(angle))
	var side := -out
	var basis := Basis(side, Vector3.UP, side.cross(Vector3.UP))
	# ShipHull's hatch (starboard, low) meets the walk's end at deck height.
	var hatch := Vector3(11.5, -5.6, 6.0)
	return Transform3D(basis, NEXUS+out*(GANGWAY_END+0.6)-basis*hatch)

static func pocket_origin(slot: int) -> Vector3:
	return POCKET_ORIGIN+Vector3(slot*POCKET_SPACING, 0, 0)

## Pocket slot of a position inside an interior room, or -1.
static func pocket_at(position: Vector3) -> int:
	if absf(position.y-POCKET_ORIGIN.y)>20.0: return -1
	var slot := roundi((position.x-POCKET_ORIGIN.x)/POCKET_SPACING)
	if slot<0 or slot>=POCKET_SLOTS: return -1
	return slot if absf(position.z)<40.0 and absf(position.x-pocket_origin(slot).x)<40.0 else -1

## Deterministic asteroids: [position, radius, crystal (bool)]. They drift
## through the whole Reach, sparse in the Haven and thickening the deeper you
## fly toward the Gloam (rock_density). Planets, the Nexus, the diner, the
## ascent from the Surface and the campaign passes keep clear water around them.
const ROCKS := 6500
const ROCK_CELL := 700.0  # lookup grid (bigger than any rock)
static var _rocks: Array = []
static var _rock_grid := {}

static func asteroids() -> Array:
	if not _rocks.is_empty(): return _rocks
	var rng := RandomNumberGenerator.new()
	rng.seed = SHARDFIELD.seed
	var out: Array = []
	var reach := WORLD_RADIUS-BOUNDARY_WARN-800.0
	while out.size()<ROCKS:
		# Thickest near the plane the planets share, thinning above and below.
		var at := Vector3(rng.randf_range(-reach, reach), rng.randf_range(-6000.0, 6000.0)*rng.randf(), rng.randf_range(-reach, reach))
		var density := rock_density(at)
		if at.length()>reach or rng.randf()>density or not _rock_clear(at): continue
		var giant := rng.randf()<0.01+0.025*density
		var radius := rng.randf_range(160.0, 320.0) if giant else rng.randf_range(10.0, 70.0)
		out.append([at, radius, rng.randf()<0.04+0.12*density])
	_rocks = out
	for rock: Array in out:
		var key := Vector3i((rock[0] as Vector3)/ROCK_CELL)
		if not _rock_grid.has(key): _rock_grid[key] = []
		_rock_grid[key].append(rock)
	return out

## How thick the rocks are at `at`, 0..1: a scattering in the Haven, more
## past the Shardfield, a thick drift in the Gloam.
static func rock_density(at: Vector3) -> float:
	var deep := smoothstep(-8000.0, 32000.0, at.z)
	return 0.035+0.965*deep*deep

## Rocks that could touch a sphere of `reach` (at most ROCK_CELL) at `at`.
static func rocks_near(at: Vector3, reach := 0.0) -> Array:
	asteroids()
	var out: Array = []
	var cell := Vector3i(at/ROCK_CELL)
	for x in range(-1, 2):
		for y in range(-1, 2):
			for z in range(-1, 2):
				var bucket: Array = _rock_grid.get(cell+Vector3i(x, y, z), [])
				for rock: Array in bucket:
					if (rock[0] as Vector3).distance_to(at)<float(rock[1])+reach: out.append(rock)
	return out

static func _rock_clear(at: Vector3) -> bool:
	if at.distance_to(NEXUS)<3200.0 or at.distance_to(DINER)<1500.0: return false
	if Vector2(at.x-ASCENT.x, at.z-ASCENT.z).length()<1200.0 and at.y<1500.0: return false
	if at.y<SURFACE_FLOOR+1500.0: return false
	for p: Dictionary in PLANETS:
		if at.distance_to(p.center)<float(p.radius)*1.8+500.0: return false
	for gap: Vector3 in passes():
		if at.distance_to(gap)<PASS_RADIUS: return false
	return true

const PASS_RADIUS := 480.0

static func passes() -> Array:
	var c: Vector3 = SHARDFIELD.center
	return [c+Vector3(-7800, 360, 0), c+Vector3(900, -240, 0), c+Vector3(9300, 600, 0)]
