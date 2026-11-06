class_name SpaceTraversal
extends SpatialController
## The local player in the Astral Reach. On foot: the Nexus deck and planets
## use the usual angled camera (gravity follows the planet), ship rooms are
## first person. Seated: the pilot flies the hull (chase camera, or cockpit
## when zoomed all the way in), gunners aim a turret, the map seat shows the
## space map. Z stands up, X lands or docks, M opens the space map.
const INPUT_RATE := 0.05
const AIM_RATE := 0.1
const MOUSE_SENSITIVITY := 0.0022
var world: SpaceWorld
var seat := ""
var _ship: SpaceShip
var _checkpoint := Vector3.ZERO
var _old_far := 4000.0
var _old_mouse := Input.MOUSE_MODE_VISIBLE
var _prior_env: Environment
var _hud: ResponsiveUILayer
var _overlay: Control
var _title: Label
var _hint: Label
var _notice: Label
var _notice_time := 0.0
var _crosshair: Control
var _ship_panel: Control
var _ship_info: Label
var _fade: ColorRect
var map: SpaceMap
var _input_timer := 0.0
var _aim_timer := 0.0
var _fire_timer := 0.0
var _mouse := Vector2.ZERO  # pilot: accumulated stick from the mouse
var _turret_yaw := 0.0
var _turret_pitch := 0.15
var _chase := Transform3D.IDENTITY
var _cockpit := false
var _rocket_flight := false

func setup(actor: Player, place: SpaceWorld) -> SpaceTraversal:
	player = actor
	world = place
	_checkpoint = actor.global_position
	_old_far = actor.camera.far
	_old_mouse = Input.mouse_mode
	return self

func _ready() -> void:
	player.camera.far = 30000.0
	_prior_env = player.camera.environment
	player.floor_snap_length = 0.9
	player.floor_max_angle = deg_to_rad(60.0)
	player.floor_constant_speed = true
	_hud = ResponsiveUILayer.new()
	_hud.layer = 32
	add_child(_hud)
	_overlay = _hud.make_ui_root()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title = UIStyle.label("", 26, UIStyle.GOLD)
	_title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_title.offset_top = 18
	_title.offset_left = -300
	_title.offset_right = 300
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay.add_child(_title)
	_hint = UIStyle.label("", 17, UIStyle.TEXT)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.offset_top = -150
	_hint.offset_bottom = -110
	_hint.offset_left = -420
	_hint.offset_right = 420
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay.add_child(_hint)
	_notice = UIStyle.label("", 20, UIStyle.GOLD)
	_notice.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_notice.offset_top = -170
	_notice.offset_bottom = -120
	_notice.offset_left = -460
	_notice.offset_right = 460
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overlay.add_child(_notice)
	_crosshair = SpaceCrosshair.new()
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(_crosshair)
	_ship_panel = VBoxContainer.new()
	_ship_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_ship_panel.position = Vector2(24, 120)
	_ship_panel.custom_minimum_size = Vector2(300, 0)
	_overlay.add_child(_ship_panel)
	_ship_info = UIStyle.label("", 16, UIStyle.TEXT)
	_ship_panel.add_child(_ship_info)
	_ship_panel.hide()
	map = SpaceMap.new()
	map.world = world
	map.player = player
	map.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	map.hide()
	_overlay.add_child(map)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(_fade)
	if world.record.get("intro", false): play_intro.call_deferred()

# --- Per frame -------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not is_instance_valid(world): return
	# The backdrop is built in a later load step than this controller.
	if is_instance_valid(world.backdrop) and player.camera.environment==_prior_env:
		player.camera.environment = world.backdrop.environment()
	_ship = world.ship_of(player.player_id)
	seat = _ship.seat_of(player.player_id) if _ship else ""
	_notice_time -= delta
	_notice.modulate.a = clampf(_notice_time, 0.0, 1.0)
	var zone := world.zone_at(player.global_position)
	_title.text = "" if zone=="ship" else world.region_at(player.global_position)
	_ship_panel.visible = _ship!=null
	if _ship:
		var place := SpaceLayout.region_name(SpaceLayout.region_at(_ship.xform.origin))
		_ship_info.text = "%s  -  %s\nHull %d / %d%s\n%s  -  %d m/s" % [_ship.name, _seat_title(seat), _ship.hp, SpaceShip.MAX_HP,
			"  -  CRIPPLED" if _ship.broken else "", place if _ship.mode=="flying" else _ship.mode.capitalize(), roundi(_ship.speed)]
		_ship_info.add_theme_color_override("font_color", UIStyle.HP_LIGHT if _ship.hp<SpaceShip.MAX_HP/3 or _ship.broken else UIStyle.TEXT)
	_update_hint()
	if seat!="":
		_seated(delta)

func _seat_title(id: String) -> String:
	return SpaceInteraction.SEAT_TITLES.get(id, "Aboard")

func _update_hint() -> void:
	var lines: Array[String] = []
	match seat:
		"pilot":
			lines.append("W/S thrust - A/D turn - mouse pitch and turn - Q/E roll - Shift boost - wheel: cockpit view")
			if _ship.mode in ["berth", "landed"]: lines.append("Press W to take off")
			var land := _ship.landable()
			if not land.is_empty(): lines.append("X: land on %s" % land.name)
			elif _ship.mode=="flying" and _ship.xform.origin.distance_to(SpaceLayout.NEXUS)<900.0: lines.append("X: dock at the Nexus")
		"turret_top", "turret_left", "turret_right":
			lines.append("Mouse aims - left mouse fires")
		"map":
			lines.append("The star map is open")
	if seat!="": lines.append("Z: stand up")
	elif world.zone_at(player.global_position)=="ship": lines.append("X at a seat to sit - the hatch is at the stern")
	_hint.text = "\n".join(lines)

func notice(text: String) -> void:
	_notice.text = text
	_notice_time = 5.0

func on_world_message(event: Array) -> void:
	match str(event[0]):
		"say": notice(str(event[1]))
		"moved":
			_flash_fade()
			match str(event[1]):
				"home": notice("Back at the Nexus.")
				"board": notice("Aboard. Sit at the helm to fly, or at a cannon to fight.")
				"planet": notice(world.region_at(player.global_position))

func _flash_fade() -> void:
	_fade.color.a = 1.0
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.6)

func hide_overlay() -> void:
	if is_instance_valid(_overlay): _overlay.hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func toggle_map() -> void:
	map.visible = not map.visible

# --- Input ------------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if cinematic or player.controls_locked(): return
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		var motion: Vector2 = event.relative*MOUSE_SENSITIVITY
		match seat:
			"pilot": _mouse = (_mouse+motion*Vector2(1.6, 1.6)).limit_length(1.0)
			"turret_top", "turret_left", "turret_right":
				_turret_yaw -= motion.x
				_turret_pitch = clampf(_turret_pitch-motion.y, -0.35, 1.25)
			_:
				player.camera_yaw -= motion.x
				look_pitch = clampf(look_pitch-motion.y, -1.35, 1.35)
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey or event is InputEventMouseButton) or not event.is_pressed(): return
	if event is InputEventKey and (event as InputEventKey).echo: return
	if event is InputEventKey and (event as InputEventKey).physical_keycode==KEY_Z:
		if seat!="": world.request(["stand"])
		get_viewport().set_input_as_handled()
		return
	if seat=="pilot":
		if event.is_action_pressed("interact"):
			world.request(["land"] if not _ship.landable().is_empty() else ["dock"])
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_cockpit = (event as InputEventMouseButton).button_index==MOUSE_BUTTON_WHEEL_UP
			get_viewport().set_input_as_handled()

func _was_seated() -> bool:
	return seat!=""

# --- Seated --------------------------------------------------------------------------

func _seated(delta: float) -> void:
	var spec := world.seat_spec(_ship.slot, seat)
	if not spec.is_empty():
		player.global_position = spec.pos
		player.velocity = Vector3.ZERO
		player.model.rotation.y = float(spec.get("yaw", 0.0))
	player._cancel_weapon_actions()
	match seat:
		"pilot":
			_input_timer -= delta
			if _input_timer<=0.0:
				_input_timer = INPUT_RATE
				var thrust := Input.get_axis("move_back", "move_forward")
				var yaw := Input.get_axis("move_left", "move_right")+_mouse.x
				var roll := Input.get_axis("orbit_left", "orbit_right")
				world.request(["pilot", [thrust, clampf(yaw, -1.0, 1.0), clampf(-_mouse.y, -1.0, 1.0), roll, Input.is_key_pressed(KEY_SHIFT)]])
			_mouse = _mouse.lerp(Vector2.ZERO, 1.0-exp(-delta*2.2))
		"turret_top", "turret_left", "turret_right":
			var dir := _turret_direction()
			_aim_timer -= delta
			if _aim_timer<=0.0:
				_aim_timer = AIM_RATE
				world.request(["aim", dir])
			_fire_timer -= delta
			if Input.is_action_pressed("shoot") and _fire_timer<=0.0 and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
				_fire_timer = 0.2
				world.request(["fire", dir])
				GameAudio.play("enemy_shot", player.camera.global_position)
		"map":
			map.visible = true

func _turret_direction() -> Vector3:
	var view: SpaceShipView = world.ship_views.get(_ship.id)
	var basis := view.global_basis if view else _ship.xform.basis
	var base := {turret_top = 0.0, turret_left = PI*0.5, turret_right = -PI*0.5}.get(seat, 0.0) as float
	return (basis*Basis(Vector3.UP, base+_turret_yaw)*Basis(Vector3.RIGHT, _turret_pitch)*Vector3.FORWARD).normalized()

# --- Walking ---------------------------------------------------------------------------

func physics_step(delta: float) -> void:
	if not is_instance_valid(world): return
	if player.frozen:
		player.frozen = not world.is_presentation_ready()
		update_camera(delta)
		return
	if cinematic or seat!="":
		player.velocity = Vector3.ZERO
		update_camera(delta)
		return
	var state := world.sample_gravity(player.global_position)
	var frame: Transform3D = state.frame
	var blend := 1.0-exp(-delta*10.0)
	player.global_basis = player.global_basis.slerp(frame.basis, blend).orthonormalized()
	player.up_direction = player.global_basis.y
	var up := player.up_direction
	player._update_magic(delta)
	if player.shield.active or player.stats.buffs.has_effect("quiet") or player.controls_locked() or player.interacting(): player._cancel_weapon_actions()
	if not player.controls_locked() and first_person<0.5:
		player.camera_yaw += Input.get_axis("orbit_right", "orbit_left")*Player.ORBIT_SPEED*delta
	var input := Vector2.ZERO if player.controls_locked() else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if player.debug_input!=Vector2.ZERO: input = player.debug_input
	if player.stats.buffs.has_effect("static"): input = Vector2.ZERO
	var dir := (player.global_basis*Basis(Vector3.UP, player.camera_yaw)*Vector3(input.x, 0, input.y)).slide(up).normalized()*input.length()
	var speed := Player.BASE_SPEED*player.stats.move_speed_multiplier()*(Player.SHIELD_MOVE_SPEED if player.shield.active else Player.CHARGE_MOVE_SPEED if player._charging else 1.0)
	var fall := minf(0.0, player.velocity.dot(up))-Player.GRAVITY*delta
	player.velocity = dir*speed+player._knock.slide(up)+up*(-2.0 if player.is_on_floor() else fall)
	player._knock = player._knock.lerp(Vector3.ZERO, 1.0-exp(-Player.KNOCKBACK_DRAG*delta))
	player.move_and_slide()
	var query := PhysicsRayQueryParameters3D.create(player.global_position+up*0.5, player.global_position-up*1.2, Player.TERRAIN_LAYER|Player.OBSTACLE_LAYER)
	query.exclude = [player.get_rid()]
	var ground := player.get_world_3d().direct_space_state.intersect_ray(query)
	if not ground.is_empty() and (ground.normal as Vector3).dot(up)>0.5:
		_checkpoint = player.global_position
	elif state.zone=="void" or float(state.distance)>30.0:
		player.global_position = world.recovery_point(_checkpoint) if world.zone_at(_checkpoint)!="void" else world.spawn_point
		player.velocity = Vector3.ZERO
	update_camera(delta)
	player._update_combat(delta, dir, speed)
	player.aim_marker.hide()

func update_camera(delta: float) -> void:
	var want_fp := seat=="" and world.first_person_at(player.global_position)
	first_person = move_toward(first_person, 1.0 if want_fp else 0.0, delta/0.8)
	var allow_capture := (first_person>0.8 or seat in ["pilot", "turret_top", "turret_left", "turret_right"]) and not player.controls_locked() \
		and not player.ui_blocked and not player.interacting() and not map.visible and not cinematic
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if allow_capture else Input.MOUSE_MODE_VISIBLE
	(_crosshair as SpaceCrosshair).mode = "" if not allow_capture else "fp" if seat=="" else "pilot" if seat=="pilot" else "turret"
	_crosshair.queue_redraw()
	_overlay.visible = not player.input_locked and not cinematic
	var alive := player.stats.hp>0.0
	player.model.visible = first_person<0.88 and alive
	player.status_visuals.visible = first_person<0.8 and alive
	player.aura.visible = first_person<0.8 and alive
	if cinematic: return
	if seat!="" and _ship!=null and world.ship_views.has(_ship.id):
		_seat_camera(delta)
		return
	var t := smoothstep(0.0, 1.0, first_person)
	var up := player.global_basis.y
	var orbit := player.global_basis*Basis(Vector3.UP, player.camera_yaw)
	var target := player.global_position+up*1.0
	var head := player.global_position+up*1.57
	var pitch := Player.OVERHEAD_PITCH if AppSettings.video.get("camera_angle", "standard")=="overhead" else Player.CAMERA_PITCH
	var from := target+orbit*Vector3(0, sin(pitch), cos(pitch))*player.camera_distance
	# Like the rest of the game, the angled camera never pulls in for roofs or
	# trees; only the walls of a ship room hold it back.
	if first_person>0.01:
		var ray := PhysicsRayQueryParameters3D.create(head, from, Player.TERRAIN_LAYER|Player.OBSTACLE_LAYER)
		ray.exclude = [player.get_rid()]
		var blocked := player.get_world_3d().direct_space_state.intersect_ray(ray)
		if not blocked.is_empty(): from = head+(from-head).normalized()*maxf(0.5, head.distance_to(blocked.position)-0.45)
	if from.distance_to(target)<0.1: from += orbit.z*0.2
	var look := (orbit*Basis(Vector3.RIGHT, look_pitch))*Vector3.FORWARD
	var rotation := Transform3D(Basis.IDENTITY, from).looking_at(target, up).basis.slerp(Transform3D(Basis.IDENTITY, head).looking_at(head+look, up).basis, t)
	player.camera.global_transform = Transform3D(rotation, from.lerp(head, t))
	player.camera.fov = lerpf(Player.CAMERA_FOV, 78.0, t)

func _seat_camera(delta: float) -> void:
	var view: SpaceShipView = world.ship_views[_ship.id]
	var pose := view.global_transform
	var anchors: Dictionary = view.hull.anchors
	var want: Transform3D
	match seat:
		"pilot":
			if _cockpit:
				want = pose*(anchors.get("cockpit", Transform3D(Basis.IDENTITY, Vector3(0, 3, -10))) as Transform3D)
			else:
				var offset: Vector3 = anchors.get("chase", Vector3(0, 9, 34))
				var at := pose*offset
				want = Transform3D(Basis.IDENTITY, at).looking_at(pose.origin-pose.basis.z*40.0, pose.basis.y)
			player.camera.fov = 72.0 if not _cockpit else 80.0
		"turret_top", "turret_left", "turret_right":
			var dir := _turret_direction()
			var eye := view.muzzle(seat)-dir*4.0+pose.basis.y*1.6
			want = Transform3D(Basis.IDENTITY, eye).looking_at(eye+dir, pose.basis.y)
			player.camera.fov = 70.0
		_:
			var at := pose.origin+pose.basis.y*60.0+pose.basis.z*80.0
			want = Transform3D(Basis.IDENTITY, at).looking_at(pose.origin, pose.basis.y)
			player.camera.fov = 60.0
	# A short lag keeps the chase view alive; turrets stay crisp.
	var k := 1.0-exp(-delta*(9.0 if seat=="pilot" and not _cockpit else 30.0))
	_chase = want if _chase==Transform3D.IDENTITY else _chase.interpolate_with(want, k)
	player.camera.global_transform = _chase

# --- Aiming on foot ---------------------------------------------------------------------

func mouse_point() -> Vector3:
	var mouse := player.get_viewport().get_visible_rect().size*0.5 if first_person>0.8 else player.get_viewport().get_mouse_position()
	var origin := player.camera.project_ray_origin(mouse)
	var direction := player.camera.project_ray_normal(mouse)
	var query := PhysicsRayQueryParameters3D.create(origin, origin+direction*300, Player.TERRAIN_LAYER|Player.OBSTACLE_LAYER|Player.ENEMY_LAYER)
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): return hit.position
	var plane := Plane(player.up_direction, player.global_position+player.up_direction)
	var crossing: Variant = plane.intersects_ray(origin, direction)
	return crossing if crossing is Vector3 else player.global_position-player.global_basis.z*20

func aim_ray() -> Array:
	var target := player._aim_point
	var origin := player.global_position+player.up_direction
	if first_person>0.8:
		var eye := player.camera.global_position
		origin = eye+player.camera.global_basis*Vector3(0.36, -0.2, -0.45)
	var direction := (target-origin).normalized()
	if direction.is_zero_approx(): direction = -player.camera.global_basis.z
	return [origin, direction]

# --- Cinematics -------------------------------------------------------------------------

## Orin's rocket home: the camera watches the launch, then the usual travel.
func fly_rocket_home() -> void:
	if cinematic or _rocket_flight: return
	_rocket_flight = true
	var rocket := world.rocket_node()
	var game := world.get_parent()
	if rocket==null or game==null or not game.has_method("travel"):
		if game and game.has_method("travel"): game.travel("hall")
		return
	cinematic = true
	player.cinematic_locked = true
	player.model.visible = false
	_hide_hud(true)
	var start := rocket.global_transform
	var shots := SpaceCinematic.new()
	add_child(shots)
	await shots.rocket_launch(player.camera, rocket, "To the Tavern")
	rocket.global_transform = start
	rocket.set_flame(0.0)
	cinematic = false
	player.cinematic_locked = false
	_rocket_flight = false
	game.travel("hall")

## First arrival: a short tour of the Nexus.
func play_intro() -> void:
	while player.frozen or not world.is_presentation_ready() or not is_instance_valid(world.station):
		await get_tree().process_frame
	if cinematic: return
	cinematic = true
	player.cinematic_locked = true
	_hide_hud(true)
	var shots := SpaceCinematic.new()
	add_child(shots)
	await shots.nexus_intro(player.camera, world)
	shots.queue_free()
	_hide_hud(false)
	cinematic = false
	player.cinematic_locked = false

func _hide_hud(hidden: bool) -> void:
	var game := world.get_parent()
	var hud: Variant = game.get("hud") if game else null
	if hud is CanvasLayer: (hud as CanvasLayer).visible = not hidden
	_overlay.visible = not hidden

func _exit_tree() -> void:
	Input.mouse_mode = _old_mouse
	if not is_instance_valid(player): return
	player.cinematic_locked = false
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
