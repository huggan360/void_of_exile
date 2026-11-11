class_name CityHouses
## Vesperis's voxel buildings in the Tavern's cosy style: walk-in houses, the
## timber halls round the cafes, bars and shops, and the Lantern Spire
## (tools/make_vesperis_houses.py, baked by tools/bake_vesperis_houses.tscn
## into scenes/vesperis/catalog.json). Each comes in three detail levels that
## take over from each other with distance, batched like the rest of the city
## (CityPlanet.Batch keys "house:<name>:<level>" and "house:<name>:glow"), and
## only its walls collide, so you can walk in through the door.
const CATALOG := "res://scenes/vesperis/catalog.json"
## The houses that fill the town blocks.
const HOUSES := ["cottage_moss", "cottage_red", "cottage_thatch", "cottage_plum", "house_blue", "house_plum", "house_moss",
	"lodge_slate", "townhouse_red", "turret_house"]
## Where each detail level shows (metres from the camera): [begin, end].
const RANGES: Array[Vector2] = [Vector2(0, 140), Vector2(140, 520), Vector2(520, 9000)]
const SPIRE_RANGES: Array[Vector2] = [Vector2(0, 1500), Vector2(1500, 5000), Vector2(5000, 24000)]
static var _catalog := {}
static var _meshes := {}

static func catalog() -> Dictionary:
	if _catalog.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
		_catalog = data if data is Dictionary else {}
	return _catalog

static func info(name: String) -> Dictionary:
	return catalog().get(name, {})

## Width (x) and depth (z) of a building's footprint (m) and its middle.
static func footprint(name: String) -> Rect2:
	var i := info(name)
	var size := Vector2(i.footprint[0], i.footprint[1])
	return Rect2(Vector2(i.center[0], i.center[1])-size*0.5, size)

static func _parse(key: String) -> Array:
	var parts := key.get_slice("@", 0).trim_prefix("d:").split(":")
	return [parts[1], parts[2]] if parts.size()>=3 else ["", ""]

static func mesh(key: String) -> Mesh:
	if _meshes.has(key): return _meshes[key]
	var p := _parse(key)
	var lods: Array = info(p[0]).get("lods", [])
	var out: Mesh = null
	if p[1]=="glow": out = load(str(lods[0].glow)) if not lods.is_empty() and lods[0].has("glow") else null
	elif int(p[1])<lods.size(): out = load(str(lods[int(p[1])].mesh))
	_meshes[key] = out
	return out

## [begin, end] of the distance a batch key shows at.
static func range_of(key: String) -> Vector2:
	var p := _parse(key)
	var level := 0 if p[1]=="glow" else int(p[1])
	var list := SPIRE_RANGES if str(p[0]).begins_with("spire") else RANGES
	return list[mini(level, list.size()-1)]

static func casts_shadow(key: String) -> bool:
	return _parse(key)[1]=="0"

## Adds building `name` standing at `xform` (planet space, -Z its front) to the
## batch, and its walls to `solids` ([planet-space transform, size, kind]).
static func place(batch: CityPlanet.Batch, solids: Array, name: String, xform: Transform3D) -> void:
	var i := info(name)
	if i.is_empty(): return
	var lods: Array = i.lods
	for k in lods.size():
		var lod: Dictionary = lods[k]
		var at := Transform3D(Basis.from_scale(Vector3.ONE*float(lod.scale)), Vector3(lod.offset[0], lod.offset[1], lod.offset[2]))
		batch.add("house:%s:%d" % [name, k], xform*at, Color.WHITE, Color())
		if k==0 and lod.has("glow"): batch.add("house:%s:glow" % name, xform*at, Color.WHITE, Color())
	for c: Dictionary in i.get("colliders", []):
		var basis := Basis(Vector3.UP, float(c.get("yaw", 0.0)))
		solids.append([xform*Transform3D(basis, Vector3(c.offset[0], c.offset[1], c.offset[2])), Vector3(c.size[0], c.size[1], c.size[2]), str(c.get("kind", "box"))])
