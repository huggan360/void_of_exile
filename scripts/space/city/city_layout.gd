class_name CityLayout
## Vesperis, the Lantern City: a planet that is one city. Data only, the same
## on the server and every client (no randomness that is not seeded here).
##
## The ground is a perfect sphere. A grid of cells covers it (each cube face,
## equal-angle, split into N x N cells): it says where the three towns lie (a
## round, ragged blob of cells round each spaceport, `reach` wobbling with the
## angle) and the rest is farmland (CityCountry). Each town's streets, houses,
## halls, plazas, parks and pond are grown from its own plan (CityTown), with no
## grid in them: the cafes, bars and shops you can walk into and sit in stand in
## timber halls along the avenues near the port, voxel houses (CityHouses) line
## every street. Lanternheart has the Lantern Spire, whose attendants take you
## up to its orb.
##
## Every building piece stands in its own tangent frame (planet space, Y up
## the local normal), so floors are level wherever they are.
const ID := "vesperis"
const N := 28
const ROAD := 4.5  # half width of the carriageway (m)
const WALK := 3.5  # sidewalk width on each side
const FACES: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
## A town: the 2 x 2 cells inside `corner` (cells corner-1..corner) are its
## spaceport. `reach` is its radius in cells (the outline wobbles round it).
const DISTRICTS := [
	{id = "lanternheart", name = "Lanternheart", port = "Lanternheart Spaceport", face = 2, corner = Vector2i(14, 14),
		tint = "e8cc9a", neon = "d7ab68", reach = 5.4, seed = 0.31},
	{id = "rosewater", name = "Rosewater", port = "Rosewater Docks", face = 4, corner = Vector2i(13, 16),
		tint = "e8d9bc", neon = "b9c9bd", reach = 4.0, seed = 0.67},
	{id = "brasswork", name = "Brasswork Heights", port = "Brasswork Skyport", face = 1, corner = Vector2i(15, 13),
		tint = "dac39b", neon = "b9935e", reach = 4.4, seed = 0.13},
]
## The Lantern Spire stands in Lanternheart (CityTown places it by the ring road).
const SPIRE_DISTRICT := "lanternheart"
## The orb (make_vesperis_houses.py): its middle, radius and floor above the ground.
const ORB_CENTER := 92.0
const ORB_RADIUS := 14.0
const ORB_FLOOR := 89.0
## Ground-floor venue kinds, dealt round a district's podiums (front, back).
const VENUE_CYCLE := ["cafe", "bar", "shop_budget", "noodle", "shop_premium", "teahouse", "bar", "shop_curio", "cafe", "arcade",
	"noodle", "shop_budget", "bar", "cafe", "shop_premium", "teahouse", "arcade", "shop_curio", "cafe", "bar"]
const VENUE_NAMES := {
	cafe = ["The Sleepy Comet", "Moonfoam Cafe", "Brass Bean", "Little Lantern Coffee", "Stardust Grind", "The Velvet Cup"],
	bar = ["The Rusty Halo", "Neon Mermaid", "The Last Lantern", "Nebula Tap", "The Gilded Gear", "Rosewater Tavern"],
	noodle = ["Comet Noodles", "Uncle Orbit's Ramen", "Steam and Stars", "Lucky Wok"],
	teahouse = ["Willowlight Tea", "The Quiet Kettle", "Pearl Steam Teahouse"],
	shop_budget = ["Bits and Bobs", "The Thrifty Gnome", "Odd Parts Market"],
	shop_premium = ["Aurelia Outfitters", "The Silver Spire", "Moonglass Armoury"],
	shop_curio = ["Curios of the Void", "The Wandering Satchel", "Whimsy and Wares"],
	arcade = ["Pixel Palace", "Starlight Arcade", "The Blinking Den"],
}
## The voxel halls round the rooms (CityHouses): bars, noodle bars and arcades
## get the ones with neon tubes round the eaves.
const HALLS := ["hall_moss", "hall_red"]
const NEON_HALLS := ["hall_neon_pink", "hall_neon_mint", "hall_neon_amber"]
## The shops (Shops.DEFS) the city's shop rooms hold, in turn.
const SHOP_ROTATION := ["wizard", "priest", "general", "bowyer", "premium", "relic", "tidecaller", "alchemist", "curio"]
## Venue room in its own frame: x across the front, -z the street side (door), y up.
const ROOM := Vector3(16.0, 5.2, 12.0)
const PODIUM := 30.0  # podium footprint (m), centred in the lot
const PODIUM_TALL := 9.0
static var _cache := {}

static func planet() -> Dictionary:
	return SpaceLayout.planet(ID)

static func radius() -> float:
	return float(planet().radius)

# --- Grid -------------------------------------------------------------------------------

## Unit direction for equal-angle cube coordinates u, v in -1..1 on `face`.
static func face_dir(face: int, u: float, v: float) -> Vector3:
	var n := FACES[face]
	var a := Vector3(n.y, n.z, n.x)
	var b := n.cross(a)
	return (n+a*tan(u*PI*0.25)+b*tan(v*PI*0.25)).normalized()

## [face, u, v] of a unit direction.
static func face_uv(dir: Vector3) -> Array:
	var best := 0
	for f in 6:
		if dir.dot(FACES[f])>dir.dot(FACES[best]): best = f
	var n := FACES[best]
	var a := Vector3(n.y, n.z, n.x)
	var b := n.cross(a)
	var d := dir.dot(n)
	return [best, atan(dir.dot(a)/d)*4.0/PI, atan(dir.dot(b)/d)*4.0/PI]

static func cell_uv(i: int, j: int) -> Vector2:
	return Vector2((i+0.5)/N*2.0-1.0, (j+0.5)/N*2.0-1.0)

## Tangent frame (planet space) at face coordinates: Y the normal, X along +u.
static func frame_at(face: int, u: float, v: float, lift := 0.0) -> Transform3D:
	var d := face_dir(face, u, v)
	var e := 0.002
	var along := (face_dir(face, u+e, v)-face_dir(face, u-e, v))
	var x := (along-d*along.dot(d)).normalized()
	var z := x.cross(d).normalized()
	return Transform3D(Basis(x, d, z), d*(radius()+lift))

## A cell's frame and its half extents (m) along local x and z (to the road centre lines).
static func cell(face: int, i: int, j: int) -> Dictionary:
	var key := Vector3i(face, i, j)
	if _cache.has(key): return _cache[key]
	var uv := cell_uv(i, j)
	var frame := frame_at(face, uv.x, uv.y)
	var r := radius()
	var hx := (face_dir(face, float(i+1)/N*2.0-1.0, uv.y)*r-frame.origin).dot(frame.basis.x)
	var hz := absf((face_dir(face, uv.x, float(j+1)/N*2.0-1.0)*r-frame.origin).dot(frame.basis.z))
	var out := {face = face, i = i, j = j, frame = frame, half = Vector2(hx, hz), seed = _hash(face*10007+i*131+j*7)}
	_cache[key] = out
	return out

## Stable 0..1 from an integer.
static func _hash(n: int) -> float:
	var x := (n*1103515245+12345) & 0x7fffffff
	x = (x ^ (x >> 13))*1274126177 & 0x7fffffff
	return float(x % 100000)/100000.0

static func rnd(seed: float, salt: int) -> float:
	return _hash(int(seed*99991.0)+salt*7919)

# --- Districts --------------------------------------------------------------------------

## The district a cell belongs to (or {}), with the cell's local index (from
## corner-3, as the port's rooms count) and its offset from the port's middle.
static func district_of(face: int, i: int, j: int) -> Dictionary:
	for d: Dictionary in DISTRICTS:
		if face!=int(d.face): continue
		var c: Vector2i = d.corner
		var off := Vector2(i+0.5-c.x, j+0.5-c.y)
		if off.length()<=edge(d, off.angle())+(_hash(face*10007+i*131+j*7+5)-0.5)*0.9:
			return {district = d, local = Vector2i(i-(c.x-3), j-(c.y-3)), rel = Vector2i(i-c.x, j-c.y), offset = off}
	return {}

## A town's outline (in cells) toward `angle`: round, with soft bulges.
static func edge(d: Dictionary, angle: float) -> float:
	var seed := float(d.seed)*TAU
	return float(d.reach)*(1.0+0.16*sin(angle*3.0+seed)+0.09*sin(angle*5.0-seed*2.0))

## "farm" outside the towns, "port" under a spaceport, else "town".
static func role(face: int, i: int, j: int) -> String:
	var at := district_of(face, i, j)
	if at.is_empty(): return "farm"
	var rel: Vector2i = at.rel
	if rel.x in [-1, 0] and rel.y in [-1, 0]: return "port"
	return "town"

static func district(id: String) -> Dictionary:
	for d: Dictionary in DISTRICTS:
		if d.id==id: return d
	return {}

## The district's centre (the port's middle) frame in planet space.
static func district_frame(d: Dictionary) -> Transform3D:
	return frame_at(int(d.face), float(d.corner.x)/N*2.0-1.0, float(d.corner.y)/N*2.0-1.0)

## Every cell of a district: [{cell, local, rel, role}].
static func district_cells(d: Dictionary) -> Array:
	var key := "cells:"+str(d.id)
	if _cache.has(key): return _cache[key]
	var out: Array = []
	var c: Vector2i = d.corner
	var span := ceili(float(d.reach)*1.4)+1
	for j in range(maxi(0, c.y-span), mini(N, c.y+span)):
		for i in range(maxi(0, c.x-span), mini(N, c.x+span)):
			var at := district_of(int(d.face), i, j)
			if at.is_empty() or at.district.id!=d.id: continue
			out.append({cell = cell(int(d.face), i, j), local = at.local, rel = at.rel, role = role(int(d.face), i, j)})
	_cache[key] = out
	return out

# --- Spaceports -------------------------------------------------------------------------

## A spaceport is one huge building over its four cells (the streets between
## them are gone): a terminal hall on the ground, offices above, and the
## three landing pads on its flat roof. A square stair core in one corner
## spirals from the hall up to a stair house on the roof. All in the
## district frame (x/z metres, y up, flat).
const PORT_HALF := 44.0  # half the building's footprint
const PORT_ROOF := 30.0  # the roof's top
const PORT_HALL := 10.0  # the terminal hall's ceiling
const PORT_PADS: Array[Vector3] = [Vector3(-28, 0, 5), Vector3(0, 0, 5), Vector3(28, 0, 5)]
const PAD_RADIUS := 10.5
## The stair core: its centre and inner half size; flights of FLIGHT_RISE
## each run along one wall, landings in the corners.
const PORT_CORE := Vector3(34, 0, -34)
const CORE_HALF := 8.0
const STAIR_WIDTH := 3.0
const FLIGHT_RISE := 3.0

## A port's landing pads (planet space frames on the roof, ship forward -Z):
## three parallel berths, with the stair house and shipwright behind them.
const SHIPWRIGHT := Vector3(0, PORT_ROOF, -35)

static func shipwright_position(d: Dictionary) -> Vector3:
	return (planet().center as Vector3)+district_frame(d)*(SHIPWRIGHT+Vector3.UP)

static func pads(d: Dictionary) -> Array[Transform3D]:
	var center := district_frame(d)
	var out: Array[Transform3D] = []
	for local: Vector3 in PORT_PADS:
		out.append(center*Transform3D(Basis.IDENTITY, local+Vector3.UP*(PORT_ROOF+0.4)))
	return out

## The stair core's landings (core-local x/z, counter-clockwise from the
## hall door): flight k climbs from corner k % 4 to corner (k+1) % 4.
static func core_corners() -> Array[Vector2]:
	var lane := CORE_HALF-STAIR_WIDTH*0.5
	return [Vector2(-lane, lane), Vector2(lane, lane), Vector2(lane, -lane), Vector2(-lane, -lane)]

## Tangent frame at a direction with -Z close to `forward`.
static func _tangent(dir: Vector3, back: Vector3) -> Transform3D:
	var z := (back-dir*back.dot(dir)).normalized()
	var x := dir.cross(z).normalized()
	return Transform3D(Basis(x, dir, x.cross(dir).normalized()), dir*radius())

## Every pad on the planet: [{district, index, frame (planet space)}].
static func all_pads() -> Array:
	var out: Array = []
	for d: Dictionary in DISTRICTS:
		var list := pads(d)
		for k in list.size(): out.append({district = d.id, index = k, frame = list[k]})
	return out

## The free pad nearest `near` (world space) within `reach` metres, as a landed
## pose in world space, or {}. `taken(world_pose)` says a pad is occupied.
static func landing_site(near: Vector3, reach: float, taken: Callable) -> Dictionary:
	var p := planet()
	var best := {}
	var best_d := reach
	for pad: Dictionary in all_pads():
		var frame: Transform3D = pad.frame
		var pose := Transform3D(frame.basis, (p.center as Vector3)+frame.origin+frame.basis.y*SpaceShip.LANDED_HEIGHT)
		var d := pose.origin.distance_to(near)
		if d<best_d and not (taken.is_valid() and bool(taken.call(pose))):
			best_d = d
			best = {frame = pose, pad = true, port = pad.district}
	return best

# --- Venues -----------------------------------------------------------------------------

## Every enterable room of a district: its shops, cafes and bars (each in a hall).
## {key, kind, name, frame (planet space, the room's floor centre, -Z the door side),
## size, seats: [{id, pos, yaw, drink}], staff: [{model, pos, yaw, lines}], patrons}
static func venues(d: Dictionary) -> Array:
	var key := "venues:"+str(d.id)
	if _cache.has(key): return _cache[key]
	var out: Array = []
	var shops_dealt := 0
	var rooms: Array = CityTown.plan(d).rooms
	for n in rooms.size():
		var kind: String = VENUE_CYCLE[(n+DISTRICTS.find(d)*3) % VENUE_CYCLE.size()]
		var room: Dictionary = rooms[n]
		var v := _venue("%s_r%d" % [d.id, n], kind, CityTown.frame(d, room.at, room.forward), d, n+1)
		v.hall = HALLS[(n+DISTRICTS.find(d)) % HALLS.size()] if not kind in ["bar", "noodle", "arcade"] \
			else NEON_HALLS[(n+DISTRICTS.find(d)) % NEON_HALLS.size()]
		# Shop rooms get a real shop (Shops), dealt round so every kind is somewhere.
		if kind.begins_with("shop"):
			v.shop = SHOP_ROTATION[(DISTRICTS.find(d)*6+shops_dealt) % SHOP_ROTATION.size()]
			v.name = str(Shops.DEFS[v.shop].name)
			shops_dealt += 1
		out.append(v)
	_cache[key] = out
	return out

static func _venue(key: String, kind: String, frame: Transform3D, d: Dictionary, n: int) -> Dictionary:
	var names: Array = VENUE_NAMES.get(kind, VENUE_NAMES.get(kind.split("_")[0], ["Lantern Hall"]))
	var v := {key = key, kind = kind, name = names[absi(n+key.hash()) % names.size()] if not names.is_empty() else kind,
		frame = frame, size = ROOM, seats = [], staff = [], patrons = [], district = d.id}
	var drink := "coffee" if kind in ["cafe", "teahouse"] else "beer"
	var add_seat := func(pos: Vector3, yaw: float) -> void:
		v.seats.append({id = "city:%s:%d" % [key, v.seats.size()], pos = pos, yaw = yaw, drink = drink})
	match kind:
		"cafe", "teahouse":
			for t: Vector3 in [Vector3(-5, 0, -1.5), Vector3(0, 0, 0.5), Vector3(5, 0, -1.5)]:
				add_seat.call(t+Vector3(-1.05, 0, 0), -PI*0.5)
				add_seat.call(t+Vector3(1.05, 0, 0), PI*0.5)
			v.staff.append({model = "city_barista" if kind=="cafe" else "city_alien_tall", pos = Vector3(0, 0, 5.0), yaw = 0.0,
				lines = ["Fresh brew, still glowing!", "Moonfoam latte? Best in the city.", "Sit, sit. The cups pour themselves."]})
		"bar", "speakeasy":
			for k in 5: add_seat.call(Vector3(-4.0+k*2.0, 0, 3.0), PI)
			for side: float in [-1.0, 1.0]:
				add_seat.call(Vector3(side*6.2, 0, -2.6), side*PI*0.5)
				add_seat.call(Vector3(side*6.2, 0, -0.6), side*PI*0.5)
			v.staff.append({model = "city_bartender", pos = Vector3(0, 0, 5.0), yaw = 0.0,
				lines = ["Nebula amber on tap!", "Pull up a stool, traveller.", "Mind the robot, he bites."]})
		"noodle":
			for k in 6: add_seat.call(Vector3(-5.0+k*2.0, 0, 3.0), PI)
			v.staff.append({model = "city_noodle_cook", pos = Vector3(0, 0, 5.0), yaw = 0.0,
				lines = ["Hot noodles! Hot noodles!", "Extra comet sauce?", "Slurping is polite here."]})
		"shop_budget", "shop_premium", "shop_curio":
			var keeper: String = {shop_budget = "city_alien_fourarm", shop_premium = "city_noble", shop_curio = "city_alien_moth"}[kind]
			v.staff.append({model = keeper, pos = Vector3(0, 0, 4.8), yaw = 0.0, lines = {
				shop_budget = ["Come in, come in! Bargains for every pocket!", "Cheap and cheerful, that's us!", "Two-for-one on rusty swords!"],
				shop_premium = ["Only the finest gear in Vesperis.", "Polished, enchanted, guaranteed.", "Quality has a price, darling."],
				shop_curio = ["Oddities from beyond the Reach...", "Everything here has a story.", "Touch nothing that hums."]}[kind]})
		"arcade":
			for k in 3: add_seat.call(Vector3(-5.0+k*5.0, 0, -0.5), 0.0)
			v.staff.append({model = "city_robot_tiny", pos = Vector3(5.5, 0, 4.6), yaw = 0.0,
				lines = ["High score! High score!", "Insert one Dot to dream.", "Beep! Play again?"]})
	# Townsfolk already sitting in some of the seats (never the first two).
	for k in range(2, v.seats.size()):
		if rnd(float(key.hash() % 1000)/1000.0, k)<0.35: v.patrons.append(k)
	return v

static func venue(key: String) -> Dictionary:
	for d: Dictionary in DISTRICTS:
		for v: Dictionary in venues(d):
			if v.key==key: return v
	return {}

## Mission 3 uses real existing venues in Lanternheart; these helpers
## derive the positions from the same authored street layout as the renderer.
## The starship-parts merchant stands outside a real general-goods shop,
## so its location follows Lanternheart's actual generated street layout.
static func story_parts_venue() -> Dictionary:
	for v: Dictionary in venues(DISTRICTS[0]):
		if str(v.get("shop", ""))=="general": return v
	for v: Dictionary in venues(DISTRICTS[0]):
		if v.kind=="shop_budget": return v
	return {}

static func story_wizard_venue() -> Dictionary:
	for v: Dictionary in venues(DISTRICTS[0]):
		if str(v.get("shop", ""))=="wizard": return v
	return {}

static func story_pub_venue() -> Dictionary:
	var wizard := story_wizard_venue()
	var best := {}
	var distance := INF
	for v: Dictionary in venues(DISTRICTS[0]):
		if str(v.kind)!="bar": continue
		var d := (v.frame.origin as Vector3).distance_to(wizard.frame.origin) if not wizard.is_empty() else 0.0
		if d<distance:
			distance = d
			best = v
	return best

static func story_venue_door(v: Dictionary) -> Vector3:
	if v.is_empty(): return Vector3.INF
	var frame: Transform3D = v.frame
	return (planet().center as Vector3)+frame*Vector3(0, 0, -float(v.size.z)*0.5-3.0)

static func story_pub_tap() -> Vector3:
	var v := story_pub_venue()
	if v.is_empty(): return Vector3.INF
	var frame: Transform3D = v.frame
	return (planet().center as Vector3)+frame*Vector3(-2.5, 1.3, 4.1)

## A seat by id: {pos, yaw, drink, stand} in world space, or {}.
static func seat(id: String) -> Dictionary:
	var parts := id.split(":")
	if parts.size()!=3: return {}
	var v := venue(parts[1])
	if v.is_empty(): return {}
	var k := int(parts[2])
	if k<0 or k>=v.seats.size(): return {}
	var s: Dictionary = v.seats[k]
	if str(s.id)!=id: return {}
	var stool: bool = v.kind in ["bar", "speakeasy", "noodle"] and absf(float(s.pos.z)-3.0)<0.2
	var booth: bool = v.kind in ["bar", "speakeasy"] and not stool
	var hip := 0.85 if stool else 0.3 if booth else 0.45
	var table := 1.1 if stool else 0.9 if booth else 1.0
	var world := Transform3D((v.frame as Transform3D).basis, (planet().center as Vector3)+(v.frame as Transform3D).origin)
	return {id = id, pos = world*((s.pos as Vector3)+Vector3(0, hip, 0)), yaw = float(s.yaw), drink = s.drink,
		cup = world*((s.pos as Vector3)+Vector3(0, table+0.15, -0.55).rotated(Vector3.UP, float(s.yaw))),
		stand = world*((s.pos as Vector3)+Vector3(0, 0.1, -0.9).rotated(Vector3.UP, float(s.yaw))), basis = world.basis, venue = v.key}

# --- The Lantern Spire --------------------------------------------------------------------------

## The Spire's ground frame (planet space): its middle, -Z the hall's door.
static func spire_frame() -> Transform3D:
	if _cache.has("spire"): return _cache.spire
	var d := district(SPIRE_DISTRICT)
	var spot: Dictionary = CityTown.plan(d).spire
	var out := CityTown.frame(d, spot.at, spot.forward)
	_cache.spire = out
	return out

## World transform of the Spire's ground frame.
static func spire_world() -> Transform3D:
	return Transform3D(spire_frame().basis, (planet().center as Vector3)+spire_frame().origin)

## The attendants beside the lift doors (both face -Z, toward whoever comes):
## in the hall at the shaft's foot, in the orb at the lift column.
static func attendant(orb: bool) -> Vector3:
	return spire_world()*(Vector3(2.4, ORB_FLOOR, -2.6) if orb else Vector3(2.6, 0, -5.6))

## Where the attendant leaves you: before the lift doors in the orb (up) or the hall (down).
static func orb_spot(up: bool) -> Vector3:
	return spire_world()*(Vector3(0, ORB_FLOOR+0.3, -3.6) if up else Vector3(0, 0.3, -6.2))

## The orb's stools: six at the curved bar on its +Z side (facing the bar),
## seven along the window ledge round its -Z side (facing the view).
## {id, pos (Spire frame), yaw, drink}.
const ORB_BAR := 9.6  # the bar's radius (its inside edge; the keeper stands behind it)
static func orb_seats() -> Array:
	var out: Array = []
	for k in 6:
		var a := deg_to_rad(52.0+k*15.2)
		out.append({id = "city:orb:%d" % out.size(), pos = Vector3(cos(a)*(ORB_BAR-1.3), ORB_FLOOR, sin(a)*(ORB_BAR-1.3)), yaw = -a-PI*0.5, drink = "beer"})
	for k in 7:
		var a := deg_to_rad(205.0+k*21.7)
		if absf(a-PI*1.5)<0.25: continue  # the lift column's way out
		out.append({id = "city:orb:%d" % out.size(), pos = Vector3(cos(a)*11.4, ORB_FLOOR, sin(a)*11.4), yaw = -a-PI*0.5, drink = "coffee" if k % 2 else "beer"})
	return out

## An orb seat by id, resolved like a venue's ("city:orb:<n>").
static func orb_seat(id: String) -> Dictionary:
	var parts := id.split(":")
	if parts.size()!=3 or parts[1]!="orb" or not parts[2].is_valid_int(): return {}
	var k := int(parts[2])
	var list := orb_seats()
	if k<0 or k>=list.size(): return {}
	var s: Dictionary = list[k]
	var world := spire_world()
	return {id = id, pos = world*((s.pos as Vector3)+Vector3(0, 0.85, 0)), yaw = float(s.yaw), drink = s.drink,
		cup = world*((s.pos as Vector3)+Vector3(0, 1.24, -0.65).rotated(Vector3.UP, float(s.yaw))),
		stand = world*((s.pos as Vector3)+Vector3(0, 0.1, 0.9).rotated(Vector3.UP, float(s.yaw))), basis = world.basis, venue = "orb"}

static func any_seat(id: String) -> Dictionary:
	if id.begins_with("city:orb:"): return orb_seat(id)
	return seat(id)

# --- People and traffic (time-driven, the same for everyone) ---------------------------------

## Sidewalk walks of a town: up one side of each street and back down the
## other, as world points (a walker pauses at each).
static func walk_loops(d: Dictionary) -> Array:
	var key := "loops:"+str(d.id)
	if _cache.has(key): return _cache[key]
	var out: Array = []
	var center := (planet().center as Vector3)
	for street: Dictionary in CityTown.plan(d).streets:
		var pts: PackedVector2Array = street.pts
		var off := float(street.half)+CityTown.WALK*0.5
		var loop: Array[Vector3] = []
		for side: float in [1.0, -1.0]:
			var last := Vector2(1e9, 1e9)
			for q in pts.size():
				var k := q if side>0.0 else pts.size()-1-q
				var along := (pts[mini(k+1, pts.size()-1)]-pts[maxi(k-1, 0)]).normalized()
				var p := pts[k]+Vector2(-along.y, along.x)*off*side
				if q>0 and q<pts.size()-1 and p.distance_to(last)<9.0: continue
				last = p
				loop.append(center+CityTown.dir(d, p)*(radius()+0.05))
		if loop.size()>=4: out.append(loop)
	_cache[key] = out
	return out

## Walkers of a district: {model, loop, phase, speed, pause}.
const FOLK := ["city_courier", "city_noble", "city_guard", "city_mechanic", "city_kid", "city_dancer", "city_elder", "city_vendor",
	"city_alien_tall", "city_alien_fourarm", "city_alien_squid", "city_alien_frog", "city_alien_moth", "city_alien_crystal",
	"city_alien_mushroom", "city_robot_butler", "city_robot_tiny", "npc_villager", "npc_traveler", "npc_magician"]

static func walkers(d: Dictionary) -> Array:
	var key := "walkers:"+str(d.id)
	if _cache.has(key): return _cache[key]
	var out: Array = []
	var loops := walk_loops(d)
	for k in clampi(int(CityTown.plan(d).houses.size()/8), 16, 70):
		var s := rnd(float(DISTRICTS.find(d)+1)*0.37, k)
		out.append({id = k, model = FOLK[int(rnd(s, 3)*FOLK.size()) % FOLK.size()], loop = int(rnd(s, 1)*loops.size()) % loops.size(),
			phase = rnd(s, 2), speed = 1.1+rnd(s, 4)*0.7, reverse = rnd(s, 5)<0.5, chat = rnd(s, 6)<0.3})
	_cache[key] = out
	return out

## Where a walker is at time `t` (seconds, server clock): [world position, forward].
static func walker_pose(d: Dictionary, w: Dictionary, t: float) -> Array:
	var loop: Array = walk_loops(d)[w.loop]
	var count := loop.size()
	var route_key := "walk_lengths:%s:%d" % [str(d.id), int(w.loop)]
	if not _cache.has(route_key):
		var lengths := PackedFloat32Array()
		var total := 0.0
		for k in count:
			var length := (loop[k] as Vector3).distance_to(loop[(k+1) % count])
			lengths.append(length)
			total += length
		_cache[route_key] = {lengths = lengths, total = total}
	var route: Dictionary = _cache[route_key]
	var lengths: PackedFloat32Array = route.lengths
	var total: float = route.total
	# Walk, with a short stop at a few corners (looking around, chatting).
	var stop := (3.0 if w.chat else 1.2)*4.0/count
	var cycle := total/float(w.speed)+stop*count
	var at := fposmod(t+float(w.phase)*cycle, cycle)
	if w.reverse: at = cycle-at
	for k in count:
		var seg := lengths[k]/float(w.speed)
		if at<seg+stop:
			var a: Vector3 = loop[k]
			var b: Vector3 = loop[(k+1) % count]
			var f := clampf(at/seg, 0.0, 1.0)
			var pos := a.lerp(b, f)
			var c := (planet().center as Vector3)
			pos = c+(pos-c).normalized()*(radius()+CityRoads.KERB)
			var fwd := (b-a).normalized()*(-1.0 if w.reverse else 1.0)
			return [pos, fwd, at>seg]
		at -= seg+stop
	return [loop[0], Vector3.FORWARD, true]

## Traffic lanes: {kind, points (world), altitude, speed, count, models}: cabs
## and carts along each town's ring road, avenues and crescent lanes.
static func lanes() -> Array:
	if _cache.has("lanes"): return _cache.lanes
	var out: Array = []
	var p := planet()
	var center := (p.center as Vector3)
	for d: Dictionary in DISTRICTS:
		var streets: Array = CityTown.plan(d).streets
		for n in streets.size():
			var st: Dictionary = streets[n]
			if st.kind=="lane": continue
			var dirs: Array[Vector3] = []
			var pts: PackedVector2Array = st.pts
			for q in range(0, pts.size(), 2): dirs.append(CityTown.dir(d, pts[q]))
			if (pts.size()-1) % 2: dirs.append(CityTown.dir(d, pts[pts.size()-1]))
			if dirs.size()<3: continue
			var dk := DISTRICTS.find(d)*1000+n
			out.append({kind = "ground", dirs = dirs, altitude = 0.0, side = 1.7, speed = 6.0+rnd(0.3, dk)*3.0, count = maxi(1, dirs.size()/10),
				models = ["ground_cab", "ground_truck", "ground_tram", "ground_cab"], seed = dk})
	for lane: Dictionary in out:
		var pts: Array[Vector3] = []
		for dir: Vector3 in lane.dirs: pts.append(center+dir*(radius()+float(lane.altitude)))
		lane.points = pts
		var total := 0.0
		var lengths := PackedFloat32Array()
		var ends := PackedFloat32Array()
		var directions := PackedVector3Array()
		var bounds := AABB(pts[0], Vector3.ZERO)
		for k in pts.size()-1:
			var segment := pts[k+1]-pts[k]
			var length := segment.length()
			lengths.append(length)
			directions.append(segment / maxf(length, 0.01))
			total += length
			ends.append(total)
			bounds = bounds.expand(pts[k+1])
		var phases := PackedFloat32Array()
		for k in int(lane.count):
			phases.append(total*2.0*float(k)/int(lane.count)+rnd(float(lane.seed)*0.01,k)*12.0)
		lane.length = total
		lane.segment_lengths = lengths
		lane.segment_ends = ends
		lane.segment_directions = directions
		lane.phases = phases
		lane.bounds = bounds.grow(850.0)
		lane.center = center
		lane.radius = radius()

	_cache.lanes = out
	return out

## A vehicle on a lane at time t: [position, forward]. Lanes are driven both
## ways (out and back on either side of the line), so traffic never ends.
static func vehicle_pose(lane: Dictionary, k: int, t: float) -> Array:
	var pts: Array = lane.points
	var length := float(lane.length)
	var s := fposmod(t*float(lane.speed)+float(lane.phases[k]),length*2.0)
	var forward := s<length
	var along := s if forward else length*2.0-s
	var ends: PackedFloat32Array = lane.segment_ends
	var i := mini(ends.bsearch(along), pts.size()-2)
	var start := 0.0 if i==0 else float(ends[i-1])
	var f := clampf((along-start)/maxf(float(lane.segment_lengths[i]),0.01),0.0,1.0)
	var pos := (pts[i] as Vector3).lerp(pts[i+1],f)
	var center: Vector3 = lane.center
	var up := (pos-center).normalized()
	var dir: Vector3 = lane.segment_directions[i]*(1.0 if forward else -1.0)
	pos = center+up*(float(lane.radius)+float(lane.altitude))
	pos += dir.cross(up).normalized()*float(lane.side)
	if lane.kind=="sky": pos += up*sin(t*0.7+k)*0.6
	return [pos, dir]

## Lamps along every street, either side in turn, benches, bins and planters
## between them and lantern strings across: [prop, frame, local at, yaw].
static func street_furniture(data: Dictionary) -> Array:
	var key := "furniture:"+str(data.id)
	if _cache.has(key): return _cache[key]
	var out: Array = []
	var streets: Array = CityTown.plan(data).streets
	for n in streets.size():
		var st: Dictionary = streets[n]
		var pts: PackedVector2Array = st.pts
		var total := 0.0
		for q in pts.size()-1: total += pts[q].distance_to(pts[q+1])
		var s := 7.0
		var k := 0
		while s<total-7.0:
			var at := 0.0
			var q := 0
			while q<pts.size()-2 and at+pts[q].distance_to(pts[q+1])<s:
				at += pts[q].distance_to(pts[q+1])
				q += 1
			var along := (pts[q+1]-pts[q]).normalized()
			var p := pts[q].lerp(pts[q+1], clampf((s-at)/maxf(0.01, pts[q].distance_to(pts[q+1])), 0.0, 1.0))
			var frame := CityTown.frame(data, p, along)  # -Z along the street, +X its right side
			var side := 1.0 if k % 2==0 else -1.0
			var edge := float(st.half)+CityTown.WALK*0.62
			var face := PI*0.5 if side>0 else -PI*0.5  # toward the street
			out.append(["street_lamp", frame, Vector3(side*edge, 0.02, 0), face])
			var roll := rnd(0.17, n*1000+k)
			var other := Vector3(-side*edge, 0.02, 2.5)
			if roll<0.18: out.append(["bench", frame, other+Vector3(-side*0.3, 0, 0), -face])
			elif roll<0.28: out.append(["planter", frame, other])
			elif roll<0.34: out.append(["trash_bin", frame, other])
			if k % 3==1 and st.kind!="lane": out.append(["lantern_span", frame*Transform3D(Basis(Vector3.UP, PI*0.5), Vector3.ZERO), Vector3.ZERO])
			s += 14.0
			k += 1
	_cache[key] = out
	return out

static func bench_key(district_id: String, pose: Transform3D) -> String:
	var at := pose.origin.snapped(Vector3.ONE*0.01)
	return "citybench:%s:%s" % [district_id, str(at)]

## All bench frames are data, including those whose visible district is not streamed.
static func bench_seat(id: String) -> Dictionary:
	var d := district(id.get_slice(":", 1))
	if d.is_empty(): return {}
	var cache_key := "bench_seats:"+str(d.id)
	if not _cache.has(cache_key):
		var seats := {}
		for pose: Transform3D in bench_frames(d):
			for slot in 2:
				var key := bench_key(str(d.id), pose)+":"+str(slot)
				var frame := pose*Transform3D(Basis.IDENTITY, Vector3((slot-0.5)*2.2*0.48, 0, -0.08))
				var center: Vector3 = planet().center
				seats[key] = {kind = "seat", key = key, pos = center+frame*Vector3(0, 0.05, 0), basis = frame.basis, yaw = 0.0,
					stand = center+frame*Vector3(0, 0.05, -1.25), drink = "beer"}
		_cache[cache_key] = seats
	return _cache[cache_key].get(id, {})

static func bench_frames(d: Dictionary) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var port := district_frame(d)
	for row in 2:
		for k in 4: out.append(port*Transform3D(Basis.IDENTITY, Vector3(-9.0+k*6.0, 0.04, -17.0+row*4.0)))
	var plan := CityTown.plan(d)
	for spot: Array in plan.plazas:
		var frame := CityTown.frame(d, spot[0], Vector2(0, -1))
		var bench := minf(10.0, minf(13.4, float(spot[1])*0.75)*0.75)  # as CityDistrict._plaza
		for k in 8:
			if k % 2==0: continue
			var a := TAU*k/8.0+0.39
			out.append(frame*Transform3D(Basis(Vector3.UP, -a+PI*0.5), Vector3(cos(a)*bench, 0.1, sin(a)*bench)))
	for role: String in ["parks", "lakes"]:
		for spot: Array in plan[role]:
			var block := CityTown.green_block(d, spot, "lake" if role=="lakes" else "park")
			var frame: Transform3D = block.frame
			var seed := rnd(float(d.seed), int((spot[0] as Vector2).length()))
			var lot := ROAD+WALK+0.8
			var lake: bool = role=="lakes"
			var spots := CityArt.pack(block, lot+1.5, seed, 3, 6.0, 60.0) if lake else CityArt.pack(block, lot, seed, 4, 5.0, 40.0)
			for k in spots.size():
				var at: Vector2 = spots[k][0]
				var rr := float(spots[k][1])+(2.6 if lake else 0.0)
				var count := 6 if lake else 4
				for b in count:
					if b % 2!=0: continue
					var a := TAU*(b+0.5)/count+k
					var p := at+Vector2.from_angle(a)*(rr+1.6 if lake else rr*0.85)
					if CityRoads.field(block, p)<lot+0.5: continue
					out.append(frame*Transform3D(Basis(Vector3.UP, -a+PI*0.5 if lake else -a-PI*0.5), Vector3(p.x, CityRoads.drop(p)+0.15, p.y)))
	for item: Array in street_furniture(d):
		if item[0]=="bench": out.append((item[1] as Transform3D)*Transform3D(Basis(Vector3.UP, float(item[3]) if item.size()>3 else 0.0), item[2]))
	return out
