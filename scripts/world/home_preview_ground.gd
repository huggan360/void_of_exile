@tool
extends MeshInstance3D
## Editor overview of the baked island ground (coast, beaches, roads, plazas).
## Streamed voxel terrain replaces it in play. Press "Rebuild Preview" after
## moving the Coastline, a HomeRoad or a HomePlaza.
@export_tool_button("Rebuild Preview") var rebuild_action := rebuild

func _enter_tree() -> void:
	visible = Engine.is_editor_hint()
	if Engine.is_editor_hint():
		rebuild.call_deferred()

func rebuild() -> void:
	var root := get_parent()
	if root == null:
		return
	var terrain := HomeTerrain.from_scene(root)
	var side := HomeTerrain.SIDE
	var image := Image.create_empty(side, side, false, Image.FORMAT_RGB8)
	for z in side:
		for x in side:
			image.set_pixel(x, z, terrain.map_color(x - HomeTerrain.EXTENT, z - HomeTerrain.EXTENT))
	var material := StandardMaterial3D.new()
	material.albedo_texture = ImageTexture.create_from_image(image)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 1.0
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * side
	plane.material = material
	mesh = plane
	position = Vector3(0.5, HomeTerrain.FLOOR + 0.98, 0.5)
