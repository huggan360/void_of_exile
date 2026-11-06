class_name TheoryWorld
extends SpatialWorld
## Theory of Everything: two enormous vessels joined by a gravity ribbon in
## deep space. The brood (TheoryEnemies) haunts the ships; the Hollow Empress
## waits in the Convergence and drops its rings as her phases change.
var record: Dictionary
var definition: Dictionary
var layout: TheoryLayout
var enemy_director := EnemyDirector.new()
var surfaces := {}
var broken_vents: Array[String] = []
var arena_stage := 0
var boss_defeated := false
## Authored packs: [position, members]. The wreck has both decks (upper at y 8).
const PACKS := [
	[Vector3(0,0,-96),["hull_skitter","hull_skitter","hull_skitter"]],
	[Vector3(0,8,-70),["hull_skitter","hull_skitter","vent_stalker"]],
	[Vector3(0,0,-498),["hull_skitter","hull_skitter","gloom_spitter"]],
	[Vector3(0,0,-528),["vent_stalker","hull_skitter","hull_skitter","hull_skitter"]],
	[Vector3(0,0,-562),["gloom_spitter","gloom_spitter","void_lamprey"]],
	[Vector3(0,0,-598),["crest_brute","hull_skitter","hull_skitter"]],
	[Vector3(0,0,-632),["vent_stalker","vent_stalker","gloom_spitter"]],
	[Vector3(0,8,-512),["void_lamprey","void_lamprey","hull_skitter"]],
	[Vector3(0,8,-578),["crest_brute","gloom_spitter","hull_skitter"]],
	[Vector3(0,8,-640),["vent_stalker","void_lamprey","void_lamprey"]],
	[Vector3(0,0,-1098),["void_lamprey","gloom_spitter","hull_skitter","hull_skitter"]],
]
var inspected_boxes: Array[int] = []
var repaired_boxes: Array[int] = []
var ship_airlock_open := false
var airlock_relay_box := -1
var _ship_relay := -1
var _electrical_targets := {}
var electrical_quest := "" # Set from the shared campaign; standalone visits use local circuit progress.
var art: TheoryArt
var soft_details: TheorySoftDetails
var _biomes: Array[BiomeDef] = []
var _boards := {}
var _labels := {}
var _projectiles: Array[Dictionary] = []
var _turret_cooldowns := {}
var _puzzle_timer := 0.0
var _shot_serial := 0
var _impact_times := {}
var _reveal := 0.0
var _flicker_lights: Array[Light3D] = []
var _smoke_emitters: Array[GPUParticles3D] = []
var gate_scenes := {}
var _gate_serial := 0
var _gate_admitted := {}
var _inlay_material: ShaderMaterial

func _init(data: Dictionary) -> void:
	record = data
	realm_id = str(data.id)
	display_name = "Theory of Everything"
	definition = Dungeons.definition("theory_of_everything")
	layout = TheoryLayout.new(int(data.get("seed",4217)))
	if not Net.is_client():
		# A new run chooses a new relay, including fixed-seed local previews.
		var relay_rng := RandomNumberGenerator.new()
		relay_rng.randomize()
		_ship_relay = relay_rng.randi_range(0,4)
	spawn_point = Vector3(0,0.08,3)
	half_extent = 1280
	set_meta("full_3d",true)
	for name in ["Aurora / Observation vessel","Chromatic Expanse","Vessel 02 / Derelict","The Unravelling"]:
		var biome := BiomeDef.new()
		biome.id = Biomes.DEEP_DARK
		biome.biome_name = name
		biome.indoor = true
		biome.mood = 1.0
		biome.sky_top_color = Color("010106")
		biome.sky_horizon_color = Color("03030c")
		biome.sun_color = Color("b5bcf5")
		biome.sun_energy = 0.3
		biome.ambient_energy = 0.28
		biome.fog_of_war_enabled = false
		biome.fog_color = Color("010107")
		biome.fog_density = 0.0
		biome.volumetric_fog_density = 0.0
		biome.torch_energy = 0.0
		_biomes.append(biome)
	_biomes[0].ambient_energy = 0.9
	_biomes[0].sun_energy = 0.55
	_biomes[2].ambient_energy = 0.115
	_biomes[2].sun_energy = 0.025
	_biomes[2].torch_energy = 0.12
	if data.has("theory_state"): apply_state(data.theory_state)

func prepare_load() -> void:
	art = TheoryArt.new()
	art.server_only = server_build or Net.is_server()
	art.build(layout)

func inlay_material() -> ShaderMaterial:
	if _inlay_material==null:
		_inlay_material = ShaderMaterial.new()
		_inlay_material.shader = preload("res://shaders/theory_inlays.gdshader")
	return _inlay_material

func _ready() -> void:
	if art==null: prepare_load()
	enemy_director.world = self
	enemy_director.realm_id = realm_id
	enemy_director.remote = Net.is_client()
	add_child(enemy_director)
	if not Net.is_client(): _place_enemies()
	for module: Dictionary in art.modules:
		if server_build or Net.is_server(): _publish(module)
		else: queue_load_step(_publish.bind(module))
	for puzzle: TheoryPuzzle in layout.puzzles:
		if server_build: _publish_puzzle(puzzle)
		else: queue_load_step(_publish_puzzle.bind(puzzle))
	if server_build: _finish_world()
	else: queue_load_step(_finish_world)

func _place_enemies() -> void:
	for i in PACKS.size():
		var members: Array = PACKS[i][1]
		_enemy_site("pack_%d" % i, PACKS[i][0], members)
	if not boss_defeated: _enemy_site("boss", TheoryLayout.ARENA, [definition.boss])
	enemy_director.enemy_killed.connect(func(enemy: Enemy) -> void:
		if enemy.def.id != definition.boss: return
		var event: Array = ["boss_down"]
		handle_event(event)
		world_event.emit(event))

func _enemy_site(name: String, at: Vector3, members: Array) -> void:
	var key := "%s_%s" % [realm_id, name]
	var specs: Array = []
	for member in members: specs.append({enemy = member, min = 1, max = 1})
	Enemies.pack_overrides[key] = {members = specs, respawn_time = -1.0, activate_radius = 40.0}
	enemy_director.add_quest_site({id = key, pack = key, pos = at, seed = int(record.get("seed", 4217)) + key.hash() % 9973})

func make_controller(actor: Player) -> SpatialController:
	local_player = actor
	return TheoryTraversal.new().setup(actor,self)

func _exit_tree() -> void:
	for key: String in Enemies.pack_overrides.keys():
		if key.begins_with(realm_id + "_"): Enemies.pack_overrides.erase(key)

func _publish(data: Dictionary) -> void:
	var surface := TheorySurface.new()
	add_child(surface)
	surface.build(self,data)
	surfaces[str(data.id)] = surface

func _finish_world() -> void:
	_prop("ship_airlock",Transform3D(Basis.IDENTITY,Vector3(0,0,-115)),"airlock")
	_prop("gate_2",Transform3D(Basis.IDENTITY,Vector3(0,0,-670)),"airlock")
	for index in TheoryLayout.ELECTRICAL_POSITIONS.size():
		var surface := _prop("electrical_"+str(index),TheoryLayout.electrical_frame(index),"electrical")
		var target := TheoryElectricalBox.new()
		target.world = self
		target.index = index
		surface.add_child(target)
		_electrical_targets[index] = target
	_update_electrical_visuals(false)
	for i in art.vents.size():
		var vent := _prop("vent_"+str(i),art.vents[i],"vent")
		vent.breakable = true
		if vent.key in broken_vents: vent.shatter()
	for i in art.turrets.size():
		_prop("turret_"+str(i),art.turrets[i],"turret")
		_turret_cooldowns[i] = float(i%3)*0.4+1.0
	_apply_arena_stage(arena_stage)
	soft_details = TheorySoftDetails.new()
	add_child(soft_details)
	soft_details.setup(self)
	# Contact fires exist on the authority too, so burning is shared combat
	# state rather than a local visual effect.
	for spec: Dictionary in art.fires:
		var fire := TheoryWreckFire.new()
		fire.configure(spec)
		fire.position = spec.at
		add_child(fire)
		if not server_build and not Net.is_server(): _smoke(spec.at,float(spec.size),float(spec.get("height",3.5)))
	if server_build or Net.is_server(): return
	for spec: Dictionary in art.lights:
		var light: Light3D = SpotLight3D.new() if spec.get("spot",false) else OmniLight3D.new()
		light.position = spec.at
		light.light_color = spec.color
		light.light_energy = spec.energy
		if light is SpotLight3D:
			var spot := light as SpotLight3D
			spot.spot_range = spec.range
			spot.spot_angle = 72
			spot.spot_attenuation = 0.65
			spot.rotation.x = -PI*0.5
			spot.shadow_enabled = true
		else:
			(light as OmniLight3D).omni_range = spec.range
		light.distance_fade_enabled = true
		light.distance_fade_begin = 45
		light.distance_fade_length = 20
		light.light_volumetric_fog_energy = 0.55
		add_child(light)
		if spec.get("fault",false):
			light.set_meta("base_energy",light.light_energy)
			light.set_meta("seed",float(spec.seed))
			_flicker_lights.append(light)
	for at in art.sparks:
		var sparks := TheorySparks.new()
		sparks.position = at
		add_child(sparks)
	for index in art.spark_jets.size():
		var spec: Dictionary = art.spark_jets[index]
		var sparks := TheorySparks.new()
		sparks.position = spec.at
		sparks.direction = spec.direction
		sparks.interval = spec.interval
		sparks.light_strength = 0.6 if index%6==0 else 0.0
		add_child(sparks)
	for sign: Dictionary in art.signs: _sign(sign.at,sign.text,sign.color)
	DungeonPortal.place(self,{id="spawn_exit",pos=spawn_point+Vector3(0,0,4),exit=true,dungeon="theory_of_everything",destination=record.get("origin","hall")})
	if boss_defeated: _open_star_portal()
	DungeonPortal.place(self,{id="theory_exit",pos=TheoryLayout.ARENA+Vector3(0,3.3,-23),exit=true,dungeon="theory_of_everything",destination=record.get("origin","hall")})

## After the Empress falls: the way on to the Astral Reach and its Nexus.
func _open_star_portal() -> void:
	if server_build or Net.is_server() or has_node("StarPortal"): return
	var portal := _add_portal(TheoryLayout.ARENA+Vector3(0,0.6,8),Vector3.BACK,"astral",Color("7dff9a"),Color("ff8ad8"))
	portal.name = "StarPortal"
	var sign := Label3D.new()
	sign.text = "To the Nexus"
	sign.font = UIStyle.bold()
	sign.font_size = 56
	sign.outline_size = 14
	sign.modulate = Color("ffe6a8")
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.pixel_size = 0.01
	sign.position = Vector3(0,4.6,0)
	portal.add_child(sign)

func _smoke(at: Vector3,size: float,height := 0.0) -> void:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.35*size
	process.direction = Vector3.UP
	process.spread = 24.0
	process.initial_velocity_min = 0.35
	process.initial_velocity_max = 0.8
	process.gravity = Vector3(0,0.12,0)
	process.scale_min = 0.65*size
	process.scale_max = 1.3*size
	var gradient := Gradient.new()
	gradient.set_color(0,Color(0.12,0.13,0.16,0))
	gradient.add_point(0.18,Color(0.12,0.13,0.16,0.17))
	gradient.add_point(0.65,Color(0.16,0.17,0.20,0.10))
	gradient.set_color(gradient.get_point_count()-1,Color(0.18,0.19,0.22,0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	var curve := Curve.new()
	curve.add_point(Vector2(0,0.25))
	curve.add_point(Vector2(1,1.6))
	var growth := CurveTexture.new()
	growth.curve = curve
	process.scale_curve = growth
	var shape := QuadMesh.new()
	shape.size = Vector2.ONE*0.70
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var fade := Gradient.new()
	fade.set_color(0,Color.WHITE)
	fade.add_point(0.3,Color(1,1,1,0.65))
	fade.set_color(1,Color(1,1,1,0))
	var texture := GradientTexture2D.new()
	texture.gradient = fade
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5,0.5)
	texture.fill_to = Vector2(1,0.5)
	material.albedo_texture = texture
	shape.material = material
	var smoke := GPUParticles3D.new()
	smoke.process_material = process
	smoke.draw_pass_1 = shape
	smoke.amount = 16
	smoke.lifetime = 3.8
	smoke.preprocess = 0.8
	smoke.position = at+Vector3.UP*(0.8+height*0.35)
	smoke.emitting = false
	smoke.visibility_aabb = AABB(Vector3(-3,-1,-3),Vector3(6,7,6))
	smoke.visibility_range_end = 55
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(smoke)
	_smoke_emitters.append(smoke)

func _prop(key: String,frame: Transform3D,type: String) -> TheorySurface:
	var sculpt := TheoryArt.new()
	sculpt.server_only = server_build or Net.is_server()
	sculpt._ship_mode = type=="electrical"
	sculpt._begin(key,frame,140)
	match type:
		"gate":
			sculpt._panel(Vector3(0,2.7,0),Vector3(20.0,5.4,0.5),Color("18283b"),true,0.5)
			for x in range(-9,10): sculpt._box(Vector3(x,2.7,0.3),Vector3(0.12,4.8,0.08),Color("ef69e9"),1.6)
		"airlock":
			sculpt._panel(Vector3(0,2.7,0),Vector3(13.35,5.4,0.6),Color("7b8c9c"),true,0.45)
			sculpt._box(Vector3(0,2.7,0.34),Vector3(0.08,5.3,0.08),Color("172232"))
			for side in [-1.0,1.0]:
				for i in 12:
					sculpt._box(Vector3(side*5.9,0.28+i*0.43,0.36),Vector3(0.45,0.23,0.06),TheoryArt.GOLD if i%2 else TheoryArt.DARK)
				sculpt._box(Vector3(side*0.6,2.4,0.38),Vector3(0.15,0.75,0.12),TheoryArt.DARK)
		"electrical":
			sculpt._panel(Vector3(0,0,-0.24),Vector3(1.12,1.45,0.16),TheoryArt.STEEL,true,0.15)
			sculpt._panel(Vector3.ZERO,Vector3(1.05,1.35,0.32),Color("62798a"),true,0.15)
			sculpt._box(Vector3(0,0.02,0.18),Vector3(0.82,0.85,0.08),TheoryArt.DARK)
			for i in 3:
				sculpt._pipe(Vector3(-0.25+i*0.17,-0.17,0.24),Vector3(-0.25+i*0.17,0.37,0.24),TheoryArt.GOLD if i%2 else TheoryArt.CYAN,0.0325)
				sculpt._box(Vector3(-0.25+i*0.17,-0.24,0.24),Vector3(0.10,0.14,0.12),TheoryArt.TRIM)
			sculpt._pipe(Vector3(0,-0.7,0),Vector3(0,-1.45,0),TheoryArt.DARK,0.09)
		"vent":
			for x in [-1.55,1.55]: sculpt._box(Vector3(x,1.5,0),Vector3(0.2,3.0,0.25),Color("758a9e"))
			for y in 11: sculpt._box(Vector3(0,0.15+y*0.27,0),Vector3(3.0,0.12,0.16),Color("5b687f"))
			sculpt._part.collision.append({at=Vector3(0,1.5,0),size=Vector3(3.25,3.0,0.2)})
		"turret":
			sculpt._panel(Vector3.ZERO,Vector3(1.5,1.5,1.5),Color("333a52"),true,0.3)
			sculpt._box(Vector3(-1,0,0),Vector3(1.4,0.35,0.45),Color("91aac2"))
			sculpt._box(Vector3(-1.72,0,0),Vector3(0.12,0.26,0.35),Color("ff516e"),2)
	sculpt._finish()
	if type in ["gate","airlock"]:
		# The opened door retracts into this fixed frame instead of hovering.
		sculpt._impact_enabled = false
		sculpt._begin(key+"_frame",frame,140)
		var half_width := 10.0 if type=="gate" else 6.7
		for side in [-1.0,1.0]:
			sculpt._panel(Vector3(side*(half_width-0.3),2.7,0),Vector3(0.6,5.4,0.85),TheoryArt.STEEL,true,0.3)
			sculpt._box(Vector3(side*(half_width-0.3),2.7,0.46),Vector3(0.12,4.6,0.08),TheoryArt.CYAN,0.7)
		sculpt._panel(Vector3(0,5.85,0),Vector3(half_width*2,0.9,0.85),TheoryArt.STEEL,true,0.3)
		sculpt._finish()
	for module: Dictionary in sculpt.modules: _publish(module)
	return surfaces[key]

func _publish_puzzle(puzzle: TheoryPuzzle) -> void:
	if not server_build and not Net.is_server():
		var board := MultiMeshInstance3D.new()
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		var mesh := BoxMesh.new()
		mesh.size = Vector3(puzzle.cell_size-0.06,0.06,puzzle.cell_size-0.06)
		multi.mesh = mesh
		multi.instance_count = puzzle.size*puzzle.size
		for y in puzzle.size:
			for x in puzzle.size:
				multi.set_instance_transform(y*puzzle.size+x,Transform3D(Basis.IDENTITY,Vector3((x-(puzzle.size-1)*0.5)*puzzle.cell_size,0.06,(y-(puzzle.size-1)*0.5)*puzzle.cell_size)))
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.emission_enabled = true
		mat.emission = Color("11131e")
		board.material_override = mat
		board.multimesh = multi
		board.transform = puzzle.frame
		add_child(board)
		_boards[puzzle.id] = board
		for i in puzzle.active_cells.size():
			if puzzle.kind=="algorithm" and i>0: continue
			var cell: Vector2i = puzzle.active_cells[i]
			var point := puzzle.frame*Vector3((cell.x-(puzzle.size-1)*0.5)*puzzle.cell_size,0.2,(cell.y-(puzzle.size-1)*0.5)*puzzle.cell_size)
			_sign(point,"START" if puzzle.kind=="algorithm" else char(65+i),Color.WHITE,0.024)
		_labels[puzzle.id] = _sign(puzzle.frame*Vector3(0,3.2,-3.9 if puzzle.id==2 else 6.0),puzzle.clue(),Color("c5ebff"),0.012)
		_labels[puzzle.id].width = 900
		_labels[puzzle.id].autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_paint_board(puzzle)
	var target := InteractionTarget.new()
	target.title = "Pathfinder" if puzzle.id==0 else "Parity engine (optional)"
	target.description = "Read the console and solve the physical grid." if puzzle.id==0 else "An optional diagnostic grid. Ship repairs control the escape airlock."
	target.response = puzzle.clue()
	target.action_text = "Read"
	target.position = puzzle.frame*(Vector3(-5,1.1,0) if puzzle.id==2 else Vector3(-7.6,1.1,7.8))
	target.reach = 4.5
	add_child(target)

func _paint_board(puzzle: TheoryPuzzle) -> void:
	if not _boards.has(puzzle.id): return
	var multi: MultiMesh = _boards[puzzle.id].multimesh
	for y in puzzle.size:
		for x in puzzle.size:
			var cell := Vector2i(x,y)
			var color := Color("8493a6") if (x+y)%2==0 else Color("182237")
			var index := puzzle.active_cells.find(cell)
			if puzzle.kind=="algorithm":
				if cell==puzzle.sequence[0]: color = Color("3bbbf1")
				if cell in puzzle.sequence.slice(0,puzzle.progress): color = Color("62edac")
			elif index>=0: color = [Color("edaa4b"),Color("59c5f5"),Color("ed6bb2"),Color("84eb9b")][index]
			if puzzle.solved: color = color.lerp(Color("8effbe"),0.65)
			multi.set_instance_color(y*puzzle.size+x,color)
	if _labels.has(puzzle.id):
		_labels[puzzle.id].text = ("LOCK RELEASED" if puzzle.id==0 else "DIAGNOSTIC COMPLETE") if puzzle.solved else ("CURRENT %s / TARGET %s\n%s" % [TheoryPuzzle.binary(puzzle.bits),TheoryPuzzle.binary(puzzle.target),puzzle.clue()] if puzzle.kind=="parity" else puzzle.clue())

func _sign(at: Vector3,text: String,color: Color,pixel := 0.018) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font = UIStyle.bold()
	label.font_size = 36
	label.pixel_size = pixel
	label.modulate = color
	label.outline_size = 5
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = at
	label.no_depth_test = false
	label.visibility_range_end = 60.0
	add_child(label)
	return label

func _process(delta: float) -> void:
	super._process(delta)
	if is_presentation_ready(): _update_gate_scenes()
	var time := clock_time()
	if _inlay_material!=null: _inlay_material.set_shader_parameter("clock",time)
	var camera := get_viewport().get_camera_3d()
	for smoke in _smoke_emitters:
		smoke.emitting = camera!=null and smoke.global_position.distance_squared_to(camera.global_position)<3025.0
	for lamp in _flicker_lights:
		var gain := TheoryLampTiming.level(time,float(lamp.get_meta("seed")))
		lamp.light_energy = float(lamp.get_meta("base_energy"))*gain
		lamp.visible = gain>0.035

func _physics_process(delta: float) -> void:
	if not is_presentation_ready(): return
	if not Net.is_client():
		_puzzle_timer -= delta
		if _puzzle_timer<=0.0:
			_puzzle_timer = 0.08
			var players: Array = enemy_director.players.duplicate()
			if is_instance_valid(local_player): players.append(local_player)
			for actor: Node3D in players:
				if not is_instance_valid(actor) or actor.frozen: continue
				for puzzle: TheoryPuzzle in layout.puzzles:
					if puzzle.step(actor.player_id,actor.global_position):
						var event: Array = ["puzzle",puzzle.state()]
						handle_event(event)
						world_event.emit(event)
		_update_turrets(delta)
	if not server_build: _update_projectiles(delta)

func _update_turrets(delta: float) -> void:
	if Net.is_client(): return
	var players: Array = enemy_director.players.duplicate()
	if is_instance_valid(local_player): players.append(local_player)
	for index: int in _turret_cooldowns:
		_turret_cooldowns[index] -= delta
		if _turret_cooldowns[index]>0.0: continue
		var frame: Transform3D = art.turrets[index]
		var target: Node3D
		var distance := 31.0
		for actor: Node3D in players:
			if not is_instance_valid(actor) or actor.frozen or GameServer.intro_protected(actor.player_id): continue
			var d := frame.origin.distance_to(actor.global_position)
			if d<distance:
				distance = d
				target = actor
		if target==null: continue
		_turret_cooldowns[index] = 1.7+float(index%3)*0.15
		var up := surface_frame(target.global_position).basis.y
		var direction := (target.global_position+up-frame.origin).normalized()
		_shot_serial += 1
		var event: Array = ["shot",frame.origin+direction*1.0,direction,_shot_serial]
		handle_event(event)
		world_event.emit(event)

func _spawn_projectile(from: Vector3,direction: Vector3) -> void:
	if server_build or not from.is_finite() or not direction.is_finite() or direction.is_zero_approx(): return
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.18,0.18,0.6)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color("ffaac7")
	mat.emission_enabled = true
	mat.emission = Color("ff395c")
	mat.emission_energy_multiplier = 2.2
	node.mesh = mesh
	node.material_override = mat
	add_child(node)
	node.global_position = from
	var up := Vector3.RIGHT if absf(direction.dot(Vector3.UP))>0.98 else Vector3.UP
	node.look_at(from+direction,up)
	_projectiles.append({node=node,direction=direction,life=3.0})

func _update_projectiles(delta: float) -> void:
	for i in range(_projectiles.size()-1,-1,-1):
		var shot: Dictionary = _projectiles[i]
		var from: Vector3 = shot.node.global_position
		var to := from+(shot.direction as Vector3)*delta*18.0
		shot.life -= delta
		var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,Player.TERRAIN_LAYER|Player.OBSTACLE_LAYER))
		if is_instance_valid(local_player) and not local_player.frozen:
			var chest := local_player.global_position+local_player.up_direction
			if Geometry3D.get_closest_point_to_segment(chest,from,to).distance_to(chest)<0.65:
				local_player.last_hit_by = "Chromatic wall turret"
				local_player.take_damage(32.0,false,true)
				shot.life = -1.0
		if not hit.is_empty():
			if hit.collider is TheorySurface: hit.collider.flash(hit.position)
			shot.life = -1.0
		shot.node.global_position = to
		if shot.life<=0.0:
			shot.node.queue_free()
			_projectiles.remove_at(i)

func request_electrical_box(index: int,actor: Player) -> void:
	if Net.is_client(): Net.client.send_action("theory",["box",index])
	else: _operate_electrical_box(index,actor.player_id,actor.global_position)

func _operate_electrical_box(index: int,actor_id: int,position: Vector3) -> void:
	if Net.is_client() or index<0 or index>=TheoryLayout.ELECTRICAL_POSITIONS.size() or not position.is_finite(): return
	if not is_presentation_ready() or position.distance_to(TheoryLayout.ELECTRICAL_POSITIONS[index])>3.4: return
	if index<5:
		if index in inspected_boxes: return
		inspected_boxes.append(index)
		if index==_ship_relay:
			ship_airlock_open = true
			airlock_relay_box = index
	else:
		if index in repaired_boxes: return
		repaired_boxes.append(index)
	var event: Array = ["electrical",_electrical_state(),actor_id,index]
	handle_event(event)
	world_event.emit(event)

func _electrical_state() -> Dictionary:
	return {inspected=inspected_boxes.duplicate(),repaired=repaired_boxes.duplicate(),ship_open=ship_airlock_open,relay_box=airlock_relay_box}

func _apply_electrical_state(data: Dictionary) -> void:
	inspected_boxes.clear()
	for index: Variant in data.get("inspected",[]):
		if (index is int or index is float) and is_finite(float(index)) and float(index)==floorf(float(index)) and index>=0 and index<5 and not int(index) in inspected_boxes: inspected_boxes.append(int(index))
	repaired_boxes.clear()
	for index: Variant in data.get("repaired",[]):
		if (index is int or index is float) and is_finite(float(index)) and float(index)==floorf(float(index)) and index>=5 and index<10 and not int(index) in repaired_boxes: repaired_boxes.append(int(index))
	ship_airlock_open = bool(data.get("ship_open",false))
	var relay := int(data.get("relay_box",-1))
	airlock_relay_box = relay if ship_airlock_open and relay>=0 and relay<5 and relay in inspected_boxes else -1

func _update_electrical_visuals(animate := true) -> void:
	for target: TheoryElectricalBox in _electrical_targets.values(): target.refresh(null)
	if ship_airlock_open: _request_gate_open("ship_airlock",animate)
	if repaired_boxes.size()==5: _request_gate_open("gate_2",animate)

func clock_time() -> float:
	return Net.client.server_time() if Net.is_client() and Net.client!=null else Net.now()

func _request_gate_open(key: String,animate: bool) -> void:
	if not surfaces.has(key): return
	if gate_scenes.has(key):
		if bool(gate_scenes[key].get("done",false)) or clock_time()>=float(gate_scenes[key].end): surfaces[key].open_gate()
		return
	if not animate:
		surfaces[key].open_gate()
		return
	if Net.is_client() or surfaces[key].opened: return
	_gate_serial += 1
	var start := clock_time()+0.85
	for scene: Dictionary in gate_scenes.values(): start = maxf(start,float(scene.end)+0.2)
	var scene := {key=key,serial=_gate_serial,token=hash(realm_id+key+str(_gate_serial)),start=start,open_at=start+1.0,end=start+4.6,done=false}
	var event: Array = ["gate",scene]
	handle_event(event)
	_protect_gate_scene(scene)
	world_event.emit(event)

func _protect_gate_scene(scene: Dictionary) -> void:
	var remaining := float(scene.end)-clock_time()
	if remaining<=0.0: return
	var token := int(scene.token)
	if not _gate_admitted.has(token): _gate_admitted[token] = []
	var actors: Array = enemy_director.players.duplicate()
	if is_instance_valid(local_player): actors.append(local_player)
	for actor: Node3D in actors:
		if not is_instance_valid(actor): continue
		var id: int = actor.player_id
		if id in _gate_admitted[token] or GameServer.player_realm(id)!=realm_id: continue
		var stats := GameServer.character(id)
		if stats==null or stats.hp<=0.0: continue
		stats.buffs.add("invincible",remaining+0.35,1,"theory_door_"+str(token))
		stats.buffs.add("immune",remaining+0.35,1,"theory_door_"+str(token))
		GameServer.begin_boss_intro(token,realm_id,[id],remaining)
		_gate_admitted[token].append(id)

func _update_gate_scenes(at := NAN) -> void:
	var now := clock_time() if is_nan(at) else at
	for key: String in gate_scenes:
		var scene: Dictionary = gate_scenes[key]
		if bool(scene.get("done",false)):
			if surfaces.has(key) and not surfaces[key].opened: surfaces[key].open_gate()
			continue
		if now>=float(scene.end):
			scene.done = true
			if surfaces.has(key): surfaces[key].open_gate()
			continue
		_protect_gate_scene(scene)
		if surfaces.has(key): surfaces[key].set_gate_progress((now-float(scene.open_at))/1.4)
		if is_instance_valid(local_player) and is_instance_valid(local_player.spatial_controller):
			local_player.spatial_controller.start_gate_cinematic(scene)

func _electrical_feedback(actor_id: int,index: int) -> void:
	if not is_instance_valid(local_player) or local_player.player_id!=actor_id: return
	var main := get_parent()
	var hud := main.get("hud") as Hud
	if hud==null: return
	var found := index==airlock_relay_box
	var message := "This is the airlock relay. Forward airlock open." if found else "Not this one. This circuit does not control the airlock."
	if index>=5: message = "All five circuits restored. Escape airlock unlocked." if repaired_boxes.size()==5 else "%s restored. %d/5 circuits online." % [TheoryLayout.ELECTRICAL_NAMES[index],repaired_boxes.size()]
	hud.toasts.push(message,UIStyle.GOOD if index>=5 or found else UIStyle.TEXT,3.5)

func impact(key: String,at: Vector3) -> void:
	if not surfaces.has(key): return
	var surface: TheorySurface = surfaces[key]
	surface.flash(at)
	if surface.breakable and not surface.broken:
		surface.hits += 1
		if surface.hits>=3:
			broken_vents.append(key)
			var event: Array = ["break",key]
			handle_event(event)
			world_event.emit(event)
	world_event.emit(["impact",key,at])

func server_action(player_record: Dictionary,args: Array) -> void:
	if args.size()==2 and str(args[0])=="box" and args[1] is int:
		if not player_record.dead and not GameServer.intro_locked(int(player_record.player_id)): _operate_electrical_box(int(args[1]),int(player_record.player_id),player_record.pos)
		return
	if args.size()!=3 or str(args[0])!="impact" or not args[2] is Vector3: return
	var key := str(args[1])
	var at: Vector3 = args[2]
	if not at.is_finite() or not surfaces.has(key): return
	var stats := GameServer.character(int(player_record.player_id))
	var weapon: Item = stats.gear.weapon if stats!=null else null
	if weapon==null or player_record.dead or GameServer.interacting(player_record.player_id): return
	if at.distance_to(player_record.pos)>weapon.projectile_range()*2.0+3.0: return
	var local := (surfaces[key] as TheorySurface).to_local(at)
	if not (surfaces[key].plan.bounds as AABB).grow(1.5).has_point(local): return
	var source: Vector3 = player_record.pos+surface_frame(player_record.pos).basis.y*1.2
	var ray := PhysicsRayQueryParameters3D.create(source,at+(at-source).normalized()*0.25,Player.TERRAIN_LAYER|Player.OBSTACLE_LAYER)
	var obstruction := get_world_3d().direct_space_state.intersect_ray(ray)
	if not obstruction.is_empty() and obstruction.collider!=surfaces[key]: return
	var token := str(player_record.player_id)+":"+key
	var now := Time.get_ticks_msec()*0.001
	if now-float(_impact_times.get(token,-10.0))<0.08: return
	_impact_times[token] = now
	impact(key,at)

func handle_event(event: Array) -> void:
	match str(event[0]):
		"gate":
			var scene: Dictionary = event[1]
			gate_scenes[str(scene.key)] = scene.duplicate(true)
			_gate_serial = maxi(_gate_serial,int(scene.serial))
		"electrical":
			_apply_electrical_state(event[1])
			_update_electrical_visuals()
			if event.size()>3: _electrical_feedback(int(event[2]),int(event[3]))
		"puzzle":
			var puzzle := layout.puzzle_by_id(int(event[1].id))
			if puzzle==null: return
			puzzle.apply(event[1])
			_paint_board(puzzle)
			if puzzle.id==0 and puzzle.solved: _request_gate_open("gate_0",true)
		"impact":
			if surfaces.has(str(event[1])): surfaces[str(event[1])].flash(event[2])
		"break":
			var key := str(event[1])
			if not key in broken_vents: broken_vents.append(key)
			if surfaces.has(key): surfaces[key].shatter()
		"shot": _spawn_projectile(event[1],event[2])
		"arena": _apply_arena_stage(int(event[1]))
		"boss_down":
			boss_defeated = true
			_open_star_portal()

func state_wire() -> Dictionary:
	return {gates=gate_scenes.duplicate(true),electrical=_electrical_state(),puzzles=layout.puzzles.map(func(p: TheoryPuzzle) -> Dictionary: return p.state()),vents=broken_vents.duplicate(),arena=arena_stage,boss=boss_defeated}

func apply_state(data: Dictionary) -> void:
	gate_scenes = data.get("gates",{}).duplicate(true)
	for scene: Dictionary in gate_scenes.values(): _gate_serial = maxi(_gate_serial,int(scene.serial))
	for state: Dictionary in data.get("puzzles",[]):
		var puzzle := layout.puzzle_by_id(int(state.id))
		if puzzle!=null: puzzle.apply(state)
	_apply_electrical_state(data.get("electrical",{}))
	broken_vents.assign(data.get("vents",[]))
	arena_stage = int(data.get("arena",0))
	boss_defeated = bool(data.get("boss",false))
	if boss_defeated and is_inside_tree(): _open_star_portal()

func set_arena_stage(stage: int) -> void:
	if Net.is_client(): return
	var event: Array = ["arena",clampi(stage,0,3)]
	handle_event(event)
	world_event.emit(event)

func _apply_arena_stage(stage: int) -> void:
	arena_stage = stage
	for ring in 4:
		var key := "arena_"+str(ring)
		if not surfaces.has(key): continue
		var surface: TheorySurface = surfaces[key]
		if ring>=stage:
			surface.bend_arena(0.006+stage*0.003)
			# A reset attempt rebuilds the rings that fell.
			if surface.collision_layer==0:
				surface.collision_layer = Player.OBSTACLE_LAYER
				if surface.visual!=null:
					surface.visual.position.y = 0.0
					surface.visual.show()
		if ring<stage and surface.collision_layer!=0:
			surface.collision_layer = 0
			if surface.visual!=null:
				var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
				tween.tween_property(surface.visual,"position:y",-35.0,2.5)
				tween.tween_callback(surface.visual.hide)

func barrier_between(from: Vector3,to: Vector3) -> Dictionary:
	var closed: Array[String] = []
	for key: String in ["gate_0","ship_airlock","gate_2"]:
		if surfaces.has(key) and not surfaces[key].opened: closed.append(key)
	for key: String in closed:
		if not surfaces.has(key): continue
		var frame: Transform3D = surfaces[key].global_transform
		var a := frame.affine_inverse()*from
		var b := frame.affine_inverse()*to
		if a.z<0.0 or b.z>=0.0: continue
		var crossing := a.lerp(b,a.z/maxf(0.001,a.z-b.z))
		if absf(crossing.x)<12.0 and absf(crossing.y)<28.0:
			return {point=frame*Vector3(clampf(a.x,-4.0,4.0),0.15,2.0)}
	return {}

func recovery_point(position: Vector3) -> Vector3:
	var frame := surface_frame(position)
	var point := frame.origin
	if zone_at(position)=="arena":
		var offset := Vector2(point.x-TheoryLayout.ARENA.x,point.z-TheoryLayout.ARENA.z)
		offset = offset.limit_length(25.0-arena_stage*5.5)
		point = TheoryLayout.ARENA+Vector3(offset.x,offset.length_squared()*(0.006+arena_stage*0.003),offset.y)
		frame = surface_frame(point)
	return point+frame.basis.y*0.12

func legal_recovery(from: Vector3,to: Vector3) -> bool:
	var frame := surface_frame(from)
	return (from-frame.origin).dot(frame.basis.y)<-3.0 and from.distance_to(to)<23.0 and to.distance_to(recovery_point(from))<2.5

func sample_gravity(position: Vector3) -> Dictionary:
	var sample := layout.sample(position)
	if sample.zone=="arena" and arena_stage>0:
		var offset := position-TheoryLayout.ARENA
		var factor := 0.006+arena_stage*0.003
		var up := Vector3(-offset.x*factor*2.0,1.0,-offset.z*factor*2.0).normalized()
		var right := Vector3.RIGHT.slide(up).normalized()
		sample.frame = Transform3D(Basis(right,up,right.cross(up)),Vector3(position.x,Vector2(offset.x,offset.z).length_squared()*factor,position.z))
	return sample

func surface_frame(position: Vector3) -> Transform3D:
	return sample_gravity(position).frame

func zone_at(position: Vector3) -> String:
	return str(layout.sample(position).zone)

func first_person_at(position: Vector3) -> bool:
	return position.z>TheoryLayout.SHIP_A_END-5.0 or (position.z<TheoryLayout.SHIP_B_START+5.0 and position.z>TheoryLayout.SHIP_B_END-5.0)

func biome_at(position: Vector3) -> BiomeDef:
	if position.z>TheoryLayout.SHIP_A_END: return _biomes[0]
	if position.z<TheoryLayout.SHIP_B_START and position.z>TheoryLayout.SHIP_B_END: return _biomes[2]
	return _biomes[3] if position.z<TheoryLayout.SHIP_B_END else _biomes[1]

## Only the Convergence bowl has a known height; ships use enemy_floor.
func ground_height(x: float,z: float) -> float:
	var offset := Vector2(x-TheoryLayout.ARENA.x,z-TheoryLayout.ARENA.z)
	if z>-1068.0 or offset.length()>=30.0: return 0.0
	return offset.length_squared()*arena_factor()

func arena_factor() -> float: return 0.006+arena_stage*0.003

## Floor under a spawn candidate, keeping the deck its site was placed on.
func enemy_floor(at: Vector3) -> float:
	return layout.sample(at).frame.origin.y if zone_at(at) in ["ship","wreck"] else ground_height(at.x,at.z)

## Shots fired in the bowl keep their height above its curved floor.
func shot_bowl(origin: Vector3) -> Array:
	if zone_at(origin)!="arena": return []
	return [TheoryLayout.ARENA.x,TheoryLayout.ARENA.z,arena_factor()]
func is_walkable(position: Vector3) -> bool: return layout.validate_position(position)
func map_color(_x: int,_z: int) -> Color: return Color("060713")
func obstacles_near(_at: Vector3,_radius: float) -> Array[String]: return []
func remove_obstacle(_id: String) -> void: pass
