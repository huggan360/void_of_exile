class_name VillageHouse
extends Node3D
## Fine-grained native VOX buildings, with a CLOSED solid collision envelope.
static var _cache := {}
var spec: Dictionary

func setup(record: Dictionary) -> VillageHouse:
	spec = record
	position = record.pos
	rotation.y = float(record.yaw) if record.has("yaw") else -float(record.get("turn", 0)) * PI * 0.5
	scale = Vector3.ONE * float(record.get("scale", 1.0))
	return self

static func warm_asset(folder: String) -> void:
	if not _cache.has(folder):
		var rig: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder + "/rig.json"))
		var meshes: Array = []
		for suffix in ["", "_glow"]:
			# Meshing is for eyes: the dedicated server only needs the rig (collision).
			var path: String = folder + "/body" + str(suffix) + ".vox"
			meshes.append(VoxModel.load_mesh(path) if FileAccess.file_exists(path) and not Net.is_server() else null)
		_cache[folder] = {rig = rig, meshes = meshes}

func _ready() -> void:
	var folder: String = spec.asset
	warm_asset(folder)
	var data: Dictionary = _cache[folder]
	var frame: Array = data.rig.parts.body.frame_min
	var voxel_size: float = data.rig.voxel_size
	for i in 2:
		# The dedicated server never draws: the house is only its collision there.
		if data.meshes[i] == null or Net.is_server():
			continue
		var mesh := MeshInstance3D.new()
		mesh.mesh = data.meshes[i]
		mesh.position = Vector3(frame[0], frame[1], frame[2]) * voxel_size
		mesh.scale = Vector3.ONE * voxel_size
		mesh.material_override = VoxModel.material() if i == 0 else VoxModel.glow_material()
		add_child(mesh)
	if folder.ends_with("/bench"):
		LeisureFurniture.bench_targets(self, "bench:town:"+str(spec.pos), Transform3D.IDENTITY, 0.8, 2.7)
	var body := StaticBody3D.new()
	body.collision_layer = Player.OBSTACLE_LAYER
	body.collision_mask = 0
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = spec.solid_size
	collider.shape = shape
	collider.position = spec.get("solid_offset", Vector3(0, shape.size.y * 0.5, 0))
	body.add_child(collider)
	add_child(body)
