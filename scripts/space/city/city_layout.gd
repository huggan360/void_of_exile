class_name CityLayout
## Vesperis, the Lantern City: a planet that is one city. Data only, the same
## on the server and every client (no randomness that is not seeded here).
##
## The ground is a perfect sphere of streets. A grid of blocks covers it: each
## cube face (equal-angle) is split into N x N cells, roads run along the cell
## edges and every cell holds a block of towers. Three districts around the
## three spaceports are built in full: cafes and bars you can sit in, shops,
## plazas with fountains, elevator skyscrapers joined by a sky bridge, and a
## secret service tunnel. Everything else is skyline.
##
## Every building piece stands in its own tangent frame (planet space, Y up
## the local normal), so floors are level wherever they are.
const ID := "vesperis"
const N := 28
const ROAD := 6.0  # half width of the carriageway (m)
const WALK := 4.0  # sidewalk width on each side
const FACES: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
## District: the 2 x 2 cells inside `corner` (cells corner-1..corner) are its spaceport; the
## 6 x 6 cells around it are built in full.
const DISTRICTS := [
	{id = "lanternheart", name = "Lanternheart", port = "Lanternheart Spaceport", face = 2, corner = Vector2i(14, 14), theme = "lantern",
		tower = 190.0, tint = "ffb86a", neon = "ff6eb4"},
	{id = "rosewater", name = "Rosewater", port = "Rosewater Docks", face = 2, corner = Vector2i(6, 21), theme = "rose",
		tower = 150.0, tint = "ff9ccf", neon = "6af0e0"},
	{id = "brasswork", name = "Brasswork Heights", port = "Brasswork Skyport", face = 2, corner = Vector2i(22, 7), theme = "brass",
		tower = 165.0, tint = "ffcf6a", neon = "9a8aff"},
]
## Roles of a district's 6 x 6 cells by local index (li, lj); the 2 x 2 middle is the port.
const ROLES := {
	Vector2i(0, 0): "plaza", Vector2i(5, 5): "plaza", Vector2i(2, 0): "plaza",
	Vector2i(4, 2): "elevator", Vector2i(4, 3): "elevator",
	Vector2i(1, 1): "venues", Vector2i(1, 2): "venues", Vector2i(1, 3): "venues", Vector2i(1, 4): "venues",
	Vector2i(2, 1): "venues", Vector2i(3, 1): "venues", Vector2i(2, 4): "venues", Vector2i(3, 4): "venues",
	Vector2i(4, 1): "venues", Vector2i(4, 4): "venues", Vector2i(0, 3): "secret",
}
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
	lobby = ["Grand Lobby"],
}
## Venue room in its own frame: x across the front, -z the street side (door), y up.
const ROOM := Vector3(16.0, 5.2, 12.0)
const PODIUM := 30.0  # podium footprint (m), centred in the lot
const PODIUM_TALL := 9.0
## Elevator skyscrapers: footprint, floor heights served (lobby first) and their kinds.
const TOWER := 26.0
const FLOOR_TALL := 5.5
const ELEVATOR_SPEED := 9.0
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

## The district a cell belongs to (or {}), with the cell's local index.
static func district_of(face: int, i: int, j: int) -> Dictionary:
	for d: Dictionary in DISTRICTS:
		if face!=int(d.face): continue
		var c: Vector2i = d.corner
		var li := i-(c.x-3)
		var lj := j-(c.y-3)
		if li>=0 and li<6 and lj>=0 and lj<6: return {district = d, local = Vector2i(li, lj)}
	return {}

static func role(face: int, i: int, j: int) -> String:
	var at := district_of(face, i, j)
	if at.is_empty(): return "skyline"
	var local: Vector2i = at.local
	if local.x in [2, 3] and local.y in [2, 3]: return "port"
	return ROLES.get(local, "district")

static func district(id: String) -> Dictionary:
	for d: Dictionary in DISTRICTS:
		if d.id==id: return d
	return {}

## The district's centre (the port's middle) frame in planet space.
static func district_frame(d: Dictionary) -> Transform3D:
	return frame_at(int(d.face), float(d.corner.x)/N*2.0-1.0, float(d.corner.y)/N*2.0-1.0)

## Every cell of a district: [{cell, local, role}].
static func district_cells(d: Dictionary) -> Array:
	var out: Array = []
	var c: Vector2i = d.corner
	for lj in 6:
		for li in 6:
			var i := c.x-3+li
			var j := c.y-3+lj
			out.append({cell = cell(int(d.face), i, j), local = Vector2i(li, lj), role = role(int(d.face), i, j)})
	return out

# --- Spaceports -------------------------------------------------------------------------

## A port's landing pads (planet space frames on the ground, ship forward -Z):
## three side by side across the port, the terminal behind them.
static func pads(d: Dictionary) -> Array[Transform3D]:
	var center := district_frame(d)
	var out: Array[Transform3D] = []
	for k in 3:
		var local := Vector3((k-1)*32.0, 0, 8.0)
		# The visible port deck is flat, so its pads share the deck frame.
		var frame := center*Transform3D(Basis.IDENTITY, local+Vector3.UP*0.4)
		out.append(frame)
	return out

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

## Every enterable room of a district: shops, cafes, bars, lobbies, the secret bar.
## {key, kind, name, frame (planet space, the room's floor centre, -Z the door side),
## size, seats: [{id, pos, yaw, drink}], staff: [{model, pos, yaw, lines}], patrons}
static func venues(d: Dictionary) -> Array:
	var key := "venues:"+str(d.id)
	if _cache.has(key): return _cache[key]
	var out: Array = []
	var n := 0
	for item: Dictionary in district_cells(d):
		var c: Dictionary = item.cell
		var frame: Transform3D = c.frame
		match str(item.role):
			"venues":
				for side: int in [-1, 1]:
					var kind: String = VENUE_CYCLE[(n+DISTRICTS.find(d)*3) % VENUE_CYCLE.size()]
					n += 1
					# On the street side of the podium, door outward.
					var at := frame*Vector3(0, 0, side*(PODIUM*0.5-ROOM.z*0.5))
					var dir := at.normalized()
					var room := _tangent(dir, frame.basis.z*-side)
					out.append(_venue("%s_%d_%d_%d" % [d.id, item.local.x, item.local.y, side+1], kind, room, d, n))
			"elevator":
				var room := _tangent(frame.origin.normalized(), frame.basis.z)
				var v := _venue("%s_%d_%d_lobby" % [d.id, item.local.x, item.local.y], "lobby", room, d, n)
				v.size = Vector3(TOWER-2.0, FLOOR_TALL, TOWER-2.0)
				out.append(v)
			"secret":
				# The hidden bar at the end of the service tunnel, deep in the block.
				var at := frame*Vector3(0, 0, 4.0)
				var room := _tangent(at.normalized(), frame.basis.z)
				var v := _venue("%s_secret" % d.id, "speakeasy", room, d, n)
				v.name = "The Hidden Valve"
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
			v.staff.append({model = "city_barista" if kind=="cafe" else "city_alien_tall", pos = Vector3(0, 0, 5.0), yaw = PI,
				lines = ["Fresh brew, still glowing!", "Moonfoam latte? Best in the city.", "Sit, sit. The cups pour themselves."]})
		"bar", "speakeasy":
			for k in 5: add_seat.call(Vector3(-4.0+k*2.0, 0, 3.0), PI)
			for side: float in [-1.0, 1.0]:
				add_seat.call(Vector3(side*6.2, 0, -2.6), side*PI*0.5)
				add_seat.call(Vector3(side*6.2, 0, -0.6), side*PI*0.5)
			v.staff.append({model = "city_bartender", pos = Vector3(0, 0, 5.0), yaw = PI,
				lines = ["Nebula amber on tap!", "Pull up a stool, traveller.", "Mind the robot, he bites."]})
		"noodle":
			for k in 6: add_seat.call(Vector3(-5.0+k*2.0, 0, 3.0), PI)
			v.staff.append({model = "city_noodle_cook", pos = Vector3(0, 0, 5.0), yaw = PI,
				lines = ["Hot noodles! Hot noodles!", "Extra comet sauce?", "Slurping is polite here."]})
		"shop_budget", "shop_premium", "shop_curio":
			var keeper: String = {shop_budget = "city_alien_fourarm", shop_premium = "city_noble", shop_curio = "city_alien_moth"}[kind]
			v.staff.append({model = keeper, pos = Vector3(0, 0, 4.8), yaw = PI, lines = {
				shop_budget = ["Come in, come in! Bargains for every pocket!", "Cheap and cheerful, that's us!", "Two-for-one on rusty swords!"],
				shop_premium = ["Only the finest gear in Vesperis.", "Polished, enchanted, guaranteed.", "Quality has a price, darling."],
				shop_curio = ["Oddities from beyond the Reach...", "Everything here has a story.", "Touch nothing that hums."]}[kind]})
		"arcade":
			for k in 3: add_seat.call(Vector3(-5.0+k*5.0, 0, -0.5), 0.0)
			v.staff.append({model = "city_robot_tiny", pos = Vector3(5.5, 0, 4.6), yaw = PI,
				lines = ["High score! High score!", "Insert one Dot to dream.", "Beep! Play again?"]})
		"lobby":
			v.staff.append({model = "city_robot_butler", pos = Vector3(-6.0, 0, -4.0), yaw = PI*0.5,
				lines = ["Welcome to the tower.", "The lift is just ahead.", "Mind the view from the sky bar!"]})
	if kind=="speakeasy":
		v.staff[0].model = "city_mechanic"
		v.staff[0].lines = ["You found us. Shh.", "Steam-brewed, valve-poured.", "Nobody knows this place. Keep it so."]
	# Townsfolk already sitting in some of the seats (never the first two).
	for k in range(2, v.seats.size()):
		if rnd(float(key.hash() % 1000)/1000.0, k)<0.35: v.patrons.append(k)
	return v

static func venue(key: String) -> Dictionary:
	for d: Dictionary in DISTRICTS:
		for v: Dictionary in venues(d):
			if v.key==key: return v
	return {}

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
	var hip := 0.65 if stool else 0.1 if booth else 0.25
	var table := 1.1 if stool else 0.9 if booth else 1.0
	var world := Transform3D((v.frame as Transform3D).basis, (planet().center as Vector3)+(v.frame as Transform3D).origin)
	return {id = id, pos = world*((s.pos as Vector3)+Vector3(0, hip, 0)), yaw = float(s.yaw), drink = s.drink,
		cup = world*((s.pos as Vector3)+Vector3(0, table+0.15, -0.55).rotated(Vector3.UP, float(s.yaw))),
		stand = world*((s.pos as Vector3)+Vector3(0, 0.1, -0.9).rotated(Vector3.UP, float(s.yaw))), basis = world.basis, venue = v.key}

# --- Elevator towers ----------------------------------------------------------------------

## Every elevator: {id, district, frame (planet space at the tower's ground
## centre), height, floors: [{h, kind, name}], shaft (local car centre x/z)}.
static func elevators() -> Array:
	if _cache.has("elevators"): return _cache.elevators
	var out: Array = []
	for d: Dictionary in DISTRICTS:
		for item: Dictionary in district_cells(d):
			if item.role!="elevator": continue
			var c: Dictionary = item.cell
			var frame := _tangent((c.frame as Transform3D).origin.normalized(), (c.frame as Transform3D).basis.z)
			var tall := float(d.tower)-float(item.local.y)*14.0
			var top := snappedf(tall-14.0, FLOOR_TALL)
			out.append({id = out.size(), district = d.id, frame = frame, height = tall, local = item.local,
				floors = [{h = 0.0, kind = "lobby", name = "Lobby"}, {h = 44.0, kind = "garden", name = "Sky Garden and Bridge"},
					{h = 88.0, kind = "residence", name = "Lantern Residences"}, {h = top, kind = "skybar", name = "Sky Bar"}]})
	_cache.elevators = out
	return out

## Seats on an elevator tower's sky bar and garden: like venue seats.
static func tower_seats(e: Dictionary) -> Array:
	var out: Array = []
	var top: float = e.floors[3].h
	for k in 8:
		var a := TAU*k/8.0+0.3
		out.append({id = "city:tower%d:%d" % [e.id, k], pos = Vector3(cos(a)*7.5, top, sin(a)*7.5), yaw = -a-PI*0.5, drink = "beer"})
	for k in 4:
		out.append({id = "city:tower%d:%d" % [e.id, 8+k], pos = Vector3(-8.0+k*5.3, 44.0, 9.0), yaw = PI, drink = "coffee"})
	return out

## Seats of elevator towers resolve like venues ("city:tower<id>:<n>").
static func tower_seat(id: String) -> Dictionary:
	var parts := id.split(":")
	if parts.size()!=3 or not parts[1].substr(5).is_valid_int() or not parts[2].is_valid_int(): return {}
	var index := int(parts[1].substr(5))
	if index<0 or index>=elevators().size(): return {}
	var e: Dictionary = elevators()[index]
	var k := int(parts[2])
	var list := tower_seats(e)
	if k<0 or k>=list.size(): return {}
	var s: Dictionary = list[k]
	if str(s.id)!=id: return {}
	var world := Transform3D((e.frame as Transform3D).basis, (planet().center as Vector3)+(e.frame as Transform3D).origin)
	return {id = id, pos = world*((s.pos as Vector3)+Vector3(0, 0.65 if k<8 else 0.25, 0)), yaw = float(s.yaw), drink = s.drink,
		cup = world*((s.pos as Vector3)+Vector3(0, 1.24 if k<8 else 1.15, -0.65).rotated(Vector3.UP, float(s.yaw))),
		stand = world*((s.pos as Vector3)+Vector3(0, 0.1, -0.9).rotated(Vector3.UP, float(s.yaw))), basis = world.basis, venue = "tower%d" % e.id}

static func any_seat(id: String) -> Dictionary:
	if id.begins_with("city:tower"): return tower_seat(id)
	return seat(id)

## World transform of an elevator tower's ground frame.
static func tower_world(e: Dictionary) -> Transform3D:
	return Transform3D((e.frame as Transform3D).basis, (planet().center as Vector3)+(e.frame as Transform3D).origin)

## The two towers of a district share a sky bridge at their garden floor:
## [a end, b end] in world space (the doors on the facing walls), or [].
static func sky_bridge(d_id: String) -> Array:
	var pair := elevators().filter(func(e: Dictionary) -> bool: return e.district==d_id)
	if pair.size()<2: return []
	var a := tower_world(pair[0])
	var b := tower_world(pair[1])
	var toward := (b.origin-a.origin)
	var la := (a.basis.inverse()*toward)
	la.y = 0
	var lb := (b.basis.inverse()*-toward)
	lb.y = 0
	# Each end in the middle of the facing wall, where its doorway is.
	var ea := a*(_wall_axis(la)*TOWER*0.5+Vector3.UP*44.0)
	var eb := b*(_wall_axis(lb)*TOWER*0.5+Vector3.UP*44.0)
	return [ea, eb, a, b]

## The tower wall (outward axis) a flat direction points at.
static func _wall_axis(v: Vector3) -> Vector3:
	if absf(v.x)>absf(v.z): return Vector3(signf(v.x), 0, 0)
	return Vector3(0, 0, signf(v.z))

# --- People and traffic (time-driven, the same for everyone) ---------------------------------

## Sidewalk loops of a district: rings around its blocks, as world points.
static func walk_loops(d: Dictionary) -> Array:
	var key := "loops:"+str(d.id)
	if _cache.has(key): return _cache[key]
	var out: Array = []
	var center := (planet().center as Vector3)
	for item: Dictionary in district_cells(d):
		if item.role in ["port"]: continue
		var c: Dictionary = item.cell
		var frame: Transform3D = c.frame
		var h: Vector2 = c.half
		var ex := h.x-ROAD-WALK*0.5
		var ez := h.y-ROAD-WALK*0.5
		var loop: Array[Vector3] = []
		for corner: Vector2 in [Vector2(-ex, -ez), Vector2(ex, -ez), Vector2(ex, ez), Vector2(-ex, ez)]:
			loop.append(center+(frame*Vector3(corner.x, 0, corner.y)).normalized()*radius())
		out.append(loop)
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
	for k in 46:
		var s := rnd(float(DISTRICTS.find(d)+1)*0.37, k)
		out.append({id = k, model = FOLK[int(rnd(s, 3)*FOLK.size()) % FOLK.size()], loop = int(rnd(s, 1)*loops.size()) % loops.size(),
			phase = rnd(s, 2), speed = 1.1+rnd(s, 4)*0.7, reverse = rnd(s, 5)<0.5, chat = rnd(s, 6)<0.3})
	_cache[key] = out
	return out

## Where a walker is at time `t` (seconds, server clock): [world position, forward].
static func walker_pose(d: Dictionary, w: Dictionary, t: float) -> Array:
	var loop: Array = walk_loops(d)[w.loop]
	var lengths: Array[float] = []
	var total := 0.0
	for k in 4:
		var l := (loop[k] as Vector3).distance_to(loop[(k+1) % 4])
		lengths.append(l)
		total += l
	# Walk, with a short stop at each corner (looking around, chatting).
	var stop := 3.0 if w.chat else 1.2
	var cycle := total/float(w.speed)+stop*4.0
	var at := fposmod(t+float(w.phase)*cycle, cycle)
	if w.reverse: at = cycle-at
	for k in 4:
		var seg := lengths[k]/float(w.speed)
		if at<seg+stop:
			var a: Vector3 = loop[k]
			var b: Vector3 = loop[(k+1) % 4]
			var f := clampf(at/seg, 0.0, 1.0)
			var pos := a.lerp(b, f)
			var c := (planet().center as Vector3)
			pos = c+(pos-c).normalized()*radius()
			var fwd := (b-a).normalized()*(-1.0 if w.reverse else 1.0)
			return [pos, fwd, at>seg]
		at -= seg+stop
	return [loop[0], Vector3.FORWARD, true]

## Traffic lanes: {kind sky/ground, points (world), altitude, speed, count, models}.
## Ground lanes run along the district roads; sky lanes follow the grid high up,
## stacked in layers, and long skyways join the three districts.
static func lanes() -> Array:
	if _cache.has("lanes"): return _cache.lanes
	var out: Array = []
	var p := planet()
	var center := (p.center as Vector3)
	for d: Dictionary in DISTRICTS:
		var f := int(d.face)
		var c: Vector2i = d.corner
		for k in 7:
			var line := float(c.x-3+k)/N*2.0-1.0
			var row := float(c.y-3+k)/N*2.0-1.0
			for along_u: bool in [true, false]:
				var pts: Array[Vector3] = []
				for s in 13:
					var t := float(c.x-3 if along_u else c.y-3)/N*2.0-1.0+s*(6.0/N*2.0)/12.0
					var dir := face_dir(f, t, row) if along_u else face_dir(f, line, t)
					pts.append(dir)
				var dk := DISTRICTS.find(d)*100+k*2+(1 if along_u else 0)
				if k!=3:  # the middle lines cross the port: no street traffic there
					out.append({kind = "ground", dirs = pts, altitude = 0.0, side = 2.6, speed = 9.0+rnd(0.3, dk)*3.0, count = 3,
						models = ["ground_cab", "ground_truck", "ground_tram", "ground_cab"], seed = dk})
				for layer in 3:
					if (k+layer) % 2==1: continue
					out.append({kind = "sky", dirs = pts, altitude = 34.0+layer*26.0+rnd(0.7, dk)*6.0, side = 3.5, speed = 16.0+layer*5.0,
						count = 4+layer, seed = dk*7+layer,
						models = ["sky_taxi", "sky_sedan", "sky_sports", "sky_van", "sky_police", "sky_bike", "sky_bus", "sky_hauler", "sky_gondola"]})
	# Skyways between the districts (great circles), high and busy.
	for a in DISTRICTS.size():
		var b := (a+1) % DISTRICTS.size()
		var da := district_frame(DISTRICTS[a]).origin.normalized()
		var db := district_frame(DISTRICTS[b]).origin.normalized()
		var pts: Array[Vector3] = []
		for s in 25: pts.append(da.slerp(db, s/24.0))
		out.append({kind = "sky", dirs = pts, altitude = 120.0, side = 5.0, speed = 32.0, count = 14, seed = 900+a,
			models = ["sky_bus", "sky_taxi", "sky_hauler", "sky_sedan", "sky_sports", "sky_gondola"]})
	for lane: Dictionary in out:
		var pts: Array[Vector3] = []
		for dir: Vector3 in lane.dirs: pts.append(center+dir*(radius()+float(lane.altitude)))
		lane.points = pts
		var total := 0.0
		for k in pts.size()-1: total += pts[k].distance_to(pts[k+1])
		lane.length = total
	_cache.lanes = out
	return out

## A vehicle on a lane at time t: [position, forward]. Lanes are driven both
## ways (out and back on either side of the line), so traffic never ends.
static func vehicle_pose(lane: Dictionary, k: int, t: float) -> Array:
	var pts: Array = lane.points
	var length := float(lane.length)
	var count := int(lane.count)
	var s := fposmod(t*float(lane.speed)+length*2.0*float(k)/count+rnd(float(lane.seed)*0.01, k)*12.0, length*2.0)
	var forward := s<length
	var along := s if forward else length*2.0-s
	var i := 0
	while i<pts.size()-2 and along>(pts[i] as Vector3).distance_to(pts[i+1]):
		along -= (pts[i] as Vector3).distance_to(pts[i+1])
		i += 1
	var a: Vector3 = pts[i]
	var b: Vector3 = pts[i+1]
	var f := clampf(along/maxf(a.distance_to(b), 0.01), 0.0, 1.0)
	var pos := a.lerp(b, f)
	var up := (pos-(planet().center as Vector3)).normalized()
	var dir := (b-a).normalized()*(1.0 if forward else -1.0)
	pos = (planet().center as Vector3)+up*(radius()+float(lane.altitude))
	pos += dir.cross(up).normalized()*float(lane.side)
	if lane.kind=="sky": pos += up*sin(t*0.7+k)*0.6
	return [pos, dir]
