class_name FloatingText
extends Label3D
## Pixel-font numbers that pop up over a creature's head and drift away:
## damage taken ("-34"), healing, and so on. Reusable for any world text.
##
##   FloatingText.spawn(parent, position, "-12", Color.RED)

const RISE := 0.9
const LIFETIME := 0.9

const ENEMY_DAMAGE := Color(1.0, 1.0, 1.0)
const PLAYER_DAMAGE := Color(1.0, 0.25, 0.25)
const PLAYER_PIERCED := Color(1.0, 0.6, 0.15)  # armor-piercing damage


static func spawn(parent: Node, pos: Vector3, text_value: String, color: Color, big := false) -> void:
	if Net.is_server():
		Net.server.fx(parent, pos, ["ft", pos, text_value, color, big])
		return
	var t := FloatingText.new()
	t.text = text_value
	t.modulate = color
	t.font = UIStyle.bold()
	t.font_size = 40 if big else 32
	t.pixel_size = 0.012
	t.outline_size = 10
	t.outline_modulate = Color(0, 0, 0, 0.85)
	t.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	t.no_depth_test = true  # always readable, even behind trees
	t.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	t.render_priority = 10
	parent.add_child(t)
	t.global_position = pos + Vector3(randf_range(-0.25, 0.25), 0, randf_range(-0.25, 0.25))
	t._animate()


func _animate() -> void:
	scale = Vector3.ONE * 0.4
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "global_position:y", global_position.y + RISE, LIFETIME).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "modulate:a", 0.0, LIFETIME * 0.4).set_delay(LIFETIME * 0.6)
	tw.tween_property(self, "outline_modulate:a", 0.0, LIFETIME * 0.4).set_delay(LIFETIME * 0.6)
	tw.chain().tween_callback(queue_free)
