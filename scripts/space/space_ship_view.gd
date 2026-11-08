class_name SpaceShipView
extends Node3D
## A ship as clients see it: the hull interpolated between authority
## snapshots (shown slightly in the past), turrets following their gunners,
## engines by speed, a boarding ramp while landed and a burst when lost.
const DELAY := 0.12
var world: SpaceWorld
var ship_id := 0
var hull: ShipHull
var _samples: Array = []  # [time, Transform3D, speed]
var _label: Label3D
var _ramp: SpaceInteraction
var _ship: SpaceShip
var _damage: ShipDamage

func setup(ship: SpaceShip) -> void:
	hull = ShipHull.new()
	add_child(hull)
	hull.build(ship.tint)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font = UIStyle.font()
	_label.font_size = 64
	_label.pixel_size = 0.02
	_label.outline_size = 12
	_label.modulate = ship.tint.lightened(0.3)
	_label.position = Vector3(0, 26, 0)
	_label.no_depth_test = false
	add_child(_label)
	_ramp = SpaceInteraction.new()
	_ramp.world = world
	_ramp.kind = "outside"
	_ramp.ship_id = ship.id
	add_child(_ramp)
	# Outside: the airlock's outer door and the parts mended on the hull.
	var lock := SpaceInteraction.new()
	lock.world = world
	lock.kind = "airlock_out"
	lock.ship_id = ship.id
	lock.position = SpaceWorld.AIRLOCK_OUTSIDE
	add_child(lock)
	for id: String in SpaceShip.PARTS:
		if SpaceShip.PARTS[id].inside: continue
		# Hull plating can be mended from either side.
		for side: float in ([1.0, -1.0] if id=="hull" else [1.0]):
			var mend := SpaceInteraction.new()
			mend.world = world
			mend.kind = "repair_out"
			mend.part = id
			mend.ship_id = ship.id
			mend.position = (SpaceShip.PARTS[id].hull as Vector3)*Vector3(side, 1, 1)
			add_child(mend)
	_damage = ShipDamage.new()
	hull.add_child(_damage)
	global_transform = ship.xform

func push(ship: SpaceShip) -> void:
	_ship = ship
	_samples.append([Time.get_ticks_msec()/1000.0, ship.xform, ship.speed])
	while _samples.size()>12: _samples.pop_front()
	_label.text = ship.name
	_ramp.enabled = ship.mode=="landed"
	var hatch: Transform3D = hull.anchors.get("hatch", Transform3D(Basis.IDENTITY, Vector3(9, -3, 4)))
	_ramp.position = hatch.origin

## The interpolated pose `DELAY` seconds ago.
func pose() -> Transform3D:
	if _samples.is_empty(): return global_transform
	var at := Time.get_ticks_msec()/1000.0-DELAY
	if at<=float(_samples[0][0]): return _samples[0][1]
	for i in range(_samples.size()-1):
		var a: Array = _samples[i]
		var b: Array = _samples[i+1]
		if at<=float(b[0]):
			var k := (at-float(a[0]))/maxf(0.001, float(b[0])-float(a[0]))
			return (a[1] as Transform3D).interpolate_with(b[1], k)
	# Past the newest sample: hold it rather than guessing ahead.
	return _samples[-1][1]

func _process(_delta: float) -> void:
	if _ship==null: return
	global_transform = pose()
	var speed := float(_samples[-1][2]) if not _samples.is_empty() else 0.0
	hull.set_engine(2.0 if speed>SpaceShip.MAX_SPEED+5.0 else clampf(speed/SpaceShip.MAX_SPEED, 0.15, 1.0) if _ship.mode=="flying" else 0.1)
	_label.visible = _ship.mode!="flying" or not _crew_is_local()
	_damage.show_parts(_ship.parts)
	for seat: String in ["turret_top", "turret_left", "turret_right"]:
		var mount := hull.get_node_or_null(_mount_name(seat))
		if mount==null or not _ship.aims.has(seat): continue
		var local := global_basis.inverse()*(_ship.aims[seat] as Vector3)
		var yaw := mount.get_node_or_null("Yaw") as Node3D
		if yaw==null: continue
		var in_mount := (mount as Node3D).basis.inverse()*local
		yaw.rotation.y = atan2(-in_mount.x, -in_mount.z)
		var pitch := yaw.get_node_or_null("Pitch") as Node3D
		if pitch: pitch.rotation.x = clampf(asin(clampf(in_mount.y, -1.0, 1.0)), -0.4, 1.3)

func _mount_name(seat: String) -> String:
	return {turret_top = "Turret_top", turret_left = "Turret_left", turret_right = "Turret_right"}[seat]

func _crew_is_local() -> bool:
	if not is_instance_valid(world.local_player): return false
	return _ship.seat_of(world.local_player.player_id)!="" or SpaceLayout.pocket_at(world.local_player.global_position)==_ship.slot

## World position of a turret's muzzle as drawn (for local bolt effects).
func muzzle(seat: String) -> Vector3:
	var node := hull.get_node_or_null(_mount_name(seat)+"/Yaw/Pitch/Muzzle") as Node3D
	return node.global_position if node else global_position

## Struck: the glitch on the hull where it hit, and a jolt for the crew.
func hit(at: Vector3) -> void:
	ArtGlitch.flash(hull, at, 6.0, 0.6)
	var local := world.local_player
	if is_instance_valid(local) and _ship and (_ship.seat_of(local.player_id)!="" or SpaceLayout.pocket_at(local.global_position)==_ship.slot):
		local.add_trauma(0.35)

func explode() -> void:
	set_process(false)
	var flash := OmniLight3D.new()
	flash.light_color = Color("7dff9a")
	flash.light_energy = 12.0
	flash.omni_range = 80.0
	flash.global_position = global_position
	world.add_child(flash)
	var burst := GPUParticles3D.new()
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 180.0
	process.initial_velocity_min = 12.0
	process.initial_velocity_max = 40.0
	process.gravity = Vector3.ZERO
	process.scale_min = 0.6
	process.scale_max = 2.2
	process.color = Color("ffcf7a")
	burst.process_material = process
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE*0.6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("6a4024")
	mat.emission_enabled = true
	mat.emission = Color("ffb04a")
	mesh.material = mat
	burst.draw_pass_1 = mesh
	burst.amount = 160
	burst.one_shot = true
	burst.explosiveness = 0.95
	burst.lifetime = 3.0
	burst.global_position = global_position
	world.add_child(burst)
	burst.emitting = true
	var tw := world.create_tween()
	tw.tween_property(flash, "light_energy", 0.0, 1.6)
	tw.tween_callback(flash.queue_free)
	world.get_tree().create_timer(4.0).timeout.connect(burst.queue_free)
	queue_free()
