class_name CityPlanet
extends Node3D
## Vesperis on the client (child of its SpacePlanet, so in planet space): the
## fairytale city over the whole sphere (CityArt: tree houses, crooked towers,
## mushroom houses, parks and lakes on every block the streets leave), the
## farmland and the three districts (CityDistrict) are all built while Space
## loads, like every other planet's town and plants, in chunks so far ones are
## culled. From orbit a light skyline stands in for them. Up close come the
## raised sidewalks and collision of the blocks around the player and the life
## in the districts (CityLife: townsfolk and traffic).
const FACADES := ["4a3550", "2c4a52", "6a3a44", "b8a088", "2a2f4a", "7a4058", "3e3a5a", "5a4a3a", "8a6a7a", "34404e"]
const NEON := ["dec69e", "d4bc92", "c1c6b5"]
const DETAIL_ALTITUDE := 1800.0
const COLLIDE_RANGE := 110.0
const CHUNK := 14  # cells a side per skyline chunk (2 x 2 a face: few draw calls)
const BUDGET_USEC := 2000
const DETAIL_RANGE := 520.0
var world: SpaceWorld
var districts := {}  # id -> CityDistrict once built
var life: CityLife
var _orbit_lod: Node3D
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
	_build_orbit_lod()
	# Everything up front (from the disk cache after the first time), so the
	# city never streams in after Space has loaded.
	for face in 6:
		for cj in range(0, CityLayout.N, CHUNK):
			for ci in range(0, CityLayout.N, CHUNK):
				_build_chunk(face, ci, cj, true)
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

## A few hundred simple instanced silhouettes, ready immediately from the
## Nexus. No citizens, collisions, voxel props or detailed windows at orbit.
func _build_orbit_lod() -> void:
	_orbit_lod = Node3D.new()
	_orbit_lod.name = "OrbitLOD"
	add_child(_orbit_lod)
	for d: Dictionary in CityLayout.DISTRICTS:
		var holder := Node3D.new()
		holder.name = "Skyline_"+str(d.id)
		_orbit_lod.add_child(holder)
		var art := NexusStation.Brush.new(holder, false)
		for item: Dictionary in CityLayout.district_cells(d):
			if item.role in ["park", "lake", "plaza", "port"]: continue
			var cell: Dictionary = item.cell
			var pose: Transform3D = cell.frame
			var seed := CityLayout.rnd(float(cell.seed), 51)
			var height := lerpf(16.0,float(d.tower)*0.8,seed)
			var width := lerpf(9.0,17.0,CityLayout.rnd(seed,4))
			var color := Color(CityArt.PLASTER[int(seed*CityArt.PLASTER.size()) % CityArt.PLASTER.size()])
			art.part("cylinder",pose*Transform3D(Basis.IDENTITY,Vector3(0,height*0.5,0)),Vector3(width,height,width),color)
			art.part("cone",pose*Transform3D(Basis.IDENTITY,Vector3(0,height+width*0.2,0)),Vector3(width*1.1,width*0.4,width*1.1),Color(CityArt.ROOF[0]))
			art.part("box",pose*Transform3D(Basis.IDENTITY,Vector3(0,height*0.7,width*0.5+0.1)),Vector3(width*0.7,0.5,0.15),Color(str(d.neon)),false,0.7)
		art.finish()
		for node in holder.get_children():
			if node is GeometryInstance3D:
				node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED

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
		_detail_shown = close
		for child in get_children():
			if child == _orbit_lod: continue
			if child is Node3D: child.visible = close
		if is_instance_valid(life): life.set_process(close)
		var flora := get_node_or_null("Flora")
		if flora: flora.set_process(close)
	# Orbit and detailed city geometry are exclusive: never draw overlapping
	# proxy buildings through the full-resolution houses.
	_orbit_lod.visible = not close
	if not close: return
	_timer -= delta
	if _timer<=0.0 and is_instance_valid(local):
		_timer = 0.25
		_update_collision(to_local(local.global_position))

# --- Skyline ------------------------------------------------------------------------------

## One chunk of skyline; `now` builds it in one go (while loading) instead of
## a slice a frame.
func _build_chunk(face: int, ci: int, cj: int, now := false) -> void:
	var batch := Batch.new()
	var file := _cache_file(face, ci, cj)
	var kept := _read_cache(file)
	if not kept.is_empty():
		for key: Vector3i in kept.solids: _solids[key] = kept.solids[key]
		_finish_chunk(face, ci, cj, batch, kept.buffers)
		return
	var start := Time.get_ticks_usec()
	for j in range(cj, mini(cj+CHUNK, CityLayout.N)):
		for i in range(ci, mini(ci+CHUNK, CityLayout.N)):
			var r := CityLayout.role(face, i, j)
			if r in ["district", "park", "lake"]: _block(batch, face, i, j, r)
			_island(batch, face, i, j)
			if not now and Time.get_ticks_usec()-start>BUDGET_USEC:
				await get_tree().process_frame
				if not is_inside_tree(): return
				start = Time.get_ticks_usec()
	var buffers := batch.buffers()
	var solids := {}
	for key: Vector3i in _solids:
		if key.x==face and key.y/CHUNK==ci/CHUNK and key.z/CHUNK==cj/CHUNK: solids[key] = _solids[key]
	_write_cache(file, {buffers = buffers, solids = solids})
	_finish_chunk(face, ci, cj, batch, buffers)

func _finish_chunk(face: int, ci: int, cj: int, batch: Batch, buffers: Dictionary) -> void:
	var holder := Node3D.new()
	holder.name = "Skyline_%d_%d_%d" % [face, ci, cj]
	holder.visible = _detail_shown
	_done[Vector3i(face, ci/CHUNK, cj/CHUNK)] = true
	add_child(holder)
	batch.flush(holder, "c", 6000.0, DETAIL_RANGE, buffers, true, 192.0)

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
const CACHE_VERSION := 5
const CACHE_DIR := "user://cache/city/"
static var _cache_tag := ""

## Each chunk's buildings and collision, saved the first time it is built and
## loaded after that; a new game version or edited city scripts make it anew.
static func _cache_file(face: int, ci: int, cj: int) -> String:
	if _cache_tag=="":
		var stamp := "%d|%s" % [CACHE_VERSION, Net.VERSION]
		for path in ["res://scripts/space/city/city_art.gd", "res://scripts/space/city/city_planet.gd", "res://scripts/space/city/city_roads.gd",
				"res://scripts/space/city/city_layout.gd", "res://scripts/space/space_layout.gd"]:
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

## A cell's blocks: buildings on round footprints, or a park or a lake.
func _block(batch: Batch, face: int, i: int, j: int, role: String) -> void:
	var key := Vector3i(face, i, j)
	var solids: Array = []
	var c := CityLayout.cell(face, i, j)
	var lot := CityLayout.ROAD+CityLayout.WALK+1.3
	var settlement: Dictionary = CityLayout.district_of(face, i, j).get("district", {})
	for block: Dictionary in CityRoads.blocks(face, i, j):
		var seed := CityLayout.rnd(float(c.seed), 40+int(block.sub))
		var art := CityArt.new(batch, block.frame, solids)
		match role:
			"park": art.park(block, lot, seed, CityLayout.rnd(seed, 5)<0.35)
			"lake": art.lake(block, lot, seed)
			_:
				var near := role=="district"
				var feet := CityArt.pack(block, lot, seed, 6, 3.0, 9.0)
				for k in feet.size():
					var foot: Array = feet[k]
					var s := CityLayout.rnd(seed, 60+k)
					var tall := lerpf(10.0, 95.0, pow(s, 2.2))*(1.5 if near else 1.0)*(1.0 if k==0 else 0.5)
					art.building(foot[0], float(foot[1]), maxf(tall*float(settlement.get("height_scale", 1.0)), 8.0), CityLayout.rnd(seed, 70+k), CityLayout.architecture(settlement, s), Color(str(settlement.get("neon", "d4bc92"))))
				art.gardens(block, lot, seed, feet)
	if _solids.has(key): (_solids[key] as Array).append_array(solids)
	else: _solids[key] = solids

## A roundabout's island at corner (i, j): a raised lawn, a kerb of stones
## and a big curly tree (or, now and then, a lantern on a plinth).
func _island(batch: Batch, face: int, i: int, j: int) -> void:
	var island := CityRoads.round_at(face, i, j)
	if island<=0.0: return
	var dir := CityRoads.dir(face, i, j)
	var frame := CityLayout._tangent(dir, Vector3.UP if absf(dir.y)<0.9 else Vector3.RIGHT)
	var key := Vector3i(face, mini(i, CityLayout.N-1), mini(j, CityLayout.N-1))
	var solids: Array = _solids.get(key, [])
	_solids[key] = solids
	var art := CityArt.new(batch, frame, solids)
	art.seed = CityLayout.rnd(float(face*1000+i*31+j), 9)
	art.part("cyl", Vector3(0, CityRoads.KERB*0.5, 0), Basis.IDENTITY, Vector3(island*2.0, CityRoads.KERB+0.1, island*2.0), Color("b8b0a8"), CityArt.M_STONE)
	art.part("cyl", Vector3(0, CityRoads.KERB+0.04, 0), Basis.IDENTITY, Vector3(island*2.0-0.8, 0.1, island*2.0-0.8), Color("3a6a42"), CityArt.M_GRASS)
	if art.r()<0.75: art.tree(Vector2.ZERO, lerpf(3.0, 4.2, art.r()), art.seed+0.3)
	else:
		art.part("cyl", Vector3(0, 1.0, 0), Basis.IDENTITY, Vector3(1.6, 1.8, 1.6), Color(CityArt.STONE[0]), CityArt.M_STONE)
		art.part("cyl", Vector3(0, 3.5, 0), Basis.IDENTITY, Vector3(0.35, 3.4, 0.35), Color("d9ac60"))
		art.part("sphere", Vector3(0, 5.6, 0), Basis.IDENTITY, Vector3.ONE*1.3, Color(NEON[int(art.r()*NEON.size()) % NEON.size()]), CityArt.M_GLOW)
		art.solid(Vector3(0, 1.0, 0), Vector3(1.6, 2.0, 1.6))

# --- Collision and raised sidewalks -----------------------------------------------------------------

## Static shapes and kerbed sidewalks for the blocks within reach of the player (planet-space `at`).
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
		_sidewalks(holder, key)

## The sidewalks round a cell's blocks as raised slabs with kerbs, painted by
## the ground shader (slabs on top, kerb stones on the sides), and solid.
func _sidewalks(holder: Node3D, key: Vector3i) -> void:
	var role := CityLayout.role(key.x, key.y, key.z)
	if role=="farm": return
	var r := CityLayout.radius()
	var h := CityRoads.KERB
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	for block: Dictionary in CityRoads.blocks(key.x, key.y, key.z):
		var frame: Transform3D = block.frame
		var outer := CityRoads.outline(block, CityLayout.ROAD, 40, false)
		var inner := CityRoads.outline(block, CityLayout.ROAD+CityLayout.WALK, 40, false)
		if outer.size()!=inner.size() or outer.size()<3: continue
		var at := func(p: Vector2, lift: float) -> Vector3: return (frame*Vector3(p.x, 0, p.y)).normalized()*(r+lift)
		var n := outer.size()
		for k in n:
			var o0: Vector3 = at.call(outer[k], h)
			var o1: Vector3 = at.call(outer[(k+1) % n], h)
			var i0: Vector3 = at.call(inner[k], h)
			var i1: Vector3 = at.call(inner[(k+1) % n], h)
			var up := o0.normalized()
			_quad(verts, normals, o0, o1, i1, i0, up)
			# The kerb's face down to the street, and the step into the courtyard.
			var ob0: Vector3 = at.call(outer[k], -0.05)
			var ob1: Vector3 = at.call(outer[(k+1) % n], -0.05)
			_quad(verts, normals, ob0, ob1, o1, o0, ((o0+o1)*0.5-frame*Vector3(block.seed.x, 0, block.seed.y)).slide(up).normalized())
			var ib0: Vector3 = at.call(inner[k], -0.05)
			var ib1: Vector3 = at.call(inner[(k+1) % n], -0.05)
			_quad(verts, normals, i1, i0, ib0, ib1, (frame*Vector3(block.seed.x, 0, block.seed.y)-(i0+i1)*0.5).slide(up).normalized())
	if verts.is_empty(): return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = PlanetTerrain.material_for(CityLayout.planet())
	holder.add_child(node)
	var body := StaticBody3D.new()
	body.collision_layer = Player.TERRAIN_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var tris := ConcavePolygonShape3D.new()
	tris.set_faces(verts)
	tris.backface_collision = true
	shape.shape = tris
	body.add_child(shape)
	holder.add_child(body)

## Two triangles a, b, c, d facing `normal` (wound to face it).
static func _quad(verts: PackedVector3Array, normals: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	var flip := (b-a).cross(c-a).dot(normal)>0.0
	for p: Vector3 in ([a, c, b, a, d, c] if flip else [a, b, c, a, c, d]):
		verts.append(p)
		normals.append(normal)

func _drop_body(key: Vector3i) -> void:
	var body: Node = _bodies[key]
	_bodies.erase(key)
	if is_instance_valid(body): body.queue_free()
