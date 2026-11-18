class_name SignaturePatterns
## Shot directions and damage shares shared by the real player, burst
## handler and previews. Every radial display has a fixed total budget.

static func primary(direction: Vector3, up: Vector3, weapon: Item) -> Array[Dictionary]:
	if weapon.is_legendary():
		return _volley(direction, up, weapon.projectile.get("primary_pattern", []), 1.0, false)
	var mode := str(weapon.projectile.get("pattern", ""))
	if mode == "": return []
	return _display(direction, up, mode, weapon.shots, 1.0)

static func charged(direction: Vector3, up: Vector3, weapon: Item, multiplier: float) -> Array[Dictionary]:
	var c := weapon.charge
	if weapon.is_legendary() and c.get("style", "") == "legendary":
		return _volley(direction, up, c.get("pattern", []), multiplier, true)
	var count := clampi(int(c.get("count", 7)), 1, 40)
	var out: Array[Dictionary] = []
	match str(c.style):
		"canopy":
			return _display(direction, up, "canopy", count, multiplier)
		"facet_volley":
			for i in count:
				var angle := (i - (count - 1) * 0.5) * deg_to_rad(3.0)
				out.append({direction = direction.rotated(up, angle), share = multiplier / count, phase = PI * (i % 2),
					mods = {up = up, speed = 1.15, size = 1.4, range = 1.15, wave_amp = 0.4, pierce = true}})
		"facet_burst", "firework":
			out.append({direction = direction, share = multiplier, phase = 0.0,
				mods = {up = up, speed = 0.8 if c.style == "firework" else 1.05, size = 1.25 if c.style == "firework" else 1.8,
					range = 1.15, pierce = false, burst = "signature", secondary = true}})
	return out

static func _volley(direction: Vector3, up: Vector3, pattern: Array, total: float, secondary: bool) -> Array[Dictionary]:
	var right := direction.cross(up).normalized()
	if right.is_zero_approx():
		var fallback := Vector3.FORWARD if absf(direction.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
		right = direction.cross(fallback).normalized()
	var lift := right.cross(direction).normalized()
	var out: Array[Dictionary] = []
	for i in pattern.size():
		var entry: Dictionary = pattern[i]
		var yaw := deg_to_rad(float(entry.get("yaw", 0)))
		var pitch := deg_to_rad(float(entry.get("pitch", 0)))
		var heading := (direction + right * tan(yaw) + lift * tan(pitch)).normalized()
		out.append({direction = heading, share = total / pattern.size(), phase = float(i),
			mods = {up = up, speed = float(entry.get("speed", 1)), delay = float(entry.get("delay", 0)),
				size = 1.35 if secondary else 1.0, range = 1.08 if secondary else 1.0, secondary = secondary}})
	return out

static func burst(weapon: Item, up: Vector3, secondary: bool) -> Array[Dictionary]:
	var p := weapon.projectile
	var c := weapon.charge
	var count := clampi(int(c.get("count", 10) if secondary else p.get("burst_count", 10)), 1, 40)
	var total := float(c.get("shard_total", 1.0) if secondary else p.get("burst_total", 0.5))
	var display := _display(Vector3.FORWARD.slide(up).normalized() if absf(up.dot(Vector3.FORWARD)) < 0.99 else Vector3.RIGHT,
		up, "canopy" if weapon.is_artifact() else "radial", count, total)
	for shot: Dictionary in display:
		shot.mods = {up = up, secondary = true, speed = 1.1, size = 0.6 if weapon.is_artifact() else 0.85,
			range = 0.48, pierce = false, style = "festival_spark" if weapon.is_artifact() else "facet_lance"}
	return display

static func _display(direction: Vector3, up: Vector3, mode: String, count: int, total: float) -> Array[Dictionary]:
	var forward := direction.slide(up).normalized()
	if forward.is_zero_approx():
		var axis := Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT
		forward = axis.slide(up).normalized()
	var right := forward.cross(up).normalized()
	var out: Array[Dictionary] = []
	for i in count:
		var angle := TAU * i / count
		var height := 0.0
		if mode == "canopy": height = 0.2 + 0.7 * float(i % 4) / 3.0
		elif mode == "sphere": height = -0.5 + float(i) / maxi(1, count - 1) * 1.4
		var flat := sqrt(maxf(0.0, 1.0 - height * height))
		var heading := ((forward * cos(angle) + right * sin(angle)) * flat + up * height).normalized()
		out.append({direction = heading, share = total / count, phase = TAU * i / count,
			mods = {up = up, wave_amp = 0.7, lift_amp = 0.6}})
	return out
