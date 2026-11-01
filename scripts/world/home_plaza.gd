@tool
class_name HomePlaza
extends Marker3D
## An editable round, paved square on the home island (fountain square, gate court).
@export_range(3.0, 40.0, 0.5) var radius := 12.0
@export_enum("rings", "tiles", "cobble") var pattern := "rings"
