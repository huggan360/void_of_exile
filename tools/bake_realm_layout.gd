extends Node
## Bakes the static realm layout (res://realm/realm_layout.tscn) and its
## reference map (res://realm/realm_map.png) from the procedural planner, once.
## After that the layout is edited by hand in Godot; run this again only to
## start over:  godot --headless --path . res://tools/bake_realm_layout.tscn

const COLORS := {Hearthwick = Color(1.0, 0.82, 0.3), Bramblebrook = Color(0.45, 0.9, 0.4),
	Sunveil = Color(1.0, 0.55, 0.2), Snowbell = Color(0.55, 0.85, 1.0)}
const NAMES := {6: "Cinder Bastion", 7: "Crown of the Rime", 8: "Azure Crucible", 5: "Court of the Sun", 10: "Hollow Throne"}


func _ready() -> void:
	var gen := IslandGenerator.new(WorldServer.MAP_SEED)
	var root := RealmLayout.new()
	root.name = "RealmLayout"
	var groups := {}
	for g in ["Villages", "Strongholds", "Landmarks", "Roads"]:
		var n := Node3D.new()
		n.name = g
		root.add_child(n)
		groups[g] = n
	for v in gen.villages:
		var m := LayoutVillage.new()
		m.name = v.display_name
		m.display_name = v.display_name
		m.biome = v.biome_id
		m.capital = v.capital
		m.color = COLORS.get(v.display_name, Color(0.9, 0.7, 1.0))
		m.exits = PackedFloat32Array(Array(v.exits).map(func(a: float) -> float: return rad_to_deg(a)))
		m.village_seed = v.village_seed
		m.position = Vector3(v.center.x, 0, v.center.y)
		groups.Villages.add_child(m)
		_label(m, v.display_name, m.color)
	for i in gen.strongholds.size():
		var f: StrongholdFeature = gen.strongholds[i]
		var m := LayoutStronghold.new()
		m.name = NAMES.get(f.biome_id, "Stronghold %d" % i).replace(" ", "")
		m.biome = f.biome_id
		m.gate_degrees = rad_to_deg((-Vector2(f.center)).angle())
		m.approach_road = i in IslandGenerator.APPROACH_ROADS
		m.fort_seed = f._seed
		m.position = Vector3(f.center.x, 0, f.center.y)
		groups.Strongholds.add_child(m)
		_label(m, NAMES.get(f.biome_id, "Stronghold"), Color(1.0, 0.4, 0.4))
	for f in gen.features:
		if f.type == "woodland_lake":
			var m := LayoutLandmark.new()
			m.name = "WoodlandLake"
			m.feature_type = f.type
			m.position = Vector3(f.center.x, 0, f.center.y)
			groups.Landmarks.add_child(m)
	var n := 0
	for road in gen.roads:
		if _is_approach(gen, road):
			continue  # rebuilt from the stronghold's approach_road flag
		var path := LayoutRoad.new()
		n += 1
		path.name = "Road%d" % n
		path.width = IslandGenerator.MAIN_ROAD_WIDTH if road.size() > 0 and _is_main(gen, road) else IslandGenerator.BRANCH_ROAD_WIDTH
		path.curve = Curve3D.new()
		path.curve.bake_interval = 2.0
		for k in range(0, road.size(), 3 if road.size() > 8 else 1):
			path.curve.add_point(Vector3(road[k].x, 0, road[k].y))
		if (road.size() - 1) % 3 != 0 and road.size() > 8:
			path.curve.add_point(Vector3(road[-1].x, 0, road[-1].y))
		groups.Roads.add_child(path)
	for node in root.find_children("*", "", true, false):
		node.owner = root
	var scene := PackedScene.new()
	scene.pack(root)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://realm"))
	print("layout: ", ResourceSaver.save(scene, RealmLayout.SCENE), "  villages %d strongholds %d roads %d" % [gen.villages.size(), gen.strongholds.size(), n])
	_bake_map(gen)
	get_tree().quit()


func _label(m: Node3D, text: String, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 400
	l.pixel_size = 0.05
	l.modulate = color
	l.outline_size = 60
	l.rotation.x = -PI * 0.5
	l.position = Vector3(0, 2, -14)
	m.add_child(l)


func _is_approach(gen: IslandGenerator, road: PackedVector2Array) -> bool:
	for f in gen.strongholds:
		var c := Vector2(f.center)
		if road[0].distance_to(c) < IslandGenerator.APPROACH_DISTANCE + 3.0 and road[-1].distance_to(c) < IslandGenerator.APPROACH_DISTANCE + 3.0:
			return true
	return false


func _is_main(gen: IslandGenerator, road: PackedVector2Array) -> bool:
	return road[0].length() < 60.0 or road[-1].length() < 60.0


func _bake_map(gen: IslandGenerator) -> void:
	var step := 2
	var half := int(RealmLayout.MAP_SIZE * 0.5)
	var n := half * 2 / step
	var image := Image.create(n, n, false, Image.FORMAT_RGB8)
	for j in n:
		for i in n:
			var x := -half + i * step
			var z := -half + j * step
			var top := gen.top_of(x, z)
			var c := GameWorld.shade_for_map(Blocks.map_color(top.y), top.x, gen.column(x - 1, z).x, IslandGenerator.SEA_LEVEL)
			if gen.is_road(x, z):
				c = c.lerp(Color(0.9, 0.85, 0.7), 0.5)
			image.set_pixel(i, j, c)
	print("map: ", image.save_png(ProjectSettings.globalize_path(RealmLayout.MAP)))
