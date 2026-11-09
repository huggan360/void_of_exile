class_name QuestMarker
extends Node3D
## Tiny emissive pixel badges, visible even in the Deep Dark.

@export var height := 0.0
var _kind := "main"
var _sprite: Sprite3D
var _material: StandardMaterial3D
var _time := 0.0
static var _textures := {}


func _init(p_kind := "main") -> void:
	_kind = p_kind


func _ready() -> void:
	height = model_top(get_parent()) + 1.35
	_sprite = Sprite3D.new()
	_sprite.fixed_size = true
	_sprite.pixel_size = 0.0007
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_material.alpha_scissor_threshold = 0.5
	_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_material.fixed_size = true
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.emission_enabled = true
	_material.emission = Color(1.0, 0.84, 0.45)
	_sprite.material_override = _material
	add_child(_sprite)
	set_kind(_kind)
	_process(0.0)


func set_kind(kind: String) -> void:
	_kind = kind if kind in ["main", "side", "turn_in", "port", "nexus"] else "main"
	if not is_instance_valid(_sprite):
		return
	if not _textures.has(_kind):
		_textures[_kind] = _make_texture(_kind)
	_sprite.texture = _textures[_kind]
	_material.emission = Color(1.0, 0.62, 0.56) if _kind == "port" else Color(1.0, 0.6, 0.9) if _kind == "nexus" else Color(1.0, 0.84, 0.45)
	_material.albedo_texture = _sprite.texture
	_material.emission_texture = _sprite.texture


func _process(delta: float) -> void:
	_time += delta
	if is_instance_valid(_sprite):
		_sprite.position.y = height + sin(_time * 2.2) * 0.09
		_material.emission_energy_multiplier = 0.45 + (sin(_time * 1.6) + 1.0) * 0.18


static func _make_texture(kind: String) -> ImageTexture:
	var image := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	# A port in Space is the same badge in red, with a little ship in it;
	# the Nexus is the same in pink.
	var nexus := kind == "nexus"
	var port := kind == "port" or nexus
	var edge := Color("4a1640") if nexus else Color("4a1616") if port else Color("49301d")
	if kind != "side":
		for y in range(24):
			for x in range(24):
				var distance := Vector2(x - 11.5, y - 11.5).length()
				if distance <= 11.5:
					var color := edge
					if distance < 10.0:
						if nexus: color = Color("e04aa8") if y > 11 else Color("ff8ad4")
						elif port: color = Color("d8453c") if y > 11 else Color("ff7a68")
						else: color = Color("f3be3c") if y > 11 else Color("ffe078")
					image.set_pixel(x, y, color)
	var glyph := ["01110", "01110", "01110", "01110", "01110", "00100", "00000", "01110", "01110"]
	if kind == "turn_in":
		glyph = ["01110", "11011", "00011", "00110", "01100", "01100", "00000", "01100", "01100"]
	elif port:
		glyph = ["00100", "00110", "00111", "00110", "00100", "00100", "11111", "11111", "01110"]
	var points: Array[Vector2i] = []
	for y in range(glyph.size()):
		for x in range(5):
			if glyph[y][x] == "1":
				for dy in range(2):
					for dx in range(2):
						points.append(Vector2i(7 + x * 2 + dx, 3 + y * 2 + dy))
	for point in points:
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			image.set_pixelv(point + offset, edge)
	for point in points:
		image.set_pixelv(point, Color("fff4cf") if kind == "side" else Color("fff0e6") if port else Color("fff1a0"))
	return ImageTexture.create_from_image(image)


## Bounds in the marked root's space, including scaled and articulated models.
## Ignore badges, labels and effects so adding a second marker cannot raise it.
static func model_top(root: Node3D) -> float:
	var top := 0.0
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var bounds := mesh.get_aabb()
		var relative := root.global_transform.affine_inverse() * mesh.global_transform
		for corner in 8:
			top = maxf(top, (relative * bounds.get_endpoint(corner)).y)
	if root is Enemy:
		top = maxf(top, root.def.body_height * root.def.model_scale)
	return top
