extends Node
var out := "/home/hugo/tmp/void_wiki/media"
var index := {enemies = {}, items = {}, attacks = {}}
var view: SubViewport
var stage: Node3D
var camera: Camera3D
var bullets := EnemyBullets.new()
var arrows := Arrows.new()
func _ready() -> void: run.call_deferred()
func decode(v: Variant) -> Variant:
	if v is Dictionary:
		if v.get("type", "") == "Color": return Color(str(v.hex))
		var d := {}
		for k in v: d[k] = decode(v[k])
		return d
	if v is Array:
		var a := []
		for x in v: a.append(decode(x))
		return a
	return v
func run() -> void:
	GameServer.set_physics_process(false)
	WorldServer.set_process(false)
	DirAccess.make_dir_recursive_absolute(out)
	view = SubViewport.new()
	view.size = Vector2i(480, 400)
	view.own_world_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	stage = Node3D.new()
	view.add_child(stage)
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("142334")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(.75,.85,1)
	settings.ambient_light_energy = .8
	env.environment = settings
	stage.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40,-28,0)
	stage.add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	stage.add_child(camera)
	camera.current = true
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("/home/hugo/tmp/void_wiki/catalog.json"))
	var seen := {}
	for row: Dictionary in data.enemies:
		var model := str(row.model)
		if not seen.has(model):
			await render(CreatureModel.new(model), "creature_"+model)
			seen[model] = true
		index.enemies[row.id] = "creature_"+model+".png"
		var attacks: Array = decode(row.attacks)
		attacks.append_array(decode(row.get("review_attacks", [])))
		for phase in row.get("phases", []):
			for attack in decode(phase).get("attacks", []): attacks.append(attack)
			for attack in decode(phase).get("attacks_shielded", []): attacks.append(attack)
		var keys := []
		for attack in attacks:
			if not attack is Dictionary: continue
			var actual: Dictionary = EnemyBullets._boss_attack(attack, str(row.id))
			var key := JSON.stringify(actual).sha256_text().substr(0,16)
			keys.append({image = "attack_"+key+".png", attack = attack})
			if seen.has(key): continue
			seen[key] = true
			var mi := MeshInstance3D.new()
			mi.mesh = bullets._mesh_for(actual)
			await render(mi, "attack_"+key)
		index.attacks[row.id] = keys
	var all_items: Array = data.items.duplicate()
	for row in data.authored_items:
		if not row.registered: all_items.append(row)
	for row in all_items:
		if float(row.damage_max) <= 0: continue
		var weapon := Item.new()
		var props := {}
		for p in weapon.get_property_list(): props[p.name] = true
		for k in row:
			if props.has(k): weapon.set(k, decode(row[k]))
		var style := str(weapon.projectile.get("style", "arrow"))
		var object := Node3D.new()
		var meshes: Array = arrows._meshes_for(weapon, style)
		for i in meshes.size():
			if meshes[i] == null: continue
			var mi := MeshInstance3D.new()
			mi.mesh = meshes[i]
			mi.material_override = VoxModel.glow_material() if i == 1 else VoxModel.material()
			object.add_child(mi)
		await render(object, "item_"+str(row.id))
		index.items[row.id] = "item_"+str(row.id)+".png"
	FileAccess.open(out+"/index.json", FileAccess.WRITE).store_string(JSON.stringify(index))
	bullets.free()
	arrows.free()
	print("Wiki renders complete: ", index.enemies.size(), " creatures and ", index.items.size(), " weapon projectiles")
	get_tree().quit()
func render(object: Node3D, key: String) -> void:
	if FileAccess.file_exists(out+"/"+key+".png"):
		object.free()
		return
	stage.add_child(object)
	if object is CreatureModel: object.animate(0,0)
	var bounds := AABB()
	var first := true
	var meshes := object.find_children("*", "MeshInstance3D", true, false)
	if object is MeshInstance3D: meshes.append(object)
	for mesh: MeshInstance3D in meshes:
		if mesh.mesh == null or not mesh.is_visible_in_tree(): continue
		var box: AABB = mesh.global_transform * mesh.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var center := bounds.get_center()
	camera.position = center+Vector3(10,7,-24)
	camera.look_at(center)
	var box := camera.global_transform.affine_inverse()*bounds
	camera.size = maxf(.2, maxf(box.size.y,box.size.x/1.2)*1.2)
	for frame in 3: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png(out+"/"+key+".png")
	object.queue_free()
	await get_tree().process_frame
