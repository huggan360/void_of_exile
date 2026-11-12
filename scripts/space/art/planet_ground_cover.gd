class_name PlanetGroundCover
extends Node3D
## What grows underfoot on a planet (clients only), like the Surface's ground
## cover: the Surface's voxel grass, flowers and ferns tinted for each world
## and the world's own small things (petals, shards, shells, bones, spore
## caps; PlanetFlora.SETS `cover`), bushes on a coarser grid, reeds and lilies
## at the water. Planted in tiles on each cube face's ground coordinates round
## the camera, worked out on worker threads; tiles come as the camera nears
## and go when it leaves. Everything sways and leans away from the crew and
## the creatures near the camera (surface_flora.gdshader).
const FACES: Array[Vector3] = [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]
## [tile size (m), reach (m), sample step (m)]: grass and small things, bushes.
const LEVELS := [[12.0, 54.0, 0.62], [32.0, 110.0, 2.2]]
const SCAN_EVERY := 0.25
const MAX_TASKS := 3

var planet: Dictionary
var _radius := 1.0
var _set: Dictionary
var _cover: Array = []  # [kind, cumulative weight, tint]
var _sand: Array = []
var _cover_total := 1.0
var _sand_total := 1.0
var _bushes: Dictionary = {}
var _bare: Array = []  # [dir, cos of the bare radius]: pads, plazas, the fortress floor
var _tiles := {}  # Vector4i(level, face, ti, tj) -> Node3D, or null while it is worked out
var _tasks: Array = []  # [task id, key, result]
var _queue: Array = []
var _scan := 0.0
var _last_eye := Vector3.INF
var _pushers := PackedVector4Array()
static var _kinds := {}  # "planet|kind" -> spec

func setup(p: Dictionary) -> void:
	planet = p
	_radius = float(p.radius)
	_set = PlanetFlora.SETS.get(p.id, {})
	var total := 0.0
	for entry: Array in _set.get("cover", []):
		total += float(entry[1])
		_cover.append([str(entry[0]), total, Color(str(entry[2]))])
	_cover_total = maxf(total, 0.001)
	total = 0.0
	for entry: Array in _set.get("sand", []):
		total += float(entry[1])
		_sand.append([str(entry[0]), total, Color(str(entry[2]))])
	_sand_total = maxf(total, 0.001)
	_bushes = _set.get("bushes", {})
	# Paved and built-on ground stays bare.
	var add := func(dir: Vector3, arc: float) -> void: _bare.append([dir, cos(arc/_radius)])
	add.call(SpaceLayout.pad_frame(p).basis.y, 30.0)
	add.call(SpaceLayout.place_frame_raw(p, SpaceLayout.dock_offset(p)), 30.0)
	add.call(SpaceLayout.place_frame_raw(p, SpaceLayout.town_offset(p)), 19.5)
	if SpaceLayout.FORTS.has(p.id): add.call(SpaceLayout.place_frame_raw(p, SpaceLayout.fort_offset(p)), SpaceLayout.FORT_FLAT)
	for v: Dictionary in SpaceLayout.settlements(p):
		if str(v.kind)=="large": add.call(v.dir, 18.5)
	_pushers.resize(24)
	SpaceLayout.surface_height(p, Vector3.UP)  # warm the caches before threads read them

func _exit_tree() -> void:
	for task: Array in _tasks: WorkerThreadPool.wait_for_task_completion(task[0])
	_tasks.clear()

func _process(delta: float) -> void:
	if planet.is_empty(): return
	_finish_tasks()
	var camera := get_viewport().get_camera_3d()
	if camera==null: return
	var eye := global_transform.affine_inverse()*camera.global_position
	var near := eye.length()<_radius+SpaceLayout.max_height(planet)+90.0
	visible = near
	if not near:
		if not _tiles.is_empty(): _clear_all()
		return
	_update_pushers(camera.global_position)
	_scan -= delta
	if _scan<=0.0:
		_scan = SCAN_EVERY
		if eye.distance_squared_to(_last_eye)>9.0:
			_last_eye = eye
			_schedule(eye)
	while _tasks.size()<MAX_TASKS and not _queue.is_empty():
		var key: Vector4i = _queue.pop_front()[1]
		if not _tiles.has(key) or _tiles[key]!=null: continue
		var result := {}
		var id := WorkerThreadPool.add_task(_work.bind(key, result))
		_tasks.append([id, key, result])

func _clear_all() -> void:
	for node: Variant in _tiles.values():
		if node!=null and is_instance_valid(node): (node as Node).queue_free()
	_tiles.clear()
	_queue.clear()
	_last_eye = Vector3.INF

# --- Tiles ----------------------------------------------------------------------------

func _schedule(eye: Vector3) -> void:
	var ground := eye.normalized()*_radius
	var want := {}
	for level in LEVELS.size():
		var tile: float = LEVELS[level][0]
		var reach: float = LEVELS[level][1]
		for face in 6:
			var n: Vector3 = FACES[face]
			if eye.normalized().dot(n)<0.3: continue
			var ax := Vector3(n.y, n.z, n.x)
			var bx := n.cross(ax)
			var at := Vector2(ground.dot(ax), ground.dot(bx))
			for tj in range(floori((at.y-reach)/tile), floori((at.y+reach)/tile)+1):
				for ti in range(floori((at.x-reach)/tile), floori((at.x+reach)/tile)+1):
					var mid := Vector2((ti+0.5)*tile, (tj+0.5)*tile)
					if mid.length()>_radius*0.9: continue
					var d := _point(face, mid).distance_to(ground)
					if d<reach+tile*0.5: want[Vector4i(level, face, ti, tj)] = d
	for key: Vector4i in _tiles.keys():
		if want.has(key): continue
		var node: Variant = _tiles[key]
		if node!=null and is_instance_valid(node): (node as Node).queue_free()
		_tiles.erase(key)
	_queue.clear()
	for key: Vector4i in want:
		if not _tiles.has(key): _tiles[key] = null
		if _tiles[key]==null: _queue.append([float(want[key])*(1.0 if key.x==0 else 1.5), key])
	_queue.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0])<float(b[0]))

func _finish_tasks() -> void:
	for i in range(_tasks.size()-1, -1, -1):
		var task: Array = _tasks[i]
		if not WorkerThreadPool.is_task_completed(task[0]): continue
		WorkerThreadPool.wait_for_task_completion(task[0])
		_tasks.remove_at(i)
		var key: Vector4i = task[1]
		if not _tiles.has(key) or _tiles[key]!=null: continue
		var holder := Node3D.new()
		add_child(holder)
		var groups: Dictionary = task[2]
		for kind: String in groups: holder.add_child(_batch(kind, groups[kind]))
		_tiles[key] = holder

## A point on the ground of `face` at its ground coordinates `ab` (planet
## space, on the base sphere).
func _point(face: int, ab: Vector2) -> Vector3:
	var n: Vector3 = FACES[face]
	var ax := Vector3(n.y, n.z, n.x)
	var bx := n.cross(ax)
	return ax*ab.x+bx*ab.y+n*sqrt(maxf(_radius*_radius-ab.length_squared(), 0.0))

static func _face_of(dir: Vector3) -> int:
	var best := 0
	for f in 6:
		if dir.dot(FACES[f])>dir.dot(FACES[best]): best = f
	return best

static func _hash(a: int, b: int, c: int) -> float:
	var h := (a*73856093) ^ (b*19349663) ^ (c*83492791)
	h = (h ^ (h >> 13))*1274126177
	return float((h ^ (h >> 16)) & 0xffffff)/16777216.0

# --- What grows (worker threads) -------------------------------------------------------

## Fills `out` with {kind: [[position, up, yaw, size, tint]...]} for tile `key`.
func _work(key: Vector4i, out: Dictionary) -> void:
	var level := key.x
	var face := key.y
	var tile: float = LEVELS[level][0]
	var step: float = LEVELS[level][2]
	var steps := int(tile/step)
	var water := SpaceLayout.water_level(planet)
	var salt := absi(str(planet.id).hash()) % 9973
	for j in steps:
		for i in steps:
			var gi := key.z*steps+i
			var gj := key.w*steps+j
			var hx := _hash(gi, gj, salt+level*7+1)
			var hz := _hash(gi, gj, salt+level*7+2)
			var h := _hash(gi, gj, salt+level*7+3)
			var h2 := _hash(gi, gj, salt+level*7+4)
			var ab := Vector2((key.z+(i+hx)/steps)*tile, (key.w+(j+hz)/steps)*tile)
			var dir := _point(face, ab).normalized()
			if _face_of(dir)!=face or _is_bare(dir): continue
			if level==1:
				_bush(out, dir, h, h2, water)
				continue
			var height := SpaceLayout.surface_height(planet, dir)
			var pos := dir*(_radius+height)
			if not is_nan(water):
				var depth := water-height
				if depth>0.0:
					var wet: Array = _set.get("wet", [])
					if depth>0.35 and depth<1.6 and h<0.012 and wet.size()>1: _put(out, str(wet[1]), dir*(_radius+water-0.03), dir, h2*TAU, 0.9+h*8.0, Color.WHITE)
					continue
				if depth> -0.7:
					var wet: Array = _set.get("wet", [])
					if not wet.is_empty() and h<0.3: _put(out, str(wet[0]), pos, dir, h2*TAU, 0.8+h, Color.WHITE)
					continue
				if not _sand.is_empty() and height<water+3.0:
					if h<float(_set.density)*0.5: _pick_put(out, _sand, _sand_total, h2, pos, dir, hx)
					continue
			if h>=float(_set.density): continue
			_pick_put(out, _cover, _cover_total, h2, pos, dir, hx)

func _pick_put(out: Dictionary, table: Array, total: float, roll: float, pos: Vector3, dir: Vector3, size_roll: float) -> void:
	var at := roll*total
	for entry: Array in table:
		if at<=float(entry[1]):
			var tone := Color(entry[2])*Color(0.92+size_roll*0.16, 0.92+fposmod(roll*7.0, 1.0)*0.16, 0.92+fposmod(roll*13.0, 1.0)*0.12)
			_put(out, str(entry[0]), pos, dir, fposmod(roll*29.0, 1.0)*TAU, 0.85+size_roll*0.45, tone)
			return

func _bush(out: Dictionary, dir: Vector3, h: float, h2: float, water: float) -> void:
	if _bushes.is_empty() or h>=0.05: return
	var height := SpaceLayout.surface_height(planet, dir)
	if not is_nan(water) and height<water+0.6: return
	var total := 0.0
	for w: float in _bushes.values(): total += w
	var at := h2*total
	for name: String in _bushes:
		at -= float(_bushes[name])
		if at<=0.0:
			_put(out, "vox:"+name, dir*(_radius+height-0.05), dir, fposmod(h2*31.0, 1.0)*TAU, 0.75+fposmod(h2*17.0, 1.0)*0.5, Color.WHITE)
			return

func _is_bare(dir: Vector3) -> bool:
	for spot: Array in _bare:
		if dir.dot(spot[0])>float(spot[1]): return true
	return false

static func _put(out: Dictionary, kind: String, pos: Vector3, up: Vector3, yaw: float, size: float, tint: Color) -> void:
	if not out.has(kind): out[kind] = []
	out[kind].append([pos, up, yaw, size, tint])

# --- Meshes (main thread) --------------------------------------------------------------

func _batch(kind: String, list: Array) -> MultiMeshInstance3D:
	var spec := _kind(kind)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = spec.mesh
	mm.instance_count = list.size()
	var unit: float = spec.unit
	var offset: Vector3 = spec.offset
	for k in list.size():
		var e: Array = list[k]
		var up: Vector3 = e[1]
		var right := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD))<0.95 else Vector3.RIGHT).normalized()
		var basis := Basis(right, up, right.cross(up)).rotated(up, float(e[2])).scaled_local(Vector3.ONE*float(e[3])*unit)
		mm.set_instance_transform(k, Transform3D(basis, (e[0] as Vector3)+basis*offset))
		mm.set_instance_custom_data(k, e[4])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = SurfaceFlora.material()
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if spec.shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = spec.far
	mmi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	mmi.set_instance_shader_parameter("sway", spec.sway)
	mmi.set_instance_shader_parameter("height", spec.height)
	mmi.set_instance_shader_parameter("fade_end", spec.far)
	mmi.set_instance_shader_parameter("glow", spec.glow)
	return mmi

## A kind's mesh and how it moves: the Surface's own plants, or a voxel
## prefab ("vox:<name>") coloured for this world.
func _kind(kind: String) -> Dictionary:
	if not kind.begins_with("vox:"): return SurfaceFlora._kind(kind)
	var key := "%s|%s" % [planet.id, kind]
	if _kinds.has(key): return _kinds[key]
	var name := kind.trim_prefix("vox:")
	var prefab := ObstacleLibrary.get_prefab(name)
	var meshes := prefab.meshes_for(PlanetFlora.biome_for(planet))
	var spec := {unit = prefab.voxel_size, offset = prefab.mesh_offset()/prefab.voxel_size, height = float(prefab.size.y), glow = 0.0,
		mesh = meshes[1] if meshes[0]==null else meshes[0]}
	if meshes[0]==null: spec.glow = 2.5
	var file := name.get_file()
	var rigid := file.begins_with("rock") or file.begins_with("fine_stone") or file.contains("shard") or file.contains("pebble") or file.contains("shell") \
		or file.contains("bone") or file.contains("obsidian") or file in ["stump", "fine_lilies", "crystal_blue", "fine_moss_stone", "fine_sand_stone", "fine_starfish"]
	spec.sway = 0.0 if rigid else 0.12 if file.contains("bush") else 0.35
	var small := file.begins_with("fine") or file.begins_with("decor")
	spec.far = SurfaceFlora.GRASS_FAR+10.0 if small else SurfaceFlora.BUSH_FAR
	spec.shadow = not small
	if file in ["decor_glow_sprouts", "fine_glow_caps", "fine_ghost_sprouts", "fine_spore_caps", "fine_storm_sparks"]: spec.glow = 2.0
	_kinds[key] = spec
	return spec

## Who the plants lean away from: players and creatures near the camera.
func _update_pushers(eye: Vector3) -> void:
	var found: Array = []
	for node in get_tree().get_nodes_in_group("local_player")+get_tree().get_nodes_in_group("remote_players"):
		var body := node as Node3D
		if body and body.is_visible_in_tree() and body.global_position.distance_squared_to(eye)<4900.0: found.append([body.global_position, 0.75])
	for node in get_tree().get_nodes_in_group("realm_creatures"):
		var creature := node as Enemy
		if creature==null or not creature.is_inside_tree(): continue
		var at := creature.global_position
		if at.distance_squared_to(eye)>4900.0: continue
		var size := 0.6
		if creature.def: size = maxf(0.5, creature.def.hit_radius*creature.def.model_scale+0.25)
		found.append([at, size])
	found.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector3).distance_squared_to(eye)<(b[0] as Vector3).distance_squared_to(eye))
	for i in _pushers.size():
		if i<found.size():
			var p: Vector3 = found[i][0]
			_pushers[i] = Vector4(p.x, p.y, p.z, found[i][1])
		else:
			_pushers[i] = Vector4.ZERO
	SurfaceFlora.set_pushers(_pushers)
