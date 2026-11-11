class_name CityPlanet
extends Node3D
## Vesperis on the client (child of its SpacePlanet, so in planet space): its
## three towns of cosy voxel houses (CityHouses) with gardens, parks and lakes
## between the streets, the farmland and the three districts' rooms and props
## (CityDistrict), all built while Space loads like every other planet's town,
## in chunks so far ones are culled; the houses thin to coarser copies far off.
## Up close come the raised sidewalks and collision of the blocks around the
## player and the life in the districts (CityLife: townsfolk and traffic).
const FACADES := ["4a3550", "2c4a52", "6a3a44", "b8a088", "2a2f4a", "7a4058", "3e3a5a", "5a4a3a", "8a6a7a", "34404e"]
const NEON := ["dec69e", "d4bc92", "c1c6b5"]
const DETAIL_ALTITUDE := 1800.0
const COLLIDE_RANGE := 110.0
const CHUNK := 14  # cells a side per skyline chunk (2 x 2 a face: few draw calls)
const DETAIL_RANGE := 520.0
var world: SpaceWorld
var districts := {}  # id -> CityDistrict once built
var life: CityLife
var _detail_started := false
var _detail_shown := false
var _solids := {}  # Vector3i cell -> Array of [Transform3D, Vector3 size, kind]
var _bodies := {}  # Vector3i cell -> Node3D (collision and raised sidewalks)
var _timer := 0.0
var _done := {}  # Vector3i(face, chunk i, chunk j) -> true once built
static var _tower_material: ShaderMaterial
static var _foliage_material: ShaderMaterial
static var _meshes := {}

## Instanced parts: kind -> [transforms, colors, customs]; "d:" kinds are fine
## detail, drawn only up close.
class Batch extends RefCounted:
	var parts := {}
	func add(kind: String, xform: Transform3D, color: Color, custom: Color, detail := false) -> void:
		var key := ("d:" if detail else "")+kind
		if not parts.has(key): parts[key] = [[], [], []]
		parts[key][0].append(xform)
		parts[key][1].append(color)
		parts[key][2].append(custom)
	## Each kind as one packed MultiMesh buffer (transform, colour, custom per
	## instance): handed to the GPU in one go, and what the city cache stores.
	func buffers() -> Dictionary:
		var out := {}
		for key: String in parts:
			var data: Array = parts[key]
			var count: int = data[0].size()
			var buf := PackedFloat32Array()
			buf.resize(count*20)
			for i in count:
				var t: Transform3D = data[0][i]
				var c: Color = data[1][i]
				var u: Color = data[2][i]
				var o := i*20
				buf[o] = t.basis.x.x; buf[o+1] = t.basis.y.x; buf[o+2] = t.basis.z.x; buf[o+3] = t.origin.x
				buf[o+4] = t.basis.x.y; buf[o+5] = t.basis.y.y; buf[o+6] = t.basis.z.y; buf[o+7] = t.origin.y
				buf[o+8] = t.basis.x.z; buf[o+9] = t.basis.y.z; buf[o+10] = t.basis.z.z; buf[o+11] = t.origin.z
				buf[o+12] = c.r; buf[o+13] = c.g; buf[o+14] = c.b; buf[o+15] = c.a
				buf[o+16] = u.r; buf[o+17] = u.g; buf[o+18] = u.b; buf[o+19] = u.a
			out[key] = [count, buf]
		return out
	func flush(parent: Node3D, label: String, far: float, detail_far := CityPlanet.DETAIL_RANGE, packed := {}, cast_shadows := false, cell_size := 0.0) -> void:
		var all := packed if not packed.is_empty() else buffers()
		preload("res://scripts/space/space_map_geometry.gd").publish_packed(parent,all)
		if cell_size>0.0: all = _spatial_buffers(all,cell_size)
		for key: String in all:
			var detail := key.begins_with("d:")
			var multi := MultiMesh.new()
			multi.transform_format = MultiMesh.TRANSFORM_3D
			multi.use_colors = true
			multi.use_custom_data = true
			multi.mesh = CityPlanet.mesh(key.get_slice("@",0).trim_prefix("d:"))
			multi.instance_count = int(all[key][0])
			multi.buffer = all[key][1]
			var node := MultiMeshInstance3D.new()
			node.name = "%s_%s" % [label, key.replace(":", "_").replace("@", "_")]
			node.multimesh = multi
			node.material_override = CityPlanet.foliage_material() if key.contains("vox:") else CityPlanet.tower_material()
			node.visibility_range_end = minf(far, detail_far) if detail else far
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if (cast_shadows or far<2000.0) and not detail else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if key.begins_with("house:"):
				# Voxel buildings: each detail level takes over from the last.
				node.material_override = VoxModel.glow_material() if key.get_slice("@", 0).ends_with(":glow") else VoxModel.material()
				var range := CityHouses.range_of(key)
				node.visibility_range_begin = range.x
				node.visibility_range_end = range.y
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if CityHouses.casts_shadow(key) else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(node)
		parts.clear()

	## Keep real geometry unchanged, but give the renderer local bounds for
	## camera and shadow culling. Whole-district MultiMeshes defeat both.
	func _spatial_buffers(source: Dictionary, cell_size: float) -> Dictionary:
		var groups := {}
		for key: String in source:
			var buffer: PackedFloat32Array = source[key][1]
			for i in int(source[key][0]):
				var offset := i*20
				var origin := Vector3(buffer[offset+3],buffer[offset+7],buffer[offset+11])
				var cell := Vector3i((origin/cell_size).floor())
				var group := "%s@%d_%d_%d" % [key,cell.x,cell.y,cell.z]
				if not groups.has(group): groups[group] = []
				(groups[group] as Array).append(buffer.slice(offset,offset+20))
		var out := {}
		for key: String in groups:
			var buffer := PackedFloat32Array()
			for piece: PackedFloat32Array in groups[key]: buffer.append_array(piece)
			out[key] = [groups[key].size(),buffer]
		return out

## Fine flowers and grass already have voxel colours; extra per-pixel noise
## aliases on their small faces while the camera moves.
static func foliage_material() -> ShaderMaterial:
	if _foliage_material==null:
		_foliage_material = VoxModel.material().duplicate() as ShaderMaterial
		_foliage_material.set_shader_parameter("jitter", 0.0)
	return _foliage_material

static func tower_material() -> ShaderMaterial:
	if _tower_material==null:
		_tower_material = ShaderMaterial.new()
		_tower_material.shader = preload("res://shaders/city_tower.gdshader")
	return _tower_material

static func mesh(kind: String) -> Mesh:
	if kind.begins_with("house:"): return CityHouses.mesh(kind)
	if _meshes.has(kind): return _meshes[kind]
	if kind.begins_with("vox:"):
		# One of the realm's voxel obstacles (obstacles/*.vox) in woodland colours.
		var voxel: Mesh = ObstacleLibrary.get_prefab(kind.trim_prefix("vox:")).meshes_for(Biomes.get_biome(Biomes.WOODS))[0]
		_meshes[kind] = voxel
		return voxel
	var m: Mesh
	match kind:
		"box":
			var box := BoxMesh.new()
			box.size = Vector3.ONE
			m = box
		"cyl", "trunk":
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.32 if kind=="trunk" else 0.5
			cyl.bottom_radius = 0.5
			cyl.height = 1.0
			cyl.radial_segments = 14
			cyl.rings = 1
			m = cyl
		"dome":
			var dome := SphereMesh.new()
			dome.radius = 0.5
			dome.height = 1.0
			dome.radial_segments = 14
			dome.rings = 6
			dome.is_hemisphere = true
			m = dome
		"sphere":
			var sphere := SphereMesh.new()
			sphere.radius = 0.5
			sphere.height = 1.0
			sphere.radial_segments = 12
			sphere.rings = 7
			m = sphere
		"cone":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.5
			cone.height = 1.0
			cone.radial_segments = 10
			m = cone
		"torus", "ring":
			var torus := TorusMesh.new()
			torus.inner_radius = 0.38 if kind=="torus" else 0.28
			torus.outer_radius = 0.5
			torus.rings = 16 if kind=="torus" else 28
			torus.ring_segments = 6
			m = torus
		"tube":
			var tube := CylinderMesh.new()
			tube.top_radius = 0.5
			tube.bottom_radius = 0.5
			tube.height = 1.0
			tube.radial_segments = 28
			tube.rings = 1
			tube.cap_top = false
			tube.cap_bottom = false
			m = tube
	_meshes[kind] = m
	return m

func build() -> void:
	# Everything up front (from the disk cache after the first time), so the
	# city never streams in after Space has loaded.
	for face in 6:
		for cj in range(0, CityLayout.N, CHUNK):
			for ci in range(0, CityLayout.N, CHUNK): _done[Vector3i(face, ci/CHUNK, cj/CHUNK)] = true
	for d: Dictionary in CityLayout.DISTRICTS: _build_town(d)
	_build_country()
	for d: Dictionary in CityLayout.DISTRICTS:
		var district := CityDistrict.new()
		district.name = "District_"+str(d.id)
		district.city = self
		district.data = d
		district.visible = false
		add_child(district)
		district.build()
		districts[d.id] = district

func _start_detail() -> void:
	_detail_started = true
	life = CityLife.new()
	life.city = self
	add_child(life)
	for d: Dictionary in CityLayout.DISTRICTS: life.add_district(d)
	var flora := CountryFlora.new()
	flora.name = "Flora"
	flora.city = self
	add_child(flora)
	CityRoads.texture()

func _process(delta: float) -> void:
	if not FrameTrace.enabled: _update_frame(delta); return
	var started := Time.get_ticks_usec()
	_update_frame(delta)
	FrameTrace.record("city/streaming",started)

func _update_frame(delta: float) -> void:
	var local: Node3D = world.local_player if is_instance_valid(world) else null
	var camera := get_viewport().get_camera_3d()
	var eye := camera.global_position if camera else Vector3.INF
	var close := eye.distance_to(global_position)<CityLayout.radius()+DETAIL_ALTITUDE
	if close and not _detail_started: _start_detail()
	if close != _detail_shown:
		# The houses stay (they thin out by themselves); the districts' rooms
		# and props, the townsfolk and the roadside plants only up close.
		_detail_shown = close
		for district: Node3D in districts.values(): district.visible = close
		if is_instance_valid(life):
			life.visible = close
			life.set_process(close)
		var flora := get_node_or_null("Flora") as Node3D
		if flora:
			flora.visible = close
			flora.set_process(close)
	if not close: return
	_timer -= delta
	if _timer<=0.0 and is_instance_valid(local):
		_timer = 0.25
		_update_collision(to_local(local.global_position))

# --- Skyline ------------------------------------------------------------------------------

## A town from its plan (CityTown): its houses, halls and the Spire, its parks,
## pond and garden trees in one batch (kept on disk after the first time), the
## walls' collision filed by grid cell for _update_collision, and its streets.
func _build_town(d: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "Town_"+str(d.id)
	add_child(holder)
	_streets(d, holder)
	var file := _cache_file(-1, DISTRICTS_INDEX[d.id], 0)
	var kept := _read_cache(file)
	if not kept.is_empty():
		for key: Vector3i in kept.solids: (_solids.get_or_add(key, []) as Array).append_array(kept.solids[key])
		Batch.new().flush(holder, "t", 9000.0, DETAIL_RANGE, kept.buffers, true, 96.0)
		return
	var batch := Batch.new()
	var list: Array = []
	var plan := CityTown.plan(d)
	for h: Dictionary in plan.houses: CityHouses.place(batch, list, str(h.name), CityTown.frame(d, h.at, h.forward))
	for v: Dictionary in CityLayout.venues(d): CityHouses.place(batch, list, str(v.hall), v.frame)
	if not (plan.spire as Dictionary).is_empty():
		CityHouses.place(batch, list, "spire_hall", CityLayout.spire_frame())
		CityHouses.place(batch, list, "spire", CityLayout.spire_frame())
	var lot := CityLayout.ROAD+CityLayout.WALK+1.0
	for role: String in ["parks", "lakes"]:
		for spot: Array in plan[role]:
			var block := CityTown.green_block(d, spot, "lake" if role=="lakes" else "park")
			var art := CityArt.new(batch, block.frame, list)
			var seed := CityLayout.rnd(float(d.seed), int((spot[0] as Vector2).length()))
			if role=="lakes": art.lake(block, lot, seed)
			else: art.park(block, lot, seed, CityLayout.rnd(seed, 5)<0.35)
	for k in (plan.green as Array).size():
		var spot: Array = plan.green[k]
		var art := CityArt.new(batch, CityTown.frame(d, spot[0], Vector2(0, -1)), list)
		art.tree(Vector2.ZERO, float(spot[1]), CityLayout.rnd(float(d.seed), 7000+k))
	var solids := {}
	for solid: Array in list:
		var at: Vector3 = (solid[0] as Transform3D).origin
		var uv := CityLayout.face_uv(at.normalized())
		var key := Vector3i(int(uv[0]), clampi(int(floor((float(uv[1])+1.0)*0.5*CityLayout.N)), 0, CityLayout.N-1),
			clampi(int(floor((float(uv[2])+1.0)*0.5*CityLayout.N)), 0, CityLayout.N-1))
		(solids.get_or_add(key, []) as Array).append(solid)
	for key: Vector3i in solids: (_solids.get_or_add(key, []) as Array).append_array(solids[key])
	var buffers := batch.buffers()
	_write_cache(file, {buffers = buffers, solids = solids})
	batch.flush(holder, "t", 9000.0, DETAIL_RANGE, buffers, true, 96.0)

const DISTRICTS_INDEX := {lanternheart = 0, rosewater = 1, brasswork = 2}

## A town's streets as two meshes laid just over the ground: the sidewalks
## (slabs, a kerb along the road) and over them the cobbled carriageways, so
## where streets meet the cobbles run on cleanly.
func _streets(d: Dictionary, holder: Node3D) -> void:
	var r := CityLayout.radius()
	for road in [false, true]:
		var verts := PackedVector3Array()
		var normals := PackedVector3Array()
		var uvs := PackedVector2Array()
		var uv2s := PackedVector2Array()
		var indices := PackedInt32Array()
		for st: Dictionary in CityTown.plan(d).streets:
			var pts: PackedVector2Array = st.pts
			var half := float(st.half)
			var width := half if road else half+CityTown.WALK
			var first := verts.size()
			for q in pts.size():
				var along := (pts[mini(q+1, pts.size()-1)]-pts[maxi(q-1, 0)]).normalized()
				var across := Vector2(-along.y, along.x)
				for s: float in [-1.0, 1.0]:
					var p := pts[q]+across*s*width
					var dir := CityTown.dir(d, p)
					verts.append(dir*(r+(0.06 if road else 0.035)))
					normals.append(dir)
					uvs.append(p)
					uv2s.append(Vector2(s*width, half))
			for q in pts.size()-1:
				var a := first+q*2
				indices.append_array([a, a+2, a+1, a+1, a+2, a+3])
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_TEX_UV2] = uv2s
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var node := MeshInstance3D.new()
		node.name = "Roads" if road else "Sidewalks"
		node.mesh = mesh
		node.material_override = street_material(road)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = 6000.0
		holder.add_child(node)

static var _street_materials := {}

static func street_material(road: bool) -> ShaderMaterial:
	if not _street_materials.has(road):
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/town_street.gdshader")
		mat.set_shader_parameter("road", road)
		mat.set_shader_parameter("cobble_tex", CityTextures.cobbles())
		mat.set_shader_parameter("slab_tex", CityTextures.slabs())
		mat.set_shader_parameter("kerb_tex", CityTextures.kerb())
		_street_materials[road] = mat
	return _street_materials[road]

## The farmland between the city cores (CityCountryArt): farmsteads, roadside
## trees and the dirt roads. Collision near the player is rebuilt to take them in.
func _build_country() -> void:
	var batch := Batch.new()
	CityCountryArt.build(batch, _solids)
	var holder := Node3D.new()
	holder.name = "Country"
	add_child(holder)
	batch.flush(holder, "farm", 3000.0, 400.0, {}, true, 192.0)
	CityCountryArt.road_meshes(holder)
	for key: Vector3i in _bodies.keys(): _drop_body(key)

# --- The city kept on disk ------------------------------------------------------------------

## Bump when the city's buildings change in a way the scripts' dates won't show.
const CACHE_VERSION := 6
const CACHE_DIR := "user://cache/city/"
static var _cache_tag := ""

## Each chunk's buildings and collision, saved the first time it is built and
## loaded after that; a new game version or edited city scripts make it anew.
static func _cache_file(face: int, ci: int, cj: int) -> String:
	if _cache_tag=="":
		var stamp := "%d|%s" % [CACHE_VERSION, Net.VERSION]
		for path in ["res://scripts/space/city/city_art.gd", "res://scripts/space/city/city_planet.gd", "res://scripts/space/city/city_roads.gd",
				"res://scripts/space/city/city_layout.gd", "res://scripts/space/space_layout.gd", "res://scripts/space/city/city_houses.gd", "res://scripts/space/city/city_town.gd", CityHouses.CATALOG]:
			stamp += "|%d" % FileAccess.get_modified_time(path)
		_cache_tag = stamp.md5_text().substr(0, 10)
		DirAccess.make_dir_recursive_absolute(CACHE_DIR)
		for old in DirAccess.get_files_at(CACHE_DIR):
			if not old.begins_with(_cache_tag): DirAccess.remove_absolute(CACHE_DIR+old)
	return "%s%s_%d_%d_%d.bin" % [CACHE_DIR, _cache_tag, face, ci, cj]

static func _read_cache(file: String) -> Dictionary:
	if not FileAccess.file_exists(file): return {}
	var f := FileAccess.open_compressed(file, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f==null: return {}
	var data: Variant = f.get_var()
	return data if data is Dictionary and data.has("buffers") and data.has("solids") else {}

static func _write_cache(file: String, data: Dictionary) -> void:
	var f := FileAccess.open_compressed(file, FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f: f.store_var(data)

# --- Collision -----------------------------------------------------------------

## Static shapes for the cells within reach of the player (planet-space `at`).
func _update_collision(at: Vector3) -> void:
	if at.length()>CityLayout.radius()+400.0:
		for key: Vector3i in _bodies.keys(): _drop_body(key)
		return
	var uv := CityLayout.face_uv(at.normalized())
	var face := int(uv[0])
	var ci := int(floor((float(uv[1])+1.0)*0.5*CityLayout.N))
	var cj := int(floor((float(uv[2])+1.0)*0.5*CityLayout.N))
	var want := {}
	for dj in range(-2, 3):
		for di in range(-2, 3):
			var i := ci+di
			var j := cj+dj
			if i<0 or j<0 or i>=CityLayout.N or j>=CityLayout.N: continue
			var c := CityLayout.cell(face, i, j)
			if (c.frame as Transform3D).origin.distance_to(at)>COLLIDE_RANGE+40.0: continue
			want[Vector3i(face, i, j)] = true
	for key: Vector3i in _bodies.keys():
		if not want.has(key): _drop_body(key)
	var made := 0
	for key: Vector3i in want:
		if _bodies.has(key) or made>=6 or not _done.has(Vector3i(key.x, key.y/CHUNK, key.z/CHUNK)): continue
		made += 1
		var holder := Node3D.new()
		holder.name = "Near_%d_%d_%d" % [key.x, key.y, key.z]
		add_child(holder)
		_bodies[key] = holder
		var body := StaticBody3D.new()
		body.collision_layer = Player.OBSTACLE_LAYER
		body.collision_mask = 0
		holder.add_child(body)
		for solid: Array in _solids.get(key, []):
			var shape := CollisionShape3D.new()
			var size: Vector3 = solid[1]
			if str(solid[2])=="cyl":
				var cyl := CylinderShape3D.new()
				cyl.radius = size.x*0.5
				cyl.height = size.y
				shape.shape = cyl
			else:
				var box := BoxShape3D.new()
				box.size = size
				shape.shape = box
			shape.transform = solid[0]
			body.add_child(shape)

func _drop_body(key: Vector3i) -> void:
	var body: Node = _bodies[key]
	_bodies.erase(key)
	if is_instance_valid(body): body.queue_free()
