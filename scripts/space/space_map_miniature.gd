class_name SpaceMapMiniature
extends RefCounted
## Terrain uses the same deterministic heights, palette, and materials as play.
## Decorations share their live meshes, without copying scripts or physics.
static var _meshes := {}
var viewport: SubViewport
var camera: Camera3D
var planet: Dictionary
var extent := 1.0
var _yaw := INF
var _tilt := INF
var _art_stamp := -1
var _copies: Array[GeometryInstance3D] = []

func build(parent: Node, p: Dictionary, world: SpaceWorld) -> void:
	planet = p
	extent = float(p.radius)+SpaceLayout.max_height(p)+(240.0 if p.get("city",false) else 40.0)
	viewport = SubViewport.new()
	viewport.size = Vector2i(256,256)
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	parent.add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("c7d3dc")
	environment.environment.ambient_light_energy = 0.7
	viewport.add_child(environment)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45,-30,0)
	light.light_energy = 1.0
	viewport.add_child(light)
	var surface := MeshInstance3D.new()
	surface.mesh = terrain_mesh(p)
	surface.position = p.center
	surface.material_override = PlanetTerrain.material_for(p)
	viewport.add_child(surface)
	refresh_art(world)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = extent*2.0
	camera.near = 1.0
	camera.far = extent*8.0
	viewport.add_child(camera)
	camera.make_current()

## Refresh only when streamed visual holders change, at most once per chart frame.
func refresh_art(world: SpaceWorld) -> bool:
	var actual: SpacePlanet = world.planets.get(str(planet.id))
	if not is_instance_valid(actual): return false
	var city := actual.get_node_or_null("City")
	var stamp := actual.get_child_count()+(city.get_child_count()*997 if city!=null else 0)
	if stamp==_art_stamp: return false
	_art_stamp = stamp
	for copy: GeometryInstance3D in _copies:
		if is_instance_valid(copy): copy.free()
	_copies.clear()
	_copy_art(actual)
	if is_instance_valid(world.gates):
		for entry: Dictionary in world.gates.entries.values():
			if str(entry.fort.planet)==str(planet.id): _copy_art(entry.root)
	_yaw = INF
	return true

func _copy_art(source: Node) -> void:
	var pending: Array[Node] = [source]
	var count := 0
	# Vesperis is a whole city of parts: draw all of it, not its far stand-in.
	var cap := 4000 if planet.get("city", false) else 240
	while not pending.is_empty() and count<cap:
		var node: Node = pending.pop_back()
		if node is PlanetTerrain or node is CountryFlora or node is CityLife or str(node.name)=="OrbitLOD": continue
		for child: Node in node.get_children(): pending.append(child)
		var copy: GeometryInstance3D
		if node is MeshInstance3D:
			var mesh := MeshInstance3D.new()
			mesh.mesh = node.mesh
			copy = mesh
		elif node is MultiMeshInstance3D:
			var mesh := MultiMeshInstance3D.new()
			mesh.multimesh = node.multimesh
			copy = mesh
		else: continue
		copy.transform = (node as Node3D).global_transform
		copy.material_override = node.material_override
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		viewport.add_child(copy)
		_copies.append(copy)
		count += 1

func update_view(yaw: float, tilt: float) -> void:
	if is_equal_approx(yaw,_yaw) and is_equal_approx(tilt,_tilt): return
	_yaw = yaw
	_tilt = tilt
	var back := Vector3(0,cos(tilt),sin(tilt)).rotated(Vector3.UP,-yaw)
	var up := Vector3(0,sin(tilt),-cos(tilt)).rotated(Vector3.UP,-yaw)
	camera.global_position = (planet.center as Vector3)+back*extent*3.0
	camera.look_at(planet.center,up)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func texture() -> Texture2D:
	return viewport.get_texture()

static func terrain_mesh(p: Dictionary) -> ArrayMesh:
	if _meshes.has(str(p.id)): return _meshes[str(p.id)]
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	const GRID := 32
	for face in 6:
		var first := vertices.size()
		var points := PackedVector3Array()
		var directions := PackedVector3Array()
		var heights := PackedFloat32Array()
		for j in GRID+1:
			for i in GRID+1:
				var dir := PlanetTerrain._dir(face,float(i)/GRID*2.0-1.0,float(j)/GRID*2.0-1.0).normalized()
				var h := SpaceLayout.surface_height(p,dir)
				directions.append(dir)
				heights.append(h)
				points.append(dir*(float(p.radius)+h))
		for j in GRID+1:
			for i in GRID+1:
				var k := j*(GRID+1)+i
				var east := points[j*(GRID+1)+mini(i+1,GRID)]-points[j*(GRID+1)+maxi(i-1,0)]
				var south := points[mini(j+1,GRID)*(GRID+1)+i]-points[maxi(j-1,0)*(GRID+1)+i]
				var normal := east.cross(south).normalized()
				if normal.dot(directions[k])<0: normal = -normal
				vertices.append(points[k])
				normals.append(normal)
				colors.append(Color.WHITE if p.get("city",false) else PlanetPalette.ground(p,directions[k],heights[k],normal))
		for j in GRID:
			for i in GRID:
				var a := first+j*(GRID+1)+i
				var b := a+1
				var c := a+GRID+1
				var d := c+1
				var tri := [a,b,c,b,d,c]
				if (vertices[b]-vertices[a]).cross(vertices[c]-vertices[a]).dot(vertices[a])>0: tri = [a,c,b,b,c,d]
				for index: int in tri: indices.append(index)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	_meshes[str(p.id)] = mesh
	return mesh
