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
	global_position = s[0]
	model.rotation.y = s[1]
	_speed = lerpf(_speed, float(s[2]), minf(1.0, delta * 10.0))
	model.animate(0.0 if buffs.has_effect("static") else _speed, delta)
	shield.active = (int(s[3]) & 1) != 0
