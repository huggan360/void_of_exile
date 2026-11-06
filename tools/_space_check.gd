extends Node
func _ready() -> void:
	await get_tree().process_frame
	var files := ["res://scripts/main.gd","res://scripts/player.gd","res://scripts/ui/hud.gd","res://scripts/ui/minimap.gd",
		"res://scripts/net/net_server.gd","res://scripts/net/net_client.gd","res://scripts/net/realm_instance.gd",
		"res://scripts/campaign/campaign_server.gd","res://scripts/campaign/campaign_client.gd","res://scripts/campaign/reach_campaign.gd",
		"res://scripts/campaign/astral_campaign.gd","res://scripts/world/hall_world.gd","res://scripts/world/world_loader.gd",
		"res://scripts/dungeons/theory/theory_world.gd","res://scripts/dungeons/theory/theory_traversal.gd"]
	for dir in ["res://scripts/space/","res://scripts/space/art/","res://scripts/world/spatial/"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"): files.append(dir+f)
	var bad := 0
	for f in files:
		var s: Script = load(f)
		if s==null or not s.can_instantiate():
			print("BAD ", f)
			bad += 1
	print("checked ", files.size(), " bad ", bad)
	var world := SpaceWorld.new({id="astral", space=true})
	add_child(world)
	for i in 40: await get_tree().process_frame
	print("station anchors ", world.station.anchors.keys() if world.station else "none")
	print("planets ", world.planets.size(), " interior seats ", world.interior_anchors.get("seats",{}).keys())
	print("npc isolde ", world.npc_position("isolde"), " moss ", world.npc_position("moss"))
	for t in ["first_light","lantern_road","shardfield","hollowmoon","pale_eye"]:
		for step in Campaigns.get_def(t).steps:
			if step.kind=="reach_search":
				for o in step.objects:
					var spots: Dictionary = world.planets[step.planet].anchors.spots
					if not spots.has(o.spot): print("MISSING spot ", t, " ", o.spot)
	get_tree().quit()
