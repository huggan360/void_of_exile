@tool
class_name RealmLayout
extends Node3D
## The realm's static layout, edited in Godot: res://realm/realm_layout.tscn.
## Every realm is this island (terrain from WorldServer.MAP_SEED), with the
## towns, strongholds, landmarks and roads placed here by hand:
##   Villages/     LayoutVillage markers (name, biome, map color, street exits)
##   Strongholds/  LayoutStronghold markers (biome, gate direction, approach road)
##   Landmarks/    LayoutLandmark markers (e.g. the woodland lake)
##   Roads/        LayoutRoad paths (Path3D: drag the points; width)
## Positions are in blocks (1 unit = 1 block); only x and z matter. The map
## under them (realm_map.png, from tools/bake_realm_layout.tscn) shows the
## terrain for reference. The procedural planner that made the first version
## still lives in IslandGenerator (for generated places such as portals).

const SCENE := "res://realm/realm_layout.tscn"
const MAP := "res://realm/realm_map.png"
const MAP_SIZE := 1376.0  # blocks the reference map covers

static var _cache := {}


## The layout as plain data for IslandGenerator ({} if there is none).
static func data() -> Dictionary:
	if not _cache.is_empty() or not ResourceLoader.exists(SCENE):
		return _cache
	var root: Node = (load(SCENE) as PackedScene).instantiate()
	var out := {villages = [], strongholds = [], landmarks = [], roads = []}
	for node in root.find_children("*", "", true, false):
		if node is LayoutVillage:
			out.villages.append(node.to_data())
		elif node is LayoutStronghold:
			out.strongholds.append(node.to_data())
		elif node is LayoutLandmark:
			out.landmarks.append(node.to_data())
		elif node is LayoutRoad:
			out.roads.append(node.to_data())
	root.free()
	_cache = out
	return out


static func flat(node: Node3D) -> Vector2i:
	return Vector2i(roundi(node.position.x), roundi(node.position.z))


func _ready() -> void:
	if Engine.is_editor_hint() and FileAccess.file_exists(MAP) and get_node_or_null("MapPreview") == null:
		var image := Image.load_from_file(ProjectSettings.globalize_path(MAP))
		if image == null:
			return
		var sprite := Sprite3D.new()
		sprite.name = "MapPreview"
		sprite.texture = ImageTexture.create_from_image(image)
		sprite.pixel_size = MAP_SIZE / image.get_width()
		sprite.rotation.x = -PI * 0.5
		sprite.position.y = -0.5
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		add_child(sprite)  # not owned: never saved into the scene
