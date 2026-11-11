class_name LowHealthOverlay
extends CanvasLayer
## Fine branching blood vessels grow inward from the edges below the HUD.
## Healing retracts the same vessels; no splashes obscure the play area.

const STAGES := [0.15, 0.10, 0.05]
const LAYOUT_SEED := 7331

var stats: PlayerStats
var dead := false

var _root := Control.new()
var _veins: Array[Dictionary] = []
var _shown := 0.0
var _time := 0.0
var _last_size := Vector2.ZERO


func _ready() -> void:
	# The world grade is created first on layer 0; HUD and windows start at 1.
	layer = 0
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_root.draw.connect(_draw_veins)


func _process(delta: float) -> void:
	_time += delta
	var share := 1.0 if stats == null else stats.hp / maxf(1.0, stats.max_hp)
	var stage := 4.0 if dead else (3.0 if share <= STAGES[2] else 2.0 if share <= STAGES[1] else 1.0 if share <= STAGES[0] else 0.0)
	_shown = move_toward(_shown, stage, delta * (1.6 if stage > _shown else 0.8))
	if _root.size != _last_size:
		_last_size = _root.size
		_build_veins(_last_size)
	_root.visible = _shown > 0.0
	if _root.visible:
		_root.queue_redraw()


func _build_veins(size: Vector2) -> void:
	_veins.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = LAYOUT_SEED
	var unit := minf(size.x, size.y)
	for side in 4:
		for i in 8:
			var t := (i + rng.randf_range(0.18, 0.82)) / 8.0
			var origin: Vector2
			var inward: Vector2
			match side:
				0:
					origin = Vector2(size.x * t, -2)
					inward = Vector2.DOWN
				1:
					origin = Vector2(size.x * t, size.y + 2)
					inward = Vector2.UP
				2:
					origin = Vector2(-2, size.y * t)
					inward = Vector2.RIGHT
				_:
					origin = Vector2(size.x + 2, size.y * t)
					inward = Vector2.LEFT
			var stage := 1 + (i + side) % 3
			var length := unit * rng.randf_range(0.09, 0.155)
			_branch(rng, origin, inward.rotated(rng.randf_range(-0.4, 0.4)), length,
				maxf(1.2, unit / 650.0), float(stage - 1), 0)


func _branch(rng: RandomNumberGenerator, origin: Vector2, direction: Vector2,
		length: float, width: float, onset: float, depth: int) -> void:
	var points := PackedVector2Array([origin])
	var heading := direction
	for i in 10:
		heading = heading.rotated(rng.randf_range(-0.32, 0.32))
		points.append(points[-1] + heading * length / 10.0)
	_veins.append({points = points, width = width, onset = onset, duration = 0.85 if depth == 0 else 0.4})
	if depth >= 2:
		return
	for fork in [4, 7]:
		var tangent := (points[fork + 1] - points[fork]).normalized()
		var turn := rng.randf_range(0.45, 0.95) * (-1.0 if fork == 4 else 1.0)
		_branch(rng, points[fork], tangent.rotated(turn), length * rng.randf_range(0.3, 0.48),
			maxf(0.65, width * 0.6), onset + float(fork) / 10.0 * 0.85, depth + 1)


func _draw_veins() -> void:
	var pulse := 0.88 if dead else 0.84 + 0.08 * sin(_time * 5.0)
	for vein: Dictionary in _veins:
		var growth := clampf((_shown - vein.onset) / vein.duration, 0.0, 1.0)
		if growth <= 0.0:
			continue
		var points: PackedVector2Array = vein.points
		var extent := growth * (points.size() - 1)
		for i in mini(ceili(extent), points.size() - 1):
			var tip := points[i].lerp(points[i + 1], minf(1.0, extent - i))
			var taper := 1.0 - 0.65 * float(i) / (points.size() - 1)
			var width := maxf(0.65, vein.width * taper)
			# Thin dark rims keep vessels legible over both foliage and pale sky.
			_root.draw_line(points[i], tip, Color(0.13, 0.015, 0.025, pulse * 0.65), width + 0.7, true)
			_root.draw_line(points[i], tip, Color(0.55, 0.055, 0.075, pulse), width, true)
