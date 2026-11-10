class_name Player
extends CharacterBody3D
## Top-down player: WASD moves relative to the camera and the character turns
## smoothly to face where it walks. No jumping: single blocks are stepped up and
## down automatically. Left click shoots toward the mouse cursor; while
## shooting the character faces the aim but keeps walking normally. Holding
## Holding right click charges a stronger shot (G3+ and Divine bows; each
## Divine bow has its own charged attack). Slow, heavy bows draw the string
## before every shot. Space raises the warp shield (needs a spell, costs
## magic); double-tapping Space with a
## tier 4+ or Divine spell sends out a warped ring. Q/E orbit the camera, I/O
## zoom. The camera follows height smoothly and can be shaken (CameraShake).
## Speed, fire rate, shots and magic all come from stats and equipped gear.
## A warm, flickering torch light follows the character in dark places
## (its strength is set from the biome, see torch_strength).

## mods: see Arrows.spawn (empty for normal shots).
signal shot(origin: Vector3, direction: Vector3, damage: int, weapon: Item, phase: float, mods: Dictionary)
signal ring_cast(spell: Item)

## Movement at 0 speed stat; PlayerStats applies the per-point Speed bonus.
const BASE_SPEED := 4.63
## Walking on roads and town streets is this much faster.
const ROAD_SPEED := 1.5
## Conversations: the camera swings in from the side, at this distance.
const TALK_DISTANCE := 4.4
const TALK_HEIGHT := 1.5
const TALK_BLEND_SPEED := 3.0
## Seconds between shots at 0 dexterity; PlayerStats applies the Dexterity bonus.
const BASE_FIRE_COOLDOWN := 0.41
const KNOCKBACK_MAX := 14.0  # m/s
const KNOCKBACK_DRAG := 7.0  # how quickly a push dies down
const KNOCKBACK_HOP := 0.3   # share of a push that lifts you off your feet
const KNOCKBACK_SHAKE := 0.03  # camera trauma per m/s of push
const GRAVITY := 30.0
const TURN_SPEED := 10.0
const STEP_HEIGHT := 1.05  # climbs single 1 m blocks, walls of 2+ still block
const STEP_SMOOTHING := 12.0  # how fast the model catches up after a step

const CAMERA_PITCH := deg_to_rad(72.0)
const CAMERA_FOV := 35.0
const ZOOM_MIN := 6.0
const ZOOM_MAX := 60.0
const ZOOM_DEFAULT := 38.0
const ZOOM_SPEED := 16.0  # meters per second while I/O is held
const ZOOM_SMOOTHING := 10.0
const ORBIT_SPEED := 2.0  # radians per second
const CAMERA_HEIGHT_SMOOTHING := 4.0
## Physics layers: terrain is on 1, obstacles on 2. The camera only avoids terrain.
const TERRAIN_LAYER := 1
const OBSTACLE_LAYER := 2
const ENEMY_LAYER := 4
## Other players online (see RemotePlayer); only solid when the server has
## player collision on.
const PLAYER_LAYER := 8
const CAMERA_PULL_OUT_SPEED := 2.0  # how quickly a zoom change settles
const AIM_HOLD := 0.5  # keep facing the aim this long after the last shot
const AIM_TURN_SPEED := 18.0
const SHOT_HEIGHT := 1.0  # arrows fly this high above the ground
const CHARGE_TIME := 1.0  # seconds to fully charge
const CHARGE_MIN := 0.25  # releasing before this cancels the shot
const SHIELD_MOVE_SPEED := 0.15  # bracing leaves 15% of normal movement
const CHARGE_MOVE_SPEED := 0.65  # walk slower while drawing a charged shot
## Where the bow sits relative to the character (for the charge effect).
const BOW_HAND := Vector3(-0.45, 1.05, -0.45)
const DOUBLE_TAP := 0.3  # seconds between Space presses that count as a double tap
const RING_COOLDOWN := 0.6
const SHAKE_DECAY := 1.8  # trauma lost per second
const SHAKE_MAX_OFFSET := 0.35  # meters, at full trauma
const SHAKE_MAX_ROLL := deg_to_rad(1.2)

const TORCH_COLOR := Color(1.0, 0.72, 0.38)
const TORCH_ENERGY := 3.2  # at torch_strength 1
const TORCH_RANGE := 16.0
const TORCH_HEIGHT := 1.4  # around chest height, lights the ground in a wide circle
const TORCH_FADE_SPEED := 2.0

var camera_yaw := 0.0
var camera_distance := ZOOM_DEFAULT
## 0 = torch off (bright places), 1 = full; fades smoothly toward this.
var torch_strength := 0.0
var status_visuals := PlayerStatusVisuals.new()
var facing := PI  # model yaw; PI = facing the camera
var terrain_viewer: VoxelViewer
var terrain: VoxelTerrain
var frozen := true
## Returns whether a position may be walked onto (e.g. not deep water).
var walkable := Callable()
## func(x, z) -> ground surface height; arrows aim this high plus SHOT_HEIGHT.
var ground_height := Callable()
## func(position) -> true when standing there burns (lava pits).
var hazard := Callable()
## func(position) -> true on a road or street (faster walking).
var road := Callable()
## Who we're talking to (an NPC), or null: the camera frames us both.
var talk_partner: Node3D
var _talk_blend := 0.0
var _talk_last := Vector3.ZERO
var _talk_camera_offset := Vector3.ZERO
var _talk_camera_timer := 0.0
var _talk_camera_partner: Node3D
## Debug/test hooks: when non-zero, used instead of WASD / the mouse aim.
var debug_input := Vector2.ZERO
var debug_aim := Vector3.ZERO  # world point

var stats: PlayerStats
## The class's figure (ArcherModel or ClassModel: animate, play_shot, hold).
var model: Node3D
var class_id := "archer"
var camera: Camera3D
var spatial_controller: SpatialController
var ground_view: GroundView
var shield := MagicShield.new()
var aura := GearAura.new()
var charge_effect := ChargeEffect.new()
## Who this is on the server (see GameServer).
var player_id := 0
## True while a UI panel (inventory) is open: clicks don't shoot.
var ui_blocked := false
## True while a menu or a loading transition is up: no moving, shooting or magic.
var input_locked := false:
	set(value):
		input_locked = value
		if value and is_instance_valid(spatial_controller): spatial_controller.hide_overlay()
var cinematic_locked := false
var _interaction_sources := {}
var _interaction_refresh := 0.0

func begin_interaction(source_id: int) -> void:
	_interaction_sources[source_id] = true
	_interaction_refresh = 1.0
	GameServer.set_interaction_protection(player_id, true)
	_cancel_weapon_actions()

func end_interaction(source_id: int) -> void:
	if not _interaction_sources.has(source_id): return
	_interaction_sources.erase(source_id)
	if _interaction_sources.is_empty(): GameServer.set_interaction_protection(player_id, false)

func interacting() -> bool:
	return not _interaction_sources.is_empty()

## Writing in the chat: keys type, the mouse doesn't aim.
var typing := false
func controls_locked() -> bool: return input_locked or cinematic_locked or typing
## What hit us last (an enemy's name), for the death screen.
var last_hit_by := ""

var _zoom_target := camera_distance
var _camera_reach := camera_distance  # actual distance after avoiding terrain
var _visual_offset := 0.0
var _camera_y := 0.0
var _cooldown := 0.0
var _aim_hold := 0.0
var _aim_point := Vector3.ZERO
## The ring on the ground where your shots go (only you see it).
var aim_marker := AimMarker.new()
var _torch := OmniLight3D.new()
var _torch_time := 0.0
var _torch_level := 0.0
var _last_magic_press := -10.0
var _ring_cooldown := 0.0
var _winding := 0.0  # seconds left drawing before a windup shot fires
var _charging := false
var _charge := 0.0
var _charge_weapon: Item
var _burst_left := 0
var _burst_timer := 0.0
var _burst := {}  # the burst being fired: weapon, mods, damage mult
var _trauma := 0.0
var _shake_time := 0.0
var _knock := Vector3.ZERO
var _hop := 0.0


func set_spatial_world(place: GameWorld) -> void:
	if is_instance_valid(ground_view):
		remove_child(ground_view)
		ground_view.free()
		ground_view = null
	if is_instance_valid(spatial_controller):
		remove_child(spatial_controller)
		spatial_controller.free()
		spatial_controller = null
	if place is SpatialWorld:
		spatial_controller = (place as SpatialWorld).make_controller(self)
		if spatial_controller!=null: add_child(spatial_controller)

	if place is HallWorld or place is IslandWorld:
		ground_view = GroundView.new()
		ground_view.player = self
		add_child(ground_view)


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)
	floor_snap_length = STEP_HEIGHT + 0.05  # stick to the ground when stepping down
	collision_mask = TERRAIN_LAYER | OBSTACLE_LAYER

	model = PlayerClasses.make_model(class_id)
	add_child(model)

	terrain_viewer = VoxelViewer.new()
	terrain_viewer.view_distance = 128
	add_child(terrain_viewer)

	camera = Camera3D.new()
	camera.fov = CAMERA_FOV
	camera.top_level = true  # follows the player in code, doesn't inherit rotation
	add_child(camera)
	camera.make_current()
	var leisure := LeisurePresentation.new()
	leisure.actor = self
	add_child(leisure)

	_torch.light_color = TORCH_COLOR
	_torch.light_energy = TORCH_ENERGY
	_torch.omni_range = TORCH_RANGE
	_torch.omni_attenuation = 0.7  # softer falloff: a wide, even pool of light
	# No shadows: the light sits inside the character, and a shadowed light
	# there would mostly light up the inside of the hood instead of the ground.
	_torch.shadow_enabled = false
	_torch.light_volumetric_fog_energy = 0.3  # keep the halo subtle
	_torch.position.y = TORCH_HEIGHT
	add_child(_torch)
	add_child(shield)
	add_child(aura)
	status_visuals.effects = stats.buffs if stats else null
	status_visuals.player_name = Account.username() if Account.username() != "" else "Adventurer"
	add_child(status_visuals)
	charge_effect.position = BOW_HAND
	model.add_child(charge_effect)  # turns with the character
	CameraShake.register(self)


func _exit_tree() -> void:
	if interacting(): GameServer.set_interaction_protection(player_id, false)
	CameraShake.unregister(self)


## Updates looks that depend on equipped gear (shield colors, aura) and the
## class's figure.
func refresh_gear() -> void:
	if stats and stats.class_id != class_id:
		set_class(stats.class_id)
	shield.set_spell(stats.gear.spell)
	aura.refresh(stats)


## Swaps the figure for another class's (keeps facing and the charge glow).
func set_class(p_class_id: String) -> void:
	class_id = p_class_id
	if model == null:
		return
	var old := model
	model = PlayerClasses.make_model(class_id)
	add_child(model)
	model.rotation.y = old.rotation.y
	charge_effect.reparent(model, false)
	old.queue_free()


## Drunk: walking drags off to one side and back, more with every drink.
func drunk_sway(dir: Vector3, up: Vector3) -> Vector3:
	var level := mini(stats.buffs.count("drunk"), 6)
	if level == 0 or dir.length_squared() < 0.0001: return dir
	var t := Time.get_ticks_msec() / 1000.0
	var angle := (sin(t * 1.3) * 0.6 + sin(t * 0.47 + 1.0) * 0.4) * 0.13 * level
	return dir.rotated(up, angle)

## Camera shake from CameraShake: 0..1, adds up and wears off by itself.
func add_trauma(amount: float) -> void:
	_trauma = minf(1.0, _trauma + amount)


func _process(delta: float) -> void:
	if interacting():
		_interaction_refresh -= delta
		if _interaction_refresh <= 0.0:
			_interaction_refresh = 1.0
			GameServer.set_interaction_protection(player_id, true)
	if stats:
		status_visuals.effects = stats.buffs
		status_visuals.player_name = Net.client.account_name if Net.is_client() and Net.client else Account.username() if Account.username() != "" else "Adventurer"
	# Torch shimmer: a few out-of-step waves so the flicker never looks regular.
	_torch_time += delta
	var t := _torch_time
	var flicker := 0.07 * sin(t * 7.3) + 0.05 * sin(t * 13.1 + 1.3) + 0.03 * sin(t * 23.7 + 0.4)
	_torch_level = move_toward(_torch_level, torch_strength, delta * TORCH_FADE_SPEED)
	_torch.visible = _torch_level > 0.01
	_torch.light_energy = TORCH_ENERGY * _torch_level * (1.0 + flicker)
	_torch.position = Vector3(sin(t * 5.1) * 0.03, TORCH_HEIGHT + sin(t * 6.7) * 0.03, cos(t * 4.3) * 0.03)


## Holds the player still until the ground under them has been generated.
func place(pos: Vector3, p_terrain: VoxelTerrain, p_walkable := Callable()) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	terrain = p_terrain
	walkable = p_walkable
	frozen = true
	_visual_offset = 0.0
	_camera_y = pos.y + 1.0


func _physics_process(delta: float) -> void:
	_update_zoom(delta)
	if not frozen and Leisure.apply_seat(self, delta): return
	if is_instance_valid(spatial_controller):
		spatial_controller.physics_step(delta)
		return
	if frozen:
		var area := AABB(global_position - Vector3(8, 8, 8), Vector3(16, 16, 16))
		if terrain and terrain.is_area_meshed(area):
			frozen = false
			clear_spawn(null)
		_update_camera(delta)
		return

	# Resolve magic before movement and weapon updates, including the first frame.
	_update_magic(delta)
	if shield.active or stats.buffs.has_effect("quiet") or controls_locked() or interacting(): _cancel_weapon_actions()
	if not controls_locked():
		camera_yaw += Input.get_axis("orbit_right", "orbit_left") * ORBIT_SPEED * delta

	var input := Vector2.ZERO if controls_locked() else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if debug_input != Vector2.ZERO:
		input = debug_input
	if stats.buffs.has_effect("static"):
		input = Vector2.ZERO
		_knock = Vector3.ZERO
		_hop = 0.0
	var dir := drunk_sway(Basis(Vector3.UP, camera_yaw) * Vector3(input.x, 0, input.y), Vector3.UP)
	var speed := BASE_SPEED * stats.move_speed_multiplier() * (SHIELD_MOVE_SPEED if shield.active else CHARGE_MOVE_SPEED if _charging else 1.0)
	if road.is_valid() and is_on_floor() and road.call(global_position):
		speed *= ROAD_SPEED
	velocity.x = dir.x * speed + _knock.x
	velocity.z = dir.z * speed + _knock.z
	_knock = _knock.lerp(Vector3.ZERO, 1.0 - exp(-KNOCKBACK_DRAG * delta))
	if walkable.is_valid():
		# Check each axis on its own so the player slides along shorelines.
		var look := 0.5
		if not walkable.call(global_position + Vector3(signf(velocity.x) * look, 0, 0)):
			velocity.x = 0.0
		if not walkable.call(global_position + Vector3(0, 0, signf(velocity.z) * look)):
			velocity.z = 0.0
	velocity.y = 0.0 if is_on_floor() else velocity.y - GRAVITY * delta
	if _hop > 0.0:
		velocity.y = _hop
		_hop = 0.0

	var prev_y := global_position.y
	move_and_slide()
	if dir != Vector3.ZERO and is_on_floor() and is_on_wall():
		_try_step_up(dir)

	# Steps move the body instantly; let the model glide to the new height.
	var dy := global_position.y - prev_y
	if absf(dy) > 0.25:
		_visual_offset -= dy
	_visual_offset = lerpf(_visual_offset, 0.0, minf(1.0, delta * STEP_SMOOTHING))
	model.position.y = _visual_offset

	_update_camera(delta)
	_update_combat(delta,dir,speed)


func _update_combat(delta: float,dir: Vector3,speed: float) -> void:
	if Leisure.hands_busy(player_id): _cancel_weapon_actions()
	_aim_point = debug_aim if debug_aim != Vector3.ZERO else spatial_controller.mouse_point() if is_instance_valid(spatial_controller) else _mouse_point()
	# Clicks on the UI (buttons, slots) don't shoot.
	var free_hands := not Leisure.hands_busy(player_id) and not interacting() and not stats.buffs.has_effect("quiet") and not shield.active and not ui_blocked and not controls_locked() and get_viewport().gui_get_hovered_control() == null
	_update_charge(delta, free_hands)
	var shooting := Input.is_action_pressed("shoot") and free_hands and not _charging and _burst_left == 0
	_aim_hold = AIM_HOLD if shooting or _charging or _winding > 0.0 else _aim_hold - delta
	if aim_marker.is_inside_tree():
		# On the cursor's own ray, so the ring's middle is always at the cursor's tip.
		aim_marker.track(_aim_point,
				(Input.is_action_pressed("shoot") or _charging) and free_hands and stats.gear.weapon != null, delta)
	if _aim_hold > 0.0 or (is_instance_valid(ground_view) and ground_view.free_look()) or (is_instance_valid(spatial_controller) and (spatial_controller.first_person>0.8 or (spatial_controller is SpaceTraversal and spatial_controller.free_look()))):
		facing = lerp_angle(facing, aim_yaw(), minf(1.0, delta * AIM_TURN_SPEED))
	elif dir != Vector3.ZERO:
		var local_dir := global_basis.inverse()*dir if is_instance_valid(spatial_controller) else dir
		facing = lerp_angle(facing, atan2(-local_dir.x, -local_dir.z), minf(1.0, delta * TURN_SPEED))
	model.rotation.y = facing
	model.animate((velocity.slide(up_direction).length() if is_instance_valid(spatial_controller) else Vector2(velocity.x,velocity.z).length())/maxf(0.01,speed),delta)

	_cooldown -= delta
	if _winding > 0.0:
		_winding -= delta
		var weapon: Item = stats.gear.weapon
		model.hold = 1.0 - clampf(_winding / maxf(0.01, weapon.windup if weapon else 1.0), 0.0, 1.0)
		if _winding <= 0.0:
			model.hold = 0.0
			_fire()
	elif shooting and _cooldown <= 0.0:
		shoot()
	_update_burst(delta)


## Fires in a straight line toward the aim point, at SHOT_HEIGHT above the
## ground there, so shots go up or down slopes directly. Multi-shot weapons
## fan their shots out (spread) or send weaving pairs (opposite phases).
func shoot() -> void:
	if interacting() or Leisure.hands_busy(player_id): return
	var weapon: Item = stats.gear.weapon
	if stats.buffs.has_effect("quiet") or shield.active or weapon == null or _winding > 0.0:
		return
	_cooldown = BASE_FIRE_COOLDOWN / stats.shots_per_second_multiplier()
	_aim_hold = AIM_HOLD
	if weapon.windup > 0.0:
		_winding = weapon.windup  # draw the string first; _fire() runs after
		return
	_fire()


func _fire() -> void:
	if interacting(): return
	if shield.active or stats.buffs.has_effect("quiet"): return
	var weapon: Item = stats.gear.weapon
	if weapon == null:
		return
	var aim := _aim_origin_and_direction()
	model.play_shot()
	for i in weapon.shots:
		var offset := ((weapon.shots - 1) * 0.5 - i) * deg_to_rad(weapon.spread_deg)
		var phase := PI * i
		var mods := {}
		if weapon.shots % 2 == 1 and float(weapon.projectile.get("wave_amp", 0.0)) > 0.0:
			if i == weapon.shots / 2: mods.wave_amp = 0.0
			phase = PI if i > weapon.shots / 2 else 0.0
		shot.emit(aim[0], (aim[1] as Vector3).rotated(up_direction, offset), roundi(stats.roll_damage() * weapon.shot_share(i)), weapon, phase, mods)


## [origin, direction] for a shot toward the aim point at SHOT_HEIGHT above
## the ground there.
func _aim_origin_and_direction() -> Array:
	if is_instance_valid(spatial_controller): return spatial_controller.aim_ray()
	if is_instance_valid(ground_view) and ground_view.free_look(): return ground_view.aim_ray()
	var forward := Basis(Vector3.UP, aim_yaw()) * Vector3.FORWARD
	var origin := global_position + Vector3(0, SHOT_HEIGHT, 0) + forward * 0.6
	var target := _aim_point
	target.y = (ground_height.call(target.x, target.z) if ground_height.is_valid() else global_position.y) + SHOT_HEIGHT
	var direction := target - origin
	if Vector2(direction.x, direction.z).length() < 1.0:
		direction = forward  # cursor right on the character: shoot straight ahead
	return [origin, direction.normalized()]


# --- Charged shots ------------------------------------------------------------------

func _cancel_weapon_actions() -> void:
	_charging = false
	_charge = 0.0
	_charge_weapon = null
	_winding = 0.0
	_burst_left = 0
	model.hold = 0.0
	charge_effect.set_level(0.0, Color.WHITE)


func _update_charge(delta: float, free_hands: bool) -> void:
	if shield.active or stats.buffs.has_effect("quiet"):
		_cancel_weapon_actions()
		return
	var weapon: Item = stats.gear.weapon
	if _charging and (weapon != _charge_weapon or not free_hands):
		_cancel_weapon_actions()
		return
	var can_charge := weapon != null and not weapon.charge.is_empty() and _burst_left == 0 and _winding <= 0.0 and (_charging or _cooldown <= 0.0)
	if Input.is_action_pressed("charge") and can_charge and (free_hands or _charging):
		_charging = true
		_charge_weapon = weapon
		charge_effect.magic_ball = weapon.kind == "Wand"
		_charge = minf(1.0, _charge + delta / CHARGE_TIME)
		model.hold = _charge
		charge_effect.set_level(_charge, weapon.projectile.get("color", Color.WHITE))
		return
	if _charging:
		_charging = false
		model.hold = 0.0
		charge_effect.set_level(0.0, Color.WHITE)
		if _charge >= CHARGE_MIN and can_charge:
			_release_charge(weapon, _charge)
		_charge = 0.0


## Fires the weapon's charged attack. `power` 0..1 scales the damage bonus.
func _release_charge(weapon: Item, power: float) -> void:
	if shield.active or stats.buffs.has_effect("quiet"): return
	var c: Dictionary = weapon.charge
	var mult := lerpf(1.0, c.get("mult", 2.0), power)
	var aim := _aim_origin_and_direction()
	var origin: Vector3 = aim[0]
	var direction: Vector3 = aim[1]
	model.play_shot()
	_aim_hold = AIM_HOLD
	_cooldown = BASE_FIRE_COOLDOWN / stats.shots_per_second_multiplier()
	var big := {speed = 1.6, size = 1.7, range = 1.5, spiral = true}
	match c.style:
		"serpent_fan":
			var count: int = c.get("count", 3)
			for i in count:
				var offset := (i - (count - 1) * 0.5) * deg_to_rad(float(c.get("spread", 12.0)))
				_emit_charged(origin, direction.rotated(up_direction, offset), weapon, mult / count, TAU * i / count,
					{speed = 1.12, size = 1.65, range = 1.25, spiral = true, wave_amp = 0.85, pierce = true, style = "serpent"})
		"arcane":
			_emit_charged(origin, direction, weapon, mult, 0.0,
				{speed=1.15, size=1.6, range=1.25, spiral=true, wave_amp=0.0, cone_deg=8.0, pierce=true})
		"stream":
			var count: int = c.get("count", 10)
			_burst = {weapon=weapon, mult=mult / count, interval=c.get("interval", 0.045), stream=true, origin=origin, direction=direction}
			_burst_left = count
			_burst_timer = 0.0
		"volley":
			var count: int = c.get("count", 7)
			for i in count:
				var offset := ((count - 1) * 0.5 - i) * deg_to_rad(c.get("spread", 6.0))
				_emit_charged(origin, direction.rotated(up_direction, offset), weapon, mult * weapon.shot_share(i, count), 0.0,
						{speed = 1.3, size = 1.2, range = 1.2, spiral = i == count / 2})
		"helix":
			for i in 2:
				_emit_charged(origin, direction, weapon, mult * 0.5, PI * i,
						{speed = 1.3, size = 1.8, range = 1.4, spiral = true, wave_amp = 1.1})
		"burst":
			_burst = {weapon = weapon, mult = mult / int(c.get("count", 6)), interval = c.get("interval", 0.07)}
			_burst_left = c.get("count", 5)
			_burst_timer = 0.0
		"singularity":
			_emit_charged(origin, direction, weapon, mult, 0.0,
					{speed = 1.15, size = 1.6, range = 1.3, spiral = true, pierce = true, burst = "singularity"})
		"inferno":
			_emit_charged(origin, direction, weapon, mult, 0.0,
					{speed = 1.4, size = 1.9, range = 1.3, spiral = true, pierce = false, burst = "inferno"})
		_:  # "power": the bow's normal pattern, but big, fast and strong
			for i in weapon.shots:
				var offset := ((weapon.shots - 1) * 0.5 - i) * deg_to_rad(weapon.spread_deg)
				_emit_charged(origin, direction.rotated(up_direction, offset), weapon, mult * weapon.shot_share(i), PI * i, big)
	if power >= 1.0:
		CameraShake.shake_at(global_position, 0.12, 6.0)


func _emit_charged(origin: Vector3, direction: Vector3, weapon: Item, mult: float, phase: float,
		mods: Dictionary) -> void:
	if interacting(): return
	mods["secondary"] = true
	shot.emit(origin, direction, int(round(stats.roll_damage() * mult)), weapon, phase, mods)


## Burst-style charged attacks fire their arrows one after another.
func _update_burst(delta: float) -> void:
	if _burst_left > 0 and (stats.gear.weapon != _burst.weapon or controls_locked() or ui_blocked):
		_cancel_weapon_actions()
		return
	if stats.buffs.has_effect("quiet") or shield.active or _burst_left <= 0:
		return
	_burst_timer -= delta
	if _burst_timer > 0.0:
		return
	_burst_timer = _burst.interval
	_burst_left -= 1
	var aim := _aim_origin_and_direction()
	if _burst.get("stream", false):
		model.play_shot()
		_emit_charged(_burst.origin, _burst.direction, _burst.weapon, _burst.mult, 0.0,
			{style="water", speed=1.35, size=0.8, range=1.3, wave_amp=0.0, spiral=true})
		return
	var jitter := randf_range(-1.0, 1.0) * deg_to_rad(2.5)
	model.play_shot()
	_emit_charged(aim[0], (aim[1] as Vector3).rotated(up_direction, jitter), _burst.weapon, _burst.mult, 0.0,
			{speed = 1.4, size = 1.25, range = 1.2})


## Takes a hit (this client detected it; the server applies it). Defence
## softens the remainder after the shield's MAG-based reduction. The warp
## shield still blocks magic completely and has no damage capacity to exhaust.
func take_damage(amount: float, armor_piercing := false, magic := false) -> bool:
	if shield.active:
		shield.flash()
		GameAudio.play("magic_shield_hit", global_position + Vector3.UP * 0.9, {source_id = get_instance_id(), cooldown = 0.08})
		if Net.is_client(): Net.client.send_action("shield_contact", [])
	if GameServer.intro_protected(player_id) or stats.buffs.has_effect("invincible"): return false
	if shield.active and magic:
		return false
	var before := stats.hp
	var result := GameServer.hit_player(player_id, amount, armor_piercing, shield.active,last_hit_by)
	var landed: float = result.landed
	if landed >= 0.5:
		GameAudio.play("hurt", global_position, {source_id = get_instance_id(), cooldown = 0.2})
	if landed >= 0.5:
		FloatingText.spawn(get_parent(), global_position + Vector3.UP * 2.3, "-%d" % roundi(landed),
				FloatingText.PLAYER_PIERCED if armor_piercing else FloatingText.PLAYER_DAMAGE, true)
	# Offline death immediately creates a fresh character: never apply this hit's
	# statuses to that new life. A blocked magic hit also returned false above.
	return landed<before and stats.hp>0.0


## Shoves the player (m/s, sideways), with a little hop and a jolt of the
## camera; the push dies down over a moment. Pushes add up to KNOCKBACK_MAX.
func knockback(push: Vector3) -> void:
	if GameServer.intro_protected(player_id): return
	push.y = 0.0
	if push.length() < 0.1:
		return
	_knock = (_knock + push).limit_length(KNOCKBACK_MAX)
	_hop = maxf(_hop, minf(push.length() * KNOCKBACK_HOP, 5.0))
	add_trauma(minf(0.4, push.length() * KNOCKBACK_SHAKE))


func _update_magic(delta: float) -> void:
	if Leisure.hands_busy(player_id):
		_set_shield(false)
		return
	_ring_cooldown -= delta
	var now := Time.get_ticks_msec() / 1000.0
	if Input.is_action_just_pressed("magic") and not controls_locked() and not interacting():
		if now - _last_magic_press < DOUBLE_TAP:
			cast_ring()
			_last_magic_press = -10.0
		else:
			_last_magic_press = now
	# No spell, no magic. The server drains magic while it's up (and may
	# refuse to raise it).
	var want := Input.is_action_pressed("magic") and not controls_locked() and not interacting() and stats.gear.spell != null
	if want and not shield.active:
		_set_shield(true)
	elif shield.active and (not want or stats.mp <= 0.0):
		_set_shield(false)


func _set_shield(up: bool) -> bool:
	shield.active = GameServer.set_shield(player_id, up)
	GameAudio.shield(shield.active)
	return shield.active


## Sends out the equipped spell's warped ring, if it has one and there's
## enough magic.
func cast_ring() -> void:
	if interacting(): return
	var spell: Item = stats.gear.spell
	if spell == null or spell.ring.is_empty() or _ring_cooldown > 0.0 or not GameServer.request_ring(player_id):
		return
	_ring_cooldown = maxf(RING_COOLDOWN, spell.ring.get("cooldown", RING_COOLDOWN))
	ring_cast.emit(spell)
	GameAudio.play("magic_ring", global_position, {source_id = get_instance_id(), cooldown = 0.2})


## Yaw from the player toward the aim point.
func aim_yaw() -> float:
	var to := _aim_point - global_position
	if is_instance_valid(spatial_controller): to = global_basis.inverse()*to
	return atan2(-to.x, -to.z) if Vector2(to.x, to.z).length() > 0.05 else facing


## Where the mouse cursor points in the world: the first thing under it.
func _mouse_point() -> Vector3:
	if is_instance_valid(ground_view) and ground_view.free_look(): return ground_view.mouse_point()
	var mouse := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var dir := camera.project_ray_normal(mouse)
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 300.0)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var body := hit.collider as CollisionObject3D
		if body and body.collision_layer & TERRAIN_LAYER:
			return hit.position  # ground: aim at it (shots climb to higher ground)
		# An enemy or object: shots fly SHOT_HEIGHT above the ground, so aim
		# where the cursor's ray crosses that height. The shot then passes
		# right under the cursor instead of at the foot of what's hovered.
		var point: Vector3 = hit.position
		for i in 2:
			var ground: float = ground_height.call(point.x, point.z) if ground_height.is_valid() else global_position.y
			var crossing = Plane(Vector3.UP, ground + SHOT_HEIGHT).intersects_ray(from, dir)
			if crossing == null:
				break
			point = crossing
		return point
	var on_plane = Plane(Vector3.UP, global_position.y + SHOT_HEIGHT).intersects_ray(from, dir)
	return on_plane if on_plane != null else global_position


## Just arrived in a world: if the body is inside something, step to the
## nearest free spot (or rise above it and fall). The server allows this one
## hop per arrival.
func clear_spawn(place: GameWorld) -> void:
	if not Leisure.seat_spec(player_id).is_empty(): return
	var spot := Unstuck.spawn_spot(self, place)
	if not spot.is_finite(): return
	global_position = spot
	velocity = Vector3.ZERO
	if Net.is_client(): Net.client.send_action("unstuck", [spot, true])


## Lifts the player onto a ledge up to `height` tall (along `normal`, the
## local up) if there's room above it.
func _try_step_up(dir: Vector3, normal := Vector3.UP, height := STEP_HEIGHT) -> void:
	var up := normal*height
	if test_move(global_transform, up):
		return  # no headroom
	if test_move(global_transform.translated(up), dir.normalized() * 0.3):
		return  # wall is taller than one block
	global_position += up


func _update_zoom(delta: float) -> void:
	if spatial_controller is SpaceTraversal and (spatial_controller as SpaceTraversal).seat!="": return
	_zoom_target = clampf(
			_zoom_target + (0.0 if controls_locked() else Input.get_axis("zoom_in", "zoom_out")) * ZOOM_SPEED * delta,
			ZOOM_MIN, ZOOM_MAX)
	camera_distance = lerpf(camera_distance, _zoom_target, minf(1.0, delta * ZOOM_SMOOTHING))


func set_zoom(distance: float) -> void:
	_zoom_target = distance
	camera_distance = distance
	_camera_reach = distance


func _update_camera(delta: float) -> void:
	if is_instance_valid(ground_view):
		ground_view.update_camera(delta)
		if ground_view.free_look(): return
	# Follow the model's smoothed height, then ease the camera after it, so
	# walking up a mountain moves the view gently instead of in steps.
	var target_y := global_position.y + _visual_offset + 1.0
	_camera_y = lerpf(_camera_y, target_y, minf(1.0, delta * CAMERA_HEIGHT_SMOOTHING))
	var target := Vector3(global_position.x, _camera_y, global_position.z)
	var direction := Basis(Vector3.UP, camera_yaw) * Vector3(0, sin(CAMERA_PITCH), cos(CAMERA_PITCH))
	# The camera keeps the zoom the player chose: it never pulls in because a
	# hill, wall or tree is between it and the character.
	_camera_reach = lerpf(_camera_reach, camera_distance, minf(1.0, delta * CAMERA_PULL_OUT_SPEED))
	var talking := is_instance_valid(talk_partner)
	_talk_blend = move_toward(_talk_blend, 1.0 if talking else 0.0, delta * TALK_BLEND_SPEED)
	var from := target + direction * _camera_reach
	if _talk_blend <= 0.0:
		camera.global_position = from
		camera.look_at(target)
	else:
		# Close and from the side, like a chat at the table: both of us in view.
		var other := talk_partner.global_position if talking else _talk_last
		_talk_last = other
		var mid := (global_position + other) * 0.5 + Vector3.UP * 1.05
		var across := Vector3(other.x - global_position.x, 0.0, other.z - global_position.z)
		var side := across.cross(Vector3.UP).normalized() if across.length() > 0.1 else Vector3.BACK
		if side.dot(from - mid) < 0.0:
			side = -side
		_talk_camera_timer -= delta
		if talking and (talk_partner != _talk_camera_partner or _talk_camera_timer <= 0.0):
			_talk_camera_partner = talk_partner
			_talk_camera_timer = 0.3
			_talk_camera_offset = _conversation_camera(mid, side, other) - mid
		var close := mid + _talk_camera_offset
		var k := smoothstep(0.0, 1.0, _talk_blend)
		camera.global_position = from.lerp(close, k)
		var look := target.lerp(mid, k)
		if camera.global_position.distance_to(look) > 0.01:
			camera.look_at(look)
		if talking:
			facing = lerp_angle(facing, atan2(-across.x, -across.z), minf(1.0, delta * 8.0))
			model.rotation.y = facing
	_apply_shake(delta)


## Try both sides and raised views, checking both speakers against world geometry.
func _conversation_camera(mid: Vector3, side: Vector3, other: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var span := global_position.distance_to(other)
	var distance := maxf(TALK_DISTANCE, span * 0.8 + 2.0)
	var heads := [global_position + Vector3.UP * 1.2, other + Vector3.UP * 1.2]
	for elevation in [TALK_HEIGHT, 4.5, 8.0, 16.0]:
		for angle in [0.0, PI, PI * 0.5, -PI * 0.5, PI * 0.25, -PI * 0.25, PI * 0.75, -PI * 0.75]:
			var candidate: Vector3 = mid + side.rotated(Vector3.UP, angle) * distance + Vector3.UP * elevation
			var clear := true
			for head: Vector3 in heads:
				var query := PhysicsRayQueryParameters3D.create(candidate, head, TERRAIN_LAYER | OBSTACLE_LAYER)
				query.exclude = [get_rid()]
				query.hit_from_inside = true
				if not space.intersect_ray(query).is_empty():
					clear = false
					break
			if clear:
				return candidate
	return mid + Vector3(0.2, maxf(24.0, span * 1.5), 0.2)


## Shake: smooth wobble (out-of-step sine waves) scaled by trauma squared, so
## small shakes stay gentle and only big ones really move the view.
func _apply_shake(delta: float) -> void:
	if _trauma <= 0.0:
		return
	_trauma = maxf(0.0, _trauma - SHAKE_DECAY * delta)
	_shake_time += delta
	var t := _shake_time * 28.0
	var amount := _trauma * _trauma
	var offset := Vector3(sin(t * 1.1) + sin(t * 2.3) * 0.5, sin(t * 1.7 + 1.0) + sin(t * 2.9) * 0.5, 0.0) / 1.5
	camera.global_position += camera.global_basis * (offset * SHAKE_MAX_OFFSET * amount)
	camera.rotate_object_local(Vector3.FORWARD, sin(t * 1.3 + 2.0) * SHAKE_MAX_ROLL * amount)


## Projectile impact: offline applies now; online references a server-issued shot.
func receive_attack_effects(attack: Dictionary) -> void:
	if GameServer.intro_protected(player_id) or stats.hp<=0.0: return
	if Net.is_client():
		var token := int(attack.get("status_token",0))
		if token>0: Net.client.send_action("status_hit",[token])
	else:
		GameServer.apply_effects(player_id,attack.get("effects",[]),str(attack.get("effect_source",attack.get("by","projectile"))))
