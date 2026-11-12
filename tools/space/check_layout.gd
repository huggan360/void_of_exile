extends Node
## Prints each planet's villages, places, town and fortress spots and checks
## that no two levelled spots overlap: godot --headless --path . res://tools/space/check_layout.tscn
func _ready() -> void:
	for p: Dictionary in SpaceLayout.PLANETS:
		if p.get("city", false): continue
		var t := Time.get_ticks_msec()
		var flats := SpaceLayout._flat_spots(p)
		var kinds := {}
		for v: Dictionary in SpaceLayout.settlements(p): kinds[v.kind] = int(kinds.get(v.kind, 0))+1
		var overlaps := 0
		for i in flats.size():
			for j in range(i+1, flats.size()):
				var arc := acos(clampf((flats[i][0] as Vector3).dot(flats[j][0]), -1.0, 1.0))*float(p.radius)
				if arc<float(flats[i][1])+float(flats[j][1]): overlaps += 1
		var places := []
		for i in 4: places.append(SpaceLayout.place_offset(p, i).round())
		var n := PlanetFlora.placements(p).size()
		print("%s: villages %s, places %s, flats %d, overlaps %d, obstacles %d (%d ms)" % [p.id, kinds, places, flats.size(), overlaps, n, Time.get_ticks_msec()-t])
	get_tree().quit()
