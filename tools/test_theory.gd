extends Node3D
## Focused route/puzzle/physics smoke check, with optional native image capture.
## Uses local ephemeral stats and generated records, never account saves.
var player: Player
var world: TheoryWorld
var hud := CanvasLayer.new()
var _failures := 0
var _frames := 0

func _process(_delta: float) -> void: _frames += 1

func _ready() -> void:
	add_child(hud)
	if "--main-integration" in OS.get_cmdline_user_args():
		var main: Node = load("res://main.tscn").instantiate()
		add_child(main)
		main.player.input_locked = true
		while main.player.frozen or not main.world.is_presentation_ready(): await get_tree().process_frame
		await get_tree().create_timer(0.3).timeout
		check(main.world is TheoryWorld,"Main loads Theory through the normal dungeon factory")
		check(is_instance_valid(main.player.spatial_controller),"Main attaches spatial controls")
		check(not main.hud.minimap.visible and not main.fog_of_war.visible,"Main hides the planar map and fog")
		main.player._aim_point = main.player.global_position+Vector3(0,2,-8)
		main.player._fire()
		await get_tree().create_timer(0.25).timeout
		check(not main.arrows._shots.is_empty(),"normal equipped weapon fires inside the ship")
		print("[theory] Main integration failures=",_failures)
		get_tree().quit(1 if _failures else 0)
		return
	var loader := WorldLoader.new()
	add_child(loader)
	var before := _frames
	world = await loader.prepare("dng_theory_of_everything_fixture",Dungeons.record("dng_theory_of_everything_fixture","theory_of_everything",4217)) as TheoryWorld
	check(world!=null,"registered dungeon factory prepares custom world")
	check(_frames>before+2,"main loop advances during art preparation")
	if world==null: get_tree().quit(1); return
	print("[theory] modules=",world.art.modules.size()," voxels=",world.art.modules.reduce(func(sum: int,module: Dictionary) -> int: return sum+(module.data as PackedFloat32Array).size()/20,0))
	add_child(world)
	while not world.is_presentation_ready(): await get_tree().process_frame
	await get_tree().physics_frame
	var mounted := true
	for index in TheoryLayout.ELECTRICAL_POSITIONS.size():
		var at: Vector3 = TheoryLayout.ELECTRICAL_POSITIONS[index]
		var facing := TheoryLayout.electrical_frame(index).basis.z
		var mount := PhysicsRayQueryParameters3D.create(at+facing*0.4,at-facing*0.55,Player.OBSTACLE_LAYER)
		mount.exclude = [world.surfaces["electrical_"+str(index)].get_rid()]
		if get_world_3d().direct_space_state.intersect_ray(mount).is_empty(): mounted = false
	check(mounted,"all electrical boxes are mounted against solid bulkheads")
	check(TheoryLayout.ELECTRICAL_POSITIONS.slice(0,5).all(func(at: Vector3) -> bool: return at.y<2 and absf(at.x)<7),"all Aurora boxes are visible on the main corridor deck")
	var cloth := world.soft_details.objects.filter(func(obj: Dictionary) -> bool: return obj.kind=="cloth")[0] as Dictionary
	var touch: Vector3 = cloth.points[(TheorySoftDetails.ROWS-3)*TheorySoftDetails.COLS+2]
	var bodies: Array[Dictionary] = [{pos=Vector3(touch.x,0,touch.z+0.1),previous=Vector3(touch.x,0,touch.z+0.3)}]
	for frame in 12: world.soft_details._simulate(cloth,bodies,1.0/60.0)
	check(absf(cloth.points[(TheorySoftDetails.ROWS-3)*TheorySoftDetails.COLS+2].z-touch.z)>0.2 and cloth.points[0].is_equal_approx(cloth.rest[0]),"curtain moves around a player while its rail stays fixed")
	var packet := TheorySoftDetails.encode(cloth.points)
	world.soft_details.receive(int(cloth.id),Net.now(),packet)
	check(packet.size()<1100 and (cloth.target[12] as Vector3).distance_to(cloth.points[12])<0.001,"cloth snapshot fits one packet and restores its pose")
	var hull := world.art.modules.filter(func(module: Dictionary) -> bool: return module.id=="aurora_0")[0] as Dictionary
	var fixed_floor := true
	var reactive_props := false
	for i in (hull.data as PackedFloat32Array).size()/20:
		if is_equal_approx(hull.data[i*20+7],-0.3) and hull.data[i*20+18]>0.5: fixed_floor = false
		if hull.data[i*20+18]>0.5: reactive_props = true
	check(fixed_floor and reactive_props,"ship floor stays still while obstacle impact effects remain enabled")
	var final_frame: Transform3D = world.layout.paths[0].frames.back()
	check(final_frame.basis.z.dot(Vector3.BACK)>0.999 and final_frame.basis.y.dot(Vector3.UP)>0.999,"approach settles flat and straight into wreck")
	var join_ok := true
	for z in [-479.9,-480.1]:
		var join := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0,0.6,z),Vector3(0,-1,z),Player.OBSTACLE_LAYER))
		if join.is_empty() or absf(join.position.y)>0.02: join_ok = false
	check(join_ok,"road and wreck deck meet at the same height")
	var burned := StatusEffects.new()
	world.update_burning_contact(burned,world.art.fires[0].at)
	check(burned.has_effect("burning") and not world.touches_fire(world.art.fires[0].at+Vector3.UP*8),"wreck fires apply burning without hitting through the upper deck")
	var clear_fire_lane := true
	var varied_fire := {}
	for spec: Dictionary in world.art.fires:
		if world.touches_fire(Vector3(0,float(spec.at.y),float(spec.at.z))): clear_fire_lane = false
		varied_fire[spec.style] = true
	check(clear_fire_lane and varied_fire.size()>1 and world.art.fires.all(func(spec: Dictionary) -> bool: return spec.size>=1.6 and spec.height>=2.8),"larger varied fuel fires leave a safe central passage")
	var room_services := true
	for module: Dictionary in world.art.modules:
		if str(module.id).trim_prefix("aurora_").trim_prefix("wreck_").is_valid_int():
			if not module.has("inlays") or not module.has("round_pipes"): room_services = false
	var bow: Dictionary = world.art.modules.filter(func(module: Dictionary) -> bool: return module.id=="aurora_observation_bow")[0]
	check(room_services and bow.has("inlays") and bow.has("fittings") and bow.has("round_pipes"),"room and observation-bow services publish with material details")
	var wreck_lights := world.art.lights.filter(func(spec: Dictionary) -> bool: return spec.at.z<TheoryLayout.SHIP_B_START and spec.at.z>TheoryLayout.SHIP_B_END)
	check(wreck_lights.size()<18 and wreck_lights.any(func(spec: Dictionary) -> bool: return spec.at.y>12 and spec.get("fault",false)),"fewer wreck ceiling lights cover both decks and include white faults")
	check(not world.surfaces.has("gate_0") and world.surfaces.has("gate_2") and world.surfaces.has("ship_airlock"),"route gates published")
	check(world.layout.puzzle_by_id(1)==null and not world.surfaces.has("gate_1"),"harmonic lock removed")
	check(world._electrical_targets.size()==10,"five electrical boxes in each ship")
	world._operate_electrical_box(world._ship_relay,91,Vector3(0,0,100))
	check(not world.ship_airlock_open,"electrical interaction requires proximity")
	var wrong := (world._ship_relay+1)%5
	world._operate_electrical_box(wrong,91,TheoryLayout.ELECTRICAL_POSITIONS[wrong])
	check(not world.ship_airlock_open,"wrong relay leaves forward airlock closed")
	check("not" in world._electrical_targets[wrong].response or "No airlock" in world._electrical_targets[wrong].response or "elsewhere" in world._electrical_targets[wrong].response,"wrong cabinet explicitly says it is not the airlock relay")
	world._operate_electrical_box(world._ship_relay,91,TheoryLayout.ELECTRICAL_POSITIONS[world._ship_relay])
	check(world.gate_scenes.has("ship_airlock") and not world.surfaces["ship_airlock"].opened,"relay schedules a shared door scene before opening")
	world._update_gate_scenes(float(world.gate_scenes.ship_airlock.end)+0.01)
	check(world.ship_airlock_open and world.surfaces["ship_airlock"].collision_layer==0,"correct relay opens forward airlock")
	check("This is the airlock relay" in world._electrical_targets[world._ship_relay].response and "This is the airlock relay" not in world._electrical_targets[wrong].response,"cabinet results distinguish the correct relay after the door opens")
	for index in range(5,9): world._operate_electrical_box(index,91,TheoryLayout.ELECTRICAL_POSITIONS[index])
	world._operate_electrical_box(5,91,TheoryLayout.ELECTRICAL_POSITIONS[5])
	check(world.repaired_boxes.size()==4 and world.surfaces["gate_2"].collision_layer!=0,"four repairs and duplicate repair keep exit locked")
	world._operate_electrical_box(9,91,TheoryLayout.ELECTRICAL_POSITIONS[9])
	world._update_gate_scenes(float(world.gate_scenes.gate_2.end)+0.01)
	check(world.surfaces["gate_2"].collision_layer==0 and not world._electrical_targets[9]._sparks.active,"fifth repair opens exit and stops box sparks")
	check(world.art.vents.size()>=3,"branching ducts have breakable vents")
	check(world.art.turrets.size()>4,"unstable route has wall turrets")
	check(not world.biome_at(Vector3(0,0,-240)).fog_of_war_enabled,"no fog of war in space")
	check(world.first_person_at(Vector3.ZERO) and world.first_person_at(Vector3(0,0,-500)),"both ships select first person")
	check(not world.first_person_at(Vector3(0,0,-300)),"space selects exterior camera")
	for puzzle: TheoryPuzzle in world.layout.puzzles:
		if puzzle.kind=="parity":
			var reachable := {}
			for mask in 16:
				var bits := 0
				for i in 4:
					if mask&(1<<i): bits = bits^puzzle.masks[i]
				reachable[bits] = true
			check(reachable.size()==16 and reachable.has(puzzle.target),"generated parity circuit is invertible and solvable")
		else:
			var copy := TheoryPuzzle.new(puzzle.id,4217+(137 if puzzle.id==0 else 577),puzzle.frame,puzzle.kind)
			for cell: Vector2i in copy.sequence:
				copy.step(91,copy.frame*Vector3((cell.x-(copy.size-1)*0.5)*copy.cell_size,0.05,(cell.y-(copy.size-1)*0.5)*copy.cell_size))
			check(copy.solved,"generated "+puzzle.kind+" clues match physical solution")
	var server_art := TheoryArt.new()
	server_art.server_only = true
	server_art.build(world.layout)
	var client_shapes := {}
	for module: Dictionary in world.art.modules:
		if not module.sky: client_shapes[module.id] = module.collision
	var parity := true
	for module: Dictionary in server_art.modules:
		if client_shapes.has(module.id) and client_shapes[module.id]!=module.collision: parity = false
	check(parity,"server and client generate identical collision geometry")
	check(server_art.fires==world.art.fires,"server and client place identical fire hazards")
	var first_vent := "vent_0"
	for i in 3: world.impact(first_vent,world.surfaces[first_vent].global_position)
	check(world.surfaces[first_vent].broken and world.surfaces[first_vent].collision_layer==0,"three hits open a vent physically")
	check(world.layout.puzzles.is_empty(),"both remaining minigames are removed")
	var replica := TheoryWorld.new(Dungeons.record("dng_theory_replica","theory_of_everything",4217))
	replica.apply_state(world.state_wire())
	check(replica.layout.puzzles.is_empty() and "vent_0" in replica.broken_vents,"joining players receive shared unobstructed route and vent state")
	check(replica.ship_airlock_open and replica.repaired_boxes.size()==5 and replica.inspected_boxes==world.inspected_boxes,"joining players receive electrical progress")
	check(replica.airlock_relay_box==world._ship_relay,"joining players know which checked box was the airlock relay")
	check(replica.gate_scenes==world.gate_scenes,"joining players receive the same door scene timeline")
	loader.retire(replica)
	player = Player.new()
	player.player_id = GameServer.join(false)
	player.stats = GameServer.character(player.player_id)
	player.stats.gear.weapon = Items.make("G8_bow")
	player.input_locked = true
	add_child(player)
	add_child(player.aim_marker)
	player.place(world.spawn_point,null,world.is_walkable)
	player.set_spatial_world(world)
	var arrows := Arrows.new()
	add_child(arrows)
	arrows.exclude = [player.get_rid()]
	player.shot.connect(func(origin: Vector3,direction: Vector3,damage: int,weapon: Item,phase: float,mods: Dictionary) -> void:
		arrows.spawn(origin,direction,damage,weapon,phase,"",mods))
	await get_tree().create_timer(0.25).timeout
	check(not player.frozen,"custom collision releases arrival without voxel terrain")
	GameServer.report_position(player.player_id,world.realm_id,player.global_position)
	var friend := NetPlayerProxy.new()
	friend.player_id = GameServer.join(false)
	GameServer.report_position(friend.player_id,world.realm_id,Vector3(20,8,-500))
	world.add_child(friend)
	world.enemy_director.players.append(friend)
	var guard := {token=991,end=world.clock_time()+0.25}
	world._protect_gate_scene(guard)
	check(GameServer.intro_locked(player.player_id) and GameServer.intro_locked(friend.player_id) and player.stats.buffs.has_effect("immune") and GameServer.character(friend.player_id).buffs.has_effect("invincible"),"door scene protects and locks all players in the dungeon")
	var hp := player.stats.hp
	GameServer.hit_player(player.player_id,10000,true,false,"fixture")
	GameServer.apply_effects(player.player_id,[{id="burning",duration=3.5}],"fixture")
	check(player.stats.hp==hp and not player.stats.buffs.has_effect("burning"),"door scene blocks lethal damage and negative effects")
	GameServer.cancel_boss_intro(991)
	for id: int in [player.player_id,friend.player_id]:
		GameServer.character(id).buffs.remove("invincible","theory_door_991")
		GameServer.character(id).buffs.remove("immune","theory_door_991")
	world.enemy_director.players.erase(friend)
	GameServer.remove_player(friend.player_id)
	friend.queue_free()
	player.spatial_controller.first_person = 1.0
	player.spatial_controller.update_camera(0.0)
	check(not player.aura.visible,"first-person view hides local equipment particles")
	player._aim_point = player.camera.global_position-player.camera.global_basis.z*12.0
	var muzzle := player.spatial_controller.aim_ray()
	check(((muzzle[0] as Vector3)-player.camera.global_position).dot(player.camera.global_basis.x)>0.2 and (muzzle[1] as Vector3).dot((player._aim_point-muzzle[0]).normalized())>0.999,"first-person muzzle is beside camera and converges on crosshair")
	player.input_locked = false
	player.shield.active = true
	player.shield._process(0.2)
	player.spatial_controller._update_first_person_shield()
	check(player.spatial_controller._fp_shield.visible,"held shield has a first-person surface")
	player.shield.active = false
	player.shield._process(0.2)
	player.spatial_controller._update_first_person_shield()
	check(not player.spatial_controller._fp_shield.visible,"released shield surface fades away")
	player.input_locked = true
	var frame := world.layout.frame_on_path(0,0.42)
	player.global_position = frame.origin+frame.basis.y*0.1
	player.global_basis = frame.basis
	player.spatial_controller.first_person = 0.0
	player.debug_input = Vector2(0,-1)
	var started := player.global_position
	await get_tree().create_timer(0.7).timeout
	player.debug_input = Vector2.ZERO
	check(player.global_position.distance_to(started)>1.0,"player can move on curved gravity ribbon")
	check(player.up_direction.dot(world.surface_frame(player.global_position).basis.y)>0.95,"body up follows curved surface")
	check(player.up_direction.dot(Vector3.UP)<0.0,"walking works upside down")
	check(world._electrical_targets[9]._lever.rotation.x>PI*0.5,"repaired cabinet lever flips down")
	player._aim_point = player.global_position+player.up_direction*10-player.global_basis.z*10
	var aim := player._aim_origin_and_direction()
	check((aim[1] as Vector3).dot(player.up_direction)>0.3,"spatial projectiles preserve vertical aim")
	player.spatial_controller._seen_reveal = true
	var entry := world.surface_frame(Vector3(0,5,-1089))
	player.global_position = entry.origin+entry.basis.y*0.12
	player.global_basis = entry.basis
	player.velocity = Vector3.ZERO
	player.debug_input = Vector2(0,-1)
	await get_tree().create_timer(1.2).timeout
	player.debug_input = Vector2.ZERO
	check(player.global_position.z<-1093.0 and player.global_position.y>2.0,"raised bridge gives physical access to the curved arena")
	if DisplayServer.get_name()!="headless": await _images()
	player.set_spatial_world(null)
	check(player.up_direction.is_equal_approx(Vector3.UP) and Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED,"normal gravity and cursor restore on exit")
	world.set_arena_stage(1)
	check(world.surfaces["arena_0"].collision_layer==0 and world.surfaces["arena_1"].collision_layer!=0,"arena stages remove the outer floor ring")
	print("[theory] smoke complete failures=",_failures)
	get_tree().quit(1 if _failures else 0)

func _images() -> void:
	if "--rooms-preview" in OS.get_cmdline_user_args():
		await _rooms_images()
		return
	if "--soft-preview" in OS.get_cmdline_user_args():
		await _soft_images()
		return
	var atmosphere := Atmosphere.new()
	add_child(atmosphere)
	atmosphere.attach_particles(player)
	player.global_basis = Basis.IDENTITY
	player.up_direction = Vector3.UP
	player.global_position = Vector3(-16,0.06,-72)
	player.camera_yaw = PI*0.5
	player.spatial_controller.first_person = 1.0
	player.spatial_controller.look_pitch = 0.16
	atmosphere.snap_to(world.biome_at(player.global_position))
	await get_tree().create_timer(0.35).timeout
	await snapshot("ship_window")
	player.global_position = Vector3(-18,0.08,-588)
	player.camera_yaw = 0.0
	player.spatial_controller.look_pitch = 0.0
	atmosphere.snap_to(world.biome_at(player.global_position))
	await get_tree().create_timer(0.35).timeout
	await snapshot("wreck_duct")
	player.global_position = Vector3(0,0.08,-503)
	player.spatial_controller.look_pitch = -0.04
	await get_tree().create_timer(0.4).timeout
	await snapshot("wreck_corridor")
	player.global_position = Vector3(-10,0.08,-498.8)
	player.spatial_controller.look_pitch = -0.08
	await get_tree().create_timer(0.3).timeout
	await snapshot("electrical_lever")
	player.spatial_controller.cinematic = true
	player.camera.global_transform = Transform3D(Basis.IDENTITY,Vector3(175,160,-320)).looking_at(Vector3(0,15,-315),Vector3.UP)
	player.camera.fov = 67
	atmosphere.snap_to(world.biome_at(Vector3(0,0,-300)))
	await get_tree().create_timer(0.2).timeout
	await snapshot("space_route")
	player.camera.global_transform = Transform3D(Basis.IDENTITY,TheoryLayout.ARENA+Vector3(50,50,50)).looking_at(TheoryLayout.ARENA+Vector3.UP*5,Vector3.UP)
	await get_tree().create_timer(0.2).timeout
	await snapshot("arena")

func _soft_images() -> void:
	var atmosphere := Atmosphere.new()
	add_child(atmosphere)
	atmosphere.attach_particles(player)
	player.global_basis = Basis.IDENTITY
	player.up_direction = Vector3.UP
	player.global_position = Vector3(2,0.08,-16)
	player.camera_yaw = -PI*0.5
	player.spatial_controller.first_person = 1.0
	player.spatial_controller.look_pitch = 0.12
	atmosphere.snap_to(world.biome_at(player.global_position))
	await get_tree().create_timer(0.3).timeout
	await snapshot("curtain_clean")
	player.global_position = Vector3(-2,0.08,-562.5)
	player.camera_yaw = PI*0.5
	atmosphere.snap_to(world.biome_at(player.global_position))
	await get_tree().create_timer(0.3).timeout
	await snapshot("curtain_torn")
	player.global_position = Vector3(0,0.08,-102)
	player.camera_yaw = 0
	player.spatial_controller.look_pitch = 0
	atmosphere.snap_to(world.biome_at(player.global_position))
	await get_tree().create_timer(0.1).timeout
	world.gate_scenes.clear()
	world.surfaces.ship_airlock.set_gate_progress(0)
	world._request_gate_open("ship_airlock",true)
	await get_tree().create_timer(2.55).timeout
	check(player.spatial_controller.cinematic and player.cinematic_locked,"scheduled door scene owns the local camera")
	await snapshot("door_opening")
	await get_tree().create_timer(3.1).timeout
	check(not player.spatial_controller.cinematic and not player.cinematic_locked and world.surfaces.ship_airlock.opened,"door scene restores controls after the shared opening")

func _rooms_images() -> void:
	var atmosphere := Atmosphere.new()
	add_child(atmosphere)
	atmosphere.attach_particles(player)
	player.global_basis = Basis.IDENTITY
	player.up_direction = Vector3.UP
	player.global_position = Vector3(22,0.08,-1)
	player.camera_yaw = 0
	player.spatial_controller.first_person = 1
	player.spatial_controller.look_pitch = 0.12
	atmosphere.snap_to(world.biome_at(player.global_position))
	await get_tree().create_timer(0.4).timeout
	await snapshot("room_services")
	player.global_position = Vector3(0,0.08,22)
	player.camera_yaw = PI
	atmosphere.snap_to(world.biome_at(player.global_position))
	await get_tree().create_timer(0.35).timeout
	await snapshot("observation_services")
	player.global_position = Vector3(0,0.08,-488)
	player.camera_yaw = 0
	player.spatial_controller.look_pitch = 0.10
	atmosphere.snap_to(world.biome_at(player.global_position))
	await get_tree().create_timer(0.6).timeout
	await snapshot("wreck_fuel_fires")
	player.global_position = Vector3(22,0.08,-492.5)
	player.spatial_controller.look_pitch = 0.15
	await get_tree().create_timer(0.35).timeout
	await snapshot("wreck_room_services")

func snapshot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/void_theory_"+name+".png")

func check(ok: bool,label: String) -> void:
	if ok: print("[theory] PASS ",label)
	else:
		_failures += 1
		push_error("[theory] FAIL "+label)
