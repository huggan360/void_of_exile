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
## zooms it. The map key (M) opens it large in the middle of the screen.

const LocalMapScript = preload("res://scripts/space/space_local_map.gd")
const PATCH := 16
const ZOOM_MIN := 16.0
const ZOOM_MAX := 160.0
const ART_PIXELS := 88.0  # pixel grid across the whole minimap (x3 screen pixels each)
const MAP_EDGE := 1.0 - 8.0 / ART_PIXELS  # carved stone, brass and inner outline
const MAX_JOBS := 4  # patches being painted in the background at once
const UPLOAD_INTERVAL := 0.2  # seconds between sending newly painted map to the GPU

const ContactsScript = preload("res://scripts/ui/minimap_contacts.gd")
var contacts = ContactsScript.new()
var live_markers: Array[Dictionary] = []
var social: SocialClient
var _space_local: LocalMapScript
var world: GameWorld
var player: Player
var fog_of_war: FogOfWar
var view_radius := 32.0
## Extra markers: [{pos: Vector3, color: Color}]
var markers: Array[Dictionary] = []
var main_route := PackedVector3Array()
var side_route := PackedVector3Array()
var expanded := false
var _art_pixels := ART_PIXELS
var _map_edge := MAP_EDGE
var _small_radius := 32.0

var _map: Image
var _map_tex: ImageTexture
var _back_tex: ImageTexture
var _painted := {}  # Vector2i patch -> true
## The whole map came ready-made (the Surface's baked map): nothing to paint,
## and the big map shows all of it.
var _prebaked := false
var _origin := Vector2.ZERO
var _size := 0
var _rotation := 0.0
var _center := Vector2.ZERO  # world x/z at the minimap's middle (the player)
var _dirty := false
var _upload_timer := 0.0
var _upload_task := -1
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
	_material.set_shader_parameter("frame_color", Color("181818") if UIStyle.TEXTURE_SET=="black" else UIStyle.BG)
	_material.set_shader_parameter("outline_color", Color("080808") if UIStyle.TEXTURE_SET=="black" else UIStyle.OUTLINE)
	_material.set_shader_parameter("frame_tex", UIStyle._skin_texture("stone"))
	_material.set_shader_parameter("brass_color", Color.WHITE if UIStyle.TEXTURE_SET=="black" else UIStyle.GOLD)
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
	set_routes(PackedVector3Array(), PackedVector3Array())
	_finish_tasks()  # workers may still be reading the previous world
	_done.clear()
	if is_instance_valid(_space_local):
		remove_child(_space_local)
		_space_local.free()
		_space_local = null
	_map_rect.show()
	world = p_world
	if world is SpaceWorld and not world is SurfaceShipWorld:
		_space_local = LocalMapScript.new()
		_space_local.world = world
		_space_local.player = player
		_space_local.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(_space_local)
		_map_rect.hide()
		show()
		set_process(true)
		return
	visible = not world is SpatialWorld
	set_process(visible)
	if world is SpatialWorld: return
	_size = world.half_extent * 2
	_origin = Vector2(-world.half_extent, -world.half_extent)
	_map = Image.create_empty(_size, _size, false, Image.FORMAT_RGB8)
	_map.fill(Color(0.04, 0.05, 0.08))
	_prebaked = false
	var whole: Image = world.call("full_map") if world.has_method("full_map") else null
	if whole != null and whole.get_width() == _size:
		_map = whole
		_prebaked = true
	_map_tex = ImageTexture.create_from_image(_map)
	_back_tex = ImageTexture.create_from_image(_map)
	_painted.clear()
	_material.set_shader_parameter("map_tex", _map_tex)
	_material.set_shader_parameter("map_origin", _origin)
	_material.set_shader_parameter("map_size", float(_size))
	var fog_on := world.biome_at(world.spawn_point).fog_of_war_enabled and not _prebaked
	_material.set_shader_parameter("explored_tex", fog_of_war.explored_texture() if fog_on else _all_explored)


## Large mode: `art_pixels` across (x3 screen pixels each), showing further.
func set_expanded(on: bool, art_pixels := ART_PIXELS) -> void:
	if on == expanded and art_pixels == _art_pixels: return
	if on and not expanded:
		_small_radius = view_radius
		view_radius = _whole_radius() if _prebaked else clampf(view_radius * 3.0, ZOOM_MIN, ZOOM_MAX * 3.0)
	elif not on and expanded:
		view_radius = _small_radius
	expanded = on
	_art_pixels = art_pixels if on else ART_PIXELS
	_map_edge = 1.0 - 8.0 / _art_pixels
	custom_minimum_size = Vector2(_art_pixels, _art_pixels) * PixelArt.SCALE
	_material.set_shader_parameter("art_pixels", _art_pixels)
	_material.set_shader_parameter("map_edge", _map_edge)
	queue_redraw()


func zoom(steps: float) -> void:
	var far := (_whole_radius() if _prebaked else ZOOM_MAX * 3.0) if expanded else ZOOM_MAX
	view_radius = clampf(view_radius * pow(1.15, steps), ZOOM_MIN, far)


## Big enough to show every corner of the map from where the player stands.
func _whole_radius() -> float:
	if player == null: return float(_size)
	var p := Vector2(absf(player.global_position.x - (_origin.x + _size * 0.5)), absf(player.global_position.z - (_origin.y + _size * 0.5)))
	return (p + Vector2.ONE * _size * 0.5).length() * 0.98


func set_routes(main: PackedVector3Array, side: PackedVector3Array) -> void:
	var dungeon := is_instance_valid(world) and Dungeons.is_dungeon(world.realm_id)
	main_route = PackedVector3Array() if dungeon else main
	side_route = PackedVector3Array() if dungeon else side
	queue_redraw()


## Rasterize on the same grid as the map, then draw yellow last and omit
## overlapping green pixels. Only actual paths are drawn, never goal rays.
func route_pixels(path: PackedVector3Array) -> Dictionary:
	var pixels := {}
	var radius := ART_PIXELS * 0.5 * MAP_EDGE - 2.0
	for i in range(path.size() - 1):
		var a := _to_art(Vector2(path[i].x, path[i].z) - _center)
		var b := _to_art(Vector2(path[i + 1].x, path[i + 1].z) - _center)
		# Skip distant segments before sampling, keeping long routes cheap.
		if Geometry2D.get_closest_point_to_segment(Vector2.ZERO, a, b).length() > radius + 1: continue
		var steps := maxi(1, ceili(a.distance_to(b) * 1.5))
		for step in range(steps + 1):
			var p := Vector2i(a.lerp(b, float(step) / steps).round())
			if Vector2(p).length() <= radius: pixels[p] = true
	return pixels


func visible_route_pixels() -> Dictionary:
	if is_instance_valid(world) and Dungeons.is_dungeon(world.realm_id): return {main = {}, side = {}}
	var yellow := route_pixels(main_route)
	var green := route_pixels(side_route)
	for p: Vector2i in yellow: green.erase(p)
	return {main = yellow, side = green}


func _draw_routes() -> void:
	var pixels := visible_route_pixels()
	for p: Vector2i in pixels.side: _art_px(Vector2(p), QuestGuide.SIDE_COLOR)
	for p: Vector2i in pixels.main: _art_px(Vector2(p), QuestGuide.MAIN_COLOR)


func _process(delta: float) -> void:
	if not FrameTrace.enabled: _profile_process(delta); return
	var started := Time.get_ticks_usec()
	_profile_process(delta)
	FrameTrace.record("ui/minimap",started)

func _profile_process(delta: float) -> void:
	live_markers = contacts.update(world, player, social, delta, fog_of_war)
	if is_instance_valid(_space_local):
		_space_local.player = player
		_space_local.contacts = live_markers
		_space_local.extra_markers = markers
		visible = _space_local.update_view(view_radius)
		return
	if world == null or player == null:
		return
	var pos := player.global_position
	if _upload_task>=0 and WorkerThreadPool.is_task_completed(_upload_task):
		WorkerThreadPool.wait_for_task_completion(_upload_task)
		_upload_task = -1
		var previous := _map_tex
		_map_tex = _back_tex
		_back_tex = previous
		_material.set_shader_parameter("map_tex",_map_tex)
	var profile_started := Time.get_ticks_usec() if FrameTrace.enabled else 0
	_collect_patches()
	if FrameTrace.enabled: FrameTrace.record("minimap/collect",profile_started)
	profile_started = Time.get_ticks_usec() if FrameTrace.enabled else 0
	_paint_around(pos)
	if FrameTrace.enabled: FrameTrace.record("minimap/paint",profile_started)
	_upload_timer -= delta
	if _dirty and _upload_timer <= 0.0 and _upload_task<0:
		profile_started = Time.get_ticks_usec() if FrameTrace.enabled else 0
		if _upload_task>=0: WorkerThreadPool.wait_for_task_completion(_upload_task)
		# Snapshot mutable painting data; the worker owns its copy and a texture
		# reference until the thread-safe RenderingServer upload finishes.
		# Upload only to the back texture, so the GPU keeps sampling the front.
		_upload_task = WorkerThreadPool.add_task(_upload_snapshot.bind(_back_tex,_map.duplicate()))
		if FrameTrace.enabled: FrameTrace.record("minimap/upload",profile_started)
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
	if world is SpatialWorld: return
	_paint_around(pos)


func _paint_around(pos: Vector3) -> void:
	if _prebaked: return
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


static func _upload_snapshot(texture: ImageTexture, snapshot: Image) -> void:
	RenderingServer.texture_2d_update(texture.get_rid(),snapshot,0)

func _finish_tasks() -> void:
	if _upload_task>=0:
		WorkerThreadPool.wait_for_task_completion(_upload_task)
		_upload_task = -1
	for task in _tasks:
		WorkerThreadPool.wait_for_task_completion(task)
	_tasks.clear()


func _exit_tree() -> void:
	_finish_tasks()


## World offset (x/z) -> minimap position in art pixels from the middle.
func _to_art(world_offset: Vector2) -> Vector2:
	var map_radius_art := _art_pixels * 0.5 * _map_edge
	var rel := world_offset / view_radius
	var c := cos(-_rotation)
	var s := sin(-_rotation)
	return Vector2(rel.x * c - rel.y * s, rel.x * s + rel.y * c) * map_radius_art


func _art_px(art: Vector2, color: Color) -> void:
	var px := PixelArt.SCALE
	var mid := (size / px * 0.5).floor()
	draw_rect(Rect2((mid + art.floor()) * px, Vector2.ONE * px), color)


func _draw() -> void:
	if is_instance_valid(_space_local): return
	if player == null:
		return
	_draw_routes()
	var map_radius_art := _art_pixels * 0.5 * _map_edge - 2.0
	var ordered := markers.duplicate()
	ordered.append_array(live_markers)
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("kind", "") == "quest") < int(b.get("kind", "") == "quest"))
	for m in ordered:
		var a := _to_art(Vector2(m.pos.x - _center.x, m.pos.z - _center.y))
		var kind: String = m.get("kind", "")
		if kind not in ["", "contact"] and a.length() >= map_radius_art - 3.0:
			a = a.normalized() * (map_radius_art - 3.0)  # towns stay on the rim, pointing the way
		if a.length() < map_radius_art - 1.0 or kind not in ["", "contact"]:
			match kind:
				"contact":
					var point: Vector2 = size*0.5+a*PixelArt.SCALE
					draw_circle(point, 4.0, Color("101522"))
					draw_circle(point, 2.8, m.color)
				"home":  # a little house
					for px: Vector2 in [Vector2(0, -3), Vector2(-1, -2), Vector2(0, -2), Vector2(1, -2), Vector2(-2, -1),
							Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(2, -1), Vector2(-1, 0), Vector2(1, 0),
							Vector2(-1, 1), Vector2(1, 1), Vector2(0, 1), Vector2(0, 0)]:
						_art_px(a + px + Vector2(1, 0), Color(0.03, 0.03, 0.06))
					for px: Vector2 in [Vector2(0, -2), Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(-1, 0),
							Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1), Vector2(0, 1)]:
						_art_px(a + px, m.color)
					_art_px(a, Color(1, 1, 1))
				"quest", "side":  # gold main objectives and green side objectives
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
	var north := _to_art(Vector2(0, -1)).normalized() * (_art_pixels * 0.5 * _map_edge - 3.0)
	PixelArt.draw_tiny(self, ((size / PixelArt.SCALE * 0.5).floor() + north.floor() - Vector2(1, 2)) * PixelArt.SCALE,
			"N", UIStyle.GOLD, PixelArt.SCALE)
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
	draw_circle(mid, 2.5, Color.WHITE)
