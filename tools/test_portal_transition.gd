extends Node3D
## Short renderer smoke fixture. Does not load or change account data.
var _frames := 0
var _failed := false

func _process(_delta: float) -> void:
	_frames += 1

func _ready() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("192133")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.8
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-35,0)
	add_child(sun)
	for spec: Array in [[Vector3(0,-0.5,0),Vector3(35,1,35),Color("37643b")],
		[Vector3(-4,2,0),Vector3(3,4,4),Color("bd734c")],
		[Vector3(4,3,-4),Vector3(4,6,4),Color("687aa4")],
		[Vector3(0,1,3),Vector3(1,2,1),Color("a9d3eb")]]:
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = spec[1]
		box.mesh = mesh
		box.position = spec[0]
		var material := StandardMaterial3D.new()
		material.albedo_color = spec[2]
		box.material_override = material
		add_child(box)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 24
	camera.far = 180
	add_child(camera)
	camera.position = Vector3(14,22,24)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var loader := WorldLoader.new()
	add_child(loader)
	var before := _frames
	var prepared := await loader.prepare("portal_fixture",{id="portal_fixture",dungeon="goblins_cave",seed=12345,origin="hall"})
	_check(prepared is DungeonWorld,"worker returns dungeon data")
	_check(_frames>before+2,"main loop advances during preparation")
	if is_instance_valid(prepared):
		_check(prepared.has_meta("prepared_fog"),"fog prepared off main thread")
		_check(is_instance_valid(prepared._prepared_scenery),"scenery prepared off main thread")
		loader.retire(prepared)
	if DisplayServer.get_name()=="headless":
		if "--prepare-worlds" in OS.get_cmdline_user_args():
			for entry: Array in [["hall",{}],["chm_portal_fixture",{id="chm_portal_fixture",chambers=true}],
				["castle",{id="castle",castle=true}],["portal_realm_fixture",{id="portal_realm_fixture",seed=WorldServer.MAP_SEED,destroyed=[]}]]:
				before = _frames
				var data := await loader.prepare(entry[0],entry[1])
				_check(is_instance_valid(data) and data.has_meta("prepared_fog"),"prepared "+str(entry[0]))
				_check(_frames>before,"frames advance for "+str(entry[0]))
				if is_instance_valid(data):
					var started := Time.get_ticks_usec()
					add_child(data)
					print("[portal] publish ",entry[0]," ms=",(Time.get_ticks_usec()-started)/1000.0)
					if data is IslandWorld:
						data.update_streaming(data.spawn_point)
						while not data.is_presentation_ready():
							data.update_streaming(data.spawn_point)
							await get_tree().process_frame
					else:
						while not data.is_presentation_ready(): await get_tree().process_frame
					loader.retire(data)
		print("[portal] worker smoke complete, frames=",_frames)
		get_tree().quit(1 if _failed else 0)
		return
	if "--actual-world" in OS.get_cmdline_user_args():
		for child in get_children():
			if child is MeshInstance3D: child.queue_free()
		var hall := await loader.prepare("hall",{})
		add_child(hall)
		while not hall.is_presentation_ready(): await get_tree().process_frame
		var viewer := VoxelViewer.new()
		viewer.view_distance = 80
		add_child(viewer)
		viewer.position = hall.spawn_point
		camera.position = hall.spawn_point+Vector3(18,25,25)
		camera.look_at(hall.spawn_point+Vector3.UP)
		camera.size = 32
		await get_tree().create_timer(1.5).timeout
	await get_tree().create_timer(0.3).timeout
	var fracture := PortalFracture.new()
	add_child(fracture)
	var mask := camera.cull_mask
	await fracture.capture(camera,false)
	await _snapshot("source",fracture,0.0)
	await _snapshot("breakup",fracture,0.38)
	fracture.clear()
	_check(camera.cull_mask==mask,"departure restores camera mask")
	await get_tree().process_frame
	await fracture.capture(camera,true)
	await _snapshot("arrival",fracture,0.48)
	await _snapshot("handoff",fracture,0.94)
	await _snapshot("settled",fracture,1.0)
	fracture.clear()
	_check(camera.cull_mask==mask,"arrival restores camera mask")
	_check(camera.environment==null,"arrival restores camera environment")
	var transition := Transition.new()
	add_child(transition)
	await transition.jump_in("Goblins Cave")
	_check(transition.is_loading(),"loading visible after departure")
	transition.set_progress(0.6)
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/void_portal_loader.png")
	await transition.jump_out()
	_check(not transition.is_loading() and not transition.is_animating(),"arrival releases overlay")
	print("[portal] renderer smoke complete, frames=",_frames)
	get_tree().quit(1 if _failed else 0)

func _snapshot(label: String,fracture: PortalFracture,progress: float) -> void:
	fracture.set_progress(progress)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/void_portal_"+label+".png")
	if label=="source":
		_check(fracture._pieces.multimesh.instance_count>500,"native geometry produces volumetric voxels")
	if label in ["handoff","settled"]:
		var image := get_viewport().get_texture().get_image()
		var visible := 0
		for y in range(10,image.get_height(),30):
			for x in range(10,image.get_width(),30):
				if image.get_pixel(x,y).get_luminance()>0.04: visible += 1
		_check(visible>40,"world stays visible during "+label)

func _check(ok: bool,label: String) -> void:
	if not ok:
		_failed = true
		push_error("[portal] FAIL "+label)
	else: print("[portal] PASS ",label)
