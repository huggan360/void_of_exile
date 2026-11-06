class_name PlayerStatusVisuals
extends Node3D
## Shared local/remote presentation. World-space ice, silence voxels, names and flags.
var effects: StatusEffects
var player_name := ""
var nameplate := Label3D.new()
var _flags := {}
var _revision := -1
var _ice := Node3D.new()
var _quiet := Node3D.new()
var _sparks := Node3D.new()
var _clock := 0.0
var _ice_blend := 0.0
var _quiet_blend := 0.0
var _spark_material := StandardMaterial3D.new()
var _burning := BurningVisuals.new()

func _ready() -> void:
	nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	nameplate.fixed_size = true
	nameplate.position.y = 2.25
	nameplate.font = UIStyle.bold()
	nameplate.font_size = 36
	nameplate.pixel_size = .005
	nameplate.outline_size = 10
	nameplate.modulate = Color(.92,.9,1)
	add_child(nameplate)
	add_child(_ice)
	add_child(_quiet)
	add_child(_sparks)
	add_child(_burning)
	var ice_mat := _material(Color(.38,.79,1,.72),true)
	var frost_mat := _material(Color(.76,.95,1,.9),true)
	for layer in 4:
		for i in 8:
			var angle := TAU*i/8.0+layer*.22
			var size := Vector3(.24+.05*(i%3),.26+.12*((i+layer)%3),.25)
			var cube := _cube(size,ice_mat if i%3 else frost_mat)
			cube.position = Vector3(cos(angle)*(.48-layer*.025),.15+layer*.36,sin(angle)*(.48-layer*.025))
			cube.rotation.y = angle
			_ice.add_child(cube)
	var quiet_mat := _material(Color(.25,.65,1),false)
	for i in 8:
		var cube := _cube(Vector3.ONE*.105,quiet_mat)
		var angle := TAU*i/8.0
		cube.position = Vector3(cos(angle)*.43,1.6,sin(angle)*.43)
		_quiet.add_child(cube)
	# A little crossed seal floating at head height makes Quiet distinct from ice.
	for sign_value in [-1,1]:
		var bar := _cube(Vector3(.36,.06,.06),quiet_mat)
		bar.position = Vector3(0,1.75,.42)
		bar.rotation.z = sign_value*PI*.25
		_quiet.add_child(bar)
	_spark_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in 10:
		var cube := _cube(Vector3.ONE*.055,_spark_material)
		_sparks.add_child(cube)
	_ice.scale = Vector3.ONE*.001
	_quiet.scale = Vector3.ONE*.001

func _process(delta: float) -> void:
	nameplate.text = player_name
	if effects == null: return
	# Authority resolves periodic damage before retiring expired effects.
	if Net.is_client(): effects.tick()
	_burning.effects = effects
	_clock += delta
	_ice_blend = move_toward(_ice_blend,1.0 if effects.has_effect("static") else 0.0,delta*5.0)
	_quiet_blend = move_toward(_quiet_blend,1.0 if effects.has_effect("quiet") else 0.0,delta*6.0)
	_ice.visible = _ice_blend>.001
	_quiet.visible = _quiet_blend>.001
	_ice.scale = Vector3.ONE*maxf(.001,_ice_blend)
	_quiet.scale = Vector3.ONE*maxf(.001,_quiet_blend)
	_quiet.rotation.y = _clock*.65
	if effects.revision != _revision:
		_revision = effects.revision
		_sync_flags()
	var active := effects.active()
	_sparks.visible = not active.is_empty()
	if not active.is_empty():
		var tint: String = StatusEffects.banner(active.back())
		_spark_material.albedo_color = {green=Color(.4,1,.5),red=Color(1,.3,.3),blue=Color(.4,.8,1),purple=Color(.8,.4,1),yellow=Color(1,.85,.3)}[tint]
		for i in _sparks.get_child_count():
			var a := _clock*(.9 if i%2 else -.7)+i*TAU/10.0
			_sparks.get_child(i).position = Vector3(cos(a)*.65,fmod(_clock*.4+i*.18,1.8),sin(a)*.65)

func _sync_flags() -> void:
	var live := {}
	var active := effects.active()
	for i in active.size():
		var e: Dictionary = active[i]
		live[e.key] = true
		var flag: Sprite3D = _flags.get(e.key)
		if flag == null:
			flag = Sprite3D.new()
			flag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			flag.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			flag.pixel_size = .025
			flag.shaded = false
			add_child(flag)
			_flags[e.key] = flag
			flag.scale = Vector3.ONE*.1
			flag.create_tween().tween_property(flag,"scale",Vector3.ONE,.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var row: int = i/4
		var count := mini(4,active.size()-row*4)
		flag.position = Vector3((i%4-(count-1)*.5)*.46,3.0+row*.45,0)
		flag.texture = BuffArt.badge(e)
	for key in _flags.keys():
		if live.has(key): continue
		var flag: Sprite3D = _flags[key]
		_flags.erase(key)
		var tween := flag.create_tween()
		tween.tween_property(flag,"scale",Vector3.ONE*.01,.18)
		tween.tween_callback(flag.queue_free)

func _material(color: Color, transparent: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = .3
	mat.metallic = .15
	if transparent: mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(color.r,color.g,color.b)*.25
	return mat

func _cube(size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var cube := MeshInstance3D.new()
	cube.mesh = mesh
	cube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return cube
