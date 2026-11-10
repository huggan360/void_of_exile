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
enum CameraMode { ANGLED, SHOULDER, FIRST_PERSON }
var camera_mode := CameraMode.ANGLED
var city_seat := ""
var _lounge_seat := ""
var _lift := -1
var _ship_slot := -1
var _outside_culled := false  # the outside hidden while we're in a ship room  # the room of the ship we sat in, to stand up beside the chair
var _lift_height := 0.0
var seat := ""
var _ship: SpaceShip
var _checkpoint := Vector3.ZERO
var _old_far := 4000.0
var _old_cull_mask := (1<<20)-1
var _old_safe_margin := 0.001
var _old_mouse := Input.MOUSE_MODE_VISIBLE
var _prior_env: Environment
var _hud: ResponsiveUILayer
var _overlay: Control
var _title: Label
var _hint: Label
var _notice: Label
var _notice_time := 0.0
var _crosshair: Control
var _fade: ColorRect
var map: SpaceMap
var _input_timer := 0.0
var _aim_timer := 0.0
var _lock_timer := 0.0
var _locked_targets: Array[Dictionary] = []
var _fire_timer := 0.0
var _pilot_look := Vector2.ZERO
var _seat_interior := false
var _turret_yaw := 0.0
var _turret_pitch := 0.15
const SIDE_TURRET_SWEEP := 1.3
var _chase := Transform3D.IDENTITY
var _cockpit := true
var _rocket_flight := false
## Pilot throttle (-1..1): Speed up and Speed down move it, and it holds
## when you let go.
var throttle := 0.0
## Kerbs and pad rims are stepped onto; tables and crates (higher) are not.
const STEP_UP := 0.55
const LAUNCH_THROTTLE := SpaceShip.LAUNCH_THRUST
var _launching := false
const THROTTLE_STEP := 0.1
const THROTTLE_REPEAT := 0.18  # seconds between steps while a key is held
var _throttle_hold := 0.0
## Outside the ship on the jetpack: walking her deck or flying beside her.
var spacewalk := false
var jetpack_attached := false
var _jetpack_block_notice := 0
## Open space is only for those who went out on purpose (up the ladder, a
## lost ship); anyone else who drops off the deck or a planet is put back.
var _out_on_purpose := false
var _last_zone := ""
var fuel := 100.0
var _fuel_rest := 0.0
var _jet := Vector3.ZERO
## Outside a ship: {ship (id), at (hull space, you), flying, vel (hull space)}.
## Flying, a line runs from her deck hatch to your belt: it pays out by itself
## up to ROPE_MAX and winds in only while you hold Ctrl.
var outside := {}
var deck := false
## Jetpacking down into a planet's air after unhooking: until you touch the
## ground, then walk with the jetpack still equipped.
var _descent := false
var _planet_fall := false
var _deck_arrival := false
var _rehook_after := 0
## Red port badges over the planets' ports (key -> holder node).
var _port_marks := {}
var _nexus_mark: Node3D
var _landing_prompt: LandingPrompt
const NEXUS_MARK_HEIGHT := 90.0
var _queue_text := ""
var _rope: MeshInstance3D
var _rope_mesh := ImmediateMesh.new()
const ROPE_MAX := 45.0
const REEL_SPEED := 9.0  # m/s the winch pulls you in
const JET_ACCEL := 24.0
const JET_MAX := 18.0
const JET_TURN := 2.2  # rad/s, A and D
const FUEL_DRAIN := 5.0
const FUEL_REGEN := 45.0
const SHIP_HULL := Color("4fd6a8")
const SHIP_HULL_LIGHT := Color("b8ffe6")
const SHIP_BOOST := Color("f0a43a")
const SHIP_BOOST_LIGHT := Color("ffd890")
const JETPACK := Color("4aa8ff")
const JETPACK_LIGHT := Color("b0e0ff")

func setup(actor: Player, place: SpaceWorld) -> SpaceTraversal:
	player = actor
	world = place
	_checkpoint = actor.global_position
	_old_far = actor.camera.far
	_old_cull_mask = actor.camera.cull_mask
	_old_safe_margin = actor.safe_margin
	_old_mouse = Input.mouse_mode
	camera_mode = CameraMode.FIRST_PERSON if place is SurfaceShipWorld else int(AppSettings.video.get("space_camera", CameraMode.ANGLED))
	return self

func _ready() -> void:
	player.camera.far = 90000.0
	_prior_env = player.camera.environment
	# Pocket decks are 14 km below the origin. The default 1 mm margin
	# is too close to floating-point precision there: repeated floor contacts
	# can consume every slide iteration before the player moves.
	player.safe_margin = 0.01
	player.floor_snap_length = 0.9
	player.floor_max_angle = deg_to_rad(60.0)
	player.floor_constant_speed = true
	_hud = ResponsiveUILayer.new()
	_hud.layer = 32
	add_child(_hud)
	_overlay = _hud.make_ui_root()
	_build_first_person_shield()
	var prompt := LandingPrompt.new()
	prompt.traversal = self
	world.add_child.call_deferred(prompt)
	_landing_prompt = prompt
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
	_rope = MeshInstance3D.new()
	_rope.mesh = _rope_mesh
	var cord := StandardMaterial3D.new()
	cord.albedo_color = Color("c8a46a")
	cord.roughness = 0.9
	cord.emission_enabled = true
	cord.emission = Color("85efac")
	cord.emission_energy_multiplier = 0.25
	cord.cull_mode = BaseMaterial3D.CULL_DISABLED
	_rope.material_override = cord
	_rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rope.top_level = true
	_rope.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rope)
	var windows := ShipWindowView.new()
	windows.world = world
	windows.player = player
	add_child(windows)
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
	_update_air()
	_ship = world.ship_of(player.player_id)
	var lounge := Leisure.seat_spec(player.player_id)
	var lounge_id := str(lounge.get("key", lounge.get("id", "")))
	if lounge_id!=_lounge_seat:
		_lounge_seat = lounge_id
		if not lounge.is_empty():
			_seat_interior = true
			player.camera_yaw = float(lounge.get("yaw", 0.0))
			look_pitch = -0.12
	var old_city_seat := city_seat
	city_seat = world.city.seat_of(player.player_id)
	if city_seat!=old_city_seat and city_seat!="":
		player.camera_yaw = float(CityLayout.any_seat(city_seat).yaw)
		look_pitch = -0.25
	var was := seat
	var was_ship := _ship_slot
	seat = _ship.seat_of(player.player_id) if _ship else ""
	_ship_slot = _ship.slot if _ship else -1
	if was!="" and seat=="" and was_ship>=0:
		# Stood up: step off the chair right away (the server sends us there too).
		var spot: Vector3 = world.seat_spec(was_ship, was).get("stand", Vector3.INF)
		if spot.is_finite() and player.global_position.distance_to(spot)<4.0:
			player.global_position = spot+Vector3.UP*0.05
			player.velocity = Vector3.ZERO
	if seat!=was:
		# Taking the wheel: carry on at the speed she holds.
		throttle = _ship.cruise() if seat=="pilot" and _ship else 0.0
		_launching = false
		_pilot_look = Vector2.ZERO
		_turret_yaw = 0.0
		_locked_targets.clear()
		_lock_timer = 0.0
		_seat_interior = seat.begins_with("chair")
		if seat=="map": map.visible = true
	if seat!=was and seat.begins_with("chair"):
		# Sitting down: look across the table, a little down at the glasses.
		player.camera_yaw = float(world.seat_spec(_ship.slot, seat).get("yaw", 0.0))
		look_pitch = -0.3
	_notice_time -= delta
	_notice.modulate.a = clampf(_notice_time, 0.0, 1.0)
	var zone := world.zone_at(player.global_position)
	_title.text = ""  # no place titles on screen
	if _ship and _ship.turned_back: _notice_edge()
	_update_bars(zone)
	_update_ports()
	_update_hint()
	_pin_to_hull()
	if seat!="":
		_seated(delta)
	update_camera(delta)
	_cull_outside()
	if _ship!=null and _ship.mode=="flying":
		if seat=="pilot": _update_target_locks(_pilot_direction())
		elif seat.begins_with("turret"): _update_target_locks(_turret_direction())

## Aboard, the bars are the ship's hull and boost; on a spacewalk, your
## health and the jetpack.
func _update_bars(zone: String) -> void:
	var game := world.game_root()
	var hud: Variant = game.get("hud") if game else null
	if hud==null: return
	var aboard: SpaceShip = _ship if _ship else world.ship_in_slot(SpaceLayout.pocket_at(player.global_position)) if zone=="ship" else null
	var helm := seat=="pilot" and _ship!=null and _ship.mode=="flying"
	hud.throttle.visible = helm
	if helm: hud.throttle.set_value(throttle)
	if aboard:
		hud.bar_override = {hp = [aboard.hp, SpaceShip.MAX_HP, "", SHIP_HULL, SHIP_HULL_LIGHT, "ship"],
			mp = [aboard.boost, 100.0, "", SHIP_BOOST, SHIP_BOOST_LIGHT, "flame"], parts = aboard.parts}
	elif jetpack_attached and (_descent or (spacewalk and not deck)):
		hud.bar_override = {hp = [player.stats.hp, player.stats.max_hp, "", UIStyle.HP, UIStyle.HP_LIGHT, "heart"],
			mp = [fuel, 100.0, "", JETPACK, JETPACK_LIGHT, "flame"]}
	else:
		hud.bar_override = {}

## The camera inside a planet's air takes on its sky, fog and light.
func _update_air() -> void:
	if not is_instance_valid(world.backdrop): return
	var eye := player.camera.global_position
	var air := {}
	var amount := 0.0
	var up := Vector3.UP
	# Diving through the air: space gives way to the planet's sky as you go down.
	for p: Dictionary in SpaceLayout.PLANETS:
		var thick := SpaceLayout.air_height(p)
		var altitude := eye.distance_to(p.center)-float(p.radius)
		if altitude<thick:
			air = p
			amount = 1.0-smoothstep(thick*0.4, thick, altitude)
			up = (eye-(p.center as Vector3)).normalized()
	world.backdrop.set_air(air, amount, up)
	if SpaceLayout.pocket_at(eye)>=0: world.backdrop.set_indoor()

## Cull exterior geometry only from the room's main camera. Live windows
## keep their own full mask and continue to show the world outside.
func _cull_outside() -> void:
	var camera := player.get_viewport().get_camera_3d()
	_outside_culled = camera==player.camera and SpaceLayout.pocket_at(player.camera.global_position)>=0 and SpaceLayout.pocket_at(player.global_position)>=0
	player.camera.cull_mask = _old_cull_mask & ~ShipWindowView.EXTERIOR_LAYER if _outside_culled else _old_cull_mask

## The keys for what you are doing now, in the HUD's key help above the
## minimap (only while seated, out on the hull, in a lift or at a city table).
func _update_hint() -> void:
	var rows: Array = []
	match seat:
		"pilot":
			if _ship.mode in ["berth", "landed"]:
				rows.append([["@ship_boost"], "Launch"])
			elif _ship.mode=="flying":
				rows.append([["@ship_forward", "@ship_reverse"], "Throttle"])
				if _ship.climbing!="": rows.append([["@ship_forward"], "Climbing to orbit"])
				elif _ship.orbit!="": rows.append([["Steer"], "In orbit: %s - steer to leave" % str(SpaceLayout.planet(_ship.orbit).get("name", ""))])
				rows.append([["@ship_left", "@ship_right"], "Turn"])
				rows.append([["@ship_pitch_down", "@ship_pitch_up"], "Nose down / up"])
				rows.append([["@ship_roll_left", "@ship_roll_right"], "Roll"])
				rows.append([["@ship_boost"], "Boost"])
				rows.append([["@ship_fire"], "Fire cannons"])
				var land := _ship.landable()
				if not _ship.queue.is_empty(): rows.append([["@ship_land"], "Waiting to land"])
				elif not land.is_empty(): rows.append([["@ship_land"], "Land here?"])
				elif SpaceLayout.can_descend(_ship.xform.origin): rows.append([["@ship_land"], "Descend"])
				elif _ship.xform.origin.distance_to(SpaceLayout.NEXUS)<SpaceWorld.DOCK_RANGE: rows.append([["@ship_land"], "Dock"])
		"turret_top", "turret_left", "turret_right":
			if _ship!=null and _ship.mode=="flying":
				rows.append([["Mouse"], "Aim"])
				rows.append([["@ship_fire"], "Fire"])
		"chair_0", "chair_1", "chair_2", "chair_3":
			rows.append([["@leisure_smoke"], "Cigar"])
	if seat!="":
		rows.append([["@seat_camera"], "Change camera"])
		rows.append([["@seat_stand"], "Stand up"])
	elif spacewalk or _descent:
		if deck: rows.append([["@jetpack_thrust"], "Fly"])
		else:
			rows.append([["@jetpack_thrust", "@jetpack_descend"], "Up / Down"])
			rows.append([["W", "S"], "Forward / Back"])
			rows.append([["A", "D"], "Turn"])
			if not outside.is_empty():
				rows.append([["Ctrl"], "Reel in"])
				rows.append([["@interact"], "Unhook line"])
	if seat=="" and city_seat=="" and _lounge_seat=="" and world.zone_at(player.global_position)!="ship" and not world.jetpack_forbidden(player.global_position):
		rows.append([["@jetpack_toggle"],"Detach jetpack" if jetpack_attached else "Attach jetpack"])
		if jetpack_attached and not spacewalk and not _descent: rows.append([["@jetpack_thrust"],"Launch jetpack"])
	if city_seat!="":
		rows.append([["@interact"], "Sip"])
		rows.append([["C"], "Order"])
		rows.append([["Z"], "Stand up"])
	if _lift>=0: rows.append([["@interact"], "Press button"])
	_hint.text = ""
	var game := world.game_root()
	var hud: Variant = game.get("hud") if game else null
	rows.append_array(Leisure.hint_rows(player.player_id))
	if _lounge_seat!="": rows.append([["@seat_camera"], "Change camera"])
	if hud: hud.key_help.set_rows(rows)

func _notice_edge() -> void:
	if _notice_time>1.0 and _notice.text.begins_with("The edge"): return
	notice("The edge of the Reach. The ship's charm turns her back toward the Nexus.")

## R in Space: home to the Tavern like anywhere else. The realm gate brings
## you back to this very spot (and your ship with you).
func recall() -> void:
	if cinematic: return
	var game := world.game_root()
	if game and game.has_method("travel"): game.travel("hall")

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
				"deck", "adrift":
					_out_on_purpose = true
					_set_jetpack(true)
			match str(event[1]):
				"deck":
					outside = {}
					_deck_arrival = true
					notice("Up on deck. Space to fly with your jetpack.")
				"adrift":
					# The wreck news can come after the server already moved us
					# while our seat still held us in the room: go now.
					if event.size()>2 and event[2] is Vector3:
						player.global_position = event[2]
						player.velocity = Vector3.ZERO
					notice("Your ship is gone! You float on your jetpack. Another crew can pick you up, or press R to call Orin's rescue skiff.")
				"planet": pass

func _flash_fade() -> void:
	_fade.color.a = 1.0
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.6)

func hide_overlay() -> void:
	if is_instance_valid(_overlay): _overlay.hide()
	if is_instance_valid(_fp_shield): _fp_shield.hide()
	var game := world.game_root() if is_instance_valid(world) else null
	var hud: Variant = game.get("hud") if game else null
	if hud: hud.key_help.set_rows([])
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func toggle_map() -> void:
	map.visible = not map.visible

# --- Input ------------------------------------------------------------------------------

func active_ship_actions() -> Array[String]:
	var actions: Array[String] = []
	if seat=="" and _lounge_seat=="":
		if city_seat=="" and Leisure.seat_spec(player.player_id).is_empty() and _lift<0 and not world is SurfaceShipWorld and world.zone_at(player.global_position)!="ship":
			if not world.jetpack_forbidden(player.global_position): actions.append("jetpack_toggle")
			if jetpack_attached: actions.append_array(["jetpack_thrust","jetpack_descend"])
		return actions
	actions.assign(["seat_camera", "seat_stand"])
	if seat=="pilot" and _ship!=null:
		if _ship.mode in ["berth", "landed"]: actions.append("ship_boost")
		elif _ship.mode=="flying":
			actions.append_array(["ship_forward", "ship_reverse", "ship_left", "ship_right", "ship_pitch_up", "ship_pitch_down", "ship_roll_left", "ship_roll_right", "ship_boost", "ship_land", "ship_fire"])
	elif seat.begins_with("turret") and _ship!=null and _ship.mode=="flying": actions.append("ship_fire")
	return actions

func consumes_event(event: InputEvent) -> bool:
	if player.controls_locked() or player.ui_blocked or player.interacting(): return false
	if map.visible and not (event.is_action("seat_camera") or event.is_action("seat_stand")): return false
	for action: String in active_ship_actions():
		if event.is_action(action): return true
	return false

func blocks_action(action: String) -> bool:
	for ship_action: String in active_ship_actions():
		if AppSettings.bindings.get(action, {})==AppSettings.bindings.get(ship_action, {}): return true
	return false

func _input(event: InputEvent) -> void:
	if cinematic or player.controls_locked() or player.ui_blocked or player.interacting(): return
	if map.visible and not (event.is_action("seat_camera") or event.is_action("seat_stand")): return
	var game := world.game_root()
	if game and game.get("hud") and Leisure.handle_input(player, event, game.hud.interaction): return
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		var motion: Vector2 = event.relative*MOUSE_SENSITIVITY
		match seat:
			"pilot":
				_pilot_look.x -= motion.x
				_pilot_look.y = clampf(_pilot_look.y-motion.y, -1.2, 1.2)
			"turret_top", "turret_left", "turret_right":
				_turret_yaw -= motion.x
				# Side cannons sweep their own side only, never back across the hull.
				if seat!="turret_top": _turret_yaw = clampf(_turret_yaw, -SIDE_TURRET_SWEEP, SIDE_TURRET_SWEEP)
				_turret_pitch = clampf(_turret_pitch-motion.y, -0.35, 1.25)
			_:
				player.camera_yaw -= motion.x
				look_pitch = clampf(look_pitch-motion.y, -1.35, 1.35)
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey or event is InputEventMouseButton) or not event.is_pressed(): return
	if event is InputEventKey and event.echo: return
	if (seat!="" or _lounge_seat!="") and event.is_action_pressed("seat_camera"):
		map.hide()
		if seat=="pilot": _cockpit = not _cockpit
		else: _seat_interior = not _seat_interior
		_chase = Transform3D.IDENTITY
		get_viewport().set_input_as_handled()
		return
	if (seat!="" or _lounge_seat!="") and event.is_action_pressed("seat_stand"):
		if _lounge_seat!="": Leisure.request(player, ["stand"])
		else: world.request(["stand"])
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.physical_keycode==KEY_V and seat=="":
		if _lift>=0: notice("The elevator uses first person. Your camera returns when you step out.")
		else:
			camera_mode = (view_mode()+1) % 3
			if camera_mode==CameraMode.ANGLED and world.zone_at(player.global_position)=="station": camera_mode = CameraMode.SHOULDER
			AppSettings.video.space_camera = camera_mode
			AppSettings.save_preferences()
		get_viewport().set_input_as_handled()
		return
	if city_seat!="":
		if event.is_action_pressed("interact"): world.request(["city", "sip"])
		elif event is InputEventKey and event.physical_keycode==KEY_C: world.request(["city", "order"])
		elif event is InputEventKey and event.physical_keycode==KEY_Z: world.request(["city", "stand"])
		else: return
		get_viewport().set_input_as_handled()
		return
	if _lift>=0 and (event.is_action_pressed("interact") or event.is_action_pressed("shoot")):
		var button := _lift_button()
		if button>=0: world.request(["city", "call", _lift, button])
		get_viewport().set_input_as_handled()
		return
	if seat=="" and _lounge_seat=="" and city_seat=="" and _lift<0 and not world is SurfaceShipWorld and world.zone_at(player.global_position)!="ship" and event.is_action_pressed("jetpack_toggle"):
		if world.jetpack_forbidden(player.global_position):
			notice("Jetpacks are disabled in strongholds and boss fights.")
		else:
			_set_jetpack(not jetpack_attached)
			notice("Jetpack attached. Space launches; Z detaches." if jetpack_attached else "Jetpack detached.")
		get_viewport().set_input_as_handled()
		return
	if spacewalk and not outside.is_empty() and outside.flying and event.is_action_pressed("interact"):
		var root := world.game_root()
		var overlay: Variant = root.get("hud") if root else null
		if overlay==null or overlay.interaction.target==null:
			_jet = _hull(int(outside.ship)).basis*(outside.vel as Vector3)
			outside = {}
			_rope.visible = false
			_rehook_after = Time.get_ticks_msec()+2500
			notice("Line unhooked. Jetpack down to a planet, or fly back to her deck.")
			get_viewport().set_input_as_handled()
			return
	if seat=="pilot" and _ship!=null:
		if event.is_action_pressed("ship_boost") and _ship.mode in ["berth", "landed"]:
			world.request(["takeoff"])
		elif _ship.mode=="flying" and event.is_action_pressed("ship_land"):
			land()
		elif not consumes_event(event): return
		get_viewport().set_input_as_handled()

## The helm's land key: down to the Surface, onto a pad, or into a berth.
func land() -> void:
	if _ship==null or _ship.mode!="flying": return
	if SpaceLayout.can_descend(_ship.xform.origin): world.request(["descend"])
	else: world.request(["land"] if not _ship.landable().is_empty() else ["dock"])

func _lift_button() -> int:
	var planet: SpacePlanet = world.planets.get(CityLayout.ID)
	if planet==null or _lift<0: return -1
	var city := planet.get_node_or_null("City") as CityPlanet
	if city==null: return -1
	for district: CityDistrict in city.districts.values():
		var button := district.button_at(_lift, player.camera.global_position, -player.camera.global_basis.z)
		if button>=0: return button
	return -1

func free_look() -> bool:
	return view_mode()!=CameraMode.ANGLED or world.first_person_at(player.global_position)

## The camera in use: the Nexus has no angled view, so there it is the
## shoulder view unless first person was chosen.
func view_mode() -> CameraMode:
	if camera_mode==CameraMode.ANGLED and world.zone_at(player.global_position)=="station": return CameraMode.SHOULDER
	return camera_mode

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
	player.model.animate(0.0, delta)
	CityState.seated_pose(player.model)
	match seat:
		"pilot":
			var enabled := _ship.mode=="flying" and not player.controls_locked() and not player.ui_blocked and not player.interacting() and not map.visible and not cinematic
			if _ship.mode!="flying":
				throttle = 0.0
				_launching = true
			elif _launching:
				# Just launched: an easy speed, and she climbs into orbit by herself.
				_launching = false
				throttle = LAUNCH_THROTTLE
			elif enabled:
				# 10% a step: one on the press, then more while the key is held.
				var axis := Input.get_axis("ship_reverse", "ship_forward")
				if is_zero_approx(axis): _throttle_hold = 0.0
				else:
					_throttle_hold -= delta
					if _throttle_hold<=0.0:
						_throttle_hold = THROTTLE_REPEAT
						throttle = clampf(snappedf(throttle+signf(axis)*THROTTLE_STEP, THROTTLE_STEP), -1.0, 1.0)
			# Climbing out after a launch: no slower than launch speed (the server holds her there too).
			if _ship.climbing!="": throttle = maxf(throttle, SpaceShip.LAUNCH_THRUST)
			_input_timer -= delta
			if _input_timer<=0.0:
				_input_timer = INPUT_RATE
				# A menu or the chat only frees the controls: the throttle holds.
				var thrust := throttle if _ship.mode=="flying" else 0.0
				var yaw := Input.get_axis("ship_left", "ship_right") if enabled else 0.0
				if enabled and player.debug_input!=Vector2.ZERO:
					thrust = -player.debug_input.y
					yaw = player.debug_input.x
				var pitch := Input.get_axis("ship_pitch_down", "ship_pitch_up") if enabled else 0.0
				var roll := Input.get_axis("ship_roll_left", "ship_roll_right") if enabled else 0.0
				world.request(["pilot", [thrust, yaw, pitch, roll, enabled and Input.is_action_pressed("ship_boost"), false]])
			_fire_timer -= delta
			if enabled and not Leisure.hands_busy(player.player_id) and Input.is_action_pressed("ship_fire") and _fire_timer<=0.0 and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
				_fire_timer = 0.2
				world.request(["fire", _pilot_direction()])
		"turret_top", "turret_left", "turret_right":
			var dir := _turret_direction()
			_aim_timer -= delta
			if _aim_timer<=0.0:
				_aim_timer = AIM_RATE
				world.request(["aim", dir])
			_fire_timer -= delta
			if _ship.mode=="flying" and not Leisure.hands_busy(player.player_id) and Input.is_action_pressed("ship_fire") and _fire_timer<=0.0 and not player.controls_locked() and not player.ui_blocked and not player.interacting() and not map.visible and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
				_fire_timer = 0.2
				world.request(["fire", dir])
				GameAudio.play("enemy_shot", player.camera.global_position)
		"map":
			pass

func _update_target_locks(aim: Vector3) -> void:
	var sight := _crosshair as SpaceCrosshair
	var points: Array[Vector2] = []
	var ids: Array[String] = []
	if _ship==null:
		sight.set_locks(points, ids)
		return
	var origin := world.turret_muzzle(_ship, seat)
	var cone := TurretTargeting.PILOT_CONE if seat=="pilot" else TurretTargeting.CONE
	var targets := _locked_targets
	_lock_timer -= get_process_delta_time()
	if _lock_timer<=0.0:
		_lock_timer = AIM_RATE
		_locked_targets = TurretTargeting.select(world, origin, aim, cone)
		targets = _locked_targets
	var to_local := sight.get_global_transform_with_canvas().affine_inverse()
	for target: Dictionary in targets:
		var sample := TurretTargeting.sample(target, world)
		if sample.is_empty(): continue
		var point := _sight_point(sample.pos)
		if not player.camera.is_position_behind(point):
			points.append(to_local*player.camera.unproject_position(point))
			if str(target.kind)=="flag":
				var flag := (target.flag as WeakRef).get_ref() as TargetFlag
				ids.append("flag:%d" % flag.get_instance_id())
			else: ids.append("brood:%d" % int(target.id))
	var point := _sight_point(origin+aim*500.0)
	if player.camera.is_position_behind(point):
		sight.mode = ""
		sight.set_locks([], [])
		return
	var center := to_local*player.camera.unproject_position(point)
	var edge := to_local*player.camera.unproject_position(point+player.camera.global_basis.x*tan(cone)*500.0)
	sight.aim_center = center
	sight.lock_radius = center.distance_to(edge)
	sight.set_locks(points, ids)

func _pilot_direction() -> Vector3:
	var view: SpaceShipView = world.ship_views.get(_ship.id)
	return -view.global_basis.z if view else -_ship.xform.basis.z

func _sight_point(point: Vector3) -> Vector3:
	if _ship!=null and ((seat=="pilot" and _cockpit) or (seat.begins_with("turret") and _seat_interior)):
		var view: SpaceShipView = world.ship_views.get(_ship.id)
		if view:
			return view.global_transform.affine_inverse()*point-ShipHull.INTERIOR_OFFSET+SpaceLayout.pocket_origin(_ship.slot)
	return point

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
		if not player.frozen and seat=="" and world.city.seat_of(player.player_id)=="": player.clear_spawn(world)
		return
	city_seat = world.city.seat_of(player.player_id)
	if city_seat!="":
		var spec := CityLayout.any_seat(city_seat)
		player.global_transform = Transform3D(spec.basis, spec.pos)
		player.up_direction = player.global_basis.y
		player.velocity = Vector3.ZERO
		player.facing = float(spec.yaw)
		player.model.rotation.y = player.facing
		player._cancel_weapon_actions()
		player.model.animate(0.0, delta)
		CityState.seated_pose(player.model)
		return
	# The floor displacement is evaluated from the same server clock as its
	# visible car, before movement. Menu users ride along too.
	if _lift>=0:
		var tower := CityLayout.tower_world(CityLayout.elevators()[_lift])
		var local := tower.affine_inverse()*player.global_position-CityState.SHAFT
		if absf(local.x)<CityState.CAR.x*0.5+0.3 and absf(local.z)<CityState.CAR.z*0.5+0.3 and absf(local.y-_lift_height)<3.0:
			# Stand on the car's floor itself while it rides (no sinking through it
			# a frame behind); the car was placed first this frame (CityDistrict).
			var car := float(world.city.car_state(_lift)[0])
			if str(world.city.elevators[_lift].phase)=="moving" or absf(car-_lift_height)>0.001:
				player.global_position += tower.basis.y*(car-local.y)
				player.velocity = player.velocity.slide(tower.basis.y)
	_lift = world.city.car_at(player.global_position)
	if _lift>=0: _lift_height = float(world.city.car_state(_lift)[0])
	if cinematic or seat!="":
		player.velocity = Vector3.ZERO
		return
	var state := world.sample_gravity(player.global_position)
	if jetpack_attached and world.jetpack_forbidden(player.global_position):
		_set_jetpack(false)
		notice("Jetpack detached: ground combat only in strongholds and boss fights.")
	# Keep the equipped pack while crossing the atmosphere and on touchdown.
	if spacewalk and outside.is_empty() and str(state.zone).begins_with("planet:"):
		_descent = jetpack_attached
		_planet_fall = not jetpack_attached
	if _descent or _planet_fall:
		spacewalk = false
		_out_on_purpose = true
		_last_zone = str(state.zone)
		if str(state.zone).begins_with("planet:") or state.zone=="station":
			_jet_descent(delta,state)
			return
		_descent = false  # Outside the atmosphere, continue in free flight.
		_planet_fall = false
	if jetpack_attached and (str(state.zone).begins_with("planet:") or state.zone=="station") and not player.controls_locked() and not player.ui_blocked and not player.interacting() and _lift<0 and Input.is_action_just_pressed("jetpack_thrust") and fuel>5.0:
		_descent = true
		_planet_fall = false
		spacewalk = false
		_out_on_purpose = true
		_jet = player.global_basis.y*8.0
		player.global_position += player.global_basis.y*0.2
		if player.shield.active: player._set_shield(false)
		_jet_descent(delta,state)
		return
	# From a ship room straight into open space is the ladder or a lost ship.
	# Up through the hatch: stand on her deck even low in a planet's air.
	if _deck_arrival and SpaceLayout.pocket_at(player.global_position)<0:
		_deck_arrival = false
		_set_jetpack(true)
		_out_on_purpose = true
		_find_deck()
	if state.zone=="ship": outside = {}
	if state.zone=="void" and _last_zone=="ship":
		_out_on_purpose = true
		_set_jetpack(true)
	if state.zone!="void" and outside.is_empty(): _out_on_purpose = false
	_last_zone = str(state.zone)
	spacewalk = _out_on_purpose and (state.zone=="void" or not outside.is_empty())
	if spacewalk:
		var before_jet_step := player.global_position
		_spacewalk(delta)
		if jetpack_attached and not world.jetpack_forbidden(before_jet_step) and world.jetpack_blocks_segment(before_jet_step,player.global_position):
			player.global_position = before_jet_step
			_jet = Vector3.ZERO
			if not outside.is_empty():
				outside.at = _hull(int(outside.ship)).affine_inverse()*before_jet_step
				outside.vel = Vector3.ZERO
			_jetpack_boundary_notice()
		player.set_meta("jetpack_flying",not deck and jetpack_attached)
		if not jetpack_attached: player._update_magic(delta)
		player._update_combat(delta,Vector3.ZERO,JET_MAX)
		return
	player.set_meta("jetpack_flying",false)
	player.set_meta("jet_on",false)
	_jet = Vector3.ZERO
	outside = {}
	_rope.visible = false
	fuel = minf(100.0, fuel+FUEL_REGEN*delta)
	var frame: Transform3D = state.frame
	# Dropped into the deck (arriving before its collision was ready): back on top.
	if state.zone=="station" and player.global_position.y< -0.6:
		player.global_position = world.recovery_point(player.global_position)
		player.velocity = Vector3.ZERO
	if state.zone=="planet:"+CityLayout.ID and player.global_position.distance_to(CityLayout.planet().center)<CityLayout.radius()-8.0:
		player.global_position = _checkpoint if world.zone_at(_checkpoint)==state.zone else (CityLayout.planet().center as Vector3)+CityLayout.district_frame(CityLayout.DISTRICTS[0]).origin+Vector3.UP
		player.velocity = Vector3.ZERO
	var blend := 1.0-exp(-delta*10.0)
	player.global_basis = player.global_basis.slerp(frame.basis, blend).orthonormalized()
	player.up_direction = player.global_basis.y
	var up := player.up_direction
	# No magic or weapons aboard a ship: the crew is safe in the room.
	var aboard: bool = state.zone=="ship"
	if not aboard and not jetpack_attached: player._update_magic(delta)
	elif jetpack_attached and player.shield.active: player._set_shield(false)
	if aboard or player.shield.active or player.stats.buffs.has_effect("quiet") or player.controls_locked() or player.interacting(): player._cancel_weapon_actions()
	if not player.controls_locked() and not free_look():
		player.camera_yaw += Input.get_axis("orbit_right", "orbit_left")*Player.ORBIT_SPEED*delta
	var input := Vector2.ZERO if player.controls_locked() else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if player.debug_input!=Vector2.ZERO: input = player.debug_input

	if player.stats.buffs.has_effect("static"): input = Vector2.ZERO
	var dir := player.drunk_sway((player.global_basis*Basis(Vector3.UP, player.camera_yaw)*Vector3(input.x, 0, input.y)).slide(up).normalized()*input.length(), up)
	var speed := Player.BASE_SPEED*player.stats.move_speed_multiplier()*(Player.SHIELD_MOVE_SPEED if player.shield.active else Player.CHARGE_MOVE_SPEED if player._charging else 1.0)
	var fall := minf(0.0, player.velocity.dot(up))-Player.GRAVITY*delta
	player.velocity = dir*speed+player._knock.slide(up)+up*(-2.0 if player.is_on_floor() else fall)
	player._knock = player._knock.lerp(Vector3.ZERO, 1.0-exp(-Player.KNOCKBACK_DRAG*delta))
	var before := player.global_position
	player.move_and_slide()
	# Step up only when a ledge really stopped us (not on every steep bit of hill).
	var made := (player.global_position-before).slide(up).length()
	if not dir.is_zero_approx() and player.is_on_floor() and player.is_on_wall() and made<speed*delta*0.5:
		player._try_step_up(dir, up, STEP_UP)
	# Steps, floor snaps and little catches on hilly ground move the body in
	# jumps; the model (and the camera with it) glide to the new height.
	var rise := (player.global_position-before).dot(up)
	if absf(rise)>0.12: player._visual_offset -= rise
	player._visual_offset = clampf(lerpf(player._visual_offset, 0.0, minf(1.0, delta*Player.STEP_SMOOTHING)), -1.5, 1.5)
	player.model.position.y = player._visual_offset
	var query := PhysicsRayQueryParameters3D.create(player.global_position+up*0.5, player.global_position-up*1.2, Player.TERRAIN_LAYER|Player.OBSTACLE_LAYER)
	query.exclude = [player.get_rid()]
	var ground := player.get_world_3d().direct_space_state.intersect_ray(query)
	if not ground.is_empty() and (ground.normal as Vector3).dot(up)>0.5:
		_checkpoint = player.global_position
	elif state.zone=="void" or (float(state.distance)>30.0 and state.zone!="planet:"+CityLayout.ID):
		player.global_position = world.recovery_point(_checkpoint) if world.zone_at(_checkpoint)!="void" else world.spawn_point
		player.velocity = Vector3.ZERO
	if not aboard: player._update_combat(delta, dir, speed)
	else:
		if free_look(): player.facing = player.camera_yaw
		elif not dir.is_zero_approx():
			var local_dir := player.global_basis.inverse()*dir
			player.facing = atan2(-local_dir.x, -local_dir.z)
		player.model.rotation.y = player.facing
		player.model.animate(dir.length(), delta)
	player.aim_marker.hide()

# --- Outside on the jetpack ------------------------------------------------------------

## Walking her deck (WASD), or flying beside her on the jetpack. Space takes
## off and climbs, Shift sinks, W and S lean you forward and back, A and D
## turn; set down on the deck to walk again (the deck is the only place to
## land). Flying, you live in the ship's frame, so she carries you along.
## Without a ship (she was lost) you float free in space.
func _spacewalk(delta: float) -> void:
	if jetpack_attached and player.shield.active: player._set_shield(false)
	player.up_direction = Vector3.UP
	var locked := player.controls_locked()
	var input := Vector2.ZERO if locked else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if player.debug_input!=Vector2.ZERO: input = player.debug_input
	var rise := 0.0 if locked else float(Input.is_action_pressed("jetpack_thrust"))-float(Input.is_action_pressed("jetpack_descend"))
	if not outside.is_empty() and not world.ship_views.has(int(outside.ship)):
		outside = {}
		notice("Your ship is gone! Your jetpack keeps you floating.")
	if outside.is_empty() and Time.get_ticks_msec()>_rehook_after: _find_deck()
	if outside.is_empty():
		_drift(delta, input, rise)
		return
	var hull := _hull(int(outside.ship))
	var at: Vector3 = outside.at
	if not outside.flying:
		deck = true
		fuel = minf(100.0, fuel+FUEL_REGEN*delta)
		if jetpack_attached and rise>0.5 and fuel>5.0:
			outside.flying = true
			outside.vel = Vector3.UP*3.0
			notice("Your line clips on at the deck hatch. Hold Ctrl to reel in.")
		else:
			var view := player.camera.global_basis
			var forward := ((hull.basis.inverse()*-view.z)*Vector3(1, 0, 1)).normalized()
			var right := ((hull.basis.inverse()*view.x)*Vector3(1, 0, 1)).normalized()
			var step := (right*input.x-forward*input.y)*Player.BASE_SPEED*player.stats.move_speed_multiplier()*delta
			at = _walk_deck(at+step)
			outside.at = at
			player.global_position = hull*at
			player.global_basis = hull.basis
			player.model.rotation = Vector3(0, atan2(-step.x, -step.z) if step.length()>0.001 else player.model.rotation.y, 0)
			player.model.animate(input.length(), delta)
			player.set_meta("jet_on", false)
			_rope.visible = false
			player.velocity = Vector3.ZERO
			return
	deck = false
	if not locked: player.camera_yaw -= input.x*JET_TURN*delta
	var facing := Basis(Vector3.UP, player.camera_yaw)
	var want := facing*Vector3(0, rise, input.y)
	var burning := jetpack_attached and want.length()>0.1 and fuel>0.5
	var vel: Vector3 = outside.vel
	if burning:
		vel = vel.move_toward(want.limit_length(1.0)*JET_MAX, JET_ACCEL*delta)
		fuel = maxf(0.0, fuel-FUEL_DRAIN*delta)
		_fuel_rest = 0.6
	else:
		vel = vel.move_toward(Vector3.ZERO, JET_ACCEL*0.35*delta)
		_fuel_rest -= delta
		if _fuel_rest<=0.0: fuel = minf(100.0, fuel+FUEL_REGEN*delta)
	at += vel*delta
	# The line pays out by itself up to its length; Ctrl winds it back in.
	var anchor := SpaceWorld.DECK_HATCH+Vector3.UP*0.4
	if not locked and Input.is_key_pressed(KEY_CTRL):
		at = at.move_toward(anchor, REEL_SPEED*delta)
		vel = vel.move_toward(Vector3.ZERO, JET_ACCEL*delta)
	var line := at-anchor
	if line.length()>ROPE_MAX:
		at = anchor+line.normalized()*ROPE_MAX
		var out := line.normalized()
		vel -= out*maxf(0.0, vel.dot(out))
	var pushed := ShipHull.push_out(at)
	if pushed!=at:
		var normal := (pushed-at).normalized()
		vel -= normal*minf(0.0, vel.dot(normal))
		at = pushed
	# Touching down on the deck: walk again, the line unclips.
	if rise<=0.0 and vel.y<=0.5 and _over_deck(at) and at.y<=ShipHull.DECK_TOP+0.3:
		outside.flying = false
		at.y = ShipHull.DECK_TOP
		vel = Vector3.ZERO
	outside.at = at
	outside.vel = vel
	player.global_position = hull*at
	player.global_basis = hull.basis
	player.model.rotation = Vector3(input.y*0.35, player.camera_yaw, -input.x*0.12)
	player.set_meta("jet_on", burning)
	player.velocity = Vector3.ZERO
	_update_rope(hull)

## Free in space without a ship: the same controls, in the world's frame.
func _drift(delta: float, input: Vector2, rise: float) -> void:
	deck = false
	_rope.visible = false
	player.global_basis = player.global_basis.slerp(Basis.IDENTITY, 1.0-exp(-delta*4.0)).orthonormalized()
	if not player.controls_locked(): player.camera_yaw -= input.x*JET_TURN*delta
	var want := player.global_basis*Basis(Vector3.UP, player.camera_yaw)*Vector3(0, rise, input.y)
	var burning := jetpack_attached and want.length()>0.1 and fuel>0.5
	if burning:
		_jet = _jet.move_toward(want.limit_length(1.0)*JET_MAX, JET_ACCEL*delta)
		fuel = maxf(0.0, fuel-FUEL_DRAIN*delta)
		_fuel_rest = 0.6
	else:
		_jet = _jet.move_toward(Vector3.ZERO, JET_ACCEL*0.35*delta)
		_fuel_rest -= delta
		if _fuel_rest<=0.0: fuel = minf(100.0, fuel+FUEL_REGEN*delta)
	var destination := player.global_position+_jet*delta
	if world.jetpack_blocks_segment(player.global_position,destination):
		_jet = Vector3.ZERO
		_jetpack_boundary_notice()
	else: player.global_position = destination
	player.model.rotation = Vector3(input.y*0.35, player.camera_yaw, 0)
	player.set_meta("jet_on", burning)
	player.velocity = Vector3.ZERO

## Fly through planet air without losing the pack; touching down returns to
## ordinary walking, leaving Space available to launch again.
func _jet_descent(delta: float, state: Dictionary) -> void:
	_rope.visible = false
	if player.shield.active: player._set_shield(false)
	var frame: Transform3D = state.frame
	player.global_basis = player.global_basis.slerp(frame.basis,1.0-exp(-delta*8.0)).orthonormalized()
	player.up_direction = player.global_basis.y
	var up := player.up_direction
	var locked := player.controls_locked() or player.ui_blocked or player.interacting()
	var input := Vector2.ZERO if locked else Input.get_vector("move_left","move_right","move_forward","move_back")
	var rise := 0.0 if locked else float(Input.is_action_pressed("jetpack_thrust"))-float(Input.is_action_pressed("jetpack_descend"))
	if not locked: player.camera_yaw -= input.x*JET_TURN*delta
	var want := player.global_basis*Basis(Vector3.UP,player.camera_yaw)*Vector3(0,rise,input.y)
	var burning := jetpack_attached and fuel>0.5 and want.length()>0.1
	if burning:
		_jet = _jet.move_toward(want.limit_length(1.0)*JET_MAX*1.4,JET_ACCEL*delta)
		fuel = maxf(0.0,fuel-FUEL_DRAIN*delta)
		_fuel_rest = 0.6
	else:
		_jet = _jet.move_toward(Vector3.ZERO,JET_ACCEL*0.2*delta)
		_fuel_rest -= delta
		if _fuel_rest<=0.0: fuel = minf(100.0,fuel+FUEL_REGEN*0.25*delta)
	_jet = (_jet-up*6.0*delta).limit_length(26.0)
	var previous := player.global_position
	if not world.jetpack_forbidden(previous) and world.jetpack_blocks_segment(previous,previous+_jet*delta):
		var along_boundary := _jet.slide(up)
		_jet = along_boundary if not world.jetpack_blocks_segment(previous,previous+along_boundary*delta) else Vector3.ZERO
		_jetpack_boundary_notice()
	player.velocity = _jet
	player.move_and_slide()
	_jet = player.velocity
	var floor_frame := world.surface_frame(player.global_position)
	var below := (player.global_position-floor_frame.origin).dot(floor_frame.basis.y)<0.06
	if (rise<=0.0 or not burning) and (player.is_on_floor() or below):
		if below: player.global_position = floor_frame.origin+floor_frame.basis.y*0.08
		_descent = false
		_planet_fall = false
		spacewalk = false
		_out_on_purpose = false
		_jet = Vector3.ZERO
		player.velocity = Vector3.ZERO
		player.model.rotation = Vector3(0,player.facing,0)
		player.set_meta("jet_on",false)
		player.set_meta("jetpack_flying",false)
		_checkpoint = player.global_position
	else:
		player.set_meta("jet_on",burning)
		player.set_meta("jetpack_flying",true)
		player._update_combat(delta,(player.global_position-previous).slide(up)/maxf(delta,0.001),JET_MAX)

func _set_jetpack(attached: bool) -> void:
	jetpack_attached = attached
	player.set_meta("jetpack_attached",attached)
	player._last_magic_press = -10.0
	if player.shield.active: player._set_shield(false)
	if not attached:
		if _descent:
			player.velocity = _jet
			_planet_fall = true
		_descent = false
		player.set_meta("jet_on",false)
		player.set_meta("jetpack_flying",false)

func _jetpack_boundary_notice() -> void:
	if Time.get_ticks_msec()<_jetpack_block_notice: return
	_jetpack_block_notice = Time.get_ticks_msec()+2500
	notice("Land outside the stronghold and enter on foot.")

## The ports' red ship badges, seen from aboard a ship near a planet (the
## planet hides those round its far side). A tale's yellow mark replaces the
## badge of the port it asks you to land at. Also the landing line's toast.
func _update_ports() -> void:
	var slot := SpaceLayout.pocket_at(player.global_position)
	var ship: SpaceShip = _ship if _ship else world.ship_in_slot(slot) if slot>=0 else null
	var targets: Array = world.my_marks().filter(func(m: Dictionary) -> bool: return m.kind=="target").map(func(m: Dictionary) -> Vector3: return m.pos)
	# Ports show on the two planets nearest the ship (or you, on foot at a
	# planet), always including the one you are at.
	var nearest: Array = []
	if ship!=null or SpaceLayout.pocket_at(player.global_position)<0:
		var from := ship.xform.origin if ship!=null else player.global_position
		nearest = SpaceLayout.PLANETS.duplicate()
		nearest.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return from.distance_to(a.center)-float(a.radius)<from.distance_to(b.center)-float(b.radius))
		nearest = nearest.slice(0, 2).map(func(p: Dictionary) -> String: return str(p.id))
	_update_nexus_mark(ship)
	for p: Dictionary in SpaceLayout.PLANETS:
		var near := str(p.id) in nearest
		var planet: Node3D = world.planets.get(p.id)
		for entry: Dictionary in SpaceLayout.ports(p):
			var key := str(entry.key)
			var pose: Transform3D = entry.pose
			if not _port_marks.has(key):
				if not near or not is_instance_valid(planet): continue
				var holder := Node3D.new()
				planet.add_child(holder)
				holder.global_transform = Transform3D(pose.basis, pose.origin+pose.basis.y*34.0)
				var badge := QuestMarker.new("port")
				holder.add_child(badge)
				badge.scale = Vector3.ONE*1.6
				badge._material.disable_fog = true
				_port_marks[key] = holder
			var mark: Node3D = _port_marks[key]
			if is_instance_valid(mark): mark.visible = near and not targets.any(func(t: Vector3) -> bool: return t.distance_to(pose.origin)<80.0)
	var text := "" if ship==null or ship.queue.is_empty() else "Waiting to land at %s - number %d in line" % [str(ship.queue[0]), int(ship.queue[1])]
	if text==_queue_text: return
	_queue_text = text
	var game := world.game_root()
	var hud: Variant = game.get("hud") if game else null
	if hud==null: return
	if text=="": hud.toasts.unpin("landing_queue")
	else: hud.toasts.pin("landing_queue", text, UIStyle.GOLD)

## The pink Nexus badge: seen from anywhere out in open space (flying or on
## the jetpack), not on a planet or at the Nexus itself.
func _update_nexus_mark(ship: SpaceShip) -> void:
	if not is_instance_valid(_nexus_mark):
		_nexus_mark = Node3D.new()
		world.add_child(_nexus_mark)
		_nexus_mark.global_position = SpaceLayout.NEXUS+Vector3.UP*NEXUS_MARK_HEIGHT
		var badge := QuestMarker.new("nexus")
		_nexus_mark.add_child(badge)
		badge.scale = Vector3.ONE*1.6
		badge._material.disable_fog = true
	var at := ship.xform.origin if ship!=null and ship.mode=="flying" else player.global_position if spacewalk else Vector3.INF
	_nexus_mark.visible = at.is_finite() and world.zone_at(at)=="void" and at.distance_to(SpaceLayout.NEXUS)>SpaceWorld.DOCK_RANGE

## Just came up through a deck hatch (or the ship found us near her deck):
## stand on the deck of the nearest ship.
func _find_deck() -> void:
	var best := {}
	var best_d := 6.0
	for ship: SpaceShip in world.ships.values():
		var view: SpaceShipView = world.ship_views.get(ship.id)
		if view==null: continue
		var local := view.pose().affine_inverse()*player.global_position
		var d := absf(local.y-ShipHull.DECK_TOP)
		if d<best_d and absf(local.x)<ShipHull.beam(local.z)+2.0 and local.z>ShipHull.BRIDGE_Z-1.0 and local.z<ShipHull.STERN_Z:
			best_d = d
			best = {ship = ship.id, at = _walk_deck(Vector3(local.x, ShipHull.DECK_TOP, local.z)), flying = false, vel = Vector3.ZERO}
	outside = best

## A step on the deck: inside the rail, around the wheelhouse, masts and castle.
func _walk_deck(at: Vector3) -> Vector3:
	at.y = ShipHull.DECK_TOP
	at.z = clampf(at.z, ShipHull.BRIDGE_Z+0.6, 13.0)
	var half := ShipHull.beam(at.z)-0.9
	at.x = clampf(at.x, -half, half)
	at = ShipHull.push_out(at+Vector3.UP*0.9)-Vector3.UP*0.9
	at.y = ShipHull.DECK_TOP
	return at

## Over the open main deck, where the crew can set down.
func _over_deck(at: Vector3) -> bool:
	return at.z>ShipHull.BRIDGE_Z+0.6 and at.z<13.0 and absf(at.x)<ShipHull.beam(at.z)-0.9 and at.y>ShipHull.DECK_TOP-0.5

## Where a ship's hull is this very frame (its view's pose, not last
## physics tick's transform: at full speed that is metres apart).
func _hull(ship_id: int) -> Transform3D:
	var view: SpaceShipView = world.ship_views.get(ship_id)
	return view.pose() if view else Transform3D.IDENTITY

## Every rendered frame, outside: stay where you are in her frame, so she
## never slides past you between physics ticks.
func _pin_to_hull() -> void:
	if not spacewalk or outside.is_empty() or not world.ship_views.has(int(outside.ship)): return
	# Sent down through the deck hatch: we are in her room now, not on the hull.
	if SpaceLayout.pocket_at(player.global_position)>=0:
		outside = {}
		return
	var hull := _hull(int(outside.ship))
	player.global_position = hull*(outside.at as Vector3)
	player.global_basis = hull.basis
	_update_rope(hull)

## The line from the deck hatch to your belt, hanging in a gentle curve.
func _update_rope(hull: Transform3D) -> void:
	if outside.is_empty() or not outside.flying:
		_rope.visible = false
		return
	var a := hull*(SpaceWorld.DECK_HATCH+Vector3.UP*0.4)
	var b := player.global_position+player.global_basis.y*0.95
	var sag := clampf(a.distance_to(b)*0.08, 0.15, 2.5)
	var bend := (a+b)*0.5-hull.basis.y*sag
	var points: Array[Vector3] = []
	for k in 17:
		var t := float(k)/16.0
		points.append(a.lerp(bend, t).lerp(bend.lerp(b, t), t))
	_draw_rope(points)

func _draw_rope(points: Array[Vector3]) -> void:
	_rope.visible = true
	_rope_mesh.clear_surfaces()
	var eye := player.camera.global_position
	_rope_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for k in points.size():
		var p: Vector3 = points[k]
		var along: Vector3 = (points[mini(k+1, points.size()-1)]-points[maxi(k-1, 0)]).normalized()
		var side := along.cross(eye-p).normalized()*0.05
		_rope_mesh.surface_set_normal((eye-p).normalized())
		_rope_mesh.surface_add_vertex(p-side)
		_rope_mesh.surface_set_normal((eye-p).normalized())
		_rope_mesh.surface_add_vertex(p+side)
	_rope_mesh.surface_end()

var _launch_shake_until := 0

func launch_shake() -> void:
	_launch_shake_until = Time.get_ticks_msec()+5000

func _shake_camera() -> void:
	var remaining := clampf(float(_launch_shake_until-Time.get_ticks_msec())/5000.0, 0.0, 1.0)
	if remaining<=0.0: return
	var t := Time.get_ticks_msec()*0.001
	player.camera.position += Vector3(sin(t*51.0), cos(t*63.0), 0.0)*0.045*remaining

func update_camera(delta: float) -> void:
	if seat!="" or city_seat!="" or spacewalk or _descent or cinematic or player.frozen:
		player._visual_offset = 0.0  # the walking glide only (physics_step)
		player.model.position.y = 0.0
	var in_chair := seat.begins_with("chair") or city_seat!="" or _lounge_seat!=""
	var mode := view_mode()
	var want_fp := _cockpit if seat=="pilot" else _seat_interior if seat!="" or _lounge_seat!="" else mode==CameraMode.FIRST_PERSON or world.first_person_at(player.global_position)
	first_person = move_toward(first_person, 1.0 if want_fp else 0.0, delta/0.25)
	var shoulder := mode==CameraMode.SHOULDER and not want_fp
	var allow_capture := (want_fp or shoulder or spacewalk or seat!="" or _lounge_seat!="") and not player.controls_locked() \
		and not player.ui_blocked and not player.interacting() and not map.visible and not cinematic
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if allow_capture else Input.MOUSE_MODE_VISIBLE
	var sight := _crosshair as SpaceCrosshair
	sight.mode = ""
	if seat=="": sight.aim_center = sight.size*Vector2(0.5, 0.42 if shoulder else 0.5)
	if allow_capture:
		if seat=="pilot" and _ship!=null and _ship.mode=="flying": sight.mode = "pilot"
		elif seat.begins_with("turret") and _ship!=null and _ship.mode=="flying": sight.mode = "turret"
		elif seat=="" or in_chair or _seat_interior: sight.mode = "fp"
	_crosshair.queue_redraw()
	_overlay.visible = not player.input_locked and not cinematic
	var alive := player.stats.hp>0.0
	player.model.visible = first_person<0.88 and alive
	player.status_visuals.visible = first_person<0.8 and alive
	player.aura.visible = first_person<0.8 and alive
	_update_first_person_shield()
	if cinematic: return
	if seat!="" and not seat.begins_with("chair") and _ship!=null and world.ship_views.has(_ship.id):
		_seat_camera(delta)
		_shake_camera()
		return
	var up := player.global_basis.y
	var orbit := player.global_basis*Basis(Vector3.UP, player.camera_yaw)
	var head := player.global_position+up*(1.57+player._visual_offset)
	var view := orbit*Basis(Vector3.RIGHT, look_pitch)
	if want_fp or shoulder or (spacewalk and mode==CameraMode.ANGLED):
		var at := head
		if not want_fp:
			at += view*Vector3(0.65, 0.25, 4.8 if shoulder else 6.5)
			var ray := PhysicsRayQueryParameters3D.create(head, at, Player.TERRAIN_LAYER|Player.OBSTACLE_LAYER)
			ray.exclude = [player.get_rid()]
			var hit := player.get_world_3d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty(): at = (hit.position as Vector3)-(at-head).normalized()*0.25
			player.model.visible = alive and at.distance_to(head)>0.65
		player.camera.global_transform = Transform3D(view, at)
		player.camera.fov = 78.0 if want_fp else 72.0
		_shake_camera()
		return
	var target := player.global_position+up*(1.0+player._visual_offset)
	var pitch := Player.CAMERA_PITCH
	var at := target+orbit*Vector3(0, sin(pitch), cos(pitch))*player.camera_distance
	# City rooms have solid ceilings; pull the angled camera inside when needed.
	if world.zone_at(player.global_position) in ["planet:"+CityLayout.ID, "station"]:
		var query := PhysicsRayQueryParameters3D.create(head, at, Player.TERRAIN_LAYER|Player.OBSTACLE_LAYER)
		query.exclude = [player.get_rid()]
		var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty(): at = (hit.position as Vector3)-(at-head).normalized()*0.3
	if at.distance_to(target)<0.1: at += orbit.z*0.2
	player.camera.global_transform = Transform3D(Basis.IDENTITY, at).looking_at(target, up)
	player.camera.fov = Player.CAMERA_FOV

func _seat_camera(delta: float) -> void:
	var view: SpaceShipView = world.ship_views[_ship.id]
	var pose := view.global_transform
	var anchors: Dictionary = view.hull.anchors
	var want: Transform3D
	if seat!="pilot" and _seat_interior:
		var spec := world.seat_spec(_ship.slot, seat)
		if not spec.is_empty():
			var basis := Basis(Vector3.UP, player.camera_yaw)*Basis(Vector3.RIGHT, look_pitch)
			if seat.begins_with("turret"):
				var base := PI*0.5 if seat=="turret_left" else -PI*0.5 if seat=="turret_right" else 0.0
				basis = Basis(Vector3.UP, base+_turret_yaw)*Basis(Vector3.RIGHT, _turret_pitch)
			player.camera.global_transform = Transform3D(basis, (spec.pos as Vector3)+Vector3.UP*1.45)
			player.camera.fov = 78.0
			return
	match seat:
		"pilot":
			if _cockpit:
				# First person at the helm in the room: the bridge window is a live view.
				var helm := world.seat_spec(_ship.slot, "pilot")
				if helm.is_empty(): return  # Seat anchors may still be loading after a world handoff.
				player.camera.global_transform = Transform3D(Basis(Vector3.UP, _pilot_look.x)*Basis(Vector3.RIGHT, _pilot_look.y), (helm.pos as Vector3)+Vector3.UP*1.45)
				player.camera.fov = 78.0
				player.model.visible = false
				_chase = Transform3D.IDENTITY
				return
			else:
				var offset: Vector3 = anchors.get("chase", Vector3(0, 9, 34))
				var orbit := pose.basis*Basis(Vector3.UP, _pilot_look.x)*Basis(Vector3.RIGHT, _pilot_look.y)
				var at := pose.origin+orbit*offset
				want = Transform3D(Basis.IDENTITY, at).looking_at(pose.origin-pose.basis.z*15.0, pose.basis.y)
			player.camera.fov = 72.0 if not _cockpit else 80.0
		"turret_top", "turret_left", "turret_right":
			var dir := _turret_direction()
			# Inside the cannon's glass dome, just above its turning barrels.
			var eye := view.turret_pivot(seat)+pose.basis.y*0.85
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
	var mouse := player.get_viewport().get_visible_rect().size*Vector2(0.5, 0.42 if view_mode()==CameraMode.SHOULDER and not world.first_person_at(player.global_position) else 0.5) if free_look() else player.get_viewport().get_mouse_position()
	var origin := player.camera.project_ray_origin(mouse)
	var direction := player.camera.project_ray_normal(mouse)
	if not free_look():
		var on_cap: Variant = _cap_aim(origin, direction)
		if on_cap is Vector3: return on_cap
	var query := PhysicsRayQueryParameters3D.create(origin, origin+direction*300, Player.TERRAIN_LAYER|Player.OBSTACLE_LAYER|Player.ENEMY_LAYER)
	query.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty(): return hit.position
	if free_look(): return origin+direction*300.0
	var plane := Plane(player.up_direction, player.global_position+player.up_direction)
	var crossing: Variant = plane.intersects_ray(origin, direction)
	return crossing if crossing is Vector3 else player.global_position-player.global_basis.z*20

## On a planet's top, like the realm on voxel hills: where the cursor's ray
## comes down to shot height over the ground there, so the arrow passes right
## under the cursor whatever the hills do (or null off the caps).
func _cap_aim(origin: Vector3, direction: Vector3) -> Variant:
	if direction.y>-0.05: return null
	var cap := SpaceLayout.cap_planet(player.global_position.x, player.global_position.z)
	if cap.is_empty(): return null
	var c: Vector3 = cap.center
	var top := c.y+float(cap.radius)+SpaceLayout.max_height(cap)+Player.SHOT_HEIGHT
	# Start where the ray enters the band the hills can reach.
	var t := maxf(0.0, (origin.y-top)/-direction.y)
	var step := 0.6
	var above := func(at: float) -> float:
		var q := origin+direction*at
		var p := SpaceLayout.cap_planet(q.x, q.z)
		if p.is_empty(): return INF
		return q.y-(SpaceLayout.cap_height(p, q.x, q.z)+Player.SHOT_HEIGHT)
	var last := t
	while t<last+400.0:
		var h: float = above.call(t)
		if h==INF: return null
		if h<=0.0:
			var lo := maxf(t-step, 0.0)
			var hi := t
			for i in 8:
				var mid := (lo+hi)*0.5
				if float(above.call(mid))>0.0: lo = mid
				else: hi = mid
			return origin+direction*hi
		t += step
	return null

func aim_ray() -> Array:
	var target := player._aim_point
	var origin := player.global_position+player.up_direction
	# On a planet, like in the realm: shots fly at shot height over the ground at
	# the target, so they follow the hills instead of diving into them.
	var cap := SpaceLayout.cap_planet(target.x, target.z)
	if not cap.is_empty() and not free_look():
		target.y = SpaceLayout.cap_height(cap, target.x, target.z)+Player.SHOT_HEIGHT
		origin = player.global_position+player.up_direction*Player.SHOT_HEIGHT
		var flat := Vector2(target.x-origin.x, target.z-origin.z)
		if flat.length()<1.0: target = origin-player.global_basis.z*4.0
	if first_person>0.8:
		var eye := player.camera.global_position
		origin = eye+player.camera.global_basis*Vector3(0.36, -0.2, -0.45)
	var direction := (target-origin).normalized()
	if direction.is_zero_approx(): direction = -player.camera.global_basis.z
	return [origin, direction]

# --- Cinematics -------------------------------------------------------------------------

## Orin's shuttle to the Surface: launch, covered loading, then arrival.
## The ship dives for the Surface (SpaceWorld "descend"): a stand-in hull
## takes the plunge while the shared ship state travels through the loading screen.
func descend(_ship_id: int, surface: String) -> void:
	if cinematic: return
	cinematic = true
	player.cinematic_locked = true
	# Keep each occupant's interior view as the actual hull boosts down.
	# The windows follow its replicated pose; no cut to an outside camera.
	await get_tree().create_timer(3.0).timeout
	if not is_instance_valid(world): return
	cinematic = false
	player.cinematic_locked = false
	var game := world.game_root()
	game.set_port_arrival("descend")
	game.travel(surface)

## Up from the Surface: watch the ship climb out of the air, then take the helm.
func rise() -> void:
	var ship := world.ship_of(player.player_id)
	var view: Node3D = world.ship_views.get(ship.id) if ship else null
	if not is_instance_valid(view): return
	cinematic = true
	player.cinematic_locked = true
	_hide_hud(true)
	var hull := ShipHull.new()
	world.add_child(hull)
	hull.build(ship.tint)
	hull.global_transform = view.global_transform
	hull.set_engine(1.8)
	view.visible = false
	var shots := SpaceCinematic.new()
	add_child(shots)
	await shots.space_rise(player.camera, hull, "Space")
	shots.queue_free()
	hull.queue_free()
	if is_instance_valid(view): view.visible = true
	cinematic = false
	player.cinematic_locked = false
	_hide_hud(false)
	notice("Fly to the Nexus above, or anywhere you like. Low over the Surface, X takes you back down.")

func fly_rocket_surface() -> void:
	if cinematic or _rocket_flight: return
	var game := world.game_root()
	if game==null or not game.has_method("travel"): return
	var destination := world.surface_realm()
	var rocket := world.rocket_node()
	if rocket==null:
		game.travel(destination, Vector3.INF, true)
		return
	_rocket_flight = true
	cinematic = true
	player.cinematic_locked = true
	player.model.visible = false
	_hide_hud(true)
	var start := rocket.global_transform
	var shots := SpaceCinematic.new()
	add_child(shots)
	await shots.rocket_launch(player.camera, rocket, "To the Surface")
	# Keep the departure camera fixed until loading covers the source scene.
	await game.transition.fade_to_black(0.25)
	rocket.global_transform = start
	rocket.set_flame(0.0)
	shots.queue_free()
	world.request(["rocket_surface"])
	await game.travel(destination, Vector3.INF, true)
	# Successful travel destroys this controller. Only a refused trip gets here.
	cinematic = false
	player.cinematic_locked = false
	_rocket_flight = false
	_hide_hud(false)

## The private Space Travels tutorial uses a separate camera so the crew's
## actual view and position are restored exactly after the story shot.
func tutorial_cinematic(kind: String, ship_id: int, foe_id: int) -> void:
	if cinematic or not is_instance_valid(world) or not is_inside_tree(): return
	if not world.ships.has(ship_id): return
	cinematic = true
	player.cinematic_locked = true
	_hide_hud(true)
	var previous := get_viewport().get_camera_3d()
	var camera := Camera3D.new()
	camera.far = player.camera.far
	camera.fov = player.camera.fov
	camera.environment = player.camera.environment
	add_child(camera)
	camera.global_transform = player.camera.global_transform
	camera.make_current()
	var shots := SpaceCinematic.new()
	add_child(shots)
	if kind=="ambush":
		await shots.tutorial_ambush(camera, world, ship_id, foe_id)
	elif kind=="repair":
		await shots.tutorial_repairs(camera, world, ship_id)
	if not is_inside_tree(): return
	shots.queue_free()
	camera.queue_free()
	if is_instance_valid(previous): previous.make_current()
	else: player.camera.make_current()
	_hide_hud(false)
	player.cinematic_locked = false
	cinematic = false

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
	var game := world.game_root()
	var hud: Variant = game.get("hud") if game else null
	if hud is CanvasLayer: (hud as CanvasLayer).visible = not hidden
	_overlay.visible = not hidden

func _exit_tree() -> void:
	player.set_meta("jetpack_attached",false)
	player.set_meta("jetpack_flying",false)
	player.set_meta("jet_on",false)
	Input.mouse_mode = _old_mouse
	if _outside_culled and is_instance_valid(world):
		_outside_culled = false
		for node: Variant in world.planets.values()+world.ship_views.values()+[world.station, world.foes]:
			if is_instance_valid(node) and node is Node3D: (node as Node3D).visible = true
	for mark: Variant in _port_marks.values()+[_nexus_mark, _landing_prompt]:
		if is_instance_valid(mark): (mark as Node).queue_free()
	var game := world.game_root() if is_instance_valid(world) else null
	var hud: Variant = game.get("hud") if game else null
	if hud:
		hud.key_help.set_rows([])
		hud.toasts.unpin("landing_queue")
		hud.throttle.hide()
	if is_instance_valid(_fp_shield): _fp_shield.queue_free()
	if not is_instance_valid(player): return
	player.cinematic_locked = false
	player.global_basis = Basis.IDENTITY
	player.up_direction = Vector3.UP
	player.safe_margin = _old_safe_margin
	player.floor_snap_length = Player.STEP_HEIGHT
	player.floor_constant_speed = false
	player.floor_max_angle = deg_to_rad(45.0)
	player.model.visible = true
	player.status_visuals.visible = true
	player.aura.visible = true
	player.camera.environment = _prior_env
	player.camera.far = _old_far
	player.camera.cull_mask = _old_cull_mask
	player.camera.fov = Player.CAMERA_FOV
	player._visual_offset = 0.0
	player.model.position.y = 0.0
