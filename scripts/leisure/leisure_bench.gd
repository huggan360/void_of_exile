extends Node3D
## Existing authored benches supply seats in the same place on every peer.
func _ready() -> void:
	var place := LeisureFurniture.world_of(self)
	if place==null: return
	LeisureFurniture.bench_targets(self, "bench:"+str(place.get_path_to(self)), Transform3D.IDENTITY, 0.8, 2.7)
