extends Boss
## Three escalating shotgun phases, separated by a three-second reload intermission.
## 100-65%: aimed buckshot and heavy slugs. 65-30%: sweeping double blasts.
## Below 30%: turnip bombs force movement between the shotgun volleys.

func _phase_started(index: int) -> void:
	behavior = "skirmish"
	move_speed = 2.2 + index * 0.6
	match index:
		0:
			status_text = "Keep off my land!"
			set_cycle(7.0, [[0.0, _blast], [2.3, _blast], [4.6, _slug]])
		1:
			status_text = "Both barrels - sweeping buckshot"
			set_cycle(7.5, [[0.0, _double], [3.0, _slug], [5.0, _double]])
		2:
			status_text = "Last stand - explosive turnips"
			set_cycle(8.0, [[0.0, _turnips], [2.2, _double], [5.0, _slug], [6.5, _blast]])


func _threshold_reached(next: int) -> void:
	if resting: return
	begin_rest(func() -> void: _enter_phase(next), "Reloading - stay clear!", "kneel")


func _round(slug: bool) -> Dictionary:
	return Boss.shot("bolt" if slug else "pellet", Color(1.0, 0.7, 0.3),
		Vector2i(60, 80) if slug else Vector2i(35, 48), 12.0 if slug else 9.0,
		0.28 if slug else 0.2, 26.0 if slug else 21.0,
		{voxel_model = "boss_projectiles/farmer_slug" if slug else "boss_projectiles/farmer_buckshot",
		size = 2.4 if slug else 3.0, pixel_projectile = true,
		projectile_glow = 0.4, authored_projectile = true})


func _blast() -> void:
	model.play_attack(0.7)
	pulse_glow(0.9, 0.7)
	var direction := aim_dir()
	after(0.7, func() -> void: fire_fan(shot_origin(0.9), direction, 9 if phase > 0 else 7, 7.0, _round(false)))


func _double() -> void:
	# Two offset fans leave moving gaps instead of repeating the same shot.
	var direction := aim_dir()
	model.play_attack(0.8)
	pulse_glow(1.2, 0.8)
	after(0.8, func() -> void: fire_fan(shot_origin(0.9), direction.rotated(Vector3.UP, -0.18), 9, 7.0, _round(false)))
	after(1.3, func() -> void:
		model.play_attack(0.25)
		fire_fan(shot_origin(0.9), direction.rotated(Vector3.UP, 0.18), 9, 7.0, _round(false)))


func _slug() -> void:
	model.play_attack(1.0)
	pulse_glow(1.6, 1.0)
	var direction := aim_dir()
	# The last phase uses a three-slug fan, still aimed before its windup.
	after(1.0, func() -> void: fire_fan(shot_origin(0.9), direction, 3 if phase == 2 else 1, 18.0, _round(true)))


func _turnips() -> void:
	model.play_attack(1.1)
	pulse_glow(1.4, 1.1)
	var direction := aim_dir()
	var bomb := Boss.shot("orb", Color("c8dc79"), Vector2i(45, 60), 5.0, 0.35, 22.0,
		{voxel_model = "boss_projectiles/farmer_turnip", authored_projectile = true,
		pixel_projectile = true, projectile_glow = 0.3})
	after(1.1, func() -> void: fire_fan(shot_origin(0.9), direction, 5, 24.0, bomb))
	# Clearly marked explosions deny camping while the slow turnips travel.
	for player in players():
		hazards.circle(player.global_position, 2.4, 1.8, Vector2i(50, 65), Color("c8dc79"))


func _reset_hook() -> void:
	resting = false
