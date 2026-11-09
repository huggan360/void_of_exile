class_name TavernLaunchpad
extends Node3D
## Tavern-sized launch deck, with a visibly lockable entry on +Z.

const Art = preload("res://scripts/space/art/ship_hull.gd").ArtBatch
var anchors := {}
var rocket: SmallRocket
var _root: Node3D
var _lock_root: Node3D
var _gate: CollisionShape3D
var _locked := true
var _sign: SignBoard

func build(server: bool) -> void:
	_root = ShipHull.content(self, _root)
	rocket = null
	_lock_root = null
	_sign = null
	anchors = {board = Vector3(0, 0, 3.05), rocket = Transform3D.IDENTITY}
	var art := Art.new(_root, server)
	art.solid(Vector3(0, -0.18, 0), Vector3(9, 0.36, 9))
	# Simple rail collision covers the balustrades, leaving a 2.5 m entry.
	for side: float in [-1.0, 1.0]:
		art.solid(Vector3(side * 4.25, 0.6, 0), Vector3(0.24, 1.2, 8.5))
	art.solid(Vector3(0, 0.6, -4.25), Vector3(8.5, 1.2, 0.24))
	for side: float in [-1.0, 1.0]: art.solid(Vector3(side * 2.8, 0.6, 4.25), Vector3(3.0, 1.2, 0.24))
	var base := CylinderShape3D.new()
	base.radius = 1.23
	base.height = 3.4
	art.collision(base, Transform3D(Basis.IDENTITY, Vector3(0, 1.7, 0)))
	for i in 4:
		var angle := i * PI * 0.5 + PI * 0.25
		art.solid(Vector3(sin(angle) * 1.5, 0.7, cos(angle) * 1.5), Vector3(0.48, 1.4, 1.25), Basis(Vector3.UP, angle))
	art.solid(Vector3(-2.65, 0.65, 2.85), Vector3(0.7, 1.3, 0.7))
	art.solid(Vector3(2.55, 0.95, 3.8), Vector3(1.6, 1.9, 0.45))
	var gate_body := StaticBody3D.new()
	gate_body.name = "EntryChainCollision"
	gate_body.collision_layer = Player.TERRAIN_LAYER
	gate_body.collision_mask = 0
	_root.add_child(gate_body)
	_gate = CollisionShape3D.new()
	var gate_shape := BoxShape3D.new()
	gate_shape.size = Vector3(2.5, 1.2, 0.18)
	_gate.shape = gate_shape
	_gate.position = Vector3(0, 0.6, 4.25)
	_gate.disabled = not _locked
	gate_body.add_child(_gate)
	if server: return
	for plank in 18:
		art.box(Vector3(-4.25 + plank * 0.5, -0.09, 0), Vector3(0.49, 0.18, 9), Art.WOOD.lightened(plank % 4 * 0.035))
	for side: float in [-1.0, 1.0]:
		art.box(Vector3(side * 4.45, -0.1, 0), Vector3(0.1, 0.28, 9), Art.BRASS)
		art.box(Vector3(0, -0.1, side * 4.45), Vector3(9, 0.28, 0.1), Art.BRASS)
	# Inlaid compass and a brass blast plate remain flush with the planks.
	art.part("cylinder", Vector3(0, 0.012, 0), Vector3(4.4, 0.025, 4.4), Art.DARK)
	art.part("ring", Vector3(0, 0.035, 0), Vector3(4.5, 0.12, 4.5), Art.BRASS)
	for i in 16:
		var angle := i * TAU / 16
		art.box(Vector3(sin(angle) * 2.8, 0.02, cos(angle) * 2.8), Vector3(0.12, 0.04, 0.4), Art.AMBER, 0.4, Basis(Vector3.UP, angle))
	for side: float in [-1.0, 1.0]:
		for z: float in [-4.25, -2.1, 0, 2.1, 4.25]: _post(art, Vector3(side * 4.25, 0, z))
		for y: float in [0.45, 1.06]:
			art.box(Vector3(side * 4.25, y, 0), Vector3(0.14, 0.12, 8.5), Art.BRASS)
			art.box(Vector3(side * 2.8, y, 4.25), Vector3(3.0, 0.12, 0.14), Art.BRASS)
		_post(art, Vector3(side * 1.3, 0, 4.25))
	for x: float in [-2.1, 0, 2.1]: _post(art, Vector3(x, 0, -4.25))
	for y: float in [0.45, 1.06]: art.box(Vector3(0, y, -4.25), Vector3(8.5, 0.12, 0.14), Art.BRASS)
	for x: float in [-4.25, 4.25]: art.lantern(Vector3(x, 1.55, -4.25))
	# The lever and sign are reachable from the entry, outside the rocket fins.
	art.box(Vector3(-2.65, 0.65, 2.85), Vector3(0.65, 1.3, 0.65), Art.WOOD)
	art.box(Vector3(-2.65, 1.33, 2.85), Vector3(0.8, 0.12, 0.8), Art.BRASS)
	art.beam(Vector3(-2.65, 1.36, 2.85), Vector3(-2.65, 1.96, 2.55), 0.1, Art.BRASS)
	art.box(Vector3(-2.65, 1.96, 2.55), Vector3(0.5, 0.16, 0.18), Color("539b75"))
	art.crystal(Vector3(-2.65, 1.45, 3.02), Vector3(0.16, 0.22, 0.16), Art.GREEN)
	art.box(Vector3(2.55, 0.65, 3.8), Vector3(0.16, 1.3, 0.18), Art.BRASS)
	art.box(Vector3(2.55, 1.45, 3.8), Vector3(1.5, 0.85, 0.18), Art.DARK)
	for y: float in [1.03, 1.87]: art.box(Vector3(2.55, y, 3.91), Vector3(1.6, 0.08, 0.08), Art.BRASS)
	art.finish()
	# Painted on the board by the deck.
	_sign = SignBoard.make("LAUNCH LOCKED", "paint", "", Art.AMBER, 0.38)
	_sign.position = Vector3(2.55, 1.45, 3.92)
	_root.add_child(_sign)
	rocket = SmallRocket.new()
	rocket.name = "Rocket"
	rocket.transform = anchors.rocket
	_root.add_child(rocket)
	rocket.build()
	_lock_root = Node3D.new()
	_lock_root.name = "ChainAndPadlock"
	_root.add_child(_lock_root)
	var lock_art := Art.new(_lock_root)
	for i in 19:
		var t := float(i) / 18
		var at := Vector3(lerpf(-1.3, 1.3, t), 1.02 - sin(t * PI) * 0.24, 4.25)
		lock_art.part("ring", at, Vector3.ONE * 0.25, Art.BRASS, 0, Basis(Vector3.RIGHT, PI * 0.5 if i % 2 else 0.0))
	lock_art.part("ring", Vector3(0, 0.79, 4.34), Vector3.ONE * 0.42, Art.BRASS, 0, Basis(Vector3.RIGHT, PI * 0.5))
	lock_art.box(Vector3(0, 0.56, 4.36), Vector3(0.45, 0.43, 0.23), Art.BRASS)
	lock_art.part("sphere", Vector3(0, 0.62, 4.49), Vector3(0.09, 0.09, 0.02), Art.DARK)
	lock_art.box(Vector3(0, 0.54, 4.49), Vector3(0.045, 0.12, 0.02), Art.DARK)
	lock_art.finish()
	set_locked(_locked)

func _post(art: Art, at: Vector3) -> void:
	art.box(at + Vector3.UP * 0.59, Vector3(0.24, 1.18, 0.24), Art.WOOD)
	art.box(at + Vector3.UP * 1.18, Vector3(0.34, 0.12, 0.34), Art.BRASS)
	art.part("sphere", at + Vector3.UP * 1.31, Vector3.ONE * 0.22, Art.BRASS)

## Lock state controls the visible chain and the entry barrier on both peers.
func set_locked(locked: bool) -> void:
	_locked = locked
	if is_instance_valid(_lock_root): _lock_root.visible = locked
	if is_instance_valid(_gate): _gate.set_deferred("disabled", not locked)
	if is_instance_valid(_sign): _sign.set_text("LAUNCH LOCKED\nAsk the keeper" if locked else "READY TO SAIL\nAll aboard!")
