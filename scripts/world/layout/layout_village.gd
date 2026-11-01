@tool
class_name LayoutVillage
extends Marker3D
## A town of the static realm (see RealmLayout). Its streets leave toward
## `exits` (degrees, 0 = +X, 90 = +Z): point them at the roads.

@export var display_name := "Town"
@export_enum("Hall", "Ocean", "Beach", "Woods", "Jungle", "Desert", "Doom", "Fosen", "Bluelay", "Deep Desert", "Deep Dark") var biome := 3
@export var capital := false
@export var color := Color(1.0, 0.8, 0.35)
@export var exits: PackedFloat32Array = []
@export var village_seed := 1


func to_data() -> Dictionary:
	return {name = display_name, at = RealmLayout.flat(self), biome = biome, capital = capital, color = color,
		exits = Array(exits).map(func(d: float) -> float: return deg_to_rad(d)), seed = village_seed}
