class_name Minimap
extends Control
## Round pixel-art map in the bottom-right corner. It turns with the camera,
## so "up" on the map is "up" on screen; a smooth white arrow shows where the
## character is and which way they face.
##
## The map is a picture of the world, one pixel per block, that slides and
## turns underneath the arrow (so turning the camera shows its pixels at an
## angle). Patches are painted on background threads (the world's map colors
## are safe to read from any thread) and copied in when ready, so exploring
## never stalls the game. It's painted lazily from the
## world's colors in 16 x 16 block patches as you get near them; areas you
## haven't explored stay dark (it reads the fog-of-war map). The mouse wheel
## zooms it.

const PATCH := 16
const ZOOM_MIN := 16.0
const ZOOM_MAX := 160.0
const ART_PIXELS := 88.0  # pixel grid across the whole minimap (x3 screen pixels each)
const MAP_EDGE := 1.0 - 4.0 / ART_PIXELS  # one blue rim pixel + one outline pixel
const MAX_JOBS := 4  # patches being painted in the background at once
const UPLOAD_INTERVAL := 0.2  # seconds between sending newly painted map to the GPU

var world: GameWorld
var player: Player
var fog_of_war: FogOfWar
var view_radius := 32.0
## Extra markers: [{pos: Vector3, color: Color}]
var markers: Array[Dictionary] = []

var _map: Image
var _map_tex: ImageTexture
var _painted := {}  # Vector2i patch -> true
var _origin := Vector2.ZERO
var _size := 0
var _rotation := 0.0
var _center := Vector2.ZERO  # world x/z at the minimap's middle (the player)
var _dirty := false
var _upload_timer := 0.0
var _tasks: Array[int] = []  # running WorkerThreadPool tasks
var _done: Array = []  # finished [patch, Image], filled by worker threads
var _done_lock := Mutex.new()
var _all_explored: ImageTexture
var _material := ShaderMaterial.new()
var _map_rect := TextureRect.new()


func _init() -> void:
	custom_minimum_size = Vector2(ART_PIXELS, ART_PIXELS) * PixelArt.SCALE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_material.shader = preload("res://shaders/minimap.gdshader")
	_material.set_shader_parameter("art_pixels", ART_PIXELS)
	_material.set_shader_parameter("map_edge", MAP_EDGE)
	_material.set_shader_parameter("frame_color", UIStyle.BG)
	_material.set_shader_parameter("outline_color", UIStyle.OUTLINE)
	_map_rect.material = _material
	_map_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Any texture works here; the shader draws everything.
	var placeholder := Image.create_empty(1, 1, false, Image.FORMAT_L8)
	placeholder.fill(Color.WHITE)
	_all_explored = ImageTexture.create_from_image(placeholder)
	_map_rect.texture = _all_explored
	_map_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_rect.show_behind_parent = true  # markers and the arrow draw on top
	add_child(_map_rect)


## Starts a fresh map for a world.
func setup(p_world: GameWorld) -> void:
	_finish_tasks()  # workers may still be reading the previous world
	_done.clear()
	world = p_world
	_size = world.half_extent * 2
	_origin = Vector2(-world.half_extent, -world.half_extent)
	_map = Image.create_empty(_size, _size, false, Image.FORMAT_RGB8)
	_map.fill(Color(0.04, 0.05, 0.08))
	_map_tex = ImageTexture.create_from_image(_map)
	_painted.clear()
	_material.set_shader_parameter("map_tex", _map_tex)
	_material.set_shader_parameter("map_origin", _origin)
	_material.set_shader_parameter("map_size", float(_size))
	var fog_on := world.biome_at(world.spawn_point).fog_of_war_enabled
	_material.set_shader_parameter("explored_tex", fog_of_war.explored_texture() if fog_on else _all_explored)


func zoom(steps: float) -> void:
	view_radius = clampf(view_radius * pow(1.15, steps), ZOOM_MIN, ZOOM_MAX)


func _process(delta: float) -> void:
	if world == null or player == null:
		return
	var pos := player.global_position
	_collect_patches()
	_paint_around(pos)
	_upload_timer -= delta
	if _dirty and _upload_timer <= 0.0:
		_map_tex.update(_map)
		_dirty = false
		_upload_timer = UPLOAD_INTERVAL
	_rotation = -player.camera_yaw  # screen-up on the map = the camera's forward
	_center = Vector2(pos.x, pos.z)
	_material.set_shader_parameter("center", _center)
	_material.set_shader_parameter("view_radius", view_radius)
	_material.set_shader_parameter("rotation", _rotation)
	queue_redraw()


## Starts background painting for patches near the player (nearest first).
## Land a party member explored: paint the map there too.
func reveal_at(pos: Vector3) -> void:
	_paint_around(pos)


func _paint_around(pos: Vector3) -> void:
	for i in range(_tasks.size() - 1, -1, -1):
		if WorkerThreadPool.is_task_completed(_tasks[i]):
			WorkerThreadPool.wait_for_task_completion(_tasks[i])
			_tasks.remove_at(i)
	if _tasks.size() >= MAX_JOBS:
		return
	var reach := int(view_radius) + PATCH * 2  # paint a bit beyond the edge, before it shows
	var center := Vector2i(floori(pos.x) >> 4, floori(pos.z) >> 4)
	var n := reach / PATCH + 1
	var wanted: Array[Vector2i] = []
	for dz in range(-n, n + 1):
		for dx in range(-n, n + 1):
			var patch := center + Vector2i(dx, dz)
			if not _painted.has(patch) and _patch_on_map(patch):
				wanted.append(patch)
	wanted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - center).length_squared() < (b - center).length_squared())
	for patch in wanted.slice(0, MAX_JOBS - _tasks.size()):
		_painted[patch] = true
		_tasks.append(WorkerThreadPool.add_task(_paint_patch.bind(patch, world)))


func _patch_on_map(patch: Vector2i) -> bool:
	var p := patch * PATCH - Vector2i(_origin)
	return p.x > -PATCH and p.y > -PATCH and p.x < _size and p.y < _size


## Runs on a worker thread: paints one patch into its own small image.
func _paint_patch(patch: Vector2i, source: GameWorld) -> void:
	var img := Image.create_empty(PATCH, PATCH, false, Image.FORMAT_RGB8)
	for z in PATCH:
		for x in PATCH:
			img.set_pixel(x, z, source.map_color(patch.x * PATCH + x, patch.y * PATCH + z))
	_done_lock.lock()
	_done.append([patch, img])
	_done_lock.unlock()


## Copies finished patches into the map (main thread).
func _collect_patches() -> void:
	_done_lock.lock()
	var finished := _done.duplicate()
	_done.clear()
	_done_lock.unlock()
	for entry in finished:
		var dst := Vector2i(entry[0]) * PATCH - Vector2i(_origin)
		_map.blit_rect(entry[1], Rect2i(0, 0, PATCH, PATCH), dst)
		_dirty = true


func _finish_tasks() -> void:
	for task in _tasks:
		WorkerThreadPool.wait_for_task_completion(task)
	_tasks.clear()


func _exit_tree() -> void:
	_finish_tasks()


## World offset (x/z) -> minimap position in art pixels from the middle.
func _to_art(world_offset: Vector2) -> Vector2:
	var map_radius_art := ART_PIXELS * 0.5 * MAP_EDGE
	var rel := world_offset / view_radius
	var c := cos(-_rotation)
	var s := sin(-_rotation)
	return Vector2(rel.x * c - rel.y * s, rel.x * s + rel.y * c) * map_radius_art


func _art_px(art: Vector2, color: Color) -> void:
	var px := PixelArt.SCALE
	var mid := (size / px * 0.5).floor()
	draw_rect(Rect2((mid + art.floor()) * px, Vector2.ONE * px), color)


func _draw() -> void:
	if player == null:
		return
	var map_radius_art := ART_PIXELS * 0.5 * MAP_EDGE - 2.0
	for m in markers:
		var a := _to_art(Vector2(m.pos.x - _center.x, m.pos.z - _center.y))
		var kind: String = m.get("kind", "")
		if kind != "" and a.length() >= map_radius_art - 3.0:
			a = a.normalized() * (map_radius_art - 3.0)  # towns stay on the rim, pointing the way
		if a.length() < map_radius_art - 1.0 or kind != "":
			match kind:
				"home":  # a little house
					for px: Vector2 in [Vector2(0, -3), Vector2(-1, -2), Vector2(0, -2), Vector2(1, -2), Vector2(-2, -1),
							Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(2, -1), Vector2(-1, 0), Vector2(1, 0),
							Vector2(-1, 1), Vector2(1, 1), Vector2(0, 1), Vector2(0, 0)]:
						_art_px(a + px + Vector2(1, 0), Color(0.03, 0.03, 0.06))
					for px: Vector2 in [Vector2(0, -2), Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(-1, 0),
							Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1), Vector2(0, 1)]:
						_art_px(a + px, m.color)
					_art_px(a, Color(1, 1, 1))
				"quest", "side":  # a diamond: gold for the story, cream for side quests
					var r := 3 if kind == "quest" else 2
					for y in range(-r - 1, r + 2):
						for x in range(-r - 1, r + 2):
							var d := absi(x) + absi(y)
							if d <= r + 1:
								_art_px(a + Vector2(x, y), Color(0.03, 0.03, 0.06) if d > r else m.color if d > 0 else Color(1, 1, 1))
				"town":  # a square in the town's color
					for y in range(-2, 3):
						for x in range(-2, 3):
							_art_px(a + Vector2(x, y), Color(0.03, 0.03, 0.06) if absi(x) == 2 or absi(y) == 2 else m.color)
				_:
					for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
						_art_px(a + d, Color(0.03, 0.03, 0.06))
					_art_px(a, m.color)
	# North marker just inside the thin rim.
	var north := _to_art(Vector2(0, -1)).normalized() * (ART_PIXELS * 0.5 * MAP_EDGE - 3.0)
	PixelArt.draw_tiny(self, ((size / PixelArt.SCALE * 0.5).floor() + north.floor() - Vector2(1, 2)) * PixelArt.SCALE,
			"N", Color(0.9, 0.2, 0.3), PixelArt.SCALE)
	_draw_facing_arrow()


## Smooth white arrow at the character's spot, pointing the way they face.
func _draw_facing_arrow() -> void:
	var here := _to_art(Vector2(player.global_position.x, player.global_position.z) - _center)
	var mid := size * 0.5 + here * PixelArt.SCALE
	var forward := Vector2(-sin(player.facing), -cos(player.facing))  # world x/z
	var dir := _to_art(forward).normalized()
	var side := dir.orthogonal()
	var length := 11.0
	var tip := mid + dir * length
	var shape := PackedVector2Array([
		tip,
		mid - dir * length * 0.7 + side * length * 0.75,
		mid - dir * length * 0.3,
		mid - dir * length * 0.7 - side * length * 0.75,
	])
	draw_colored_polygon(shape, Color(0.02, 0.02, 0.05, 0.85))  # soft shadow / outline
	var inner := PackedVector2Array()
	for p in shape:
		inner.append(mid + (p - mid) * 0.78 - Vector2(0, 1))
	draw_polyline(shape + PackedVector2Array([shape[0]]), Color(0.02, 0.02, 0.05), 3.0, true)
	draw_colored_polygon(inner, Color.WHITE)
