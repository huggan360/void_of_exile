class_name ShipWindowView
extends Node
## Real windows for the walk-in ship rooms. The room is a fixed pocket far
## from the hull (SpaceLayout), so while the local camera is in a room a
## second camera sits at the same spot inside the flying hull
## (ShipHull.INTERIOR_OFFSET) and renders the shared world; every window of
## the room shows that image at its own screen position, so the view through
## each window is exactly what it would be on the real ship.
const EXTERIOR_LAYER := 2

var world: SpaceWorld
var player: Player
var _viewport: SubViewport
var _camera: Camera3D
var _live := false
var _outside_mask := (1<<20)-1

func _ready() -> void:
	_outside_mask = player.camera.cull_mask
	get_tree().node_added.connect(_tag_exterior)
	for node: Variant in world.planets.values()+world.ship_views.values()+[world.station, world.foes, world.backdrop]:
		if is_instance_valid(node): _tag_existing(node)
	process_priority = 100  # after the player's camera has moved this frame
	_viewport = SubViewport.new()
	_viewport.name = "ShipWindowView"
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.msaa_3d = get_viewport().msaa_3d
	add_child(_viewport)
	_camera = Camera3D.new()
	_viewport.add_child(_camera)
	_camera.current = true
	_camera.cull_mask = _outside_mask

## Exterior visuals use a separate camera layer. The main room camera skips
## them while live windows still see them. New streamed props are tagged too.
func _tag_existing(node: Node) -> void:
	_tag_exterior(node)
	for child in node.get_children(): _tag_existing(child)

func _tag_exterior(node: Node) -> void:
	if not node is VisualInstance3D or not is_instance_valid(world) or not world.is_ancestor_of(node): return
	var ancestor: Node = node
	while ancestor!=null and ancestor!=world:
		if ancestor is ShipInterior: return
		if ancestor is SpacePlanet or ancestor is SpaceShipView or ancestor is NexusStation or ancestor is SpaceFoes or ancestor is SpaceBackdrop:
			(node as VisualInstance3D).layers = ((node as VisualInstance3D).layers & ~1) | EXTERIOR_LAYER
			return
		ancestor = ancestor.get_parent()

func _process(_delta: float) -> void:
	var eye := player.camera.global_transform
	var slot := SpaceLayout.pocket_at(eye.origin)
	var ship := world.ship_in_slot(slot) if slot>=0 else null
	var view: SpaceShipView = world.ship_views.get(ship.id) if ship else null
	var live := view!=null and is_instance_valid(view)
	if live:
		var size := Vector2i(get_viewport().get_visible_rect().size)
		if _viewport.size!=size: _viewport.size = size
		var in_room := Transform3D(Basis.IDENTITY, -SpaceLayout.pocket_origin(slot))*eye
		_camera.global_transform = view.global_transform*Transform3D(Basis.IDENTITY, ShipHull.INTERIOR_OFFSET)*in_room
		_camera.fov = player.camera.fov
		_camera.near = player.camera.near
		_camera.far = player.camera.far
		_camera.environment = player.camera.environment
	if live!=_live:
		_live = live
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if live else SubViewport.UPDATE_DISABLED
		for material in ShipInterior.window_materials():
			material.set_shader_parameter("live", live)
			material.set_shader_parameter("view_tex", _viewport.get_texture() if live else null)

func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_tag_exterior): get_tree().node_added.disconnect(_tag_exterior)
	for material in ShipInterior.window_materials():
		material.set_shader_parameter("live", false)
		material.set_shader_parameter("view_tex", null)
