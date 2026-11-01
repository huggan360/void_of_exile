class_name CameraShake
## Proximity camera shake, reusable for anything that should rattle the
## screen: warp rings, boss slams, explosions...
##
##   CameraShake.shake_at(position, strength, radius)
##
## Every registered listener (each player's camera) within `radius` gets
## shaken; the effect falls off quickly with distance, so only players close
## by really feel it. Strength 1.0 is the strongest shake; keep everyday
## effects around 0.2-0.4 so they never get in the way of aiming.
##
## Listeners need `global_position` and `add_trauma(amount: float)` (Player
## has both).

static var _listeners: Array = []


static func register(listener: Object) -> void:
	if not listener in _listeners:
		_listeners.append(listener)


static func unregister(listener: Object) -> void:
	_listeners.erase(listener)


## shake_at for something in a world (an enemy): on the server it's sent to
## the players in that realm.
static func shake_from(source: Node, position: Vector3, strength: float, radius: float) -> void:
	if Net.is_server():
		Net.server.fx(source, position, ["sh", position, strength, radius])
		return
	shake_at(position, strength, radius)


static func shake_at(position: Vector3, strength: float, radius: float) -> void:
	for listener in _listeners.duplicate():
		if not is_instance_valid(listener):
			_listeners.erase(listener)
			continue
		var d: float = listener.global_position.distance_to(position)
		if d < radius:
			var falloff := 1.0 - d / radius
			listener.add_trauma(strength * falloff * falloff)
