extends Node3D
## Small logic checks for developer commands, roster stats and player-only range.
class CommandProbe:
	extends SocialServer
	var messages: Array[String] = []
	var records := {}
	func system(_id: int, text: String) -> void: messages.append(text)
	func find(who: String) -> Dictionary: return records.get(who, {})

class HomeProbe:
	extends CampaignServer
	var state := {id = "frozen_whisper", status = "active", step = Campaigns.step_index("frozen_whisper", "home")}
	var advances := 0
	func _run_of(_party: Dictionary) -> Dictionary: return state
	func _advance(_party: Dictionary, _player: Dictionary, _side := false) -> void:
		advances += 1
		state.step += 1

var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func _ready() -> void:
	GameServer.set_physics_process(false)
	var stats := PlayerStats.new()
	var pid := GameServer.add_player(stats)
	var p := {player_id = pid, name = "Developer", developer = false, dead = false}
	var commands := CommandProbe.new()
	commands._command(p, "/lvl")
	check(stats.level == 1 and commands.messages.back().contains("Only developers"), "Ordinary players cannot use /lvl")
	commands._command(p, "/max")
	check(stats.base.attack == 0 and commands.messages.back().contains("Only developers"), "Ordinary players cannot use /max")
	p.developer = true
	var xp_awards: Array[int] = []
	stats.xp_gained.connect(func(amount: int) -> void: xp_awards.append(amount))
	var kept := Items.make("elixir_hp")
	stats.backpack[0] = kept
	var weapon := stats.gear.weapon as Item
	var base_hp := stats.base_hp
	commands._command(p, "/lvl")
	check(stats.level == 50 and stats.base_hp > base_hp, "/lvl defaults to max level with real growth")
	check(xp_awards.is_empty() and stats.xp == 0, "Developer levels award no account XP")
	check(stats.backpack[0] == kept and stats.gear.weapon == weapon, "Developer levels preserve equipment and inventory")
	check(stats.hp == stats.max_hp and stats.mp == stats.max_mp, "Developer levels fill vitals")
	commands._command(p, "/max")
	for stat in PlayerStats.STAT_NAMES:
		check(stats.stat_base(stat) == stats.stat_max(stat), "/max fills permanent " + stat)
	check(stats.gear.weapon == weapon and stats.backpack[0] == kept, "/max preserves inventory")
	commands._command(p, "/lvl 51")
	check(stats.level == 50 and commands.messages.back().contains("1 to 50"), "Out-of-range levels are rejected")
	var other := PlayerStats.new()
	var oid := GameServer.add_player(other)
	commands.records.Other = {player_id = oid, name = "Other", dead = false}
	commands._command(p, "/lvl Other 25")
	check(other.level == 25, "Developer can set another player's active character level")
	other.xp = roundi(other.xp_to_next() * 0.6)
	var ring := XpRing.new()
	add_child(ring)
	ring.set_values(other.level, float(other.xp) / other.xp_to_next())
	var displayed: Array[float] = []
	var initial_fill := ring._shown
	var update_display := func() -> void:
		ring.set_values(other.level, float(other.xp) / other.xp_to_next())
		displayed.append(ring._shown)
	other.changed.connect(update_display)
	other.load_data(other.to_data())
	check(displayed.size() == 1 and is_equal_approx(displayed[0], initial_fill), "Inventory replacement publishes once without resetting XP fill")
	var update := other.to_data()
	update.xp += 5
	other.load_data(update)
	check(is_equal_approx(ring._shown, initial_fill) and ring.progress > initial_fill, "New XP animates from the current fill")
	other.changed.disconnect(update_display)
	var homes := HomeProbe.new()
	var party := {members = [pid, oid], leader = pid}
	stats.home = "Snowbell"
	other.home = "Sunveil"
	var home_step := Campaigns.step_def("frozen_whisper", Campaigns.step_index("frozen_whisper", "home"))
	var home_progress := homes._home_progress(party, home_step)
	homes._check_home_step(party)
	check(homes.advances == 0, "Campaign waits while another party account has not set home")
	check(Campaigns.objective_text(home_step, 0, home_progress, pid).begins_with("Wait for your party to set home in Snowbell"),
		"Ready party members see their waiting objective")
	other.home = "Snowbell"
	homes._check_home_step(party)
	check(homes.advances == 1, "Campaign advances when every party account has the required home")
	homes.free()
	commands.records.Other.dead = true
	commands._command(p, "/lvl Other 50")
	check(other.level == 25, "Dead characters cannot be leveled")
	var picker := CharacterPicker.new(stats)
	add_child(picker)
	var saved := {"class" = stats.class_id, level = stats.level, stats = {base = stats.base.duplicate(), base_hp = stats.base_hp, base_mp = stats.base_mp}, gear = {}}
	for slot in stats.gear: saved.gear[slot] = stats.gear[slot].id if stats.gear[slot] else null
	var preview := picker._row_stats(saved, false)
	check(preview.max_hp == stats.max_hp and preview.max_mp == stats.max_mp, "Inactive character shows saved full vitals with gear")
	for stat in PlayerStats.STATS:
		check(preview.total(stat) == stats.total(stat), "Roster total agrees for " + stat)
	saved.id = 123
	var row := picker._alive_row(saved, false)
	picker.add_child(row)
	var content := row.get_child(0).get_child(0).get_child(1)
	check(content.get_child_count() == 2, "Character buttons contain only name/level and HP/MP rows")
	picker.free()
	var shard := Items.make("story_clue")
	var first_icon := shard.icon()
	var first_shape := shard.silhouette()
	check(shard._icon == first_icon, "Map shard retains its color texture for draw commands")
	shard.count = 6
	var complete_shape := shard.silhouette()
	check(shard._icon_variant == 6 and shard._icon != first_icon and complete_shape != first_shape,
		"Changing shard count refreshes both the colored map and its outline")
	var map_image := shard.icon().get_image()
	var colored := false
	for y in map_image.get_height():
		for x in map_image.get_width():
			var color := map_image.get_pixel(x, y)
			if color.a > 0 and (not is_equal_approx(color.r, color.g) or not is_equal_approx(color.g, color.b)): colored = true
	check(colored, "Completed map keeps its colored image")
	var arrows := Arrows.new()
	add_child(arrows)
	arrows.set_physics_process(false)
	arrows.spawn(Vector3.ZERO, Vector3.FORWARD, 1, weapon)
	check(is_equal_approx(float(arrows._shots[0].range), float(weapon.projectile.range) * .6), "Own projectile range reduced by 40 percent")
	arrows.spawn(Vector3.ZERO, Vector3.FORWARD, 1, weapon, 0, "", {visual = true, range = 1.5})
	check(is_equal_approx(float(arrows._shots[1].range), float(weapon.projectile.range) * .6 * 1.5), "Remote charged shots use the same reduced range")
	var step := SoundSynth.make("step_wood0")
	var peak := 0.0
	for i in step.data.size() / 2: peak = maxf(peak, absf(step.data.decode_s16(i * 2) / 32767.0))
	check(peak <= .301, "Footstep source peak is quieter")
	check(GameAudio.canonical("enemy_hurt") != GameAudio.canonical("hurt"), "Enemies and players use separate hurt events")
	var paths: Array = GameAudio.events["combat.enemy_hurt"].paths
	check(paths.size() == 4 and paths.all(func(path: String) -> bool: return "enemy_hurt" in path), "All four dedicated enemy hurt clips are imported")
	check(GameAudio._compressor.ratio <= 1.3 and GameAudio._compressor.threshold >= -8, "Balanced mix uses gentle compression")
	commands.free()
	GameServer.remove_player(pid)
	GameServer.remove_player(oid)
	print("Combat tuning: %d checks, %d failures" % [checks, failures])
	get_tree().quit(1 if failures else 0)
