class_name ArtGlitch
extends RefCounted
## The game's hit glitch (white and coloured blinking voxels, flying voxel
## chips) for art built from batched blocks: ship hulls and brood ships.
## The flash sits on the blocks nearest the impact and rides along with them.

## Flash the blocks of `root` within `radius` metres of world point `impact`.
static func flash(root: Node3D, impact: Vector3, radius := 5.0, cell := 0.5) -> void:
	if not is_instance_valid(root) or Net.is_server(): return
	var points := PackedVector3Array()
	var colors := PackedColorArray()
	for node in root.find_children("*", "MultiMeshInstance3D", true, false):
		var batch := node as MultiMeshInstance3D
		if batch.multimesh==null or batch.material_override==CreatureModel._glitch_shader(): continue
		var multi := batch.multimesh
		for i in multi.instance_count:
			var frame := batch.global_transform*multi.get_instance_transform(i)
			if frame.origin.distance_to(impact)>radius+frame.basis.get_scale().length()*0.5: continue
			# A few points on the block's face toward the impact.
			var toward := frame.affine_inverse()*impact
			var axis := 0 if absf(toward.x)>=absf(toward.y) and absf(toward.x)>=absf(toward.z) else (1 if absf(toward.y)>=absf(toward.z) else 2)
			for k in 3:
				var local := Vector3(randf()-0.5, randf()-0.5, randf()-0.5)
				local[axis] = 0.5*signf(toward[axis]) if toward[axis]!=0.0 else 0.5
				points.append(frame*local)
				colors.append(multi.get_instance_color(i) if multi.use_colors else Color.WHITE)
			if points.size()>=72: break
		if points.size()>=72: break
	if points.is_empty(): return
	var cube := BoxMesh.new()
	cube.size = Vector3.ONE*cell
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = cube
	multi.instance_count = points.size()
	var to_root := root.global_transform.affine_inverse()
	for i in points.size():
		multi.set_instance_transform(i, Transform3D(Basis.IDENTITY, to_root*points[i]))
		multi.set_instance_color(i, Color.WHITE if randf()>CreatureModel.GLITCH_COLOR_CHANCE else CreatureModel.GLITCH_COLORS[randi() % CreatureModel.GLITCH_COLORS.size()])
	var overlay := MultiMeshInstance3D.new()
	overlay.multimesh = multi
	overlay.material_override = CreatureModel._glitch_shader()
	overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(overlay)
	overlay.scale = Vector3.ONE/root.global_basis.get_scale()
	var tween := overlay.create_tween()
	tween.tween_method(func(fade: float) -> void: overlay.set_instance_shader_parameter("fade", fade), 1.0, 0.0, CreatureModel.GLITCH_TIME)
	tween.tween_callback(overlay.queue_free)
	Debris.burst_flash(root, points, colors, cell*0.6, mini(points.size(), 40), impact, -1.0e9, 0.6)
