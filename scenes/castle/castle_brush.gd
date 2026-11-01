@tool
extends MeshInstance3D
## An editable solid voxel brush. Its local BoxMesh is rasterized once on load.
## Keep brushes axis aligned, with integer edges. Checker brushes are floors.
@export var block: int = Blocks.CASTLE_STONE
@export var checker := false
@export var walk_surface := false

func _ready() -> void:
	if not Engine.is_editor_hint():
		visible = false
