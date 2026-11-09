class_name SurfaceLaunchpad
extends Node3D
## The Skyward Launch Pad on the Surface, south of Hearthwick (the "launchpad"
## landmark paves its ground): a battleship moored east-west in a timber
## cradle, sunk into the earth and fenced in, two wooden gantry towers, and the
## shipwright who sells you one (500 Dots) or takes one out of your fleet.
## Space opens once the Theory of Everything is told.
##
## Nobody walks around the hull: step up to the fence anywhere to board, and the
## hatch inside brings you back out by the gate (ARRIVAL).
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
const TOWERS: Array[Vector2] = [Vector2(-18, -13.5), Vector2(4, -13.5)]

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
var _busy := false
var _rng := RandomNumberGenerator.new()

## Boarding from anywhere along the fence: the card follows the nearest point.
class FenceBoarding extends InteractionTarget:
	var pad: SurfaceLaunchpad

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
	for at: Vector2 in TOWERS: _tower(art, at)
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
	for at: Vector3 in [Vector3(-12, 7.0, -12), Vector3(SHIP_REST.x, 9.0, SHIP_REST.z), Vector3(-34, 6.0, -6)]:
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

## A wooden gantry tower: stone footing, four posts, cross bracing, two
## landings, a ladder, a gangplank out over the fence to the deck, and a
## pointed shingle roof with a pennant.
func _tower(art: NexusStation.Brush, at2: Vector2) -> void:
	var g := _ground(at2)
	var base := Vector3(at2.x, g, at2.y)
	for x in 4:
		for z in 4:
			art.box(base+Vector3(-1.05+x*0.7, 0.3, -1.05+z*0.7), Vector3(0.7, 0.6, 0.7), STONE.lightened(_rng.randf()*0.12-0.04), x in [0, 3] or z in [0, 3])
	var top := 11.0
	var corners: Array[Vector3] = [Vector3(-1.1, 0, -1.1), Vector3(1.1, 0, -1.1), Vector3(1.1, 0, 1.1), Vector3(-1.1, 0, 1.1)]
	for c: Vector3 in corners:
		var y := 0.6
		while y<top:
			art.box(base+c+Vector3.UP*(y+0.25), Vector3(0.4, 0.5, 0.4), OAK.lightened(_rng.randf()*0.07-0.02), true)
			y += 0.5
	for level: float in [0.6, 4.2, 7.8]:
		for i in 4:
			var a := corners[i]
			var b := corners[(i+1) % 4]
			if level>1.0: _beam(art, base+a+Vector3.UP*level, base+b+Vector3.UP*(level+3.6) if level<7.0 else base+b+Vector3.UP*(top-0.2), 0.16, OAK_DARK)
			_beam(art, base+a+Vector3.UP*(level+0.1), base+b+Vector3.UP*(level+0.1), 0.24, OAK_DARK)
	# Landings of planks with a rail.
	for level: float in [4.2, 7.8]:
		for i in 6:
			art.box(base+Vector3(-1.0+i*0.4, level+0.25, 0), Vector3(0.38, 0.1, 2.6), BIRCH.darkened(_rng.randf()*0.1))
		for side: float in [-1.0, 1.0]:
			art.box(base+Vector3(side*1.35, level+1.2, 0), Vector3(0.08, 0.08, 2.6), OAK)
			art.box(base+Vector3(0, level+1.2, side*1.35), Vector3(2.6, 0.08, 0.08), OAK)
	# Ladder up the north face.
	for side: float in [-0.35, 0.35]: art.box(base+Vector3(side, 4.3, -1.42), Vector3(0.09, 7.4, 0.09), OAK_DARK)
	for i in 18: art.box(base+Vector3(0, 0.9+i*0.42, -1.42), Vector3(0.7, 0.06, 0.07), BIRCH)
	# The gangplank out over the fence toward the ship's deck rail.
	var deck := ship_point(Vector3(0, ShipHull.DECK_Y, 0))
	var start := base+Vector3(0, 7.9, 1.3)
	var end := Vector3(at2.x, maxf(start.y-0.2, deck.y+0.4), deck.z-ShipHull.beam(at2.x-SHIP_REST.x)+1.3)
	var length := start.distance_to(end)
	var along := (end-start).normalized()
	var plank_basis := Basis(along.cross(Vector3.UP).normalized(), Vector3.UP, -along)
	for i in int(length/0.45):
		art.part("box", Transform3D(plank_basis, start+along*(0.225+i*0.45)), Vector3(1.3, 0.1, 0.42), BIRCH.darkened(float(i % 3)*0.05))
	for side: float in [-0.62, 0.62]:
		art.part("box", Transform3D(plank_basis, start.lerp(end, 0.5)+plank_basis.x*side+Vector3.UP*0.9), Vector3(0.06, 0.06, length), OAK_DARK)
		for i in int(length/1.5)+1:
			art.box(start+along*minf(i*1.5, length)+plank_basis.x*side+Vector3.UP*0.45, Vector3(0.07, 0.9, 0.07), OAK_DARK)
	art.box(end+Vector3.UP*0.3, Vector3(0.3, 0.3, 0.3), BRASS)
	# Pointed fairytale roof of stepped shingles, finial, pennant and lantern.
	for step in 7:
		var w := 3.4-step*0.48
		var color := ROOF.lightened(0.05*(step % 2)) if at2.x<0 else ROOF_RED.lightened(0.05*(step % 2))
		art.box(base+Vector3.UP*(top+0.18+step*0.36), Vector3(w, 0.36, w), color)
		if step<5:
			for side: float in [-1.0, 1.0]:
				art.box(base+Vector3(side*(w*0.5-0.05), top+0.05+step*0.36, 0), Vector3(0.1, 0.12, w), color.darkened(0.25))
	art.box(base+Vector3.UP*(top+2.9), Vector3(0.12, 1.0, 0.12), BRASS)
	art.box(base+Vector3(0.45, top+3.15, 0), Vector3(0.8, 0.4, 0.05), FLOWERS[0] if at2.x<0 else FLOWERS[1])
	art.box(base+Vector3(0.95, top+3.2, 0), Vector3(0.3, 0.24, 0.05), FLOWERS[0] if at2.x<0 else FLOWERS[1])
	art.box(base+Vector3.UP*(top+3.5), Vector3(0.36, 0.36, 0.36), Color("8ad8ff"), false, 2.4)
	art.hanging_lantern(base+Vector3(0, 7.2, 0))
	art.lantern(base+Vector3(1.6, 0, -1.8), 4.0)

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
	_fence.action_text = "Board"
	_fence.response = "Boarding..."
	if not unlocked:
		_wright.response = "Finish the Theory of Everything to open the way to Space."
		_fence.description = "Space is not unlocked yet."
	else:
		_wright.response = "Buy a battleship or take one out from your fleet."
		_fence.description = "Go aboard the moored battleship." if owned else "Ask Shipwright Odessa to bring out a ship, then board her here."

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
