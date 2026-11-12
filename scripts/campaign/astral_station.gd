class_name AstralStation
extends Node3D
## A small rocket and its mechanic on natural woodland ground.
const PARTS := ["story_starcoil","story_spellsteel_nozzle","story_aether_heart"]
const OFFSETS := {mechanic=Vector3(-2,0,3),parts=Vector3(-4,0,3),boarding=Vector3(6,0,-2)}
const ROCKET_OFFSET := Vector3(6,0,-5)
const HALF := Vector2(9,8)
var world: IslandWorld
var rocket := SmallRocket.new()
var flight := {}
var _rocket_rest := Vector3.ZERO
var _board_target: InteractionTarget
var _board_badge: QuestMarker
var _parts_badge: QuestMarker

static func plan(generator: IslandGenerator) -> Vector3:
	var home := Vector2i(generator.villages[0].center) if not generator.villages.is_empty() else Vector2i.ZERO
	# First choice: the open woodland glade nearest the capital (baked, see
	# SurfaceMap.glades), so Orin and his rocket stand in the open.
	var glade := _glade_site(generator, home)
	if glade.is_finite(): return glade
	var best := Vector3.INF
	var best_score := INF
	# No towns, walls, roads or shore in the clearing. Prefer a level
	# clearing near the woodland heart, with a full ring of trees around it.
	for oz in range(-180,181,12):
		for ox in range(-180,181,12):
			var x := home.x+ox
			var z := home.y+oz
			if Vector2(ox,oz).length()<90 or Vector2(ox,oz).length()>185: continue
			var low := INF
			var high := -INF
			var clear := true
			for dz in [-8,0,8]:
				for dx in [-9,0,9]:
					var col := generator.column(x+dx,z+dz)
					if col.y!=Biomes.WOODS or generator.feature_at(x+dx,z+dz)!=null or generator.map.cell_flags(x+dx,z+dz)&IslandGenerator.BUSY or generator.map.cell_water(x+dx,z+dz)>0: clear=false
					low = minf(low,col.x+1)
					high = maxf(high,col.x+1)
			if not clear: continue
			var score := (high-low)*30.0+Vector2(ox,oz).length()*0.06
			if score<best_score:
				if not _footprint_clear(generator,x,z): continue
				best_score=score
				best=Vector3(x,high+0.18,z)
	if not best.is_finite():
		push_error("No woodland clearing for Starfall Launchworks")
		return best
	best.y = generator.ground_y(best.x, best.z)
	return best

## The nearest woods glade to `home` (within 400 m) that the whole station
## fits in on fairly level ground; INF if none.
static func _glade_site(generator: IslandGenerator, home: Vector2i) -> Vector3:
	var best := Vector3.INF
	var best_distance := 400.0
	for g: Dictionary in generator.map.glades():
		if int(g.biome)!=Biomes.WOODS or float(g.r)<13.0: continue
		var at := Vector2(float(g.at[0]), float(g.at[1]))
		var distance := at.distance_to(Vector2(home))
		if distance>=best_distance or not _footprint_clear(generator, floori(at.x), floori(at.y), 1.6): continue
		best = Vector3(at.x, 0, at.y)
		best_distance = distance
	if best.is_finite(): best.y = generator.ground_y(best.x, best.z)
	return best

## Every column of the footprint checked: nine samples can miss a narrow
## diagonal road, a small ruin or a creek between the corners. `max_rise`
## also asks for fairly level ground.
static func _footprint_clear(generator: IslandGenerator, x: int, z: int, max_rise := INF) -> bool:
	var low := INF
	var high := -INF
	for dz in range(-8,9,2):
		for dx in range(-9,10,2):
			var col := generator.column(x+dx,z+dz)
			if col.y!=Biomes.WOODS or generator.feature_at(x+dx,z+dz)!=null or generator.map.cell_flags(x+dx,z+dz)&IslandGenerator.BUSY or generator.map.cell_water(x+dx,z+dz)>0:
				return false
			low = minf(low,col.x)
			high = maxf(high,col.x)
	return high-low<=max_rise

static func contains(center: Vector3,point: Vector3,margin := 0.0) -> bool:
	return absf(point.x-center.x)<HALF.x+margin and absf(point.z-center.z)<HALF.y+margin

func _ready() -> void:
	name = "StarfallLaunchworks"
	position = world.astral_site
	rocket.name = "Starling"
	_rocket_rest = world.astral_anchor("rocket")-position
	rocket.position = _rocket_rest
	add_child(rocket)
	if not world.server_build and not Net.is_server():
		rocket.build()
		_interactions()
	# Only the rocket hull needs collision; the forest provides the floor.
	var body := StaticBody3D.new()
	body.collision_layer = Player.OBSTACLE_LAYER
	body.collision_mask = 0
	rocket.add_child(body)
	var shape := CollisionShape3D.new()
	var capsule := CylinderShape3D.new()
	capsule.radius = 1.2
	capsule.height = 5.4
	shape.shape = capsule
	shape.position.y = 3.3
	body.add_child(shape)

func _interactions() -> void:
	_board_target=InteractionTarget.new()
	_board_target.position=world.astral_anchor("boarding")-global_position
	_board_target.title="Starling boarding hatch"
	_board_target.action_text="Board"
	_board_target.reach=4.0
	_board_target.response="Boarding the Starling. Waiting for every member of your party."
	_board_target.activated.connect(func(_actor: Node3D) -> void:
		if Net.is_client(): Net.client.send_action("camp",["quest","astral:board"]))
	add_child(_board_target)
	_board_badge=QuestMarker.new("main");_board_target.add_child(_board_badge)
	_parts_badge=QuestMarker.new("main");_parts_badge.position=world.astral_anchor("parts")-global_position;add_child(_parts_badge)

func update_campaign(camp: Dictionary) -> void:
	var step := Campaigns.step_def(str(camp.get("id","")),int(camp.get("step",0)))
	flight=camp.get("astral",{}).get("flight",{})
	if is_instance_valid(_board_target):
		_board_target.enabled=step.get("kind","")=="astral_board" and flight.is_empty()
		_board_badge.visible=_board_target.enabled
		_parts_badge.visible=step.get("kind","")=="astral_parts"

func _process(_delta: float) -> void:
	var now := Net.client.server_time() if Net.is_client() else Net.now()
	var age := now-float(flight.get("start",now+1))
	var active := not flight.is_empty() and age>=0
	var lift := maxf(0,age-3.2) if active else 0.0
	rocket.position = _rocket_rest+Vector3.UP*lift*lift*2.2
	rocket.rotation.z = sin(age*35)*0.002*clampf(age,0,1) if active else 0.0
	rocket.set_flame(clampf(age,0,1) if active else 0.0)
