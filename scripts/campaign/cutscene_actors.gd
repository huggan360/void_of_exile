class_name CutsceneActors
extends Node3D
## The people of a film (a cutscene's `actors`), standing in the real places
## its shots visit: the stage (the Hollow Castle) or a planet of the Reach.
## Made by CampaignClient._staged, freed when the film ends. Each actor
## idles, walks a circle (`walk` = [radius, speed]) or marches to and fro
## along `march` (a local offset), so the places do not look frozen.
var _actors: Array = []  # [model, centre, walk, march, basis, time]

func add(model_id: String, frame: Transform3D, spec: Dictionary) -> void:
	var model := CreatureModel.new(model_id)
	add_child(model)
	model.global_transform = Transform3D(frame.basis.rotated(frame.basis.y.normalized(), float(spec.get("yaw", 0.0))).scaled_local(Vector3.ONE*float(spec.get("scale", 1.0))), frame.origin)
	if spec.has("variant"): model.set_variant(str(spec.variant))
	_actors.append([model, frame, spec.get("walk", []), spec.get("march", Vector3.ZERO), randf()*TAU])

func _process(delta: float) -> void:
	for a: Array in _actors:
		var model: CreatureModel = a[0]
		var frame: Transform3D = a[1]
		var walk: Array = a[2]
		var march: Vector3 = a[3]
		a[4] = float(a[4])+delta
		var t := float(a[4])
		var moving := 0.0
		if walk.size()==2:
			var angle := t*float(walk[1])
			var local := Vector3(cos(angle), 0, sin(angle))*float(walk[0])
			var ahead := Vector3(-sin(angle), 0, cos(angle))*signf(float(walk[1]))
			model.global_transform = Transform3D(Basis.looking_at(frame.basis*ahead, frame.basis.y).scaled_local(model.basis.get_scale()), frame*local)
			moving = 1.0
		elif march!=Vector3.ZERO:
			var along := pingpong(t*1.4, march.length())/march.length()
			var dir := march.normalized()*(1.0 if fmod(t*1.4, march.length()*2.0)<march.length() else -1.0)
			model.global_transform = Transform3D(Basis.looking_at(frame.basis*dir, frame.basis.y).scaled_local(model.basis.get_scale()), frame*(march*along))
			moving = 1.0
		model.animate(moving, delta)
