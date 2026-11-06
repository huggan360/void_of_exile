class_name PortalLoadingScreen
extends Control
## A real 3D voxel portal; shader time animates it while async work progresses.
var _where := Label.new()
var _bar := ProgressBar.new()
var _progress := 0.0
var _shown := 0.0
var _view := SubViewport.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UIStyle.theme()
	var background := ColorRect.new()
	var backdrop := ShaderMaterial.new()
	backdrop.shader = preload("res://shaders/void_loading.gdshader")
	background.material = backdrop
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	var portal := SubViewportContainer.new()
	portal.custom_minimum_size = Vector2(300,260)
	portal.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portal.stretch = true
	portal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(portal)
	_view.size = Vector2i(300,260)
	_view.own_world_3d = true
	_view.transparent_bg = true
	_view.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	_view.msaa_3d = Viewport.MSAA_2X
	portal.add_child(_view)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0,0,0,0)
	environment.environment.glow_enabled = true
	environment.environment.glow_intensity = 0.75
	_view.add_child(environment)
	var camera := Camera3D.new()
	camera.position = Vector3(0,0,6.5)
	camera.fov = 32
	_view.add_child(camera)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/loading_portal.gdshader")
	for band in 2:
		var blocks := MultiMeshInstance3D.new()
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		var cube := BoxMesh.new()
		cube.size = Vector3(0.15,0.23,0.15) if band==0 else Vector3(0.07,0.07,0.12)
		multi.mesh = cube
		multi.instance_count = 36 if band==0 else 18
		for i in multi.instance_count:
			var angle := TAU*i/multi.instance_count
			var radius := 1.04 if band==0 else 1.38
			multi.set_instance_transform(i,Transform3D(Basis(Vector3.FORWARD,angle),Vector3(cos(angle)*radius,sin(angle)*radius,0)))
			multi.set_instance_color(i,Color("70ddeb").lerp(Color("9d82ff"),0.5+0.5*sin(angle)))
		blocks.multimesh = multi
		blocks.material_override = material
		_view.add_child(blocks)
	var going := UIStyle.label("TRAVELLING TO",UIStyle.SIZE_SMALL,Color("8395b4"))
	going.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(going)
	UIStyle.text(_where,UIStyle.SIZE_LARGE,Color("dcecff"))
	_where.add_theme_font_override("font",UIStyle.bold())
	_where.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_where)
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(220,4)
	_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var track := StyleBoxFlat.new()
	track.bg_color = Color("111b30")
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("83dbe8")
	_bar.add_theme_stylebox_override("background",track)
	_bar.add_theme_stylebox_override("fill",fill)
	box.add_child(_bar)

func set_destination(place_name: String) -> void:
	set_destination_name(place_name)
	_progress = 0.0
	_shown = 0.0

func set_destination_name(place_name: String) -> void:
	_where.text = place_name

func set_progress(value: float) -> void:
	_progress = maxf(_progress,clampf(value,0.0,1.0))

func _process(delta: float) -> void:
	_shown = lerpf(_shown,_progress,1.0-exp(-delta*7.0))
	_bar.value = _shown*100.0
