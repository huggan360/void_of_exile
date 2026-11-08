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
var _lift_height := 0.0
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
var _pulse := false
## Out on a spacewalk (jetpack in open space), and the line clipped to a ship.
var spacewalk := false
## Open space is only for those who went out on purpose (airlock, a lost
## ship); anyone else who drops off the deck or a planet is put back.
var _out_on_purpose := false
var _last_zone := ""
var fuel := 100.0
var _fuel_rest := 0.0
var _jet := Vector3.ZERO
var tether := {}  # {ship (id), anchor (hull space), at (hull space)}
## Standing on the ship's deck in magnetic boots (clipped on).
var deck := false
var _rope: MeshInstance3D
var _rope_mesh := ImmediateMesh.new()
const ROPE := 26.0
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
	_old_mouse = Input.mouse_mode
	camera_mode = int(AppSettings.video.get("space_camera", CameraMode.ANGLED))
	return self

func _ready() -> void:
	player.camera.far = 90000.0
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
	_rope = MeshInstance3D.new()
	_rope.mesh = _rope_mesh
	var cord := StandardMaterial3D.new()
	cord.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cord.albedo_color = Color("85efac")
	cord.emission_enabled = true
	cord.emission = Color("85efac")
	cord.emission_energy_multiplier = 1.6
	_rope.material_override = cord
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
	seat = _ship.seat_of(player.player_id) if _ship else ""
	if seat!=was and seat.begins_with("chair"):
		# Sitting down: look across the table, a little down at the glasses.
		player.camera_yaw = float(world.seat_spec(_ship.slot, seat).get("yaw", 0.0))
		look_pitch = -0.3
	_notice_time -= delta
	_notice.modulate.a = clampf(_notice_time, 0.0, 1.0)
	var zone := world.zone_at(player.global_position)
	_title.text = "" if zone=="ship" else world.region_at(player.global_position)
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
	if seat!="":
		_seated(delta)

## Aboard, the bars are the ship's hull and boost; on a spacewalk, your
## health and the jetpack.
func _update_bars(zone: String) -> void:
	var game := world.get_parent()
	var hud: Variant = game.get("hud") if game else null
	if hud==null: return
	var aboard: SpaceShip = _ship if _ship else world.ship_in_slot(SpaceLayout.pocket_at(player.global_position)) if zone=="ship" else null
	if aboard:
		hud.bar_override = {hp = [aboard.hp, SpaceShip.MAX_HP, "SHIP HULL", SHIP_HULL, SHIP_HULL_LIGHT],
			mp = [aboard.boost, 100.0, "SHIP BOOST", SHIP_BOOST, SHIP_BOOST_LIGHT]}
	elif spacewalk:
		hud.bar_override = {hp = [player.stats.hp, player.stats.max_hp, "HEALTH", UIStyle.HP, UIStyle.HP_LIGHT],
			mp = [fuel, 100.0, "JETPACK", JETPACK, JETPACK_LIGHT]}
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

func _update_hint() -> void:
	var lines: Array[String] = []
	match seat:
		"pilot":
			lines.append("W/S thrust - A/D turn - mouse steers - Q/E roll - Shift boost - C pulse drive - V first person")
			if _ship.mode in ["berth", "landed"]: lines.append("Press W to take off")
			var land := _ship.landable()
			if not land.is_empty(): lines.append("X: land on %s" % land.name)
			elif _ship.mode=="flying" and _ship.xform.origin.distance_to(SpaceLayout.NEXUS)<SpaceWorld.DOCK_RANGE: lines.append("X: dock at the Nexus")
			if _pulse and not SpaceShip.pulse_clear(_ship.xform.origin): lines.append("The pulse drive is quiet this close to worlds, rocks or the Nexus")
		"turret_top", "turret_left", "turret_right":
			lines.append("Mouse aims - left mouse fires")
		"map":
			lines.append("The star map is open")
		"chair_0", "chair_1", "chair_2", "chair_3":
			lines.append("X: drink - C: light a cigar")
	if seat!="": lines.append("Z: stand up")
	elif spacewalk:
		lines.append("WASD walk the deck - Space jetpack off" if deck else "Space fires the jetpack (WASD steers) - Ctrl brakes - Shift faster")
		lines.append("X: unhook the line" if not tether.is_empty() else "X near your ship: clip your line on")
	elif world.zone_at(player.global_position)=="ship":
		lines.append("X at a seat to sit - the airlock is on the port side, the hatch at the stern")
		var ship := world.ship_in_slot(SpaceLayout.pocket_at(player.global_position))
		if ship:
			var hurt: Array[String] = []
			for id: String in SpaceShip.PARTS:
				if ship.part(id)<1.0: hurt.append("%s %d%%" % [SpaceShip.PARTS[id].name, roundi(ship.part(id)*100.0)])
			if not hurt.is_empty(): lines.append("Damaged: "+", ".join(hurt))
	if city_seat!="": lines.append("X: sip - C: order another - Z: stand up")
	if _lift>=0:
		var button := _lift_button()
		lines.append("Look at a floor button and click or press X" if button<0 else "X / click: "+str(CityLayout.elevators()[_lift].floors[button].name))
	elif seat=="": lines.append("V: camera - "+["Angled", "Shoulder", "First person"][camera_mode])
	_hint.text = "\n".join(lines)

func _notice_edge() -> void:
	if _notice_time>1.0 and _notice.text.begins_with("The edge"): return
	notice("The edge of the Reach. The ship's charm turns her back toward the Nexus.")

## R in the Reach: a rescue call when stranded, otherwise a reminder.
func recall() -> void:
	if world.stranded(player.player_id, player.global_position): world.request(["rescue"])
	else: notice("There is no quick way home out here. Fly your ship back to the Nexus.")

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
			match str(event[1]):
				"airlock_out": notice("Out on the hull. Press X near the ship to clip your line on.")
				"airlock_in": notice("Back inside. The airlock hisses shut.")
				"adrift": notice("Your ship is gone! You float on your jetpack. Another crew can pick you up, or press R to call Orin's rescue skiff.")
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
	if player.ui_blocked or player.interacting() or map.visible: return
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
	if event is InputEventKey and (event as InputEventKey).physical_keycode==KEY_Z:
		if seat!="": world.request(["stand"])
		get_viewport().set_input_as_handled()
		return
	if seat.begins_with("chair"):
		if event.is_action_pressed("interact"):
			world.request(["drink"])
			get_viewport().set_input_as_handled()
		elif event is InputEventKey and (event as InputEventKey).physical_keycode==KEY_C:
			world.request(["cigar"])
			get_viewport().set_input_as_handled()
		return
	if spacewalk and event.is_action_pressed("interact") and not _interaction_near():
		_toggle_tether()
		get_viewport().set_input_as_handled()
		return
	if seat=="pilot":
		if event is InputEventKey and (event as InputEventKey).physical_keycode==KEY_C:
			_pulse = not _pulse
			notice("Pulse drive engaged. Hold W." if _pulse else "Pulse drive off.")
			get_viewport().set_input_as_handled()
		elif event is InputEventKey and (event as InputEventKey).physical_keycode==KEY_V:
			_cockpit = not _cockpit
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("interact"):
			world.request(["land"] if not _ship.landable().is_empty() else ["dock"])
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			_cockpit = (event as InputEventMouseButton).button_index==MOUSE_BUTTON_WHEEL_UP
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
	var game := world.get_parent()
	var hud: Variant = game.get("hud") if game else null
	return hud!=null and hud.interaction.target!=null

## Clip the line to the nearest ship of your crew in reach, or unhook it.
func _toggle_tether() -> void:
	if not tether.is_empty():
		tether = {}
		notice("Line unhooked. Careful out there.")
		return
	for ship: SpaceShip in world.ships.values():
		var view: SpaceShipView = world.ship_views.get(ship.id)
		if view==null: continue
		var local := view.global_transform.affine_inverse()*player.global_position
		if absf(local.x)<16.0 and absf(local.y)<14.0 and absf(local.z)<36.0:
			var anchor := Vector3(clampf(local.x, -9.0, 9.0), clampf(local.y, -5.0, 3.3), clampf(local.z, -26.0, 21.0))
			tether = {ship = ship.id, anchor = anchor, at = local}
			notice("Line clipped to %s. You ride along with her now." % ship.name)
			return
	notice("No ship close enough to clip your line to.")

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
				world.request(["pilot", [thrust, clampf(yaw, -1.0, 1.0), clampf(-_mouse.y, -1.0, 1.0), roll, Input.is_key_pressed(KEY_SHIFT), _pulse]])
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
		update_camera(delta)
		return
	# The floor displacement is evaluated from the same server clock as its
	# visible car, before movement. Menu users ride along too.
	if _lift>=0:
		var tower := CityLayout.tower_world(CityLayout.elevators()[_lift])
		var local := tower.affine_inverse()*player.global_position-CityState.SHAFT
		if absf(local.x)<CityState.CAR.x*0.5+0.3 and absf(local.z)<CityState.CAR.z*0.5+0.3 and absf(local.y-_lift_height)<3.0:
			player.global_position += tower.basis.y*(float(world.city.car_state(_lift)[0])-_lift_height)
	_lift = world.city.car_at(player.global_position)
	if _lift>=0: _lift_height = float(world.city.car_state(_lift)[0])
	if cinematic or seat!="":
		player.velocity = Vector3.ZERO
		update_camera(delta)
		return
	var state := world.sample_gravity(player.global_position)
	# From a ship room straight into open space is the airlock or a lost ship.
	if state.zone=="void" and _last_zone=="ship": _out_on_purpose = true
	if state.zone!="void": _out_on_purpose = false
	_last_zone = str(state.zone)
	spacewalk = state.zone=="void" and _out_on_purpose
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
	update_camera(delta)
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
	var firing := not player.controls_locked() and Input.is_key_pressed(KEY_SPACE) and fuel>0.5
	var braking := not player.controls_locked() and Input.is_key_pressed(KEY_CTRL)
	var fast := Input.is_key_pressed(KEY_SHIFT)
	var view := player.camera.global_basis
	var ship_view: SpaceShipView = world.ship_views.get(int(tether.get("ship", -1)))
	if not tether.is_empty() and ship_view==null:
		tether = {}
		deck = false
		notice("Your line went slack: the ship is gone.")
	var hull := ship_view.global_transform if ship_view else Transform3D.IDENTITY
	if ship_view and _on_deck(tether.at) and not firing:
		# Magnetic boots: walk the deck in the ship's frame.
		deck = true
		_jet = Vector3.ZERO
		var forward := (hull.basis.inverse()*-view.z)*Vector3(1, 0, 1)
		var right := (hull.basis.inverse()*view.x)*Vector3(1, 0, 1)
		var step := (right.normalized()*input.x-forward.normalized()*input.y)*Player.BASE_SPEED*delta
		var at: Vector3 = tether.at+step
		at.y = ShipHull.DECK_Y+0.14
		var half := ShipHull.beam(at.z)-0.6
		at.x = clampf(at.x, -half, half)
		at.z = clampf(at.z, -17.5, 13.0)
		tether.at = at
		player.global_position = hull*at
		player.global_basis = hull.basis
		if step.length()>0.001: player.model.rotation.y = atan2(-step.x, -step.z)
		_draw_rope(hull*(tether.anchor as Vector3), player.global_position+hull.basis.y*1.0)
		player.set_meta("jet_on", false)
		fuel = minf(100.0, fuel+FUEL_REGEN*delta)
		update_camera(delta)
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
	if ship_view:
		var at: Vector3 = (tether.at as Vector3)+hull.basis.inverse()*_jet*delta
		var anchor: Vector3 = tether.anchor
		if at.distance_to(anchor)>ROPE: at = anchor+(at-anchor).normalized()*ROPE
		tether.at = at
		player.global_position = hull*at
		_draw_rope(hull*anchor, player.global_position+Vector3.UP*1.0)
	else:
		player.global_position += _jet*delta
		_rope.visible = false
	player.velocity = Vector3.ZERO
	if _jet.length()>0.4: player.model.rotation.y = lerp_angle(player.model.rotation.y, atan2(-_jet.x, -_jet.z), 1.0-exp(-delta*6.0))
	update_camera(delta)

## Over the main deck and low enough for the boots to hold (hull space).
func _on_deck(at: Vector3) -> bool:
	return at.z> -17.5 and at.z<13.0 and absf(at.x)<ShipHull.beam(at.z)-0.3 and at.y>ShipHull.DECK_Y-0.5 and at.y<ShipHull.DECK_Y+1.6

func _draw_rope(from: Vector3, to: Vector3) -> void:
	_rope.visible = true
	_rope_mesh.clear_surfaces()
	_rope_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var sag := Vector3.DOWN*minf(3.0, from.distance_to(to)*0.08)
	for k in 13:
		var t := k/12.0
		_rope_mesh.surface_add_vertex(from.lerp(to, t)+sag*sin(t*PI))
	_rope_mesh.surface_end()

func update_camera(delta: float) -> void:
	var in_chair := seat.begins_with("chair") or city_seat!=""
	var want_fp := (seat=="" or in_chair) and (camera_mode==CameraMode.FIRST_PERSON or world.first_person_at(player.global_position))
	first_person = move_toward(first_person, 1.0 if want_fp else 0.0, delta/0.25)
	var shoulder := camera_mode==CameraMode.SHOULDER and not want_fp
	var allow_capture := (want_fp or shoulder or spacewalk or seat in ["pilot", "turret_top", "turret_left", "turret_right"]) and not player.controls_locked() \
		and not player.ui_blocked and not player.interacting() and not map.visible and not cinematic
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if allow_capture else Input.MOUSE_MODE_VISIBLE
	(_crosshair as SpaceCrosshair).mode = "" if not allow_capture else "fp" if seat=="" or in_chair else "pilot" if seat=="pilot" else "turret"
	_crosshair.queue_redraw()
	_overlay.visible = not player.input_locked and not cinematic
	var alive := player.stats.hp>0.0
	player.model.visible = first_person<0.88 and alive
	player.status_visuals.visible = first_person<0.8 and alive
	player.aura.visible = first_person<0.8 and alive
	if cinematic: return
	if seat!="" and not in_chair and _ship!=null and world.ship_views.has(_ship.id):
		_seat_camera(delta)
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
	match seat:
		"pilot":
			if _cockpit:
				# First person at the helm in the room: the bridge window is a live view.
				var helm := world.seat_spec(_ship.slot, "pilot")
				player.camera.global_transform = Transform3D(Basis.IDENTITY, (helm.pos as Vector3)+Vector3.UP*1.45)
				player.camera.fov = 78.0
				player.model.visible = false
				_chase = Transform3D.IDENTITY
				return
			else:
				var offset: Vector3 = anchors.get("chase", Vector3(0, 9, 34))
				var at := pose*offset
				want = Transform3D(Basis.IDENTITY, at).looking_at(pose.origin-pose.basis.z*40.0, pose.basis.y)
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
