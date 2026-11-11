@tool
class_name HomePlaza
extends Marker3D
## An editable round, paved square on the home island (fountain square, gate court).
## Give it a size to pave a rectangle instead (the chapel market square).
@export_range(3.0, 40.0, 0.5) var radius := 12.0
## Width (x) and depth (z) of a rectangular square; zero keeps it round.
@export var size := Vector2.ZERO
@export_enum("rings", "tiles", "cobble") var pattern := "rings"
