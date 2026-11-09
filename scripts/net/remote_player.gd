class_name RemotePlayer
extends AnimatableBody3D
## Another player online, as this client sees them: their archer, their name,
## their gear's aura and their warp shield, moved smoothly along the
## server's snapshots (see NetClient.player_state). With player collision on
## (server.cfg) they're solid: you can't walk through them and your shots stop
## on them; otherwise they're only a picture.

const NAME_HEIGHT := 2.55

var player_id := 0
var solid := false
var model: Node3D = ArcherModel.new()
var class_id := "archer"
var shield := MagicShield.new()
var aura := GearAura.new()
var status_visuals := PlayerStatusVisuals.new()
var buffs := StatusEffects.new()
var _label: Label3D
var _look := PlayerStats.new()
var _gear := ""
var _speed := 0.0
var _have_position := false


func _ready() -> void:
	add_to_group("remote_players")
	sync_to_physics = false
	collision_layer = Player.PLAYER_LAYER if solid else 0
	collision_mask = 0
	if solid:
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.4
		capsule.height = 1.8
		shape.shape = capsule
		shape.position.y = 0.9
		add_child(shape)
	add_child(model)
	var leisure := LeisurePresentation.new()
	leisure.actor = self
	add_child(leisure)
	add_child(shield)
	add_child(aura)
	status_visuals.effects = buffs
	add_child(status_visuals)
	_label = status_visuals.nameplate


## Name, class and gear ("class|id,id,id,id", one id per gear slot).
func set_look(player_name: String, gear: String) -> void:
	status_visuals.player_name = player_name
	if gear == _gear:
		return
	_gear = gear
	var parts := gear.split("|", true, 1)
	if parts.size() == 2:
		_set_class(parts[0])
	var ids := parts[-1].split(",")
	for i in mini(ids.size(), PlayerStats.GEAR_SLOTS.size()):
		_look.gear[PlayerStats.GEAR_SLOTS[i]] = Items.make(ids[i]) if Items.exists(ids[i]) else null
	shield.set_spell(_look.gear.spell)
	aura.refresh(_look)


func _set_class(p_class_id: String) -> void:
	if p_class_id == class_id or not PlayerClasses.exists(p_class_id):
		return
	class_id = p_class_id
	var rot := model.rotation.y
	model.queue_free()
	model = PlayerClasses.make_model(class_id)
	add_child(model)
	model.rotation.y = rot


func shot() -> void:
	model.play_shot()


func _process(delta: float) -> void:
	var s: Array = Net.client.player_state(player_id) if Net.client else []
	if s.is_empty():
		return
	var target: Vector3 = s[0]
	global_basis = Net.client.world.surface_frame(target).basis if Net.client and Net.client.world is SpatialWorld else Basis.IDENTITY
	if not _have_position or global_position.distance_to(target) >= NetClient.PLAYER_TELEPORT_DISTANCE:
		global_position = target
		model.rotation.y = s[1]
		_have_position = true
	else:
		var blend := 1.0 - exp(-25.0 * delta)
		global_position = global_position.lerp(target, blend)
		model.rotation.y = lerp_angle(model.rotation.y, float(s[1]), blend)
	_speed = lerpf(_speed, float(s[2]), minf(1.0, delta * 10.0))
	model.animate(0.0 if buffs.has_effect("static") else _speed, delta)
	if Net.client and Net.client.world is SpaceWorld:
		var seat := (Net.client.world as SpaceWorld).city.seat_of(player_id)
		if seat!="":
			var spec := CityLayout.any_seat(seat)
			global_transform = Transform3D(spec.basis, spec.pos)
			model.rotation.y = float(spec.yaw)
			CityState.seated_pose(model)
	if Net.client and is_instance_valid(Net.client.world):
		var place := Net.client.world
		var fleet: SpaceWorld = place if place is SpaceWorld else place.surface_ships if place is IslandWorld else null
		var vessel := fleet.ship_of(player_id) if fleet else null
		if vessel:
			var seat := vessel.seat_of(player_id)
			var spec := fleet.seat_spec(vessel.slot, seat)
			if not spec.is_empty():
				global_position = spec.pos
				model.rotation.y = float(spec.get("yaw", 0.0))
				CityState.seated_pose(model)
	var seat := Leisure.seat_spec(player_id)
	if not seat.is_empty():
		global_transform = Transform3D(seat.get("basis", Basis.IDENTITY), seat.pos)
		model.rotation.y = float(seat.get("yaw", 0.0))
		CityState.seated_pose(model)
	shield.active = (int(s[3]) & 1) != 0
