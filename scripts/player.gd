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

## Movement at 0 speed stat; each point of speed adds 1% (8 speed = ~5 m/s).
const BASE_SPEED := 4.63
## Walking on roads and town streets is this much faster.
const ROAD_SPEED := 1.5
## Conversations: the camera swings in from the side, at this distance.
const TALK_DISTANCE := 4.4
const TALK_HEIGHT := 1.5
const TALK_BLEND_SPEED := 3.0
## Seconds between shots at 0 dexterity; each point makes it 1.5% faster.
const BASE_FIRE_COOLDOWN := 0.41
const SHIELD_BREAK_LOCKOUT := 1.5  # seconds before a broken shield can rise again
const KNOCKBACK_MAX := 14.0  # m/s
const KNOCKBACK_DRAG := 7.0  # how quickly a push dies down
const KNOCKBACK_HOP := 0.3   # share of a push that lifts you off your feet
const KNOCKBACK_SHAKE := 0.03  # camera trauma per m/s of push
const GRAVITY := 30.0
const TURN_SPEED := 10.0
const STEP_HEIGHT := 1.05  # climbs single 1 m blocks, walls of 2+ still block
const STEP_SMOOTHING := 12.0  # how fast the model catches up after a step

const CAMERA_PITCH := deg_to_rad(55.0)
const CAMERA_FOV := 35.0
const ZOOM_MIN := 6.0
const ZOOM_MAX := 45.0
const ZOOM_DEFAULT := 30.0
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
## Standing in a lava pit: armor-piercing damage once a second.
const LAVA_DAMAGE := 40.0
const LAVA_TICK := 1.0
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
## Debug/test hooks: when non-zero, used instead of WASD / the mouse aim.
var debug_input := Vector2.ZERO
var debug_aim := Vector3.ZERO  # world point

var stats: PlayerStats
## The class's figure (ArcherModel or ClassModel: animate, play_shot, hold).
var model: Node3D
var class_id := "archer"
var camera: Camera3D
var shield := MagicShield.new()
var aura := GearAura.new()
var charge_effect := ChargeEffect.new()
## Who this is on the server (see GameServer).
var player_id := 0
## True while a UI panel (inventory) is open: clicks don't shoot.
var ui_blocked := false
## True while a menu or a loading transition is up: no moving, shooting or magic.
var input_locked := false
var cinematic_locked := false

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
var _torch := OmniLight3D.new()
var _torch_time := 0.0
var _torch_level := 0.0
var _shield_pool := 0.0
var _shield_lockout := 0.0
var _last_magic_press := -10.0
var _ring_cooldown := 0.0
var _winding := 0.0  # seconds left drawing before a windup shot fires
var _charging := false
var _charge := 0.0
var _charge_weapon: Item
var _burst_left := 0
var _burst_timer := 0.0
var _burst := {}  # the burst being fired: weapon, mods, damage mult
var _lava_timer := 0.0
var _trauma := 0.0
var _shake_time := 0.0
var _knock := Vector3.ZERO
var _hop := 0.0


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

	var viewer := VoxelViewer.new()
	viewer.view_distance = 128
	add_child(viewer)

	camera = Camera3D.new()
	camera.fov = CAMERA_FOV
	camera.top_level = true  # follows the player in code, doesn't inherit rotation
	add_child(camera)
	camera.make_current()

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


## Camera shake from CameraShake: 0..1, adds up and wears off by itself.
func add_trauma(amount: float) -> void:
	_trauma = minf(1.0, _trauma + amount)


func _process(delta: float) -> void:
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
	if frozen:
		var area := AABB(global_position - Vector3(8, 8, 8), Vector3(16, 16, 16))
		if terrain and terrain.is_area_meshed(area):
			frozen = false
		_update_camera(delta)
		return

	# Resolve magic before movement and weapon updates, including the first frame.
	_update_magic(delta)
	if shield.active or stats.buffs.has_effect("quiet") or controls_locked(): _cancel_weapon_actions()
	if not controls_locked():
		camera_yaw += Input.get_axis("orbit_right", "orbit_left") * ORBIT_SPEED * delta

	var input := Vector2.ZERO if controls_locked() else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if debug_input != Vector2.ZERO:
		input = debug_input
	if stats.buffs.has_effect("static"):
		input = Vector2.ZERO
		_knock = Vector3.ZERO
		_hop = 0.0
	var dir := Basis(Vector3.UP, camera_yaw) * Vector3(input.x, 0, input.y)
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
	_aim_point = debug_aim if debug_aim != Vector3.ZERO else _mouse_point()
	# Clicks on the UI (buttons, slots) don't shoot.
	var free_hands := not stats.buffs.has_effect("quiet") and not shield.active and not ui_blocked and not controls_locked() and get_viewport().gui_get_hovered_control() == null
	_update_charge(delta, free_hands)
	var shooting := Input.is_action_pressed("shoot") and free_hands and not _charging and _burst_left == 0
	_aim_hold = AIM_HOLD if shooting or _charging or _winding > 0.0 else _aim_hold - delta
	if _aim_hold > 0.0:
		facing = lerp_angle(facing, aim_yaw(), minf(1.0, delta * AIM_TURN_SPEED))
	elif dir != Vector3.ZERO:
		facing = lerp_angle(facing, atan2(-dir.x, -dir.z), minf(1.0, delta * TURN_SPEED))
	model.rotation.y = facing
	model.animate(Vector2(velocity.x, velocity.z).length() / speed, delta)

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
	_update_lava(delta)


## Fires in a straight line toward the aim point, at SHOT_HEIGHT above the
## ground there, so shots go up or down slopes directly. Multi-shot weapons
## fan their shots out (spread) or send weaving pairs (opposite phases).
func shoot() -> void:
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
		shot.emit(aim[0], (aim[1] as Vector3).rotated(Vector3.UP, offset), roundi(stats.roll_damage() * weapon.shot_share(i)), weapon, phase, mods)


## [origin, direction] for a shot toward the aim point at SHOT_HEIGHT above
## the ground there.
func _aim_origin_and_direction() -> Array:
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
				_emit_charged(origin, direction.rotated(Vector3.UP, offset), weapon, mult * weapon.shot_share(i, count), 0.0,
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
				_emit_charged(origin, direction.rotated(Vector3.UP, offset), weapon, mult * weapon.shot_share(i), PI * i, big)
	if power >= 1.0:
		CameraShake.shake_at(global_position, 0.12, 6.0)


func _emit_charged(origin: Vector3, direction: Vector3, weapon: Item, mult: float, phase: float,
		mods: Dictionary) -> void:
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
	_emit_charged(aim[0], (aim[1] as Vector3).rotated(Vector3.UP, jitter), _burst.weapon, _burst.mult, 0.0,
			{speed = 1.4, size = 1.25, range = 1.2})


## Takes a hit (this client detected it; the server applies it). Defence
## softens normal hits; the warp shield blocks magic completely and soaks up
## most of a normal hit until it breaks.
func take_damage(amount: float, armor_piercing := false, magic := false) -> bool:
	if GameServer.intro_protected(player_id) or stats.buffs.has_effect("invincible"): return false
	if shield.active and magic:
		shield.flash()
		return false
	var before := stats.hp
	var result := GameServer.hit_player(player_id, amount, armor_piercing, shield.active)
	if shield.active:
		shield.flash()
		_shield_pool -= result.soaked
		if _shield_pool <= 0.0:
			_set_shield(false)
			_shield_lockout = SHIELD_BREAK_LOCKOUT
	var landed: float = result.landed
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
	if shield.active: _shield_pool = minf(_shield_pool,stats.shield_capacity())
	_shield_lockout -= delta
	_ring_cooldown -= delta
	var now := Time.get_ticks_msec() / 1000.0
	if Input.is_action_just_pressed("magic") and not controls_locked():
		if now - _last_magic_press < DOUBLE_TAP:
			cast_ring()
			_last_magic_press = -10.0
		else:
			_last_magic_press = now
	# No spell, no magic. The server drains magic while it's up (and may
	# refuse to raise it).
	var want := Input.is_action_pressed("magic") and not controls_locked() and _shield_lockout <= 0.0 and stats.gear.spell != null
	if want and not shield.active:
		if _set_shield(true):
			_shield_pool = stats.shield_capacity()
	elif shield.active and (not want or stats.mp <= 0.0):
		_set_shield(false)


func _set_shield(up: bool) -> bool:
	shield.active = GameServer.set_shield(player_id, up)
	return shield.active


## Lava pits burn: armor-piercing damage as soon as you step in, then every
## second you stay.
func _update_lava(delta: float) -> void:
	if not hazard.is_valid() or not is_on_floor() or not hazard.call(global_position):
		_lava_timer = 0.0
		return
	_lava_timer -= delta
	if _lava_timer <= 0.0:
		_lava_timer = LAVA_TICK
		last_hit_by = "Lava"
		take_damage(LAVA_DAMAGE, true)


## Sends out the equipped spell's warped ring, if it has one and there's
## enough magic.
func cast_ring() -> void:
	var spell: Item = stats.gear.spell
	if spell == null or spell.ring.is_empty() or _ring_cooldown > 0.0 or not GameServer.request_ring(player_id):
		return
	_ring_cooldown = maxf(RING_COOLDOWN, spell.ring.get("cooldown", RING_COOLDOWN))
	ring_cast.emit(spell)


## Yaw from the player toward the aim point.
func aim_yaw() -> float:
	var to := _aim_point - global_position
	return atan2(-to.x, -to.z) if Vector2(to.x, to.z).length() > 0.05 else facing


## Where the mouse cursor points in the world: the first thing under it.
func _mouse_point() -> Vector3:
	var mouse := get_viewport().get_mouse_position()
	var from := camera.project_ray_origin(mouse)
	var dir := camera.project_ray_normal(mouse)
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 300.0)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit.position
	var on_plane = Plane(Vector3.UP, global_position.y + SHOT_HEIGHT).intersects_ray(from, dir)
	return on_plane if on_plane != null else global_position


## Lifts the player onto a 1-block ledge if there's room above it.
func _try_step_up(dir: Vector3) -> void:
	var up := Vector3(0, STEP_HEIGHT, 0)
	if test_move(global_transform, up):
		return  # no headroom
	if test_move(global_transform.translated(up), dir.normalized() * 0.3):
		return  # wall is taller than one block
	global_position += up


func _update_zoom(delta: float) -> void:
	_zoom_target = clampf(
			_zoom_target + (0.0 if controls_locked() else Input.get_axis("zoom_in", "zoom_out")) * ZOOM_SPEED * delta,
			ZOOM_MIN, ZOOM_MAX)
	camera_distance = lerpf(camera_distance, _zoom_target, minf(1.0, delta * ZOOM_SMOOTHING))


func set_zoom(distance: float) -> void:
	_zoom_target = distance
	camera_distance = distance
	_camera_reach = distance


func _update_camera(delta: float) -> void:
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
		var close := mid + side * TALK_DISTANCE + Vector3.UP * TALK_HEIGHT - across.normalized() * 0.4
		var k := smoothstep(0.0, 1.0, _talk_blend)
		camera.global_position = from.lerp(close, k)
		var look := target.lerp(mid, k)
		if camera.global_position.distance_to(look) > 0.01:
			camera.look_at(look)
		if talking:
			facing = lerp_angle(facing, atan2(-across.x, -across.z), minf(1.0, delta * 8.0))
			model.rotation.y = facing
	_apply_shake(delta)


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
