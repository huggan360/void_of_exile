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
var _ship_panel: Control
var _ship_info: Label
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
var _chase := Transform3D.IDENTITY
var _cockpit := true
var _rocket_flight := false
var _pulse := false
## Out on a spacewalk (jetpack in open space), and the line clipped to a ship.
var spacewalk := false
## Open space is only for those who went out on purpose (airlock, a lost
## ship); anyone else who drops off the deck or a planet is put back.
var _out_on_purpose := false
var _safety_line := false  # out through the airlock: clip on there first thing
var _last_zone := ""
var fuel := 100.0
var _fuel_rest := 0.0
var _jet := Vector3.ZERO
## Clipped to a ship's hull: {ship (id), anchor (hull space, on the hull), at
## (hull space, you), rope/prev: the line's points (hull space, a real rope:
## slack, taut, wrapping round the hull)}.
var tether := {}
## Standing on a ship's deck in magnetic boots: {ship, at (hull space)}. The
## boots hold you to her whether or not your line is clipped on.
var boots := {}
var deck := false
## How much line is paid out (zoom in reels it in, zoom out lets it out).
var rope_length := 10.0
var _rope: MeshInstance3D
var _rope_mesh := ImmediateMesh.new()
const ROPE_MIN := 2.0
const ROPE_MAX := 40.0
const REEL_SPEED := 6.0  # m/s the winch pulls you in
## Brass cleats on the hull a line clips to (hull space): the airlock ring,
## the deck rails along both sides, the stern.
const CLIP_REACH := 4.0  # close enough to the hull to move the clip there
const ROPE_POINTS := 26
const JET_ACCEL := 14.0
const JET_MAX := 12.0
const FUEL_DRAIN := 16.0
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
		_pilot_look = Vector2.ZERO
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
	_ship_panel.visible = _ship!=null
	if _ship:
		var place := SpaceLayout.region_name(SpaceLayout.region_at(_ship.xform.origin))
		_ship_info.text = "%s  -  %s\nHull %d / %d%s\n%s  -  %d m/s%s" % [_ship.name, _seat_title(seat), _ship.hp, SpaceShip.MAX_HP,
			"  -  CRIPPLED" if _ship.broken else "", place if _ship.mode=="flying" else _ship.mode.capitalize(), roundi(_ship.speed),
			"  -  PULSE DRIVE" if _ship.pulse else ""]
		if _ship.turned_back: _notice_edge()
		_ship_info.add_theme_color_override("font_color", UIStyle.HP_LIGHT if _ship.hp<SpaceShip.MAX_HP/3 or _ship.broken else UIStyle.TEXT)
	_update_bars(zone)
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
	if aboard:
		hud.bar_override = {hp = [aboard.hp, SpaceShip.MAX_HP, "", SHIP_HULL, SHIP_HULL_LIGHT, "ship"],
			mp = [aboard.boost, 100.0, "", SHIP_BOOST, SHIP_BOOST_LIGHT, "flame"]}
	elif spacewalk:
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

func _seat_title(id: String) -> String:
	return SpaceInteraction.SEAT_TITLES.get(id, "Aboard")

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
				rows.append([["@ship_launch"], "Launch"])
			elif _ship.mode=="flying":
				rows.append([["@ship_forward", "@ship_reverse"], "Thrust"])
				rows.append([["@ship_left", "@ship_right"], "Turn"])
				rows.append([["@ship_pitch_up", "@ship_pitch_down"], "Pitch"])
				rows.append([["@ship_roll_left", "@ship_roll_right"], "Roll"])
				rows.append([["@ship_boost"], "Boost"])
				rows.append([["@ship_pulse"], "Pulse drive"])
				rows.append([["@ship_fire"], "Fire cannons"])
				var land := _ship.landable()
				if not land.is_empty(): rows.append([["@ship_land"], "Land"])
				elif SpaceLayout.can_descend(_ship.xform.origin): rows.append([["@ship_land"], "Descend"])
				elif _ship.xform.origin.distance_to(SpaceLayout.NEXUS)<SpaceWorld.DOCK_RANGE: rows.append([["@ship_land"], "Dock"])
		"turret_top", "turret_left", "turret_right":
			if _ship!=null and _ship.mode=="flying":
				rows.append([["Mouse"], "Aim"])
				rows.append([["@ship_fire"], "Fire"])
		"chair_0", "chair_1", "chair_2", "chair_3":
			rows.append([["@interact"], "Drink"])
			rows.append([["C"], "Cigar"])
	if seat!="":
		rows.append([["@seat_camera"], "Change camera"])
		rows.append([["@seat_stand"], "Stand up"])
	elif spacewalk:
		if deck: rows.append([["Space"], "Jump off"])
		else:
			rows.append([["Space"], "Jetpack"])
			rows.append([["Ctrl"], "Brake"])
		rows.append([["@interact"], "Unhook" if not tether.is_empty() else "Clip on"])
		if not tether.is_empty(): rows.append([["@zoom_in", "@zoom_out"], "Reel"])
	if city_seat!="":
		rows.append([["@interact"], "Sip"])
		rows.append([["C"], "Order"])
		rows.append([["Z"], "Stand up"])
	if _lift>=0: rows.append([["@interact"], "Press button"])
	_hint.text = ""
	var game := world.game_root()
	var hud: Variant = game.get("hud") if game else null
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
				"airlock_out", "adrift": _out_on_purpose = true
			if str(event[1])=="airlock_out": _safety_line = true
			match str(event[1]):
				"airlock_out": notice("Out on the hull, your line clipped by the airlock. X unhooks it.")
				"airlock_in": notice("Back inside. The airlock hisses shut.")
				"adrift": notice("Your ship is gone! You float on your jetpack. Another crew can pick you up, or press R to call Orin's rescue skiff.")
				"planet": pass

func _flash_fade() -> void:
	_fade.color.a = 1.0
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, 0.6)

func hide_overlay() -> void:
	if is_instance_valid(_overlay): _overlay.hide()
	var game := world.game_root() if is_instance_valid(world) else null
	var hud: Variant = game.get("hud") if game else null
	if hud: hud.key_help.set_rows([])
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func toggle_map() -> void:
	map.visible = not map.visible

# --- Input ------------------------------------------------------------------------------

func active_ship_actions() -> Array[String]:
	var actions: Array[String] = []
	if seat=="": return actions
	actions.assign(["seat_camera", "seat_stand"])
	if seat=="pilot" and _ship!=null:
		if _ship.mode in ["berth", "landed"]: actions.append("ship_launch")
		elif _ship.mode=="flying":
			actions.append_array(["ship_forward", "ship_reverse", "ship_left", "ship_right", "ship_pitch_up", "ship_pitch_down", "ship_roll_left", "ship_roll_right", "ship_boost", "ship_pulse", "ship_land", "ship_fire"])
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
	if event is InputEventMouseMotion and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
		var motion: Vector2 = event.relative*MOUSE_SENSITIVITY
		match seat:
			"pilot":
				_pilot_look.x -= motion.x
				_pilot_look.y = clampf(_pilot_look.y-motion.y, -1.2, 1.2)
			"turret_top", "turret_left", "turret_right":
				_turret_yaw -= motion.x
				_turret_pitch = clampf(_turret_pitch-motion.y, -0.35, 1.25)
			_:
				player.camera_yaw -= motion.x
				look_pitch = clampf(look_pitch-motion.y, -1.35, 1.35)
		get_viewport().set_input_as_handled()
		return
	if not (event is InputEventKey or event is InputEventMouseButton) or not event.is_pressed(): return
	if event is InputEventKey and event.echo: return
	if seat!="" and event.is_action_pressed("seat_camera"):
		map.hide()
		if seat=="pilot": _cockpit = not _cockpit
		else: _seat_interior = not _seat_interior
		_chase = Transform3D.IDENTITY
		get_viewport().set_input_as_handled()
		return
	if seat!="" and event.is_action_pressed("seat_stand"):
		world.request(["stand"])
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.physical_keycode==KEY_V and seat=="":
		if _lift>=0: notice("The elevator uses first person. Your camera returns when you step out.")
		else:
			camera_mode = (camera_mode+1) % 3
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
	if seat.begins_with("chair"):
		if event.is_action_pressed("interact"): world.request(["drink"])
		elif event is InputEventKey and event.physical_keycode==KEY_C: world.request(["cigar"])
		else: return
		get_viewport().set_input_as_handled()
		return
	if spacewalk and event.is_action_pressed("interact") and not _interaction_near():
		_toggle_tether()
		get_viewport().set_input_as_handled()
		return
	if seat=="pilot" and _ship!=null:
		if event.is_action_pressed("ship_launch") and _ship.mode in ["berth", "landed"]:
			world.request(["takeoff"])
		elif _ship.mode=="flying" and event.is_action_pressed("ship_pulse"):
			_pulse = not _pulse
			notice("Pulse drive engaged." if _pulse else "Pulse drive off.")
		elif _ship.mode=="flying" and event.is_action_pressed("ship_land"):
			if SpaceLayout.can_descend(_ship.xform.origin): world.request(["descend"])
			else: world.request(["land"] if not _ship.landable().is_empty() else ["dock"])
		elif not consumes_event(event): return
		get_viewport().set_input_as_handled()

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
	return camera_mode!=CameraMode.ANGLED or world.first_person_at(player.global_position)

func _interaction_near() -> bool:
	var game := world.game_root()
	var hud: Variant = game.get("hud") if game else null
	return hud!=null and hud.interaction.target!=null

## X on a spacewalk: clip the line onto the hull of a ship in reach, at the
## point nearest you. On the line: close to the hull, move the clip there;
## else unhook.
func _toggle_tether() -> void:
	if not tether.is_empty():
		var view: Node3D = world.ship_views.get(int(tether.ship))
		if view:
			var local := view.global_transform.affine_inverse()*player.global_position
			var spot := ShipHull.surface_point(local)
			if spot.distance_to(local)<CLIP_REACH and spot.distance_to(tether.anchor)>2.0:
				_clip(int(tether.ship), spot, local)
				notice("Line clipped on here.")
				return
		tether = {}
		notice("Line unhooked. Careful out there.")
		return
	for ship: SpaceShip in world.ships.values():
		var view: SpaceShipView = world.ship_views.get(ship.id)
		if view==null: continue
		var local := view.global_transform.affine_inverse()*player.global_position
		var spot := ShipHull.surface_point(local)
		if spot.distance_to(local)<12.0:
			_clip(ship.id, spot, local)
			notice("Line clipped to %s. Zoom in and out to reel it." % ship.name)
			return
	notice("Get closer to a ship's hull to clip your line on.")

## The airlock you just came out of (the server put you there by her true
## pose, so the ship is the one whose airlock is nearest): clip on right by it,
## before she flies on without you.
func _clip_at_airlock() -> void:
	var best: SpaceShip = null
	for ship: SpaceShip in world.ships.values():
		if not world.ship_views.has(ship.id): continue
		if best==null or (ship.xform*SpaceWorld.AIRLOCK_OUTSIDE).distance_to(player.global_position)<(best.xform*SpaceWorld.AIRLOCK_OUTSIDE).distance_to(player.global_position):
			best = ship
	if best==null or (best.xform*SpaceWorld.AIRLOCK_OUTSIDE).distance_to(player.global_position)>120.0: return
	_clip(best.id, ShipHull.surface_point(SpaceWorld.AIRLOCK_OUTSIDE), SpaceWorld.AIRLOCK_OUTSIDE)
	player.global_position = _hull(best.id)*SpaceWorld.AIRLOCK_OUTSIDE

## A fresh line from `anchor` (on the hull) to `at`, both hull space.
func _clip(ship_id: int, anchor: Vector3, at: Vector3) -> void:
	rope_length = clampf(anchor.distance_to(at)+1.5, ROPE_MIN+1.0, ROPE_MAX)
	var points: Array[Vector3] = []
	for k in ROPE_POINTS: points.append(anchor.lerp(at, float(k)/(ROPE_POINTS-1)))
	tether = {ship = ship_id, anchor = anchor, at = at, rope = points, prev = points.duplicate()}

## Steps the line (verlet, hull space): the clip holds, the points drift and
## keep their spacing, never pass through the hull, and a taut line pulls you
## back. Returns where you can be with `want` as your aim.
func _simulate_rope(want: Vector3) -> Vector3:
	var points: Array = tether.rope
	var prev: Array = tether.prev
	var n := points.size()
	var spacing := rope_length/(n-1)
	points[0] = tether.anchor
	points[n-1] = want
	for i in range(1, n-1):
		var step: Vector3 = ((points[i] as Vector3)-(prev[i] as Vector3))*0.94
		prev[i] = points[i]
		points[i] = (points[i] as Vector3)+step
	prev[n-1] = want
	for iteration in 18:
		for i in n-1:
			var a: Vector3 = points[i]
			var b: Vector3 = points[i+1]
			var d := b-a
			var length := d.length()
			if length<=spacing: continue  # a line goes slack, it never pushes
			var wa := 0.0 if i==0 else 1.0
			var wb := 0.55 if i+1==n-1 else 1.0  # you are heavier than the line
			var fix := d*(1.0-spacing/length)/(wa+wb)
			points[i] = a+fix*wa
			points[i+1] = b-fix*wb
		for i in range(1, n):
			var hit: Array = ShipHull.inside(points[i])
			if float(hit[0])>0.0: points[i] = (points[i] as Vector3)+(hit[1] as Vector3)*(float(hit[0])+0.08)
	return points[n-1]

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
			_input_timer -= delta
			if _input_timer<=0.0:
				_input_timer = INPUT_RATE
				var thrust := Input.get_axis("ship_reverse", "ship_forward") if enabled else 0.0
				var yaw := Input.get_axis("ship_left", "ship_right") if enabled else 0.0
				if enabled and player.debug_input!=Vector2.ZERO:
					thrust = -player.debug_input.y
					yaw = player.debug_input.x
				var pitch := Input.get_axis("ship_pitch_down", "ship_pitch_up") if enabled else 0.0
				var roll := Input.get_axis("ship_roll_left", "ship_roll_right") if enabled else 0.0
				world.request(["pilot", [thrust, yaw, pitch, roll, enabled and Input.is_action_pressed("ship_boost"), enabled and _pulse]])
			_fire_timer -= delta
			if enabled and Input.is_action_pressed("ship_fire") and _fire_timer<=0.0 and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
				_fire_timer = 0.2
				world.request(["fire", _pilot_direction()])
		"turret_top", "turret_left", "turret_right":
			var dir := _turret_direction()
			_aim_timer -= delta
			if _aim_timer<=0.0:
				_aim_timer = AIM_RATE
				world.request(["aim", dir])
			_fire_timer -= delta
			if _ship.mode=="flying" and Input.is_action_pressed("ship_fire") and _fire_timer<=0.0 and not player.controls_locked() and not player.ui_blocked and not player.interacting() and not map.visible and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED:
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
	# From a ship room straight into open space is the airlock or a lost ship.
	if state.zone=="void" and _last_zone=="ship": _out_on_purpose = true
	if state.zone!="void": _out_on_purpose = false
	_last_zone = str(state.zone)
	spacewalk = state.zone=="void" and _out_on_purpose
	if spacewalk and _safety_line:
		_safety_line = false
		_clip_at_airlock()
	if spacewalk:
		_spacewalk(delta)
		return
	_jet = Vector3.ZERO
	tether = {}
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
	var aboard: bool = state.zone=="ship" or state.zone=="planet:"+CityLayout.ID
	if not aboard: player._update_magic(delta)
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
	player.move_and_slide()
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

# --- Spacewalk ----------------------------------------------------------------------------

## Zero-g on the jetpack: hold Space to fire it along the view (WASD steers
## the burst, Shift harder), Ctrl brakes, let go and you drift. Fuel drains
## while firing and refills quickly. Clipped to a ship you move in its frame
## and ride along within the line's length; over the deck the boots hold you
## and you walk on it like on any floor.
func _spacewalk(delta: float) -> void:
	player._cancel_weapon_actions()
	player.up_direction = Vector3.UP
	var input := Vector2.ZERO if player.controls_locked() else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if player.debug_input!=Vector2.ZERO: input = player.debug_input
	var firing := not player.controls_locked() and Input.is_key_pressed(KEY_SPACE) and fuel>0.5
	var braking := not player.controls_locked() and Input.is_key_pressed(KEY_CTRL)
	var fast := Input.is_key_pressed(KEY_SHIFT)
	var view := player.camera.global_basis
	if not tether.is_empty() and world.ship_views.get(int(tether.ship))==null:
		tether = {}
		notice("Your line went slack: the ship is gone.")
	if not boots.is_empty() and world.ship_views.get(int(boots.ship))==null: boots = {}
	# Reel the line with the zoom keys.
	if not tether.is_empty() and not player.controls_locked():
		var reel := Input.get_axis("zoom_in", "zoom_out")
		if absf(reel)>0.01: rope_length = clampf(rope_length+reel*REEL_SPEED*delta, ROPE_MIN, ROPE_MAX)
	# Magnetic boots: touching a deck (ours or any ship's) holds you to it.
	if boots.is_empty() and not firing:
		for ship: SpaceShip in world.ships.values():
			var v: SpaceShipView = world.ship_views.get(ship.id)
			if v==null: continue
			var local := v.global_transform.affine_inverse()*player.global_position
			if _on_deck(local):
				boots = {ship = ship.id, at = local}
				notice("Magnetic boots: you walk her deck.")
				break
	if firing and not boots.is_empty():
		# Kicking off: carry on in the ship's frame on the line, or float free.
		if not tether.is_empty() and int(tether.ship)==int(boots.ship): tether.at = boots.at
		boots = {}
	if not boots.is_empty():
		var hull: Transform3D = _hull(int(boots.ship))
		deck = true
		_jet = Vector3.ZERO
		var forward := (hull.basis.inverse()*-view.z)*Vector3(1, 0, 1)
		var right := (hull.basis.inverse()*view.x)*Vector3(1, 0, 1)
		var step := (right.normalized()*input.x-forward.normalized()*input.y)*Player.BASE_SPEED*delta
		var at: Vector3 = (boots.at as Vector3)+step
		at.y = ShipHull.DECK_Y+0.14
		var half := ShipHull.beam(at.z)-0.6
		at.x = clampf(at.x, -half, half)
		at.z = clampf(at.z, -17.5, 13.0)
		if not tether.is_empty() and int(tether.ship)==int(boots.ship):
			at = _simulate_rope(at)
			at.y = ShipHull.DECK_Y+0.14
			tether.at = at
		boots.at = at
		player.global_position = hull*at
		player.global_basis = hull.basis
		if step.length()>0.001: player.model.rotation.y = atan2(-step.x, -step.z)
		_update_rope(hull)
		player.set_meta("jet_on", false)
		fuel = minf(100.0, fuel+FUEL_REGEN*delta)
		return
	deck = false
	player.global_basis = player.global_basis.slerp(Basis.IDENTITY, 1.0-exp(-delta*4.0)).orthonormalized()
	if firing:
		var aim := -view.z
		if input.length()>0.1: aim = (view.x*input.x+view.z*input.y).normalized()
		_jet += aim*JET_ACCEL*(1.6 if fast else 1.0)*delta
		fuel = maxf(0.0, fuel-FUEL_DRAIN*(1.8 if fast else 1.0)*delta)
		_fuel_rest = 0.5
	else:
		_fuel_rest -= delta
		if _fuel_rest<=0.0: fuel = minf(100.0, fuel+FUEL_REGEN*delta)
	if braking: _jet = _jet.move_toward(Vector3.ZERO, JET_ACCEL*1.5*delta)
	_jet *= exp(-0.35*delta)
	_jet = _jet.limit_length(JET_MAX*(1.7 if fast else 1.0))
	player.set_meta("jet_on", firing)
	if not tether.is_empty():
		# On the line you live in the ship's frame: she tows you wherever she goes.
		var hull: Transform3D = _hull(int(tether.ship))
		var want: Vector3 = (tether.at as Vector3)+hull.basis.inverse()*_jet*delta
		var at := _simulate_rope(want)
		var pulled := at-want
		if pulled.length()>0.001:
			# Taut: the line takes away whatever pulls against it.
			var back := (hull.basis*pulled).normalized()
			var against := _jet.dot(back)
			if against<0.0: _jet -= back*against
		# You don't float through the hull either.
		var hit: Array = ShipHull.inside(at)
		if float(hit[0])>0.0: at += (hit[1] as Vector3)*(float(hit[0])+0.3)
		tether.at = at
		player.global_position = hull*at
		_update_rope(hull)
	else:
		player.global_position += _jet*delta
		_rope.visible = false
	player.velocity = Vector3.ZERO
	if _jet.length()>0.4: player.model.rotation.y = lerp_angle(player.model.rotation.y, atan2(-_jet.x, -_jet.z), 1.0-exp(-delta*6.0))

## Where a ship's hull is this very frame (its view's pose, not last
## physics tick's transform: at full speed that is metres apart).
func _hull(ship_id: int) -> Transform3D:
	var view: SpaceShipView = world.ship_views.get(ship_id)
	return view.pose() if view else Transform3D.IDENTITY

## Every rendered frame, booted or roped: stay where you are in her frame, so
## she never slides past you between physics ticks.
func _pin_to_hull() -> void:
	if not spacewalk: return
	if not boots.is_empty() and world.ship_views.has(int(boots.ship)):
		var hull := _hull(int(boots.ship))
		player.global_position = hull*(boots.at as Vector3)
		player.global_basis = hull.basis
		_update_rope(hull)
	elif not tether.is_empty() and world.ship_views.has(int(tether.ship)):
		var hull := _hull(int(tether.ship))
		player.global_position = hull*(tether.at as Vector3)
		_update_rope(hull)

## The line from the hull to your belt, through its simulated points.
func _update_rope(hull: Transform3D) -> void:
	if tether.is_empty() or not world.ship_views.has(int(tether.ship)):
		_rope.visible = false
		return
	var points: Array[Vector3] = []
	for p: Vector3 in tether.rope: points.append(hull*p)
	points[points.size()-1] = player.global_position+player.global_basis.y*0.95
	_draw_rope(points)

## Over the main deck and low enough for the boots to hold (hull space).
func _on_deck(at: Vector3) -> bool:
	return at.z> -17.5 and at.z<13.0 and absf(at.x)<ShipHull.beam(at.z)-0.3 and at.y>ShipHull.DECK_Y-0.5 and at.y<ShipHull.DECK_Y+1.6

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
	var in_chair := seat.begins_with("chair") or city_seat!=""
	var want_fp := _cockpit if seat=="pilot" else _seat_interior if seat!="" else camera_mode==CameraMode.FIRST_PERSON or world.first_person_at(player.global_position)
	first_person = move_toward(first_person, 1.0 if want_fp else 0.0, delta/0.25)
	var shoulder := camera_mode==CameraMode.SHOULDER and not want_fp
	var allow_capture := (want_fp or shoulder or spacewalk or seat!="") and not player.controls_locked() \
		and not player.ui_blocked and not player.interacting() and not map.visible and not cinematic
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if allow_capture else Input.MOUSE_MODE_VISIBLE
	var sight := _crosshair as SpaceCrosshair
	sight.mode = ""
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
	if cinematic: return
	if seat!="" and not seat.begins_with("chair") and _ship!=null and world.ship_views.has(_ship.id):
		_seat_camera(delta)
		_shake_camera()
		return
	var up := player.global_basis.y
	var orbit := player.global_basis*Basis(Vector3.UP, player.camera_yaw)
	var head := player.global_position+up*(1.15 if in_chair else 1.57)
	var view := orbit*Basis(Vector3.RIGHT, look_pitch)
	if want_fp or shoulder or (spacewalk and camera_mode==CameraMode.ANGLED):
		var at := head
		if not want_fp:
			at += view*Vector3(0.65, 0.25, 3.4 if shoulder else 6.5)
			var ray := PhysicsRayQueryParameters3D.create(head, at, Player.TERRAIN_LAYER|Player.OBSTACLE_LAYER)
			ray.exclude = [player.get_rid()]
			var hit := player.get_world_3d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty(): at = (hit.position as Vector3)-(at-head).normalized()*0.25
			player.model.visible = alive and at.distance_to(head)>0.65
		player.camera.global_transform = Transform3D(view, at)
		player.camera.fov = 78.0 if want_fp else 72.0
		_shake_camera()
		return
	var target := player.global_position+up
	var pitch := Player.OVERHEAD_PITCH if AppSettings.video.get("camera_angle", "standard")=="overhead" else Player.CAMERA_PITCH
	var at := target+orbit*Vector3(0, sin(pitch), cos(pitch))*player.camera_distance
	# City rooms have solid ceilings; pull the angled camera inside when needed.
	if world.zone_at(player.global_position)=="planet:"+CityLayout.ID:
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
			# Just past the barrels: the gunner sees space, not the deck.
			var eye := view.muzzle(seat)+dir*3.0+pose.basis.y*0.9
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
	var mouse := player.get_viewport().get_visible_rect().size*0.5 if free_look() else player.get_viewport().get_mouse_position()
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

## Orin's rocket home: the camera watches the launch, then the usual travel.
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

func fly_rocket_home() -> void:
	if cinematic or _rocket_flight: return
	_rocket_flight = true
	var rocket := world.rocket_node()
	var game := world.game_root()
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
	var game := world.game_root()
	var hud: Variant = game.get("hud") if game else null
	if hud is CanvasLayer: (hud as CanvasLayer).visible = not hidden
	_overlay.visible = not hidden

func _exit_tree() -> void:
	Input.mouse_mode = _old_mouse
	if _outside_culled and is_instance_valid(world):
		_outside_culled = false
		for node: Variant in world.planets.values()+world.ship_views.values()+[world.station, world.foes]:
			if is_instance_valid(node) and node is Node3D: (node as Node3D).visible = true
	var game := world.game_root() if is_instance_valid(world) else null
	var hud: Variant = game.get("hud") if game else null
	if hud: hud.key_help.set_rows([])
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
