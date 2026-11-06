class_name PortalVoxelBuilder
extends RefCounted
## Converts native mesh faces and a copied terrain volume into world-space
## voxels. This worker never reads live nodes or a screen/depth texture.
const LIMIT := 140000
var _cache := {}
var _data := PackedFloat32Array()
var _count := 0
var _projection := Projection()
var _view := Transform3D.IDENTITY
var _focus := Vector3.ZERO

func build(sources: Array, terrain: Dictionary, projection: Projection, camera: Transform3D, focus: Vector3) -> PackedFloat32Array:
	_count = 0
	_data = PackedFloat32Array()
	_data.resize(LIMIT*20)
	_projection = projection
	_view = camera.affine_inverse()
	_focus = focus
	for source: Dictionary in sources:
		if _count>=LIMIT-20000: break
		var t: Transform3D = source.transform
		var scale := t.basis.get_scale().abs()
		var mesh: Mesh = source.mesh
		var desired := 0.065 if source.actor else 0.24
		var step := maxf(1.0,roundf(desired/maxf(0.001,scale[scale.min_axis_index()])))
		if mesh is BoxMesh: step = clampf(mesh.size[mesh.size.min_axis_index()],0.12,0.65)
		var key := str(mesh.get_instance_id())+":"+str(step)
		if not _cache.has(key): _cache[key] = _surface_voxels(mesh,step)
		var voxels: Dictionary = _cache[key]
		var points: PackedVector3Array = voxels.points
		var colors: PackedColorArray = voxels.colors
		for i in points.size():
			var at := t*points[i]
			if not _visible(at): continue
			_add(Transform3D(t.basis.scaled(Vector3.ONE*step),at),colors[i]*source.tint,source.glow)
			if _count>=LIMIT-20000: break
	if not terrain.is_empty(): _terrain_voxels(terrain)
	_data.resize(_count*20)
	return _data

func _visible(at: Vector3) -> bool:
	var position := _view*at
	var p := _projection*Vector4(position.x,position.y,position.z,1.0)
	return p.w>0.0 and absf(p.x)<p.w*1.12 and absf(p.y)<p.w*1.15 and p.z>-p.w and p.z<p.w

func _add(t: Transform3D, color: Color, glow: float) -> void:
	if _count>=LIMIT: return
	var o := _count*20
	var b := t.basis
	var p := t.origin
	_data[o] = b.x.x
	_data[o+1] = b.y.x
	_data[o+2] = b.z.x
	_data[o+3] = p.x
	_data[o+4] = b.x.y
	_data[o+5] = b.y.y
	_data[o+6] = b.z.y
	_data[o+7] = p.y
	_data[o+8] = b.x.z
	_data[o+9] = b.y.z
	_data[o+10] = b.z.z
	_data[o+11] = p.z
	_data[o+12] = color.r
	_data[o+13] = color.g
	_data[o+14] = color.b
	_data[o+15] = 1.0
	_data[o+16] = fposmod(sin(p.dot(Vector3(12.9898,78.233,37.719)))*43758.5453,1.0)
	_data[o+17] = fposmod(sin(p.dot(Vector3(5.31,17.17,53.13)))*23421.631,1.0)
	_data[o+18] = glow
	_data[o+19] = fposmod(sin((p/4.0).floor().dot(Vector3(13.1,7.7,11.2)))*7312.13,1.0)
	_count += 1

func _surface_voxels(mesh: Mesh, step: float) -> Dictionary:
	var points := PackedVector3Array()
	var colors := PackedColorArray()
	var seen := {}
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		if arrays.is_empty(): continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var palette: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR]!=null else PackedColorArray()
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
		if indices.is_empty():
			indices.resize(vertices.size())
			for i in vertices.size(): indices[i] = i
		for face in range(0,indices.size()-2,3):
			var ia := indices[face]
			var normal := normals[ia] if not normals.is_empty() else (vertices[indices[face+1]]-vertices[ia]).cross(vertices[indices[face+2]]-vertices[ia]).normalized()
			var axis := normal.abs().max_axis_index()
			if absf(normal[axis])<0.99: continue
			var a := vertices[ia]
			var b := vertices[indices[face+1]]
			var c := vertices[indices[face+2]]
			var lo := a.min(b).min(c)
			var hi := a.max(b).max(c)
			var u := (axis+1)%3
			var v := (axis+2)%3
			var fixed := floori((lo[axis]-normal[axis]*step*0.01)/step)
			var color := palette[ia] if not palette.is_empty() else Color.WHITE
			for y in range(floori(lo[v]/step+0.001),ceili(hi[v]/step-0.001)):
				for x in range(floori(lo[u]/step+0.001),ceili(hi[u]/step-0.001)):
					var cell := Vector3i.ZERO
					cell[axis] = fixed
					cell[u] = x
					cell[v] = y
					if seen.has(cell): continue
					seen[cell] = true
					points.append((Vector3(cell)+Vector3.ONE*0.5)*step)
					colors.append(color)
	return {points=points,colors=colors}

func _terrain_voxels(source: Dictionary) -> void:
	var buffer: VoxelBuffer = source.buffer
	var origin: Vector3 = source.origin
	var size := buffer.get_size()
	for z in range(1,size.z-1):
		for x in range(1,size.x-1):
			for y in range(size.y-2,0,-1):
				var id := buffer.get_voxel(x,y,z,VoxelBuffer.CHANNEL_TYPE)
				if id==Blocks.AIR: continue
				# Keep real side faces and two layers of soil beneath exposed tops.
				if buffer.get_voxel(x,y+1,z,VoxelBuffer.CHANNEL_TYPE)!=Blocks.AIR and buffer.get_voxel(x,mini(y+2,size.y-1),z,VoxelBuffer.CHANNEL_TYPE)!=Blocks.AIR \
					and buffer.get_voxel(x-1,y,z,VoxelBuffer.CHANNEL_TYPE)!=Blocks.AIR and buffer.get_voxel(x+1,y,z,VoxelBuffer.CHANNEL_TYPE)!=Blocks.AIR \
					and buffer.get_voxel(x,y,z-1,VoxelBuffer.CHANNEL_TYPE)!=Blocks.AIR and buffer.get_voxel(x,y,z+1,VoxelBuffer.CHANNEL_TYPE)!=Blocks.AIR: continue
				var at := origin+Vector3(x+0.5,y+0.5,z+0.5)
				if _visible(at): _add(Transform3D(Basis.IDENTITY,at),Blocks.map_color(id),1.0 if id in Blocks.GLOWING else 0.0)
				if _count>=LIMIT: return
