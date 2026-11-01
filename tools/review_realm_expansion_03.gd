extends Node3D
## Native production-model inspection. Run with --biome=doom/fosen/blue/desert/dark/normal.
const GROUPS := {
	doom=["slag_seraph","obsidian_ram","ember_lich"],
	fosen=["aurora_sentinel","hoarfrost_owl","icebound_colossus"],
	blue=["prism_ray","runic_archivist","azure_medusa"],
	desert=["sun_jackal","dune_monolith","glass_scorpion"],
	dark=["umbral_reaper","amethyst_widow","nightbell_idol"],
	normal=["bramble_fox","moss_tortoise","vine_mantis","tide_snail","dune_crawler","gloam_bat","bile_bandit"],
}
var models: Array[CreatureModel] = []
func _ready() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=",true,1)
		args[kv[0]] = kv[1] if kv.size()==2 else "true"
	var names: Array = GROUPS.get(str(args.get("biome","doom")),GROUPS.doom)
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("#182435")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("#c7d7e6")
	settings.ambient_light_energy = .65
	settings.glow_enabled = true
	env.environment = settings
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-32,0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	var columns := 4 if names.size()>3 else 3
	for i in names.size():
		var model := CreatureModel.new(names[i])
		model.position = Vector3((float(columns-1)*.5-i%columns)*4.7,0,(i/columns)*5.5)
		add_child(model)
		models.append(model)
		var floor_mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(4,.12,4)
		floor_mesh.mesh = box
		floor_mesh.position = model.position-Vector3.UP*.08
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("#344757")
		floor_mesh.material_override = mat
		add_child(floor_mesh)
		var title := Label3D.new()
		title.text = names[i].replace("_"," ").capitalize()
		title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		title.font_size = 38
		title.pixel_size = .008
		title.position = model.position+Vector3(0,-.4,-2)
		title.no_depth_test = true
		add_child(title)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12 if names.size()>3 else 8.5
	var focus := Vector3(0,1.2,2.4 if names.size()>3 else 0)
	camera.position = focus+Vector3(0,9,-18)
	add_child(camera)
	camera.look_at(focus)
	camera.current = true
	if args.has("shot"):
		await get_tree().create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(str(args.shot))
		get_tree().quit()
func _process(delta: float) -> void:
	for model in models: model.animate(.1,delta)
