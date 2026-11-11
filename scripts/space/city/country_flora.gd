class_name CountryFlora
extends Node3D
## The standing farmland round the camera on Vesperis (client only): voxel
## wheat in its rows, green crops (ferns), meadow grass and flowers, hedge
## bushes and trees, the realm's own voxel obstacles (obstacles/*.vox) in
## woodland colours. Planted in tiles on each cube face's ground coordinates
## from CityCountry.field(), the CPU twin of the painted fields, so every plant
## stands in its painted field; nothing grows on roads, yards or cities
## (CityCountry.masked). Tiles come in as the camera nears and go when it
## leaves; crops and grass sway and lean away from the player and the cows.
var city: CityPlanet
## Three rings: [name, tile size (m), reach (m), slot step (m)].
# Build beyond the visible rings, so plants are ready before they are revealed.
const LEVELS := [["crops", 12.0, 96.0, 1.0], ["hedges", 32.0, 170.0, 1.6], ["trees", 64.0, 400.0, 8.0], ["distant_crops", 24.0, 180.0, 2.0]]
const FADE_RANGES := [Vector3(0, 48, 72), Vector3(0, 110, 140), Vector3(0, 300, 360), Vector3(40, 110, 150)]
const TREES := ["tree_round", "tree_small", "tree_tall", "tree_round", "pine"]
const BUDGET_USEC := 1500
var _tiles := {}  # Vector4i(level, face, ti, tj) -> Node3D (or null while building)
var _queue: Array = []  # [distance, key]
var _scan := 0.0
var _scheduled_eye := Vector3.INF
var _building := false
var _fading: Array = []
static var _kinds := {}  # kind -> {mesh, offset, unit, height, sway, material}

func _process(delta: float) -> void:
	if not FrameTrace.enabled: _update_frame(delta); return
	var started := Time.get_ticks_usec()
	_update_frame(delta)
	FrameTrace.record("city/flora",started)

func _update_frame(delta: float) -> void:
	for entry: Dictionary in _fading.duplicate():
		# Streaming can free a tile before its fade finishes; check before casting.
		if not is_instance_valid(entry.node):
			_fading.erase(entry)
			continue
		var node := entry.node as MultiMeshInstance3D
		if node.is_queued_for_deletion():
			_fading.erase(entry)
			continue
		entry.weight = minf(1.0, float(entry.weight)+delta/0.8)
		node.set_instance_shader_parameter("tile_visibility", entry.weight)
		if entry.weight>=1.0: _fading.erase(entry)
	var camera := get_viewport().get_camera_3d()
	if camera==null: return
	var center: Vector3 = CityLayout.planet().center
	var eye := camera.global_position-center
	var shown := eye.length()<CityLayout.radius()+320.0
	visible = shown
	if not shown: return
	_scan -= delta
	if _scan<=0.0:
		_scan = 0.2
		if eye.distance_squared_to(_scheduled_eye)>16.0:
			_scheduled_eye = eye
			_schedule(eye)
	if not _building and not _queue.is_empty():
		var next: Array = _queue.pop_front()
		if _tiles.has(next[1]) and _tiles[next[1]]==null: _build(next[1])
	var pushers := _pushers()
	for kind: String in _kinds:
		var spec: Dictionary = _kinds[kind]
		if float(spec.sway)>0.0: (spec.material as ShaderMaterial).set_shader_parameter("pushers", pushers)

# --- Tiles --------------------------------------------------------------------------------

## Wanted tiles round the camera (planet-space `eye`), nearest first; far ones go.
func _schedule(eye: Vector3) -> void:
	var r := CityLayout.radius()
	var ground := eye.normalized()*r
	var want := {}
	for level in LEVELS.size():
		var tile: float = LEVELS[level][1]
		var reach: float = LEVELS[level][2]
		for face in 6:
			var n: Vector3 = CityLayout.FACES[face]
			if eye.normalized().dot(n)<0.3: continue
			var ax := Vector3(n.y, n.z, n.x)
			var bx := n.cross(ax)
			var at := Vector2(ground.dot(ax), ground.dot(bx))
			for tj in range(floori((at.y-reach)/tile), floori((at.y+reach)/tile)+1):
				for ti in range(floori((at.x-reach)/tile), floori((at.x+reach)/tile)+1):
					var mid := Vector2((ti+0.5)*tile, (tj+0.5)*tile)
					if mid.length()>r*0.9: continue
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
		if _tiles[key]==null: _queue.append([float(want[key])*(0.7 if key.x==3 else 1.0 if key.x==0 else 1.6), key])
	_queue.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0])<float(b[0]))

## A point on the ground of `face` at its ground coordinates `ab` (planet space).
static func _point(face: int, ab: Vector2) -> Vector3:
	var n: Vector3 = CityLayout.FACES[face]
	var ax := Vector3(n.y, n.z, n.x)
	var bx := n.cross(ax)
	var r := CityLayout.radius()
	return ax*ab.x+bx*ab.y+n*sqrt(maxf(r*r-ab.length_squared(), 0.0))

static func _face_of(dir: Vector3) -> int:
	var best := 0
	for f in 6:
		if dir.dot(CityLayout.FACES[f])>dir.dot(CityLayout.FACES[best]): best = f
	return best

func _tile_inside_city(key: Vector4i) -> bool:
	var tile: float = LEVELS[key.x][1]
	var city_id := ""
	for corner: Vector2 in [Vector2.ZERO,Vector2.RIGHT,Vector2.DOWN,Vector2.ONE]:
		var p := _point(key.y,(Vector2(key.z,key.w)+corner)*tile)
		var uv := CityLayout.face_uv(p.normalized())
		var i := floori((float(uv[1])+1.0)*0.5*CityLayout.N)
		var j := floori((float(uv[2])+1.0)*0.5*CityLayout.N)
		var district := CityLayout.district_of(int(uv[0]),i,j)
		if district.is_empty(): return false
		var id := str(district.district.id)
		if city_id!="" and city_id!=id: return false
		city_id = id
	return true

## Plants one tile, a slice at a time across frames.
func _build(key: Vector4i) -> void:
	_building = true
	var level := key.x
	var face := key.y
	var tile: float = LEVELS[level][1]
	var step: float = LEVELS[level][3]
	# Country crops never grow inside a city core. A tile wholly within one
	# rectangular district is already covered by its gardens/parks; avoid
	# sampling hundreds of masked planting positions just to build an empty tile.
	if _tile_inside_city(key):
		var empty := Node3D.new()
		add_child(empty)
		_tiles[key] = empty
		_building = false
		return
	var count := int(round(tile/step))
	var lists := {}  # kind -> Array[Transform3D]
	var start := Time.get_ticks_usec()
	for j in count:
		for i in count:
			var ab := Vector2(key.z*tile+(i+0.5)*step, key.w*tile+(j+0.5)*step)
			var h := CityCountry.hash3i(Vector3i(roundi(ab.x*8.0), roundi(ab.y*8.0), face*3+level), 9)
			match level:
				0: _crops(lists, face, ab, h)
				3: _crops(lists, face, ab, h)
				1: _hedge(lists, face, ab+(Vector2(h.x, h.y)-Vector2(0.5, 0.5))*0.6, h)
				_: _trees(lists, face, ab+(Vector2(h.x, h.y)-Vector2(0.5, 0.5))*5.0, h)
		if Time.get_ticks_usec()-start>BUDGET_USEC:
			await get_tree().process_frame
			start = Time.get_ticks_usec()
			if not is_inside_tree() or not _tiles.has(key):
				_building = false
				return
	var holder := Node3D.new()
	holder.name = "Tile_%d_%d_%d_%d" % [key.x, key.y, key.z, key.w]
	add_child(holder)
	for kind: String in lists:
		var spec := _kind(kind)
		var list: Array = lists[kind]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = spec.mesh
		multi.instance_count = list.size()
		for k in list.size(): multi.set_instance_transform(k, list[k])
		var node := MultiMeshInstance3D.new()
		node.multimesh = multi
		node.material_override = spec.material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if level==2 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Per-plant distance blending avoids showing or hiding an entire tile at once.
		var fade: Vector3 = FADE_RANGES[level]
		node.set_instance_shader_parameter("detail_near", fade.x)
		node.set_instance_shader_parameter("detail_far_start", fade.y)
		node.set_instance_shader_parameter("detail_far_end", fade.z)
		node.set_instance_shader_parameter("tile_visibility", 0.0)
		_fading.append({node = node, weight = 0.0})
		node.visibility_range_end = float(LEVELS[level][2])+float(LEVELS[level][1])
		holder.add_child(node)
	_tiles[key] = holder
	_building = false

## A plant's pose (planet space): standing on the ground at `p`, turned by
## `yaw`, `size` times its natural size.
static func _pose(kind: String, p: Vector3, yaw: float, size: float) -> Transform3D:
	var spec := _kind(kind)
	var up := p.normalized()
	var right := up.cross(Vector3.FORWARD if absf(up.z)<0.9 else Vector3.RIGHT).normalized()
	var basis := (Basis(right, up, right.cross(up))*Basis(Vector3.UP, yaw)).scaled_local(Vector3.ONE*float(spec.unit)*size)
	return Transform3D(basis, p+basis*(spec.offset as Vector3))

func _add(lists: Dictionary, kind: String, p: Vector3, yaw: float, size: float) -> void:
	if not lists.has(kind): lists[kind] = []
	lists[kind].append(_pose(kind, p, yaw, size))

## The near ring: wheat in its rows, green crops, meadow grass and flowers,
## grass along the hedges.
func _crops(lists: Dictionary, face: int, ab: Vector2, h: Vector3) -> void:
	var p := _point(face, ab)
	if _face_of(p)!=face or CityCountry.masked(p.normalized(), 0.8): return
	var info := CityCountry.field(p)
	var kind: int = info[0]
	var edge: float = info[1]
	var hedged: bool = info[2]
	if hedged and edge<1.6:
		if edge>0.8 and h.y<0.5: _add(lists, "vox:decor_tuft", p, h.z*TAU, lerpf(0.9, 1.4, h.x))
		return
	match kind:
		0:
			for sub in 4:
				var s := ab+Vector2(sub % 2-0.5, sub/2-0.5)*0.5
				if CityCountry.row(s, info[4])<0.2: continue
				_add(lists, "wheat_%d" % ((sub+int(h.x*3.0)) % 3), _point(face, s), float((sub+int(h.y*4.0)) % 4)*PI*0.5, lerpf(0.9, 1.12, fposmod(h.z*7.0+sub*0.37, 1.0)))
		1:
			if CityCountry.row(ab, info[4])<0.55: _add(lists, "vox:decor_fern", p, h.z*TAU, lerpf(1.0, 1.35, h.x))
		3:
			if h.x<0.65:
				var decor := "vox:decor_tuft" if h.y<0.55 else "vox:decor_flowers" if h.y<0.85 else "vox:decor_dry_grass"
				_add(lists, decor, p, h.z*TAU, lerpf(0.9, 1.5, h.x))
		_:
			if h.x<0.03: _add(lists, "vox:decor_pebbles", p, h.z*TAU, 1.0)

## The middle ring: bushes along the hedges.
func _hedge(lists: Dictionary, face: int, ab: Vector2, h: Vector3) -> void:
	var p := _point(face, ab)
	if _face_of(p)!=face or CityCountry.masked(p.normalized(), 1.5): return
	var info := CityCountry.field(p)
	if not info[2] or float(info[1])>0.8: return
	if h.y<0.05: _add(lists, "vox:tree_small", p, h.z*TAU, lerpf(0.8, 1.1, h.x))
	else: _add(lists, "vox:bush", p, h.z*TAU, lerpf(0.85, 1.3, h.x))

## The far ring: trees along the hedges and now and then in a meadow.
func _trees(lists: Dictionary, face: int, ab: Vector2, h: Vector3) -> void:
	var p := _point(face, ab)
	if _face_of(p)!=face or CityCountry.masked(p.normalized(), 5.0): return
	var info := CityCountry.field(p)
	var kind: int = info[0]
	if not ((info[2] and float(info[1])<2.5 and h.x<0.3) or (kind==3 and h.x<0.06)): return
	_add(lists, "vox:"+str(TREES[int(h.y*TREES.size()) % TREES.size()]), p, h.z*TAU, lerpf(0.85, 1.3, fposmod(h.x*11.0, 1.0)))

## Who the crops lean away from: the local player and the cows near the camera.
func _pushers() -> PackedVector4Array:
	var out := PackedVector4Array()
	out.resize(8)
	var k := 0
	var local: Node3D = city.world.local_player if is_instance_valid(city.world) else null
	if is_instance_valid(local):
		out[k] = Vector4(local.global_position.x, local.global_position.y, local.global_position.z, 1.1)
		k += 1
	if is_instance_valid(city.life):
		for cow: Dictionary in city.life._cows:
			if k>=8: break
			if is_instance_valid(cow.node):
				var at: Vector3 = (cow.node as Node3D).global_position
				out[k] = Vector4(at.x, at.y, at.z, 1.5)
				k += 1
	return out

# --- What grows ---------------------------------------------------------------------------

## A plant kind's mesh, where its base sits, its unit size (m per mesh unit),
## height (mesh units), how far its top sways and its material.
static func _kind(kind: String) -> Dictionary:
	if _kinds.has(kind): return _kinds[kind]
	var mesh: Mesh
	var unit := 0.1
	var sway := 0.0
	if kind.begins_with("wheat_"):
		mesh = _wheat(int(kind.trim_prefix("wheat_")))
		sway = 0.9
	else:
		var name := kind.trim_prefix("vox:")
		mesh = CityPlanet.mesh(kind)
		unit = ObstacleLibrary.get_prefab(name).voxel_size
		sway = 0.0 if name.begins_with("tree") or name=="pine" else 0.15 if name=="bush" else 0.45
	var box := mesh.get_aabb()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/farm_sway.gdshader")
	mat.set_shader_parameter("planet_center", CityLayout.planet().center)
	mat.set_shader_parameter("height", box.end.y)
	mat.set_shader_parameter("sway", sway)
	var spec := {mesh = mesh, offset = -Vector3(box.position.x+box.size.x*0.5, box.position.y, box.position.z+box.size.z*0.5),
		unit = unit, height = box.end.y, sway = sway, material = mat}
	_kinds[kind] = spec
	return spec

## A 0.5 m patch of wheat in voxels (1 unit = 10 cm): four stalks, each with
## a golden ear; three variants of height and colour.
static func _wheat(variant: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stalk: Color = [Color("a8853a"), Color("b8923f"), Color("9c7a34")][variant]
	var ear: Color = [Color("f0cf6a"), Color("e6bc52"), Color("f5d97c")][variant]
	var spots := [Vector2(1, 1), Vector2(3, 1), Vector2(1, 3), Vector2(3, 3)]
	for k in 4:
		var at: Vector2 = spots[k]
		var tall := 7+(k+variant) % 3
		_box(st, Vector3(at.x, 0, at.y), Vector3(at.x+1, tall, at.y+1), stalk)
		_box(st, Vector3(at.x-0.5, tall, at.y-0.5), Vector3(at.x+1.5, tall+3, at.y+1.5), ear if (k+variant) % 2 else ear.darkened(0.08))
	st.index()
	st.generate_normals()
	return st.commit()

## An axis box from `lo` to `hi` (no bottom face), one colour.
static func _box(st: SurfaceTool, lo: Vector3, hi: Vector3, color: Color) -> void:
	var c := [Vector3(lo.x, lo.y, lo.z), Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, lo.y, hi.z), Vector3(lo.x, lo.y, hi.z),
		Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]
	st.set_color(color)
	for quad: Array in [[4, 5, 6, 7], [0, 4, 7, 3], [1, 2, 6, 5], [0, 1, 5, 4], [3, 7, 6, 2]]:
		var a: Vector3 = c[quad[0]]
		var b: Vector3 = c[quad[1]]
		var d: Vector3 = c[quad[2]]
		var e: Vector3 = c[quad[3]]
		for v: Vector3 in [a, b, d, a, d, e]: st.add_vertex(v)
