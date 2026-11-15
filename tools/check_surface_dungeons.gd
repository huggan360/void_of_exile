extends Node
## The eight Surface dungeons (docs/dungeons/SURFACE_DUNGEONS.md): layouts,
## fine terrain, dressing, doors, creatures, bosses, Divine sets and loot.
##   godot --headless --path . res://tools/check_surface_dungeons.tscn

const IDS := ["sporewomb", "saltbone_wreck", "jade_ziggurat", "afterlife", "rimewake_barrow", "glass_labyrinth",
	"unlit_cathedral", "starless_sepulchre"]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var failures := 0
	var world := GameWorld.new()
	add_child(world)
	for id: String in IDS:
		var d := Dungeons.definition(id)
		assert(not d.is_empty(), id)
		var theme := Dungeons.theme(d)
		assert(theme.has("fine"), id + " has a fine theme")
		for seed_value in 12:
			var layout := DungeonLayout.new(d, seed_value)
			assert(layout.rooms.size() >= 4, id)
			assert(layout.rooms[1].kind == "boss")
		var layout := DungeonLayout.new(d, 4217)
		# Fine terrain: one block in a room and one across a wall.
		var gen := FineDungeonGenerator.new(layout, theme)
		var buffer := VoxelBuffer.new()
		buffer.create(16, 16, 16)
		var center := layout.point(1)
		gen._generate_block(buffer, Vector3i(int(center.x * 4) - 8, -8, int(center.z * 4) - 8), 0)
		var floor_block := buffer.get_voxel(8, 8 + 3, 8, VoxelBuffer.CHANNEL_TYPE)
		var air := buffer.get_voxel(8, 8 + 5, 8, VoxelBuffer.CHANNEL_TYPE)
		if floor_block == 0 or air != 0:
			push_error("%s: boss room floor %d / air %d" % [id, floor_block, air])
			failures += 1
		# Dressing (worker side) and its publishing.
		var scenery := DungeonScenery.new()
		scenery.prepare(layout, str(d.theme))
		world.add_child(scenery)
		scenery.publish()
		assert(scenery.glow_material != null, id + " has glowing dressing")
		print("[check] %s: rooms=%d glow points=%d" % [id, layout.rooms.size(), scenery.glow_points.size()])
		scenery.queue_free()
		# Its door, through a whole open and close.
		var portal := DungeonPortal.place(world, {id = "door_" + id, dungeon = id, remaining = 2.0})
		for k in 30: portal._process(0.1)
		# Creatures, boss and their art.
		for enemy_id: String in d.low_enemies + d.mid_enemies + ([d.miniboss] if d.miniboss != "" else []) + [d.boss]:
			var def := Enemies.get_def(enemy_id)
			assert(def != null, enemy_id)
			if not FileAccess.file_exists("res://creatures/%s/rig.json" % def.model):
				push_warning("no model yet: " + def.model)
			for attack: Dictionary in def.attacks:
				var model := str(attack.get("voxel_model", ""))
				if model != "" and not FileAccess.file_exists("res://creatures/%s/rig.json" % model):
					push_error("%s: missing projectile %s" % [enemy_id, model])
					failures += 1
		var boss := Enemies.get_def(d.boss) as BossDef
		var actor: Script = load(boss.actor_script)
		if actor == null or not actor.can_instantiate():
			push_error("boss script does not compile: " + boss.actor_script)
			failures += 1
		var ids := Items.divine_ids_for(boss.id)
		assert(not ids.is_empty(), boss.id + " has a Divine set")
		for item_id: String in ids:
			var item := Items.make(item_id)
			assert(item != null, item_id)
			if not FileAccess.file_exists("res://items/textures/%s.png" % item_id):
				push_error("no icon: " + item_id)
				failures += 1
		var rng := RandomNumberGenerator.new()
		rng.seed = 5
		var divine := 0
		var potions := 0
		for i in 400:
			for bag in Loot.roll(boss, {1: boss.hp}, rng):
				for item: Item in bag.items:
					divine += int(item.is_divine())
					potions += int(item.id.begins_with("elixir_of_"))
		print("[check] %s: 400 kills -> %d divine, %d potions" % [boss.id, divine, potions])
		assert(potions >= 380)
	# Every new Divine item: a shot look the projectile code knows.
	var arrows := Arrows.new()
	add_child(arrows)
	for set_name: String in DungeonDivineSets.SET_NAMES:
		for item_id: String in Items.DIVINE_SETS[set_name]:
			var item := Items.make(item_id)
			if item.slot == "weapon":
				arrows.spawn(Vector3.ZERO, Vector3.FORWARD, 10, item)
				print("[check] %s: %s %d-%d x%.1f %s charge=%s" % [item_id, item.projectile.style, item.damage_min, item.damage_max,
					item.fire_rate, item.shots, item.charge.get("style", "")])
	arrows.clear()
	print("[check] %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	get_tree().quit(1 if failures else 0)
