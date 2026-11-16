class_name ShipPrediction
extends RefCounted
## The pilot's own ship flown ahead on their client, the way shooters predict
## their player: every physics tick flies a local copy on the helm's last sent
## input, and each server snapshot (which says the last helm input the server
## has and how many ticks it has flown on it) resets the copy to the server's
## and flies again the ticks the server hasn't flown yet. SpaceShipView eases
## out whatever difference is left, so a correction never jumps.
const HISTORY := 180  # ticks kept (3 s at 60 a second)

var ship := SpaceShip.new()
var _seq := 0
var _input: Array = [0.0, 0.0, 0.0, 0.0, false, false]
var _ticks: Array = []  # [helm seq, input, delta] per tick flown here, oldest first
var _before := Transform3D.IDENTITY  # the pose a tick ago, drawn toward the current one

## A helm input on its way to the server: its number, which comes back in snapshots.
func send(input: Array) -> int:
	_seq += 1
	_input = input.duplicate()
	return _seq

## Taking the helm: fly on from the server's latest.
func start(server: SpaceShip) -> void:
	_ticks.clear()
	_copy(server)
	_before = ship.xform

func tick(delta: float) -> void:
	_ticks.append([_seq, _input, delta])
	if _ticks.size()>HISTORY: _ticks.pop_front()
	_fly(_input, delta)

func reconcile(server: SpaceShip) -> void:
	_copy(server)
	_before = ship.xform
	# The server counts its ticks on an input from the start: keep them until it moves on.
	var flown := server.input_ticks
	var kept: Array = []
	for t: Array in _ticks:
		if int(t[0])<server.input_seq: continue
		kept.append(t)
		if int(t[0])==server.input_seq and flown>0:
			flown -= 1
			continue
		_fly(t[1], float(t[2]))
	_ticks = kept

## Drawn between the last two ticks, so it glides at any frame rate.
func pose() -> Transform3D:
	return _before.interpolate_with(ship.xform, Engine.get_physics_interpolation_fraction())

func _fly(input: Array, delta: float) -> void:
	_before = ship.xform
	ship.input = input.duplicate()
	ship.input_age = 0.0
	ship.step(delta)

func _copy(server: SpaceShip) -> void:
	SpaceShip.from_wire(server.wire(), ship)
