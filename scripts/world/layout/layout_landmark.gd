@tool
class_name LayoutLandmark
extends Marker3D
## A one-off realm feature placed by hand (see RealmFeature.create types).

@export var feature_type := "woodland_lake"


func to_data() -> Dictionary:
	return {type = feature_type, at = RealmLayout.flat(self)}
