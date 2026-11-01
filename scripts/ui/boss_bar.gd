class_name BossBar
extends Control
## The health bar of the boss you're fighting, across the top of the screen:
## its name above a thick framed bar, health in numbers on it, notches where
## its phases change, and a framed miniature of the boss (a live little 3D
## render) at the right end. While its guards protect it the bar is striped
## and says so; during its intro the bar fills up. A sealed boss shows its
## shell's health in stone gray; objectives (guards, conduits, sentinels)
## show as pips under the bar.

const BAR_SIZE := Vector2(620, 34)
const PORTRAIT := 104  # frame size in screen pixels
const FRAME := 6
const TRAIL_SPEED := 0.35  # how fast the white "damage taken" trail catches up (share per second)
const HP_COLOR := Color(0.85, 0.16, 0.24)
const HP_LIGHT := Color(1.0, 0.45, 0.45)
const SHIELD_COLOR := Color(0.45, 0.7, 1.0)
const SHELL_COLOR := Color(0.62, 0.6, 0.58)

var boss: Boss
var _name := Label.new()
var _numbers := Label.new()
var _status := Label.new()
var _shown := 1.0
var _trail := 1.0
var _viewport := SubViewport.new()
var _portrait_model: CreatureModel
var _portrait_pivot := Node3D.new()


func _ready() -> void:
	custom_minimum_size = Vector2(BAR_SIZE.x + PORTRAIT + 14, PORTRAIT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIStyle.text(_name, UIStyle.SIZE_LARGE, Color(0.8, 0.9, 1.0))
	_name.add_theme_font_override("font", UIStyle.bold())
	_name.position = Vector2(0, 2)
	add_child(_name)
	UIStyle.text(_numbers, UIStyle.SIZE_SMALL)
	_numbers.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_numbers.size = Vector2(BAR_SIZE.x, BAR_SIZE.y)
	_numbers.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_numbers)
	UIStyle.text(_status, UIStyle.SIZE_SMALL, SHIELD_COLOR)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.size = Vector2(BAR_SIZE.x, 20)
	add_child(_status)
	_build_portrait()
	hide()


## Shows a boss's bar (null hides it).
func track(p_boss: Boss) -> void:
	if p_boss == null or not is_instance_valid(p_boss):
		boss = null
		hide()
		return
	if p_boss == boss and visible:
		return
	boss = p_boss
	show()
	_name.text = boss.def.enemy_name
	_shown = 0.0
	_trail = 0.0
	_set_portrait_model(boss.def.model)


func _process(delta: float) -> void:
	if boss == null or not is_instance_valid(boss):
		track(null)
		return
	var target := float(boss.hp) / maxf(1.0, boss.max_hp) * boss.intro_progress()
	if boss.is_sealed():
		target = float(boss.shell_hp) / maxf(1.0, boss.shell_max)
	_shown = move_toward(_shown, target, delta * 3.0) if target > _shown else target
	_trail = maxf(_shown, _trail - delta * TRAIL_SPEED) if _trail > _shown else _shown
	if boss.is_sealed():
		_numbers.text = "SEALED  %s / %s" % [_grouped(boss.shell_hp), _grouped(boss.shell_max)]
		_status.text = "Break the shell"
	elif boss.state == Enemy.State.INTRO:
		_numbers.text = "AWAKENING..."
		_status.text = ""
	else:
		_numbers.text = "%s / %s" % [_grouped(boss.hp), _grouped(boss.max_hp)]
		_status.text = boss.bar_status()
	_numbers.position = _bar_origin()
	_status.position = _bar_origin() + Vector2(0, BAR_SIZE.y + FRAME + 2)
	_portrait_pivot.rotation.y += delta * 0.4
	queue_redraw()


func _bar_origin() -> Vector2:
	return Vector2(0, 34)


func _draw() -> void:
	if boss == null:
		return
	var o := _bar_origin()
	var bar := Rect2(o, BAR_SIZE)
	# Frame: dark outline, a bevelled gold-blue rim, then the dark trough.
	draw_rect(bar.grow(FRAME + 3), UIStyle.OUTLINE)
	draw_rect(bar.grow(FRAME), Color(0.32, 0.4, 0.62))
	draw_rect(Rect2(bar.position - Vector2.ONE * FRAME, Vector2(bar.size.x + FRAME * 2, 3)), Color(0.6, 0.72, 0.95))
	draw_rect(bar.grow(3), UIStyle.OUTLINE)
	draw_rect(bar, Color(0.08, 0.06, 0.12))
	# The trail of recent damage, then health, with a light top edge.
	draw_rect(Rect2(o, Vector2(BAR_SIZE.x * _trail, BAR_SIZE.y)), Color(1.0, 0.95, 0.85, 0.85))
	var fill := Rect2(o, Vector2(BAR_SIZE.x * _shown, BAR_SIZE.y))
	var guarded := boss.shielded or boss.immune
	var base := SHELL_COLOR if boss.is_sealed() else SHIELD_COLOR if guarded else HP_COLOR
	draw_rect(fill, base)
	draw_rect(Rect2(o, Vector2(fill.size.x, 6)), (HP_LIGHT if not guarded else Color(0.75, 0.9, 1.0)))
	draw_rect(Rect2(o + Vector2(0, BAR_SIZE.y - 5), Vector2(fill.size.x, 5)), base.darkened(0.35))
	if guarded:
		# Diagonal stripes across the protected bar.
		var t := Time.get_ticks_msec() / 60.0
		for i in range(-4, int(BAR_SIZE.x / 16.0) + 4):
			var x := o.x + i * 16 + fmod(t, 16.0)
			var pts := PackedVector2Array([Vector2(x, o.y + BAR_SIZE.y), Vector2(x + 6, o.y + BAR_SIZE.y),
					Vector2(x + 6 + BAR_SIZE.y * 0.5, o.y), Vector2(x + BAR_SIZE.y * 0.5, o.y)])
			for k in pts.size():
				pts[k].x = clampf(pts[k].x, o.x, o.x + fill.size.x)
			draw_colored_polygon(pts, Color(1, 1, 1, 0.18))
	# Notches where the phases change.
	for p: Dictionary in boss.boss_def.phases:
		var until: float = p.get("until", 0.0)
		if until > 0.0:
			var x := o.x + BAR_SIZE.x * until
			draw_rect(Rect2(x - 2, o.y - 4, 4, BAR_SIZE.y + 8), UIStyle.OUTLINE)
			draw_rect(Rect2(x - 1, o.y - 3, 2, BAR_SIZE.y + 6), Color(0.85, 0.92, 1.0))
	# Objective pips under the bar: bright while alive, dark once destroyed.
	var pips: Array = boss.bar_pips() if not boss.is_sealed() else []
	for i in pips.size():
		var r := Rect2(o + Vector2(i * 22, BAR_SIZE.y + FRAME + 6), Vector2(16, 16))
		draw_rect(r.grow(2), UIStyle.OUTLINE)
		var c: Color = pips[i].color
		draw_rect(r, c if pips[i].alive else c.darkened(0.75))
	# The portrait's frame, joined to the end of the bar.
	var frame := Rect2(Vector2(BAR_SIZE.x + 14, 0), Vector2(PORTRAIT, PORTRAIT))
	draw_rect(Rect2(Vector2(BAR_SIZE.x + FRAME, o.y + 8), Vector2(14, BAR_SIZE.y - 16)), Color(0.32, 0.4, 0.62))
	draw_rect(frame.grow(3), UIStyle.OUTLINE)
	draw_rect(frame, Color(0.32, 0.4, 0.62))
	draw_rect(Rect2(frame.position, Vector2(frame.size.x, 3)), Color(0.6, 0.72, 0.95))
	var inner := frame.grow(-FRAME)
	draw_rect(inner.grow(2), UIStyle.OUTLINE)
	draw_rect(inner, Color(0.06, 0.08, 0.16))
	draw_texture_rect(_viewport.get_texture(), inner, false)


## A small world of its own with the boss model, a light and a camera.
func _build_portrait() -> void:
	_viewport.size = Vector2i.ONE * (PORTRAIT - FRAME * 2) * 2
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_viewport)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.65, 0.8)
	env.environment.glow_enabled = true
	_viewport.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40, 35, 0)
	_viewport.add_child(light)
	_viewport.add_child(_portrait_pivot)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.9, 3.2)
	cam.fov = 40
	_viewport.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 0.1, 0))


func _set_portrait_model(creature: String) -> void:
	if _portrait_model:
		_portrait_model.queue_free()
	_portrait_model = CreatureModel.new(creature)
	_portrait_pivot.add_child(_portrait_model)
	# Fit it to the frame: scale its bounds to about two units across.
	var bounds := AABB()
	var first := true
	for mi: MeshInstance3D in _portrait_model.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh == null:
			continue
		var box := _portrait_model.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var fit := 2.4 / maxf(0.01, maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)))
	_portrait_model.scale = Vector3.ONE * fit
	_portrait_model.position = -bounds.get_center() * fit
	_portrait_model.rotation.y = 0.6


static func _grouped(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out
