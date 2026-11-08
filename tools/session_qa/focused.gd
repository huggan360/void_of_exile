extends Node3D
## Focused session regression checks. No accounts or persistent saves.
var checks := 0
var failures := 0
class TargetBody extends StaticBody3D:
	var damage := 0
	var source: Node
	func take_hit(_at: Vector3, _dir: Vector3, amount: int, who: Node) -> void:
		damage += amount
		source = who
class TestWorld extends SpaceWorld:
	func _ready() -> void:
		set_physics_process(false)
		foes = SpaceFoes.new()
		foes.world = self
		foes.surface_combat = true
		add_child(foes)
		foes.set_physics_process(false)
	func _ensure_interior(_slot: int) -> void: pass
	func _broadcast_ship(_ship: SpaceShip) -> void: pass

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("[focused] ", "PASS " if ok else "FAIL ", label)

func _ready() -> void:
	_run.call_deferred()

func _buffs() -> void:
	for id: String in StatusEffects.IDS:
		var buffs := StatusEffects.new()
		check(buffs.add(id, 10.0, 2, "first"), id+": initial grant")
		var original: Dictionary = buffs.active()[0].duplicate()
		var revision := buffs.revision
		check(not buffs.add(id, 8.0, 99, "second") and buffs.count(id)==1 and buffs.revision==revision and buffs.active()[0]==original, id+": shorter application is discarded without changing value or timer")
		check(buffs.add(id, 15.0, 3, "third") and buffs.active().size()==1 and float(buffs.active()[0].expires)>float(original.expires)+4.9 and buffs.active()[0].source=="third", id+": longer application replaces rather than stacks")
	var buffs := StatusEffects.new()
	buffs.add("defence", 10.0, 4)
	buffs.add("defense", 8.0, 20, "alias")
	check(buffs.count("defence")==1 and buffs.additive("defense", 0)==4, "aliases cannot bypass the no-stacking rule")
	buffs.replace_wire([["old:a", "speed", 4, 10.0, 10.0, "a"], ["old:b", "speed", 99, 8.0, 8.0, "b"], ["old:c", "speed", 7, 12.0, 12.0, "c"]])
	check(buffs.active().size()==1 and buffs.additive("speed", 0)==7, "legacy network stacks collapse to the longest remaining entry")
	buffs.clear()
	check(not buffs.drink_beer() and not buffs.has_effect("drunk"), "one completed beer does not cause drunkenness")
	check(buffs.drink_beer() and buffs.count("drunk")==1, "two completed beers in a minute cause drunkenness")
	buffs.entries.drunk.expires = Net.now()+10.0
	check(buffs.drink_beer() and float(buffs.active()[0].expires)-Net.now()>149.0 and buffs.count("drunk")==1, "one beer refreshes existing drunkenness without stacking")
	buffs.clear()
	buffs.drink_beer()
	buffs._last_beer = Net.now()-61.0
	check(not buffs.drink_beer() and not buffs.has_effect("drunk"), "a beer outside the one-minute window does not count")
	check(buffs.drink_beer(), "the expired-window beer becomes the first of a fresh pair")
	buffs.clear()
	buffs.add("drunk", 300.0)
	var expiry := float(buffs.active()[0].expires)
	check(not buffs.drink_beer() and float(buffs.active()[0].expires)==expiry, "beer cannot shorten a longer existing drunkenness buff")

func _beer_paths(world: TestWorld) -> void:
	var pid := GameServer.join(false)
	var stats := GameServer.character(pid)
	var ship := SpaceShip.new()
	ship.id = 50
	ship.slot = 2
	ship.owner = pid
	ship.crew = {chair_0 = pid}
	world.ships[ship.id] = ship
	var p := {player_id = pid, peer_id = 0, account_id = 0, pos = SpaceLayout.pocket_origin(ship.slot)}
	world.server_action(p, ["drink"])
	world.server_action(p, ["drink"])
	check(not stats.buffs.has_effect("drunk"), "actual ship sips do not count as completed beers")
	world.server_action(p, ["drink"])
	check(not stats.buffs.has_effect("drunk"), "finishing the first ship beer leaves the character sober")
	world.server_action(p, ["pour"])
	for i in 3: world.server_action(p, ["drink"])
	check(stats.buffs.count("drunk")==1, "finishing two ship beers applies exactly one drunkenness effect")
	stats.buffs.clear()
	# Finish one ship beer, then one city beer: the threshold is character-wide.
	world.server_action(p, ["pour"])
	for i in 3: world.server_action(p, ["drink"])
	var city := CityState.new()
	var seat_id := ""
	for district: Dictionary in CityLayout.DISTRICTS:
		for venue: Dictionary in CityLayout.venues(district):
			for seat: Dictionary in venue.seats:
				if str(seat.drink)=="beer":
					seat_id = seat.id
					break
			if seat_id!="": break
		if seat_id!="": break
	city.seats[seat_id] = pid
	city.cups[seat_id] = 1.0
	for i in 3: city.handle(pid, Vector3.ZERO, ["city", "sip"])
	check(not stats.buffs.has_effect("drunk"), "city beer also waits for the glass to be finished")
	city.handle(pid, Vector3.ZERO, ["city", "sip"])
	check(stats.buffs.count("drunk")==1, "a ship beer and a city beer share the one-minute threshold")
	world.ships.erase(ship.id)

func _target(world: TestWorld, at: Vector3, collision := false) -> TargetBody:
	var body := TargetBody.new()
	body.position = at
	body.collision_layer = Player.ENEMY_LAYER if collision else 0
	world.add_child(body)
	if collision:
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 2.0
		shape.shape = sphere
		body.add_child(shape)
	var flag := TargetFlag.new()
	flag.name = "Flag"
	flag.hit_radius = 2.0
	body.add_child(flag)
	return body

func _run() -> void:
	GameServer.set_physics_process(false)
	_buffs()
	var tavern := load("res://scenes/home/tavern.tscn").instantiate() as HallWorld
	var home := HomeTerrain.from_scene(tavern)
	var ground := HallGenerator.new(home)
	var under := VoxelBuffer.new()
	under.create(16, 16, 16)
	ground._generate_block(under, Vector3i(0, -16, 0), 0)
	check(under.is_uniform(VoxelBuffer.CHANNEL_TYPE) and under.get_voxel(0, 0, 0, VoxelBuffer.CHANNEL_TYPE)==Blocks.AIR, "Tavern terrain below the shallow floor is empty, with no deep rock underside")
	tavern.free()
	var world := TestWorld.new({id = "qa"})
	add_child(world)
	_beer_paths(world)
	var source := Node3D.new()
	add_child(source)
	var actor := Player.new()
	world.local_player = actor
	var far := _target(world, Vector3(1, 0, -400))
	var near := _target(world, Vector3(2, 0, -100))
	var mid := _target(world, Vector3(-1, 0, -200))
	var fourth := _target(world, Vector3(0, 0, -300))
	var outside := _target(world, Vector3(60, 0, -100))
	var distant := _target(world, Vector3(0, 0, -1300))
	var disabled := _target(world, Vector3(0, 0, -50))
	(disabled.get_node("Flag") as TargetFlag).target = false
	await get_tree().physics_frame
	var locks := TurretTargeting.select(world, Vector3.ZERO, Vector3.FORWARD)
	check(locks.size()==3 and (locks[0].flag as WeakRef).get_ref().get_parent()==near and (locks[1].flag as WeakRef).get_ref().get_parent()==mid and (locks[2].flag as WeakRef).get_ref().get_parent()==fourth, "only the nearest three eligible targets are selected, regardless of insertion order")
	check(not locks.any(func(t: Dictionary) -> bool: return (t.flag as WeakRef).get_ref().get_parent() in [outside, distant, disabled, far]), "range, crosshair cone, disabled flags and fourth-nearest are excluded")
	var cannon := SpaceShip.new()
	cannon.id = 9
	for i in 3: world.foes.fire_bolt(cannon, Vector3.ZERO, Vector3.FORWARD, 77)
	var selected: Array = world.foes._bolts.map(func(b: Dictionary) -> Object: return (b.target.flag as WeakRef).get_ref().get_parent())
	check(selected==[near, mid, fourth], "successive cannon shots cycle across the three nearest locks")
	world.foes._bolts.clear()

	(near.get_node("Flag") as TargetFlag).target = false
	locks = TurretTargeting.select(world, Vector3.ZERO, Vector3.FORWARD)
	check(locks.size()==3 and (locks[2].flag as WeakRef).get_ref().get_parent()==far, "losing a target immediately promotes the next closest eligible object")
	var wall := StaticBody3D.new()
	wall.collision_layer = Player.OBSTACLE_LAYER
	wall.position = Vector3(0, 0, -25)
	world.add_child(wall)
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 40, 2)
	collider.shape = box
	wall.add_child(collider)
	await get_tree().physics_frame
	check(TurretTargeting.select(world, Vector3.ZERO, Vector3.FORWARD).is_empty(), "solid cover blocks target acquisition")
	wall.queue_free()
	for body in [far, near, mid, fourth, outside, distant, disabled]: body.queue_free()
	await get_tree().physics_frame
	var target := _target(world, Vector3(5, 0, -100), true)
	await get_tree().physics_frame
	var ship := SpaceShip.new()
	ship.id = 1
	var bolts := world.foes
	bolts.fire_bolt(ship, Vector3.ZERO, Vector3.FORWARD, 77)
	var initial: Vector3 = bolts._bolts[0].vel
	for step in 80:
		bolts._fly_bolts(1.0/120.0)
		if bolts._bolts.is_empty(): break
	check(target.damage==SpaceFoes.BOLT_DAMAGE, "a cannon bolt curves to hit an off-centre flagged target")
	check(bolts._bolts.is_empty(), "impact removes the authoritative projectile")
	check(target.source==actor, "damage retains the firing player's source")
	var steered := TurretTargeting.steer(initial, initial.normalized(), Vector3.ZERO, {pos = Vector3(5, 0, -100), vel = Vector3(10, 0, 0)}, 1.0/60.0)
	check(initial.angle_to(steered)<=TurretTargeting.TURN_RATE/60.0+0.0001 and steered.x>0, "guidance leads a moving target while respecting the turn-rate limit")
	var straight := TurretTargeting.steer(initial, initial.normalized(), Vector3.ZERO, {pos = Vector3(100, 0, -10), vel = Vector3.ZERO}, 1.0)
	check(straight.is_equal_approx(initial), "a target far outside the bend limit cannot pull the bolt around")
	var lost := TurretTargeting.select(world, Vector3.ZERO, Vector3.FORWARD)[0]
	(target.get_node("Flag") as TargetFlag).target = false
	check(TurretTargeting.sample(lost, world).is_empty(), "disabling a target drops in-flight guidance safely")
	# Transfer a damaged hull with mixed seated/standing occupants, beer and smoke.
	ship.owner = 77
	ship.slot = 4
	ship.hp = 1234
	ship.parts.engines = 42.0
	ship.glasses = [0.32, 1.0, 0.66, 0.0]
	ship.crew = {pilot = 77, chair_1 = 88}
	ship.smoking = {88: 27.0}
	var transfer := {wire = ship.wire().duplicate(true), smoking = ship.smoking.duplicate(), imported = {}, account = 0}
	var imported := world.accept_transfer(transfer, "flying")
	check(imported!=null and imported.hp==1234 and imported.parts.engines==42.0 and imported.glasses==ship.glasses and imported.crew==ship.crew and imported.smoking==ship.smoking, "world handoff preserves damage, seated crew, beer levels and smoking duration")
	check(world.accept_transfer(transfer, "flying")==imported and world.ships.size()==1, "all passengers in a handoff share one imported ship")
	actor.free()
	world.local_player = null
	print("[focused] RESULT %d checks, %d failures" % [checks,failures])
	get_tree().quit(1 if failures else 0)
