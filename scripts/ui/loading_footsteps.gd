class_name LoadingFootsteps
extends Control
## Curved paths are constrained to the outside quarter of the screen.
const LIFETIME := 3.0
var _prints: Array[Dictionary] = []
var _walkers: Array[Dictionary] = []
var _step_clock := 0.0
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rng.randomize()

func reset_trails() -> void:
	_prints.clear()
	_walkers.clear()
	_step_clock = 0.0
	var paths := [
		[Vector2(-0.06,0.08),Vector2(0.22,0.06),Vector2(0.22,0.42),Vector2(-0.06,0.5)],
		[Vector2(1.06,0.35),Vector2(0.79,0.38),Vector2(0.79,0.87),Vector2(1.06,0.92)],
		[Vector2(0.12,1.06),Vector2(0.32,0.78),Vector2(0.65,0.78),Vector2(0.84,1.06)],
		[Vector2(0.15,-0.06),Vector2(0.34,0.20),Vector2(0.65,0.20),Vector2(0.9,-0.06)],
	]
	paths.shuffle()
	for i in 3: _walkers.append({points=paths[i],t=0.04+i*0.1,side=false,speed=_rng.randf_range(0.065,0.085)})
	queue_redraw()

func advance(delta: float) -> void:
	for mark in _prints: mark.age += delta
	_prints = _prints.filter(func(mark: Dictionary) -> bool: return mark.age<LIFETIME)
	for walker in _walkers:
		walker.t += delta*walker.speed
		if walker.t>1.12: walker.t = -0.08
	_step_clock += delta
	while _step_clock>=0.22:
		_step_clock -= 0.22
		for walker in _walkers: _stamp(walker)
	queue_redraw()

func _path(points: Array, t: float) -> Vector2:
	return (points[0] as Vector2).bezier_interpolate(points[1],points[2],points[3],clampf(t,0,1))

func _stamp(walker: Dictionary) -> void:
	if walker.t<0 or walker.t>1: return
	var point := _path(walker.points,walker.t)
	# A hard exclusion protects the central weapon, destination and progress.
	if point.x>0.25 and point.x<0.75 and point.y>0.22 and point.y<0.78: return
	var direction := (_path(walker.points,minf(1.0,walker.t+0.004))-_path(walker.points,maxf(0.0,walker.t-0.004))) * size
	direction = direction.normalized()
	walker.side = not walker.side
	var position := point*size + direction.orthogonal()*(7 if walker.side else -7)
	_prints.append({position=position,angle=direction.angle()+PI*0.5,age=0.0})

func _draw() -> void:
	for mark in _prints:
		var alpha := pow(1.0-mark.age/LIFETIME,1.5)*0.78
		draw_set_transform(mark.position,mark.angle,Vector2.ONE*0.8)
		var color := Color(0.95,0.95,0.95,alpha)
		draw_colored_polygon(PackedVector2Array([Vector2(-4,0),Vector2(-6,-7),Vector2(-3,-13),Vector2(2,-14),Vector2(5,-10),Vector2(5,-3),Vector2(3,0)]),color)
		draw_rect(Rect2(-3,4,6,7),color)
		# Small tread cuts keep the prints in the same ink-dotted language.
		for at in [Vector2(-2,-6),Vector2(2,-8),Vector2(0,-3)]: draw_circle(at,0.8,Color(0.03,0.03,0.03,alpha))
	draw_set_transform(Vector2.ZERO)
