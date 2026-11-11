class_name InkLoadingScreen
extends Control
## Pure 2D ink-on-black travel: six authored firing poses played at five FPS.
const WEAPONS := ["bow", "wand", "trident"]
const FPS := 5.0
var _where := Label.new()
var _art := TextureRect.new()
var _vine := LoadingVine.new()
var _footsteps := LoadingFootsteps.new()
var _progress := 0.0
var _shown := 0.0
var _elapsed := 0.0
var _frame := -1
var _variant := 0
var _frames: Array = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UIStyle.theme()
	var background := ColorRect.new()
	background.color = Color("080808")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	add_child(_footsteps)
	_footsteps.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 640
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)
	_art.custom_minimum_size = Vector2(480,300)
	_art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ink := ShaderMaterial.new()
	ink.shader = preload("res://shaders/loading_stipple.gdshader")
	_art.material = ink
	box.add_child(_art)
	UIStyle.text(_where,48,Color.WHITE)
	_where.add_theme_font_override("font",UIStyle.bold())
	_where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_where.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_where)
	_vine.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_vine)
	_build_frames()
	_select_variant(_rng.randi_range(0,2))
	visibility_changed.connect(_visibility_changed)
	set_process(is_visible_in_tree())

func _build_frames() -> void:
	for weapon: String in WEAPONS:
		var texture: Texture2D = load("res://assets/ui/black/loading/"+weapon+".png")
		var cell := texture.get_size()/Vector2(3,2)
		var frames: Array[AtlasTexture] = []
		for i in 6:
			var origin := Vector2(i%3,i/3)*cell
			var region := Rect2(origin,cell)
			# Tight vertical crops keep the slender weapons readable at menu scale.
			if weapon!="bow":
				region.position.y += cell.y*0.25
				region.size.y *= 0.5
			var frame := AtlasTexture.new()
			frame.atlas = texture
			frame.region = region
			frame.filter_clip = true
			frames.append(frame)
		_frames.append(frames)

func _select_variant(index: int) -> void:
	_variant = index
	_frame = -1
	_elapsed = 0.0
	_show_frame(0)

func _show_frame(index: int) -> void:
	if _frames.is_empty() or index==_frame: return
	_frame = index
	_art.texture = _frames[_variant][index]

func set_destination(place_name: String) -> void:
	set_destination_name(place_name)
	_progress = 0.0
	_shown = 0.0
	_vine.progress = 0.0
	_select_variant(_rng.randi_range(0,2))
	_footsteps.reset_trails()

func set_destination_name(place_name: String) -> void:
	_where.text = place_name

func set_progress(value: float) -> void:
	_progress = maxf(_progress,clampf(value,0.0,1.0))

func _visibility_changed() -> void:
	set_process(is_visible_in_tree())

func _process(delta: float) -> void:
	_elapsed += delta
	_show_frame(int(floor(_elapsed*FPS))%6)
	_shown = move_toward(_shown,1.0,delta*2.0) if _progress==1.0 else lerpf(_shown,_progress,1.0-exp(-delta*7.0))
	_vine.progress = _shown
	_footsteps.advance(delta)
