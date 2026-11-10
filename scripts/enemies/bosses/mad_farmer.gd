extends Boss
## Campaign-only shotgun miniboss. Uses normal encounter cleanup and rewards.

func _phase_started(index: int) -> void:
	behavior = "skirmish"
	move_speed = 2.2 + index * 0.6
	if index == 0:
		set_cycle(6.5, [[0.0, _blast], [2.0, _blast], [4.0, _slug]])
	elif index == 1:
		set_cycle(5.5, [[0.0, _double], [2.5, _slug], [4.0, _blast]])
	else:
		set_cycle(5.0, [[0.0, _double], [2.0, _slug], [3.2, _double]])


func _threshold_reached(next: int) -> void:
	if resting: return
	begin_rest(func() -> void: _enter_phase(next), "Reloading - stay clear!", "kneel")


func _round(slug: bool) -> Dictionary:
	return Boss.shot("bolt" if slug else "pellet", Color(1.0, 0.7, 0.3),
		Vector2i(50, 70), 12.0 if slug else 10.0,
		0.16 if slug else 0.09, 24.0 if slug else 17.0,
		{voxel_model = "boss_projectiles/farmer_slug" if slug else "boss_projectiles/farmer_buckshot",
		authored_projectile = true})


func _blast() -> void:
	model.play_attack(0.7)
	pulse_glow(0.9, 0.7)
	var direction := aim_dir()
	after(0.7, func() -> void: fire_fan(shot_origin(), direction, 7, 7.0, _round(false)))


func _double() -> void:
	_blast()
	after(1.1, _blast)


func _slug() -> void:
	model.play_attack(1.0)
	pulse_glow(1.6, 1.0)
	var direction := aim_dir()
	after(1.0, func() -> void: shoot(shot_origin(), direction, _round(true)))


func _reset_hook() -> void:
	resting = false
