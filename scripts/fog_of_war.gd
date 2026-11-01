class_name FogOfWar
extends MeshInstance3D
## Hides everything the player hasn't explored yet. Keeps an "explored" map
## (1 texel per block) that gets painted around the player as they move; the
## fog_of_war shader draws fog wherever the map is still dark.
##
## The fog takes the color of the land it covers: a coarse map of every
## biome's fog color (and opacity) is made when a world loads, so fog over
## the desert stays sandy and fog over the forest dark wherever you stand,
## blending softly at the borders.
##
## It is drawn as a soft volume hugging the terrain (a heightmap made at
## load, HEIGHT_CELL blocks a texel), with slowly rolling noise; see the
## shader. Explored land carries no fog at all.

var _image: Image
var _texture: ImageTexture
var _material := ShaderMaterial.new()
var _origin := Vector2.ZERO  # world x/z of texel (0, 0)
var _size := 0
var _radius := 12.0
var _last_cell := Vector2i(1 << 30, 0)
var _dirty := false
var _upload_timer := 0.0
var _strongholds: Array[StrongholdFeature] = []
var _revealed_forts := {}

## Seconds between sending the explored map to the GPU. The clear circle
## around the player is drawn live by the shader, so a short delay here is
## invisible, and it keeps walking smooth.
const UPLOAD_INTERVAL := 0.25
## Blocks per texel of the fog color map (bigger = softer borders between biomes).
const REGION_CELL := 8
## Blocks per texel of the terrain heightmap the fog follows.
const HEIGHT_CELL := 4
## Share of the reveal radius over which freshly explored land fades in.
const SOFT_EDGE := 0.5


func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)  # the shader stretches it over the screen
	mesh = quad
	extra_cull_margin = 16384.0  # never frustum-culled
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material.shader = preload("res://shaders/fog_of_war.gdshader")
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.02
	noise.fractal_octaves = 3
	var noise_tex := NoiseTexture2D.new()
	noise_tex.noise = noise
	noise_tex.width = 256
	noise_tex.height = 256
	noise_tex.seamless = true
	_material.set_shader_parameter("noise_map", noise_tex)
	material_override = _material


## Starts a fresh, fully hidden map. half_extent: playable size from the
## center, in blocks. biome_at: func(pos) -> BiomeDef, to color the fog by
## region (without it the fog takes one color, see set_style).
## height_at: func(x, z) -> ground height, so the fog follows the terrain.
func setup(half_extent: int, biome_at := Callable(), height_at := Callable()) -> void:
	_size = half_extent * 2
	_origin = Vector2(-half_extent, -half_extent)
	_image = Image.create_empty(_size, _size, false, Image.FORMAT_L8)
	_texture = ImageTexture.create_from_image(_image)
	_last_cell = Vector2i(1 << 30, 0)
	_strongholds.clear()
	_revealed_forts.clear()
	_dirty = false
	_material.set_shader_parameter("explored_map", _texture)
	_material.set_shader_parameter("map_origin", _origin)
	_material.set_shader_parameter("map_size", float(_size))
	_material.set_shader_parameter("use_region_map", biome_at.is_valid())
	if biome_at.is_valid():
		_material.set_shader_parameter("region_map", _region_map(biome_at))
	_material.set_shader_parameter("use_height_map", height_at.is_valid())
	if height_at.is_valid():
		_material.set_shader_parameter("height_map", _height_map(height_at))


## Stronghold discovery reveals the whole fortress, including apron and gates.
func set_strongholds(forts: Array[StrongholdFeature]) -> void:
	_strongholds.assign(forts)

func _reveal_strongholds(pos: Vector3) -> void:
	for fort: StrongholdFeature in _strongholds:
		if _revealed_forts.has(fort.center): continue
		var offset := Vector2(pos.x-fort.center.x,pos.z-fort.center.y)
		if maxf(absf(offset.x),absf(offset.y))>StrongholdFeature.WALL_OUTER+1: continue
		_revealed_forts[fort.center] = true
		var area := Rect2i(fort.bounds.position-Vector2i(_origin),fort.bounds.size).grow(8)
		area = area.intersection(Rect2i(Vector2i.ZERO,Vector2i.ONE*_size))
		_image.fill_rect(area,Color.WHITE)
		# Upload now: neither the first step in nor the hatch shot sees stale fog.
		_texture.update(_image)
		_dirty = false
		_upload_timer = UPLOAD_INTERVAL


## Ground height (meters) every HEIGHT_CELL blocks, as a float texture.
func _height_map(height_at: Callable) -> ImageTexture:
	var cells := ceili(float(_size) / HEIGHT_CELL)
	var img := Image.create_empty(cells, cells, false, Image.FORMAT_RF)
	for y in cells:
		for x in cells:
			img.set_pixel(x, y, Color(height_at.call(_origin.x + (x + 0.5) * HEIGHT_CELL, _origin.y + (y + 0.5) * HEIGHT_CELL), 0, 0))
	return ImageTexture.create_from_image(img)


## Each biome's fog color (rgb) and opacity (a), REGION_CELL blocks a texel.
func _region_map(biome_at: Callable) -> ImageTexture:
	var cells := ceili(float(_size) / REGION_CELL)
	var img := Image.create_empty(cells, cells, false, Image.FORMAT_RGBA8)
	for y in cells:
		for x in cells:
			var pos := Vector3(_origin.x + (x + 0.5) * REGION_CELL, 0.0, _origin.y + (y + 0.5) * REGION_CELL)
			var biome: BiomeDef = biome_at.call(pos)
			img.set_pixel(x, y, Color(biome.fog_of_war_color, biome.fog_of_war_opacity))
	return ImageTexture.create_from_image(img)


## The explored map (white = explored), e.g. for the minimap.
func explored_texture() -> ImageTexture:
	return _texture


## Look of the fog; called continuously as biomes blend. With a region map
## only the reveal radius is used (color and opacity come from the map).
func set_style(color: Color, radius: float, opacity: float) -> void:
	_radius = radius
	_material.set_shader_parameter("fog_color", color)
	_material.set_shader_parameter("reveal_radius", radius)
	_material.set_shader_parameter("fog_opacity", opacity)


## Marks the area around pos as explored. Cheap to call every frame: the map is
## only repainted when the player enters a new block.
func reveal_around(pos: Vector3) -> void:
	if _image == null:
		return
	_reveal_strongholds(pos)
	_material.set_shader_parameter("player_pos", Vector2(pos.x, pos.z))
	_upload_timer -= get_process_delta_time()
	if _dirty and _upload_timer <= 0.0:
		_texture.update(_image)
		_dirty = false
		_upload_timer = UPLOAD_INTERVAL
	var cell := Vector2i(floori(pos.x), floori(pos.z))
	if cell == _last_cell:
		return
	_last_cell = cell
	_paint(pos)


## Marks land someone else explored (the party's shared fog).
func reveal_at(pos: Vector3) -> void:
	if _image != null:
		_paint(pos)


func _paint(pos: Vector3) -> void:
	var center := Vector2(pos.x, pos.z) - _origin
	var r := ceili(_radius)
	var soft_edge := _radius * SOFT_EDGE
	for y in range(maxi(0, int(center.y) - r), mini(_size, int(center.y) + r + 1)):
		for x in range(maxi(0, int(center.x) - r), mini(_size, int(center.x) + r + 1)):
			var d := center.distance_to(Vector2(x + 0.5, y + 0.5))
			var v := clampf((_radius - d) / soft_edge, 0.0, 1.0)
			if v > _image.get_pixel(x, y).r:
				_image.set_pixel(x, y, Color(v, v, v))
	_dirty = true
