@tool
class_name LayoutStronghold
extends Marker3D
## A boss stronghold of the static realm (see RealmLayout). Its gate faces
## `gate_degrees` (0 = +X, 90 = +Z); `approach_road` runs a road up to it.

@export_enum("Hall", "Ocean", "Beach", "Woods", "Jungle", "Desert", "Doom", "Fosen", "Bluelay", "Deep Desert", "Deep Dark") var biome := 8
@export var gate_degrees := 0.0
@export var approach_road := false
@export var fort_seed := 1


func to_data() -> Dictionary:
	return {at = RealmLayout.flat(self), biome = biome, gate_angle = deg_to_rad(gate_degrees), approach = approach_road,
		seed = fort_seed}
