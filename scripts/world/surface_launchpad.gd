class_name SurfaceLaunchpad
extends Node3D
## The Skyward Launch Pad on the Surface, south of Hearthwick (the "launchpad"
## landmark; the Surface baker levels, paves and clears its ground): a
## battleship moored east-west in a timber cradle, sunk into the earth and
## fenced in, a stone boarding tower whose stair climbs to a gangway onto the
## deck, and the shipwright who sells you one (500 Dots) or takes one out of
## your fleet.
## Space opens once the Theory of Everything is told.
##
## Nobody walks around the hull: step up to the fence anywhere, or climb the
## tower and cross the gangway, to board; the hatch inside brings you back out
## by the gate (ARRIVAL).
## The docked hull and walk-in rooms are shared with Space through SurfaceShipWorld.
## Launch belongs to whoever occupies the pilot seat, using Space.
const SHIP_REST := Vector3(-12.0, SpaceShip.LANDED_HEIGHT-2.6, 4.0)
## The bow points west; the starboard hatch faces the gate and the city.
const SHIP_BASIS := Basis(Vector3(0, 0, -1), Vector3.UP, Vector3(1, 0, 0))
const ARRIVAL := Vector3(-6.0, 0.2, -13.5)  # outside the gate, where you stand after landing
## The fence around the moored ship (pad space, x/z), closed.
const FENCE: Array[Vector2] = [Vector2(-33, -9.5), Vector2(12, -9.5), Vector2(15.5, -3), Vector2(15.5, 11),
	Vector2(12, 16), Vector2(-33, 16), Vector2(-44, 7), Vector2(-44, 1)]
const GATE := Vector2(-6, -9.5)
## The boarding tower (pad space x/z): a stone core 2 * CORE wide, a stair
## STAIR wide round three of its sides in flights of STEPS steps, and the
## balcony at BALCONY (the deck's height) the gangway leaves from.
const TOWER := Vector2(-20.0, -16.0)
const CORE := 2.2
const STAIR := 1.3
const STEPS := 10
const RISE := STEPS*0.25
const BALCONY := RISE*3.0
const STONE_TOP := BALCONY
const ROOM := 3.2
const GANGWAY_HALF := 0.75

const OAK := Color("8a5a36")
const OAK_DARK := Color("5e3b26")
const BIRCH := Color("c9a274")
const STONE := Color("7d7480")
const IRON := Color("3a3540")
const BRASS := Color("d9ac60")
const ROOF := Color("4f7f78")
const ROOF_RED := Color("a4503f")
const EARTH := Color("6b4a33")
const MOSS := Color("5e8a45")
const FLOWERS: Array[Color] = [Color("f2a8d0"), Color("ffe08a"), Color("b9a2f2"), Color("f7f2e8")]

var world: GameWorld
var unlocked := false
var owned := false
var _wright: InteractionTarget
var _fence: FenceBoarding
var _gangway_gate: InteractionTarget
var _busy := false
var _rng := RandomNumberGenerator.new()

## Boarding from anywhere along the fence: the card follows the nearest point.
class FenceBoarding extends InteractionTarget:
	var pad: SurfaceLaunchpad

	func _init() -> void:
		follows_player = true

	func available(player: Node3D) -> bool:
		if not enabled or not is_instance_valid(player) or not is_inside_tree(): return false
		var local := pad.to_local(player.global_position)
		var near := SurfaceLaunchpad.nearest_on_fence(Vector2(local.x, local.z))
		position = Vector3(near.x, local.y+1.0, near.y)
		return near.distance_to(Vector2(local.x, local.z))<=reach

	func focus() -> Node3D:
		return self

static func nearest_on_fence(at: Vector2) -> Vector2:
	var best := FENCE[0]
	for i in FENCE.size():
		var a := FENCE[i]
		var b := FENCE[(i+1) % FENCE.size()]
		var t := clampf((at-a).dot(b-a)/(b-a).length_squared(), 0.0, 1.0)
		var p := a.lerp(b, t)
		if p.distance_squared_to(at)<best.distance_squared_to(at): best = p
	return best

func build(p_world: GameWorld) -> void:
	world = p_world
	add_to_group("surface_ports")
	_rng.seed = 7741
	var art := NexusStation.Brush.new(self, false, 900.0)
	_earthworks(art)
	_cradle(art)
	_fence_art(art)
	_gate(art)
	_boarding_tower(art)
	_stall(art, Vector3(10.5, 0, -14.5))
	art.finish()
	var sign := SignBoard.make("BOARDING", "plank", "helm", Color("ffe0a0"), 0.7)
	sign.position = Vector3(GATE.x, _ground(GATE)+3.75, GATE.y-0.3)
	sign.rotation.y = PI
	add_child(sign)
	var wright := CreatureModel.new("city_mechanic")
	wright.position = Vector3(10.5, 0, -13.1)
	wright.rotation.y = PI
	add_child(wright)
	_wright = InteractionTarget.new()
	_wright.title = "Shipwright Odessa"
	_wright.reach = 4.5
	_wright.position = Vector3(0, 1.0, 0.4)
	wright.add_child(_wright)
	_wright.activated.connect(_on_wright)
	_fence = FenceBoarding.new()
	_fence.pad = self
	_fence.title = "Your battleship"
	_fence.reach = 3.0
	add_child(_fence)
	_fence.activated.connect(_on_launch)
	_gangway_gate = InteractionTarget.new()
	_gangway_gate.title = "Your battleship"
	_gangway_gate.reach = 2.5
	_gangway_gate.position = gangway_end()+Vector3(0, 1.0, -0.6)
	add_child(_gangway_gate)
	_gangway_gate.activated.connect(_on_launch)
	for at: Vector3 in [Vector3(-8, 7.0, -12), Vector3(SHIP_REST.x, 9.0, SHIP_REST.z), Vector3(-34, 6.0, -6),
			Vector3(TOWER.x, BALCONY+2.2, TOWER.y+CORE+1.5)]:
		var lamp := OmniLight3D.new()
		lamp.position = at
		lamp.light_color = Color("ffd8a0")
		lamp.omni_range = 20.0
		lamp.light_energy = 0.8
		lamp.shadow_enabled = false
		add_child(lamp)
	refresh()

## Height of the ground at a pad-space point, relative to the pad.
func _ground(at: Vector2) -> float:
	if world is IslandWorld:
		var g := global_transform*Vector3(at.x, 0, at.y)
		return (world as IslandWorld).ground_height(g.x, g.z)-global_position.y
	return 0.0

## Ship space to pad space.
static func ship_point(local: Vector3) -> Vector3:
	return SHIP_REST+SHIP_BASIS*local

## Earth heaped against the sunken hull, with moss, flowers and mushrooms.
func _earthworks(art: NexusStation.Brush) -> void:
	var ground_local := -SHIP_REST.y  # the ground in hull space
	var depth := clampf((ShipHull.DECK_Y-ground_local)/(ShipHull.DECK_Y-ShipHull.KEEL_Y), 0.0, 1.0)
	var z := ShipHull.BOW_Z+0.5
	while z<ShipHull.STERN_Z:
		var half := ShipHull.beam(z)*lerpf(1.0, 0.45, depth)
		for side: float in [-1.0, 1.0]:
			for layer in 3:
				var out := half+0.15+layer*0.42
				var at := ship_point(Vector3(side*out, ground_local, z))
				var g := _ground(Vector2(at.x, at.z))
				var tall := (0.75-layer*0.24)*(0.7+_rng.randf()*0.5)
				var color := (MOSS if layer==2 or _rng.randf()<0.25 else EARTH).lightened(_rng.randf()*0.12)
				art.box(Vector3(at.x, g+tall*0.5-0.05, at.z), Vector3(0.45, tall, 0.45), color)
				if layer==2 and _rng.randf()<0.18:
					art.box(Vector3(at.x, g+tall+0.08, at.z), Vector3(0.14, 0.14, 0.14), FLOWERS[_rng.randi() % FLOWERS.size()], false, 0.25)
				elif layer==1 and _rng.randf()<0.06:
					art.box(Vector3(at.x, g+tall+0.12, at.z), Vector3(0.08, 0.24, 0.08), BIRCH)
					art.box(Vector3(at.x, g+tall+0.28, at.z), Vector3(0.3, 0.1, 0.3), Color("d6644f"))
		z += 0.45

## Timber cradle frames the hull rests in: a sill across, props up to the
## hull, chocks and iron bands, every few metres along the keel.
func _cradle(art: NexusStation.Brush) -> void:
	var ground_local := -SHIP_REST.y
	var depth := clampf((ShipHull.DECK_Y-ground_local)/(ShipHull.DECK_Y-ShipHull.KEEL_Y), 0.0, 1.0)
	for z: float in [-20.0, -11.0, -2.0, 7.0, 15.0]:
		var half := ShipHull.beam(z)*lerpf(1.0, 0.45, depth)
		var mid := ship_point(Vector3(0, ground_local, z))
		var g := _ground(Vector2(mid.x, mid.z))
		var across := SHIP_BASIS.x
		# The sill, built of short voxel-sized lengths with a little colour play.
		var steps := int((half+3.0)*2.0/0.5)
		for i in steps+1:
			var off := -half-3.0+i*0.5
			art.box(Vector3(mid.x, g+0.22, mid.z)+across*off, Vector3(0.62, 0.44, 0.5), OAK_DARK.lightened(_rng.randf()*0.08))
		for side: float in [-1.0, 1.0]:
			var foot := Vector3(mid.x, g+0.4, mid.z)+across*side*(half+2.6)
			var top := ship_point(Vector3(side*(half+0.55), ground_local+1.9, z))
			_beam(art, foot, top, 0.36, OAK.lightened(_rng.randf()*0.06))
			for k in 3:
				art.box(foot.lerp(top, 0.25+k*0.25), Vector3(0.44, 0.07, 0.44), IRON)
			art.box(Vector3(mid.x, g+0.75, mid.z)+across*side*(half+0.6), Vector3(0.7, 0.62, 0.8), BIRCH.darkened(0.1))
			art.box(Vector3(mid.x, g+1.12, mid.z)+across*side*(half+0.6), Vector3(0.74, 0.08, 0.84), IRON)

## A square timber from a to b.
func _beam(art: NexusStation.Brush, a: Vector3, b: Vector3, width: float, color: Color, solid := false) -> void:
	var up := (b-a).normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD))<0.9 else Vector3.RIGHT).normalized()
	art.part("box", Transform3D(Basis(side, up, side.cross(up)), (a+b)*0.5), Vector3(width, a.distance_to(b), width), color, solid)

## Pickets between posts, two solid rails, lantern posts and flower boxes.
func _fence_art(art: NexusStation.Brush) -> void:
	for i in FENCE.size():
		var a := FENCE[i]
		var b := FENCE[(i+1) % FENCE.size()]
		var length := a.distance_to(b)
		var dir := (b-a)/length
		var basis := Basis(Vector3.UP, atan2(-dir.y, dir.x))
		var posts := maxi(1, ceili(length/2.4))
		for k in posts:
			var p := a.lerp(b, float(k)/posts)
			var q := a.lerp(b, float(k+1)/posts)
			var span := p.distance_to(q)
			var g := _ground(p)
			var gate := i==0 and absf(p.x-GATE.x)<2.0
			# Post, with a stepped cap.
			art.box(Vector3(p.x, g+1.0, p.y), Vector3(0.34, 2.0, 0.34), OAK_DARK, true)
			art.box(Vector3(p.x, g+2.06, p.y), Vector3(0.44, 0.12, 0.44), OAK.lightened(0.1))
			art.box(Vector3(p.x, g+2.17, p.y), Vector3(0.24, 0.1, 0.24), BRASS)
			if k % 4==2 and not gate: _fence_lantern(art, p, g, dir)
			var centre := (p+q)*0.5
			var gc := _ground(centre)
			for height: float in [0.5, 1.45]:
				art.part("box", Transform3D(basis, Vector3(centre.x, gc+height, centre.y)), Vector3(span, 0.16, 0.12), OAK, true)
			# A low solid board keeps feet from slipping under the bottom rail.
			art.part("box", Transform3D(basis, Vector3(centre.x, gc+0.14, centre.y)), Vector3(span, 0.28, 0.08), OAK_DARK, true)
			var pickets := int(span/0.32)
			for m in range(1, pickets):
				var at := p.lerp(q, float(m)/pickets)
				var tall := 1.55+(0.12 if m % 2 else 0.0)
				var tint := BIRCH.lightened(_rng.randf()*0.08) if (m+k) % 5 else BIRCH.darkened(0.12)
				art.part("box", Transform3D(basis, Vector3(at.x, gc+tall*0.5, at.y)), Vector3(0.17, tall, 0.07), tint)
				art.part("box", Transform3D(basis, Vector3(at.x, gc+tall+0.05, at.y)), Vector3(0.09, 0.1, 0.07), tint)
			if k % 3==1 and not gate:
				var box := Vector3(centre.x, gc+1.62, centre.y)
				art.part("box", Transform3D(basis, box), Vector3(1.0, 0.22, 0.3), OAK_DARK)
				for f in 5:
					var bloom := box+basis.x*(-0.4+f*0.2)+Vector3.UP*(0.16+_rng.randf()*0.06)
					art.box(bloom, Vector3(0.13, 0.13, 0.13), FLOWERS[(f+k) % FLOWERS.size()], false, 0.3)
					art.box(bloom-Vector3.UP*0.1, Vector3(0.05, 0.1, 0.05), MOSS)

func _fence_lantern(art: NexusStation.Brush, p: Vector2, g: float, dir: Vector2) -> void:
	var out := Vector3(dir.y, 0, -dir.x)  # away from the ship
	var at := Vector3(p.x, g, p.y)
	art.box(at+Vector3.UP*2.6, Vector3(0.18, 1.0, 0.18), OAK_DARK)
	art.box(at+Vector3.UP*3.05+out*0.3, Vector3(0.1, 0.1, 0.1)+out.abs()*0.5, IRON)
	art.hanging_lantern(at+Vector3.UP*2.6+out*0.55)

## The boarding gate on the north side, under an arch, opposite the hatch.
func _gate(art: NexusStation.Brush) -> void:
	var g := _ground(GATE)
	for side: float in [-1.0, 1.0]:
		var at := Vector3(GATE.x+side*1.9, g, GATE.y)
		art.box(at+Vector3.UP*1.75, Vector3(0.5, 3.5, 0.5), OAK_DARK, true)
		art.box(at+Vector3.UP*0.2, Vector3(0.8, 0.4, 0.8), STONE)
		for y: float in [0.9, 2.0, 3.1]: art.box(at+Vector3.UP*y, Vector3(0.56, 0.08, 0.56), IRON)
		art.box(at+Vector3.UP*3.6, Vector3(0.62, 0.14, 0.62), BRASS)
	# Arched lintel stepped out of short timbers.
	for i in 9:
		var x := -2.0+i*0.5
		var lift := 0.55*(1.0-pow(x/2.2, 2.0))
		art.box(Vector3(GATE.x+x, g+3.4+lift, GATE.y), Vector3(0.52, 0.34, 0.42), OAK.lightened(float(i % 3)*0.04))
		art.box(Vector3(GATE.x+x, g+3.62+lift, GATE.y), Vector3(0.52, 0.08, 0.5), ROOF_RED)
	art.hanging_lantern(Vector3(GATE.x, g+3.0, GATE.y-0.1))
	# The gate leaves stand half open: the way in is the hatch, not the yard.
	for side: float in [-1.0, 1.0]:
		var hinge := Vector3(GATE.x+side*1.65, g, GATE.y)
		var leaf := Basis(Vector3.UP, side*0.35)
		for m in 5:
			var at := hinge+leaf*Vector3(-side*(0.18+m*0.3), 0, 0)
			art.part("box", Transform3D(leaf, at+Vector3.UP*0.95), Vector3(0.2, 1.7-absf(m-2)*0.05, 0.08), BIRCH.darkened(0.05*(m % 2)))
		for y: float in [0.5, 1.4]:
			art.part("box", Transform3D(leaf, hinge+leaf*Vector3(-side*0.78, y, 0.06)), Vector3(1.55, 0.12, 0.06), OAK_DARK)
	# The opening itself is closed off: boarding happens at the fence.
	art.part("box", Transform3D(Basis.IDENTITY, Vector3(GATE.x, g+1.2, GATE.y+0.35)), Vector3(3.3, 2.4, 0.1), OAK_DARK.darkened(0.3), true)

## The boarding tower north of the fence: a stone keep with a timber stair
## climbing round three sides (west, north, east, a landing at each corner)
## to a balcony level with the deck, a gangway from there over the fence to
## the ship, and a half-timbered lantern room under a pointed roof on top.
## Steps, landings, balusters and the gangway are solid: you walk up.
func _boarding_tower(art: NexusStation.Brush) -> void:
	var base := Vector3(TOWER.x, _ground(TOWER), TOWER.y)
	var wall := STONE.darkened(0.12)
	# Plinth and the solid core, faced with ashlar in a running bond.
	_block(art, base, Vector3(-CORE-0.25, 0, -CORE-0.25), Vector3(CORE+0.25, 0.45, CORE+0.25), STONE.darkened(0.25), true)
	_block(art, base, Vector3(-CORE, 0, -CORE), Vector3(CORE, STONE_TOP, CORE), wall, true)
	var rows := int(STONE_TOP/0.5)
	for face in 4:
		var turn := Basis(Vector3.UP, face*PI*0.5)
		for row in rows:
			var shift := 0.275 if row % 2 else 0.0
			var x := -CORE+shift
			while x<CORE-0.05:
				var w := minf(0.55, CORE-x)
				if face==0 and row*0.5<2.4 and absf(x+w*0.5)<0.9:
					x += w
					continue  # the arched door
				var at := turn*Vector3(x+w*0.5, row*0.5+0.25, CORE+0.03)
				var tint := STONE.lightened(_rng.randf()*0.14-0.05)
				if (x<=-CORE+0.01 or x+w>=CORE-0.01) and row % 2==0: tint = Color("a59c92")  # quoins
				art.part("box", Transform3D(turn, base+at), Vector3(w-0.04, 0.46, 0.08), tint)
				x += w
		# String courses.
		for y: float in [2.5, 5.0]:
			art.part("box", Transform3D(turn, base+turn*Vector3(0, y, CORE+0.08)), Vector3(2.0*CORE+0.2, 0.16, 0.12), STONE.darkened(0.3))
	# Arrow slits with a warm glow on the west and north faces.
	for at: Vector3 in [Vector3(-CORE-0.08, 3.8, 0.4), Vector3(-CORE-0.08, 6.4, -0.6)]:
		art.box(base+at, Vector3(0.1, 0.9, 0.2), Color("ffc27a"), false, 0.9)
	for at: Vector3 in [Vector3(0.6, 6.6, -CORE-0.08)]:
		art.box(base+at, Vector3(0.2, 0.9, 0.1), Color("ffc27a"), false, 0.9)
	# Ground door on the south face under a stone arch, studded oak.
	for i in 5:
		art.box(base+Vector3(-0.48+i*0.24, 1.0, CORE+0.07), Vector3(0.22, 2.0, 0.08), OAK_DARK.lightened(float(i % 2)*0.06))
	for y: float in [0.5, 1.5]: art.box(base+Vector3(0, y, CORE+0.12), Vector3(1.2, 0.08, 0.04), IRON)
	art.box(base+Vector3(0.35, 1.05, CORE+0.14), Vector3(0.08, 0.08, 0.06), BRASS)
	for i in 7:
		var x := -0.75+i*0.25
		art.box(base+Vector3(x, 2.15+0.25*(1.0-pow(x/0.85, 2.0)), CORE+0.1), Vector3(0.24, 0.3, 0.14), Color("a59c92"))

	# Flight one: stone, up the west face going north.
	_flight(art, base, Vector3(-CORE, 0, CORE), Vector3.FORWARD, Vector3.LEFT, 0.0, true)
	_block(art, base, Vector3(-CORE-STAIR, 0, -CORE-STAIR), Vector3(-CORE, RISE, -CORE), STONE.lightened(0.04), true)
	_block(art, base, Vector3(-CORE-STAIR, RISE-0.06, -CORE-STAIR), Vector3(-CORE, RISE+0.02, -CORE), Color("a59c92"))
	_rail(art, base, Vector3(-CORE-STAIR+0.06, RISE, -CORE), Vector3(-CORE-STAIR+0.06, RISE, -CORE-STAIR+0.06))
	_rail(art, base, Vector3(-CORE-STAIR+0.06, RISE, -CORE-STAIR+0.06), Vector3(-CORE, RISE, -CORE-STAIR+0.06))
	# Flight two: timber along the north face going east, to a landing on posts.
	_flight(art, base, Vector3(-CORE, 0, -CORE), Vector3.RIGHT, Vector3.FORWARD, RISE, false)
	_landing(art, base, Vector3(CORE, 0, -CORE-STAIR), Vector3(CORE+STAIR, 0, -CORE), RISE*2.0)
	_rail(art, base, Vector3(CORE, RISE*2.0, -CORE-STAIR+0.06), Vector3(CORE+STAIR-0.06, RISE*2.0, -CORE-STAIR+0.06))
	_rail(art, base, Vector3(CORE+STAIR-0.06, RISE*2.0, -CORE-STAIR+0.06), Vector3(CORE+STAIR-0.06, RISE*2.0, -CORE))
	# Flight three: timber up the east face going south, onto the balcony.
	_flight(art, base, Vector3(CORE, 0, -CORE), Vector3.BACK, Vector3.RIGHT, RISE*2.0, false)
	_landing(art, base, Vector3(-CORE-STAIR, 0, CORE), Vector3(CORE+STAIR, 0, CORE+STAIR), BALCONY)
	var edge := CORE+STAIR-0.06
	_rail(art, base, Vector3(-edge, BALCONY, CORE+0.06), Vector3(-edge, BALCONY, edge))
	_rail(art, base, Vector3(-edge, BALCONY, edge), Vector3(-GANGWAY_HALF, BALCONY, edge))
	_rail(art, base, Vector3(GANGWAY_HALF, BALCONY, edge), Vector3(edge, BALCONY, edge))
	_rail(art, base, Vector3(edge, BALCONY, edge), Vector3(edge, BALCONY, CORE))
	_rail(art, base, Vector3(-edge, BALCONY, CORE+0.06), Vector3(-CORE, BALCONY, CORE+0.06))
	# Curved brackets under the balcony.
	for x: float in [-3.0, -1.2, 1.2, 3.0]:
		_beam(art, base+Vector3(x, BALCONY-1.6, CORE+0.05), base+Vector3(x, BALCONY-0.2, CORE+STAIR-0.15), 0.2, OAK_DARK)
		art.box(base+Vector3(x, BALCONY-1.7, CORE+0.12), Vector3(0.36, 0.3, 0.2), STONE.darkened(0.3))

	# The lantern room: plaster between an oak frame, windows and a door out.
	var top := STONE_TOP+ROOM
	_block(art, base, Vector3(-CORE, STONE_TOP, -CORE), Vector3(CORE, top, CORE), Color("eadfc6"), true)
	art.box(base+Vector3(0, STONE_TOP+0.08, 0), Vector3(2.0*CORE+0.3, 0.16, 2.0*CORE+0.3), OAK_DARK)
	art.box(base+Vector3(0, top-0.06, 0), Vector3(2.0*CORE+0.3, 0.14, 2.0*CORE+0.3), OAK_DARK)
	for face in 4:
		var turn := Basis(Vector3.UP, face*PI*0.5)
		var out := CORE+0.06
		for x: float in [-CORE+0.05, CORE-0.05]:
			art.part("box", Transform3D(turn, base+turn*Vector3(x, STONE_TOP+ROOM*0.5, out)), Vector3(0.24, ROOM, 0.12), OAK_DARK)
		if face==0:  # south: the door onto the balcony and a brass porthole
			for i in 4:
				art.part("box", Transform3D(turn, base+turn*Vector3(-0.42+i*0.28, BALCONY+1.05, out)), Vector3(0.26, 2.1, 0.08), OAK.darkened(0.1*(i % 2)))
			art.part("box", Transform3D(turn, base+turn*Vector3(0.32, BALCONY+1.05, out+0.05)), Vector3(0.08, 0.08, 0.06), BRASS)
			art.part("box", Transform3D(turn, base+turn*Vector3(0, top-0.55, out)), Vector3(0.6, 0.6, 0.08), BRASS)
			art.part("box", Transform3D(turn, base+turn*Vector3(0, top-0.55, out+0.03)), Vector3(0.38, 0.38, 0.06), Color("8ad8ff"), false, 1.2)
			continue
		art.part("box", Transform3D(turn, base+turn*Vector3(0, STONE_TOP+1.5, out)), Vector3(2.0*CORE, 0.14, 0.1), OAK)
		for side: float in [-1.0, 1.0]:
			_beam(art, base+turn*Vector3(side*(CORE-0.15), STONE_TOP+0.15, out), base+turn*Vector3(side*0.85, STONE_TOP+1.45, out), 0.12, OAK_DARK)
		art.part("box", Transform3D(turn, base+turn*Vector3(0, STONE_TOP+2.2, out)), Vector3(1.0, 0.9, 0.06), Color("ffc27a"), false, 1.0)
		art.part("box", Transform3D(turn, base+turn*Vector3(0, STONE_TOP+2.2, out+0.04)), Vector3(0.08, 0.9, 0.06), OAK_DARK)
		art.part("box", Transform3D(turn, base+turn*Vector3(0, STONE_TOP+2.2, out+0.04)), Vector3(1.0, 0.08, 0.06), OAK_DARK)
		for side: float in [-1.0, 1.0]:
			art.part("box", Transform3D(turn, base+turn*Vector3(side*0.78, STONE_TOP+2.2, out+0.02)), Vector3(0.5, 1.0, 0.06), ROOF_RED)
		art.part("box", Transform3D(turn, base+turn*Vector3(0, STONE_TOP+1.68, out+0.1)), Vector3(1.3, 0.12, 0.22), OAK)
	# Pointed roof of stepped shingles over wide eaves, a spire and the beacon.
	for k in 9:
		var w := 2.0*CORE+1.4-k*0.62
		var color := ROOF.lightened(0.06*(k % 2))
		art.box(base+Vector3.UP*(top+0.17+k*0.34), Vector3(w, 0.34, w), color)
		if k<3:
			art.box(base+Vector3.UP*(top+0.03+k*0.34), Vector3(w+0.08, 0.08, w+0.08), color.darkened(0.3))
	var tip := top+9*0.34
	art.box(base+Vector3.UP*(tip+0.6), Vector3(0.14, 1.2, 0.14), BRASS)
	art.box(base+Vector3.UP*(tip+0.2), Vector3(0.34, 0.14, 0.34), BRASS)
	art.box(base+Vector3.UP*(tip+1.45), Vector3(0.42, 0.42, 0.42), Color("8ad8ff"), false, 2.4)
	art.box(base+Vector3(0.5, tip+0.9, 0), Vector3(0.9, 0.42, 0.05), FLOWERS[0])
	art.box(base+Vector3(1.05, tip+0.95, 0), Vector3(0.3, 0.26, 0.05), FLOWERS[0])
	# Lanterns: at the foot of the stair, on the corner posts, on the balcony.
	art.lantern(base+Vector3(-CORE-STAIR-0.7, 0, CORE+1.4), 4.0)
	art.lantern(base+Vector3(CORE+STAIR-0.25, RISE*2.0, -CORE-STAIR+0.25), 3.0)
	for x: float in [-1.6, 1.6]:
		art.box(base+Vector3(x, BALCONY+2.1, CORE+0.35), Vector3(0.1, 0.1, 0.6), IRON)
		art.hanging_lantern(base+Vector3(x, BALCONY+1.5, CORE+0.6))
	# Cargo waiting by the west wall.
	for k in 4:
		var at := base+Vector3(-CORE-STAIR-1.1-(k % 2)*0.85, 0.4+(k >> 1)*0.8, -0.6+(k % 2)*0.3)
		art.box(at, Vector3(0.8, 0.8, 0.8), BIRCH.darkened(0.08*k), k<2)
		art.box(at+Vector3.UP*0.2, Vector3(0.84, 0.08, 0.84), OAK_DARK)
	for k in 2:
		var at := base+Vector3(-CORE-STAIR-1.0, 0.5, 1.2+k*0.85)
		art.round_part(at, 0.36, 1.0, OAK.darkened(0.05*k), true)
		for y: float in [-0.3, 0.3]: art.round_part(at+Vector3.UP*y, 0.38, 0.07, IRON)
	_gangway(art, base)

## Ten steps of 0.25 m from `origin` (on the core, at y0) along `along`, the
## tread reaching out by STAIR; stone stairs are solid down to the ground,
## timber ones are planks on stringers with posts underneath. Balusters
## line the outer edge.
func _flight(art: NexusStation.Brush, base: Vector3, origin: Vector3, along: Vector3, out: Vector3, y0: float, stone: bool) -> void:
	var step := 2.0*CORE/STEPS
	var turn := Basis(Vector3.UP, atan2(along.x, along.z))
	for i in STEPS:
		var top := y0+(i+1)*0.25
		var mid := origin+along*(i+0.5)*step+out*STAIR*0.5
		if stone:
			art.part("box", Transform3D(turn, base+Vector3(mid.x, top*0.5, mid.z)), Vector3(STAIR, top, step), STONE.lightened(_rng.randf()*0.1-0.02), true)
			art.part("box", Transform3D(turn, base+Vector3(mid.x, top-0.03, mid.z)), Vector3(STAIR+0.04, 0.08, step+0.02), Color("a59c92"))
		else:
			art.part("box", Transform3D(turn, base+Vector3(mid.x, top-0.125, mid.z)), Vector3(STAIR, 0.25, step), BIRCH.darkened(_rng.randf()*0.12), true)
			art.part("box", Transform3D(turn, base+Vector3(mid.x, top-0.2, mid.z)+along*(-step*0.5+0.03)), Vector3(STAIR+0.02, 0.12, 0.06), OAK_DARK)
		var post := origin+along*(i+0.5)*step+out*(STAIR-0.06)
		art.box(base+Vector3(post.x, top+0.47, post.z), Vector3(0.08, 0.94, 0.08), OAK_DARK, true)
	var a := origin+along*0.5*step+out*(STAIR-0.06)
	var b := origin+along*(STEPS-0.5)*step+out*(STAIR-0.06)
	_beam(art, base+Vector3(a.x, y0+1.25, a.z), base+Vector3(b.x, y0+RISE+1.0, b.z), 0.1, OAK)
	if stone: return
	for side: float in [0.08, STAIR-0.1]:
		var s := origin+out*side
		_beam(art, base+s+Vector3.UP*(y0-0.3), base+s+along*2.0*CORE+Vector3.UP*(y0+RISE-0.3), 0.2, OAK_DARK)
	for t: float in [0.15, 0.6]:
		var p := origin+along*t*2.0*CORE+out*(STAIR-0.15)
		var under := y0+t*RISE-0.35
		art.box(base+Vector3(p.x, under*0.5, p.z), Vector3(0.26, under, 0.26), OAK, true)
		art.box(base+Vector3(p.x, 0.15, p.z), Vector3(0.44, 0.3, 0.44), STONE)
		_beam(art, base+Vector3(p.x, under-1.1, p.z), base+origin+along*t*2.0*CORE+out*0.05+Vector3.UP*(under-0.05), 0.12, OAK_DARK)

## A plank floor (top at `y`) from lo to hi (x/z), on posts at its outer corners.
func _landing(art: NexusStation.Brush, base: Vector3, lo: Vector3, hi: Vector3, y: float) -> void:
	_block(art, base, Vector3(lo.x, y-0.3, lo.z), Vector3(hi.x, y, hi.z), BIRCH.darkened(0.08), true)
	var x := lo.x+0.2
	while x<hi.x-0.1:
		art.box(base+Vector3(x, y+0.005, (lo.z+hi.z)*0.5), Vector3(0.03, 0.02, hi.z-lo.z), OAK_DARK)
		x += 0.4
	art.box(base+Vector3((lo.x+hi.x)*0.5, y-0.38, (lo.z+hi.z)*0.5), Vector3(hi.x-lo.x+0.08, 0.16, hi.z-lo.z+0.08), OAK_DARK)
	for c: Vector3 in [Vector3(lo.x, 0, lo.z), Vector3(hi.x, 0, lo.z), Vector3(lo.x, 0, hi.z), Vector3(hi.x, 0, hi.z)]:
		if absf(c.x)<=CORE+0.01 and absf(c.z)<=CORE+0.01: continue  # rests on the core
		var p := c+Vector3(0.15 if c.x==lo.x else -0.15, 0, 0.15 if c.z==lo.z else -0.15)
		art.box(base+Vector3(p.x, (y-0.3)*0.5, p.z), Vector3(0.3, y-0.3, 0.3), OAK, true)
		art.box(base+Vector3(p.x, 0.2, p.z), Vector3(0.5, 0.4, 0.5), STONE)

## Solid balusters with a handrail between two points at floor height y.
func _rail(art: NexusStation.Brush, base: Vector3, a: Vector3, b: Vector3) -> void:
	var n := maxi(1, ceili(a.distance_to(b)/0.42))
	for i in n+1:
		var p := a.lerp(b, float(i)/n)
		art.box(base+p+Vector3.UP*0.47, Vector3(0.08, 0.94, 0.08), OAK_DARK, true)
	_beam(art, base+a+Vector3.UP*1.0, base+b+Vector3.UP*1.0, 0.1, OAK)

## From the balcony over the fence to the deck: a planked gangway on a
## trestle, rope-and-rail sides, and a gate where you step aboard.
func _gangway(art: NexusStation.Brush, base: Vector3) -> void:
	var start := base+Vector3(0, BALCONY, CORE+STAIR)
	var end := gangway_end()
	var length := start.distance_to(end)
	var along := (end-start).normalized()
	var turn := Basis(along.cross(Vector3.UP).normalized(), Vector3.UP, -along)
	for i in int(length/0.45):
		art.part("box", Transform3D(turn, start+along*(0.225+i*0.45)-Vector3.UP*0.08), Vector3(2.0*GANGWAY_HALF, 0.16, 0.43), BIRCH.darkened(float(i % 3)*0.05), true)
	for side: float in [-1.0, 1.0]:
		var edge := turn.x*side*(GANGWAY_HALF-0.05)
		art.part("box", Transform3D(turn, start.lerp(end, 0.5)+edge-Vector3.UP*0.2), Vector3(0.12, 0.2, length), OAK_DARK)
		art.part("box", Transform3D(turn, start.lerp(end, 0.5)+edge+Vector3.UP*1.0), Vector3(0.08, 0.08, length), OAK)
		for i in int(length/0.45)+1:
			art.box(start+along*minf(i*0.45, length)+edge+Vector3.UP*0.47, Vector3(0.07, 0.94, 0.07), OAK_DARK, true)
	# The trestle where it crosses the fence.
	var cross := Vector3(start.x, _ground(Vector2(start.x, FENCE[0].y+0.8)), FENCE[0].y+0.8)
	var under := start.y-0.16
	for side: float in [-1.0, 1.0]:
		var foot := Vector3(cross.x+side*(GANGWAY_HALF+0.3), cross.y, cross.z)
		_beam(art, foot, Vector3(foot.x-side*0.3, under, foot.z), 0.26, OAK)
		art.box(foot+Vector3.UP*0.2, Vector3(0.5, 0.4, 0.5), STONE)
	for y: float in [2.5, 5.0]:
		art.box(cross+Vector3.UP*y, Vector3(2.0*GANGWAY_HALF+0.8, 0.18, 0.18), OAK_DARK)
	_beam(art, cross+Vector3(-GANGWAY_HALF-0.25, 0.6, 0), Vector3(cross.x+GANGWAY_HALF+0.05, under-0.4, cross.z), 0.14, OAK_DARK)
	# A swing gate at the ship's end: the way aboard.
	art.part("box", Transform3D(turn, end-along*0.1+Vector3.UP*0.55), Vector3(2.0*GANGWAY_HALF, 1.1, 0.1), OAK_DARK, true)
	art.part("box", Transform3D(turn, end-along*0.16+Vector3.UP*0.75), Vector3(2.0*GANGWAY_HALF-0.2, 0.1, 0.06), BRASS)
	art.hanging_lantern(end-along*0.3+Vector3.UP*2.0)
	art.box(end-along*0.3+Vector3.UP*2.35, Vector3(0.1, 0.1, 0.1), IRON)
	for side: float in [-1.0, 1.0]:
		art.box(end-along*0.1+turn.x*side*GANGWAY_HALF+Vector3.UP*1.2, Vector3(0.14, 2.4, 0.14), OAK_DARK)
	art.part("box", Transform3D(turn, end-along*0.1+Vector3.UP*2.4), Vector3(2.0*GANGWAY_HALF+0.3, 0.14, 0.14), OAK_DARK)

## The end of the gangway at the ship's rail, where you step aboard (pad space).
func gangway_end() -> Vector3:
	var deck := ship_point(Vector3(0, ShipHull.DECK_Y, 0))
	return Vector3(TOWER.x, maxf(_ground(TOWER)+BALCONY, deck.y+0.4), deck.z-ShipHull.beam(TOWER.x-SHIP_REST.x)+1.3)

## A box from local corner lo to hi.
func _block(art: NexusStation.Brush, base: Vector3, lo: Vector3, hi: Vector3, color: Color, solid := false) -> void:
	art.box(base+(lo+hi)*0.5, hi-lo, color, solid)

## Odessa's timber stall: counter, awning, crates and a ship model.
func _stall(art: NexusStation.Brush, at: Vector3) -> void:
	var g := _ground(Vector2(at.x, at.z))
	var base := Vector3(at.x, g, at.z)
	for i in 8:
		art.box(base+Vector3(-1.75+i*0.5, 0.55, 0), Vector3(0.5, 1.1, 1.3), OAK.lightened(float(i % 3)*0.03), i in [0, 7])
	art.box(base+Vector3(0, 0.55, 0), Vector3(4.0, 1.1, 1.3), OAK, true)
	art.box(base+Vector3(0, 1.15, 0), Vector3(4.3, 0.1, 1.55), BRASS)
	for x: float in [-2.0, 2.0]:
		for z: float in [-0.7, 0.7]: art.box(base+Vector3(x, 1.6, z+0.9), Vector3(0.18, 3.2, 0.18), OAK_DARK)
	for i in 9:
		art.box(base+Vector3(-2.2+i*0.55, 3.25+(0.06 if i % 2 else 0.0), 0.9), Vector3(0.55, 0.12, 2.4), ROOF_RED if i % 2 else Color("f2e6cf"))
	for z: float in [-0.25, 0.3]:
		art.box(base+Vector3(-1.2, 1.32, z), Vector3(0.5, 0.3, 0.3), BIRCH)
	art.box(base+Vector3(0.6, 1.4, 0), Vector3(1.1, 0.35, 0.4), Color("ff9a6a"))
	art.box(base+Vector3(0.6, 1.62, 0), Vector3(0.5, 0.12, 0.2), BRASS)
	for k in 3:
		art.box(base+Vector3(2.7, 0.35+k*0.62, 0.4-k*0.15), Vector3(0.62, 0.6, 0.62), BIRCH.darkened(0.1*k), k==0)

func set_state(p_unlocked: bool, p_owned: bool) -> void:
	unlocked = p_unlocked
	owned = p_owned
	refresh()

func refresh() -> void:
	if not is_instance_valid(_wright): return
	_wright.description = "Shipwright"
	_wright.action_text = "Talk"
	_wright.confirm_text = ""
	_wright.cancel_text = "Leave"
	for way: InteractionTarget in [_fence, _gangway_gate]:
		way.action_text = "Board"
		way.response = "Boarding..."
		if not unlocked:
			way.description = "Space is not unlocked yet."
		else:
			way.description = "Go aboard the moored battleship." if owned else "Ask Shipwright Odessa to bring out a ship, then board her here."
	_wright.response = "Buy a battleship or take one out from your fleet." if unlocked \
			else "Finish the Theory of Everything to open the way to Space."

func _on_wright(_actor: Node3D) -> void:
	refresh()
	if unlocked: get_tree().call_group("fleet_panels", "open_for", _wright)

func _on_launch(actor: Node3D) -> void:
	if not unlocked or _busy or not actor is Player: return
	if Net.is_client(): Net.client.send_action("port", ["board"])
	elif world is IslandWorld:
		var dock := (world as IslandWorld).surface_ships
		dock.local_player = actor
		var record := {player_id = actor.player_id, peer_id = 0, name = "You", account_id = 0, pos = actor.global_position}
		var vessel := dock.ensure_ship(record) if owned else null
		if vessel: dock.server_action(record, ["board", vessel.id])

func on_port_event(ev: Array) -> void:
	if str(ev[1])=="owned":
		owned = bool(ev[2])
		refresh()

func arrival_point() -> Vector3:
	return global_transform*ARRIVAL
