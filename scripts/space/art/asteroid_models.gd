class_name AsteroidModels
extends RefCounted
## Voxel asteroids for the Reach (SpaceBackdrop). Each shape is a lumpy rock
## (noise on a squashed sphere, a few craters) cut into voxels, built once at
## three resolutions: LOD 0 up close, LOD 1 in the middle distance, LOD 2 far
## off (a handful of big blocks). Only faces open to the air are kept, every
## face flat-shaded. Meshes are unit sized (the rock's radius is the instance
## scale), so a batch swaps LOD by swapping its mesh.
##
## Vertex colour: rgb a per-voxel stone shade, alpha 1 on crystal voxels (seams
## and, on crystal rocks, the spikes on top) for shaders/space_rock.gdshader.

const ROCK_SHAPES := 3
const KINDS := ["rock", "crystal", "giant"]
## Voxels across the rock (-1.25..1.25) per LOD; giants are bigger, so finer.
const RESOLUTION := {rock = [22, 11, 5], crystal = [22, 11, 6], giant = [34, 16, 8]}
const LOD_COUNT := 3
const SPAN := 1.25

static var _meshes := {}  # "kind:shape:lod" -> ArrayMesh


static func shape_count(kind: String) -> int:
	return 2 if kind != "rock" else ROCK_SHAPES


static func mesh(kind: String, shape: int, lod: int) -> ArrayMesh:
	var key := "%s:%d:%d" % [kind, shape, lod]
	if not _meshes.has(key):
		_meshes[key] = _build(kind, shape, RESOLUTION[kind][lod])
	return _meshes[key]


## Which LOD a batch this far from the eye uses (giants keep detail further).
static func lod_for(distance: float, giant: bool) -> int:
	var scale := 2.5 if giant else 1.0
	if distance < 1400.0 * scale: return 0
	if distance < 4200.0 * scale: return 1
	return 2


static func _build(kind: String, shape: int, res: int) -> ArrayMesh:
	var seed := 824 + shape * 237 + (5000 if kind == "giant" else 0) + (9000 if kind == "crystal" else 0)
	var noise := FastNoiseLite.new()
	noise.seed = seed
	noise.frequency = 1.4
	noise.fractal_octaves = 3
	var warp := Vector3(1.0, 0.72 + shape * 0.1, 0.86)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var craters: Array = []
	for i in (5 if kind == "giant" else 3):
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized()
		craters.append([dir * warp * 1.02, rng.randf_range(0.22, 0.42)])
	# Crystal rocks wear a crown of spikes (the old cone shards, in voxels).
	var spikes: Array = []
	if kind == "crystal":
		for j in 4:
			spikes.append([Vector2((j - 1.5) * 0.22, rng.randf_range(-0.1, 0.1)), rng.randf_range(0.55, 0.95), 0.1])
	var top := SPAN + (0.9 if kind == "crystal" else 0.0)
	var size := SPAN * 2.0 / res
	var ny := ceili((top + SPAN) / size)
	var solid := PackedByteArray()
	solid.resize(res * ny * res)
	var shade := PackedFloat32Array()
	shade.resize(solid.size())
	for y in ny:
		for z in res:
			for x in res:
				var p := Vector3(-SPAN + (x + 0.5) * size, -SPAN + (y + 0.5) * size, -SPAN + (z + 0.5) * size)
				var kind_here := _sample(p, warp, noise, craters, spikes)
				var i := (y * res + z) * res + x
				solid[i] = kind_here
				if kind_here != 0:
					shade[i] = 0.82 + absf(noise.get_noise_3dv(p * 4.3)) * 0.4
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var dims := Vector3i(res, ny, res)
	var origin := Vector3(-SPAN, -SPAN, -SPAN)
	for y in ny:
		for z in res:
			for x in res:
				var i := (y * res + z) * res + x
				if solid[i] == 0: continue
				var color := Color(shade[i], shade[i], shade[i], 1.0 if solid[i] == 2 else 0.0)
				var cell := Vector3i(x, y, z)
				for f in 6:
					var n: Vector3i = FACES[f]
					var o := cell + n
					if o.x >= 0 and o.y >= 0 and o.z >= 0 and o.x < dims.x and o.y < dims.y and o.z < dims.z \
							and solid[(o.y * res + o.z) * res + o.x] != 0:
						continue
					var corner := origin + Vector3(cell) * size
					for k in 6:
						vertices.append(corner + QUADS[f][QUAD_ORDER[k]] * size)
						normals.append(Vector3(n))
						colors.append(color)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	if not vertices.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## 0 air, 1 stone, 2 crystal.
static func _sample(p: Vector3, warp: Vector3, noise: FastNoiseLite, craters: Array, spikes: Array) -> int:
	for s: Array in spikes:
		var foot: Vector2 = s[0]
		var h: float = s[1]
		var width: float = s[2] * (1.0 - clampf((p.y - 0.45) / (h + 0.45), 0.0, 1.0) * 0.7)
		if p.y > 0.3 and p.y < 0.45 + h and Vector2(p.x - foot.x, p.z - foot.y).length() < width:
			return 2
	var q := p / warp
	var r := q.length()
	if r < 0.001: return 1
	var dir := q / r
	var lump := 0.82 + noise.get_noise_3dv(dir * 1.7) * 0.32 + absf(noise.get_noise_3dv(dir * 5.0)) * 0.08
	if r > lump: return 0
	for c: Array in craters:
		if p.distance_to(c[0]) < float(c[1]): return 0
	return 2 if noise.get_noise_3dv(dir * 3.1) > 0.38 and r > lump - 0.2 else 1


const FACES: Array[Vector3i] = [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]
## Each face's corners (unit cube), counter-clockwise seen from outside
## (QUAD_ORDER turns them clockwise, Godot's front face).
const QUADS := [
	[Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)],
	[Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0), Vector3(0, 0, 0)],
	[Vector3(0, 1, 0), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0)],
	[Vector3(0, 0, 1), Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1)],
	[Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1), Vector3(0, 0, 1)],
	[Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(1, 0, 0)],
]
const QUAD_ORDER := [0, 2, 1, 0, 3, 2]
