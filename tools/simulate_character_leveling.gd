extends Node
## Run: ~/Godot/godot_voxel_editor --headless --path . tools/simulate_character_leveling.tscn

const SAMPLES := 1000


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var samples := SAMPLES
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--samples="): samples = clampi(int(argument.get_slice("=", 1)), 1, SAMPLES)
	seed(20261102)
	var total_xp := 0
	for at_level in range(1, PlayerStats.MAX_LEVEL):
		total_xp += PlayerStats.xp_for_level(at_level)
	print("XP to level 50: %d" % total_xp)
	for at_level in [1, 8, 20, 30, 50]:
		print("Level %d curve XP: %d" % [at_level, PlayerStats.xp_for_level(at_level)])
	for class_id: String in PlayerClasses.ORDER:
		var results := {}
		for stat in PlayerStats.STAT_NAMES:
			results[stat] = []
		for sample in samples:
			var stats := PlayerStats.new()
			stats.class_id = class_id
			stats.reset()
			for stat in PlayerStats.STATS: assert(stats.stat_base(stat) == 0)
			assert(stats.stat_max("attack") <= 45)
			stats.add_xp(total_xp)
			assert(stats.level == PlayerStats.MAX_LEVEL)
			for stat in results:
				var amount := int(Items.STAT_ELIXIRS[stat][1])
				var short := ceili(float(stats.stat_max(stat) - stats.stat_base(stat)) / amount)
				results[stat].append(short)
			if sample == 0:
				_verify(stats)
		print("%s: elixirs short of cap, %d characters (mean, standard deviation, min..max)" % [class_id, samples])
		for stat in results:
			var values: Array = results[stat]
			var sum := 0
			for value: int in values:
				sum += value
			var mean := float(sum)/samples
			var variance := 0.0
			for value: int in values: variance += pow(float(value)-mean,2.0)
			var deviation := sqrt(variance/samples)
			if samples>=100:
				assert(mean>=8.5 and mean<=11.5,"Level-50 cohort should average about ten potions short")
				assert(values.min()<10 and values.max()>10,"Both lucky and unlucky stat totals should occur")
			print("  %s: %.2f, sd %.2f, %d..%d" % [stat, mean, deviation, values.min(), values.max()])
	print("PASS: save/load, gain events, caps, elixir refusal and legacy levels")
	get_tree().quit()


func _verify(stats: PlayerStats) -> void:
	var restored := PlayerStats.new()
	restored.load_data(JSON.parse_string(JSON.stringify(stats.to_data())))
	assert(restored.base == stats.base)
	assert(restored.base_hp == stats.base_hp and restored.base_mp == stats.base_mp)
	assert(restored.level == stats.level and restored.xp == stats.xp)
	for stat in PlayerStats.STAT_NAMES:
		var place := {kind = "pack", key = 0}
		var elixir := Items.stat_elixir(stat)
		var target := restored.stat_max(stat)
		# Even a lucky max-level roll can already cap a stat. Start this
		# consumption check explicitly one point below the cap.
		if stat == "hp": restored.base_hp = mini(restored.base_hp, target - 1)
		elif stat == "mp": restored.base_mp = mini(restored.base_mp, target - 1)
		else: restored.base[stat] = mini(int(restored.base[stat]), target - 1)
		restored._raise(stat, target - restored.stat_base(stat) - 1)
		restored.backpack[0] = elixir
		assert(restored.use(place))
		assert(restored.stat_base(stat) == target)
		elixir = Items.stat_elixir(stat)
		restored.backpack[0] = elixir
		assert(not restored.use(place))
		assert(elixir.count == 1 and restored.backpack[0] == elixir)
	var data := stats.to_data()
	data.level = 72
	for stat in PlayerStats.STATS:
		data.base[stat] = 9999
	data.base_hp = 99999
	data.base_mp = 99999
	restored.load_data(data)
	restored.add_xp(100)
	assert(restored.level == 72)
	for stat in PlayerStats.STAT_NAMES:
		assert(restored.stat_base(stat) == restored.stat_max(stat))
	var fresh := PlayerStats.new()
	fresh.class_id = stats.class_id
	fresh.reset()
	var before := {}
	for stat in PlayerStats.STAT_NAMES:
		before[stat] = fresh.stat_base(stat)
	var events: Array = []
	fresh.leveled_up.connect(func(_level: int, gains: Dictionary) -> void: events.append(gains))
	fresh.add_xp(fresh.xp_to_next())
	assert(events.size() == 1)
	for stat in PlayerStats.STAT_NAMES:
		assert(fresh.stat_base(stat) - int(before[stat]) == int(events[0].get(stat, 0)))
