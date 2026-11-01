@tool
class_name HomeRoad
extends Path3D
## An editable road, path or pier on the home island. Drag its curve points in
## the editor; the voxel ground is paved along it when the Tavern loads.
## Later roads in the scene tree are painted over earlier ones.
@export_range(1.0, 12.0, 0.5) var width := 4.0
@export_enum("cobble", "gravel", "dirt", "tiles", "pier") var surface := "cobble"
## Darker stone curbs along both edges (cobble and tiles).
@export var curbs := true
