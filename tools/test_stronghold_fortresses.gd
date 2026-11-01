extends SceneTree
## Geometry contract, including mountain cuts, filled foundations and shut gates.
var failures := 0
var checks := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	for biome in [Biomes.DOOM, Biomes.FOSEN, Biomes.BLUELAY, Biomes.DESERT, Biomes.DEEP_DARK]:
		for direction in [Vector2(0, -100), Vector2(100, 0), Vector2(0, 100), Vector2(-100, 0)]:
			var fort := StrongholdFeature.plan(Vector2i.ZERO, biome, 40, 1234, direction)
			check(fort.radius == 52 and fort.bounds == Rect2i(-52, -52, 105, 105), "Full landscaped footprint")
			for z in range(-26, 27):
				for x in range(-26, 27):
					var col := [90, -1, -1]
					fort.shape(x, z, col)
					check(col[0] == 40 and col.size() == 3, "Clear level 53x53 arena")
			for natural in [10, 90]:
				var previous := 40
				for r in range(38, 53):
					var col := [natural, -1, -1]
					fort.shape(r, 0, col)
					check(col[0] >= mini(40, natural) and col[0] <= maxi(40, natural), "Blend never overshoots")
					check((col[0] >= previous) if natural > 40 else (col[0] <= previous), "Blend is monotonic")
					previous = col[0]
				check(previous == natural, "Apron meets untouched terrain")
			for gate_z in [-34, 34]:
				var p := fort.to_world(Vector2i(0, gate_z))
				var col := [90, -1, -1]
				fort.shape(p.x, p.y, col)
				check(col.size() == 6 and col[3] >= 45, "Open gate has clear headroom")
				fort.gate_open = false
				col = [10, -1, -1]
				fort.shape(p.x, p.y, col)
				check(col[3] == 41 and col[4] >= 45, "Closed gate blocks the opening")
				fort.gate_open = true
			check(fort.packs[0].offset == 0.0 and fort.packs[0].pack.ends_with("_lair"), "Boss stays centered")
			var guards := Enemies.pack(fort.packs[1].pack)
			check(guards.activate_radius + fort.packs[1].offset < 32 and guards.respawn_time == -1, "Guards wake inside and stay cleared")
			for member in guards.members:
				check(Enemies.get_def(member.enemy) != null, "Existing guard enemy")
	# Exercise the real pack-site placer: every fortress keeps its boss AND guards.
	var generator := IslandGenerator.new(20261031)
	var area := Rect2i(-1024, -1024, 2048, 2048)
	var sites := generator._feature_pack_sites(area, [])
	var ids := {}
	for site in sites:
		check(not ids.has(site.id), "Independent persistent pack ids")
		ids[site.id] = true
	for fort in generator.strongholds:
		for entry in fort.packs:
			var matches := sites.filter(func(site: Dictionary) -> bool: return site.pack == entry.pack)
			check(matches.size() == 1, "Exactly one fortress pack: " + entry.pack)
			if not matches.is_empty():
				check(Vector2(matches[0].pos.x - 0.5, matches[0].pos.z - 0.5) == Vector2(fort.center), "Pack anchored at fortress center")
	print("FORTRESSES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
