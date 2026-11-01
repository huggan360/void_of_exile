extends SceneTree
## Renders a realm plan (roads, towns, strongholds) and each town close up for review.
## Usage: OUT=/path/map.png godot --headless --path . -s tools/review_realm_plan.gd -- [seed]
func _initialize() -> void:
	var seed_value := int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 20261031
	var t := Time.get_ticks_msec()
	var gen := IslandGenerator.new(seed_value)
	print("planned in ", (Time.get_ticks_msec() - t) / 1000.0, "s roads=", gen.roads.size())
	var half := 420
	var scale := 1
	var image := Image.create_empty(half * 2 / scale, half * 2 / scale, false, Image.FORMAT_RGB8)
	for z in image.get_height():
		for x in image.get_width():
			var wx := x * scale - half
			var wz := z * scale - half
			var top := gen.top_of(wx, wz)
			var c := Blocks.map_color(top.y)
			if top.x < IslandGenerator.SEA_LEVEL:
				c = c.lerp(Color(0.16, 0.42, 0.58), 0.7)
			var f := gen.feature_at(wx, wz)
			if f and f.type == "road":
				c = Color(1, 0.95, 0.6)
			image.set_pixel(x, z, c)
	for v in gen.villages:
		print(v.display_name, " at ", v.center, " houses=", v.houses.size(), " exits=", v.exits, " trees=", v.trees.size(), " props=", v.props.size(), " services=", v.service_sites.map(func(s): return s.role))
	for road in gen.roads:
		print("road ", road.size(), " ", road[0].round(), " -> ", road[-1].round())
	for f in gen.strongholds:
		print(f.display_name, " at ", f.center, " turn=", f.turn)
	image.save_png(OS.get_environment("OUT"))
	for v in gen.villages:
		var r := int(v.radius) + 10
		var img := Image.create_empty(r * 8 + 4, r * 8 + 4, false, Image.FORMAT_RGB8)
		for z in range(-r, r):
			for x in range(-r, r):
				var wx: int = v.center.x + x
				var wz: int = v.center.y + z
				var top := gen.top_of(wx, wz)
				var c := Blocks.map_color(top.y)
				img.fill_rect(Rect2i((x + r) * 4, (z + r) * 4, 4, 4), c)
		for h in v.houses:
			var p := (Vector2(h.pos.x, h.pos.z) - Vector2(v.center) + Vector2(r, r)) * 4
			var yaw: float = h.yaw
			var front := Vector2(-sin(yaw), -cos(yaw))
			var right := Vector2(cos(yaw), -sin(yaw))
			for a in range(-17, 18):
				for b in range(-18, 19):
					var q := p + right * a + front * b
					var col := Color(0.55, 0.3, 0.2) if b < 14 else Color(1, 0.9, 0)
					if abs(a) < 3 or b < 14:
						img.set_pixelv(Vector2i(q.round()).clamp(Vector2i.ZERO, Vector2i(img.get_width() - 1, img.get_height() - 1)), col)
		for pr in v.props:
			var p := (Vector2(pr.pos.x, pr.pos.z) - Vector2(v.center) + Vector2(r, r)) * 4
			img.fill_rect(Rect2i(Vector2i(p) - Vector2i(3, 3), Vector2i(6, 6)), Color.WHITE if pr.asset.ends_with("lantern") else Color.MAGENTA)
		for tr in v.trees:
			var p := (Vector2(tr.pos.x, tr.pos.z) - Vector2(v.center) + Vector2(r, r)) * 4
			img.fill_rect(Rect2i(Vector2i(p) - Vector2i(4, 4), Vector2i(8, 8)), Color(0.1, 0.35, 0.1))
		for npc in v.residents:
			var p := (Vector2(npc.pos.x, npc.pos.z) - Vector2(v.center) + Vector2(r, r)) * 4
			img.fill_rect(Rect2i(Vector2i(p) - Vector2i(3, 3), Vector2i(6, 6)), Color.CYAN if not npc.stationary else Color.RED)
		img.save_png(OS.get_environment("OUT").get_base_dir() + "/town_%s.png" % v.display_name)
	quit()
