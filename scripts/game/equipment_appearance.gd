class_name EquipmentAppearance
extends RefCounted
## Shared by world figures and portraits. Source meshes/materials stay immutable.
const UNIT := 1.8 / 16.0
static var _profiles: Dictionary = {}
static var _palettes: Dictionary = {}
static var _meshes: Dictionary = {}
static var _accent_material: ShaderMaterial

static func accent_material() -> ShaderMaterial:
	if _accent_material == null:
		_accent_material = VoxModel.material().duplicate() as ShaderMaterial
		_accent_material.set_shader_parameter("glow_strength", 0.85)
	return _accent_material

static func profiles() -> Dictionary:
	if _profiles.is_empty():
		_profiles = JSON.parse_string(FileAccess.get_file_as_string("res://characters/equipment/profiles.json"))
	return _profiles

static func apply(model: Node3D, weapon: Item, armor: Item) -> void:
	if not model.is_node_ready():
		model.ready.connect(func() -> void: apply(model, weapon, armor), CONNECT_ONE_SHOT)
		return
	var key := "%s|%s" % [weapon.id if weapon else "", armor.id if armor else ""]
	if model.get_meta("equipment_key", "unset") == key: return
	model.set_meta("equipment_key", key)
	var rig := model.find_child("Rig", true, false) as Node3D
	if rig == null: return
	var socket := rig.find_child("Bow" if model.class_id == "archer" else "Staff", true, false) as Node3D
	if socket:
		socket.set_meta("equipment_visible", weapon != null)
		socket.visible = weapon != null
		for child in socket.get_children():
			if child.name in ["StringTop", "StringBottom"]: continue
			if child.has_meta("equipped_art"):
				socket.remove_child(child)
				child.queue_free()
			else: child.visible = false
		if weapon and profiles().has(weapon.id):
			var profile: Dictionary = profiles()[weapon.id]
			for suffix: String in (["", "_glow"] if profile.glow else [""]):
				var part := MeshInstance3D.new()
				part.set_meta("equipped_art", true)
				part.mesh = VoxModel.load_mesh("res://characters/equipment/%s%s.vox" % [weapon.id, suffix])
				part.material_override = accent_material() if suffix != "" else VoxModel.material()
				part.scale = Vector3(profile.scale[0], profile.scale[1], profile.scale[2]) * UNIT
				part.position = Vector3(profile.offset[0], profile.offset[1], profile.offset[2]) * UNIT
				socket.add_child(part)
	var armor_id := armor.id if armor else ""
	var advanced := armor != null and armor.tier != 1 and profiles().has(armor_id)
	var garment := model.get_meta("garment_mesh", null) as MeshInstance3D
	if garment:
		garment.set_instance_shader_parameter("garment_glow", float(profiles()[armor_id].get("body_glow", 0.0)) if advanced else 0.0)
	if not _palettes.has(model.class_id):
		_palettes[model.class_id] = JSON.parse_string(FileAccess.get_file_as_string("res://characters/%s/palette.json" % model.class_id))
	var palette: Dictionary = _palettes[model.class_id]
	for node: Node in rig.find_children("*", "MeshInstance3D", true, false):
		var part := node as MeshInstance3D
		if not part.has_meta("original_mesh"): part.set_meta("original_mesh", part.mesh)
		var source: Mesh = part.get_meta("original_mesh")
		var label := str(part.get_parent().name)
		if label not in ["Body", "UpperArm", "Forearm", "Leg"]: continue
		if not advanced:
			part.mesh = source
			continue
		var cache_key := "%s|%s|%s" % [model.class_id, armor_id, source.get_instance_id()]
		if not _meshes.has(cache_key):
			var mesh := ArrayMesh.new()
			var profile: Dictionary = profiles()[armor_id]
			var main := _color(profile.main)
			var accent := _color(profile.accent)
			for surface in source.get_surface_count():
				var arrays := source.surface_get_arrays(surface)
				var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				for i in colors.size():
					# Merrow's fins are anatomy, even though the original art shares cloth colors.
					if model.class_id == "merrow" and label == "Body" and vertices[i].y >= 9.0: continue
					for role: String in palette:
						if not (role.begins_with("hood") or role in ["cloth", "cloth_light", "shade", "accent"] or (model.class_id == "archer" and role == "tunic_dark")): continue
						if Color(colors[i], 1.0).is_equal_approx(_color(palette[role])):
							var mask := colors[i].a
							colors[i] = accent if role == "accent" else main.darkened(0.28) if "dark" in role or role == "shade" else main.lightened(0.15) if role == "cloth_light" or role.ends_with("_c") else main
							colors[i].a = mask
							break
				arrays[Mesh.ARRAY_COLOR] = colors
				mesh.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays)
			_meshes[cache_key] = mesh
		part.mesh = _meshes[cache_key]
	var old := rig.get_node_or_null("EquipmentCollar")
	if old:
		rig.remove_child(old)
		old.queue_free()
	if advanced and profiles()[armor_id].ornate:
		_collar(rig, armor_id, model.class_id)

## Compact solid fists replace the old flat 3-by-3 rings, including the free hand.
static func fit_hands(model: Node3D) -> void:
	var class_id: String = model.class_id
	var key := "fists_" + class_id
	if not _meshes.has(key):
		var palette: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://characters/%s/palette.json" % class_id))
		var box := BoxMesh.new()
		box.size = Vector3(1.65, 1.35, 1.65)
		var arrays := box.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in vertices.size(): vertices[i] += Vector3(1.5, 0.5, 1.5)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		var colors := PackedColorArray()
		colors.resize(vertices.size())
		colors.fill(_color(palette.skin))
		arrays[Mesh.ARRAY_COLOR] = colors
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		_meshes[key] = mesh
	for hand_name: String in ["LeftHand", "RightHand"]:
		var hand := model.find_child(hand_name, true, false)
		if hand:
			var part := hand.get_node("Hand/ClothAndEquipment") as MeshInstance3D
			part.mesh = _meshes[key]
	prepare_garment(model)

static func _color(rgb: Array) -> Color:
	return Color8(int(rgb[0]), int(rgb[1]), int(rgb[2]))

## Small shoulder clasps sit on the existing collar, leaving the hem free.
static func _collar(rig: Node3D, id: String, class_id: String) -> void:
	var root := Node3D.new()
	root.name = "EquipmentCollar"
	rig.add_child(root)
	var profile: Dictionary = profiles()[id]
	var key := "collar_" + id + class_id
	var front := -3 if class_id in ["archer", "wizard"] else -4
	if not _meshes.has(key):
		var buf := VoxelBuffer.new()
		buf.create(16, 21, 16)
		var palette := VoxelColorPalette.new()
		palette.set_color(1, _color(profile.accent))
		for x in [-3, 2]: buf.set_voxel(1, x + 8, 8, front + 8, VoxelBuffer.CHANNEL_COLOR)
		if profile.get("signature", false):
			for x in [-2, 0, 2]:
				buf.set_voxel(1, x + 8, 9 + (1 if x == 0 else 0), front + 8, VoxelBuffer.CHANNEL_COLOR)
				if int(profile.get("form", 0)) % 2 == 1:
					buf.set_voxel(1, x + 8, 7, front + 8, VoxelBuffer.CHANNEL_COLOR)
		_meshes[key] = VoxModel.mesh_from_buffer(buf, palette)
	var part := MeshInstance3D.new()
	part.mesh = _meshes[key]
	part.material_override = accent_material()
	part.scale = Vector3.ONE * UNIT
	part.position = Vector3(-8, 0, -8) * UNIT
	root.add_child(part)

## Only rear garment vertices receive a motion mask; bags, skin and arrows stay fixed.
static func prepare_garment(model: Node3D) -> void:
	var body := model.find_child("Body", true, false).get_child(0) as MeshInstance3D
	var key: String = "garment_mask_" + model.class_id
	if not _meshes.has(key):
		var palette: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://characters/%s/palette.json" % model.class_id))
		var cloth_colors: Array[Color] = []
		for role: String in palette:
			if role.begins_with("hood") or role in ["cloth", "cloth_light", "shade"]:
				cloth_colors.append(_color(palette[role]))
		var mesh := ArrayMesh.new()
		var source := _split_at_hem(body.mesh)
		for surface in source.get_surface_count():
			var arrays := source.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			for i in colors.size():
				var garment := false
				if vertices[i].z >= 10.0 and vertices[i].y < 5.5:
					for color: Color in cloth_colors:
						if colors[i].is_equal_approx(color): garment = true
				colors[i].a = 1.0 if garment else 0.0
			arrays[Mesh.ARRAY_COLOR] = colors
			mesh.add_surface_from_arrays(source.surface_get_primitive_type(surface), arrays)
		_meshes[key] = mesh
	body.mesh = _meshes[key]
	body.material_override = body.material_override.duplicate()
	body.extra_cull_margin = 0.6
	model.set_meta("garment_mesh", body)

static func animate_garment(model: Node3D, stride: float, blend: float) -> void:
	var body: MeshInstance3D = model.get_meta("garment_mesh", null)
	if body:
		var material := body.material_override as ShaderMaterial
		material.set_shader_parameter("garment_swing", absf(stride) * blend * 0.9)

## Cut long greedy-meshed faces at the pinned waist before moving the hem.
## Otherwise a single face from shoulder to hem would pull the whole back out.
static func _split_at_hem(source: Mesh) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for surface in source.get_surface_count():
		var original := source.surface_get_arrays(surface)
		var vertices: PackedVector3Array = original[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = original[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray = original[Mesh.ARRAY_COLOR]
		var indices: PackedInt32Array = original[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for i in vertices.size(): indices.append(i)
		var out_vertices := PackedVector3Array()
		var out_normals := PackedVector3Array()
		var out_colors := PackedColorArray()
		for i in range(0, indices.size(), 3):
			var triangle: Array[Dictionary] = []
			for j in 3:
				var index := indices[i+j]
				triangle.append({p = vertices[index], n = normals[index], c = colors[index]})
			var low := false
			var high := false
			for vertex: Dictionary in triangle:
				low = low or vertex.p.y < 5.5
				high = high or vertex.p.y > 5.5
			var pieces: Array = []
			if low and high:
				for lower: bool in [true, false]:
					var polygon: Array[Dictionary] = []
					for j in 3:
						var a: Dictionary = triangle[j]
						var b: Dictionary = triangle[(j+1)%3]
						var a_inside: bool = a.p.y <= 5.5 if lower else a.p.y >= 5.5
						var b_inside: bool = b.p.y <= 5.5 if lower else b.p.y >= 5.5
						if a_inside: polygon.append(a)
						if a_inside != b_inside:
							var t: float = (5.5-a.p.y)/(b.p.y-a.p.y)
							polygon.append({p = a.p.lerp(b.p, t), n = a.n.lerp(b.n, t).normalized(), c = a.c.lerp(b.c, t)})
					pieces.append(polygon)
			else: pieces.append(triangle)
			for polygon: Array in pieces:
				for j in range(1, polygon.size()-1):
					for vertex: Dictionary in [polygon[0], polygon[j], polygon[j+1]]:
						out_vertices.append(vertex.p)
						out_normals.append(vertex.n)
						out_colors.append(vertex.c)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = out_vertices
		arrays[Mesh.ARRAY_NORMAL] = out_normals
		arrays[Mesh.ARRAY_COLOR] = out_colors
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
