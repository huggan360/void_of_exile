extends Node
## One-time authored road extensions; preserve every town/landmark and existing path.
func _ready() -> void:
	var root := (load(RealmLayout.SCENE) as PackedScene).instantiate() as Node3D
	for child in root.get_node("Roads").get_children():
		if str(child.name).begins_with("OuterApproach"):
			root.get_node("Roads").remove_child(child)
			child.free()
	var layout := _data(root)
	var generator := IslandGenerator.new(WorldServer.MAP_SEED,layout)
	generator._build_road_grid()
	for fort: StrongholdFeature in generator.strongholds:
		if not fort.get_meta(&"approach",false): continue
		var target := Vector2(fort.center)+generator._gate_direction(fort)*IslandGenerator.APPROACH_DISTANCE
		var nearest := Vector2.ZERO
		var best := INF
		for road: Dictionary in layout.roads:
			for p: Vector2 in road.points:
				var d := p.distance_squared_to(target)
				if d<best: best = d; nearest = p
		var before := generator.roads.size()
		var rng := RandomNumberGenerator.new()
		rng.seed = WorldServer.MAP_SEED+fort.biome_id*71
		generator._route_road(nearest,target,rng,IslandGenerator.MAIN_ROAD_WIDTH)
		if generator.roads.size()==before: continue
		var path := LayoutRoad.new()
		path.name = "OuterApproach%d" % fort.biome_id
		path.width = IslandGenerator.MAIN_ROAD_WIDTH
		path.curve = Curve3D.new()
		path.curve.bake_interval = 2
		var points: PackedVector2Array = generator.roads[-1]
		for i in range(0,points.size(),3): path.curve.add_point(Vector3(points[i].x,0,points[i].y))
		path.curve.add_point(Vector3(points[-1].x,0,points[-1].y))
		root.get_node("Roads").add_child(path)
		path.owner = root
	var packed := PackedScene.new()
	packed.pack(root)
	ResourceSaver.save(packed,RealmLayout.SCENE)
	var final_layout := _data(root)
	root.free()
	RealmLayout._cache.clear()
	generator = IslandGenerator.new(WorldServer.MAP_SEED,final_layout)
	var half := int(RealmLayout.MAP_SIZE*.5)
	var step := 2
	var count := half*2/step
	var image := Image.create(count,count,false,Image.FORMAT_RGB8)
	for z in count:
		for x in count:
			var wx := -half+x*step
			var wz := -half+z*step
			var top := generator.top_of(wx,wz)
			var color := GameWorld.shade_for_map(Blocks.map_color(top.y),top.x,generator.column(wx-1,wz).x,IslandGenerator.SEA_LEVEL)
			if generator.is_road(wx,wz): color = color.lerp(Color(.9,.85,.7),.5)
			image.set_pixel(x,z,color)
	image.save_png(ProjectSettings.globalize_path(RealmLayout.MAP))
	print("Expanded authored roads and reference map saved")
	get_tree().quit()

func _data(root: Node) -> Dictionary:
	var data := {villages=[],strongholds=[],landmarks=[],roads=[]}
	for node in root.find_children("*","",true,false):
		if node is LayoutVillage: data.villages.append(node.to_data())
		elif node is LayoutStronghold: data.strongholds.append(node.to_data())
		elif node is LayoutLandmark: data.landmarks.append(node.to_data())
		elif node is LayoutRoad: data.roads.append(node.to_data())
	return data
