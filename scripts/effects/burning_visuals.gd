class_name BurningVisuals
extends Node3D
## Presentation only; the owning actor's authority resolves damage and water.
var effects: StatusEffects
var character_height := 1.8
var show_icon := false
var _fire: VoxelFire
var _icon: Sprite3D

func _ready() -> void:
	if Net.is_server(): set_process(false)

func _process(_delta: float) -> void:
	var active := effects != null and effects.has_effect("burning")
	if active and not is_instance_valid(_fire):
		_fire = VoxelFire.new(clampf(character_height*0.55,0.8,3.0))
		_fire.contact_burn = false
		_fire.set_meta("burning_character",true)
		var actor := get_parent()
		while actor != null:
			if actor.is_in_group("remote_players"):
				_fire.set_meta("ally_fire",true)
				break
			actor = actor.get_parent()
		_fire.position.y = character_height*0.15
		add_child(_fire)
	elif not active and is_instance_valid(_fire):
		_fire.queue_free()
		_fire = null
	if active and show_icon and _icon == null:
		_icon = Sprite3D.new()
		_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_icon.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		_icon.pixel_size = 0.025
		_icon.shaded = false
		_icon.texture = BuffArt.badge({id="burning",amount=1})
		_icon.position.y = character_height+0.65
		add_child(_icon)
	if _icon != null: _icon.visible = active
