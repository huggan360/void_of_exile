class_name TheoryTraversal
extends SpatialController
## Local magnetic gravity and smoothly blended ship/exterior cameras. Combat
## stays in Player's shared weapon, charge, shield and damage code.
var world: TheoryWorld
var _checkpoint := Vector3.ZERO
var _old_far := 4000.0
var _old_mouse := Input.MOUSE_MODE_VISIBLE
var _hud: CanvasLayer
var _overlay: Control
var _title: Label
var _objective: Label
var _dot: Control
var _flashlight: SpotLight3D
var _seen_reveal := false
var _camera_env: Environment
var _prior_env: Environment
var _bars: Control
var _walk_speed := 0.0
var _bob_phase := 0.0
var _bob_weight := 0.0
var _flashlight_rng := RandomNumberGenerator.new()
var _flashlight_pause := 1.8
var _flashlight_fault := 0.0
var _flashlight_clock := 0.0
var _flashlight_in_wreck := false
var _door_scene := {}
var _door_saved := {}
var _door_hud: CanvasLayer
var _last_door_serial := -1
var _door_presenting := false

func setup(actor: Player,place: TheoryWorld) -> TheoryTraversal:
	player = actor
	world = place
	_checkpoint = actor.global_position
	_old_far = actor.camera.far
	_old_mouse = Input.mouse_mode
	return self

func _ready() -> void:
	_flashlight_rng.randomize()
	player.camera.far = 6500.0
	_prior_env = player.camera.environment
	var original := _prior_env if _prior_env!=null else player.get_world_3d().environment
	_camera_env = original.duplicate() as Environment if original!=null else Environment.new()
	_camera_env.background_mode = Environment.BG_COLOR
	_camera_env.background_color = Color("010107")
	_camera_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_camera_env.ambient_light_color = Color("c7daed")
	_camera_env.fog_enabled = false
	_camera_env.glow_enabled = true
	_camera_env.glow_intensity = 0.48
	_camera_env.glow_bloom = 0.025
	player.camera.environment = _camera_env
	player.floor_snap_length = 0.9
	player.floor_max_angle = deg_to_rad(65.0)
	player.floor_constant_speed = true
	_hud = ResponsiveUILayer.new()
	_hud.layer = 32
	add_child(_hud)
	_overlay = (_hud as ResponsiveUILayer).make_ui_root()
	_bars = Control.new()
	_bars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_bars)
	for lower in [false,true]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bar.anchor_top = 0.88 if lower else 0.0
		bar.anchor_bottom = 1.0 if lower else 0.12
		_bars.add_child(bar)
	_bars.hide()
	_title = UIStyle.label("",22,Color("b7daee"))
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_title.position = Vector2(-300,70)
	_title.size = Vector2(600,32)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay.add_child(_title)
	_objective = UIStyle.label("",18,Color("9caec5"))
	_objective.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_objective.position = Vector2(-330,105)
	_objective.size = Vector2(660,100)
	_objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay.add_child(_objective)
	_dot = Control.new()
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dot.draw.connect(func() -> void:
		var center := _dot.size*0.5
		_dot.draw_circle(center,3.6,Color(0,0,0,0.65))
		_dot.draw_circle(center,2.1,Color.WHITE))
	_overlay.add_child(_dot)
	_flashlight = SpotLight3D.new()
	_flashlight.light_color = Color("c5dbf3")
	_flashlight.light_energy = 4.0
	_flashlight.spot_range = 27
	_flashlight.spot_angle = 36
	_flashlight.spot_attenuation = 1.2
	_flashlight.shadow_enabled = true
	_flashlight.position = Vector3(0.16,-0.12,-0.15)
	player.camera.add_child(_flashlight)
	_build_first_person_shield()

func _process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(world): return
	if not _door_scene.is_empty(): _update_gate_cinematic()
	_flashlight_clock += delta
	var wreck := world.zone_at(player.global_position)=="wreck"
	if wreck and not _flashlight_in_wreck: _flashlight_pause = 1.8
	_flashlight_in_wreck = wreck
	var power := 1.0
	if wreck and _flashlight.visible and not cinematic:
		_flashlight_pause -= delta
		if _flashlight_pause<=0.0:
			_flashlight_fault = _flashlight_rng.randf_range(0.25,0.65)
			_flashlight_pause = _flashlight_rng.randf_range(5.0,12.0)
		_flashlight_fault = maxf(0.0,_flashlight_fault-delta)
		power = 0.92+0.025*sin(_flashlight_clock*7.3)
		if _flashlight_fault>0.0:
			power *= 0.45 if sin(_flashlight_clock*47.0)+0.4*sin(_flashlight_clock*83.0)>0.15 else 0.7
	else:
		_flashlight_fault = 0.0
	_flashlight.light_energy = (9.0 if wreck else 5.0)*power
	_flashlight.spot_angle = 42.0 if wreck else 38.0
	_flashlight.spot_range = 42.0 if wreck else 32.0

func hide_overlay() -> void:
	if is_instance_valid(_overlay): _overlay.hide()
	if is_instance_valid(_fp_shield): _fp_shield.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and not cinematic and not player.controls_locked():
		player.camera_yaw -= event.relative.x*0.0022
		look_pitch = clampf(look_pitch-event.relative.y*0.0022,-1.35,1.35)
		get_viewport().set_input_as_handled()

func physics_step(delta: float) -> void:
	if not is_instance_valid(world): return
	if player.frozen:
		_walk_speed = 0.0
		player.frozen = not world.is_presentation_ready()
		if not player.frozen: player.clear_spawn(world)
		update_camera(delta)
		return
	if cinematic:
		player.velocity = Vector3.ZERO
		player._cancel_weapon_actions()
		return
	var state := world.sample_gravity(player.global_position)
	var frame: Transform3D = state.frame
	var blend := 1.0-exp(-delta*14.0)
	player.global_basis = player.global_basis.slerp(frame.basis,blend).orthonormalized()
	player.up_direction = player.global_basis.y
	var up := player.up_direction
	player._update_magic(delta)
	if player.shield.active or player.stats.buffs.has_effect("quiet") or player.controls_locked() or player.interacting(): player._cancel_weapon_actions()
	if not player.controls_locked() and first_person<0.5:
		player.camera_yaw += Input.get_axis("orbit_right","orbit_left")*Player.ORBIT_SPEED*delta
	var input := Vector2.ZERO if player.controls_locked() else Input.get_vector("move_left","move_right","move_forward","move_back")
	if player.debug_input!=Vector2.ZERO: input = player.debug_input
	if player.stats.buffs.has_effect("static"): input = Vector2.ZERO
	var dir := (player.global_basis*Basis(Vector3.UP,player.camera_yaw)*Vector3(input.x,0,input.y)).slide(up).normalized()*input.length()
	var speed := Player.BASE_SPEED*player.stats.move_speed_multiplier()*(Player.SHIELD_MOVE_SPEED if player.shield.active else Player.CHARGE_MOVE_SPEED if player._charging else 1.0)
	var fall := minf(0.0,player.velocity.dot(up))-Player.GRAVITY*delta
	player.velocity = dir*speed+player._knock.slide(up)+up*(-2.0 if player.is_on_floor() else fall)
	player._knock = player._knock.lerp(Vector3.ZERO,1.0-exp(-Player.KNOCKBACK_DRAG*delta))
	var previous := player.global_position
	player.move_and_slide()
	if dir.length_squared()>0.01 and player.is_on_floor() and player.is_on_wall():
		# A tilted gravity normal can point into a stair riser. Lift along the
		# wall plane first, so small voxel steps remain climbable on a curve.
		var lift_axis := up.slide(player.get_wall_normal()).normalized()
		if lift_axis.length_squared()<0.1: lift_axis = up
		var lift := lift_axis*0.65
		if not player.test_move(player.global_transform,lift) and not player.test_move(player.global_transform.translated(lift),dir.normalized()*0.5):
			player.global_position += lift
	if not world.barrier_between(previous,player.global_position).is_empty():
		player.global_position = previous
		player.velocity = Vector3.ZERO
	var query := PhysicsRayQueryParameters3D.create(player.global_position+up*0.5,player.global_position-up*1.2,Player.TERRAIN_LAYER|Player.OBSTACLE_LAYER)
	query.exclude = [player.get_rid()]
	var ground := player.get_world_3d().direct_space_state.intersect_ray(query)
	if not ground.is_empty() and (ground.normal as Vector3).dot(up)>0.5:
		var on_ground: Vector3 = ground.position+up*0.035
		if on_ground.distance_to(player.global_position)<0.9:
			player.global_position = player.global_position.lerp(on_ground,1.0-exp(-delta*20.0))
			_checkpoint = player.global_position
	elif player.global_position.distance_to(frame.origin)>17.0 or player.global_position.y<-90.0:
		var recovery := world.recovery_point(player.global_position)
		player.global_position = _checkpoint if _checkpoint.distance_to(recovery)<2.0 else recovery
		player.velocity = Vector3.ZERO
	var step := (player.global_position-previous).dot(up)
	if absf(step)>0.22: player._visual_offset -= step
	player._visual_offset = lerpf(player._visual_offset,0.0,1.0-exp(-delta*12.0))
	player.model.position.y = player._visual_offset
	_walk_speed = (player.global_position-previous).slide(up).length()/maxf(delta,0.001) if player.is_on_floor() and dir.length_squared()>0.01 and not player.controls_locked() and not player.interacting() else 0.0
	update_camera(delta)
	player._update_combat(delta,dir,speed)
	player.aim_marker.hide()
	if not _seen_reveal and player.global_position.z<TheoryLayout.SHIP_B_END-7.0:
		_seen_reveal = true
		_reveal_madness()

func update_camera(delta: float) -> void:
	var want_fp := world.first_person_at(player.global_position)
	first_person = move_toward(first_person,1.0 if want_fp else 0.0,delta/1.15)
	var t := smoothstep(0.0,1.0,first_person)
	var up := player.global_basis.y
	var orbit := player.global_basis*Basis(Vector3.UP,player.camera_yaw)
	var target := player.global_position+up*1.0
	var head := player.global_position+up*1.57
	var pitch := Player.CAMERA_PITCH
	var from := target+orbit*Vector3(0,sin(pitch),cos(pitch))*player.camera_distance
	var camera_ray := PhysicsRayQueryParameters3D.create(head,from,Player.TERRAIN_LAYER|Player.OBSTACLE_LAYER)
	camera_ray.exclude = [player.get_rid()]
	var blocked := player.get_world_3d().direct_space_state.intersect_ray(camera_ray)
	if not blocked.is_empty():
		from = head+(from-head).normalized()*maxf(0.5,head.distance_to(blocked.position)-0.45)
	# Never point a camera at its own origin when a close bulkhead clips it.
	if from.distance_to(target)<0.1: from += orbit.z*0.2
	var look := (orbit*Basis(Vector3.RIGHT,look_pitch))*Vector3.FORWARD
	var position := from.lerp(head,t)
	var rotation := Transform3D(Basis.IDENTITY,from).looking_at(target,up).basis.slerp(Transform3D(Basis.IDENTITY,head).looking_at(head+look,up).basis,t)
	# A small, speed-limited footfall sway; it settles smoothly when stopped.
	var walk_weight := clampf(_walk_speed/Player.BASE_SPEED,0.0,1.0)
	_bob_weight = lerpf(_bob_weight,walk_weight,1.0-exp(-delta*9.0))
	if _walk_speed>0.05: _bob_phase = fmod(_bob_phase+delta*TAU*lerpf(1.05,1.8,clampf(_walk_speed/8.0,0.0,1.0)),TAU)
	var bob := _bob_weight*smoothstep(0.75,1.0,first_person)
	position += rotation*Vector3(sin(_bob_phase)*0.012,sin(_bob_phase*2.0)*0.018,0.0)*bob
	rotation = rotation*Basis(Vector3.FORWARD,sin(_bob_phase)*0.0012*bob)
	player.camera.global_transform = Transform3D(rotation,position)
	player.camera.fov = lerpf(Player.CAMERA_FOV,78.0,t)
	var alive := player.stats.hp>0.0
	player.model.visible = first_person<0.88 and alive
	player.status_visuals.visible = first_person<0.8 and alive
	player.aura.visible = first_person<0.8 and alive
	_flashlight.visible = first_person>0.75
	var allow_capture := first_person>0.8 and not player.controls_locked() and not player.ui_blocked and not player.interacting()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if allow_capture else Input.MOUSE_MODE_VISIBLE
	_dot.visible = allow_capture
	_dot.queue_redraw()
	_overlay.visible = not player.input_locked and not cinematic and alive
	_update_first_person_shield()
	var biome := world.biome_at(player.global_position)
	_camera_env.ambient_light_energy = lerpf(_camera_env.ambient_light_energy,biome.ambient_energy,1.0-exp(-delta*2.5))
	var in_wreck := biome==world._biomes[2]
	var in_bright_ship := biome==world._biomes[0]
	_camera_env.volumetric_fog_enabled = (in_wreck or in_bright_ship) and GraphicsSettings.volumetric_fog_allowed(AppSettings.graphics)
	_camera_env.volumetric_fog_density = 0.0025 if in_wreck else 0.0018
	_camera_env.volumetric_fog_length = 28 if in_wreck else 48
	_camera_env.volumetric_fog_albedo = Color("8895ae") if in_wreck else Color("c3dfed")
	_title.text = ""  # no place titles on screen
	_objective.text = ("Forward airlock open" if world.ship_airlock_open else "Inspect electrical boxes to find the airlock relay. %d/5 checked." % world.inspected_boxes.size()) if want_fp else "Follow the magnetic ribbon. Gravity follows the surface."
	if world.zone_at(player.global_position)=="ship" and not world.ship_airlock_open:
		var nearest := -1
		var distance := INF
		for index in 5:
			if index in world.inspected_boxes: continue
			var d := player.global_position.distance_to(TheoryLayout.ELECTRICAL_POSITIONS[index])
			if d<distance:
				distance = d
				nearest = index
		if nearest>=0:
			_objective.text += "\n%s - %s wall on the main deck, %d m away." % [TheoryLayout.ELECTRICAL_NAMES[nearest],"left" if TheoryLayout.ELECTRICAL_POSITIONS[nearest].x<0 else "right",roundi(distance)]
	if world.zone_at(player.global_position)=="wreck": _objective.text = "Escape airlock open" if world.repaired_boxes.size()==5 else "Repair the five sparking electrical boxes. %d/5 repaired. Follow the marked service bays beside the main passage." % world.repaired_boxes.size()


func mouse_point() -> Vector3:
	var mouse := player.get_viewport().get_visible_rect().size*0.5 if first_person>0.8 else player.get_viewport().get_mouse_position()
	var origin := player.camera.project_ray_origin(mouse)
	var direction := player.camera.project_ray_normal(mouse)
	var query := PhysicsRayQueryParameters3D.create(origin,origin+direction*300,Player.TERRAIN_LAYER|Player.OBSTACLE_LAYER|Player.ENEMY_LAYER)
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): return hit.position
	if first_person>0.8: return origin+direction*120
	var plane := Plane(player.up_direction,player.global_position+player.up_direction)
	var crossing: Variant = plane.intersects_ray(origin,direction)
	return crossing if crossing is Vector3 else player.global_position-player.global_basis.z*20

func aim_ray() -> Array:
	var target := player._aim_point
	var origin := player.global_position+player.up_direction
	if first_person>0.8:
		# Shoot from a shoulder-height side muzzle, converging on the exact
		# crosshair target. Retract near a wall rather than firing through it.
		var eye := player.camera.global_position
		var basis := player.camera.global_basis
		var distance := eye.distance_to(target)
		var clearance := clampf(distance/0.9,0.0,1.0)
		origin = eye+basis*Vector3(0.36*clearance,-0.20*clearance,-minf(0.48,distance*0.4))
		var query := PhysicsRayQueryParameters3D.create(eye,origin,Player.TERRAIN_LAYER|Player.OBSTACLE_LAYER)
		query.exclude = [player.get_rid()]
		var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty(): origin = eye.lerp(hit.position,0.85)
	var direction := (target-origin).normalized()
	if direction.is_zero_approx(): direction = -player.camera.global_basis.z
	return [origin,direction]

func start_gate_cinematic(scene: Dictionary) -> void:
	if int(scene.serial)<=_last_door_serial or cinematic or player.stats.hp<=0.0: return
	_last_door_serial = int(scene.serial)
	_door_scene = scene.duplicate(true)
	_door_presenting = false
	_door_saved = {camera=player.camera.global_transform,fov=player.camera.fov,mouse=Input.mouse_mode,hud_visible=false,hud_input=false}
	_door_hud = world.get_parent().get("hud") as CanvasLayer
	if _door_hud!=null:
		_door_saved.hud_visible = _door_hud.visible
		_door_saved.hud_input = _door_hud.is_processing_input()
		if _door_hud is Hud: (_door_hud as Hud).interaction.close()
	cinematic = true
	player.cinematic_locked = true
	player.velocity = Vector3.ZERO
	player._knock = Vector3.ZERO
	player._cancel_weapon_actions()
	player.shield.active = false
	GameServer.set_shield(player.player_id,false)
	player.begin_interaction(get_instance_id())

func _update_gate_cinematic() -> void:
	var age := world.clock_time()-float(_door_scene.start)
	if age<0.0: return
	if world.clock_time()>=float(_door_scene.end):
		_finish_gate_cinematic()
		return
	if not _door_presenting:
		_door_presenting = true
		if _door_hud!=null:
			_door_hud.hide()
			_door_hud.set_process_input(false)
		_overlay.show()
		_bars.show()
		_title.hide()
		_objective.hide()
		_dot.hide()
		_flashlight.hide()
		_fp_shield.hide()
		player.aura.hide()
		player.status_visuals.hide()
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		var biome := world.biome_at(world.surfaces[str(_door_scene.key)].global_position)
		_camera_env.ambient_light_energy = biome.ambient_energy
	var gate: Transform3D = world.surfaces[str(_door_scene.key)].global_transform
	var t := smoothstep(0.0,3.8,age)
	var eye := gate*Vector3(lerpf(4.2,1.8,t),lerpf(3.2,2.8,t),lerpf(6.3,4.8,t))
	var camera := Transform3D(Basis.IDENTITY,eye).looking_at(gate*Vector3(0,2.4,0),gate.basis.y)
	var returning := smoothstep(3.9,4.6,age)
	player.camera.global_transform = camera.interpolate_with(_door_saved.camera,returning)
	player.camera.fov = lerpf(61.0,float(_door_saved.fov),returning)

func _finish_gate_cinematic() -> void:
	if _door_scene.is_empty(): return
	player.camera.global_transform = _door_saved.camera
	player.camera.fov = float(_door_saved.fov)
	if is_instance_valid(_door_hud):
		_door_hud.visible = bool(_door_saved.hud_visible)
		_door_hud.set_process_input(bool(_door_saved.hud_input))
	_bars.hide()
	_title.show()
	_objective.show()
	Input.mouse_mode = int(_door_saved.mouse)
	player.end_interaction(get_instance_id())
	player.cinematic_locked = false
	cinematic = false
	_door_scene.clear()
	_door_saved.clear()
	_door_hud = null

func _reveal_madness() -> void:
	_fp_shield.hide()
	cinematic = true
	player.cinematic_locked = true
	player.begin_interaction(get_instance_id())
	_bars.show()
	_camera_env.ambient_light_energy = world._biomes[3].ambient_energy
	_camera_env.volumetric_fog_enabled = false
	player._cancel_weapon_actions()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_overlay.show()
	_title.hide()
	_objective.hide()
	_dot.hide()
	var main := world.get_parent()
	var hud: CanvasLayer = main.get("hud") as CanvasLayer
	var visible_hud := hud.visible if hud!=null else false
	if hud!=null: hud.hide()
	var before := player.camera.global_transform
	var fov := player.camera.fov
	var start := TheoryLayout.SHIP_B_END
	var camera_start := Vector3(10,12,start-15)
	var camera_end := Vector3(-38,35,start-60)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(func(t: float) -> void:
		var eye := camera_start.lerp(camera_end,t)
		player.camera.global_transform = Transform3D(Basis.IDENTITY,eye).looking_at(Vector3(0,10,-860),Vector3.UP)
		player.camera.fov = lerpf(52.0,68.0,t)
		for surface: TheorySurface in world.surfaces.values():
			if surface.material!=null and surface.plan.get("unstable",false): surface.material.set_shader_parameter("reveal",t)
	,0.0,1.0,6.5)
	tween.tween_interval(1.0)
	tween.tween_method(func(t: float) -> void:
		var from := Transform3D(Basis.IDENTITY,camera_end).looking_at(Vector3(0,10,-860),Vector3.UP)
		player.camera.global_transform = from.interpolate_with(before,t)
		player.camera.fov = lerpf(68.0,fov,t)
	,0.0,1.0,1.2)
	await tween.finished
	if hud!=null: hud.visible = visible_hud
	_bars.hide()
	_title.show()
	_objective.show()
	player.end_interaction(get_instance_id())
	cinematic = false
	player.cinematic_locked = false

func _exit_tree() -> void:
	if not _door_scene.is_empty(): _finish_gate_cinematic()
	Input.mouse_mode = _old_mouse
	if not is_instance_valid(player): return
	player.cinematic_locked = false
	player.end_interaction(get_instance_id())
	player.global_basis = Basis.IDENTITY
	player.up_direction = Vector3.UP
	player.floor_snap_length = Player.STEP_HEIGHT
	player.floor_constant_speed = false
	player.floor_max_angle = deg_to_rad(45.0)
	player.model.visible = true
	player.status_visuals.visible = true
	player.aura.visible = true
	player.camera.environment = _prior_env
	player.camera.far = _old_far
	player.camera.fov = Player.CAMERA_FOV
	if is_instance_valid(_flashlight): _flashlight.queue_free()
	if is_instance_valid(_fp_shield): _fp_shield.queue_free()
